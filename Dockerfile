FROM pytorch/pytorch:2.3.1-cuda11.8-cudnn8-runtime

WORKDIR /app

# Ensure CUDA runtime libs are discoverable at runtime
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# Copy requirements.txt first to leverage Docker's build cache
COPY requirements.txt .

# Install Python dependencies (torch is already provided in base image with CUDA 11.8)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY . /app

# Pre-download all models at build time so the container never hits Hugging Face
# at runtime (avoids firewall/network issues in restricted environments).
# Models are cached to the default HuggingFace cache dir: /root/.cache/huggingface
RUN python - <<'EOF'
from huggingface_hub import snapshot_download
models = [
    "stabilityai/stable-diffusion-xl-base-1.0",
    "SG161222/RealVisXL_V4.0",
]
for model_id in models:
    print(f"Pre-downloading {model_id}...")
    snapshot_download(repo_id=model_id)
    print(f"Done: {model_id}")
EOF

EXPOSE 8080

CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0"]