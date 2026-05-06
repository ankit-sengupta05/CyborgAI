# 🚀 Deploying CyborgAI to Hugging Face Spaces

This guide explains how to deploy the entire CyborgAI system (Flutter Web Frontend + Python FastAPI Backend) as a single Hugging Face Space.

## 1. Prepare the Frontend

First, build the Flutter web application:

```bash
flutter build web --web-renderer canvaskit
```

This will generate the compiled web files in `build/web/`.

## 2. Prepare the Hugging Face Repo

Create a new Space on Hugging Face using the **Docker** template.

Copy the following files from your local repository to the Hugging Face repo:

1. `assets/backend/` -> `./backend/`
2. `build/web/` -> `./backend/static/`
3. `Dockerfile.hf` (provided below) -> `Dockerfile`
4. `.huggingface/` -> `.huggingface/` (optional, for Secrets)

## 3. Hugging Face Dockerfile (`Dockerfile.hf`)

Create this file at the root of your Hugging Face space repository:

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl git poppler-utils tesseract-ocr && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the backend code and pre-built frontend
COPY backend/ /app/
# Ensure the static folder exists
RUN mkdir -p /app/static

# Expose the port Hugging Face expects (7860)
EXPOSE 7860
ENV PORT=7860
ENV HOST=0.0.0.0
# Set backend to offline/HF mode
ENV HUGGINGFACE_SPACE=true

CMD ["python", "main.py"]
```

## 4. Environment Variables

In your Hugging Face Space settings, add any necessary Secrets (like API keys if you aren't using local models). Note that Hugging Face free tier does not support GPUs, so local LLM inference will be extremely slow. For best results, configure `settings.py` to use a cloud provider API key when running on HF.

## 5. Enable Web Serving in Backend

The backend is already configured to serve the Flutter web app. When the FastAPI server starts, it checks if the `static/` directory exists. If it does, it mounts it at the root `/` and serves `index.html`.

That's it! Your Space will build and launch, providing the full CyborgAI experience via the web.
