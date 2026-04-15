#!/bin/bash
set -e

# Set the region
REGION="${GCP_REGION:-us-central1}"

# ─── Select GCP Project (same behavior as setup.sh) ──────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:-}"
if [ -n "$PROJECT_ID" ]; then
  echo "  Using project from GCP_PROJECT_ID: $PROJECT_ID"
else
  echo "Fetching your GCP projects..."
  mapfile -t PROJECTS < <(gcloud projects list --format="value(projectId)" 2>/dev/null)

  if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo "❌ No GCP projects found. Make sure you are authenticated:"
    echo "    gcloud auth login"
    exit 1
  fi

  DEFAULT_PROJECT="$(gcloud config get-value project 2>/dev/null)"
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
fi

echo "  Setting gcloud project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" --quiet >/dev/null

# Get first available T4 zone (only needed for gpu/check)
T4_ZONE=$(gcloud compute accelerator-types list --project="$PROJECT_ID" --filter="name:nvidia-tesla-t4 AND zone~${REGION}" --format="value(zone)" | head -1)
ZONE="${T4_ZONE:-${REGION}-b}"

check_gpu_availability() {
  echo "Checking T4 GPU availability in $REGION..."
  ZONES=$(gcloud compute accelerator-types list \
    --project="$PROJECT_ID" \
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
    --project="$PROJECT_ID" \
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
  gcloud services enable compute.googleapis.com container.googleapis.com --project="$PROJECT_ID" --quiet
  echo "Creating CPU GKE cluster in $ZONE..."
  START_TIME=$(date +%s)
  
  if ! gcloud container clusters create ai-on-gke-image-cluster \
    --project="$PROJECT_ID" \
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
  
  gcloud container clusters get-credentials ai-on-gke-image-cluster --project="$PROJECT_ID" --zone="$ZONE"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "CPU cluster created successfully in ${MINUTES}m ${SECONDS}s!"
}

start_gpu() {
  echo "Enabling required Google Cloud APIs..."
  gcloud services enable compute.googleapis.com container.googleapis.com --project="$PROJECT_ID" --quiet

  if [ -z "$T4_ZONE" ]; then
    echo "No T4 GPUs available in $REGION region"
    exit 1
  fi

  echo "Creating GPU GKE cluster in $T4_ZONE..."
  START_TIME=$(date +%s)
  
  if ! gcloud container clusters create ai-on-gke-image-cluster-gpu \
    --project="$PROJECT_ID" \
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
  
  gcloud container clusters get-credentials ai-on-gke-image-cluster-gpu --project="$PROJECT_ID" --zone="$T4_ZONE"
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "GPU cluster created successfully in ${MINUTES}m ${SECONDS}s!"
}

list() {
  echo "Listing clusters in active project: $PROJECT_ID"

  local rows
  rows=$(gcloud container clusters list --project="$PROJECT_ID" --format="value(name,location,status)" 2>/dev/null || true)

  if [ -n "$rows" ]; then
    printf "%-35s %-20s %-12s %-20s\n" "PROJECT" "NAME" "LOCATION" "STATUS"
    printf "%-35s %-20s %-12s %-20s\n" "-------" "----" "--------" "------"
    while IFS=$'\t' read -r name location status; do
      [ -z "$name" ] && continue
      printf "%-35s %-20s %-12s %-20s\n" "$PROJECT_ID" "$name" "$location" "$status"
    done <<< "$rows"
    return
  fi

  echo "No clusters found in active project. Searching other accessible projects..."
  local found_any=0
  printf "%-35s %-20s %-12s %-20s\n" "PROJECT" "NAME" "LOCATION" "STATUS"
  printf "%-35s %-20s %-12s %-20s\n" "-------" "----" "--------" "------"

  while read -r project; do
    [ -z "$project" ] && continue
    [ "$project" = "$PROJECT_ID" ] && continue

    local other_rows
    other_rows=$(gcloud container clusters list --project="$project" --format="value(name,location,status)" 2>/dev/null || true)
    if [ -z "$other_rows" ]; then
      continue
    fi

    found_any=1
    while IFS=$'\t' read -r name location status; do
      [ -z "$name" ] && continue
      printf "%-35s %-20s %-12s %-20s\n" "$project" "$name" "$location" "$status"
    done <<< "$other_rows"
  done < <(gcloud projects list --format="value(projectId)" 2>/dev/null || true)

  if [ "$found_any" -eq 0 ]; then
    echo "No GKE clusters found in any accessible project."
  else
    echo
    echo "Tip: set GCP_PROJECT_ID to the project that contains your cluster before running this script."
  fi
}

stop() {
  echo "Deleting managed clusters in project: $PROJECT_ID"

  local found_any=0
  local rows
  rows=$(gcloud container clusters list --project="$PROJECT_ID" --format="value(name,location)" 2>/dev/null || true)

  while IFS=$'\t' read -r name location; do
    [ -z "$name" ] && continue
    case "$name" in
      ai-on-gke-image-cluster|ai-on-gke-image-cluster-gpu)
        found_any=1
        echo "Deleting cluster: $name ($location)"
        gcloud container clusters delete "$name" --project="$PROJECT_ID" --location="$location" --quiet
        ;;
    esac
  done <<< "$rows"

  if [ "$found_any" -eq 0 ]; then
    echo "No managed clusters found to delete."
  else
    echo "Managed clusters deleted successfully!"
  fi
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