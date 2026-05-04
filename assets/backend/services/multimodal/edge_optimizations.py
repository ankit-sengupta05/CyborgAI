"""
Edge Optimizations for Multimodal Inference
Quantization, caching, and pruning utilities for Raspberry Pi / Android Go deployment
"""

import os
import hashlib
import json
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


class EdgeOptimizer:
    """
    Optimization utilities for deploying multimodal models on edge devices.
    Targets <4GB RAM footprint for Raspberry Pi 4 / Jetson Nano / Android Go.
    """

    # ── Response Cache ──────────────────────────────────────────────────────

    def __init__(self, cache_dir: str = "data/edge_cache"):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        self._memory_cache: dict[str, Any] = {}

    def cache_key(self, image_path: str, prompt: str) -> str:
        """Deterministic cache key from image hash + prompt hash"""
        try:
            with open(image_path, "rb") as f:
                img_hash = hashlib.md5(f.read()).hexdigest()[:8]
        except Exception:
            img_hash = "nohash"
        prompt_hash = hashlib.md5(prompt.encode()).hexdigest()[:8]
        return f"{img_hash}_{prompt_hash}"

    def get_cached(self, key: str) -> Optional[Any]:
        if key in self._memory_cache:
            return self._memory_cache[key]
        path = os.path.join(self.cache_dir, f"{key}.json")
        if os.path.exists(path):
            with open(path) as f:
                result = json.load(f)
            self._memory_cache[key] = result
            return result
        return None

    def set_cache(self, key: str, value: Any):
        self._memory_cache[key] = value
        path = os.path.join(self.cache_dir, f"{key}.json")
        try:
            with open(path, "w") as f:
                json.dump(value, f)
        except Exception as e:
            logger.warning(f"Cache write failed: {e}")

    # ── Model Quantization Helpers ──────────────────────────────────────────

    @staticmethod
    def recommend_quantization(available_ram_gb: float) -> str:
        """Recommend GGUF quantization level based on available RAM"""
        if available_ram_gb >= 8:
            return "Q8_0"      # High quality, 8GB+
        elif available_ram_gb >= 4:
            return "Q4_K_M"    # Balanced — Raspberry Pi 4, Jetson Nano
        elif available_ram_gb >= 2:
            return "Q2_K"      # Low quality but runs on 2GB devices
        else:
            return "Q2_K"      # Minimum viable

    @staticmethod
    def get_device_profile() -> dict:
        """Detect current device capabilities"""
        import psutil
        ram_gb = psutil.virtual_memory().total / (1024 ** 3)
        cpu_count = os.cpu_count() or 1
        try:
            import torch
            has_cuda = torch.cuda.is_available()
            gpu_name = torch.cuda.get_device_name(0) if has_cuda else "None"
            gpu_vram = torch.cuda.get_device_properties(0).total_memory / (1024**3) if has_cuda else 0
        except Exception:
            has_cuda, gpu_name, gpu_vram = False, "None", 0.0

        quant = EdgeOptimizer.recommend_quantization(ram_gb)
        return {
            "ram_gb": round(ram_gb, 1),
            "cpu_cores": cpu_count,
            "cuda_available": has_cuda,
            "gpu_name": gpu_name,
            "gpu_vram_gb": round(gpu_vram, 1),
            "recommended_quantization": quant,
            "estimated_latency": EdgeOptimizer._estimate_latency(ram_gb, has_cuda),
        }

    @staticmethod
    def _estimate_latency(ram_gb: float, has_cuda: bool) -> dict:
        if has_cuda:
            return {"xray_analysis_s": "5-8", "homework_grading_s": "3-5"}
        elif ram_gb >= 4:
            return {"xray_analysis_s": "12-18", "homework_grading_s": "6-10"}
        else:
            return {"xray_analysis_s": "20-30", "homework_grading_s": "10-15"}

    # ── Batch Optimization ──────────────────────────────────────────────────

    @staticmethod
    def optimal_batch_size(ram_gb: float) -> int:
        """Return safe batch size for inference given available RAM"""
        if ram_gb >= 8:
            return 4
        elif ram_gb >= 4:
            return 2
        return 1
