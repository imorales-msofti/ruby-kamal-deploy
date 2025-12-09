# Deploy with GitHub Actions

This project is configured to automatically deploy to AWS using Kamal with **multi-environment support** (staging and production).

## 🎯 Overview

The deployment system uses:

- **GitHub Environments** for secrets management
- **Branch-based deployments**: `stage` branch → Staging, `main` branch → Production
- **Multi-server support**: Staging (1 server), Production (2 servers)
- **Automatic environment detection** based on branch

## Prerequisites

Before setting up the deployment workflow, ensure you have:

- AWS account with access to ECR and EC2
- Running Ubuntu 24.04 EC2 instances
- ECR repository created (for Docker images)
- SSH key pair for EC2 instance access
- Rails application with Kamal configured (`config/deploy.yml`, `config/deploy.staging.yml`, `config/deploy.production.yml`)

## GitHub Actions Workflow

The deployment is automated through `.github/workflows/deploy.yml` which handles the entire deployment process for both environments.

### GitHub Environments Configuration

The workflow uses **GitHub Environments** to manage secrets securely:

- **Staging Environment**: Contains secrets for the staging server
- **Production Environment**: Contains secrets for production servers (can require manual approval)

Each environment stores:
- AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- SSH private key for server access
- Rails master key for credentials decryption
- SECRET_KEY_BASE for session encryption
- EC2_HOSTS list (space-separated server hostnames)

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
    sed -i "/servers:/,/web:/{ n; s/- .*/    - ${{ secrets.EC2_HOST }}/; }" config/deploy.yml
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

  
Entire workflow

```yaml
name: Deploy
on:
    push:
        branches: [main]
jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
                uses: actions/checkout@v4
            - name: Set up Ruby
                uses: ruby/setup-ruby@v1
                with:
                    ruby-version: .ruby-version
                    bundler-cache: true
            - name: Install Kamal
                run: gem install kamal
            - name: Configure AWS credentials
                uses: aws-actions/configure-aws-credentials@v4
                with:
                    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
                    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                    aws-region: us-east-1
            - name: Login to Amazon ECR
                id: login-ecr
                uses: aws-actions/amazon-ecr-login@v2
            - name: Setup SSH key
                run: |
                    mkdir -p ~/.ssh
                    echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/kamal-server-key.pem
                    chmod 600 ~/.ssh/kamal-server-key.pem
                    cat >> ~/.ssh/config << EOF
                    Host *
                        StrictHostKeyChecking no
                        UserKnownHostsFile=/dev/null
                    EOF
            - name: Setup master key
                run: echo "${{ secrets.RAILS_MASTER_KEY }}" > config/master.key
            - name: Update deploy.yml with EC2 host
                run: |
                    sed -i "/servers:/,/web:/{ n; s/- .*/    - ${{ secrets.EC2_HOST }}/; }" config/deploy.yml
            - name: Install Docker on server
                run: |
                    ssh -i ~/.ssh/kamal-server-key.pem ubuntu@${{ secrets.EC2_HOST }} \
                        "curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker ubuntu"
            - name: Deploy with Kamal
                env:
                    KAMAL_REGISTRY_PASSWORD: ${{ steps.login-ecr.outputs.docker_password_922126656512_dkr_ecr_us_east_1_amazonaws_com }}

        run: kamal deploy
```

## Deployment Flow

### Deploying to Staging

1. Create a feature branch from `stage`
2. Make your changes
3. Push to `stage` branch:

   ```bash
   git checkout stage
   git merge feature-branch
   git push origin stage
   ```

4. GitHub Actions automatically deploys to staging
5. Verify at the staging server URL

### Deploying to Production

1. After testing in staging, merge to `main`:

   ```bash
   git checkout main
   git merge stage
   git push origin main
   ```

2. GitHub Actions automatically deploys to production (2 servers)
3. Verify at the production server URLs

### Manual Workflow Trigger

If you need to deploy without pushing:

