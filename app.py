import streamlit as st
from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline, EulerDiscreteScheduler
import torch
import time
import os
import subprocess
import threading

st.set_page_config(page_title="AI Image Generator", layout="wide")

st.title("🎨 AI Image Generator on GKE by [KSUG.AI](https://ksug.ai)")
st.write("Type a prompt and let AI create an image for you!")

# Model selection (SDXL recommended for photorealism)
MODEL_CHOICES = {
    "SDXL 1.0 Base": "stabilityai/stable-diffusion-xl-base-1.0",
    "Realistic Vision XL (RealVisXL V4.0)": "SG161222/RealVisXL_V4.0",
}
selected_model_label = st.selectbox("Model", list(MODEL_CHOICES.keys()), index=1)
selected_model_id = MODEL_CHOICES[selected_model_label]

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

@st.cache_resource(show_spinner=True)
def load_model(model_id: str):
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    st.write(f"Loading {model_id} on: {device} with dtype: {dtype}")

    # Decide pipeline class: use SDXL pipeline for XL models, SD for SD1.5
    is_sdxl = "xl" in model_id.lower() or "stable-diffusion-xl" in model_id.lower()

    if is_sdxl:
        # Some SDXL repos provide fp16 weights; avoid forcing variant that may not exist
        pipe = StableDiffusionXLPipeline.from_pretrained(
            model_id,
            torch_dtype=dtype,
            use_safetensors=True,
        )
    else:
        pipe = StableDiffusionPipeline.from_pretrained(
            model_id,
            torch_dtype=dtype,
            use_safetensors=True,
        )
    # Use model's default scheduler to avoid indexing issues

    return pipe.to(device)

pipe = load_model(selected_model_id)

prompt = st.text_input("Enter your prompt:", "A kubestronaut riding a dragon in space")
negative_prompt = st.text_input("Negative prompt (optional)", "blurry, low quality, deformed, cartoon, illustration")
steps = st.slider("Inference steps", 10, 50, 25)
guidance = st.slider("Guidance scale", 1.0, 12.0, 5.0)
if "xl" in selected_model_id.lower():
    width = st.select_slider("Width", options=[768, 896, 1024, 1152, 1280], value=1024)
    height = st.select_slider("Height", options=[768, 896, 1024, 1152, 1280], value=1024)
else:
    width = st.select_slider("Width", options=[512, 640, 768], value=512)
    height = st.select_slider("Height", options=[512, 640, 768], value=512)

# Global lock to prevent concurrent generations
if "generation_lock" not in st.session_state:
    st.session_state.generation_lock = threading.Lock()

if st.button("Generate"):
    with st.session_state.generation_lock:
        with st.spinner("Generating image..."):
            # Monitor GPU usage during generation
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                start_memory = torch.cuda.memory_allocated()
                st.write(f"GPU memory before: {start_memory / 1024**3:.2f} GB")
            
            start_time = time.time()
            if isinstance(pipe, StableDiffusionXLPipeline):
                image = pipe(
                    prompt=prompt,
                    negative_prompt=negative_prompt or None,
                    num_inference_steps=int(steps),
                    guidance_scale=float(guidance),
                    height=int(height),
                    width=int(width),
                ).images[0]
            else:
                image = pipe(
                    prompt,
                    negative_prompt=negative_prompt or None,
                    num_inference_steps=int(steps),
                    guidance_scale=float(guidance),
                    height=int(height),
                    width=int(width),
                ).images[0]
            end_time = time.time()
            
            if torch.cuda.is_available():
                end_memory = torch.cuda.memory_allocated()
                st.write(f"GPU memory after: {end_memory / 1024**3:.2f} GB")
                st.write(f"GPU memory used: {(end_memory - start_memory) / 1024**3:.2f} GB")
            
            st.write(f"Generation time: {end_time - start_time:.2f} seconds")
            st.image(image, caption=prompt, use_container_width=True)
