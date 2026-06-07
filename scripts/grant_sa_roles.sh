#!/bin/bash
# ==============================================================================
# Script: grant_sa_roles.sh
# Purpose: Grants the minimum required IAM roles to the GitHub Actions deployer
#          Service Account created by setup_wif.sh.
#
# Instructions:
# 1. Ensure setup_wif.sh has already been run successfully.
# 2. Make the script executable: chmod +x grant_sa_roles.sh
# 3. Run: ./scripts/grant_sa_roles.sh
#
# To add or remove roles, edit the ROLES array in Section 2.
# Re-running this script is safe — granting an already-held role is a no-op.
# ==============================================================================

set -e

# ==============================================================================
# 1. Configuration (must match setup_wif.sh)
# ==============================================================================
PROJECT_ID="datai-core"  # Update this to match the project used in setup_wif.sh
SA_NAME="<SA_NAME>"  # Update this to match the SA_NAME used in setup_wif.sh (e.g., datai-website-deployer)
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# ==============================================================================
# 2. Role Definitions
#
# Add/remove roles here as the deployment requirements change.
# Each entry is:   "roles/<role>"   # reason
# ==============================================================================
ROLES=(
  "roles/run.admin"                     # Deploy and manage Cloud Run services
  "roles/artifactregistry.writer"       # Push Docker images to Artifact Registry
  "roles/storage.admin"                 # Read/write GCS buckets (build artefacts, static assets)
  "roles/cloudbuild.builds.builder"     # Submit Cloud Build jobs
  "roles/iam.serviceAccountUser"        # Allow SA to act-as itself when deploying Cloud Run
  "roles/secretmanager.secretAccessor"  # Read secrets at deploy time

  # Cloud SQL (PostgreSQL)
  "roles/cloudsql.client"               # Connect to Cloud SQL instances via Auth Proxy or direct
  "roles/cloudsql.instanceUser"         # Authenticate to Cloud SQL databases using IAM auth
)

# ==============================================================================
# 3. Grant Roles
# ==============================================================================
echo "Granting IAM roles to: ${SA_EMAIL}"
echo "Project: ${PROJECT_ID}"
echo "======================================================================"

for ROLE in "${ROLES[@]}"; do
  # Strip inline comment from role string (everything after whitespace)
  ROLE_ID=$(echo "$ROLE" | awk '{print $1}')
  echo "  Granting ${ROLE_ID}..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE_ID" \
    --quiet
  echo "  ✓ ${ROLE_ID}"
done

# ==============================================================================
# 4. Summary
# ==============================================================================
echo ""
echo "======================================================================"
echo "✅ Done. Roles granted to ${SA_EMAIL}:"
for ROLE in "${ROLES[@]}"; do
  ROLE_ID=$(echo "$ROLE" | awk '{print $1}')
  echo "   - ${ROLE_ID}"
done
echo ""
echo "To audit current bindings run:"
echo "  gcloud projects get-iam-policy ${PROJECT_ID} \\"
echo "    --flatten='bindings[].members' \\"
echo "    --filter='bindings.members:${SA_EMAIL}' \\"
echo "    --format='table(bindings.role)'"
echo "======================================================================"
