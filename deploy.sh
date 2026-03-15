#!/bin/bash

# 1. Ask the cluster: "Who is currently getting traffic?"
CURRENT_VERSION=$(kubectl get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}')

# 2. Determine the new version name
if [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
else
    NEXT_VERSION="v1"
fi

echo "Current Live Version: $CURRENT_VERSION"
echo "Deploying New Version: $NEXT_VERSION"

# 3. Replace the placeholder in deployment.yaml with the new version name
# This creates a 'virtual' version of your file for this specific deployment
sed -i "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml

# 4. Deploy the new version (Green) side-by-side with the old one (Blue)
kubectl apply -f k8s/deployment.yaml

# 5. Wait for the new pods to be 100% ready before switching
echo "Waiting for $NEXT_VERSION to be ready..."
kubectl rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# 6. FLIP THE SWITCH: Point the Load Balancer to the new pods
echo "Switching traffic to $NEXT_VERSION..."
kubectl patch svc itomata-frontend-service -p "{\"spec\":{\"selector\":{\"version\":\"$NEXT_VERSION\"}}}"

echo "Blue/Green Deployment Complete! $NEXT_VERSION is now live."