# AWS Infrastructure Setup with Terraform

This guide explains how to create the required AWS infrastructure (EC2, ECR, Security Groups) for Kamal deployment using Terraform.

## Prerequisites

Before starting, ensure you have:

- AWS CLI configured with credentials
- Terraform installed (version 1.0+)
- SSH key pair generated for EC2 access
- Basic knowledge of AWS services (EC2, ECR, IAM)

## AWS Resources Created

This Terraform configuration will create:

- **ECR Repository**: Docker image registry for your application
- **EC2 Instance**: Ubuntu 24.04 LTS server (t3.micro)
- **Security Group**: Firewall rules for SSH (22), HTTP (80), and HTTPS (443)
- **SSH Key Pair**: For secure EC2 instance access
- **Lifecycle Policy**: Automatically keeps only the last 10 Docker images

### ECR Repository Configuration

The ECR repository in `main.tf` includes:

```terraform
resource "aws_ecr_repository" "app_repository" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allows deletion even with images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = var.ecr_repository_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### ECR Lifecycle Policy

Automatically clean up old images:

```terraform
resource "aws_ecr_lifecycle_policy" "app_repository_policy" {
  repository = aws_ecr_repository.app_repository.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

## Generate SSH Key Pair

Before running Terraform, create an SSH key pair:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/your-server-key -N ""

# Generate public key from private key
ssh-keygen -y -f ~/.ssh/your-server-key > ~/.ssh/your-server-key.pub

# Set correct permissions
chmod 600 ~/.ssh/your-server-key
chmod 644 ~/.ssh/your-server-key.pub
```

## Terraform Files Structure

```
.
├── main.tf           # Main infrastructure definitions
├── variables.tf      # Input variables
├── outputs.tf        # Output values after apply
└── terraform.tf      # Terraform version requirements
```

### AWS Provider Configuration

In `main.tf`, the AWS provider is configured:

```terraform
provider "aws" {
  region = "us-east-1"
}
```

## Configuration Variables

You can customize these variables in `variables.tf`:

```terraform
variable "instance_name" {
  description = "The name tag for the EC2 instance"
  type        = string
  default     = "AppServerInstance"
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t3.micro"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the application"
  type        = string
  default     = "your-app"
}
```

### instance_name
- **Description**: Name tag for the EC2 instance
- **Default**: `AppServerInstance`
- **Type**: string

### instance_type
- **Description**: EC2 instance type
- **Default**: `t3.micro`
- **Type**: string
- **Options**: `t3.micro`, `t3.small`, `t3.medium`, etc.

### ecr_repository_name
- **Description**: Name of the ECR repository
- **Default**: `your-app`
- **Type**: string

## Initialize Terraform

Initialize Terraform in your project directory:

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

## Deploy Infrastructure

Create all AWS resources:

```bash
# Apply configuration
terraform apply

# Review the changes and type 'yes' to confirm
```

After successful deployment, Terraform will display outputs with important values:

```
Outputs:

aws_region = "us-east-1"
docker_login_command = "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/your-app"
ecr_registry_id = "ACCOUNT_ID"
ecr_repository_name = "your-app"
ecr_repository_url = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/your-app"
instance_public_dns = "ec2-XX-XXX-XX-XX.compute-1.amazonaws.com"
instance_public_ip = "XX.XXX.XX.XX"
kamal_registry_password_command = "export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)"
ssh_connection_command = "ssh -i ~/.ssh/your-server-key.pem ubuntu@ec2-XX-XXX-XX-XX.compute-1.amazonaws.com"
```

## Retrieve Outputs

Get specific output values anytime:

```bash
# Get all outputs
terraform output

# Get specific output
terraform output instance_public_dns
terraform output ecr_repository_url

# Get output in JSON format
terraform output -json
```

### Output Definitions

The `outputs.tf` file defines all output values:

```terraform
output "instance_public_dns" {
  description = "Public DNS name of the EC2 Instance"
  value       = aws_instance.app_server.public_dns
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 Instance"
  value       = aws_instance.app_server.public_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repository.repository_url
}

output "ecr_registry_id" {
  description = "Registry ID (AWS Account ID)"
  value       = aws_ecr_repository.app_repository.registry_id
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/your-server-key.pem ubuntu@${aws_instance.app_server.public_dns}"
}

output "kamal_registry_password_command" {
  description = "Command to set Kamal registry password"
  value       = "export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)"
}
```

## Verify EC2 Instance

Test SSH connection to your EC2 instance:

```bash
# Connect via SSH
ssh -i ~/.ssh/your-server-key.pem ubuntu@$(terraform output -raw instance_public_dns)

# Or use the provided command
$(terraform output -raw ssh_connection_command)
```

## Configure ECR Authentication

Set up Docker authentication with ECR:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# Set Kamal registry password
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)
```

## Update Kamal Configuration

Update `config/deploy.yml` with Terraform outputs:

```yaml
service: your-app

image: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/your-app

servers:
  web:
    - ec2-XX-XXX-XX-XX.compute-1.amazonaws.com

registry:
  server: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
  username: AWS
  password:
    - KAMAL_REGISTRY_PASSWORD

ssh:
  user: ubuntu
  keys:
    - ~/.ssh/your-server-key.pem
```

Get values from Terraform:

```bash
# Get ECR repository URL
terraform output -raw ecr_repository_url

# Get EC2 public DNS
terraform output -raw instance_public_dns

# Get AWS account ID
terraform output -raw ecr_registry_id
```

## Customize Infrastructure

### Change Instance Type

Edit `variables.tf` or pass variable:

```bash
# Using variable flag
terraform apply -var="instance_type=t3.small"

# Or create terraform.tfvars file
echo 'instance_type = "t3.small"' > terraform.tfvars
terraform apply
```

### Change ECR Repository Name

```bash
# Pass variable
terraform apply -var="ecr_repository_name=my-app"

# Or in terraform.tfvars
echo 'ecr_repository_name = "my-app"' > terraform.tfvars
```

### Change AWS Region

Edit `main.tf`:

```terraform
provider "aws" {
  region = "eu-west-1"  # Change to your preferred region
}
```

Remember to update the region in outputs and ECR commands as well.

## Infrastructure Components

### EC2 Instance

The EC2 instance configuration in `main.tf`:

```terraform
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.terraform-server-key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = var.instance_name
  }
}
```

### Ubuntu AMI Data Source

Automatically selects the latest Ubuntu 24.04 LTS:

```terraform
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}
```

### SSH Key Pair Resource

```terraform
resource "aws_key_pair" "terraform-server-key" {
  key_name   = "terraform-server-key"
  public_key = file("~/.ssh/your-server-key.pub")
}
```

## Modify Security Group Rules

### Current Security Group Configuration

The security group in `main.tf` allows SSH, HTTP, and HTTPS:

```terraform
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}
```

### Add Custom Port

To add or modify firewall rules, edit the security group:

```terraform
resource "aws_security_group" "allow_ssh_http" {
  # ... existing configuration ...

  # Add new ingress rule
  ingress {
    description = "Custom port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Then apply changes:

```bash
terraform apply
```

## Destroy Infrastructure

When you no longer need the infrastructure:

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' to confirm
```

**Note**: The ECR repository is configured with `force_delete = true`, allowing deletion even if it contains images.

## Troubleshooting

### Error: "InvalidKeyPair.NotFound"
The SSH public key file doesn't exist. Make sure you generated it:
```bash
ssh-keygen -y -f ~/.ssh/your-server-key > ~/.ssh/your-server-key.pub
```

### Error: "UnauthorizedOperation"
Your AWS credentials don't have sufficient permissions. Ensure your IAM user has:
- EC2 full access
- ECR full access
- VPC security group permissions
