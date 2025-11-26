provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

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

resource "aws_instance" "app_server" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.terraform-server-key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = "${var.instance_name}-${count.index + 1}"
    Role = "web"
    Environment = "production"
  }

}

resource "aws_key_pair" "terraform-server-key" {
  key_name   = "terraform-server-key"
  public_key = file("~/.ssh/kamal-server-key.pub") # Path to your public key
}

# ECR Repository for Kamal
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

# ECR Lifecycle Policy - Keep only last 10 images
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

# Get current AWS account ID
data "aws_caller_identity" "current" {}
