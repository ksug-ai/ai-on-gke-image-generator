import streamlit as st
from diffusers import StableDiffusionPipeline
import torch

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
        image = pipe(prompt).images[0]
        st.image(image, caption=prompt, use_column_width=True)
