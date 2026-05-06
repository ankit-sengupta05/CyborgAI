import asyncio
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from pydantic import BaseModel, Field

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

async def run():
    try:
        print("Starting stream...")
        async for chunk in llm_with_tools.astream([HumanMessage(content="What's the weather in SF?")]):
            print(f"Chunk: {chunk}")
        print("Done")
    except Exception as e:
        print(f"Error: {e}")

asyncio.run(run())
