#!/bin/bash

CLUSTER_NAME="ai-on-gke-image-cluster"
ZONE="us-central1-a"

start() {
  echo "Creating GKE cluster..."
  gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=1 \
    --machine-type=e2-standard-2 \
    --disk-size=50GB
  
  gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
  echo "Cluster created successfully!"
}

stop() {
  echo "Deleting GKE cluster..."
  gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet
  echo "Cluster deleted successfully!"
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac