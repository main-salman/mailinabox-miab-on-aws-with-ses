# Create SES SMTP credentials
resource "aws_iam_user" "ses_smtp_user" {
  name = "ses-smtp-user-${var.environment}"
  path = "/system/"
}

resource "aws_iam_access_key" "ses_smtp_user" {
  user = aws_iam_user.ses_smtp_user.name
}

resource "aws_iam_user_policy" "ses_smtp_policy" {
  name = "ses-smtp-policy"
  user = aws_iam_user.ses_smtp_user.name

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

# Store SMTP credentials in SSM Parameter Store
resource "aws_ssm_parameter" "smtp_username" {
  name  = "/mail-server/${var.environment}/smtp-username"
  type  = "SecureString"
  value = aws_iam_access_key.ses_smtp_user.id
  tags  = var.tags
}

resource "aws_ssm_parameter" "smtp_password" {
  name  = "/mail-server/${var.environment}/smtp-password"
  type  = "SecureString"
  value = aws_iam_access_key.ses_smtp_user.ses_smtp_password_v4
  tags  = var.tags
}

# Additional SES configuration
resource "aws_ses_configuration_set" "main" {
  name = "mail-server-${var.environment}"

  reputation_metrics_enabled = true
  sending_enabled          = true

  delivery_options {
    tls_policy = "Require"
  }
}

# Event destination for configuration set
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "event-destination-cloudwatch"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "delivery", "reject", "renderingFailure"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "ses_events"
    value_source   = "messageTag"
  }
}

resource "aws_ses_domain_mail_from" "main" {
  domain               = var.mail_subdomain
  mail_from_domain    = "bounce.${var.mail_subdomain}"
  behavior_on_mx_failure = "UseDefaultValue"

  depends_on = [
    aws_ses_domain_identity.mail,
    aws_route53_record.ses_verification
  ]
} 