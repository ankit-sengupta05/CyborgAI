"""
Education Data Ethics
COPPA/GDPR-K inspired consent flows and data minimization for student data
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)


class LearningDataEthics:
    """
    Ensure student data is used responsibly and transparently.
    Implements consent templates, bias checking, and data minimization.
    """

    CONSENT_TEMPLATES = {
        "en": """
Cyborg Learning Assistant — Parent/Guardian Consent

This tool helps your child practice {subject} by:
✓ Grading homework with constructive feedback
✓ Creating personalized practice quizzes
✓ Tracking progress to identify learning gaps

Your child's work:
• Is processed entirely on this device (no cloud upload)
• Is never shared without your explicit permission
• Can be deleted anytime via Settings → Privacy → Clear Student Data

[ ] I consent to my child using this learning assistant
[ ] I would like to receive weekly progress summaries
[ ] I allow anonymized data to help improve the tool (optional)

Signature: ___________________ Date: ___________
""",
        "es": """
Asistente de Aprendizaje Cyborg — Consentimiento de Padre/Tutor

Esta herramienta ayuda a su hijo(a) a practicar {subject}:
✓ Calificando tareas con retroalimentación constructiva
✓ Creando cuestionarios personalizados
✓ Siguiendo el progreso para identificar brechas de aprendizaje

El trabajo de su hijo(a):
• Se procesa completamente en este dispositivo (sin carga a la nube)
• Nunca se comparte sin su permiso explícito
• Se puede eliminar en cualquier momento desde Configuración → Privacidad

[ ] Doy mi consentimiento para que mi hijo use este asistente
[ ] Me gustaría recibir resúmenes de progreso semanales
[ ] Permito datos anonimizados para mejorar la herramienta (opcional)
""",
        "hi": """
साइबोर्ग लर्निंग असिस्टेंट — माता-पिता/अभिभावक की सहमति

यह उपकरण आपके बच्चे को {subject} में अभ्यास करने में मदद करता है:
✓ रचनात्मक प्रतिक्रिया के साथ गृहकार्य की ग्रेडिंग
✓ व्यक्तिगत अभ्यास प्रश्नोत्तरी बनाना
✓ सीखने की कमियों की पहचान के लिए प्रगति ट्रैक करना

आपके बच्चे का काम:
• पूरी तरह इस डिवाइस पर प्रोसेस होता है (कोई क्लाउड अपलोड नहीं)
• आपकी स्पष्ट अनुमति के बिना कभी साझा नहीं किया जाता
• सेटिंग्स → गोपनीयता से कभी भी हटाया जा सकता है

[ ] मैं अपने बच्चे के इस सहायक का उपयोग करने की सहमति देता/देती हूं
""",
    }

    POTENTIAL_BIASES = [
        "only boys", "only girls", "all poor people", "rich people always",
        "primitive", "uncivilized", "backward country",
    ]

    @staticmethod
    def get_parental_consent_template(language: str, subject: str = "various subjects") -> str:
        """Generate age-appropriate consent form in target language"""
        template = LearningDataEthics.CONSENT_TEMPLATES.get(
            language, LearningDataEthics.CONSENT_TEMPLATES["en"]
        )
        return template.format(subject=subject)

    @staticmethod
    def bias_check_quiz_questions(questions: list, cultural_context: Optional[str] = None) -> list:
        """Flag potentially biased or culturally insensitive quiz content"""
        flagged = []
        for q in questions:
            text = q.get("question", "").lower()
            for bias_phrase in LearningDataEthics.POTENTIAL_BIASES:
                if bias_phrase in text:
                    flagged.append({
                        "question_id": q.get("id"),
                        "issue": "Potential cultural bias",
                        "phrase_found": bias_phrase,
                        "suggestion": "Review with a local educator before use",
                    })
                    break
        return flagged

    @staticmethod
    def anonymize_student_record(record: dict) -> dict:
        """Strip PII from student record, keep only learning data"""
        safe_keys = {"grade_level", "subject", "score", "error_categories",
                     "session_id", "timestamp", "language"}
        return {k: v for k, v in record.items() if k in safe_keys}

    @staticmethod
    def data_minimization_policy() -> dict:
        """Return the data minimization policy for UI display"""
        return {
            "stored": ["Grade level", "Subject", "Score", "Error categories", "Session timestamps"],
            "never_stored": ["Student name", "Photo", "School name", "Location", "Device ID"],
            "retention_days": 90,
            "deletion_method": "Settings → Privacy → Clear Student Data",
            "sharing": "Never shared without explicit opt-in consent",
        }
