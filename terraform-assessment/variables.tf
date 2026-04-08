variable "region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "admin_ip" {
  description = "Your current public IP address (without /32) for SSH access to the bastion host"
  type        = string
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair to associate with instances for SSH access"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the database server"
  type        = string
  default     = "t3.small"
}
