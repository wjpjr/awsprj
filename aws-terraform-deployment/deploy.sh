#!/usr/bin/env bash
#
# Drives the two-stage deployment: state bootstrap, then main environment.
# Run from the repo root: ./deploy.sh
#
set -euo pipefail

BOOTSTRAP_DIR="01-state-bootstrap"
MAIN_DIR="02-main-environment"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }

bold "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "ERROR: No valid AWS credentials found. Run 'aws configure' or set up SSO first." >&2
  exit 1
fi
aws sts get-caller-identity

bold "Checking Terraform is installed..."
if ! command -v terraform > /dev/null 2>&1; then
  echo "ERROR: terraform not found on PATH. Install it: https://developer.hashicorp.com/terraform/install" >&2
  exit 1
fi
terraform version

# --- Stage 1: state bootstrap ---
bold "=== Stage 1: Bootstrapping remote state (S3 + DynamoDB) ==="
pushd "$BOOTSTRAP_DIR" > /dev/null

terraform init -input=false
terraform plan -out=tfplan
read -rp "Apply state bootstrap? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted before applying bootstrap."
  exit 1
fi
terraform apply -input=false tfplan

BACKEND_SNIPPET=$(terraform output -raw backend_config_snippet)
popd > /dev/null

bold "Backend config generated:"
echo "$BACKEND_SNIPPET"
echo
echo "NOTE: This script does not auto-edit backend.tf for you."
echo "Paste the snippet above into ${MAIN_DIR}/backend.tf (uncommented) before continuing."
read -rp "Press Enter once backend.tf is updated, or Ctrl+C to stop here... "

# --- Stage 2: main environment ---
bold "=== Stage 2: Deploying main environment (VPC + EC2) ==="
pushd "$MAIN_DIR" > /dev/null

terraform init -input=false
terraform plan -out=tfplan
read -rp "Apply main environment? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted before applying main environment."
  exit 1
fi
terraform apply -input=false tfplan

bold "Deployment complete. Outputs:"
terraform output
popd > /dev/null

bold "Connect to the instance via SSM (no SSH key needed):"
echo "  aws ssm start-session --target \$(cd ${MAIN_DIR} && terraform output -raw app_instance_id)"
