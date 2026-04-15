#!/bin/bash
set -e

# ─── Configuration ────────────────────────────────────────────────────────────
REGION="${GCP_REGION:-us-central1}"
REPO="ai-image-generator"
IMAGE="ai-image-generator"
TAG="latest"

# ─── Select GCP Project ───────────────────────────────────────────────────────
echo "Fetching your GCP projects..."
mapfile -t PROJECTS < <(gcloud projects list --format="value(projectId)" 2>/dev/null)

if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "❌ No GCP projects found. Make sure you are authenticated:"
  echo "    gcloud auth login"
  exit 1
fi

# Determine the default: prefer GCP_PROJECT_ID env var, then active gcloud project
DEFAULT_PROJECT="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
DEFAULT_IDX=1
for i in "${!PROJECTS[@]}"; do
  if [ "${PROJECTS[$i]}" = "$DEFAULT_PROJECT" ]; then
    DEFAULT_IDX=$((i+1))
    break
  fi
done

echo
echo "Available GCP projects:"
for i in "${!PROJECTS[@]}"; do
  if [ "${PROJECTS[$i]}" = "$DEFAULT_PROJECT" ]; then
    printf "  [%d] %s  ← default\n" "$((i+1))" "${PROJECTS[$i]}"
  else
    printf "  [%d] %s\n" "$((i+1))" "${PROJECTS[$i]}"
  fi
done
echo

while true; do
  read -rp "Select a project [${DEFAULT_IDX}]: " SELECTION
  SELECTION="${SELECTION:-$DEFAULT_IDX}"
  if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#PROJECTS[@]}" ]; then
    PROJECT_ID="${PROJECTS[$((SELECTION-1))]}"
    break
  fi
  echo "  ⚠️  Invalid selection. Enter a number between 1 and ${#PROJECTS[@]}."
done

echo
echo "  Selected project: $PROJECT_ID"
read -rp "  Confirm? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE}:${TAG}"

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
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com --quiet
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

# ─── Step 2: Configure Docker auth & build + push image ──────────────────────
echo
echo "▶ Step 2: Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
echo "  ✔ Docker configured."

echo
echo "▶ Step 3: Building Docker image..."
docker build -t "$IMAGE_PATH" .
echo "  ✔ Build complete."

echo
echo "▶ Step 4: Pushing image to Artifact Registry..."
docker push "$IMAGE_PATH"
echo "  ✔ Push complete."

# ─── Step 5: Patch the Kubernetes YAML files ─────────────────────────────────
echo
echo "▶ Step 5: Patching Kubernetes deployment YAML files..."
for YAML_FILE in k8s/gpu-deployment.yaml k8s/deployment.yaml; do
  if [ -f "$YAML_FILE" ]; then
    sed -i.bak "s|PROJECT_ID|${PROJECT_ID}|g; s|us-central1-docker.pkg.dev|${REGION}-docker.pkg.dev|g" "$YAML_FILE"
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
