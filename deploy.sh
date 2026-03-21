#!/bin/bash -e
export AWS_STS_REGIONAL_ENDPOINTS=regional

rollback() {
    echo "DEPLOYMENT CRITICAL FAILURE!"
    echo "Initiating emergency cleanup of broken version: $NEXT_VERSION..."
    # Delete the new (failed) deployment so it doesn't waste resources or cause confusion
    kubectl delete deployment itomata-app-$NEXT_VERSION --ignore-not-found=true
    echo "Cleanup complete. The cluster remains safely on $CURRENT_VERSION."
    exit 1
}

trap 'rollback' ERR

echo "Refreshing EKS credentials..."
# aws eks update-kubeconfig --region ap-south-1 --name itomata-eks-cluster


CURRENT_VERSION=$(kubectl get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")

if [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
    OLD_VERSION="v1"
else
    NEXT_VERSION="v1"
    OLD_VERSION="v2"
fi

echo "Current Live: $CURRENT_VERSION | Deploying Green: $NEXT_VERSION | Deleting Blue: $OLD_VERSION"

sed -i "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml

kubectl apply -f k8s/deployment.yaml

echo "Verifying health of $NEXT_VERSION..."
sleep 15
kubectl rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

sed -i "s/version: v1/version: $NEXT_VERSION/g" k8s/service.yaml
sed -i "s/version: v2/version: $NEXT_VERSION/g" k8s/service.yaml
kubectl apply -f k8s/service.yaml

if [ "$CURRENT_VERSION" != "none" ]; then
    echo "Cleanup: Removing $OLD_VERSION..."
    kubectl delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

echo "Updating HPA to watch $NEXT_VERSION..."
sed -i "s/itomata-app-v1/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml
sed -i "s/itomata-app-v2/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml
kubectl apply -f k8s/hpa.yaml

echo "Company-Grade Blue/Green Deployment Complete!"