# 🎨 AI Image Generator on GKE

This is a hands-on workshop app that runs **Stable Diffusion** on **Google Kubernetes Engine (GKE)**.

## 🚀 Features
- Generate AI images from text prompts
- Runs on GKE (CPU or GPU nodes)
- Scales with Kubernetes deployments

## Prerequisites

Before you begin, you need a GKE cluster. You can create one using the provided script:

**Create a CPU-based GKE cluster:**
```bash
./ai-on-gke-cluster.sh cpu
```

**Or, create a GPU-based GKE cluster (recommended for faster inference):**
```bash
./ai-on-gke-cluster.sh gpu
```
Once the cluster is created, you are ready to proceed with the setup.

## 🛠 Setup

### 1. Build & Push Image
```bash
PROJECT_ID=$(gcloud config get-value project)
docker build -t gcr.io/$PROJECT_ID/ai-image-generator:latest .
docker push gcr.io/$PROJECT_ID/ai-image-generator:latest
```

### 2. Deploy to GKE
```bash
kubectl apply -f k8s/deployment.yaml
```

Get external IP:
```bash
kubectl get svc ai-image-generator-svc
```

Open in browser and try:  
👉 "A Kubestronaut riding a dragon in space"

### 3. Optional: GPU Deployment
If your GKE cluster has GPU nodes:
```bash
kubectl apply -f k8s/gpu-deployment.yaml
```

## 🌍 Demo Ideas
- Show scaling with:
```bash
kubectl scale deployment ai-image-generator --replicas=5
```
- Run multiple prompts at once to see Kubernetes distribute load.