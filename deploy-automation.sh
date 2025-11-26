#!/bin/bash
set -e

echo "🚀 Deploying Kamal + AWS"
echo ""

# Create infrastructure
echo "▶ Creating infrastructure..."
terraform apply -auto-approve

# Get EC2 host
EC2_HOST=$(terraform output -raw instance_public_dns)
AWS_REGION=$(terraform output -raw aws_region)
echo "✓ EC2: $EC2_HOST"
echo ""

# Wait for EC2
echo "▶ Waiting 30s for EC2..."
sleep 30

# Install and configure Docker
echo "▶ Installing Docker..."
ssh -i ~/.ssh/kamal-server-key.pem -o StrictHostKeyChecking=no ubuntu@$EC2_HOST \
    "curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker ubuntu && sudo systemctl restart docker"

# Update deploy.yml
echo "▶ Updating deploy.yml..."
sed -i "/servers:/,/web:/{ n; s/- .*/    - $EC2_HOST/; }" config/deploy.yml

# Deploy with Kamal
echo "▶ Deploying with Kamal..."
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION)
kamal setup

echo ""
echo "✓ Deployed! → http://$EC2_HOST"

