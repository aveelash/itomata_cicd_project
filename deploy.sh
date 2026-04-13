#!/bin/bash
set -e

KUBE="kubectl"

echo "Starting simple deployment..."

echo "Applying backend deployment..."
$KUBE apply -f k8s/backend-deployment.yaml

echo "Applying backend service..."
$KUBE apply -f k8s/backend-service.yaml

echo "Applying frontend deployment..."
$KUBE apply -f k8s/frontend-deployment.yaml

echo "Applying frontend service..."
$KUBE apply -f k8s/frontend-service.yaml

echo "Applying HPA..."
$KUBE apply -f k8s/hpa.yaml

echo "Waiting for backend rollout..."
$KUBE rollout status deployment/itomata-backend --timeout=180s

echo "Waiting for frontend rollout..."
$KUBE rollout status deployment/itomata-frontend --timeout=180s

echo "Deployment successful!"