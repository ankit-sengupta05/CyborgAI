"""
Multimodal Vision Encoder
SigLIP / CLIP-ViT feature extraction for vision+text fusion pipeline
"""

import os
import numpy as np
from typing import Optional, Union
import logging

logger = logging.getLogger(__name__)


class VisionEncoder:
    """
    Unified vision encoder supporting SigLIP and CLIP models.
    Optimized for edge deployment with ONNX runtime support.
    """

    def __init__(self,
                 model_name: str = "google/siglip-so400m-patch14-384",
                 use_onnx: bool = False,
                 device: str = "cpu"):
        self.model_name = model_name
        self.use_onnx = use_onnx
        self.device = device
        self.model = None
        self.processor = None
        self._initialized = False

    def initialize(self):
        """Lazy initialization of vision encoder"""
        if self._initialized:
            return
        try:
            if self.use_onnx:
                self._init_onnx()
            else:
                self._init_transformers()
            self._initialized = True
            logger.info(f"✅ VisionEncoder initialized: {self.model_name}")
        except Exception as e:
            logger.warning(f"⚠️ VisionEncoder init failed ({e}), mock mode active")
            self._initialized = True
            self.model = None

    def _init_transformers(self):
        from transformers import SiglipVisionModel, SiglipProcessor
        import torch
        self.processor = SiglipProcessor.from_pretrained(self.model_name)
        self.model = SiglipVisionModel.from_pretrained(self.model_name)
        if self.device == "cuda":
            import torch
            if torch.cuda.is_available():
                self.model = self.model.cuda()
        self.model.eval()

    def _init_onnx(self):
        """ONNX runtime for edge deployment (lower memory)"""
        try:
            import onnxruntime as ort
            onnx_path = f"assets/models/siglip-so400m-patch14-384.onnx"
            if os.path.exists(onnx_path):
                self.ort_session = ort.InferenceSession(onnx_path)
                self.use_onnx = True
            else:
                logger.warning("ONNX model not found, falling back to transformers")
                self._init_transformers()
        except ImportError:
            self._init_transformers()

    def encode(self, image_input: Union[str, np.ndarray]) -> np.ndarray:
        """
        Encode image to feature vector.

        Args:
            image_input: Path to image file or numpy array (H, W, C)

        Returns:
            Feature vector as numpy array (1, hidden_dim)
        """
        self.initialize()

        if self.model is None:
            # Mock mode: return zero vector
            return np.zeros((1, 768), dtype=np.float32)

        try:
            from PIL import Image
            if isinstance(image_input, str):
                image = Image.open(image_input).convert("RGB")
            else:
                image = Image.fromarray(image_input.astype(np.uint8))

            if self.use_onnx and hasattr(self, 'ort_session'):
                return self._encode_onnx(image)
            else:
                return self._encode_transformers(image)
        except Exception as e:
            logger.error(f"Vision encoding failed: {e}")
            return np.zeros((1, 768), dtype=np.float32)

    def _encode_transformers(self, image) -> np.ndarray:
        import torch
        inputs = self.processor(images=image, return_tensors="pt")
        if self.device == "cuda" and torch.cuda.is_available():
            inputs = {k: v.cuda() for k, v in inputs.items()}
        with torch.no_grad():
            outputs = self.model(**inputs)
        return outputs.pooler_output.cpu().numpy()

    def _encode_onnx(self, image) -> np.ndarray:
        import torchvision.transforms as T
        transform = T.Compose([T.Resize((384, 384)), T.ToTensor(),
                               T.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5])])
        tensor = transform(image).unsqueeze(0).numpy()
        outputs = self.ort_session.run(None, {"pixel_values": tensor})
        return outputs[0]

    def encode_batch(self, images: list) -> np.ndarray:
        """Encode multiple images; returns (N, hidden_dim)"""
        return np.vstack([self.encode(img) for img in images])
