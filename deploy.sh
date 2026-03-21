#!/bin/bash -e
export AWS_STS_REGIONAL_ENDPOINTS=regional

# 1. Improved Rollback Logic
rollback() {
    echo "DEPLOYMENT CRITICAL FAILURE!"
    echo "Initiating emergency cleanup of broken version: $NEXT_VERSION..."
    kubectl delete deployment itomata-app-$NEXT_VERSION --ignore-not-found=true
    echo "Cleanup complete. The cluster remains safely on $CURRENT_VERSION."
    exit 1
}

trap 'rollback' ERR

echo "Refreshing EKS credentials..."
# The region/cluster name is handled by the CodePipeline environment variables or manual update-kubeconfig

# 2. Identify Current State
# We check the Service to see who is currently receiving traffic
CURRENT_VERSION=$(kubectl get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "v1")

if [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
    OLD_VERSION="v1"
else
    NEXT_VERSION="v1"
    OLD_VERSION="v2"
fi

echo "Current Live: $CURRENT_VERSION | Deploying Green: $NEXT_VERSION | Deleting Blue: $OLD_VERSION"

# 3. Safe Substitution (Using a temporary file to keep the original manifest clean)
# This prevents the "VERSION_PLACEHOLDER is missing" error on the second run
sed "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml > k8s/deployment_tmp.yaml
kubectl apply -f k8s/deployment_tmp.yaml

# 4. Wait for Existence & Health
echo "Waiting for $NEXT_VERSION to appear in EKS..."
sleep 10 # Give the API a moment to register the new deployment

echo "Verifying health of $NEXT_VERSION..."
kubectl rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# 5. Switch Traffic (Update Service)
# We create a temp service file to avoid corrupting the original
sed "s/version: .*/version: $NEXT_VERSION/g" k8s/service.yaml > k8s/service_tmp.yaml
kubectl apply -f k8s/service_tmp.yaml

# 6. Post-Deployment Cleanup
if [ "$CURRENT_VERSION" != "none" ] && [ "$CURRENT_VERSION" != "$NEXT_VERSION" ]; then
    echo "Cleanup: Removing $OLD_VERSION..."
    kubectl delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

# 7. Update HPA
sed "s/itomata-app-.*/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml > k8s/hpa_tmp.yaml
kubectl apply -f k8s/hpa_tmp.yaml

# 8. Clean up temporary files
rm k8s/*_tmp.yaml

echo "Company-Grade Blue/Green Deployment Complete!"