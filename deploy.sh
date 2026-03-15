#!/bin/bash -e
export AWS_STS_REGIONAL_ENDPOINTS=regional

echo "Refreshing EKS credentials..."
aws eks update-kubeconfig --region ap-south-1 --name itomata-eks-cluster

# 1. Ask the cluster: "Who is currently getting traffic?"
# We add '|| echo "v2"' so that if the service is missing, it defaults to v1 as the "next" version.
CURRENT_VERSION=$(kubectl get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")

# 2. Determine the new version name
if [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
else
    NEXT_VERSION="v1"
fi

echo "Current Live Version: $CURRENT_VERSION"
echo "Deploying New Version: $NEXT_VERSION"

# 3. Replace the placeholder in deployment.yaml
sed -i "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml

# 4. Deploy the new version
kubectl apply -f k8s/deployment.yaml

# 5. Wait for the new pods to be ready
echo "Waiting for $NEXT_VERSION to be ready..."
kubectl rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# 6. FLIP THE SWITCH: Update the Service
# Note: We use 'kubectl apply' for the service too, in case it doesn't exist yet!
sed -i "s/version: v1/version: $NEXT_VERSION/g" k8s/service.yaml
sed -i "s/version: v2/version: $NEXT_VERSION/g" k8s/service.yaml
kubectl apply -f k8s/service.yaml

echo "Blue/Green Deployment Complete! $NEXT_VERSION is now live."