"""
Health Track Module Initialization
MedGemma 4B integration for medical imaging analysis
"""

from .medgemma.inference import MedGemmaPipeline
from .medgemma.prompts import MEDICAL_PROMPTS, get_prompt, get_disclaimer
from .medgemma.ehr_functions import (
    EHR_FUNCTIONS,
    EHRFunctionCaller,
    MedicalFunctionGuard,
    execute_ehr_functions
)

__all__ = [
    # Inference
    "MedGemmaPipeline",
    
    # Prompts
    "MEDICAL_PROMPTS",
    "get_prompt",
    "get_disclaimer",
    
    # EHR Integration
    "EHR_FUNCTIONS",
    "EHRFunctionCaller",
    "MedicalFunctionGuard",
    "execute_ehr_functions"
]

# Version info
__version__ = "1.0.0"
__author__ = "Cyborg AGI Team"
