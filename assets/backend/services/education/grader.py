"""
Homework Grader with Adaptive Tutor
Photo-based homework analysis with Gemma 4
Supports multiple subjects and languages
"""

import os
from typing import Dict, Any, List, Optional
from PIL import Image


class HomeworkGrader:
    """
    AI-powered homework grader using Gemma 4 multimodal capabilities

    Features:
    - OCR for handwritten/printed text
    - Diagram interpretation
    - Rubric-based grading
    - Error analysis and feedback
    - Multi-language support
    """

    _instance = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self,
                 gemma_model: str = None,
                 language: str = "en"):
        # Default to models directory if not provided
        if gemma_model is None:
            models_dir = os.path.join(os.getcwd(), "assets", "models")
            import glob
            matches = glob.glob(os.path.join(models_dir, "**", "*gemma-4-4b*.gguf"), recursive=True)
            if matches:
                self.model_path = matches[0]
            else:
                self.model_path = os.path.join(models_dir, "gemma-4-4b-it-q4", "gemma-2-9b-it-Q4_K_M.gguf")
        else:
            self.model_path = gemma_model
        
        self.language = language
        self.llm_backend = None
        self._initialized = False

    def initialize(self):
        """Lazy initialization"""
        if self._initialized:
            return

        # Try to initialize Ollama or llama-cpp backend
        try:
            import ollama
            self.llm_backend = "ollama"
            ollama.list()
        except ImportError:
            try:
                from llama_cpp import Llama
                self.llm = Llama(
                    model_path=self.model_path,
                    n_ctx=4096,
                    n_gpu_layers=-1,
                    verbose=False
                )
                self.llm_backend = "llama_cpp"
            except ImportError:
                self.llm_backend = "mock"

        self._initialized = True

    def _ocr_with_layout(self, image_path: str) -> Dict[str, Any]:
        """
        Extract text from homework image with layout information

        Returns dict with:
        - extracted_text: Full text content
        - layout: Bounding boxes and structure
        - confidence: OCR confidence scores
        """
        # For now, use mock OCR
        # In production, integrate with:
        # - Tesseract OCR
        # - EasyOCR
        # - Google Cloud Vision (optional cloud)

        return {
            "extracted_text": "Sample math problem solution...",
            "layout": {"lines": [], "diagrams": []},
            "confidence": 0.95
        }

    def _load_domain_rubrics(self, subject: str) -> Dict[str, Any]:
        """Load grading rubrics for specific subject"""

        rubrics = {
            "math": {
                "elementary": {
                    "criteria": [
                        "Correct answer",
                        "Showed work clearly",
                        "Used appropriate method"
                    ],
                    "weights": [0.4, 0.3, 0.3]
                },
                "middle_school": {
                    "criteria": [
                        "Correct methodology",
                        "Accurate calculations",
                        "Proper notation",
                        "Complete explanation"
                    ],
                    "weights": [0.3, 0.3, 0.2, 0.2]
                }
            },
            "science": {
                "general": {
                    "criteria": [
                        "Scientific accuracy",
                        "Hypothesis clarity",
                        "Data interpretation",
                        "Conclusion validity"
                    ],
                    "weights": [0.3, 0.2, 0.3, 0.2]
                }
            },
            "literacy": {
                "essay": {
                    "criteria": [
                        "Thesis clarity",
                        "Evidence quality",
                        "Organization",
                        "Grammar and mechanics"
                    ],
                    "weights": [0.25, 0.3, 0.25, 0.2]
                }
            }
        }

        return rubrics.get(subject, rubrics["math"]["elementary"])

    def _build_grading_prompt(self,
                             problem: str,
                             rubric: Dict[str, Any],
                             language: str,
                             subject: str,
                             grade_level: int,
                             context: str = "") -> str:
        """Construct grading prompt with rubric and optional RAG context."""

        knowledge_hint = ""
        if context:
            knowledge_hint = f"\n\nREFERENCE KNOWLEDGE (from student's notes):\n{context}\n"

        prompts = {
            "en": f"""You are a supportive tutor grading {subject} homework for grade {grade_level}.
{knowledge_hint}
Evaluate this student work:

STUDENT WORK:
{problem}

GRADING RUBRIC:
Criteria: {', '.join(rubric['criteria'])}

Provide:
1. Score (0-100)
2. Specific, constructive feedback
3. Identify errors with explanations
4. Suggest 1-2 practice problems

Be encouraging but honest. Use simple language appropriate for grade {grade_level}.""",

            "es": f"""Eres un tutor solidario que evalúa tareas de {subject} para grado {grade_level}.

Evalúa este trabajo del estudiante:

TRABAJO DEL ESTUDIANTE:
{problem}

RÚBRICA DE EVALUACIÓN:
Criterios: {', '.join(rubric['criteria'])}

Proporciona:
1. Puntuación (0-100)
2. Retroalimentación específica y constructiva
3. Identifica errores con explicaciones
4. Sugiere 1-2 problemas de práctica

Sé alentador pero honesto.""",

            "hi": f"""आप कक्षा {grade_level} के लिए {subject} गृहकार्य का मूल्यांकन करने वाले सहायक ट्यूटर हैं।

छात्र के कार्य का मूल्यांकन करें:

छात्र का कार्य:
{problem}

मूल्यांकन रूब्रिक:
मानदंड: {', '.join(rubric['criteria'])}

प्रदान करें:
1. स्कोर (0-100)
2. विशिष्ट, रचनात्मक प्रतिक्रिया
3. स्पष्टीकरण के साथ त्रुटियों की पहचान करें
4. 1-2 अभ्यास समस्याओं का सुझाव दें""",
        }

        return prompts.get(language, prompts["en"])

    def _generate(self, prompt: str, **kwargs) -> str:
        """Generate response from LLM"""
        if self.llm_backend == "ollama":
            import ollama
            response = ollama.generate(
                model="gemma-4-4b-it",
                prompt=prompt,
                options={"temperature": 0.7}
            )
            return response['response']
        elif self.llm_backend == "llama_cpp":
            response = self.llm(prompt, max_tokens=1024, temperature=0.7)
            return response['choices'][0]['text']
        else:
            return self._mock_response(prompt)

    def _mock_response(self, prompt: str) -> str:
        """Mock response for development"""
        return """
SCORE: 85/100

FEEDBACK:
Great effort! You've shown good understanding of the core concept.

✅ What you did well:
- Correct approach to setting up the equation
- Clear step-by-step work
- Good organization

⚠️ Areas for improvement:
- Calculation error in step 3: 5 × 7 = 35, not 32
- Remember to check your final answer by substituting back

💡 Let's practice:
Try these similar problems:
1. Solve: 3x + 12 = 27
2. If 2y - 8 = 14, what is y?

Keep up the good work! Practice makes perfect. 🌟
"""

    def _extract_score(self, analysis: str) -> int:
        """Extract numerical score from analysis"""
        import re
        match = re.search(r'SCORE[:\s]*(\d+)', analysis, re.IGNORECASE)
        if match:
            return int(match.group(1))
        return 0

    def _categorize_errors(self, analysis: str) -> List[Dict[str, str]]:
        """Categorize identified errors"""
        # Simple parsing - can be enhanced with NLP
        errors = []

        if "calculation error" in analysis.lower():
            errors.append({
                "type": "calculation",
                "description": "Arithmetic or computation mistake",
                "severity": "minor"
            })

        if "method" in analysis.lower() and "error" in analysis.lower():
            errors.append({
                "type": "methodology",
                "description": "Incorrect approach or formula",
                "severity": "major"
            })

        return errors

    async def grade_submission(self,
                        image_path: str,
                        subject: str,
                        grade_level: int,
                        rubric: Optional[Dict[str, Any]] = None,
                        language: Optional[str] = None,
                        context: str = "",
                        llm_svc = None) -> Dict[str, Any]:
        """
        Main entry point for homework grading

        Args:
            image_path: Path to homework photo
            subject: Subject area (math, science, literacy)
            grade_level: Grade level (1-12)
            rubric: Optional custom rubric
            language: Language code (en, es, hi, etc.)
            context: Optional RAG context from vault
            llm_svc: Global LLMService instance from FastAPI state

        Returns:
            Structured grading results
        """
        # Validate input
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        language = language or self.language

        # Load rubric
        rubric = self._load_domain_rubrics(subject)
        grade_rubric = rubric.get(
            "elementary" if grade_level <= 5 else
            "middle_school" if grade_level <= 8 else "general",
            list(rubric.values())[0]
        )

        # Build prompt
        prompt = self._build_grading_prompt(
            problem="[Uploaded Homework Image]",
            rubric=grade_rubric,
            language=language,
            subject=subject,
            grade_level=grade_level,
            context=context
        )

        # Generate analysis using global LLM service with multimodal vision if available
        if llm_svc and llm_svc.is_ready:
            analysis = ""
            async for chunk in llm_svc.stream_chat_multimodal(
                text_prompt=prompt,
                image_paths=[image_path],
                temperature=0.3,
                max_tokens=1024
            ):
                analysis += chunk
        else:
            self.initialize()
            analysis = self._generate(prompt)

        # Parse results
        result = {
            "score": self._extract_score(analysis),
            "feedback": analysis,
            "error_categories": self._categorize_errors(analysis),
            "ocr_confidence": 0.95,
            "subject": subject,
            "grade_level": grade_level,
            "language": language
        }

        # Generate remediation quiz
        result["remediation_quiz"] = self.generate_quiz(
            weak_concepts=result["error_categories"],
            language=language,
            difficulty=grade_level
        )

        return result

    def generate_quiz(self,
                     weak_concepts: List[Dict[str, str]],
                     language: str,
                     difficulty: int) -> List[Dict[str, Any]]:
        """
        Generate adaptive quiz targeting knowledge gaps

        Returns list of quiz questions
        """
        # Mock quiz generation
        # In production, call LLM to generate personalized questions

        questions = []

        for i, error in enumerate(weak_concepts[:3]):  # Max 3 questions
            questions.append({
                "id": i + 1,
                "type": "multiple_choice" if error["type"] == "calculation" else "short_answer",
                "question": f"Practice problem for {error['type']} error",
                "options": ["A) 10", "B) 15", "C) 20", "D) 25"] if error["type"] == "calculation" else None,
                "correct_answer": "C",
                "explanation": f"This tests your understanding of {error['description'].lower()}"
            })

        return questions if questions else [{
            "id": 1,
            "type": "encouragement",
            "message": "Great job! Review the feedback and try similar problems."
        }]
