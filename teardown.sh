#!/bin/bash
set -e

echo "🗑️  Tearing down Kamal + AWS"
echo ""

# Check if infrastructure exists
if ! terraform output -raw instance_public_dns &>/dev/null; then
    echo "⚠ No infrastructure found"
    exit 0
fi

EC2_HOST=$(terraform output -raw instance_public_dns)
AWS_REGION=$(terraform output -raw aws_region)

# Confirm
echo "⚠ WARNING: This will destroy all resources!"
echo "  EC2: $EC2_HOST"
echo ""
read -p "Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "✗ Cancelled"
    exit 0
fi

# Remove Kamal deployment
echo "▶ Removing Kamal deployment..."
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION)
kamal remove

# Destroy infrastructure
echo "▶ Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "✓ All resources destroyed!"
