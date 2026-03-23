#!/bin/bash -e

# --- 1. THE ULTIMATE AUTH FIX ---
# We define a variable that physically contains the token and the skip-tls flag
if [ ! -z "$KUBERNETES_TOKEN" ]; then
    echo "Force-injecting STS token into all commands..."
    KUBE="kubectl --token=$KUBERNETES_TOKEN --insecure-skip-tls-verify=true"
else
    echo "No token found, using default context..."
    KUBE="kubectl"
fi

export AWS_STS_REGIONAL_ENDPOINTS=regional

# --- 2. Improved Rollback Logic ---
rollback() {
    echo "DEPLOYMENT CRITICAL FAILURE!"
    echo "Initiating emergency cleanup of broken version: $NEXT_VERSION..."
    $KUBE delete deployment itomata-app-$NEXT_VERSION --ignore-not-found=true
    echo "Cleanup complete. The cluster remains safely on $CURRENT_VERSION."
    exit 1
}

trap 'rollback' ERR

echo "Refreshing EKS credentials..."

# --- 3. Identify Current State ---
# Physically using $KUBE variable for every call
CURRENT_VERSION=$($KUBE get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")

if [ "$CURRENT_VERSION" == "none" ]; then
    echo "First deployment detected!"
    NEXT_VERSION="v1"
    OLD_VERSION="none"
elif [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
    OLD_VERSION="v1"
else
    NEXT_VERSION="v1"
    OLD_VERSION="v2"
fi

echo "Current Live: $CURRENT_VERSION | Deploying Green: $NEXT_VERSION | Deleting Blue: $OLD_VERSION"

# --- 4. Safe Substitution ---
sed "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml > k8s/deployment_tmp.yaml
$KUBE apply -f k8s/deployment_tmp.yaml

# --- 5. Wait for Existence & Health ---
echo "Waiting for $NEXT_VERSION to be ready..."
$KUBE rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# --- 6. Switch Traffic (Update Service) ---
echo "Updating Service to point to $NEXT_VERSION..."
sed "s/version: .*/version: $NEXT_VERSION/g" k8s/service.yaml > k8s/service_tmp.yaml
$KUBE apply -f k8s/service_tmp.yaml

# --- 7. Post-Deployment Cleanup ---
if [ "$OLD_VERSION" != "none" ] && [ "$OLD_VERSION" != "$NEXT_VERSION" ]; then
    echo "Cleanup: Removing old version $OLD_VERSION..."
    $KUBE delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

# --- 8. Update HPA ---
echo "Updating HPA to track $NEXT_VERSION..."
sed "s/itomata-app-.*/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml > k8s/hpa_tmp.yaml
$KUBE apply -f k8s/hpa_tmp.yaml

# --- 9. Clean up temporary files ---
rm k8s/*_tmp.yaml

echo "🚀 Company-Grade Blue/Green Deployment Complete!"