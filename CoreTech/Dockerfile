# Dockerfile for PhytoCare Ultra AI Pathology Service (Google Cloud Run / Firebase Container)
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PORT=8001

WORKDIR /app

# Install minimal OS dependencies for OpenCV and image processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install PyTorch CPU first (clean, optimized wheels)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install application dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    python-multipart \
    pydantic \
    pillow \
    opencv-python-headless \
    timm \
    scikit-learn \
    requests

# Copy project files and trained weights
COPY preprocessing /app/preprocessing
COPY Plant_Identification_Experiment /app/Plant_Identification_Experiment
COPY Plant_Disease_Experiment /app/Plant_Disease_Experiment

WORKDIR /app/Plant_Disease_Experiment

EXPOSE 8001

CMD ["sh", "-c", "uvicorn web.app:app --host 0.0.0.0 --port ${PORT:-8001}"]

