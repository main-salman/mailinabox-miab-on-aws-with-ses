# Security Group for Mail Server
resource "aws_security_group" "mail_server" {
  name        = "mail-server-sg"
  description = "Security group for mail server"

  # SMTP
  ingress {
    from_port   = 25
    to_port     = 25
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SMTP Submission
  ingress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IMAP
  ingress {
    from_port   = 993
    to_port     = 993
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Mail Server EC2 Instance
resource "aws_instance" "mail_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  vpc_security_group_ids = [aws_security_group.mail_server.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.mail_server.name

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    admin_email    = var.admin_email
    domain_name    = var.domain_name
    mail_subdomain = var.mail_subdomain
    backup_bucket  = aws_s3_bucket.mail_backup.id
    storage_bucket = aws_s3_bucket.mail_storage.id
    region        = var.aws_region
    environment   = var.environment
  })

  tags = merge(var.tags, {
    Name = "mail-server",
    Backup = "true"
  })
}

# Latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Attach Elastic IP to Instance
resource "aws_eip_association" "mail_server" {
  instance_id   = aws_instance.mail_server.id
  allocation_id = aws_eip.mail_server.id
}

# IAM Role for AWS Backup
resource "aws_iam_role" "aws_backup" {
  name = "aws-backup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "backup.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_backup_policy" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWS Backup Plan for EC2 instance
resource "aws_backup_plan" "mail_server_daily" {
  name = "mail-server-daily-backup"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = "Default"
    schedule          = "cron(0 5 * * ? *)" # Daily at 05:00 UTC (AWS default window)
    lifecycle {
      delete_after = 65 # Retention period in days
    }
  }
}

# Update aws_backup_selection to use the new role
resource "aws_backup_selection" "mail_server" {
  name         = "mail-server-selection"
  iam_role_arn = aws_iam_role.aws_backup.arn
  plan_id      = aws_backup_plan.mail_server_daily.id

  resources = [] # Not used when using selection_tag

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
} 