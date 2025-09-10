FROM python:3.10-slim

WORKDIR /app

# Copy requirements.txt first to leverage Docker's build cache
COPY requirements.txt .

# Install PyTorch and all other Python dependencies in a single layer
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --upgrade diffusers

COPY . /app

EXPOSE 8080

CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0"]