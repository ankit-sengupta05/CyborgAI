"""
World Monitor Service
Real-time system metrics + news headlines + LLM spoken briefing.
"""
import asyncio
import hashlib
import structlog
from datetime import datetime, timedelta
from typing import Optional
import httpx

log = structlog.get_logger(__name__)


# Free news sources (RSS/JSON APIs, no key required)
NEWS_SOURCES = [
    {
        "name": "Reuters",
        "url": "https://feeds.reuters.com/reuters/topNews",
        "type": "rss"
    },
    {
        "name": "BBC",
        "url": "https://feeds.bbci.co.uk/news/world/rss.xml",
        "type": "rss"
    },
    {
        "name": "Hacker News",
        "url": "https://hacker-news.firebaseio.com/v0/topstories.json",
        "type": "hn"
    },
    {
        "name": "NASA APOD",
        "url": "https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY",
        "type": "json"
    },
]

# Category filters
CATEGORIES = ["world", "tech", "science", "markets", "health"]


class NewsItem:
    def __init__(self, title: str, summary: str, url: str,
                 source: str, category: str = "world",
                 published: str = ""):
        self.title = title
        self.summary = summary
        self.url = url
        self.source = source
        self.category = category
        self.published = published
        self.id = hashlib.sha256(title.encode()).hexdigest()[:12]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "summary": self.summary,
            "url": self.url,
            "source": self.source,
            "category": self.category,
            "published": self.published,
        }


