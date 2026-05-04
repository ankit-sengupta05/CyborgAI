"""
System API Routes — metrics, config, device management
"""
import platform
import structlog
from fastapi import APIRouter

log = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/metrics")
async def get_metrics():
    """Get real-time system metrics."""
    try:
        import psutil
        cpu_pct = psutil.cpu_percent(interval=0.3)
        cpu_freq = psutil.cpu_freq()
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage("/")
        net = psutil.net_io_counters()

        # GPU info (optional)
        gpu_info = []
        try:
            import pynvml
            pynvml.nvmlInit()
            for i in range(pynvml.nvmlDeviceGetCount()):
                h = pynvml.nvmlDeviceGetHandleByIndex(i)
                name = pynvml.nvmlDeviceGetName(h).decode()
                mem_info = pynvml.nvmlDeviceGetMemoryInfo(h)
                util = pynvml.nvmlDeviceGetUtilizationRates(h)
                gpu_info.append({
                    "name": name,
                    "utilization": util.gpu,
                    "memory_used_gb": mem_info.used / 1e9,
                    "memory_total_gb": mem_info.total / 1e9,
                })
        except Exception:
            pass

        return {
            "cpu": {
                "percent": cpu_pct,
                "cores": psutil.cpu_count(),
                "freq_mhz": cpu_freq.current if cpu_freq else 0,
                "per_core": psutil.cpu_percent(percpu=True),
            },
            "memory": {
                "total_gb": mem.total / 1e9,
                "used_gb": mem.used / 1e9,
                "available_gb": mem.available / 1e9,
                "percent": mem.percent,
            },
            "disk": {
                "total_gb": disk.total / 1e9,
                "used_gb": disk.used / 1e9,
                "free_gb": disk.free / 1e9,
                "percent": disk.percent,
            },
            "network": {
                "bytes_sent_mb": net.bytes_sent / 1e6,
                "bytes_recv_mb": net.bytes_recv / 1e6,
                "packets_sent": net.packets_sent,
                "packets_recv": net.packets_recv,
            },
            "gpu": gpu_info,
            "platform": {
                "os": platform.system(),
                "release": platform.release(),
                "machine": platform.machine(),
                "python": platform.python_version(),
            },
        }
    except ImportError:
        return {"error": "psutil not installed"}


@router.get("/config")
async def get_config():
    """Get current backend configuration (no secrets)."""
    from config.settings import settings
    return {
        "version": settings.app_version,
        "debug": settings.debug,
        "offline_mode": settings.offline_mode,
        "llm_server_url": settings.llm_server_url,
        "embedding_model": settings.embedding_model,
        "features": {
            "voice": settings.enable_voice,
            "vision": settings.enable_vision,
            "world_monitor": settings.enable_world_monitor,
        },
    }


@router.get("/devices")
async def list_devices():
    """Discover local network devices via mDNS."""
    devices = []
    try:
        from zeroconf import Zeroconf
        zc = Zeroconf()
        # In production, browse for _cyborg._tcp services
        zc.close()
    except ImportError:
        pass

    return {"devices": devices}


@router.get("/processes")
async def list_processes():
    """List running processes with resource usage."""
    try:
        import psutil
        procs = []
        for p in sorted(
            psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]),
            key=lambda p: p.info.get("cpu_percent", 0) or 0,
            reverse=True,
        )[:20]:
            try:
                mem = p.info.get("memory_info")
                procs.append({
                    "pid": p.info["pid"],
                    "name": p.info["name"],
                    "cpu_percent": round(p.info.get("cpu_percent", 0) or 0, 1),
                    "memory_mb": round(mem.rss / 1e6, 1) if mem else 0,
                })
            except Exception:
                pass
        return {"processes": procs}
    except ImportError:
        return {"processes": []}
