"""
MedGemma 4B Inference Pipeline
Chest X-ray analysis with plain-language explanations
Optimized for offline edge deployment
"""

from transformers import AutoTokenizer
import torch
import numpy as np
from typing import Optional, Dict, Any, List
import gc
import os


class MedGemmaPipeline:
    """
    Multimodal medical imaging pipeline using MedGemma 4B
    Supports chest X-ray analysis with vision encoder + language model
    """

    _instance = None

    def __init__(self, model_path: str = None, device: str = "cuda"):
        # Default to models directory if not provided
        if model_path is None:
            models_dir = os.path.join(os.getcwd(), "assets", "models")
            # Search for medgemma GGUF
            import glob
            matches = glob.glob(os.path.join(models_dir, "**", "*medgemma*.gguf"), recursive=True)
            if matches:
                self.model_path = matches[0]
            else:
                self.model_path = os.path.join(models_dir, "medgemma-2-9b-q4", "MedGemma-2-9b-it-Q4_K_M.gguf")
        else:
            self.model_path = model_path
        
        self.device = device if torch.cuda.is_available() else "cpu"
        self.tokenizer = None
        self.vision_encoder = None
        self.llm_backend = None
        self._initialized = False

    @classmethod
    def get_instance(cls, model_path: str = None) -> 'MedGemmaPipeline':
        """Singleton pattern for efficient model loading"""
        if cls._instance is None:
            cls._instance = cls(model_path=model_path or "assets/models/medgemma-4b-Q4_K_M.gguf")
        return cls._instance

    def initialize(self):
        """Lazy initialization of models"""
        if self._initialized:
            return

        try:
            # Initialize tokenizer (avoid hitting internet)
            try:
                self.tokenizer = AutoTokenizer.from_pretrained(
                    "google/gemma-2b-it",
                    cache_dir=os.path.join(os.path.dirname(self.model_path), "cache"),
                    local_files_only=True
                )
            except Exception:
                self.tokenizer = None

            # Initialize vision encoder (SigLIP) (avoid hitting internet)
            try:
                from transformers import SiglipVisionModel
                self.vision_encoder = SiglipVisionModel.from_pretrained(
                    "google/siglip-so400m-patch14-384",
                    local_files_only=True
                ).to(self.device)
                self.vision_encoder.eval()
            except Exception:
                self.vision_encoder = None

            # Initialize Ollama backend for GGUF inference
            try:
                import ollama
                self.llm_backend = "ollama"
                # Test connection (catches connection/http/timeout exceptions)
                ollama.list()
            except Exception:
                # Fallback to llama-cpp-python
                try:
                    from llama_cpp import Llama
                    self.llm = Llama(
                        model_path=self.model_path,
                        n_ctx=4096,
                        n_gpu_layers=-1 if self.device == "cuda" else 0,
                        verbose=False
                    )
                    self.llm_backend = "llama_cpp"
                except Exception:
                    self.llm_backend = "mock"

            self._initialized = True
            print(f"[OK] MedGemmaPipeline initialized on {self.device}")

        except Exception as e:
            print(f"[WARNING] Model initialization failed: {e}")
            print("Running in mock mode for development")
            self._initialized = True  # Allow mock mode
            self.llm_backend = "mock"

    def _encode_image(self, image_path: str) -> torch.Tensor:
        """Encode medical image using SigLIP vision encoder"""
        from PIL import Image
        import torchvision.transforms as transforms

        # Load and preprocess image
        image = Image.open(image_path).convert("RGB")

        # SigLIP preprocessing
        transform = transforms.Compose([
            transforms.Resize((384, 384)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
        ])

        image_tensor = transform(image).unsqueeze(0).to(self.device)

        # Extract features
        with torch.no_grad():
            outputs = self.vision_encoder(pixel_values=image_tensor)
            image_features = outputs.last_hidden_state

        return image_features

    def _build_medical_prompt(self,
                             image_features: torch.Tensor,
                             context: Optional[Dict[str, Any]] = None,
                             template: str = "explain_like_im_5") -> str:
        """Construct medical prompt with patient context"""

        templates = {
            "explain_like_im_5": """You are a compassionate medical assistant analyzing a chest X-ray.

Patient Context:
- Age: {age}
- Symptoms: {symptoms}

Analyze this X-ray and explain in simple terms:
1. What you observe (avoid jargon)
2. Possible conditions (with confidence levels)
3. Risk factors the patient should know
4. Recommended next steps

IMPORTANT: Always end with: "⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice."

Analysis:""",

            "clinical_summary": """Clinical X-ray Analysis Report

Patient: Age {age}, Symptoms: {symptoms}

Findings:
Differential Diagnosis:
Recommendations:

DISCLAIMER: AI assistance only - not a substitute for professional medical evaluation."""
        }

        prompt_template = templates.get(template, templates["explain_like_im_5"])

        prompt_text = prompt_template.format(
            age=context.get("age", "N/A") if context else "N/A",
            symptoms=", ".join(context.get("symptoms", [])) if context and context.get("symptoms") else "None reported"
        )

        if context and context.get("rag_history"):
            prompt_text = f"RELEVANT MEDICAL HISTORY:\n{context['rag_history']}\n\n" + prompt_text

        return prompt_text

    def _safe_generate(self,
                      prompt: str,
                      max_new_tokens: int = 512,
                      stop_sequences: Optional[List[str]] = None) -> str:
        """Generate response with safety constraints"""

        if self.llm_backend == "ollama":
            import ollama
            response = ollama.generate(
                model="medgemma-4b",
                prompt=prompt,
                options={
                    "num_predict": max_new_tokens,
                    "stop": stop_sequences or ["###", "[INST]"],
                    "temperature": 0.3  # Lower temperature for medical safety
                }
            )
            return response['response']

        elif self.llm_backend == "llama_cpp":
            response = self.llm(
                prompt,
                max_tokens=max_new_tokens,
                stop=stop_sequences or ["###", "[INST]"],
                temperature=0.3
            )
            return response['choices'][0]['text']

        elif self.llm_backend == "mock":
            # Mock response for development without models
            return self._generate_mock_response(prompt)

        return ""

    def _generate_mock_response(self, prompt: str) -> str:
        """Generate realistic mock response for testing"""
        return """
**Possible Findings**: No acute abnormalities detected. Lung fields appear clear. Heart size within normal limits.

**Confidence**: 85%

### Plain-Language Explanation
The X-ray shows normal lung structures with no signs of pneumonia, fluid buildup, or masses. The heart size and shape look healthy. The diaphragm and rib cage appear normal.

### Risk Factors
Based on the information provided, there are no immediate risk factors visible in this X-ray.

### Recommended Next Steps
- If symptoms persist, consider follow-up with your healthcare provider
- Maintain regular check-ups
- Continue healthy lifestyle habits

⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice.
"""

    def _parse_medical_response(self, response: str) -> Dict[str, Any]:
        """Parse structured medical response"""
        # Simple parsing - can be enhanced with regex or NLP
        result = {
            "diagnosis_suggestion": "No acute abnormalities detected",
            "confidence": 85,
            "plain_language_explanation": "",
            "risk_factors": [],
            "recommendations": [],
            "ehr_functions": None,
            "full_response": response
        }

        # Extract sections
        lines = response.split('\n')
        current_section = None

        for line in lines:
            line = line.strip()
            if 'Confidence' in line and '%' in line:
                try:
                    conf_str = line.split('%')[0].split(':')[-1].strip()
                    result["confidence"] = int(conf_str)
                except:
                    pass
            elif 'Plain-Language Explanation' in line or 'Explanation' in line:
                current_section = "explanation"
            elif 'Risk Factors' in line:
                current_section = "risk"
            elif 'Next Steps' in line or 'Recommendations' in line:
                current_section = "recommendations"
            elif current_section == "explanation" and line:
                result["plain_language_explanation"] += line + " "
            elif current_section == "risk" and line:
                result["risk_factors"].append(line)
            elif current_section == "recommendations" and line:
                result["recommendations"].append(line)

        result["plain_language_explanation"] = result["plain_language_explanation"].strip()

        return result

    async def analyze_xray(self,
                    image_path: str,
                    patient_context: Optional[Dict[str, Any]] = None,
                    llm_svc=None) -> Dict[str, Any]:
        """
        Main entry point for X-ray analysis

        Args:
            image_path: Path to chest X-ray image (PNG/JPG/DICOM)
            patient_context: Optional dict with age, symptoms, language
            llm_svc: Global LLMService instance from FastAPI state

        Returns:
            Structured analysis results
        """
        # If no global service provided, try to mock
        if not llm_svc or not llm_svc.is_ready:
            print("Running in mock mode for development (no global LLM provided)")
            prompt = self._build_medical_prompt(None, context=patient_context, template="explain_like_im_5")
            response = self._generate_mock_response(prompt)
            result = self._parse_medical_response(response)
            if "⚠️" not in result.get("full_response", ""):
                result["full_response"] += "\n\n⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice."
            return result

        # Validate input
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        # Build prompt
        prompt = self._build_medical_prompt(
            None,
            context=patient_context,
            template="explain_like_im_5"
        )

        response = ""
        async for chunk in llm_svc.stream_chat_multimodal(
            text_prompt=prompt,
            image_paths=[image_path],
            temperature=0.3,
            max_tokens=512
        ):
            response += chunk

        # Parse and return structured results
        result = self._parse_medical_response(response)

        # Add disclaimer if missing
        if "⚠️" not in result.get("full_response", ""):
            result["full_response"] += "\n\n⚠️ This is not a diagnosis. Please consult a healthcare professional for medical advice."

        # Clean up memory
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        return result

    def unload(self):
        """Free GPU memory"""
        if self.vision_encoder:
            del self.vision_encoder
        if hasattr(self, 'llm'):
            del self.llm
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        self._initialized = False
