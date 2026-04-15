#!/bin/bash
set -e

# Set the region
REGION="${GCP_REGION:-us-central1}"

# ─── Resolve GCP Project (no interactive prompt — run setup.sh first) ─────────
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
if [ -z "$PROJECT_ID" ]; then
  echo "❌ No GCP project set. Run ./setup.sh first, or set GCP_PROJECT_ID."
  exit 1
fi
echo "  Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" --quiet >/dev/null

# Get first available T4 zone (only needed for gpu/check)
T4_ZONE=$(gcloud compute accelerator-types list --filter="name:nvidia-tesla-t4 AND zone~${REGION}" --format="value(zone)" | head -1)
ZONE="${T4_ZONE:-${REGION}-b}"

check_gpu_availability() {
  echo "Checking T4 GPU availability in $REGION..."
  ZONES=$(gcloud compute accelerator-types list \
    --filter="name:nvidia-tesla-t4 AND zone~${REGION}" \
    --format="value(zone)" | sort -u)
  if [ -z "$ZONES" ]; then
    echo "  ❌ No T4 GPUs found in $REGION"
  else
    echo "  ✔ T4 GPUs available in zones:"
    echo "$ZONES" | sed 's/^/    /'
  fi

  echo
  echo "Checking GPU Quota in $REGION..."
  printf "  %-40s %8s %8s\n" "METRIC" "LIMIT" "USAGE"
  printf "  %-40s %8s %8s\n" "------" "-----" "-----"
  gcloud compute regions describe "$REGION" \
    --flatten="quotas" \
    --format="value(quotas.metric, quotas.limit, quotas.usage)" \
    | grep "NVIDIA_T4_GPUS" \
    | while IFS=$'\t' read -r metric limit usage; do
        printf "  %-40s %8s %8s\n" "$metric" "$limit" "$usage"
        if [[ "$limit" == "0.0" || "$limit" == "0" ]]; then
          echo "  ⚠️  $metric limit is 0 — request a quota increase at:"
          echo "      https://console.cloud.google.com/iam-admin/quotas"
        fi
      done
}

start_cpu() {
  echo "Enabling required Google Cloud APIs..."
  gcloud services enable compute.googleapis.com container.googleapis.com --quiet
  echo "Creating CPU GKE cluster in $ZONE..."
  START_TIME=$(date +%s)
  
  if ! gcloud container clusters create ai-on-gke-image-cluster \
    --zone="$ZONE" \
    --num-nodes=1 \
    --machine-type=e2-standard-4 \
    --disk-size=50GB \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=3 \
    --spot; then
    echo "Failed to create CPU cluster"
    exit 1
  fi
  
  gcloud container clusters get-credentials ai-on-gke-image-cluster --zone="$ZONE"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "CPU cluster created successfully in ${MINUTES}m ${SECONDS}s!"
}

start_gpu() {
  echo "Enabling required Google Cloud APIs..."
  gcloud services enable compute.googleapis.com container.googleapis.com --quiet

  if [ -z "$T4_ZONE" ]; then
    echo "No T4 GPUs available in $REGION region"
    exit 1
  fi

  echo "Creating GPU GKE cluster in $T4_ZONE..."
  START_TIME=$(date +%s)
  
  if ! gcloud container clusters create ai-on-gke-image-cluster-gpu \
    --zone="$T4_ZONE" \
    --num-nodes=1 \
    --machine-type=n1-standard-4 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=2 \
    --spot; then
    echo "Failed to create GPU cluster"
    exit 1
  fi
  
  gcloud container clusters get-credentials ai-on-gke-image-cluster-gpu --zone="$T4_ZONE"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "GPU cluster created successfully in ${MINUTES}m ${SECONDS}s!"
}

list() {
  echo "Listing all clusters..."
  gcloud container clusters list --format="table(name,zone,status)"
}

stop() {
  echo "Deleting clusters..."
  # Get all existing clusters matching the pattern and delete them
  gcloud container clusters list --filter="name ~ ai-on-gke-image-cluster" --format="value(name,zone)" | while read -r name zone; do
    gcloud container clusters delete "$name" --zone="$zone" --quiet
  done
  echo "Clusters deleted successfully!"
}

case "$1" in
  cpu)
    start_cpu
    ;;
  gpu)
    start_gpu
    ;;
  check)
    check_gpu_availability
    ;;
  list)
    list
    ;;
  stop)
    stop
    ;;
  *)
    echo "Usage: $0 {cpu|gpu|check|list|stop}"
    echo "  cpu   - Create CPU cluster (slow inference)"
    echo "  gpu   - Create GPU cluster (fast inference)"
    echo "  check - Check T4 GPU availability"
    echo "  list  - List all clusters"
    echo "  stop  - Delete all clusters"
    echo
    echo "Configuration:"
    echo "  GCP_PROJECT_ID - GCP Project ID (default: \$(gcloud config get-value project))"
    echo "  GCP_REGION     - GCP Region (default: us-central1)"
    exit 1
    ;;
esac