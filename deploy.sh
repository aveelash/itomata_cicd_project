#!/bin/bash -e

KUBE="kubectl"

echo "Running Blue/Green deployment in $AWS_DEFAULT_REGION"

rollback() {
    echo "DEPLOYMENT CRITICAL FAILURE!"
    if [ ! -z "$NEXT_VERSION" ]; then
        $KUBE delete deployment itomata-app-$NEXT_VERSION --ignore-not-found=true
    fi
    exit 1
}

trap 'rollback' ERR

CURRENT_VERSION=$($KUBE get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")

if [ "$CURRENT_VERSION" == "none" ]; then
    echo "First-time deployment detected!"
    NEXT_VERSION="v1"
    OLD_VERSION="none"
elif [ "$CURRENT_VERSION" == "v1" ]; then
    NEXT_VERSION="v2"
    OLD_VERSION="v1"
else
    NEXT_VERSION="v1"
    OLD_VERSION="v2"
fi

echo "Current Live (Blue): $CURRENT_VERSION"
echo "Deploying New (Green): $NEXT_VERSION"

echo "Applying Kubernetes Deployment for $NEXT_VERSION..."
sed "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml > k8s/deployment_tmp.yaml
$KUBE apply -f k8s/deployment_tmp.yaml

echo "Waiting for $NEXT_VERSION to be ready..."
$KUBE rollout status deployment/itomata-app-$NEXT_VERSION --timeout=180s

echo "Updating Service to point to $NEXT_VERSION..."
sed "s/version: .*/version: $NEXT_VERSION/g" k8s/service.yaml > k8s/service_tmp.yaml
$KUBE apply -f k8s/service_tmp.yaml

if [ "$OLD_VERSION" != "none" ]; then
    echo "Cleanup: Removing old version $OLD_VERSION..."
    $KUBE delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

echo "Updating HPA to track $NEXT_VERSION..."
sed "s/itomata-app-.*/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml > k8s/hpa_tmp.yaml
$KUBE apply -f k8s/hpa_tmp.yaml

rm k8s/*_tmp.yaml

echo "Blue/Green Deployment successful!"