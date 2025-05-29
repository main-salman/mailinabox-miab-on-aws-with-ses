output "mail_server_eip" {
  description = "Elastic IP address assigned to the mail server"
  value       = aws_eip.mail_server.public_ip
}

output "mail_server_domain" {
  description = "Domain name for the mail server"
  value       = var.mail_subdomain
}

output "backup_bucket" {
  description = "S3 bucket for mail server backups"
  value       = aws_s3_bucket.mail_backup.id
}

output "storage_bucket" {
  description = "S3 bucket for mail server storage"
  value       = aws_s3_bucket.mail_storage.id
}

output "ses_verification_token" {
  description = "SES verification token"
  value       = aws_ses_domain_identity.mail.verification_token
}

output "dkim_tokens" {
  description = "DKIM tokens for SES configuration"
  value       = aws_ses_domain_dkim.mail.dkim_tokens
}

output "smtp_username" {
  description = "SMTP username for SES"
  value       = aws_iam_access_key.ses_smtp_user.id
  sensitive   = true
}

output "smtp_password" {
  description = "SMTP password for SES"
  value       = aws_iam_access_key.ses_smtp_user.ses_smtp_password_v4
  sensitive   = true
} 