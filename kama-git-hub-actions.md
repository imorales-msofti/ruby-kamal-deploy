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

          sed -i "/servers:/,/web:/{ n; s/- .*/    - ${{ secrets.EC2_HOST }}/; }" config/deploy.yml

  

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
5. Verify at: <http://ec2-34-226-234-69.compute-1.amazonaws.com>

### Deploying to Production

1. After testing in staging, merge to `main`:

   ```bash
   git checkout main
   git merge stage
   git push origin main
   ```

2. GitHub Actions automatically deploys to production (2 servers)
3. Verify at:
   - <http://ec2-98-93-202-251.compute-1.amazonaws.com>
   - <http://ec2-3-236-235-204.compute-1.amazonaws.com>

### Manual Workflow Trigger

If you need to deploy without pushing:

1. Go to **Actions** in your repository
2. Select the **Deploy** workflow
3. Click **Run workflow**
4. Select branch (`main` for production or `stage` for staging)
5. Click **Run workflow**

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

## Environment Configuration

  

You can customize `.github/workflows/deploy.yml` to fit your needs:

  

### Change Target Branch

```yaml

on:

  push:

    branches: [production]  # Deploy from production branch

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

    aws-region: eu-west-1  # Change to your region

```

  

## Monitoring and Logs

### GitHub Actions

- View deployment status in the **Actions** tab
- Click on workflow runs for detailed logs
- See which environment was deployed and when

### Environment URLs

Each environment has a registered URL in GitHub:

- **Staging**: http://ec2-34-226-234-69.compute-1.amazonaws.com
- **Production**: http://ec2-98-93-202-251.compute-1.amazonaws.com

### Application Logs

```bash
# View logs in real-time
kamal app logs -d staging --follow

# View last 100 lines
kamal app logs -d production --tail 100

# View logs for specific server
kamal app logs -d production --hosts ec2-98-93-202-251.compute-1.amazonaws.com
```

### Deployment History

- Go to **Environments** in repository settings
- Each environment shows deployment history
- View who deployed, when, and the git commit

## Key Features

### Multi-Environment Support

✅ Separate staging and production environments  
✅ Environment-specific secrets management  
✅ Branch-based automatic deployment

### Multi-Server Deployment

✅ Deploy to multiple servers simultaneously  
✅ Automatic health checks per server  
✅ Rollback if any server fails

### Security

✅ Secrets managed through GitHub Environments  
✅ No credentials in code  
✅ Environment-specific access control  
✅ Optional manual approval for production

### Zero-Downtime Deployments

✅ Rolling deployments via kamal-proxy  
✅ Health checks before switching traffic  
✅ Previous containers remain active if deployment fails

## Required GitHub Actions

The workflow uses these actions:

- `actions/checkout@v4` - Repository checkout
- `ruby/setup-ruby@v1` - Ruby environment setup
- `aws-actions/configure-aws-credentials@v4` - AWS authentication
- `aws-actions/amazon-ecr-login@v2` - ECR authentication

## Deployment Performance

- **Average deployment time**: ~5 minutes per environment
- **Simultaneous deployment**: All servers in the environment deploy in parallel
- **Zero downtime**: Rolling updates ensure the application remains available
- **Automatic rollback**: If any server fails health checks, deployment stops