# Deploy with GitHub Actions

This project is configured to automatically deploy to AWS using Kamal every time you push to the `main` branch.

## Prerequisites

Before setting up the deployment workflow, ensure you have:

- AWS account with access to ECR and EC2
- Running Ubuntu 24.04 EC2 instance
- ECR repository created (for Docker images)
- SSH key pair for EC2 instance access
- Rails application with Kamal configured (`config/deploy.yml`)

## GitHub Actions Workflow

The deployment is automated through `.github/workflows/deploy.yml` which handles the entire deployment process.

## Configure Secrets in GitHub

Go to your repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add the following secrets:

### 1. AWS_ACCESS_KEY_ID
Your AWS Access Key ID with ECR permissions.

```bash
# Get from AWS IAM Console or run:
aws configure get aws_access_key_id
```

### 2. AWS_SECRET_ACCESS_KEY
Your AWS Secret Access Key.

```bash
# Get from AWS IAM Console or run:
aws configure get aws_secret_access_key
```

### 3. SSH_PRIVATE_KEY
The SSH private key to connect to the EC2 instance.

```bash
# Show the content of your private key:
cat ~/.ssh/your-private-key.pem

# Copy ALL content including:
# -----BEGIN RSA PRIVATE KEY-----
# ...
# -----END RSA PRIVATE KEY-----
```

### 4. RAILS_MASTER_KEY
The Rails master key to decrypt credentials.

```bash
# Show the content:
cat config/master.key

# Example: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

### 5. EC2_HOST
The public hostname of your EC2 instance.

```bash
# Get from AWS Console or CLI:
aws ec2 describe-instances --query 'Reservations[*].Instances[*].PublicDnsName' --output text

# Example: ec2-XX-XXX-XX-XX.compute-1.amazonaws.com
```

## How the Workflow Works

The workflow defined in `.github/workflows/deploy.yml` triggers automatically when you push to the `main` branch.

### Workflow Steps Breakdown

The workflow executes the following steps:

1. **Checkout code** (`actions/checkout@v4`)
   - Clones your repository code

2. **Setup Ruby** (`ruby/setup-ruby@v1`)
   - Installs Ruby version from `.ruby-version`
   - Caches bundler dependencies

3. **Install Kamal**
```yaml
- name: Install Kamal
  run: gem install kamal
```

4. **Configure AWS credentials** (`aws-actions/configure-aws-credentials@v4`)
   - Sets up AWS access using secrets
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

5. **Login to Amazon ECR** (`aws-actions/amazon-ecr-login@v2`)
   - Authenticates with ECR for Docker operations
```yaml
- name: Login to Amazon ECR
  id: login-ecr
  uses: aws-actions/amazon-ecr-login@v2
```

6. **Setup SSH key**
   - Configures SSH for server access
   - Disables strict host key checking
```yaml
- name: Setup SSH key
  run: |
    mkdir -p ~/.ssh
    echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/your-key.pem
    chmod 600 ~/.ssh/your-key.pem
```

7. **Setup master key**
   - Configures Rails credentials
```yaml
- name: Setup master key
  run: echo "${{ secrets.RAILS_MASTER_KEY }}" > config/master.key
```

8. **Update deploy.yml**
   - Updates server hostname dynamically
```yaml
- name: Update deploy.yml with EC2 host
  run: |
    sed -i "/servers:/,/web:/{ n; s/- .*/    - ${{ secrets.EC2_HOST }}/; }" config/deploy.yml
```

9. **Install Docker on server**
   - Ensures Docker is installed and configured
```yaml
- name: Install Docker on server
  run: |
    ssh -i ~/.ssh/your-key.pem ubuntu@${{ secrets.EC2_HOST }} \
      "curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker ubuntu"
```

10. **Deploy with Kamal**
    - Executes the deployment
```yaml
- name: Deploy with Kamal
  env:
    KAMAL_REGISTRY_PASSWORD: ${{ steps.login-ecr.outputs.docker_password_... }}
  run: kamal deploy
```

## Manual Deploy

If you need to deploy without waiting for a push:

1. Go to **Actions** in your repository
2. Select the **Deploy** workflow
3. Click **Run workflow**
4. Select the `main` branch
5. Click **Run workflow**

## Verify Deployment

After a successful deployment:

```bash
# View application logs
kamal app logs

# View running containers
kamal app containers

# View container details
kamal app details
```

Or access directly via URL:
```
http://<EC2_HOST>
```

## Troubleshooting

### Error: "docker: command not found"
The server doesn't have Docker installed. The workflow will install it automatically.

### Error: "Authentication failed"
Verify that `SSH_PRIVATE_KEY` is correct and matches the public key configured in EC2.

### Error: "bad URI"
Verify that `config/deploy.yml` doesn't have `remote: true` in the builder (should be commented or removed).

### Error: "Repository not found"
Verify that the ECR repository exists and `AWS_ACCESS_KEY_ID` has permissions.

### Error: "Host key verification failed"
Already configured in the workflow with `StrictHostKeyChecking no`.

## Customizing the Workflow

You can customize `.github/workflows/deploy.yml` to fit your needs:

### Change Target Branch
```yaml
on:
  push:
    branches: [production]  # Deploy from production branch
```

### Add Environment Variables
```yaml
- name: Deploy with Kamal
  env:
    KAMAL_REGISTRY_PASSWORD: ${{ steps.login-ecr.outputs.docker_password_... }}
    CUSTOM_VAR: ${{ secrets.CUSTOM_VAR }}
  run: kamal deploy
```

### Skip Docker Installation
If Docker is already installed on your servers, remove this step:
```yaml
- name: Install Docker on server
  # Remove this entire step
```

### Use Different AWS Region
Update the AWS region in the workflow:
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: eu-west-1  # Change to your region
```

## Monitoring

- **GitHub Actions**: View deployment status in the **Actions** tab of your repository
- **Workflow Logs**: Click on any workflow run to see detailed logs of each step
- **AWS CloudWatch**: Monitor EC2 instance logs and metrics
- **ECR**: View published Docker images in your ECR repository

## Workflow File Reference

The complete workflow is defined in `.github/workflows/deploy.yml`. Key sections:

**Trigger Configuration:**
```yaml
on:
  push:
    branches: [main]
```

**Job Definition:**
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
```

**Required Actions:**
- `actions/checkout@v4` - Repository checkout
- `ruby/setup-ruby@v1` - Ruby environment
- `aws-actions/configure-aws-credentials@v4` - AWS authentication
- `aws-actions/amazon-ecr-login@v2` - ECR authentication

## Best Practices

1. **Test Before Merging**: Always test changes in a separate branch before merging to `main`
2. **Review Workflow Logs**: Check logs after each deployment to catch issues early
3. **Rotate Secrets**: Regularly update AWS credentials and SSH keys
4. **Monitor Deployments**: Set up notifications for failed deployments
5. **Use Protected Branches**: Require pull request reviews before merging to `main`
