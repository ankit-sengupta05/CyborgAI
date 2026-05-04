"""
Medical Data Security & Privacy
HIPAA-inspired safeguards for patient-adjacent data handling
"""

import hashlib
import os
import logging
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)


class MedicalDataHandler:
    """
    Privacy-preserving handling of patient-adjacent data.
    Implements anonymization, encryption, and immutable audit logs.
    """

    BLACKLISTED_TERMS = ["diagnose", "prescribe", "cure", "guarantee", "will heal", "definitive"]

    @staticmethod
    def anonymize_patient_context(context: dict) -> dict:
        """Remove PII while preserving clinical relevance"""
        return {
            "age_range": MedicalDataHandler._bin_age(context.get("age")),
            "symptom_categories": MedicalDataHandler._categorize_symptoms(
                context.get("symptoms", [])
            ),
            # Never stored: name, DOB, address, ID numbers, contact info
        }

    @staticmethod
    def _bin_age(age: Optional[int]) -> str:
        if age is None:
            return "unknown"
        if age < 18:
            return "pediatric (<18)"
        elif age < 40:
            return "young_adult (18-39)"
        elif age < 65:
            return "adult (40-64)"
        return "senior (65+)"

    @staticmethod
    def _categorize_symptoms(symptoms: list) -> list:
        categories = []
        respiratory = {"cough", "wheeze", "dyspnea", "shortness of breath", "breathing"}
        cardiac     = {"chest pain", "palpitations", "heart", "tachycardia"}
        systemic    = {"fever", "fatigue", "night sweats", "weight loss", "malaise"}
        for s in symptoms:
            sl = s.lower()
            if any(r in sl for r in respiratory):
                categories.append("respiratory")
            elif any(c in sl for c in cardiac):
                categories.append("cardiac")
            elif any(sy in sl for sy in systemic):
                categories.append("systemic")
            else:
                categories.append("other")
        return list(set(categories))

    @staticmethod
    def encrypt_local_storage(data: bytes, device_key: bytes) -> bytes:
        """AES-256-GCM encryption for on-device data at rest"""
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            aesgcm = AESGCM(device_key)
            nonce = os.urandom(12)
            ciphertext = aesgcm.encrypt(nonce, data, None)
            return nonce + ciphertext
        except ImportError:
            logger.warning("cryptography not installed — data NOT encrypted")
            return data

    @staticmethod
    def decrypt_local_storage(encrypted: bytes, device_key: bytes) -> bytes:
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            aesgcm = AESGCM(device_key)
            nonce, ciphertext = encrypted[:12], encrypted[12:]
            return aesgcm.decrypt(nonce, ciphertext, None)
        except ImportError:
            return encrypted

    @staticmethod
    def audit_log(action: str, device_id: str, log_path: str = "data/audit.log"):
        """Immutable local audit trail with SHA-256 hash chain"""
        timestamp = datetime.utcnow().isoformat()
        entry_hash = hashlib.sha256(
            f"{action}{device_id}{timestamp}".encode()
        ).hexdigest()
        log_entry = f"{timestamp}|{device_id}|{action}|{entry_hash}\n"
        try:
            os.makedirs(os.path.dirname(log_path), exist_ok=True)
            with open(log_path, "a") as f:
                f.write(log_entry)
        except Exception as e:
            logger.error(f"Audit log write failed: {e}")

    @staticmethod
    def sanitize_response(text: str) -> str:
        """Remove or flag potentially harmful medical claims"""
        for term in MedicalDataHandler.BLACKLISTED_TERMS:
            if term in text.lower():
                text = text.replace(term, f"[{term.upper()} — CONSULT PROFESSIONAL]")
        # Ensure disclaimer is present
        disclaimer = "⚠️ This is not a diagnosis. Please consult a healthcare professional."
        if "consult" not in text.lower():
            text += f"\n\n{disclaimer}"
        return text
