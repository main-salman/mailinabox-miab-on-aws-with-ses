#!/bin/bash
set -ex

# Get SES SMTP credentials from SSM Parameter Store
SMTP_USERNAME=$(aws ssm get-parameter --name "/mail-server/${environment}/smtp-username" --with-decryption --region ${region} --query "Parameter.Value" --output text)
SMTP_PASSWORD=$(aws ssm get-parameter --name "/mail-server/${environment}/smtp-password" --with-decryption --region ${region} --query "Parameter.Value" --output text)

# Configure Postfix for SES
cat > /etc/postfix/sasl_passwd << EOL
[email-smtp.${region}.amazonaws.com]:587 $SMTP_USERNAME:$SMTP_PASSWORD
EOL

# Create hash db and set permissions
postmap hash:/etc/postfix/sasl_passwd
chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

# Configure Postfix main.cf
postconf -e "relayhost = [email-smtp.${region}.amazonaws.com]:587"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_note_starttls_offer = yes"

# Restart Postfix
systemctl restart postfix 