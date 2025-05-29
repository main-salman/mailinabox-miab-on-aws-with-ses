terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# S3 buckets for backups and storage
resource "aws_s3_bucket" "mail_backup" {
  bucket = "mail-backup-${var.mail_subdomain}"
  tags   = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.mail_backup.id

  rule {
    id     = "backup_retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

resource "aws_s3_bucket" "mail_storage" {
  bucket = "mail-storage-${var.mail_subdomain}"
  tags   = var.tags
}

# SES Configuration
resource "aws_ses_domain_identity" "mail" {
  domain = var.mail_subdomain
}

resource "aws_ses_domain_dkim" "mail" {
  domain = aws_ses_domain_identity.mail.domain
}

# Route53 Records for Mail Server
data "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "mail_subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.mail_subdomain
  type    = "A"
  ttl     = "300"
  records = [aws_eip.mail_server.public_ip]
}

# DKIM Records
resource "aws_route53_record" "dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${element(aws_ses_domain_dkim.mail.dkim_tokens, count.index)}._domainkey.${var.mail_subdomain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.mail.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

# MX Record
resource "aws_route53_record" "mx" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.mail_subdomain
  type    = "MX"
  ttl     = "300"
  records = ["10 ${var.mail_subdomain}"]
}

# SPF Record
resource "aws_route53_record" "spf" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.mail_subdomain
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com ~all"]
}

# MAIL FROM MX Record
resource "aws_route53_record" "mail_from_mx" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bounce.${var.mail_subdomain}"
  type    = "MX"
  ttl     = "300"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

# MAIL FROM TXT Record for SPF
resource "aws_route53_record" "mail_from_spf" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bounce.${var.mail_subdomain}"
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com ~all"]
}

# SES Domain Verification Record
resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_amazonses.${var.mail_subdomain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.mail.verification_token]
}

# Elastic IP for Mail Server
resource "aws_eip" "mail_server" {
  domain = "vpc"
  tags   = var.tags
}

# IAM Role for EC2
resource "aws_iam_role" "mail_server" {
  name = "mail-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "s3_access" {
  name = "mail-server-s3-access"
  role = aws_iam_role.mail_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.mail_backup.arn,
          "${aws_s3_bucket.mail_backup.arn}/*",
          aws_s3_bucket.mail_storage.arn,
          "${aws_s3_bucket.mail_storage.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for SES access
resource "aws_iam_role_policy" "ses_access" {
  name = "mail-server-ses-access"
  role = aws_iam_role.mail_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail",
          "ses:SendEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for SSM Parameter Store access
resource "aws_iam_role_policy" "ssm_access" {
  name = "mail-server-ssm-access"
  role = aws_iam_role.mail_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.smtp_username.arn,
          aws_ssm_parameter.smtp_password.arn
        ]
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "mail_server" {
  name = "mail-server-profile"
  role = aws_iam_role.mail_server.name
} 