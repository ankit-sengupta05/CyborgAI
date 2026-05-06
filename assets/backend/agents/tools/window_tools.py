"""
Window Tools — Cross-window intelligence for the chat agent.

These tools allow the chat to route actions to other CyborgAI windows:
- World Monitor: news, metrics, briefings
- MiroFish: document generation and report creation
- Vault: knowledge base search
- Devices: device management
- Health: health tracking data
- Skills: skill execution
"""
import structlog
from langchain_core.tools import tool

log = structlog.get_logger(__name__)

# Global references set during app startup
_app_state = None


def set_app_state(state):
    """Called during app startup to inject FastAPI app.state."""
    global _app_state
    _app_state = state


@tool
def search_knowledge_graph(query: str) -> str:
    """Search the knowledge graph for information about a topic.
    Use this to find relevant documents, concepts, and relationships
    from the user's ingested knowledge base."""
    import asyncio

    if not _app_state:
        return "Knowledge graph not available."

    try:
        graph_svc = _app_state.graph_service
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, graph_svc.search(query, limit=5))
                results = future.result(timeout=10)
        else:
            results = asyncio.run(graph_svc.search(query, limit=5))

        if not results:
            return f"No results found for '{query}' in knowledge graph."

        output = f"Knowledge Graph results for '{query}':\n\n"
        for r in results[:5]:
            label = r.get("label", "Unknown")
            content = r.get("content", "")[:300]
            score = r.get("score", 0)
            output += f"• [{score:.2f}] **{label}**: {content}\n\n"
        return output

    except Exception as e:
        return f"Knowledge graph search error: {e}"


@tool
def get_world_news(category: str = "all") -> str:
    """Get current world news and headlines. Use this when the user asks
    about news, current events, or world happenings.
    Categories: all, technology, science, business, health, sports, politics"""
    import asyncio

    if not _app_state:
        return "World monitor not available."

    try:
        svc = _app_state.world_monitor_service
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, svc.get_news(category=category))
                news = future.result(timeout=15)
        else:
            news = asyncio.run(svc.get_news(category=category))

        if not news:
            return f"No news available for category '{category}'."

        output = f"Latest {category} news:\n\n"
        for article in news[:8]:
            title = article.get("title", "")
            source = article.get("source", "")
            desc = article.get("description", "")[:150]
            output += f"📰 **{title}** ({source})\n{desc}\n\n"
        return output

    except Exception as e:
        return f"World monitor error: {e}"


@tool
def get_system_metrics() -> str:
    """Get current system performance metrics (CPU, RAM, GPU, disk).
    Use when the user asks about system status or performance."""
    import asyncio

    if not _app_state:
        return "System metrics not available."

    try:
        svc = _app_state.world_monitor_service
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, svc.get_system_metrics())
                metrics = future.result(timeout=5)
        else:
            metrics = asyncio.run(svc.get_system_metrics())

        return f"System Metrics:\n{_format_metrics(metrics)}"
    except Exception as e:
        return f"Metrics error: {e}"


@tool
def search_vault_notes(query: str) -> str:
    """Search the user's vault (markdown notes) for information.
    Use this to find specific notes, documents, or saved information."""
    import asyncio

    if not _app_state:
        return "Vault not available."

    try:
        svc = _app_state.vault_service
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, svc.search_notes(query, limit=5))
                results = future.result(timeout=10)
        else:
            results = asyncio.run(svc.search_notes(query, limit=5))

        if not results:
            return f"No vault notes found for '{query}'."

        output = f"Vault results for '{query}':\n\n"
        for note in results[:5]:
            title = note.get("title", "Untitled")
            content = note.get("content", "")[:200]
            output += f"📝 **{title}**\n{content}\n\n"
        return output

    except Exception as e:
        return f"Vault search error: {e}"


@tool
def generate_report_mirofish(task: str, context: str = "") -> str:
    """Generate a report or document using MiroFish.
    Use this when the user needs document generation, report writing,
    or structured output based on data analysis.

    Args:
        task: Description of the report to generate.
        context: Additional context or data for the report.
    """
    if not _app_state:
        return "MiroFish not available."

    return (
        f"📄 MiroFish Report Task queued:\n"
        f"Task: {task}\n"
        f"Context: {context[:200] if context else 'None provided'}\n\n"
        f"To generate this report, please open the MiroFish tab from the sidebar "
        f"and use the document generation feature with the above task."
    )


