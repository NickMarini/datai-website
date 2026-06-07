#!/bin/bash
# ==============================================================================
# Script: setup_wif.sh
# Purpose: Provisions GCP Workload Identity Federation for GitHub Actions
# Instructions:
# 1. Update the configuration variables in Section 1.
# 2. Ensure you have the gcloud CLI installed and authenticated with permissions to manage IAM and Workload Identity.
# 3. Make the script executable: chmod +x setup_wif.sh
# 4. Run this script to set up the WIF trust relationship. 
# 5. Copy the output values for WIF_PROVIDER and SERVICE_ACCOUNT to your GitHub Actions Secrets.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# ==============================================================================
# 1. Configuration Variables (Update these for new projects)
# ==============================================================================
PROJECT_ID="datai-core"  # GCP project where the SA and WIF resources will be created
GITHUB_ORG="NickMarini"  # GitHub username or organization that owns the repository
REPO_NAME="<REPO_NAME>"  # GitHub repository name

# Derived variables
GITHUB_REPO="${GITHUB_ORG}/${REPO_NAME}"
SA_NAME="${REPO_NAME}-deployer"    # Unique service account per repo (e.g., datai-website-deployer)
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"

echo "Starting Workload Identity Federation setup for ${PROJECT_ID}..."

# ==============================================================================
# 2. Environment Setup
# ==============================================================================
echo "Setting active GCP project..."
gcloud config set project "$PROJECT_ID"

# Fetch the numerical project number dynamically
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

echo "Enabling required IAM and Resource Manager APIs..."
gcloud services enable iamcredentials.googleapis.com cloudresourcemanager.googleapis.com

# ==============================================================================
# 3. Identity Provisioning
# ==============================================================================
echo "Creating Service Account: ${SA_NAME}..."
# The || true prevents the script from failing if the SA already exists
gcloud iam service-accounts create "$SA_NAME" \
    --display-name="GitHub Actions Deployer SA" || true

echo "Creating Workload Identity Pool: ${POOL_NAME}..."
gcloud iam workload-identity-pools create "$POOL_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool" || true

echo "Creating OIDC Provider: ${PROVIDER_NAME}..."
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository == '${GITHUB_REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com" || true

# ==============================================================================
# 4. IAM Binding (The Trust Relationship)
# ==============================================================================
echo "Binding GitHub repository to the Service Account..."
gcloud iam service-accounts add-iam-policy-binding "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO}"

# ==============================================================================
# 5. Output Verification
# ==============================================================================
echo -e "\n===================================================================="
echo "✅ SUCCESS: Setup Complete!"
echo "Save these values for your GitHub Actions Secrets:"
echo "===================================================================="
echo "WIF_PROVIDER: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"
echo "SERVICE_ACCOUNT: ${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "===================================================================="