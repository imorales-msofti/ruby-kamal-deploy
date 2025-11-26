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

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 3
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the application"
  type        = string
  default     = "kamal-app"
}