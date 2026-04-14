#!/bin/bash
set -e

# ─── Configuration ────────────────────────────────────────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${GCP_REGION:-us-central1}"
REPO="ai-image-generator"
IMAGE="ai-image-generator"
TAG="latest"
IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE}:${TAG}"

# ─── Validate project ─────────────────────────────────────────────────────────
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
  echo "❌ No GCP project set. Please configure your project first:"
  echo
  echo "    gcloud config set project YOUR_PROJECT_ID"
  echo
  echo "  Or pass it inline:"
  echo
  echo "    GCP_PROJECT_ID=YOUR_PROJECT_ID ./setup.sh"
  echo
  exit 1
fi

echo "============================================"
echo "  AI on GKE - Setup Script"
echo "============================================"
echo "  Project : $PROJECT_ID"
echo "  Region  : $REGION"
echo "  Image   : $IMAGE_PATH"
echo "============================================"
echo

# ─── Step 0: Enable required APIs ────────────────────────────────────────────
echo "▶ Step 0: Enabling required Google Cloud APIs..."
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com --quiet
echo "  ✔ APIs enabled."

# ─── Step 1: Create Artifact Registry repository (skip if exists) ─────────────
echo
echo "▶ Step 1: Creating Artifact Registry repository..."
if gcloud artifacts repositories describe "$REPO" --location="$REGION" --quiet &>/dev/null; then
  echo "  ✔ Repository '$REPO' already exists, skipping."
else
  gcloud artifacts repositories create "$REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="AI Image Generator repository"
  echo "  ✔ Repository created."
fi

# ─── Step 2: Build & push via Cloud Build ────────────────────────────────────
echo
echo "▶ Step 2: Building and pushing image via Cloud Build..."
echo "  (builds and pushes entirely within GCP — no local Docker push needed)"
gcloud builds submit \
  --tag "$IMAGE_PATH" \
  --machine-type=e2-highcpu-8 \
  .
echo "  ✔ Build and push complete."

# ─── Step 5: Patch the Kubernetes YAML files ─────────────────────────────────
echo
echo "▶ Step 5: Patching Kubernetes deployment YAML files..."
for YAML_FILE in k8s/gpu-deployment.yaml k8s/deployment.yaml; do
  if [ -f "$YAML_FILE" ]; then
    sed -i.bak "s|image:.*ai-image-generator.*|image: ${IMAGE_PATH}|g" "$YAML_FILE"
    rm -f "${YAML_FILE}.bak"
    echo "  ✔ Patched $YAML_FILE"
  fi
done

# ─── Done ─────────────────────────────────────────────────────────────────────
echo
echo "============================================"
echo "  ✅ Setup complete!"
echo
echo "  Deploy with:"
echo "    kubectl apply -f k8s/gpu-deployment.yaml   # GPU"
echo "    kubectl apply -f k8s/deployment.yaml        # CPU"
echo
echo "  Get the app URL:"
echo "    echo \"http://\$(kubectl get svc ai-image-generator-gpu-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')\""
echo "============================================"
