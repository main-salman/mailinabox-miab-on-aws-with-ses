variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Main domain name (must be set in terraform.tfvars)"
  type        = string
}

variable "mail_subdomain" {
  description = "Subdomain for mail server (must be set in terraform.tfvars)"
  type        = string
}

variable "environment" {
  description = "Environment name (must be set in terraform.tfvars)"
  type        = string
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 90
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"  # x86 instance with sufficient resources for Mail-in-a-Box
}

variable "volume_size" {
  description = "Size of EBS volume in GB"
  type        = number
  default     = 50
}

variable "ssh_key_name" {
  description = "Name of SSH key pair (must be set in terraform.tfvars)"
  type        = string
}

variable "admin_email" {
  description = "Admin email address (must be set in terraform.tfvars)"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "mail-server"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

variable "dmarc_policy" {
  description = "DMARC policy (e.g., quarantine, reject, none)"
  type        = string
  default     = "quarantine"
}

variable "dmarc_rua_email" {
  description = "DMARC aggregate report email address"
  type        = string
  default     = "postmaster@qolimpact.org"
} 