"""
Text Extractor Utility
Handles extraction of text from various file formats: .docx, .pdf, .txt, .md.
"""
import structlog
from pathlib import Path


log = structlog.get_logger(__name__)


async def extract_text(file_path: Path) -> str:
    ext = file_path.suffix.lower()

    if ext in (".txt", ".md"):
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()

    if ext == ".docx":
        try:
            import docx
            doc = docx.Document(file_path)
            return "\n".join([para.text for para in doc.paragraphs])
        except ImportError:
            log.error("python-docx not installed")
            return f"Error: python-docx not installed to read {file_path.name}"

    if ext == ".pdf":
        try:
            import PyPDF2
            with open(file_path, "rb") as f:
                reader = PyPDF2.PdfReader(f)
                text = ""
                for page in reader.pages:
                    text += page.extract_text() + "\n"
                return text
        except ImportError:
            log.error("PyPDF2 not installed")
            return f"Error: PyPDF2 not installed to read {file_path.name}"

    return ""
