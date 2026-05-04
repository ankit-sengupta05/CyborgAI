"""CodeFlow API Routes"""
from fastapi import APIRouter, Request
from pydantic import BaseModel
from services.codeflow_service import CodeFlowService
from services.llm_service import LLMService

router = APIRouter()


class AnalyzeRequest(BaseModel):
    path: str


class ExplainRequest(BaseModel):
    file_path: str


@router.post("/analyze")
async def analyze(data: AnalyzeRequest, request: Request):
    svc: CodeFlowService = request.app.state.codeflow_service
    return await svc.analyze_project(data.path)


@router.get("/file")
async def get_file(path: str, request: Request):
    svc: CodeFlowService = request.app.state.codeflow_service
    return await svc.get_file_content(path)


@router.post("/explain")
async def explain(data: ExplainRequest, request: Request):
    svc: CodeFlowService = request.app.state.codeflow_service
    llm: LLMService = request.app.state.llm_service
    explanation = await svc.explain_file(data.file_path, llm)
    return {"explanation": explanation}
