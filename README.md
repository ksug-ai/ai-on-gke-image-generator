# 🎨 AI Image Generator on GKE

This is a hands-on workshop app that runs **Stable Diffusion** on **Google Kubernetes Engine (GKE)**.

## 🚀 Features
- Generate AI images from text prompts
- Runs on GKE (CPU or GPU nodes)
- Scales with Kubernetes deployments

## Prerequisites

Before you begin, you need a GKE cluster with GPU nodes. You can create one using the provided script:

```bash
./ai-on-gke-cluster.sh gpu
```

**Optional: Create a CPU-based GKE cluster:**
```bash
./ai-on-gke-cluster.sh cpu
```
Once the cluster is created, you are ready to proceed with the setup.

## 🛠 Setup

### 1. Deploy to GKE
```bash
kubectl apply -f k8s/gpu-deployment.yaml
```

Get external IP and open in browser:
```bash
echo "http://$(kubectl get svc ai-image-generator-gpu-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

Click the URL above and try:  
👉 "A Kubestronaut riding a dragon in space"

### 2. Optional: CPU Deployment
If you don't have GPU nodes, you can use the CPU-based deployment:
```bash
kubectl apply -f k8s/deployment.yaml
```

Get external IP and open in browser:
```bash
echo "http://$(kubectl get svc ai-image-generator-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

### 3. Optional: Build & Push Your Own Image

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

## 🌍 Demo Ideas
- Show scaling with:
```bash
kubectl scale deployment ai-image-generator --replicas=5
```
- Run multiple prompts at once to see Kubernetes distribute load.