#!/bin/bash
set -ex

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
DEBIAN_FRONTEND=noninteractive apt-get install -y curl git python3 python3-pip

# Install AWS CLI
pip3 install awscli

# Create user-data user and directory
useradd -m -s /bin/bash user-data || true
mkdir -p /home/user-data/mail
chown -R user-data:user-data /home/user-data/mail

# Clone Mail-in-a-Box repository
git clone https://github.com/mail-in-a-box/mailinabox /root/mailinabox

# Save variables for Mail-in-a-Box setup
cat > /root/mailinabox/setup/variables.env << 'EOL'
PRIMARY_HOSTNAME=${mail_subdomain}
PRIMARY_EMAIL=${admin_email}
STORAGE_ROOT=/home/user-data/mail
STORAGE_USER=user-data
BACKUP_BUCKET=${backup_bucket}
STORAGE_BUCKET=${storage_bucket}
AWS_DEFAULT_REGION=${region}
NONINTERACTIVE=1
SKIP_NETWORK_CHECKS=1
EOL

# Run Mail-in-a-Box setup with environment variables
cd /root/mailinabox
export $(cat setup/variables.env | xargs)
bash setup/start.sh

# Configure backup script
cat > /etc/cron.daily/backup-to-s3 << EOL
#!/bin/bash
/usr/local/bin/aws s3 sync /home/user-data/mail/backup/ s3://${backup_bucket}/\$(hostname)/
EOL

chmod +x /etc/cron.daily/backup-to-s3

# Configure storage sync script
cat > /etc/cron.hourly/sync-to-s3 << EOL
#!/bin/bash
/usr/local/bin/aws s3 sync /home/user-data/mail/mail/ s3://${storage_bucket}/\$(hostname)/
EOL

chmod +x /etc/cron.hourly/sync-to-s3

# Configure SES integration
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