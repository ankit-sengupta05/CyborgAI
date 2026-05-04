"""
EHR Function Calling for MedGemma 4B
Safe, privacy-preserving integration with electronic health records
"""

from typing import Literal, Optional, Dict, Any, List
import json
from datetime import datetime


# EHR Function Definitions (FHIR-compatible)
EHR_FUNCTIONS = {
    "get_patient_history": {
        "name": "get_patient_history",
        "description": "Retrieve patient's medical history from local EHR system",
        "parameters": {
            "type": "object",
            "properties": {
                "patient_id": {
                    "type": "string",
                    "required": True,
                    "description": "Unique patient identifier"
                },
                "time_range": {
                    "type": "string",
                    "enum": ["last_30d", "last_1y", "all"],
                    "default": "last_1y",
                    "description": "Time range for history retrieval"
                }
            }
        },
        "returns": {
            "type": "object",
            "properties": {
                "conditions": {"type": "array"},
                "medications": {"type": "array"},
                "allergies": {"type": "array"},
                "procedures": {"type": "array"}
            }
        }
    },

    "check_drug_interactions": {
        "name": "check_drug_interactions",
        "description": "Check for potential medication interactions and contraindications",
        "parameters": {
            "type": "object",
            "properties": {
                "current_meds": {
                    "type": "array",
                    "items": {"type": "string"},
                    "required": True,
                    "description": "List of current medications"
                },
                "proposed_med": {
                    "type": "string",
                    "required": True,
                    "description": "New medication to check"
                },
                "patient_id": {
                    "type": "string",
                    "required": False,
                    "description": "Optional: for patient-specific factors"
                }
            }
        },
        "returns": {
            "type": "object",
            "properties": {
                "interaction_level": {"type": "string"},
                "details": {"type": "string"},
                "recommendations": {"type": "array"}
            }
        }
    },

    "schedule_followup": {
        "name": "schedule_followup",
        "description": "Create follow-up appointment reminder in clinic calendar",
        "parameters": {
            "type": "object",
            "properties": {
                "patient_id": {
                    "type": "string",
                    "required": True
                },
                "priority": {
                    "type": "string",
                    "enum": ["routine", "urgent", "emergency"],
                    "required": True
                },
                "days": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 90,
                    "default": 30
                },
                "reason": {
                    "type": "string",
                    "description": "Reason for follow-up"
                }
            }
        },
        "returns": {
            "type": "object",
            "properties": {
                "appointment_id": {"type": "string"},
                "scheduled_date": {"type": "string"},
                "confirmation": {"type": "boolean"}
            }
        }
    },

    "order_lab_test": {
        "name": "order_lab_test",
        "description": "Order laboratory tests based on clinical findings",
        "parameters": {
            "type": "object",
            "properties": {
                "patient_id": {"type": "string", "required": True},
                "test_codes": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "LOINC or CPT codes for tests"
                },
                "priority": {
                    "type": "string",
                    "enum": ["routine", "stat"],
                    "default": "routine"
                },
                "clinical_notes": {
                    "type": "string",
                    "description": "Clinical indication for tests"
                }
            }
        },
        "returns": {
            "type": "object",
            "properties": {
                "order_id": {"type": "string"},
                "status": {"type": "string"},
                "collection_instructions": {"type": "string"}
            }
        }
    }
}


