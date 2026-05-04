"""
Medical Function Safety Guard
Prevents unsafe EHR function calls and sanitizes hallucinated medical advice
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class MedicalFunctionGuard:
    """
    Safety layer for EHR function calling.
    Validates function names, parameters, and sanitizes outputs.
    """

    ALLOWED_FUNCTIONS = {
        "get_patient_history",
        "check_drug_interactions",
        "schedule_followup",
        "get_lab_results",
        "get_allergies",
        "get_current_medications",
    }

    BLACKLISTED_TERMS = [
        "diagnose", "prescribe", "cure", "guarantee",
        "will heal", "definitive diagnosis", "100% certain",
    ]

    REQUIRED_DISCLAIMER = (
        "⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice."
    )

    @classmethod
    def validate_function_call(cls, function_name: str, parameters: dict) -> tuple[bool, str]:
        """
        Validate a proposed EHR function call.

        Returns:
            (is_valid, reason)
        """
        if function_name not in cls.ALLOWED_FUNCTIONS:
            return False, f"Function '{function_name}' is not in allowed set: {cls.ALLOWED_FUNCTIONS}"

        # Validate required parameters per function
        required = {
            "get_patient_history":       ["patient_id"],
            "check_drug_interactions":   ["current_meds", "proposed_med"],
            "schedule_followup":         ["patient_id", "priority", "days"],
            "get_lab_results":           ["patient_id"],
            "get_allergies":             ["patient_id"],
            "get_current_medications":   ["patient_id"],
        }
        for param in required.get(function_name, []):
            if param not in parameters:
                return False, f"Missing required parameter '{param}' for {function_name}"

        # Validate types
        if function_name == "schedule_followup":
            days = parameters.get("days", 0)
            if not isinstance(days, int) or not (1 <= days <= 90):
                return False, "days must be an integer between 1 and 90"
            if parameters.get("priority") not in ("routine", "urgent", "emergency"):
                return False, "priority must be 'routine', 'urgent', or 'emergency'"

        return True, "OK"

    @classmethod
    def sanitize_response(cls, text: str) -> str:
        """Remove or flag potentially harmful medical claims"""
        for term in cls.BLACKLISTED_TERMS:
            if term in text.lower():
                idx = text.lower().find(term)
                text = (
                    text[:idx]
                    + f"[{term.upper()} — CONSULT PROFESSIONAL]"
                    + text[idx + len(term):]
                )
        # Ensure disclaimer always present
        if "consult" not in text.lower():
            text += f"\n\n{cls.REQUIRED_DISCLAIMER}"
        return text

    @classmethod
    def safe_execute(cls, function_name: str, parameters: dict,
                     executor_fn) -> dict[str, Any]:
        """
        Validate and execute an EHR function safely.

        Args:
            function_name: Name of EHR function
            parameters: Function parameters
            executor_fn: Callable(function_name, parameters) -> result

        Returns:
            {"success": bool, "result": ..., "error": str|None}
        """
        valid, reason = cls.validate_function_call(function_name, parameters)
        if not valid:
            logger.warning(f"[MedicalFunctionGuard] Blocked call: {function_name} — {reason}")
            return {"success": False, "result": None, "error": reason}

        try:
            result = executor_fn(function_name, parameters)
            return {"success": True, "result": result, "error": None}
        except Exception as e:
            logger.error(f"[MedicalFunctionGuard] Execution error: {e}")
            return {"success": False, "result": None, "error": str(e)}
