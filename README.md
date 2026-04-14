# 🎨 AI Image Generator on GKE by [KSUG.AI](https://ksug.ai)

This is a hands-on workshop python app that runs **Stable Diffusion** on **Google Kubernetes Engine (GKE)**.

## 🚀 Features
- Generate AI images from text prompts
- Runs on GKE (CPU or GPU nodes)
- Scales with Kubernetes deployments

**Performance:** GPU is recommended, typically an image can be generated in ~30 seconds with NVIDIA T4. For CPU, it does take 15 mins or much longer.

## Prerequisites

Before you begin, ensure you have the following installed on your machine:
- **[Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`)**
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (required for building the container image)

Make sure your Google Cloud SDK is initialized so `gcloud` points to your GCP project:

```bash
gcloud init
```

Next, you need a GKE cluster with GPU nodes. You can create one using the provided script:

```bash
./ai-on-gke-cluster.sh gpu
```

**Optional: Create a CPU-based GKE cluster:**
```bash
./ai-on-gke-cluster.sh cpu
```
Once the cluster is created, you are ready to proceed with the setup.

## ⚠️ GPU Quota Pre-check

Google Cloud projects typically start with **zero** GPU quota. Before running the GPU script, you must ensure you have enough quota in your region (e.g., `us-central1`).

### 1. Check your current Quota (CLI)
Run this command to see your T4 GPU quota:

```bash
gcloud compute regions describe us-central1 \
    --flatten="quotas" \
    --format="table(quotas.metric, quotas.limit, quotas.usage)" | grep "NVIDIA_T4_GPUS"
```

If the `LIMIT` is `0.0`, you **must** request an increase.

### 2. Requesting an Increase (Web Console)
1. Go to **[IAM & Admin > Quotas](https://console.cloud.google.com/iam-admin/quotas)**.
2. Filter by `Metric: nvidia.com/t4_gpus`.
3. Select the region (e.g., `us-central1`).
4. Click **EDIT QUOTAS** at the top.
5. Enter the new limit (e.g., `1`) and submit.

> [!NOTE]
> GPU quotas are **not available** on the Google Cloud Free Trial ($300 credit). You must upgrade to a "Paid" account (though you will still have your remaining credits).


## 🛠 Setup

### 1. Build & Push the Docker Image

Since you are running this in your own Google Cloud project, you need to build the Docker image and push it to your own Artifact Registry.

First, create a repository in Artifact Registry:

```bash
PROJECT_ID=$(gcloud config get-value project)
gcloud artifacts repositories create ai-image-generator --repository-format=docker --location=us-central1 --description="AI Image Generator repository"
```

Then, build and push your image:

```bash
PROJECT_ID=$(gcloud config get-value project)
docker build -t us-docker.pkg.dev/$PROJECT_ID/ai-image-generator/ai-image-generator:latest .
docker push us-docker.pkg.dev/$PROJECT_ID/ai-image-generator/ai-image-generator:latest
```

**Important:** Before moving to the next step, you must update the image reference in the deployment YAML files (`k8s/gpu-deployment.yaml` and `k8s/deployment.yaml`) to match your `$PROJECT_ID`. Change `ai-on-gke-image-generator` in the image path to your actual project ID.

### 2. Deploy to GKE
```bash
kubectl apply -f k8s/gpu-deployment.yaml
```

Get external IP and open in browser:
```bash
echo "http://$(kubectl get svc ai-image-generator-gpu-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

Click the URL above and try:  
👉 "A kubestronaut riding a dragon in space"

**Note:** It might take a few minutes to load_model for the first time use due to the fact of the model size ~8GB, GPU initialization, CUDA kernels warm-up, cold start on GKE.

### 3. Optional: CPU Deployment
If you don't have GPU nodes, you can use the CPU-based deployment:
```bash
kubectl apply -f k8s/deployment.yaml
```

Get external IP and open in browser:
```bash
echo "http://$(kubectl get svc ai-image-generator-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

## 🌍 Demo Ideas
- Show scaling with:
```bash
# For GPU deployment
kubectl scale deployment ai-image-generator-gpu --replicas=2

# For CPU deployment
kubectl scale deployment ai-image-generator-cpu --replicas=2
```
- Run multiple prompts at once to see Kubernetes distribute load.

## 🛠 Tech Stack

**🤖 AI/ML:**
- **Stable Diffusion XL** - AI image generation models
- **PyTorch** - Deep learning framework with CUDA support
- **Diffusers** - Hugging Face library for diffusion models
- **Transformers** - Text encoding and model management

**🖥️ Frontend:**
- **Streamlit** - Python web app framework for UI

**☁️ Cloud Infrastructure:**
- **Google Kubernetes Engine (GKE)** - Managed Kubernetes service
- **NVIDIA T4 GPUs** - Hardware acceleration for AI inference
- **Google Artifact Registry** - Container image storage

**🐳 Containerization:**
- **Docker** - Application containerization
- **Python 3.10** - Runtime environment
- **CUDA 11.8** - GPU computing platform

**⚙️ DevOps:**
- **GitHub Actions** - CI/CD pipeline
- **Kubernetes** - Container orchestration
- **kubectl** - Kubernetes CLI tool
- **gcloud** - Google Cloud CLI

**🔧 Development:**
- **Bash scripting** - Cluster management automation
- **YAML** - Kubernetes configuration
- **Threading** - Concurrent request handling

## Join the KSUG.AI Global Community  
📍 **Meetups Around the World!**  
📢 **Follow Us:** [https://github.com/ksug-ai](https://github.com/ksug-ai)  
🌐 **Website:** [https://ksug.ai](https://ksug.ai/?ref=workshop)  
