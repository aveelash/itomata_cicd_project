# Itomata Cloud-Native Platform (EKS)
Enterprise-Grade DevSecOps, Automated Scaling & Regional Disaster Recovery
## Executive Summary
The Itomata Project is a production-hardened deployment of a microservices architecture on Amazon EKS (Elastic Kubernetes Service). This platform is engineered to solve three critical business challenges:

**High Availability**: Zero-downtime deployments via Blue-Green/Rolling strategies.

**Cost Efficiency**: Dynamic resource allocation using Horizontal Pod Autoscaling (HPA).

**Business Continuity**: Cross-region Disaster Recovery (DR) between Mumbai (ap-south-1) and Singapore (ap-southeast-1).

### 1. Infrastructure as Code (IaC)
To eliminate "Configuration Drift" and human error, 100% of the infrastructure is managed via Terraform.

Networking: A custom VPC spanning multiple Availability Zones (AZs) to prevent single-point-of-failure at the data center level.

Orchestration: A managed EKS cluster with optimized Node Groups for compute efficiency.

Security: IAM Roles for Service Accounts (IRSA) and private ECR registries to ensure the Principle of Least Privilege.

### 2. CI/CD & Deployment Strategy
We prioritize Uptime. The application is containerized using Docker and deployed with Kubernetes manifests that ensure:

Self-Healing: Containers that fail health checks are automatically restarted.

Safe Rollouts: New versions are only promoted if they pass "Readiness" gates. If a deployment fails, the system maintains the previous stable version.

### 3. Performance & Automated Elasticity
A core feature of this platform is its ability to handle Viral Traffic Spikes without manual intervention.

The Stress Test Scenario:
Steady State: 2 healthy pods running at minimal cost.

Synthetic Load: Executed a multi-threaded load generator (8 parallel streams) to simulate a massive surge in user requests.

The Reaction: The Horizontal Pod Autoscaler (HPA) detected a CPU spike over 50% and instantly scaled the deployment to 10 Replicas.

Cost Savings: Once the load subsided, the cluster automatically "Scaled Down" to 2 pods, ensuring we only pay for the compute power we actually use.

### 4. Global Disaster Recovery (DR) Architecture
We treat "Regional Outages" as a certainty, not a possibility.

Replication: Automated ECR Cross-Region Replication copies our software images from Mumbai to Singapore.

Resilience: In the event of a primary region failure, the entire infrastructure can be redeployed in the recovery region using our Terraform blueprints in under 15 minutes.

### 5. Getting Started (Local Replication)
To run this setup on your local machine, ensure you have AWS CLI, Terraform, and Kubectl installed.

#### Step 1: Provision Infrastructure
`cd terraform`

`terraform init`

`terraform apply -var="region=ap-south-1" -var='azs=["ap-south-1a", "ap-south-1b"]'`

#### Step 2: Connect & Deploy

##### Connect to EKS
`aws eks update-kubeconfig --region ap-south-1 --name itomata-eks-cluster`

##### Deploy Application Stack
`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

`kubectl apply -f ../k8s/deployment.yaml`

`kubectl apply -f ../k8s/service.yaml`

#### Step 3: Trigger Scale-Up (Stress Test)
`kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://itomata-frontend-service; done"`

`kubectl get hpa -w`

#### Step 4: Clean Up (Cost Control)
`terraform destroy -var="region=ap-south-1" -var='azs=["ap-south-1a", "ap-south-1b"]'`

### Tech Stack
Cloud: Amazon Web Services (AWS)

Orchestration: Kubernetes (EKS)

IaC: Terraform

Containers: Docker

Monitoring: Kubernetes Metrics Server

# Developed By
Aveelash Hota

DevOps & Cloud Infrastructure Engineer
