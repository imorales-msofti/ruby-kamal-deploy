output "instance_hostnames" {
  description = "Private DNS names of all EC2 Instances"
  value       = aws_instance.app_server[*].private_dns
}

output "instance_public_ips" {
  description = "Public IP addresses of all EC2 Instances"
  value       = aws_instance.app_server[*].public_ip
}

output "instance_public_dns_list" {
  description = "Public DNS names of all EC2 Instances"
  value       = aws_instance.app_server[*].public_dns
}

output "instance_public_dns_yaml" {
  description = "Public DNS names formatted for Kamal deploy.yml"
  value       = join("\n    - ", aws_instance.app_server[*].public_dns)
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to each instance"
  value       = [for instance in aws_instance.app_server : "ssh -i ~/.ssh/kamal-server-key.pem ubuntu@${instance.public_dns}"]
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repository.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app_repository.name
}

output "ecr_registry_id" {
  description = "Registry ID (AWS Account ID)"
  value       = aws_ecr_repository.app_repository.registry_id
}

output "aws_region" {
  description = "AWS Region"
  value       = "us-east-1"
}

output "docker_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.app_repository.repository_url}"
}

output "kamal_registry_password_command" {
  description = "Command to set Kamal registry password"
  value       = "export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)"
}