class EHRFunctionCaller:
    """
    Safe EHR function calling with validation and audit logging
    """

    def __init__(self, ehr_backend: str = "mock"):
        """
        Initialize EHR function caller

        Args:
            ehr_backend: Backend type ('mock', 'fhir', 'epic', 'cerner')
        """
        self.backend = ehr_backend
        self.audit_log = []

    def validate_function_call(self,
                               function_name: str,
                               parameters: Dict[str, Any]) -> bool:
        """
        Validate function call against schema

        Returns True if valid, raises ValueError if invalid
        """
        if function_name not in EHR_FUNCTIONS:
            raise ValueError(f"Unknown function: {function_name}")

        func_def = EHR_FUNCTIONS[function_name]
        required_params = []

        # Check required parameters
        for param_name, param_def in func_def["parameters"]["properties"].items():
            if param_def.get("required"):
                required_params.append(param_name)

            if param_name in required_params and param_name not in parameters:
                raise ValueError(
                    f"Missing required parameter: {param_name} for function {function_name}"
                )

        # Validate enums
        for param_name, param_value in parameters.items():
            if param_name in func_def["parameters"]["properties"]:
                param_def = func_def["parameters"]["properties"][param_name]
                if "enum" in param_def and param_value not in param_def["enum"]:
                    raise ValueError(
                        f"Invalid value for {param_name}: {param_value}. "
                        f"Must be one of: {param_def['enum']}"
                    )

        return True

    async def execute_function(self,
                              function_name: str,
                              parameters: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute EHR function with validation

        Returns structured response
        """
        # Validate first
        self.validate_function_call(function_name, parameters)

        # Log the call
        self._log_audit(function_name, parameters, "executing")

        try:
            # Route to appropriate backend
            if self.backend == "mock":
                result = await self._execute_mock(function_name, parameters)
            elif self.backend == "fhir":
                result = await self._execute_fhir(function_name, parameters)
            else:
                raise NotImplementedError(f"Backend not implemented: {self.backend}")

            self._log_audit(function_name, parameters, "success", result)
            return result

        except Exception as e:
            self._log_audit(function_name, parameters, "error", str(e))
            raise

    async def _execute_mock(self,
                           function_name: str,
                           parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Mock backend for development/testing"""

        if function_name == "get_patient_history":
            return {
                "patient_id": parameters["patient_id"],
                "conditions": ["Hypertension", "Type 2 Diabetes"],
                "medications": ["Lisinopril 10mg", "Metformin 500mg"],
                "allergies": ["Penicillin"],
                "procedures": ["Appendectomy (2015)"]
            }

        elif function_name == "check_drug_interactions":
            # Mock interaction check
            interactions = {
                "interaction_level": "Low",
                "details": "No significant interactions detected",
                "recommendations": ["Monitor blood pressure if starting new medication"]
            }

            # Simulate specific interaction
            if "lisinopril" in [m.lower() for m in parameters.get("current_meds", [])]:
                if "potassium" in parameters.get("proposed_med", "").lower():
                    interactions = {
                        "interaction_level": "Moderate",
                        "details": "ACE inhibitors + potassium supplements may cause hyperkalemia",
                        "recommendations": [
                            "Monitor serum potassium levels",
                            "Consider alternative if patient has renal impairment"
                        ]
                    }

            return interactions

        elif function_name == "schedule_followup":
            from datetime import timedelta
            followup_date = datetime.now() + timedelta(days=parameters.get("days", 30))

            return {
                "appointment_id": f"APT-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                "scheduled_date": followup_date.isoformat(),
                "confirmation": True,
                "priority": parameters["priority"]
            }

        elif function_name == "order_lab_test":
            return {
                "order_id": f"LAB-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                "status": "pending",
                "collection_instructions": "Please visit lab within 7 days. Fasting required."
            }

        return {"status": "unknown_function"}

    async def _execute_fhir(self,
                           function_name: str,
                           parameters: Dict[str, Any]) -> Dict[str, Any]:
        """
        Real FHIR server integration (placeholder)

        In production, this would connect to a FHIR R4 server
        using libraries like fhir.resources or hapi-fhir
        """
        # TODO: Implement real FHIR integration
        # - Connect to FHIR endpoint
        # - Authenticate with OAuth2
        # - Execute FHIR operations
        # - Handle SMART on FHIR if needed

        raise NotImplementedError(
            "FHIR backend not yet implemented. Use mock backend for development."
        )

    def _log_audit(self,
                  function_name: str,
                  parameters: Dict[str, Any],
                  status: str,
                  result: Any = None):
        """Append to audit log (for compliance)"""
        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "function": function_name,
            "parameters_hash": hash(json.dumps(parameters, sort_keys=True)),
            "status": status,
            "result_preview": str(result)[:100] if result else None
        }
        self.audit_log.append(entry)

    def get_audit_log(self) -> List[Dict[str, Any]]:
        """Retrieve audit log for compliance reporting"""
        return self.audit_log


# Safety guardrails for medical function calls
class MedicalFunctionGuard:
    """
    Prevent unsafe EHR function calls or hallucinated medical advice
    """

    ALLOWED_FUNCTIONS = set(EHR_FUNCTIONS.keys())

    BLACKLISTED_TERMS = [
        "diagnose", "prescribe", "cure", "guarantee",
        "definitely", "certainly", "100%", "absolute"
    ]

    @classmethod
    def validate_function_call(cls,
                              function_name: str,
                              parameters: Dict[str, Any]) -> bool:
        """Validate function is allowed and parameters are safe"""
        if function_name not in cls.ALLOWED_FUNCTIONS:
            return False

        # Additional safety checks could go here
        # e.g., rate limiting, patient consent verification

        return True

    @classmethod
    def sanitize_response(cls, text: str) -> str:
        """Remove or flag potentially harmful medical claims"""
        sanitized = text

        for term in cls.BLACKLISTED_TERMS:
            if term in sanitized.lower():
                # Replace with safer language
                replacement = f"[{term.upper()} - CONSULT PROFESSIONAL]"
                sanitized = sanitized.replace(term, replacement)
                sanitized = sanitized.replace(term.capitalize(), replacement)
                sanitized = sanitized.replace(term.upper(), replacement)

        return sanitized

    @classmethod
    def add_disclaimer(cls, text: str, level: str = "standard") -> str:
        """Append appropriate medical disclaimer"""
        disclaimers = {
            "short": "\n\n⚠️ This is not medical advice. Consult a healthcare professional.",
            "standard": "\n\n⚠️ IMPORTANT: This AI assistance provides information only. "
                       "It is NOT a substitute for professional medical advice, diagnosis, or treatment. "
                       "Always consult your physician.",
            "emergency": "\n\n🚨 If you think you may have a medical emergency, "
                        "call your doctor or emergency services immediately."
        }

        return text + disclaimers.get(level, disclaimers["standard"])


async def execute_ehr_functions(functions_to_call: List[Dict[str, Any]],
                                backend: str = "mock") -> List[Dict[str, Any]]:
    """
    Convenience function to execute multiple EHR functions

    Args:
        functions_to_call: List of {name, parameters} dicts
        backend: EHR backend type

    Returns:
        List of results
    """
    caller = EHRFunctionCaller(backend=backend)
    results = []

    for func_call in functions_to_call:
        try:
            result = await caller.execute_function(
                function_name=func_call["name"],
                parameters=func_call.get("parameters", {})
            )
            results.append({
                "function": func_call["name"],
                "status": "success",
                "result": result
            })
        except Exception as e:
            results.append({
                "function": func_call["name"],
                "status": "error",
                "error": str(e)
            })

    return results
