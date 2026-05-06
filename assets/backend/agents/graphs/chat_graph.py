"""
LangGraph Chat Agent — RAG-powered ReAct with cross-window tools.

Compatible with: langchain 1.x + langchain-openai 1.x + openai 2.x + langgraph 1.x

This agent:
- Uses Active RAG for knowledge-augmented responses
- Can route to World Monitor, MiroFish, Vault, and other windows
- Supports dynamic skill creation and execution
- Manages conversation context with token awareness
"""
from __future__ import annotations
from typing import TypedDict, Annotated, Sequence
import os
from langgraph.graph.message import add_messages

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableConfig
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode

from config.settings import settings
from agents.tools.code_tools import ALL_CODE_TOOLS
from agents.tools.rag_tools import ALL_RAG_TOOLS
from agents.tools.window_tools import ALL_WINDOW_TOOLS


# ── State ──────────────────────────────────────────────────────────────────────

class AgentState(TypedDict):
    messages:   Annotated[Sequence[BaseMessage], add_messages]
    model:      str
    session_id: str
    output:     str
    usage:      dict


# ── All tools combined ────────────────────────────────────────────────────────

ALL_TOOLS = [*ALL_RAG_TOOLS, *ALL_WINDOW_TOOLS, *ALL_CODE_TOOLS]

SYSTEM_PROMPT = """You are Cyborg, a local-first AI OS assistant running entirely on the user's device.
You are private, offline-capable, and have access to these capabilities:

## Knowledge & RAG
- rag_search: Hybrid search over the user's knowledge base (embeddings + graph + vault)
- get_graph_context: Detailed entity lookup with relationships from the knowledge graph
- search_knowledge_graph: Direct semantic search over knowledge graph nodes
- search_vault_notes: Search the user's markdown vault notes

## World Awareness
- get_world_news: Current news headlines by category
- get_system_metrics: CPU, RAM, GPU, disk stats

## Document Generation
- generate_report_mirofish: Generate reports/documents via MiroFish

## Skills & Automation
- list_available_skills: See what automation skills are available
- execute_skill: Run an existing skill
- create_new_skill: Auto-create a new skill when needed (generates, tests, debugs automatically)

## Code & Files
- run_python: Execute Python code
- read_file / write_file: File I/O
- list_directory: Browse filesystem
- get_system_info: Hardware info

## How to handle requests:
1. For knowledge questions → Use rag_search first, then get_graph_context for deeper context
2. For news/current events → Use get_world_news, interpret the data naturally
3. For automation tasks → Check list_available_skills first, then execute_skill or create_new_skill
4. For reports → Use generate_report_mirofish
5. For code tasks → Use run_python

Always respond naturally and conversationally. When using voice mode, keep responses concise.
Use markdown for structured responses. Cite knowledge sources when available."""


# ── Build graph ───────────────────────────────────────────────────────────────

def build_chat_graph(llm_service, rag_service=None):
    """Build RAG-powered ReAct agent with cross-window intelligence.

    Args:
        llm_service: LLMService instance for inference.
        rag_service: Optional RAGService for context augmentation.
    """
    # Set a dummy key to prevent openai client from requiring OPENAI_API_KEY env var
    os.environ.setdefault("OPENAI_API_KEY", "not-needed")

    llm = ChatOpenAI(
        openai_api_base=f"http://{settings.host}:{settings.port}/api/v1",
        openai_api_key="not-needed",
        model_name=llm_service.current_model or "local-model",
        request_timeout=120,
        streaming=True,
    )

    llm_with_tools = llm.bind_tools(ALL_TOOLS)
    tool_node = ToolNode(ALL_TOOLS)

    async def agent_node(state: AgentState, config: RunnableConfig) -> dict:
        """Main agent node — augments with RAG context before calling LLM."""
        messages = list(state["messages"])

        # Inject RAG context into system prompt if available
        system_prompt = SYSTEM_PROMPT
        if rag_service and rag_service.is_ready:
            # Get the latest user message for RAG retrieval
            user_query = ""
            for msg in reversed(messages):
                if isinstance(msg, HumanMessage):
                    user_query = msg.content
                    break

            if user_query:
                try:
                    retrieval = await rag_service.retrieve(user_query, top_k=5, max_tokens=1000)
                    context = retrieval.get("context", "")
                    if context:
                        system_prompt += (
                            "\n\n## Active Knowledge Context (auto-retrieved)\n"
                            "The following was automatically retrieved from the knowledge base:\n\n"
                            f"{context}\n\n"
                            f"Sources: {retrieval.get('total_results', 0)} results found."
                        )
                except Exception:
                    pass  # Graceful degradation — RAG failure shouldn't break chat

        full_messages = [SystemMessage(content=system_prompt)] + messages

        # Await LangGraph / LLM response
        response = await llm_with_tools.ainvoke(full_messages, config=config)
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
