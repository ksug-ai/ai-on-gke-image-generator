# 🎨 AI Image Generator on GKE by [KSUG.AI](https://ksug.ai)

This is a hands-on workshop python app that runs **Stable Diffusion** on **Google Kubernetes Engine (GKE)**.

## 🚀 Features
- Generate AI images from text prompts
- Runs on GKE (CPU or GPU nodes)
- Scales with Kubernetes deployments

**Performance:** GPU is recommended, typically an image can be generated in ~30 seconds with NVIDIA T4. For CPU, it does take 15 mins or much longer.

## Prerequisites

This workshop uses **[Google Cloud Shell](https://shell.cloud.google.com)** — a free, browser-based terminal that comes pre-installed with `gcloud`, `kubectl`, `docker`, and `git`, and is already authenticated to your Google Cloud project. No local setup required.

> [!TIP]
> Open Cloud Shell by clicking the **Activate Cloud Shell** button (>_) in the top-right corner of the [Google Cloud Console](https://console.cloud.google.com), or go directly to [shell.cloud.google.com](https://shell.cloud.google.com).

Clone the repository and navigate into the directory:

```bash
git clone https://github.com/ksug-ai/ai-on-gke-image-generator.git
cd ai-on-gke-image-generator
```

Next, create a GKE cluster with GPU nodes using the provided script:

```bash
./ai-on-gke-cluster.sh gpu
```

**Optional: Create a CPU-based GKE cluster:**
```bash
./ai-on-gke-cluster.sh cpu
```
Once the cluster is created, you are ready to proceed with the setup.

## ⚠️ GPU Quota Pre-check

Google Cloud projects typically start with **zero** GPU quota. Before running the GPU script, you must ensure you have enough quota in your chosen region.

> [!IMPORTANT]
> The cluster script uses **Spot (preemptible) VMs** (`--spot`), which have a **separate quota** from regular VMs. You need to check and request **both** if they are at `0.0`.

### 1. Check your current Quota (CLI)

```bash
REGION=us-central1  # change this if using a different region
gcloud compute regions describe $REGION \
    --flatten="quotas" \
    --format="table(quotas.metric, quotas.limit, quotas.usage)" | grep "NVIDIA_T4_GPUS"
```

This will show two relevant rows:

| Metric | Used for |
|---|---|
| `NVIDIA_T4_GPUS` | Regular (on-demand) VMs |
| `PREEMPTIBLE_NVIDIA_T4_GPUS` | Spot / preemptible VMs (`--spot`) ← **this one** |

If either `LIMIT` is `0.0`, you must request an increase before proceeding.

### 2. Requesting an Increase (Web Console)

> [!NOTE]
> GPU quota increases **cannot be done via CLI** — they require Google's human review and approval (typically within a few hours). Use the direct links below to skip the navigation steps.

👉 **[Request Preemptible T4 GPU Quota](https://console.cloud.google.com/iam-admin/quotas?service=compute.googleapis.com&metric=compute.googleapis.com%2Fpreemptible_nvidia_t4_gpus)** ← needed for `--spot`

👉 **[Request On-demand T4 GPU Quota](https://console.cloud.google.com/iam-admin/quotas?service=compute.googleapis.com&metric=compute.googleapis.com%2Fnvidia_t4_gpus)** ← needed if removing `--spot`

On each page:
1. Select your region from the list.
2. Click **EDIT QUOTAS** and enter `1` as the new limit.
3. Submit — approval is usually granted within a few hours.

> [!NOTE]
> GPU quotas are **not available** on the Google Cloud Free Trial ($300 credit). You must upgrade to a "Paid" account (though you will still have your remaining credits).


## 🛠 Setup

The `setup.sh` script automates everything — creating the Artifact Registry repository, building and pushing the Docker image, and patching the Kubernetes YAML files with your project and region.

```bash
./setup.sh
```

By default it uses your active `gcloud` project and region `us-central1`. Override with environment variables if needed:

```bash
GCP_PROJECT_ID=my-project GCP_REGION=australia-southeast1 ./setup.sh
```

### Deploy to GKE
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
