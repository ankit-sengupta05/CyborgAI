# Cyborg Backend Dockerfile
# Multi-stage build for optimized image size and security

# ─── Stage 1: Build Environment ──────────────────────────────────────────────
FROM python:3.10-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements first for better caching
COPY assets/backend/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: Runtime Environment ────────────────────────────────────────────
FROM python:3.10-slim as runtime

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    APP_HOME=/app \
    PORT=8765 \
    HOST=0.0.0.0

WORKDIR $APP_HOME

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    libssl \
    libffi2 \
    # For file processing
    poppler-utils \
    # For OCR
    tesseract-ocr \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user for security
RUN groupadd --gid 1000 cyborg && \
    useradd --uid 1000 --gid cyborg --shell /bin/bash --create-home cyborg

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY --chown=cyborg:cyborg assets/backend/ ./

# Create necessary directories
RUN mkdir -p config models data/vault logs && \
    chown -R cyborg:cyborg /app

# Switch to non-root user
USER cyborg

# Expose port
EXPOSE ${PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/v1/health || exit 1

# Default command
CMD ["python", "main.py"]
