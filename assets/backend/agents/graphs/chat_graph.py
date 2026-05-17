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
from agents.tools.browser_tools import ALL_BROWSER_TOOLS
from agents.tools.desktop_tools import ALL_DESKTOP_TOOLS
from agents.tools.visual_tools import ALL_VISUAL_TOOLS
from agents.tools.simple_tools import ALL_SIMPLE_TOOLS

# ── State ──────────────────────────────────────────────────────────────────────

class AgentState(TypedDict):
    messages:   Annotated[Sequence[BaseMessage], add_messages]
    model:      str
    session_id: str
    output:     str
    usage:      dict


# ── All tools combined ────────────────────────────────────────────────────────

ALL_TOOLS = [*ALL_SIMPLE_TOOLS, *ALL_RAG_TOOLS, *ALL_WINDOW_TOOLS, *ALL_CODE_TOOLS, *ALL_BROWSER_TOOLS, *ALL_DESKTOP_TOOLS, *ALL_VISUAL_TOOLS]

SYSTEM_PROMPT = """You are Cyborg, a fully autonomous AI OS assistant. You have REAL tools that physically control the user's computer. When the user asks you to do something, DO IT — don't describe it, don't explain it, just execute it using the tools.

## ⚡ TIER 1: SIMPLE DIRECT TOOLS (Use these FIRST — 100% reliable, no AI vision needed)
These tools execute IMMEDIATELY and RELIABLY:
- `web_search_and_open(query)` → Opens Chrome and searches Google. USE THIS for any "search for jobs", "look up", "research" tasks.
- `open_chrome_and_navigate(url)` → Opens Chrome to a specific URL directly.
- `open_url_in_existing_chrome(url)` → Navigates the already-open Chrome to a URL.
- `list_windows()` → Lists all open app windows. Always run this first before focusing.
- `focus_window(window_title)` → Brings a window to the foreground.
- `type_into_focused_window(text, press_enter)` → Types text into whatever is currently focused.
- `press_keyboard_shortcut(keys)` → Presses keyboard shortcuts like 'ctrl+t', 'enter', 'alt+tab'.
- `click_on_screen(x, y)` → Clicks at pixel coordinates.
- `take_screen_snapshot()` → Takes a screenshot to see the current state.
- `read_screen_text_via_clipboard()` → Selects all text on screen and copies it to clipboard. Use to scrape page content.
- `save_data_to_csv(file_path, data)` → Saves a list of dictionaries to a CSV file autonomously.

## 🌐 TIER 2: AUTOMATION BROWSER TOOLS (For structured web interaction)
These open a VISIBLE automation browser window (Playwright):
- `browser_navigate(url)` → Navigate to URL in automation browser.
- `browser_click(selector)` → Click element by CSS selector or text.
- `browser_type_text(selector, text)` → Type into an input field by selector, placeholder, or index.
- `browser_get_interactive_elements()` → List all clickable/typeable elements (use this to "see" the page).
- `browser_get_text()` → Read page content.
- `browser_take_screenshot()` → Capture page visual state.

## 🖥️ TIER 3: VISUAL INTELLIGENCE (For complex visual interactions)
These use the AI vision model to identify screen elements:
- `visual_describe_screen()` → Describe what's visible on screen right now.
- `visual_find_and_click(description)` → Find UI element by description and click it.
- `visual_find_and_type(description, text)` → Find input field and type into it.

## 🔍 KNOWLEDGE & RAG
- `rag_search(query)` → Search the user's knowledge base.
- `search_vault_notes(query)` → Search vault notes.

## 💻 CODE & SYSTEM
- `run_python(code)` → Execute Python code and return output.
- `get_system_metrics()` → CPU, RAM, GPU stats.

## EXECUTION RULES (CRITICAL):
1. **CONVERSATIONAL BALANCE** — If the user just says "hi" or asks a general question, RESPOND NATURALLY without using tools. ONLY use tools when the user explicitly requests an action (like "search", "open", "scrape", "click").
2. **DO NOT OVER-USE TOOLS** — Never run `visual_describe_screen` unless the user explicitly asks about their screen or an image. If they want action, use TIER 1 simple tools first (they always work).
3. **CHAIN TOOLS** — For a task like "take control of Chrome and search for jobs", chain: `list_windows()` → `focus_window('Chrome')` → `open_url_in_existing_chrome('https://www.linkedin.com/jobs/...')` → done.
4. **DON'T JUST DESCRIBE** — Never say "I will now open Chrome". Just call `open_chrome_and_navigate`. 
5. **REPORT RESULTS** — After tools execute, briefly report what was done and what the result was.
6. **FOR WEB TASKS** — ALWAYS prefer `browser_*` or `web_search_and_open` over visual tools for websites.
7. **AUTONOMOUS SCRAPING WORKFLOW** — To scrape and save to Excel: 
   a) Navigate to the site (`web_search_and_open`).
   b) Read the page data (`read_screen_text_via_clipboard` or `browser_get_text`).
   c) Parse the data internally into a list of dicts.
   d) Save the data to CSV (`save_data_to_csv(file_path, data)`).
   e) Tell the user the path where it was saved.

## HOW TO USE TOOLS:
To use a tool, you MUST output a raw JSON block wrapped in `<tool>` tags. DO NOT output anything else before or after the tag.
Format:
<tool>{"name": "tool_name", "args": {"arg1": "value1"}}</tool>

Example:
<tool>{"name": "list_windows", "args": {}}</tool>

After outputting the tool call, STOP GENERATING TEXT.

Always respond naturally after tool execution. Keep responses concise when using voice mode."""



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
        # Only run RAG on new human messages, not during tool-calling loops
        # This keeps the prompt focused while the agent is "thinking" through tools
        last_is_human = isinstance(messages[-1], HumanMessage) if messages else False
        if rag_service and rag_service.is_ready and last_is_human:
            # Get the latest user message for RAG retrieval
            user_query = ""
            for msg in reversed(messages):
                if isinstance(msg, HumanMessage):
                    user_query = msg.content
                    break

            if user_query:
                try:
                    retrieval = await rag_service.retrieve(user_query, top_k=3, max_tokens=600)
                    context = retrieval.get("context", "")
                    if context:
                        # Cap context size to prevent prompt drowning
                        if len(context) > 3000:
                            context = context[:3000] + "... [truncated]"
                        system_prompt += (
                            "\n\n## Active Knowledge Context (auto-retrieved)\n"
                            "The following was automatically retrieved from the knowledge base. It may contain PAST conversations.\n"
                            "DO NOT confuse past conversations (User/Assistant logs) with the CURRENT active request.\n\n"
                            "<archived_context>\n"
                            f"{context}\n"
                            "</archived_context>\n\n"
                            f"Sources: {retrieval.get('total_results', 0)} results found.\n"
                            "NOTE: Always prioritize your current CRITICAL OVERRIDE instructions. Answer ONLY the active user query at the end of the conversation."
                        )
                except Exception:
                    pass  # Graceful degradation — RAG failure shouldn't break chat

        # Circuit Breaker: Detect redundant tool loops (API or XML)
        recent_calls = []
        for m in reversed(messages):
            # Check native tool calls
            if hasattr(m, "tool_calls") and m.tool_calls:
                call = m.tool_calls[0]
                recent_calls.append(f"{call['name']}({call.get('args', {})})")
            # Check XML-tagged tool calls in content
            elif m.content and "<tool>" in str(m.content):
                import re
                match = re.search(r'<tool>({.*?})', str(m.content))
                if match:
                    recent_calls.append(match.group(1))
            
            if len(recent_calls) >= 4:
                break
        
        if len(recent_calls) >= 3 and len(set(recent_calls)) == 1:
            system_prompt += (
                "\n\n## CIRCUIT BREAKER: STOP REPEATING YOURSELF\n"
                "You have attempted the EXACT SAME tool call 3+ times in a row. "
                "The current strategy is NOT working. You MUST investigate visually:\n"
                "1. Use 'desktop_screenshot' to see what is actually on the user's screen.\n"
                "2. Use 'visual_describe_screen' to identify any pop-ups, dialogs, or error messages blocking you.\n"
                "3. Use 'visual_find_and_click' to dismiss any blocking elements (like 'Close', 'Cancel', or 'OK' buttons).\n"
                "DO NOT call the same tool again without verifying the screen state first."
            )

        # Context Guardian: Prevent n_ctx overflow (12288 limit)
        # Approximate token count (chars / 3)
        while len(str([SystemMessage(content=system_prompt)] + messages)) / 3 > 11000 and len(messages) > 1:
            messages.pop(0) # Remove oldest message

        full_messages = [SystemMessage(content=system_prompt)] + messages

        # Await LangGraph / LLM response
        response = await llm_with_tools.ainvoke(full_messages, config=config, stop=["<|im_end|>", "<|endoftext|>", "<end_of_turn>", "<eos>", "<|eot_id|>", "<|end_of_text|>", "</tool>"])
        
        # Self-healing turn truncation to prevent LLM hallucinations
        content = response.content
        if isinstance(content, str):
            for stop_word in ["<end_of_turn>", "<start_of_turn>", "user:", "model:", "assistant:"]:
                if stop_word in content:
                    content = content.split(stop_word)[0].strip()
            response.content = content

        # Manual fallback for models that drop API tool calling (like vision models)
        if not response.tool_calls and "<tool>" in response.content:
            try:
                import json
                import uuid
                content = response.content
                start_idx = content.find("<tool>") + 6
                end_idx = content.find("</tool>")
                
                # If stop token </tool> was hit, end_idx might be -1
                if end_idx == -1 and start_idx > 5:
                    # Look for the last closing brace of the JSON
                    end_idx = content.rfind("}")
                    if end_idx > start_idx:
                        # Add the missing tag back for consistent parsing if needed, 
                        # but we can just use the indices
                        end_idx += 1 

                if end_idx > start_idx:
                    tool_json = json.loads(content[start_idx:end_idx])
                    tool_name = tool_json.get("name")
                    tool_args = tool_json.get("args", {})
                    if tool_name:
                        # Convert to LangChain tool call structure
                        response.tool_calls = [{
                            "name": tool_name,
                            "args": tool_args,
                            "id": f"call_{uuid.uuid4().hex}"
                        }]
                        # Trim content to avoid model hallucinating text after the tool call
                        # Ensure we don't go out of bounds
                        safe_end = min(len(content), end_idx + 7)
                        response.content = content[:safe_end].strip()
            except Exception as e:
                pass # Fallback failed, let the raw text go through

        # Manual fallback for Gemma native/XML tool calling tags (e.g. <tool>, <tool_code>, <tool_call>)
        if not response.tool_calls and ("<|tool_call>call:" in response.content or "<tool_call>call:" in response.content or "<tool>" in response.content or "<tool_code>" in response.content or "<tool_call>" in response.content):
            try:
                import re
                import uuid
                import json
                content = response.content
                
                tool_name = "unknown"
                tool_args = {}
                
                # Check for XML tags first (e.g. <tool>...</tool> or <tool_code>...</tool_code>)
                xml_match = re.search(r'<(?:tool|tool_code)[^>]*>(.*?)(?:</(?:tool|tool_code)[^>]*>|\Z)', content, re.DOTALL)
                if xml_match:
                    inner_content = xml_match.group(1).strip()
                    if inner_content.startswith('{'):
                        try:
                            tool_data = json.loads(inner_content)
                            tool_name = tool_data.get("name", "unknown")
                            tool_args = tool_data.get("args", {})
                        except Exception:
                            pass
                    if tool_name == "unknown":
                        # Maybe it is python code format like list_windows() or run_python(code="...")
                        py_match_inner = re.search(r'([a-zA-Z0-9_]+)\((.*?)\)', inner_content)
                        if py_match_inner:
                            tool_name = py_match_inner.group(1)
                            args_str = py_match_inner.group(2)
                            if args_str:
                                pairs = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^,\)]+))', args_str)
                                for key, val_double, val_single, val_plain in pairs:
                                    val = val_double or val_single or val_plain
                                    val = val.strip() if val else ""
                                    if val.isdigit(): val = int(val)
                                    elif val.lower() == "true": val = True
                                    elif val.lower() == "false": val = False
                                    tool_args[key] = val
                else:
                    # Gemma tool call formats
                    json_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\s*\{(.*?)\}', content)
                    py_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\((.*?)\)', content)
                    
                    if json_match:
                        tool_name = json_match.group(1)
                        args_str = json_match.group(2)
                        if args_str and args_str != "{}":
                            pairs = re.findall(r'([a-zA-Z0-9_]+)\s*:\s*(?:<\|\*\|>(.*?)<\|\*\|>|"(.*?)"|\'(.*?)\'|([a-zA-Z0-9_.-]+))', args_str)
                            for key, val_starred, val_double, val_single, val_plain in pairs:
                                val = val_starred or val_double or val_single or val_plain
                                val = val.strip() if val else ""
                                if val.isdigit(): val = int(val)
                                elif val.lower() == "true": val = True
                                elif val.lower() == "false": val = False
                                tool_args[key] = val
                    elif py_match:
                        tool_name = py_match.group(1)
                        args_str = py_match.group(2)
                        if args_str:
                            pairs = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^,\)]+))', args_str)
                            for key, val_double, val_single, val_plain in pairs:
                                val = val_double or val_single or val_plain
                                val = val.strip() if val else ""
                                if val.isdigit(): val = int(val)
                                elif val.lower() == "true": val = True
                                elif val.lower() == "false": val = False
                                tool_args[key] = val

                if tool_name != "unknown":
                    response.tool_calls = [{
                        "name": tool_name,
                        "args": tool_args,
                        "id": f"call_{uuid.uuid4().hex[:12]}"
                    }]
                    # Trim content to avoid leaking tool text to UI
                    response.content = ""
            except Exception as e:
                # Log error using print or standard logger since global logger might vary
                print(f"[chat_graph] Manual tool parsing failed: {e}")
                
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