@tool
def execute_skill(skill_name: str, parameters: str = "{}") -> str:
    """Execute a registered skill by name. Use this when the user asks
    to perform a task that matches an existing skill.

    Args:
        skill_name: Name of the skill to execute.
        parameters: JSON string of parameters to pass.
    """
    import asyncio
    import json

    if not _app_state or not hasattr(_app_state, "skills_service"):
        return "Skills service not available."

    try:
        params = json.loads(parameters) if parameters else {}
        svc = _app_state.skills_service

        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, svc.execute_skill(skill_name, params))
                result = future.result(timeout=60)
        else:
            result = asyncio.run(svc.execute_skill(skill_name, params))

        if result.get("success"):
            return f"✅ Skill '{skill_name}' executed successfully:\n{result.get('output', '')}"
        else:
            return f"❌ Skill '{skill_name}' failed: {result.get('error', 'Unknown error')}"

    except Exception as e:
        return f"Skill execution error: {e}"


@tool
def list_available_skills() -> str:
    """List all available skills that can be executed.
    Use this to see what capabilities are available."""
    if not _app_state or not hasattr(_app_state, "skills_service"):
        return "Skills service not available."

    skills = _app_state.skills_service.get_all_skills()
    if not skills:
        return "No skills registered yet. Skills can be auto-created when needed."

    output = "Available Skills:\n\n"
    for s in skills:
        status = "✅" if s.get("is_active") else "❌"
        output += f"{status} **{s['name']}** — {s.get('description', '')}\n"
        output += f"   Usage: `{s.get('usage', '')}`\n\n"
    return output


@tool
def create_new_skill(task_description: str) -> str:
    """Create a new skill dynamically when no existing skill matches.
    The system will generate, test, debug, and register the skill automatically.

    Args:
        task_description: What the skill should do. Be specific and general-purpose.
    """
    import asyncio

    if not _app_state or not hasattr(_app_state, "skills_service"):
        return "Skills service not available."

    try:
        svc = _app_state.skills_service

        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, svc.create_skill(task_description))
                result = future.result(timeout=120)
        else:
            result = asyncio.run(svc.create_skill(task_description))

        result_dict = result.to_dict()
        if result_dict.get("success"):
            skill = result_dict.get("skill", {})
            return (
                f"✅ New skill created: **{skill.get('name', '')}**\n"
                f"Description: {skill.get('description', '')}\n"
                f"Usage: `{skill.get('usage', '')}`\n"
                f"Debug iterations: {result_dict.get('iterations', 0)}\n\n"
                f"The skill is now registered and ready to use."
            )
        else:
            log_text = "\n".join(result_dict.get("debug_log", []))
            return f"❌ Skill creation failed: {result_dict.get('error', '')}\nLog:\n{log_text}"

    except Exception as e:
        return f"Skill creation error: {e}"


def _format_metrics(metrics: dict) -> str:
    """Format system metrics dict into readable string."""
    parts = []
    cpu = metrics.get("cpu", {})
    if cpu:
        parts.append(f"CPU: {cpu.get('percent', 0):.1f}% ({cpu.get('cores', '?')} cores)")
    mem = metrics.get("memory", {})
    if mem:
        used = mem.get("used_gb", 0)
        total = mem.get("total_gb", 0)
        parts.append(f"RAM: {used:.1f}/{total:.1f} GB ({mem.get('percent', 0):.0f}%)")
    gpu = metrics.get("gpu", {})
    if gpu:
        parts.append(f"GPU: {gpu.get('name', 'N/A')} — {gpu.get('utilization', 0)}%")
    disk = metrics.get("disk", {})
    if disk:
        parts.append(f"Disk: {disk.get('used_gb', 0):.0f}/{disk.get('total_gb', 0):.0f} GB")
    return "\n".join(parts) if parts else str(metrics)


# Collect all window tools
ALL_WINDOW_TOOLS = [
    search_knowledge_graph,
    get_world_news,
    get_system_metrics,
    search_vault_notes,
    generate_report_mirofish,
    execute_skill,
    list_available_skills,
    create_new_skill,
]
