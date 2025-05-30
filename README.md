# Mail-in-a-Box + SES Infrastructure

## Quick Setup

1. **Clone this repository**
2. **Install prerequisites:**
   - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
   - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and run `aws configure`
   - Ensure you have an AWS EC2 SSH key pair
3. **Configure variables:**
   - Copy and edit variables:
     ```sh
     cp terraform.tfvars.example terraform.tfvars
     # Edit terraform.tfvars and fill in your real values
     ```
4. **Deploy infrastructure:**
   ```sh
   terraform init
   terraform apply
   # Review and type 'yes' to confirm
   ```
5. **Set up DNS:**
   - Use the Terraform outputs to configure DNS records at your registrar (if not using Route53)
6. **SSH into your server:**
   ```sh
   ssh -i <your-key.pem> ubuntu@<mail_subdomain>
   ```
7. **Run Mail-in-a-Box setup:**
   ```sh
   sudo curl -s https://mailinabox.email/setup.sh | sudo -E bash
   ```
   Note: I had to run " sudo rm /etc/mailinabox.conf" and then "reboot" and then "sudo mailinabox" again becuase it didn't work the first time.
8. **Access the admin interface:**
   - Go to `https://<mail_subdomain>/admin` in your browser
9. **(Optional) Set up SMTP relay with SES:**
   - Follow the instructions in the SMTP relay section below

---

