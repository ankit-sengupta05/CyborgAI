"""
Offline Edge Sync Manager
Optional encrypted sync for clinics/classrooms with intermittent connectivity
"""

import json
import os
import logging
from datetime import datetime
from typing import Any

logger = logging.getLogger(__name__)


class EdgeSyncManager:
    """
    Manages encrypted sync bundles for edge devices that occasionally connect
    to a central server. All data is anonymized before packaging.
    """

    def __init__(self, vault_path: str = "data/sync_vault",
                 encryption_key: bytes = None):
        self.vault_path = vault_path
        self._key = encryption_key or os.urandom(32)
        os.makedirs(vault_path, exist_ok=True)

    def prepare_sync_package(self, device_id: str) -> bytes:
        """
        Create encrypted bundle:
        - Anonymized learning/health records
        - Model hash for version tracking
        - Opt-in aggregated metrics
        """
        package = {
            "device_id": device_id,
            "timestamp": datetime.utcnow().isoformat(),
            "data": self._collect_syncable_data(),
            "model_hash": self._get_model_checksum(),
            "schema_version": "1.0",
        }
        raw = json.dumps(package).encode()
        return self._encrypt(raw)

    def apply_sync_package(self, encrypted_package: bytes) -> dict:
        """
        Decrypt and apply updates from central server.
        Returns: {status, updates_applied}
        """
        try:
            raw = self._decrypt(encrypted_package)
            updates = json.loads(raw)
            applied = self._apply_updates(updates)
            return {"status": "success", "updates_applied": applied}
        except Exception as e:
            logger.error(f"Sync apply failed: {e}")
            return {"status": "error", "error": str(e)}

    def _collect_syncable_data(self) -> list:
        """Collect anonymized records from local vault"""
        records = []
        sync_file = os.path.join(self.vault_path, "pending_sync.json")
        if os.path.exists(sync_file):
            with open(sync_file) as f:
                records = json.load(f)
        return records

    def _get_model_checksum(self) -> str:
        import hashlib
        model_paths = [
            "assets/models/medgemma-4b-Q4_K_M.gguf",
            "assets/models/gemma-4-4b-it-Q4_K_M.gguf",
        ]
        for path in model_paths:
            if os.path.exists(path):
                with open(path, "rb") as f:
                    return hashlib.md5(f.read(4096)).hexdigest()
        return "model-not-found"

    def _apply_updates(self, updates: dict) -> list:
        applied = []
        for key, value in updates.get("data", {}).items():
            dest = os.path.join(self.vault_path, f"{key}.json")
            with open(dest, "w") as f:
                json.dump(value, f)
            applied.append(key)
        return applied

    def _encrypt(self, data: bytes) -> bytes:
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            nonce = os.urandom(12)
            return nonce + AESGCM(self._key).encrypt(nonce, data, None)
        except ImportError:
            logger.warning("cryptography not installed — sync data NOT encrypted")
            return data

    def _decrypt(self, data: bytes) -> bytes:
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            return AESGCM(self._key).decrypt(data[:12], data[12:], None)
        except ImportError:
            return data
