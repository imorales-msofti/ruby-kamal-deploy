Perfect 💪 Here's a **complete README** with all the steps to configure and deploy a Ruby on Rails application on AWS using **Kamal + ECR + EC2**.

You can save it as `README_KAMAL_DEPLOY.md` inside your project 👇

> **📝 Important**: This guide uses placeholder values. Replace the following with your actual values:
> - `YOUR-AWS-ACCOUNT-ID`: Your 12-digit AWS account ID
> - `your-region`: Your AWS region (e.g., `us-east-1`, `eu-west-1`)
> - `your-org/your-app-name`: Your organization and application name
> - `your-server.amazonaws.com`: Your EC2 instance public DNS
> - `your-ssh-key.pem`: Your SSH key filename

---

# 🚀 Deploy with Kamal on AWS (ECR + EC2)

This guide describes step by step how to configure and deploy a Ruby on Rails application on an AWS EC2 server, using **Kamal**, **Docker**, and **Amazon ECR** as an image repository.

---

## 🧩 Prerequisites

Make sure you have:

* An **AWS** account
* Access to **ECR** (Elastic Container Registry)
* An **EC2** instance with Ubuntu (Ubuntu is recommended because it has excellent Docker support, comes with systemd for service management, and has a large community with extensive documentation for deployment scenarios)
* **Docker** and **Kamal** installed locally
* Your SSH key (`.pem`) to connect to the server
* AWS CLI configured:

  ```bash
  aws configure
  ```

### 🐧 Why Ubuntu for EC2?

Ubuntu is specifically recommended for your EC2 instance for several reasons:

- **Docker compatibility**: Ubuntu has excellent out-of-the-box Docker support and official Docker packages
- **System management**: Comes with `systemd` which makes it easy to manage services like Docker daemon
- **Package management**: APT package manager simplifies installing dependencies
- **Community support**: Large community with extensive documentation for deployment scenarios
- **Security updates**: Regular and reliable security updates from Canonical
- **Kamal compatibility**: Kamal is well-tested on Ubuntu environments
- **Default user**: The default `ubuntu` user comes with sudo privileges, perfect for deployment tasks

**Recommended AMI**: For this guide, the following Ubuntu AMI was used:
```
ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20251022
```
This is Ubuntu 24.04 LTS (Noble Numbat) with SSD GP3 storage, which provides excellent performance and long-term support.

Other distributions like Amazon Linux or CentOS can work, but Ubuntu provides the smoothest experience for Rails deployment with Kamal.

---

## ⚙️ 1. Create the ECR repository

> 💻 **Run locally** (from your development machine)

Create a repository for your images:

```bash
aws ecr create-repository --repository-name your-org/your-app-name --region your-region
```

Verify it's empty (initially):

```bash
aws ecr list-images --repository-name your-org/your-app-name --region your-region
```

---

## 🧱 2. Build and push Docker image to ECR

> 💻 **Run locally** (from your Rails project directory)

First authenticate Docker with ECR:

```bash
aws ecr get-login-password --region your-region | docker login --username AWS --password-stdin YOUR-AWS-ACCOUNT-ID.dkr.ecr.your-region.amazonaws.com
```

Then build the image:

```bash
docker build -t your-org/your-app-name .
```

And tag it for ECR:

```bash
docker tag your-org/your-app-name:latest YOUR-AWS-ACCOUNT-ID.dkr.ecr.your-region.amazonaws.com/your-org/your-app-name:latest
```

Finally, push the image:

```bash
docker push YOUR-AWS-ACCOUNT-ID.dkr.ecr.your-region.amazonaws.com/your-org/your-app-name:latest
```

---

## 🔐 3. Configure Kamal

> 💻 **Run locally** (in your Rails project directory)

**Important**: This step must be done in your **local Ruby on Rails project**. If the `config/deploy.yml` file doesn't exist in your project, you need to create it.

Create the `config/deploy.yml` file with the following content:

```yaml
service: your-app-name
image: YOUR-AWS-ACCOUNT-ID.dkr.ecr.your-region.amazonaws.com/your-org/your-app-name

servers:
  web:
    - your-server.amazonaws.com

registry:
  server: YOUR-AWS-ACCOUNT-ID.dkr.ecr.your-region.amazonaws.com
  username: AWS
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production

builder:
  arch: amd64
  # skip: true   # Uncomment if you want to skip local build

ssh:
  user: ubuntu
  keys:
    - ~/.ssh/your-ssh-key.pem
```

---

## 🔑 4. Configure environment variable

> 💻 **Run locally** (from your development machine)

Export the ECR registry password (temporarily valid):

```bash
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region your-region)
```

---

## ⚡ 5. Prepare the remote server

> 🖥️ **Run on EC2 server** (SSH connection required)

Connect via SSH to EC2:

```bash
ssh -i ~/.ssh/your-ssh-key.pem ubuntu@your-server.amazonaws.com
```

**Once connected to the EC2 server**, make sure Docker is running:

```bash
sudo systemctl start docker
sudo systemctl enable docker
docker ps
```

Then exit the server:

```bash
exit
```

> 💻 **Back to local machine** (you should now be back in your local terminal)

---

## 🚀 6. Configure Kamal in the project

> 💻 **Run locally** (from your Rails project directory)

Run the following command:

```bash
kamal setup
```

This:

* Connects to the server
* Installs `kamal-proxy`
* Prepares the base containers

If SSH authentication error appears, make sure the user is `ubuntu` (not `root`) and the `.pem` key has correct permissions:

```bash
chmod 400 ~/.ssh/your-ssh-key.pem
```

---

## 🚢 7. Deploy the application

> 💻 **Run locally** (from your Rails project directory)

Finally, run the deployment:

```bash
kamal deploy
```

Kamal:

* Uses the ECR image
* Creates and starts the containers
* Configures the reverse proxy (port 80)

---

## ✅ 8. Verify the deployment

> 🖥️ **Run on EC2 server** (SSH connection required)

Connect to the server:

```bash
ssh -i ~/.ssh/your-ssh-key.pem ubuntu@your-server.amazonaws.com
docker ps
```

You should see two containers:

* `your-app-name-app`
* `kamal-proxy`

Then, test in the browser:

```
http://your-server.amazonaws.com
```

> 🌐 **Test from anywhere** (browser verification)

---

## 🧰 9. View logs

> 🖥️ **Run on EC2 server** (SSH connection required)

To see the app logs:

```bash
docker logs -f $(docker ps -q -f name=your-app-name-app)
```

---

## 🧹 10. Cleanup (optional)

> 💻 **Run locally** (from your Rails project directory)

If you want to remove everything:

```bash
kamal remove
```

This will remove the containers and proxy from the server.

---

## 🌐 11. (Optional) Non-production deployment

> 💻 **Run locally** (edit config file and redeploy)

If you want to use `RAILS_ENV=development` or `staging`, adjust in the `deploy.yml`:

```yaml
env:
  clear:
    RAILS_ENV: development
```

And redeploy with:

```bash
kamal deploy
```

---

## 🧾 Final notes

* The error `address already in use` indicates that port 80 is already occupied.
  Solution: stop any service using that port (`nginx`, etc.).
* If `Authentication failed` appears, make sure to use `user: ubuntu` and that your `.pem` is correctly configured.

---

Would you like me to also add the part for **configuring HTTPS with Let's Encrypt** using Kamal (integrated proxy)?
I can extend the README with that as the next step.
