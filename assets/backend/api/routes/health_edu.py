"""
Health & Education API Routes
Gemma 4 multimodal endpoints for X-ray analysis, EHR, homework grading, and quiz generation
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import JSONResponse
from typing import Optional, Dict, Any, List
import os
import tempfile
import shutil
from datetime import datetime

router = APIRouter()

# Import health services
try:
    from ..services.health.inference import MedGemmaPipeline
    from ..services.health.ehr_functions import EHRFunctionCaller
    HEALTH_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ Health services not available: {e}")
    HEALTH_AVAILABLE = False
    MedGemmaPipeline = None
    EHRFunctionCaller = None

# Import education services
try:
    from ..services.education.grader import HomeworkGrader
    from ..services.education.quiz_generator import QuizGenerator as AdaptiveQuizGenerator
    from ..services.education.progress_tracker import ProgressTracker
    EDUCATION_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ Education services not available: {e}")
    EDUCATION_AVAILABLE = False
    HomeworkGrader = None
    AdaptiveQuizGenerator = None
    ProgressTracker = None


# ============================================================================
# HEALTH TRACK ENDPOINTS
# ============================================================================

@router.get("/health/status")
async def get_health_status():
    """Check health service availability"""
    return {
        "available": HEALTH_AVAILABLE,
        "services": {
            "xray_analysis": HEALTH_AVAILABLE,
            "ehr_assistant": HEALTH_AVAILABLE
        }
    }


@router.post("/health/analyze-xray")
async def analyze_xray(
    image: UploadFile = File(..., description="Chest X-ray image (PNG/JPG)"),
    age: Optional[int] = Form(None, description="Patient age"),
    symptoms: Optional[str] = Form(None, description="Comma-separated symptoms"),
    language: Optional[str] = Form("en", description="Language code (en, es, hi)")
):
    """
    Analyze chest X-ray using MedGemma 4B

    Returns structured analysis with:
    - Findings and confidence levels
    - Plain-language explanation
    - Risk factors
    - Recommendations
    - Medical disclaimer
    """
    if not HEALTH_AVAILABLE:
        raise HTTPException(status_code=503, detail="Health services not initialized")

    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(image.filename)[1]) as tmp:
            shutil.copyfileobj(image.file, tmp)
            tmp_path = tmp.name

        try:
            # Initialize pipeline
            pipeline = MedGemmaPipeline.get_instance()

            # Build patient context
            patient_context = {}
            if age:
                patient_context["age"] = age
            if symptoms:
                patient_context["symptoms"] = [s.strip() for s in symptoms.split(",")]
            if language:
                patient_context["language"] = language

            # Run analysis
            result = pipeline.analyze_xray(tmp_path, patient_context=patient_context)

            # Add metadata
            result["timestamp"] = datetime.utcnow().isoformat()
            result["image_name"] = image.filename
            result["language"] = language

            return JSONResponse(content=result)

        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")


@router.post("/health/ehr/query")
async def query_ehr(
    patient_id: str = Form(..., description="Patient ID"),
    query_type: str = Form("summary", description="Query type: summary, labs, meds, allergies"),
    date_range: Optional[str] = Form(None, description="Date range (YYYY-MM-DD to YYYY-MM-DD)")
):
    """
    Query EHR system using function calling
    Supports FHIR-compatible data retrieval
    """
    if not HEALTH_AVAILABLE:
        raise HTTPException(status_code=503, detail="Health services not initialized")

    try:
        ehr_caller = EHRFunctionCaller.get_instance()

        result = await ehr_caller.query_patient_data(
            patient_id=patient_id,
            query_type=query_type,
            date_range=date_range
        )

        return JSONResponse(content={
            "success": True,
            "data": result,
            "timestamp": datetime.utcnow().isoformat()
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"EHR query failed: {str(e)}")


@router.post("/health/ehr/update")
async def update_ehr(
    patient_id: str = Form(...),
    update_type: str = Form(..., description="Type of update: note, lab_result, prescription"),
    data: str = Form(..., description="JSON-encoded update data")
):
    """
    Update EHR with new clinical data
    Includes safety validation and audit logging
    """
    if not HEALTH_AVAILABLE:
        raise HTTPException(status_code=503, detail="Health services not initialized")

    try:
        import json
        ehr_caller = EHRFunctionCaller.get_instance()

        data_dict = json.loads(data)

        result = await ehr_caller.update_patient_record(
            patient_id=patient_id,
            update_type=update_type,
            data=data_dict
        )

        return JSONResponse(content={
            "success": True,
            "record_id": result.get("record_id"),
            "timestamp": datetime.utcnow().isoformat()
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"EHR update failed: {str(e)}")


# ============================================================================
# EDUCATION TRACK ENDPOINTS
# ============================================================================

@router.get("/education/status")
async def get_education_status():
    """Check education service availability"""
    return {
        "available": EDUCATION_AVAILABLE,
        "services": {
            "homework_grader": EDUCATION_AVAILABLE,
            "quiz_generator": EDUCATION_AVAILABLE,
            "progress_tracker": EDUCATION_AVAILABLE
        }
    }


@router.post("/education/grade-homework")
async def grade_homework(
    image: UploadFile = File(..., description="Homework image (PNG/JPG)"),
    subject: str = Form(..., description="Subject: math, science, english, history"),
    grade_level: int = Form(..., description="Grade level (1-12)"),
    rubric: Optional[str] = Form(None, description="Custom grading rubric (JSON)"),
    language: Optional[str] = Form("en", description="Language: en, es, hi")
):
    """
    Grade homework using OCR + adaptive evaluation
    Supports multiple subjects and languages
    """
    if not EDUCATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Education services not initialized")

    try:
        # Save uploaded file
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(image.filename)[1]) as tmp:
            shutil.copyfileobj(image.file, tmp)
            tmp_path = tmp.name

        try:
            grader = HomeworkGrader.get_instance()

            # Parse rubric if provided
            rubric_dict = None
            if rubric:
                import json
                rubric_dict = json.loads(rubric)

            # Grade homework
            result = await grader.grade_submission(
                image_path=tmp_path,
                subject=subject,
                grade_level=grade_level,
                rubric=rubric_dict,
                language=language
            )

            result["timestamp"] = datetime.utcnow().isoformat()
            result["image_name"] = image.filename

            return JSONResponse(content=result)

        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Grading failed: {str(e)}")


@router.post("/education/generate-quiz")
async def generate_quiz(
    topic: str = Form(..., description="Quiz topic"),
    grade_level: int = Form(..., description="Grade level (1-12)"),
    num_questions: int = Form(5, description="Number of questions (1-20)"),
    question_types: Optional[str] = Form("multiple_choice", description="Comma-separated types"),
    cultural_context: Optional[str] = Form(None, description="Cultural context for relevance"),
    language: Optional[str] = Form("en", description="Language: en, es, hi")
):
    """
    Generate adaptive quiz with cultural relevance
    Questions adapt to student's performance history
    """
    if not EDUCATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Education services not initialized")

    try:
        generator = AdaptiveQuizGenerator.get_instance()

        # Parse question types
        types = [t.strip() for t in question_types.split(",")] if question_types else ["multiple_choice"]

        quiz = await generator.generate_quiz(
            topic=topic,
            grade_level=grade_level,
            num_questions=num_questions,
            question_types=types,
            cultural_context=cultural_context,
            language=language
        )

        return JSONResponse(content={
            "success": True,
            "quiz": quiz,
            "timestamp": datetime.utcnow().isoformat()
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {str(e)}")


@router.get("/education/progress/{student_id}")
async def get_student_progress(student_id: str):
    """Get student progress and learning path recommendations"""
    if not EDUCATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Education services not initialized")

    try:
        tracker = ProgressTracker.get_instance()

        progress = await tracker.get_progress(student_id)
        recommendations = await tracker.get_learning_path(student_id)

        return JSONResponse(content={
            "success": True,
            "progress": progress,
            "recommendations": recommendations,
            "timestamp": datetime.utcnow().isoformat()
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Progress retrieval failed: {str(e)}")


@router.post("/education/track-submission")
async def track_submission(
    student_id: str = Form(...),
    quiz_id: str = Form(...),
    answers: str = Form(..., description="JSON-encoded answers"),
    score: float = Form(...),
    time_spent: int = Form(..., description="Time spent in seconds")
):
    """Track quiz submission and update progress"""
    if not EDUCATION_AVAILABLE:
        raise HTTPException(status_code=503, detail="Education services not initialized")

    try:
        import json
        tracker = ProgressTracker.get_instance()

        answers_dict = json.loads(answers)

        await tracker.record_submission(
            student_id=student_id,
            quiz_id=quiz_id,
            answers=answers_dict,
            score=score,
            time_spent=time_spent
        )

        return JSONResponse(content={
            "success": True,
            "message": "Submission tracked successfully",
            "timestamp": datetime.utcnow().isoformat()
        })

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Tracking failed: {str(e)}")


# ============================================================================
# DEMO HELPER ENDPOINTS
# ============================================================================

@router.get("/health/demo-config")
async def get_health_demo_config():
    """Get configuration for health demo UI"""
    return {
        "supported_languages": ["en", "es", "hi"],
        "supported_symptoms": [
            "cough", "fever", "shortness of breath", "chest pain",
            "fatigue", "wheezing", "night sweats"
        ],
        "age_range": {"min": 0, "max": 120},
        "disclaimer": "⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice."
    }


@router.get("/education/demo-config")
async def get_education_demo_config():
    """Get configuration for education demo UI"""
    return {
        "supported_languages": ["en", "es", "hi"],
        "subjects": ["math", "science", "english", "history", "geography"],
        "grade_levels": list(range(1, 13)),
        "question_types": [
            "multiple_choice", "true_false", "short_answer",
            "matching", "fill_in_blank"
        ],
        "cultural_contexts": [
            "urban india", "rural india", "us city", "us rural",
            "latin america", "southeast asia", "africa"
        ]
    }
