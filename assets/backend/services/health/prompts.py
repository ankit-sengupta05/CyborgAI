"""
Medical prompt templates for MedGemma 4B
Plain-language explanations and clinical summaries
"""

MEDICAL_PROMPTS = {
    "xray_explain_simple": """
You are a compassionate medical assistant. Analyze this chest X-ray and explain to a patient:

1. What you see in simple terms (avoid jargon)
2. Possible conditions this might indicate (with confidence levels)
3. Risk factors the patient should know about
4. Recommended next steps (when to see a doctor, tests to ask about)

IMPORTANT: Always include: "This is not a diagnosis. Please consult a healthcare professional for medical advice."

Patient context: {patient_context}
Image analysis: {visual_description}
""",

    "xray_clinical": """
Clinical Chest X-Ray Analysis Report

PATIENT INFORMATION:
- Age: {age}
- Presenting Symptoms: {symptoms}
- Clinical Indication: {indication}

RADIOLOGIC FINDINGS:
{findings}

IMPRESSION:
{impression}

DIFFERENTIAL DIAGNOSIS:
{differential}

RECOMMENDATIONS:
{recommendations}

---
DISCLAIMER: This AI-generated report is for educational and decision-support purposes only. 
It does not constitute a medical diagnosis. A qualified radiologist or physician must review 
all imaging and clinical data before making diagnostic or treatment decisions.
""",

    "ehr_function_call": """
Based on the clinical findings, determine if any EHR functions should be called.
Available functions: {available_functions}

Respond in JSON format:
{{
  "functions_to_call": [
    {{"name": "function_name", "parameters": {{...}}}}
  ],
  "reasoning": "Brief explanation"
}}
""",

    "drug_interaction_check": """
Review the following medications for potential interactions:

Current Medications: {current_meds}
Proposed Medication: {proposed_med}

Provide:
1. Interaction risk level (None/Low/Moderate/High/Contraindicated)
2. Mechanism of interaction (if any)
3. Clinical recommendations
4. Alternative suggestions if needed

Format as structured JSON.
""",

    "patient_education_plain": """
Explain the following medical condition in simple, accessible language suitable for a patient with limited medical knowledge:

Condition: {condition}
Key Points to Cover: {key_points}
Language Level: {language_level}  # e.g., "5th grade reading level", "ESL-friendly"

Use:
- Simple words and short sentences
- Analogies from everyday life
- Clear action steps
- Reassuring but honest tone

Avoid medical jargon. If technical terms are necessary, define them immediately.
"""
}


# Confidence level descriptions
CONFIDENCE_LEVELS = {
    "high": {
        "range": "86-100%",
        "description": "Strong evidence supports this finding",
        "color": "#10b981"  # Green
    },
    "medium": {
        "range": "61-85%",
        "description": "Moderate evidence; clinical correlation recommended",
        "color": "#f59e0b"  # Amber
    },
    "low": {
        "range": "0-60%",
        "description": "Limited evidence; further evaluation needed",
        "color": "#ef4444"  # Red
    }
}


# Medical disclaimer templates
DISCLAIMERS = {
    "short": "⚠️ This is not a diagnosis. Please consult a healthcare professional.",
    
    "standard": """⚠️ IMPORTANT: This AI assistance provides information and suggestions only. 
It is NOT a substitute for professional medical advice, diagnosis, or treatment. 
Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.""",
    
    "emergency": """🚨 If you think you may have a medical emergency, call your doctor or emergency services immediately. 
This AI tool cannot diagnose emergencies or provide urgent care guidance."""
}


def get_prompt(template_name: str, **kwargs) -> str:
    """
    Get a formatted prompt template
    
    Args:
        template_name: Name of the template from MEDICAL_PROMPTS
        **kwargs: Variables to fill in the template
        
    Returns:
        Formatted prompt string
    """
    template = MEDICAL_PROMPTS.get(template_name)
    if not template:
        raise ValueError(f"Unknown template: {template_name}")
    
    return template.format(**kwargs)


def get_disclaimer(level: str = "standard") -> str:
    """Get disclaimer by level"""
    return DISCLAIMERS.get(level, DISCLAIMERS["standard"])


def format_confidence(confidence_pct: float) -> dict:
    """
    Format confidence percentage into structured info
    
    Returns dict with level, description, and color
    """
    if confidence_pct >= 86:
        level_info = CONFIDENCE_LEVELS["high"]
    elif confidence_pct >= 61:
        level_info = CONFIDENCE_LEVELS["medium"]
    else:
        level_info = CONFIDENCE_LEVELS["low"]
    
    return {
        "percentage": confidence_pct,
        "level": level_info["range"].split('-')[0],
        "description": level_info["description"],
        "color": level_info["color"]
    }
