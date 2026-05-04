
import os
import locale

import builtins


def apply_patches():
    """Apply Windows-specific patches for encoding and stability."""
    if os.name != 'nt':
        return

    print("[PATCH] Applying Windows UTF-8 stability patches...")

    # 1. Force UTF-8 for locale
    try:
        locale.getpreferredencoding = lambda do_setlocale=True: 'utf-8'
    except Exception:
        pass

    # 2. Monkeypatch builtins.open
    _orig_open = builtins.open

    def _patched_open(
        file, mode='r', buffering=-1, encoding=None, errors=None,
        newline=None, closefd=True, opener=None
    ):
        file_str = str(file).lower()
        # Binary extensions that should NEVER be opened with encoding
        is_binary_ext = any(file_str.endswith(ext) for ext in [
            '.onnx', '.bin', '.exe', '.dll', '.so', '.pyd', '.pyc',
            '.pt', '.pth', '.weights', '.gguf', '.npz', '.wav',
            '.mp3', '.flac', '.png', '.jpg', '.jpeg', '.gif'
        ])

        # If text mode and no encoding, force utf-8
        if 'b' not in mode and encoding is None and not is_binary_ext:
            # We use 'replace' to ensure we never crash on a bad character
            return _orig_open(
                file, mode, buffering, encoding='utf-8',
                errors=errors or 'replace', newline=newline,
                closefd=closefd, opener=opener
            )

        return _orig_open(file, mode, buffering, encoding, errors, newline, closefd, opener)

    builtins.open = _patched_open

    # 3. Monkeypatch pathlib.Path.open
    from pathlib import Path as _Path
    _orig_path_open = _Path.open

    def _patched_path_open(
        self, mode='r', buffering=-1, encoding=None, errors=None, newline=None
    ):
        is_binary_ext = any(self.name.lower().endswith(ext) for ext in [
            '.onnx', '.bin', '.exe', '.dll', '.so', '.pyd', '.pyc',
            '.pt', '.pth', '.weights', '.gguf', '.npz', '.wav',
            '.mp3', '.flac', '.png', '.jpg', '.jpeg', '.gif'
        ])
        if 'b' not in mode and encoding is None and not is_binary_ext:
            return _orig_path_open(
                self, mode, buffering, encoding='utf-8',
                errors=errors or 'replace', newline=newline
            )
        return _orig_path_open(self, mode, buffering, encoding, errors, newline)

    _Path.open = _patched_path_open

    # 4. Environment Variables
    os.environ["PYTHONUTF8"] = "1"

    print("[PATCH] Windows patches applied successfully.")
