FROM python:3.10-slim

WORKDIR /app

# Copy requirements.txt first to leverage Docker's build cache
COPY requirements.txt .

# Install Python dependencies, then CUDA-enabled PyTorch WITH dependencies so CUDA libs (libcudart, etc.) are present
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir --upgrade diffusers && \
    pip install --no-cache-dir \
      torch==2.3.1+cu118 torchvision==0.18.1+cu118 torchaudio==2.3.1+cu118 \
      --index-url https://download.pytorch.org/whl/cu118

COPY . /app

EXPOSE 8080

CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0"]