## Introduction
This project automates the deployment and configuration of a secure, self-hosted email server using [Mail-in-a-Box](https://mailinabox.email/) on AWS EC2, with Amazon SES as the SMTP relay. AWS SSM Parameter Store is used for secure credential management, and all setup can be managed from your local machine.

---

## Terraform Setup Instructions

### 1. Prerequisites
- [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and run `aws configure` to set up your credentials
- Ensure you have an AWS EC2 SSH key pair created

### 2. Configure Variables
- Copy the example variables file:
  ```sh
  cp terraform.tfvars.example terraform.tfvars
  ```
- Edit `terraform.tfvars` and set the following variables:
  - `domain_name`: Your main domain (e.g., `example.com`)
  - `mail_subdomain`: Subdomain for mail server (e.g., `mail.example.com`)
  - `environment`: Environment name (e.g., `prod`)
  - `ssh_key_name`: Name of your AWS EC2 SSH key pair
  - `admin_email`: Admin email address
  - (Optional) Adjust `backup_retention_days`, `instance_type`, `volume_size`, and `tags` as needed
- **Note:** Do not commit `terraform.tfvars` to version control (it is in `.gitignore`).

### 3. Initialize Terraform
```sh
terraform init
```

### 4. Review the Plan
```sh
terraform plan
```

### 5. Apply the Infrastructure
```sh
terraform apply
```
- Review the output and type `yes` to confirm

### 6. Outputs
- After apply, Terraform will output:
  - Mail server EIP (public IP)
  - Mail server domain
  - S3 backup and storage bucket names
  - SES verification and DKIM tokens
  - SMTP credentials (sensitive)

### 7. DNS Setup
- Use the output tokens to configure DNS records at your registrar if not managed by Route53

---

# Mail-in-a-Box Quick Setup Guide

Based on the [Mail-in-a-Box official guide](https://mailinabox.email/guide.html)

---

## 1. Prerequisites
- **Cloud VM**: Use a fresh Ubuntu 22.04 x64 (server edition) instance (do not use for anything else).
- **Domain Name**: Have a domain name ready (see guide for TLD recommendations).
- **Open Ports**: Ensure the following ports are open in your firewall/security group:
  - 22 (SSH)
  - 25 (SMTP)
  - 53 (DNS, TCP & UDP)
  - 80 (HTTP)
  - 443 (HTTPS)
  - 465 (SMTP submission)
  - 993 (IMAP)
  - 995 (POP)
  - 4190 (Sieve)

## 2. SSH into Your Server
```sh
ssh -i <your-key.pem> ubuntu@<your-server-ip>
```

## 3. Run the Mail-in-a-Box Setup
```sh
curl -s https://mailinabox.email/setup.sh | sudo -E bash
```
- Follow the prompts to enter your email address and other configuration details.
- At the end, set a password for your email account (not for SSH).

## 4. Access the Admin Interface
- After setup, access the admin panel at:
  - `https://<your-server-ip>/admin` or `https://box.<your-domain>/admin`
- The first time, you may get a certificate warning. Confirm the fingerprint matches the one shown in your setup output.

## 5. Complete DNS Setup
- Follow the admin panel's instructions to:
  - Set up glue records and nameservers at your domain registrar.
  - Optionally, set up DNSSEC.

## 6. Get a Signed TLS Certificate
- Use the admin panel to provision a free Let's Encrypt certificate.

## 7. Check System Status
- Use the admin panel's System Status Checks to verify everything is working.

## 8. Maintenance
- To re-run setup or update Mail-in-a-Box:
```sh
sudo mailinabox
```
Note: I had to run " sudo rm /etc/mailinabox.conf" and then "reboot" and then "sudo mailinabox" again becuase it didn't work the first time.
---

## Setting Up SMTP Relay with Amazon SES (from your local computer)

To relay outbound mail through Amazon SES:

1. **Ensure SES is out of sandbox mode and your domain is verified.**
2. **Create SES SMTP credentials and SSM parameters** (these are created automatically by Terraform in `ses.tf`).
3. **Configure SSH access:**
   - Ensure you can SSH into your Mail-in-a-Box server from your computer (e.g., `ssh -i ~/.ssh/your-key.pem ubuntu@your.mailinabox.server`).
   - Update `REMOTE_USER`, `REMOTE_HOST`, and `SSH_KEY` variables in `setup_postfix_ses_relay.sh` as needed.
4. **On your local computer, run:**
   ```sh
   ./setup_postfix_ses_relay.sh
   ```
   This script will:
   - Retrieve SMTP credentials from SSM (locally)
   - Copy a setup script to your Mail-in-a-Box server via SSH
   - Configure Postfix on the server to relay mail through SES
   - Reload Postfix

5. **Reference:**
   - [Mail-in-a-Box: Advanced Configuration – Relaying](https://mailinabox.email/advanced-configuration.html#relaying)
   - [AWS SES: Using SMTP with SES](https://docs.aws.amazon.com/ses/latest/dg/send-email-smtp.html)

**Note:**
- You can revert to direct delivery by removing the relayhost config in Postfix and reloading Postfix.
- Do not use this server for anything other than Mail-in-a-Box.
- Configuration changes outside the admin panel may be overwritten.
- For advanced usage or troubleshooting, see the [full guide](https://mailinabox.email/guide.html).

## Architecture Diagram

```
+-------------------+         +-------------------+         +-------------------+         +-------------------+
|                   |  SSH    |                   |  SMTP   |                   |  API    |                   |
|   Your Local      +-------->+   EC2 Instance    +-------->+   Amazon SES      +------->+   SSM Parameter   |
|   Machine         |         | (Mail-in-a-Box)   |         |                   |         |   Store           |
|                   |         |                   |         |                   |         |                   |
+-------------------+         +-------------------+         +-------------------+         +-------------------+
```

- **Your Local Machine**: Runs setup scripts, manages AWS resources, and connects to the EC2 instance via SSH.
- **EC2 Instance (Mail-in-a-Box)**: Hosts the mail server, relays outbound mail through SES.
- **Amazon SES**: Handles outbound email delivery.
- **AWS SSM Parameter Store**: Securely stores SES SMTP credentials, accessed by your local machine during setup.

---

## Email Flow Diagram: Mail-in-a-Box <-> Gmail

### 1. User A (Mail-in-a-Box) sends email to User B (Gmail)

```
+---------+        +-------------------+        +-------------------+        +-------------+
| User A  |        |   EC2 Instance    |        |   Amazon SES      |        |   Gmail     |
| (MiaB)  +------->+ (Mail-in-a-Box)   +------->+   (SMTP Relay)    +------->+  (User B)   |
+---------+  SMTP  +-------------------+  SMTP  +-------------------+  SMTP  +-------------+
```

- User A composes and sends an email from their Mail-in-a-Box inbox.
- Mail-in-a-Box relays the email through Amazon SES.
- Amazon SES delivers the email to User B's Gmail inbox.

### 2. User B (Gmail) sends email to User A (Mail-in-a-Box)

```
+-------------+        +-------------------+        +-------------------+
|   Gmail     |        |   EC2 Instance    |        |   User A          |
|  (User B)   +------->+ (Mail-in-a-Box)   +------->+  (MiaB Inbox)     |
+-------------+  SMTP  +-------------------+  IMAP  +-------------------+
```

- User B (Gmail) sends an email to User A's Mail-in-a-Box address.
- The email is delivered directly to the Mail-in-a-Box server (EC2 instance).
- User A retrieves the email from their Mail-in-a-Box inbox (e.g., via IMAP or webmail).
