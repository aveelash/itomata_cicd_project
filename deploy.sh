#!/bin/bash -e
export AWS_STS_REGIONAL_ENDPOINTS=regional

echo "Refreshing EKS credentials..."
aws eks update-kubeconfig --region ap-south-1 --name itomata-eks-cluster

# 1. Identify the versions
CURRENT_VERSION=$(kubectl get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")

if [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
    OLD_VERSION="v1"
else
    NEXT_VERSION="v1"
    OLD_VERSION="v2"
fi

echo "Current Live: $CURRENT_VERSION | Deploying Green: $NEXT_VERSION | Deleting Blue: $OLD_VERSION"

# 2. Update Deployment Manifest
sed -i "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml

# 3. Deploy Green (v2) while Blue (v1) is still taking traffic
kubectl apply -f k8s/deployment.yaml

# 4. HEALTH GATE: Wait for Green to be 100% ready before switching
echo "Verifying health of $NEXT_VERSION..."
kubectl rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# 5. THE SWITCH: Update Service to point to Green
sed -i "s/version: v1/version: $NEXT_VERSION/g" k8s/service.yaml
sed -i "s/version: v2/version: $NEXT_VERSION/g" k8s/service.yaml
kubectl apply -f k8s/service.yaml

# 6. CLEANUP: Delete the old version to save AWS Resources/Cost
if [ "$CURRENT_VERSION" != "none" ]; then
    echo "Cleaning up old version ($OLD_VERSION)..."
    kubectl delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

# 7. UPDATE HPA: Tell the autoscaler to watch the NEW live version
echo "Updating HPA to watch $NEXT_VERSION..."
sed -i "s/itomata-app-v1/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml
sed -i "s/itomata-app-v2/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml
kubectl apply -f k8s/hpa.yaml

echo "Company-Grade Blue/Green Deployment Complete!"