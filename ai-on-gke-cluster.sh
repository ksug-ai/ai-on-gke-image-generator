#!/bin/bash

# Set the project ID
PROJECT_ID="ai-on-gke-image-generator"
echo "Setting GCP project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Get first available T4 zone (cached to avoid duplicate API calls)
T4_ZONE=$(gcloud compute accelerator-types list --filter="name:nvidia-tesla-t4 AND zone~us-central1" --format="value(zone)" | head -1)
ZONE="${T4_ZONE:-us-central1-b}"

check_gpu_availability() {
  echo "Checking T4 GPU availability..."
  gcloud compute accelerator-types list --filter="name:nvidia-tesla-t4" --format="value(zone)" | head -5
}

start_cpu() {
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
    --preemptible; then
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
  if [ -z "$T4_ZONE" ]; then
    echo "No T4 GPUs available in us-central1 region"
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
    --preemptible; then
    echo "Failed to create GPU cluster"
    exit 1
  fi
  
  gcloud container clusters get-credentials ai-on-gke-image-cluster-gpu --zone="$T4_ZONE"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "GPU cluster created successfully in $T4_ZONE in ${MINUTES}m ${SECONDS}s!"
}

list() {
  echo "Listing all clusters..."
  gcloud container clusters list --format="table(name,zone,status)"
}

stop() {
  echo "Deleting clusters..."
  # Get all existing clusters and delete them
  gcloud container clusters list --format="value(name,zone)" | while read -r name zone; do
    if [[ "$name" == "ai-on-gke-image-cluster"* ]]; then
      gcloud container clusters delete "$name" --zone="$zone" --quiet 2>/dev/null || true
    fi
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
    exit 1
    ;;
esac