# Google Cloud Native Automation Setup Guide

Complete guide for setting up CI/CD automation using Google Cloud Build and Vertex AI (Gemini) for the Sentrais Intelligence Backbone.

## Overview

This infrastructure uses **100% Google Cloud native tools**:
- **Cloud Build** - CI/CD pipeline orchestration
- **Vertex AI (Gemini)** - AI-powered code analysis
- **Artifact Registry** - Container image storage
- **Cloud Run** - Serverless container deployment
- **Container Scanning** - Security vulnerability detection
- **Cloud Logging** - Centralized logging
- **Cloud Monitoring** - Observability

---

## Prerequisites

- GCP Project with billing enabled
- `gcloud` CLI installed and authenticated
- Repository connected to Cloud Build

---

## 1. Initial GCP Setup

Run the bootstrap script to enable all required APIs and create service accounts:

```bash
# Set your project ID
export GCP_PROJECT_ID=sentrais-backbone-dev

# Run bootstrap
chmod +x scripts/bootstrap-gcp.sh
./scripts/bootstrap-gcp.sh
```

This enables:
- BigQuery, Cloud Run, Cloud Build, Pub/Sub
- Secret Manager, Artifact Registry, IAM
- **Vertex AI (Gemini)** for AI code analysis
- **Container Scanning** for security
- Cloud Logging & Monitoring

---

## 2. Cloud Build Setup

### 2.1 Connect Repository

1. Go to [Cloud Build Triggers](https://console.cloud.google.com/cloud-build/triggers)
2. Click **Connect Repository**
3. Select **GitHub** and authorize
4. Choose your repository

### 2.2 Create Build Triggers

```bash
PROJECT_ID=sentrais-backbone-dev
REPO_OWNER=NOVATEHER
REPO_NAME=sentrais-backbone-infra

# Staging trigger (develop branch)
gcloud builds triggers create github \
  --name="deploy-staging" \
  --repo-name="$REPO_NAME" \
  --repo-owner="$REPO_OWNER" \
  --branch-pattern="^develop$" \
  --build-config="cloudbuild.yaml" \
  --project="$PROJECT_ID"

# Production trigger (main branch)
gcloud builds triggers create github \
  --name="deploy-production" \
  --repo-name="$REPO_NAME" \
  --repo-owner="$REPO_OWNER" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --project="$PROJECT_ID"
```

### 2.3 Grant Cloud Build Permissions

```bash
PROJECT_ID=sentrais-backbone-dev
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Cloud Run deployment
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/run.admin"

# Service account impersonation
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/iam.serviceAccountUser"

# Artifact Registry
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/artifactregistry.writer"

# Vertex AI (for Gemini code analysis)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/aiplatform.user"

# Logging
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/logging.logWriter"
```

---

## 3. Pipeline Stages

The `cloudbuild.yaml` pipeline includes:

| Stage | Description |
|-------|-------------|
| `detect-environment` | Determines staging/production from branch |
| `gemini-code-review` | AI-powered code analysis using Vertex AI |
| `terraform-init` | Initialize Terraform |
| `terraform-plan` | Plan infrastructure changes |
| `terraform-apply` | Apply infrastructure |
| `build-container` | Build Docker image |
| `push-container` | Push to Artifact Registry |
| `security-scan` | Container vulnerability scanning |
| `deploy-cloud-run` | Deploy to Cloud Run |
| `health-check` | Verify deployment |
| `build-summary` | Log results |

---

## 4. Terraform State Backend

For team collaboration, configure remote state:

### 4.1 Create State Bucket

```bash
PROJECT_ID=sentrais-backbone-dev

gsutil mb -p ${PROJECT_ID} -l us-central1 gs://${PROJECT_ID}-terraform-state
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### 4.2 Enable Backend in terraform/main.tf

Uncomment:

```hcl
terraform {
  backend "gcs" {
    bucket = "sentrais-backbone-dev-terraform-state"
    prefix = "terraform/state"
  }
}
```

---

## 5. Deployment Workflow

### Branch Strategy

```
Feature Branch → PR → Merge to develop → Deploy to Staging
                                              ↓
                        Merge to main → Deploy to Production
```

### Deploy Commands

```bash
# Deploy to staging
git checkout develop
git merge feature/my-feature
git push origin develop
# Cloud Build automatically triggers

# Deploy to production
git checkout main
git merge develop
git push origin main
# Cloud Build automatically triggers
```

### Manual Trigger

```bash
# Submit build manually
gcloud builds submit --config=cloudbuild.yaml

# Trigger specific build
gcloud builds triggers run deploy-staging --branch=develop
```

---

## 6. Verify Deployment

```bash
# Get service URL
gcloud run services describe ingestion-api-staging \
  --region us-central1 \
  --format 'value(status.url)'

# Test health endpoint
curl https://ingestion-api-staging-xxx.run.app/health

# View recent builds
gcloud builds list --limit=10
```

---

## 7. Monitoring & Logs

### Cloud Build Logs

```bash
# List recent builds
gcloud builds list --limit=10

# View specific build
gcloud builds log BUILD_ID

# Stream logs
gcloud builds log BUILD_ID --stream
```

### Cloud Run Logs

```bash
# View service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ingestion-api-staging" \
  --limit=50 \
  --format=json
```

### Build Notifications (via Cloud Logging)

```bash
# View build results
gcloud logging read 'logName="projects/PROJECT_ID/logs/sentrais-build-log"' \
  --limit=20 \
  --format=json
```

---

## 8. Rollback Procedures

### Rollback Cloud Run

```bash
# List revisions
gcloud run revisions list --service=ingestion-api-staging --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic ingestion-api-staging \
  --region=us-central1 \
  --to-revisions=ingestion-api-staging-PREVIOUS_REVISION=100
```

### Rollback via Git

```bash
# Revert last commit
git revert HEAD
git push origin develop
# Cloud Build will redeploy
```

---

## 9. Security Features

### Container Scanning

Automatic vulnerability scanning on every push to Artifact Registry:

```bash
# View scan results
gcloud artifacts docker images list-vulnerabilities \
  us-central1-docker.pkg.dev/PROJECT_ID/sentrais-repo/ingestion-api:latest
```

### Gemini Code Analysis

AI-powered code review runs on every build, checking for:
- Security vulnerabilities
- Best practices violations
- Code quality issues

---

## 10. Troubleshooting

### Build Failures

```bash
# Check build logs
gcloud builds log BUILD_ID

# Check Cloud Build service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloudbuild" \
  --format="table(bindings.role)"
```

### API Not Enabled

```bash
# Enable missing API
gcloud services enable SERVICE_NAME.googleapis.com

# Verify enabled APIs
gcloud services list --enabled
```

### Terraform Errors

```bash
# Re-initialize terraform
cd terraform
terraform init -upgrade
terraform validate
```

---

## Security Checklist

- [ ] Billing enabled on project
- [ ] All required APIs enabled
- [ ] Cloud Build service account has required roles
- [ ] Terraform state bucket has versioning enabled
- [ ] Container scanning enabled
- [ ] Service accounts follow least-privilege principle
- [ ] Secrets stored in Secret Manager (not in code)

---

## Quick Reference

| Task | Command |
|------|---------|
| Run bootstrap | `./scripts/bootstrap-gcp.sh` |
| Manual build | `gcloud builds submit --config=cloudbuild.yaml` |
| List builds | `gcloud builds list --limit=10` |
| View logs | `gcloud builds log BUILD_ID` |
| Get service URL | `gcloud run services describe SERVICE --region=us-central1 --format='value(status.url)'` |

---

*Sentrais Engineering - Google Cloud Native*
