#!/bin/bash
set -euo pipefail

# This script configures Postfix on a remote EC2 instance (Mail-in-a-Box) to relay mail through Amazon SES.
# It retrieves SMTP credentials from AWS SSM Parameter Store LOCALLY and pushes them to the remote server via SSH.
# Reference: https://mailinabox.email/advanced-configuration.html#relaying

# --- CONFIGURATION ---
AWS_REGION="us-east-1"  # Change if your SES is in a different region
ENVIRONMENT="prod"      # Change to your environment name if needed
SSM_USERNAME_PATH="/mail-server/${ENVIRONMENT}/smtp-username"
SSM_PASSWORD_PATH="/mail-server/${ENVIRONMENT}/smtp-password"
SES_SMTP_SERVER="email-smtp.${AWS_REGION}.amazonaws.com"
SES_SMTP_PORT=587

# --- REMOTE SERVER CONFIG ---
REMOTE_USER="ubuntu"  # Change if your instance uses a different user
REMOTE_HOST="44.208.145.23"  # Set to your Mail-in-a-Box server's IP or hostname
SSH_KEY="salman-test.pem"  # Path to your SSH private key

# --- RETRIEVE SMTP CREDENTIALS FROM SSM (LOCALLY) ---
echo "Retrieving SMTP credentials from SSM Parameter Store (locally)..."
SMTP_USERNAME=$(aws ssm get-parameter --region "$AWS_REGION" --name "$SSM_USERNAME_PATH" --with-decryption --query Parameter.Value --output text)
SMTP_PASSWORD=$(aws ssm get-parameter --region "$AWS_REGION" --name "$SSM_PASSWORD_PATH" --with-decryption --query Parameter.Value --output text)

# --- GENERATE REMOTE SCRIPT ---
REMOTE_SCRIPT="/tmp/setup_postfix_ses_remote.sh"
cat <<EOF > $REMOTE_SCRIPT
#!/bin/bash
set -euo pipefail
POSTFIX_SASL_PASSWD_FILE="/etc/postfix/sasl_passwd"
POSTFIX_SASL_PASSWD_DB="/etc/postfix/sasl_passwd.db"
SES_SMTP_SERVER='$SES_SMTP_SERVER'
SES_SMTP_PORT=$SES_SMTP_PORT
SMTP_USERNAME='$SMTP_USERNAME'
SMTP_PASSWORD='$SMTP_PASSWORD'

echo "[[32mConfiguring Postfix on remote server[0m]"
echo "[[34mWriting credentials[0m]"
echo "[\$SES_SMTP_SERVER]:\$SES_SMTP_PORT \$SMTP_USERNAME:\$SMTP_PASSWORD" | sudo tee \$POSTFIX_SASL_PASSWD_FILE > /dev/null
sudo chmod 600 \$POSTFIX_SASL_PASSWD_FILE
sudo postmap \$POSTFIX_SASL_PASSWD_FILE

sudo postconf -e "relayhost = [\$SES_SMTP_SERVER]:\$SES_SMTP_PORT"
sudo postconf -e "smtp_sasl_auth_enable = yes"
sudo postconf -e "smtp_sasl_password_maps = hash:\$POSTFIX_SASL_PASSWD_FILE"
sudo postconf -e "smtp_sasl_security_options = noanonymous"
sudo postconf -e "smtp_tls_security_level = encrypt"
sudo postconf -e "smtp_tls_note_starttls_offer = yes"
sudo postconf -e "smtp_use_tls = yes"

echo "Reloading Postfix..."
sudo systemctl reload postfix
echo "Postfix is now configured to relay mail through Amazon SES."
EOF
chmod +x $REMOTE_SCRIPT

# --- COPY AND EXECUTE REMOTE SCRIPT ---
echo "Copying setup script to remote server..."
scp -i $SSH_KEY $REMOTE_SCRIPT $REMOTE_USER@$REMOTE_HOST:/tmp/

echo "Running setup script on remote server..."
ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST 'bash /tmp/setup_postfix_ses_remote.sh && rm /tmp/setup_postfix_ses_remote.sh'

echo "Done. Postfix on $REMOTE_HOST is now configured to relay mail through Amazon SES." 