# Multi-Server Deployment with Kamal

This guide explains how to deploy your application to multiple EC2 instances simultaneously using Kamal, enabling horizontal scaling and high availability.

## Overview

Kamal supports deploying to multiple servers in parallel, allowing you to:

- Scale horizontally by adding more servers
- Achieve high availability across multiple instances
- Deploy updates to all servers simultaneously
- Manage multiple servers from a single configuration

## Prerequisites

- Multiple EC2 instances running and accessible
- Ubuntu 24.04 LTS or similar Linux distribution on all instances
- SSH access configured for all servers
- ECR repository for Docker images
- Kamal installed locally
- AWS CLI configured with proper credentials

## Configure Multiple Servers

Update `config/deploy.yml` to include multiple server addresses:

```yaml
service: your-app

servers:
  web:
    - ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
    - ec2-YY-YYY-YY-YY.compute-1.amazonaws.com
    - ec2-ZZ-ZZZ-ZZ-ZZ.compute-1.amazonaws.com

registry:
  server: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
  username: AWS
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  arch: amd64

ssh:
  user: ubuntu
  keys:
    - ~/.ssh/your-server-key.pem
```

## Get Server Addresses

Retrieve the DNS names of all running instances:

```bash
# List all running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicDnsName' \
  --output text | tr '\t' '\n'

# List with instance details
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicDnsName,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Filter by specific tag
aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=web" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicDnsName' \
  --output text | tr '\t' '\n'
```

## Update deploy.yml with Server Addresses

Copy the server addresses from the AWS CLI output to your `config/deploy.yml`:

```bash
# Get server addresses
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].PublicDnsName' \
  --output text | tr '\t' '\n'
```

Manually add them to `config/deploy.yml` under the servers section.

## Install Docker on All Servers

Before first deployment, ensure Docker is installed on all instances:

```bash
# Using Kamal to run commands on all servers
kamal app exec 'curl -fsSL https://get.docker.com | sudo sh'
kamal app exec 'sudo usermod -aG docker ubuntu'
kamal app exec 'sudo systemctl restart docker'
kamal app exec 'sudo chmod 666 /var/run/docker.sock'
```

Or install manually via SSH on each server:

```bash
# Connect to each server
ssh -i ~/.ssh/your-server-key.pem ubuntu@ec2-XX-XXX-XX-XX.compute-1.amazonaws.com

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo systemctl restart docker

# Exit and reconnect for group changes to take effect
exit
```

## Deploy to All Servers

Deploy your application to all servers simultaneously:

```bash
# Set ECR password
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)

# Initial setup (first deployment)
kamal setup

# Subsequent deployments
kamal deploy
```

## Deployment Process

When you run `kamal deploy`, it performs these steps on all servers in parallel:

1. **Build**: Creates Docker image locally
2. **Push**: Uploads image to ECR registry
3. **Pull**: Downloads image on all servers simultaneously
4. **Deploy**: Starts containers on all servers
5. **Health Check**: Verifies deployment success

## Verify Deployment

Check deployment status across all servers:

```bash
# View running containers on all servers
kamal app containers

# View detailed information
kamal app details

# Check application version
kamal app version

# View logs from all servers
kamal app logs

# View logs with live tail
kamal app logs --tail 50
```

## Test Each Server

Access each server individually to verify deployment:

```bash
# Test each server
curl http://ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
curl http://ec2-YY-YYY-YY-YY.compute-1.amazonaws.com
curl http://ec2-ZZ-ZZZ-ZZ-ZZ.compute-1.amazonaws.com

# Or open in browser
# http://ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
```

## Manage Specific Servers

Execute commands on specific servers:

```bash
# Deploy to specific servers only
kamal deploy --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com,ec2-YY-YYY-YY-YY.compute-1.amazonaws.com

# View logs from specific server
kamal app logs --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com

# Execute command on specific server
kamal app exec --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com 'df -h'

# Restart specific server
kamal app restart --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
```

## View Available Images

Check which Docker images are available on each server:

```bash
# List all images on all servers
kamal app images
```

Example output:
```
App Host: ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
IMAGE                                                      ID             DISK USAGE
your-registry/your-app:abc123def                          f5ceefbd2c44   825MB
your-registry/your-app:xyz789ghi                          4f7e213962b9   825MB
your-registry/your-app:latest                             6f2c227c65ad   825MB
```

## Version Tagging

### Default: Git Commit SHA

By default, Kamal uses the Git commit SHA as the image tag:

```
your-registry/your-app:4a597ce193a3eb044f2b1621f25689d7547160f8
```

**Important**: You must commit changes before deploying for them to be included in the image.

## Health Checks

Configure health checks to ensure successful deployments:

```yaml
healthcheck:
  path: /up
  port: 80
  max_attempts: 7
  interval: 5s
  timeout: 5s
```

Kamal will verify each server responds successfully before considering the deployment complete.

## Monitoring and Maintenance

### View Server Status

```bash
# Check all servers
kamal app details

# View resource usage on specific server
kamal app exec --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com 'df -h'
kamal app exec --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com 'free -h'
kamal app exec --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com 'docker stats --no-stream'
```

### Clean Up Old Images

Remove old Docker images to free up disk space:

```bash
# Remove unused images on all servers
kamal app remove-images

# Remove specific image version
kamal app remove --version <commit-sha>
```

### Restart Servers

```bash
# Restart all servers
kamal app restart

# Restart specific servers
kamal app restart --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com

# Restart specific role
kamal app restart --roles worker
```

## Troubleshooting

### Server Not Responding

Check if the container is running:
```bash
kamal app containers --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
```

View logs for errors:
```bash
kamal app logs --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com --tail 100
```

### Deployment Stuck

Check SSH connectivity:
```bash
ssh -i ~/.ssh/your-server-key.pem ubuntu@ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
```

Verify Docker is running:
```bash
kamal app exec --hosts ec2-XX-XXX-XX-XX.compute-1.amazonaws.com 'docker ps'
```

### Image Not Found

Verify ECR authentication:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

Check if image exists in registry:
```bash
aws ecr describe-images --repository-name your-app
```

### Different Versions on Different Servers

This shouldn't happen with `kamal deploy`, but if it does:
```bash
# Check version on each server
kamal app version

# Force redeploy to all servers
kamal app remove
kamal deploy
```

