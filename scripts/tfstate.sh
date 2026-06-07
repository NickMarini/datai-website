#!/bin/bash
# ==============================================================================
# Script: create_state_bucket.sh
# Purpose: Provisions an isolated, secured GCS bucket for Terraform state
# ==============================================================================
set -e

# ==============================================================================
# 1. Configuration Variables
# ==============================================================================
PROJECT_ID="datai-core"
REGION="europe-west6"       # Zurich
REPO_NAME="<REPO_NAME>"   # Change this for each new repository

# Standardized bucket naming convention
BUCKET_NAME="datai-state-${PROJECT_ID}-${REPO_NAME}"
SA_EMAIL="${REPO_NAME}-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Checking storage bucket status for ${REPO_NAME}..."
gcloud config set project "$PROJECT_ID"

# ==============================================================================
# 2. Provision Bucket (Idempotent: Skips if already exists)
# ==============================================================================
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
    echo "Creating secure state bucket: gs://${BUCKET_NAME} in ${REGION}..."
    
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --location="$REGION" \
        --uniform-bucket-level-access \
        --public-access-prevention

    echo "Enabling Object Versioning..."
    gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

else
    echo "✅ Storage bucket gs://${BUCKET_NAME} already exists. Skipping creation."
fi

# ==============================================================================
# 3. Authorize the Isolated Service Account
# ==============================================================================
echo "Granting Storage Object Admin access to ${SA_EMAIL}..."

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectAdmin"

echo -e "\n===================================================================="
echo "✅ State Bucket Is Ready!"
echo "Update your 'terraform/backend.tf' file with the following configuration:"
echo "===================================================================="
echo -e "terraform {\n  backend \"gcs\" {\n    bucket = \"${BUCKET_NAME}\"\n    # prefix is injected at init time via -backend-config=\"prefix=terraform/state/<env>\"\n  }\n}"
echo "===================================================================="