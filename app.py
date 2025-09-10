import streamlit as st
from diffusers import StableDiffusionPipeline
import torch
import time

st.set_page_config(page_title="AI Image Generator", layout="wide")

st.title("🎨 AI Image Generator on GKE")
st.write("Type a prompt and let AI create an image for you!")

# Display GPU info
if torch.cuda.is_available():
    st.success(f"✅ GPU Available: {torch.cuda.get_device_name(0)}")
    st.info(f"CUDA Version: {torch.version.cuda}")
else:
    st.error("❌ No GPU detected - using CPU (slow)")

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