1. Go to **Actions** in your repository
2. Select the **Deploy** workflow
3. Click **Run workflow**
4. Select branch (`main` for production or `stage` for staging)
5. Click **Run workflow**

## Rollback on Deployment Failure

The workflow includes automatic rollback functionality. If the deployment step fails:

1. **Automatic Detection**: The workflow detects deployment failure
2. **Rollback Execution**: Automatically executes `kamal rollback` command
3. **Previous Version**: Restores the last successful deployment
4. **Notification**: Logs rollback action in GitHub Actions output

### Manual Rollback via GitHub Actions

A dedicated rollback workflow (`.github/workflows/rollback.yml`) allows manual rollback through the GitHub interface:

**Steps to trigger manual rollback:**

1. **Find the version to rollback to**:
   
   **Option A: Check ECR via AWS Console**
   - Go to AWS ECR console → `kamal-quick-start` repository
   - View available image tags (commit SHAs) with push dates
   
   **Option B: Check via AWS CLI**
   ```bash
   aws ecr describe-images \
     --repository-name kamal-quick-start \
     --region us-east-1 \
     --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt]' \
     --output table
   ```
   
   **Option C: Check GitHub commit history**
   - Go to your repository commits
   - Copy the SHA of the commit you want to restore

2. Go to **Actions** tab in your repository
3. Select **Rollback** workflow
4. Click **Run workflow**
5. The workflow will show you:
   - Last 10 versions available in ECR
   - Current deployed version on servers
6. Select parameters:
   - **Environment**: Choose `staging` or `production`
   - **Version** (required): Enter the commit SHA to rollback to
7. Click **Run workflow**

**Note**: The workflow automatically displays available versions from ECR before executing the rollback, so you can verify the target version exists.

**The rollback workflow will:**
- Authenticate with AWS and ECR
- Configure the selected environment
- Execute rollback to specified or previous version
- Verify the rollback status
- Show deployment details after rollback

### Manual Rollback via Command Line

If you need to manually rollback from your local machine:

```bash
# Rollback to previous version (staging)
kamal rollback -d staging

# Rollback to previous version (production)
kamal rollback -d production

# Rollback to specific version
kamal rollback -d production --version <commit-sha>
```

## Verify Deployment

After a successful deployment:

```bash
# View application logs (staging)
kamal app logs -d staging

# View application logs (production)
kamal app logs -d production

# View running containers
kamal app containers -d staging
kamal app containers -d production

# View container details
kamal app details -d staging
kamal app details -d production

# SSH into a server
kamal app exec -d staging 'bash'
```


## Monitoring and Logs

### GitHub Actions

- View deployment status in the **Actions** tab
- Click on workflow runs for detailed logs
- See which environment was deployed and when


### Application Logs

```bash
# View logs in real-time
kamal app logs -d staging --follow

# View last 100 lines
kamal app logs -d production --tail 100

# View logs for specific server
kamal app logs -d production --hosts <server-hostname>
```

## Docker Image Build Process

The Docker image is built during the **Deploy with Kamal** step. Here's what happens:

### Build Location
- Image is built on the **GitHub Actions runner** (ubuntu-latest VM)
- Not built on the target EC2 servers

### Build Process
1. **Kamal reads Dockerfile**: Uses the project's Dockerfile to build the image
2. **Build context**: Includes all application code and dependencies
3. **Tagging**: Image is tagged with git commit SHA for version tracking
4. **Push to ECR**: Built image is pushed to Amazon ECR registry
5. **Pull on servers**: Each EC2 server pulls the image from ECR
6. **Deploy**: Containers are started from the pulled image


### Multi-Environment Support

✅ Separate staging and production environments  
✅ Environment-specific secrets management  
✅ Branch-based automatic deployment



## Required GitHub Actions

The workflow uses these actions:

- `actions/checkout@v4` - Repository checkout
- `ruby/setup-ruby@v1` - Ruby environment setup
- `aws-actions/configure-aws-credentials@v4` - AWS authentication
- `aws-actions/amazon-ecr-login@v2` - ECR authentication
