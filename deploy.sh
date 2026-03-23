#!/bin/bash -e

echo "🛠️ Hard-resetting EKS configuration for $AWS_DEFAULT_REGION..."

# 1. Clean everything
rm -rf ~/.kube
mkdir -p ~/.kube

# 2. Get the token manually one time
TOKEN=$(aws eks get-token --cluster-name itomata-eks-cluster --region $AWS_DEFAULT_REGION | jq -r '.status.token')
ENDPOINT=$(aws eks describe-cluster --name itomata-eks-cluster --region $AWS_DEFAULT_REGION --query "cluster.endpoint" --output text)

# 3. Create a static config that DOES NOT use 'exec' or 'aws cli'
# This removes the 'server asked for credentials' loop entirely
cat <<EOF > ~/.kube/config
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $ENDPOINT
  name: eks-cluster
contexts:
- context:
    cluster: eks-cluster
    user: codebuild
  name: eks-context
current-context: eks-context
users:
- name: codebuild
  user:
    token: $TOKEN
EOF

# 4. Define the command with global flags to force authentication
KUBE="kubectl --kubeconfig=$HOME/.kube/config --insecure-skip-tls-verify"

# --- Deployment Logic ---
echo "Checking cluster connection..."
# This is the test command - if this fails, the role permissions are the issue
$KUBE version || echo "Connection test failed, but attempting anyway..."

CURRENT_VERSION=$($KUBE get svc itomata-frontend-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none")
NEXT_VERSION="v1"
[ "$CURRENT_VERSION" == "v1" ] && NEXT_VERSION="v2"

echo "Current: $CURRENT_VERSION | Deploying: $NEXT_VERSION"

# APPLY - Using --validate=false to skip the problematic OpenAPI download
sed "s/VERSION_PLACEHOLDER/$NEXT_VERSION/g" k8s/deployment.yaml > k8s/deployment_tmp.yaml
$KUBE apply -f k8s/deployment_tmp.yaml --validate=false

echo "Waiting for rollout..."
$KUBE rollout status deployment/itomata-app-$NEXT_VERSION --timeout=120s

# SWITCH TRAFFIC
sed "s/version: .*/version: $NEXT_VERSION/g" k8s/service.yaml > k8s/service_tmp.yaml
$KUBE apply -f k8s/service_tmp.yaml --validate=false

# CLEANUP
if [ "$CURRENT_VERSION" != "none" ]; then
    $KUBE delete deployment itomata-app-$CURRENT_VERSION --ignore-not-found=true
fi

rm k8s/*_tmp.yaml
echo "🚀 Success in $AWS_DEFAULT_REGION"