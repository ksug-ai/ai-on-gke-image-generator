FROM python:3.10-slim

WORKDIR /app

# Copy requirements.txt first to leverage Docker's build cache
COPY requirements.txt .

# Install Python dependencies first, then install CUDA-enabled PyTorch LAST without deps so it isn't overridden
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir --upgrade diffusers && \
    pip install --no-cache-dir --no-deps \
      torch==2.3.1+cu118 torchvision==0.18.1+cu118 torchaudio==2.3.1+cu118 \
      -f https://download.pytorch.org/whl/torch_stable.html

COPY . /app

EXPOSE 8080

CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0"]