class WorldMonitorService:
    def __init__(self):
        self._news_cache: list[NewsItem] = []
        self._last_fetch: Optional[datetime] = None
        self._metrics_history: list[dict] = []
        self._client = httpx.AsyncClient(timeout=10.0)

    async def get_system_metrics(self) -> dict:
        """Real-time CPU, RAM, disk, network, GPU metrics."""
        try:
            import psutil
            cpu_per_core = psutil.cpu_percent(percpu=True, interval=0.3)
            mem = psutil.virtual_memory()
            swap = psutil.swap_memory()
            disk = psutil.disk_usage("/")
            net = psutil.net_io_counters()
            temps = {}
            try:
                temps = psutil.sensors_temperatures() or {}
            except Exception:
                pass

            # Network interfaces
            net_addrs = psutil.net_if_addrs()
            interfaces = list(net_addrs.keys())[:5]

            # Processes (top 10 by CPU)
            procs = []
            for p in sorted(
                psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]),
                key=lambda p: p.info.get("cpu_percent", 0) or 0,
                reverse=True,
            )[:10]:
                try:
                    mem_info = p.info.get("memory_info")
                    procs.append({
                        "pid": p.info["pid"],
                        "name": p.info["name"],
                        "cpu": round(p.info.get("cpu_percent", 0) or 0, 1),
                        "mem_mb": round(mem_info.rss / 1e6, 1) if mem_info else 0,
                    })
                except Exception:
                    pass

            metrics = {
                "timestamp": datetime.utcnow().isoformat(),
                "cpu": {
                    "total": sum(cpu_per_core) / len(cpu_per_core) if cpu_per_core else 0,
                    "per_core": cpu_per_core,
                    "count": psutil.cpu_count(),
                    "freq_mhz": getattr(psutil.cpu_freq(), "current", 0),
                },
                "memory": {
                    "total_gb": round(mem.total / 1e9, 2),
                    "used_gb": round(mem.used / 1e9, 2),
                    "available_gb": round(mem.available / 1e9, 2),
                    "percent": mem.percent,
                    "swap_used_gb": round(swap.used / 1e9, 2),
                    "swap_total_gb": round(swap.total / 1e9, 2),
                },
                "disk": {
                    "total_gb": round(disk.total / 1e9, 2),
                    "used_gb": round(disk.used / 1e9, 2),
                    "free_gb": round(disk.free / 1e9, 2),
                    "percent": disk.percent,
                },
                "network": {
                    "bytes_sent_mb": round(net.bytes_sent / 1e6, 2),
                    "bytes_recv_mb": round(net.bytes_recv / 1e6, 2),
                    "interfaces": interfaces,
                },
                "processes": procs,
                "gpu": await self._get_gpu_info(),
                "temperatures": {
                    k: [{"label": t.label, "current": t.current, "high": t.high}
                        for t in v[:3]] for k, v in list(temps.items())[:3]
                },
            }

            # Keep rolling 60-point history
            self._metrics_history.append({
                "t": metrics["timestamp"],
                "cpu": metrics["cpu"]["total"],
                "mem": metrics["memory"]["percent"],
            })
            self._metrics_history = self._metrics_history[-60:]
            metrics["history"] = self._metrics_history
            return metrics

        except ImportError:
            return {"error": "psutil not installed", "timestamp": datetime.utcnow().isoformat()}

    async def _get_gpu_info(self) -> list[dict]:
        """Get NVIDIA GPU info via pynvml."""
        gpus = []
        try:
            import pynvml
            pynvml.nvmlInit()
            for i in range(pynvml.nvmlDeviceGetCount()):
                h = pynvml.nvmlDeviceGetHandleByIndex(i)
                name = pynvml.nvmlDeviceGetName(h)
                if isinstance(name, bytes):
                    name = name.decode()
                mem = pynvml.nvmlDeviceGetMemoryInfo(h)
                util = pynvml.nvmlDeviceGetUtilizationRates(h)
                temp = pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU)
                gpus.append({
                    "name": name,
                    "utilization_pct": util.gpu,
                    "memory_used_gb": round(mem.used / 1e9, 2),
                    "memory_total_gb": round(mem.total / 1e9, 2),
                    "temperature_c": temp,
                })
        except Exception:
            pass
        return gpus

    async def get_news(self, category: str = "all",
                       force_refresh: bool = False) -> list[dict]:
        """Fetch news from free RSS/JSON sources. Cache for 15 minutes."""
        now = datetime.utcnow()
        if (not force_refresh and self._news_cache
                and self._last_fetch
                and (now - self._last_fetch) < timedelta(minutes=15)):
            items = self._news_cache
        else:
            items = await self._fetch_all_news()
            self._news_cache = items
            self._last_fetch = now

        if category != "all":
            items = [i for i in items if i.category == category]
        return [i.to_dict() for i in items[:50]]

    async def _fetch_all_news(self) -> list[NewsItem]:
        items: list[NewsItem] = []
        tasks = [
            self._fetch_rss(
                "https://feeds.bbci.co.uk/news/world/rss.xml", "BBC World", "world"
            ),
            self._fetch_rss(
                "https://feeds.bbci.co.uk/news/technology/rss.xml", "BBC Tech", "tech"
            ),
            self._fetch_rss(
                "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml",
                "BBC Science", "science"
            ),
            self._fetch_hacker_news(),
            self._fetch_rss(
                "https://www.reddit.com/r/worldnews/.rss", "Reddit WorldNews", "world"
            ),
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        for r in results:
            if isinstance(r, list):
                items.extend(r)
        return items

    async def _fetch_rss(self, url: str, source: str, category: str) -> list[NewsItem]:
        """Parse RSS feed — no library needed, simple regex."""
        import re
        items = []
        try:
            resp = await self._client.get(url, follow_redirects=True)
            text = resp.text

            # Extract items from RSS/Atom
            item_pattern = re.compile(
                r'<item>(.*?)</item>', re.DOTALL | re.IGNORECASE)
            title_pat = re.compile(
                r'<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', re.DOTALL
            )
            desc_pat = re.compile(
                r'<description>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</description>',
                re.DOTALL
            )
            link_pat = re.compile(r'<link>(.*?)</link>', re.DOTALL)
            pub_pat = re.compile(r'<pubDate>(.*?)</pubDate>', re.DOTALL)

            for m in item_pattern.finditer(text):
                block = m.group(1)
                title = (
                    (title_pat.search(block) or re.search('', '')).group(1)
                    if title_pat.search(block) else ""
                )
                desc = (
                    (desc_pat.search(block) or re.search('', '')).group(1)
                    if desc_pat.search(block) else ""
                )
                link = (
                    (link_pat.search(block) or re.search('', '')).group(1)
                    if link_pat.search(block) else ""
                )
                pub = (
                    (pub_pat.search(block) or re.search('', '')).group(1)
                    if pub_pat.search(block) else ""
                )

                # Strip HTML
                title = re.sub(r'<[^>]+>', '', title).strip()
                desc = re.sub(r'<[^>]+>', '', desc).strip()[:300]

                if title and len(title) > 5:
                    items.append(NewsItem(title, desc, link.strip(),
                                          source, category, pub.strip()))
            return items[:20]
        except Exception as e:
            log.debug(f"RSS fetch failed for {source}: {e}")
            return []

    async def _fetch_hacker_news(self) -> list[NewsItem]:
        """Fetch top Hacker News stories."""
        items = []
        try:
            resp = await self._client.get(
                "https://hacker-news.firebaseio.com/v0/topstories.json")
            ids = resp.json()[:10]
            tasks = [
                self._client.get(
                    f"https://hacker-news.firebaseio.com/v0/item/{sid}.json")
                for sid in ids
            ]
            responses = await asyncio.gather(*tasks, return_exceptions=True)
            for r in responses:
                if isinstance(r, Exception):
                    continue
                try:
                    story = r.json()
                    if story and story.get("title"):
                        items.append(NewsItem(
                            title=story["title"],
                            summary=story.get("text", "")[:200],
                            url=story.get(
                                "url",
                                f"https://news.ycombinator.com/item?id={story['id']}"
                            ),
                            source="Hacker News",
                            category="tech",
                            published=datetime.fromtimestamp(story.get("time", 0)).isoformat(),
                        ))
                except Exception:
                    pass
        except Exception as e:
            log.debug(f"HN fetch error: {e}")
        return items

    async def generate_briefing(self, llm_service, category: str = "all") -> str:
        """Generate an AI briefing of current world state using local LLM."""
        news = await self.get_news(category=category)
        metrics = await self.get_system_metrics()

        if not news:
            return "No news data available. Check your internet connection."

        headlines = "\n".join(
            f"- [{item['source']}] {item['title']}"
            for item in news[:15]
        )

        cpu_pct = metrics.get("cpu", {}).get("total", 0)
        mem_pct = metrics.get("memory", {}).get("percent", 0)

        prompt = f"""You are Cyborg's World Monitor AI. Generate a concise spoken briefing
(3-5 sentences) covering the most important current events from these headlines.

SYSTEM STATUS: CPU {cpu_pct:.0f}%, RAM {mem_pct:.0f}%
DATE: {datetime.utcnow().strftime('%A, %B %d, %Y at %H:%M UTC')}

HEADLINES:
{headlines}

Generate a natural, news-anchor style briefing. Be factual, concise, and informative.
Start with "Good [time of day]. Here's your Cyborg world briefing."
"""
        return await llm_service.complete(prompt, temperature=0.4, max_tokens=400)

    async def close(self):
        await self._client.aclose()
