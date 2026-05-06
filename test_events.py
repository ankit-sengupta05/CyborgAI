import asyncio
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from pydantic import BaseModel, Field
from langgraph.graph import StateGraph, END
from langchain_core.runnables import RunnableConfig
from typing import TypedDict, Annotated, Sequence
import operator

llm = ChatOpenAI(
    openai_api_base="http://127.0.0.1:8765/api/v1",
    openai_api_key="not-needed",
    model_name="local-model",
    request_timeout=120,
    streaming=True,
)

class GetWeather(BaseModel):
    """Get the current weather in a given location"""
    location: str = Field(description="The city and state, e.g. San Francisco, CA")

llm_with_tools = llm.bind_tools([GetWeather])

class AgentState(TypedDict):
    messages: Annotated[Sequence[dict], operator.add]

async def agent_node(state: AgentState, config: RunnableConfig):
    response = await llm_with_tools.ainvoke(state["messages"], config)
    return {"messages": [response]}

workflow = StateGraph(AgentState)
workflow.add_node("agent", agent_node)
workflow.set_entry_point("agent")
workflow.add_edge("agent", END)
graph = workflow.compile()

async def run():
    print("Starting astream_events...")
    async for event in graph.astream_events({"messages": [HumanMessage(content="What is the weather?")]}, version="v2"):
        kind = event["event"]
        if kind == "on_chat_model_stream":
            chunk = event["data"]["chunk"]
            print(f"Token: '{chunk.content}'")

asyncio.run(run())
