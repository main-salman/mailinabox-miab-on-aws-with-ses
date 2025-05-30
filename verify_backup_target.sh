#!/bin/bash

# 1. List EC2 instances with Project=mail-server tag (JSON output)
echo "\n--- EC2 Instances with tag Project=mail-server (JSON) ---"
aws ec2 describe-instances --filters Name=tag:Project,Values=mail-server --output json

# 2. Show instance IDs only
echo "\n--- Instance IDs with Project=mail-server ---"
aws ec2 describe-instances --filters Name=tag:Project,Values=mail-server --query "Reservations[*].Instances[*].InstanceId" --output text

# 3. Show AWS account ID
echo "\n--- AWS Account ID ---"
aws sts get-caller-identity --query Account --output text

# 4. Print backup job command template
echo "\n--- To trigger a manual backup, run the following (replace <instance-id> and <account-id> as needed): ---"
echo "aws backup start-backup-job \\"
echo "  --backup-vault-name Default \\"
echo "  --resource-arn arn:aws:ec2:us-east-1:<account-id>:instance/<instance-id> \\"
echo "  --iam-role-arn arn:aws:iam::<account-id>:role/aws-backup-service-role"

# 5. List recent backup jobs
echo "\n--- Recent Backup Jobs in Default Vault ---"
aws backup list-backup-jobs --by-backup-vault-name Default --max-results 5

echo "\n--- Script complete. Review the output above. ---" 