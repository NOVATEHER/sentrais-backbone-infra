# Sentrais Intelligence Backbone - GCP Infrastructure

This repository contains the infrastructure configuration for the Sentrais Intelligence Backbone on Google Cloud Platform.

## Overview

The infrastructure includes:
- **BigQuery** - Data warehouse for analytics
- **Cloud Run** - Serverless container execution
- **Cloud Build** - CI/CD pipelines
- **Pub/Sub** - Messaging and event streaming
- **Secret Manager** - Secure secrets storage
- **Artifact Registry** - Container image storage
- **IAM** - Identity and access management

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and configured
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- GCP account with billing enabled
- Sufficient permissions to create projects and enable APIs

## Quick Start

### Option 1: Shell Script (Manual Setup)

```bash
# Make the script executable
chmod +x scripts/setup-gcp-project.sh

# Run with default settings
./scripts/setup-gcp-project.sh

# Or customize with environment variables
GCP_PROJECT_ID=my-project GCP_REGION=us-west1 ./scripts/setup-gcp-project.sh
```

### Option 2: Terraform (Recommended)

```bash
cd terraform

# Initialize Terraform
terraform init

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Project Structure

```
sentrais-backbone-infra/
├── scripts/
│   └── setup-gcp-project.sh    # Manual GCP setup script
├── terraform/
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   └── terraform.tfvars.example # Example variable values
├── docs/                        # Additional documentation
├── .gitignore
└── README.md
```

## Configuration

### Environment Variables (Shell Script)

| Variable | Default | Description |
|----------|---------|-------------|
| `GCP_PROJECT_ID` | `sentrais-backbone` | GCP Project ID |
| `GCP_PROJECT_NAME` | `Sentrais Intelligence Backbone` | Project display name |
| `GCP_REGION` | `us-central1` | Default GCP region |

### Terraform Variables

See `terraform/variables.tf` for all available variables.

## Enabled APIs

The following GCP APIs are enabled:

- `bigquery.googleapis.com` - BigQuery
- `run.googleapis.com` - Cloud Run
- `cloudbuild.googleapis.com` - Cloud Build
- `pubsub.googleapis.com` - Pub/Sub
- `secretmanager.googleapis.com` - Secret Manager
- `artifactregistry.googleapis.com` - Artifact Registry
- `iam.googleapis.com` - IAM
- `cloudresourcemanager.googleapis.com` - Resource Manager

## Service Accounts

The infrastructure creates the following service accounts with appropriate IAM permissions:

### Cloud Build Deployer (`cloudbuild-deployer`)

Used for CI/CD deployments via Cloud Build.

| Role | Purpose |
|------|---------|
| `roles/run.admin` | Deploy and manage Cloud Run services |
| `roles/bigquery.admin` | Manage BigQuery datasets and tables |
| `roles/iam.serviceAccountUser` | Act as other service accounts |

### Ingestion API (`ingestion-api`)

Used by the Ingestion API Cloud Run service.

| Role | Purpose |
|------|---------|
| `roles/bigquery.dataEditor` | Insert and update data in BigQuery |
| `roles/pubsub.publisher` | Publish messages to Pub/Sub topics |

## Artifact Registry

Container images are stored in Artifact Registry:

```
us-central1-docker.pkg.dev/sentrais-backbone/sentrais-repo
```

### Push an Image

```bash
# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Tag and push
docker tag myimage:latest us-central1-docker.pkg.dev/sentrais-backbone/sentrais-repo/myimage:latest
docker push us-central1-docker.pkg.dev/sentrais-backbone/sentrais-repo/myimage:latest
```

## Next Steps

After initial setup:

1. **Link Billing Account** - Ensure billing is enabled for the project
2. **Configure Remote State** - Enable GCS backend for Terraform state
3. **Set up Workload Identity** - Configure secure authentication for Cloud Run
4. **Create Cloud Build Triggers** - Set up CI/CD pipelines

## License

Proprietary - Sentrais AI
