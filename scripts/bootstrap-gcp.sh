#!/bin/bash
# =============================================================================
# Sentrais Intelligence Backbone - GCP Project Setup Script
# =============================================================================
# This script sets up the GCP project with required APIs and resources
# for the Sentrais Intelligence Backbone infrastructure.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Billing account linked to the project
#   - Sufficient permissions to create projects and enable APIs
# =============================================================================

set -euo pipefail

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-sentrais-backbone}"
PROJECT_NAME="${GCP_PROJECT_NAME:-Sentrais Intelligence Backbone}"
REGION="${GCP_REGION:-us-central1}"
ARTIFACT_REPO_NAME="sentrais-repo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Step 1: Create or select GCP project
# =============================================================================
setup_project() {
    log_info "Setting up GCP project: ${PROJECT_ID}"

    # Check if project exists
    if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        log_info "Project ${PROJECT_ID} already exists, selecting it..."
    else
        log_info "Creating new project: ${PROJECT_ID}"
        gcloud projects create "${PROJECT_ID}" --name="${PROJECT_NAME}"
    fi

    # Set the project as active
    gcloud config set project "${PROJECT_ID}"
    log_info "Active project set to: ${PROJECT_ID}"
}

# =============================================================================
# Step 2: Enable required APIs
# =============================================================================
enable_apis() {
    log_info "Enabling required GCP APIs..."

    local apis=(
        "bigquery.googleapis.com"
        "run.googleapis.com"
        "cloudbuild.googleapis.com"
        "pubsub.googleapis.com"
        "secretmanager.googleapis.com"
        "artifactregistry.googleapis.com"
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "aiplatform.googleapis.com"
        "containerscanning.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )

    for api in "${apis[@]}"; do
        log_info "Enabling ${api}..."
        gcloud services enable "${api}" --project="${PROJECT_ID}"
    done

    log_info "All required APIs enabled successfully"
}

# =============================================================================
# Step 3: Create Artifact Registry repository
# =============================================================================
setup_artifact_registry() {
    log_info "Setting up Artifact Registry..."

    # Check if repository exists
    if gcloud artifacts repositories describe "${ARTIFACT_REPO_NAME}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_warn "Artifact Registry repository ${ARTIFACT_REPO_NAME} already exists"
    else
        log_info "Creating Artifact Registry repository: ${ARTIFACT_REPO_NAME}"
        gcloud artifacts repositories create "${ARTIFACT_REPO_NAME}" \
            --repository-format=docker \
            --location="${REGION}" \
            --description="Sentrais container images" \
            --project="${PROJECT_ID}"
    fi

    log_info "Artifact Registry setup complete"
    log_info "Container registry URL: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}"
}

# =============================================================================
# Step 4: Create service accounts
# =============================================================================
setup_service_accounts() {
    log_info "Setting up service accounts..."

    # Cloud Build Deployer service account
    if gcloud iam service-accounts describe "cloudbuild-deployer@${PROJECT_ID}.iam.gserviceaccount.com" &>/dev/null; then
        log_warn "Service account cloudbuild-deployer already exists"
    else
        log_info "Creating service account: cloudbuild-deployer"
        gcloud iam service-accounts create cloudbuild-deployer \
            --display-name="Cloud Build Deployer" \
            --project="${PROJECT_ID}"
    fi

    # Ingestion API service account
    if gcloud iam service-accounts describe "ingestion-api@${PROJECT_ID}.iam.gserviceaccount.com" &>/dev/null; then
        log_warn "Service account ingestion-api already exists"
    else
        log_info "Creating service account: ingestion-api"
        gcloud iam service-accounts create ingestion-api \
            --display-name="Ingestion API Service" \
            --project="${PROJECT_ID}"
    fi

    log_info "Service accounts created successfully"
}

# =============================================================================
# Step 5: Grant IAM permissions
# =============================================================================
setup_iam_bindings() {
    log_info "Configuring IAM permissions..."

    # Cloud Build Deployer permissions
    log_info "Granting permissions to cloudbuild-deployer..."

    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:cloudbuild-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/run.admin" \
        --condition=None \
        --quiet

    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:cloudbuild-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/bigquery.admin" \
        --condition=None \
        --quiet

    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:cloudbuild-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser" \
        --condition=None \
        --quiet

    # Ingestion API permissions
    log_info "Granting permissions to ingestion-api..."

    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:ingestion-api@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/bigquery.dataEditor" \
        --condition=None \
        --quiet

    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:ingestion-api@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="roles/pubsub.publisher" \
        --condition=None \
        --quiet

    log_info "IAM permissions configured successfully"
}

# =============================================================================
# Step 6: Display summary
# =============================================================================
display_summary() {
    echo ""
    echo "============================================================================="
    echo "GCP Project Setup Complete!"
    echo "============================================================================="
    echo ""
    echo "Project ID:     ${PROJECT_ID}"
    echo "Project Name:   ${PROJECT_NAME}"
    echo "Region:         ${REGION}"
    echo ""
    echo "Enabled APIs:"
    echo "  - BigQuery"
    echo "  - Cloud Run"
    echo "  - Cloud Build"
    echo "  - Pub/Sub"
    echo "  - Secret Manager"
    echo "  - Artifact Registry"
    echo "  - IAM"
    echo "  - Cloud Resource Manager"
    echo "  - Vertex AI (Gemini)"
    echo "  - Container Scanning"
    echo "  - Cloud Logging"
    echo "  - Cloud Monitoring"
    echo ""
    echo "Artifact Registry:"
    echo "  Repository: ${ARTIFACT_REPO_NAME}"
    echo "  URL: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO_NAME}"
    echo ""
    echo "Service Accounts:"
    echo "  cloudbuild-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
    echo "    - roles/run.admin"
    echo "    - roles/bigquery.admin"
    echo "    - roles/iam.serviceAccountUser"
    echo ""
    echo "  ingestion-api@${PROJECT_ID}.iam.gserviceaccount.com"
    echo "    - roles/bigquery.dataEditor"
    echo "    - roles/pubsub.publisher"
    echo ""
    echo "Next steps:"
    echo "  1. Link a billing account to the project"
    echo "  2. Configure Terraform backend (if using Terraform)"
    echo "  3. Deploy infrastructure using Terraform"
    echo "  4. Set up Workload Identity for Cloud Run services"
    echo "============================================================================="
}

# =============================================================================
# Main execution
# =============================================================================
main() {
    log_info "Starting Sentrais Intelligence Backbone GCP setup..."
    echo ""

    setup_project
    enable_apis
    setup_artifact_registry
    setup_service_accounts
    setup_iam_bindings
    display_summary
}

# Run main function
main "$@"
