import streamlit as st
from diffusers import StableDiffusionPipeline
import torch
import time
import os
import subprocess

st.set_page_config(page_title="AI Image Generator", layout="wide")

st.title("🎨 AI Image Generator on GKE")
st.write("Type a prompt and let AI create an image for you!")

# Display GPU info
torch_version = getattr(torch, "__version__", "unknown")
cuda_version = getattr(torch.version, "cuda", None)
is_cuda_available = torch.cuda.is_available()

if is_cuda_available:
    st.success(f"✅ GPU Available: {torch.cuda.get_device_name(0)}")
    st.info(f"CUDA Version (torch): {cuda_version}")
else:
    st.error("❌ No GPU detected - using CPU (slow)")

with st.expander("GPU diagnostics"):
    st.write({
        "torch_version": torch_version,
        "torch_cuda_version": cuda_version,
        "torch_cuda_available": is_cuda_available,
        "device_count": torch.cuda.device_count(),
    })
    if is_cuda_available:
        props = torch.cuda.get_device_properties(0)
        st.write({
            "device_name": props.name,
            "total_memory_bytes": props.total_memory,
            "multi_processor_count": props.multi_processor_count,
        })
    # Show relevant env vars that the NVIDIA device plugin usually injects
    env_snapshot = {k: v for k, v in os.environ.items() if k.startswith("NVIDIA_") or k in ("LD_LIBRARY_PATH", "PATH")}
    st.write({"env": env_snapshot})
    # Try nvidia-smi if available
    try:
        smi_output = subprocess.check_output(["nvidia-smi"], text=True)
        st.text(smi_output)
    except Exception as e:
        st.write(f"nvidia-smi not available or failed: {e}")

@st.cache_resource
def load_model():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    st.write(f"Loading model on: {device} with dtype: {dtype}")
    return StableDiffusionPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5", torch_dtype=dtype
    ).to(device)

pipe = load_model()

prompt = st.text_input("Enter your prompt:", "A Kubestronaut riding a dragon in space")

if st.button("Generate"):
    with st.spinner("Generating image..."):
        # Monitor GPU usage during generation
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            start_memory = torch.cuda.memory_allocated()
            st.write(f"GPU memory before: {start_memory / 1024**3:.2f} GB")
        
        start_time = time.time()
        image = pipe(prompt).images[0]
        end_time = time.time()
        
        if torch.cuda.is_available():
            end_memory = torch.cuda.memory_allocated()
            st.write(f"GPU memory after: {end_memory / 1024**3:.2f} GB")
            st.write(f"GPU memory used: {(end_memory - start_memory) / 1024**3:.2f} GB")
        
        st.write(f"Generation time: {end_time - start_time:.2f} seconds")
        st.image(image, caption=prompt, use_column_width=True)
