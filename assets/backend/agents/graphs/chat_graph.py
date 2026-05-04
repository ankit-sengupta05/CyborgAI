"""
LangGraph Chat Agent — ReAct with tool use.
Compatible with: langchain 1.x + langchain-openai 1.x + openai 2.x + langgraph 1.x
"""
from __future__ import annotations
from typing import TypedDict, Annotated, Sequence
import operator
import os

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from config.settings import settings
from agents.tools.code_tools import ALL_CODE_TOOLS


# ── State ──────────────────────────────────────────────────────────────────────

class AgentState(TypedDict):
    messages:   Annotated[Sequence[BaseMessage], operator.add]
    model:      str
    session_id: str
    output:     str
    usage:      dict


# ── Knowledge base search tool ────────────────────────────────────────────────

@tool
def search_knowledge_base(query: str) -> str:
    """Search the local knowledge base for information about a topic."""
    return (
        f"[KB Search: '{query}']\n"
        "Ingest documents via the Knowledge Graph tab to populate results."
    )


ALL_TOOLS = [search_knowledge_base, *ALL_CODE_TOOLS]

SYSTEM_PROMPT = """You are Cyborg, a local-first AI assistant running entirely on the user's device.
You are private, offline-capable, and have access to:
- search_knowledge_base: semantic search over ingested documents
- run_python: execute Python code safely
- read_file / write_file: read and write local files
- list_directory: browse the local filesystem
- get_system_info: current hardware stats

Think step-by-step. Use markdown code blocks. Be concise and accurate."""


# ── Build graph ───────────────────────────────────────────────────────────────

def build_chat_graph(llm_service):
    """Build ReAct agent. Works with langchain-openai 1.x and openai 2.x."""

    # Set a dummy key to prevent openai client from requiring OPENAI_API_KEY env var
    os.environ.setdefault("OPENAI_API_KEY", "not-needed")

    llm = ChatOpenAI(
        openai_api_base=settings.llm_server_url,   # langchain-openai 1.x param name
        openai_api_key="not-needed",                # explicit, avoids env-var lookup
        model_name=llm_service.current_model or "local-model",
        request_timeout=120,
    )

    llm_with_tools = llm.bind_tools(ALL_TOOLS)
    tool_node = ToolNode(ALL_TOOLS)

    async def agent_node(state: AgentState) -> dict:
        messages = [SystemMessage(content=SYSTEM_PROMPT)] + list(state["messages"])
        try:
            response = await llm_with_tools.ainvoke(messages)
        except Exception:
            last = state["messages"][-1] if state["messages"] else HumanMessage(content="Hello")
            text = await llm_service.complete(getattr(last, "content", str(last)))
            response = AIMessage(content=text)
        return {"messages": [response], "output": response.content}

    def should_continue(state: AgentState) -> str:
        last = state["messages"][-1]
        if hasattr(last, "tool_calls") and last.tool_calls:
            return "tools"
        return END

    workflow = StateGraph(AgentState)
    workflow.add_node("agent", agent_node)
    workflow.add_node("tools", tool_node)
    workflow.set_entry_point("agent")
    workflow.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
    workflow.add_edge("tools", "agent")
    return workflow.compile()
