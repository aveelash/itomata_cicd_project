#!/bin/bash -e

echo "🛠️ Configuring direct EKS access for $AWS_DEFAULT_REGION..."

# 1. Wipe stale configs
rm -rf ~/.kube/config
mkdir -p ~/.kube

# 2. Get Cluster Endpoint and Certificate Authority Data
ENDPOINT=$(aws eks describe-cluster --name itomata-eks-cluster --region $AWS_DEFAULT_REGION --query "cluster.endpoint" --output text)
CA_DATA=$(aws eks describe-cluster --name itomata-eks-cluster --region $AWS_DEFAULT_REGION --query "cluster.certificateAuthority.data" --output text)

# 3. Manually construct the kubeconfig
cat <<EOF > ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $CA_DATA
    server: $ENDPOINT
  name: eks-cluster
contexts:
- context:
    cluster: eks-cluster
    user: aws
  name: eks-context
current-context: eks-context
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "itomata-eks-cluster"
        - "--region"
        - "$AWS_DEFAULT_REGION"
EOF

# 4. Use insecure-skip-tls-verify as a fallback for the discovery phase
KUBE="kubectl --insecure-skip-tls-verify=true"

# --- Deployment Logic Starts Here ---

rollback() {
    echo "DEPLOYMENT CRITICAL FAILURE!"
    $KUBE delete deployment itomata-app-$NEXT_VERSION --ignore-not-found=true
    exit 1
}
trap 'rollback' ERR

echo "Checking current version..."
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

echo "Current Live: $CURRENT_VERSION | Deploying: $NEXT_VERSION"

# Apply Deployment
sed "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml > k8s/deployment_tmp.yaml
$KUBE apply -f k8s/deployment_tmp.yaml

# Wait for Health
echo "Waiting for $NEXT_VERSION to be ready..."
$KUBE rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# Switch Traffic
echo "Updating Service to point to $NEXT_VERSION..."
sed "s/version: .*/version: $NEXT_VERSION/g" k8s/service.yaml > k8s/service_tmp.yaml
$KUBE apply -f k8s/service_tmp.yaml

# Cleanup
if [ "$OLD_VERSION" != "none" ] && [ "$OLD_VERSION" != "$NEXT_VERSION" ]; then
    echo "Removing $OLD_VERSION..."
    $KUBE delete deployment itomata-app-$OLD_VERSION --ignore-not-found=true
fi

# Update HPA
echo "Updating HPA..."
sed "s/itomata-app-.*/itomata-app-$NEXT_VERSION/g" k8s/hpa.yaml > k8s/hpa_tmp.yaml
$KUBE apply -f k8s/hpa_tmp.yaml

rm k8s/*_tmp.yaml
echo "🚀 Deployment successful in $AWS_DEFAULT_REGION!"