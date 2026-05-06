# --- Stage 1: Build Flutter Web ---
FROM debian:latest AS flutter-builder

RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor
RUN flutter config --enable-web

WORKDIR /app
COPY . .
RUN flutter build web --release

# --- Stage 2: Final Backend Server ---
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy backend code
COPY assets/backend /app/backend

# Copy built flutter web app to backend static folder
COPY --from=flutter-builder /app/build/web /app/backend/static

# Install dependencies
WORKDIR /app/backend
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir uvicorn fastapi structlog langchain-openai langgraph

# Set up environment for llama-cpp-python with CUDA
ENV CMAKE_ARGS="-DLLAMA_CUBLAS=on"
RUN pip install llama-cpp-python --force-reinstall --upgrade --no-cache-dir

# Expose port (HF Space default)
EXPOSE 7860
ENV PORT=7860
ENV HOST=0.0.0.0

CMD ["python3", "main.py"]
