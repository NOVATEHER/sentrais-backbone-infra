# Automation Setup Guide

Complete guide for setting up CI/CD automation for the Sentrais Intelligence Backbone.

## Prerequisites

- GCP Project(s) created:
  - `sentrais-backbone` (production)
  - `sentrais-backbone-dev` (staging/dev)
- GitHub repository access
- Terraform >= 1.5.0

---

## 1. Initial GCP Setup

Run the bootstrap script once per environment:

```bash
# Development/Staging
GCP_PROJECT_ID=sentrais-backbone-dev ./scripts/bootstrap-gcp.sh

# Production
GCP_PROJECT_ID=sentrais-backbone ./scripts/bootstrap-gcp.sh
```

This enables APIs, creates service accounts, and sets up Artifact Registry.

---

## 2. GitHub Actions Setup

### 2.1 Configure Workload Identity Federation

Set up keyless authentication between GitHub and GCP:

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="sentrais-backbone" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="sentrais-backbone" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Get the Workload Identity Provider resource name
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="sentrais-backbone" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
```

### 2.2 Create CI/CD Service Account

```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions CI/CD"

# Grant required roles
PROJECT_ID=sentrais-backbone
SA_EMAIL=github-actions@${PROJECT_ID}.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.admin"

# Allow GitHub to impersonate this service account
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/sentrais-backbone"
```

### 2.3 Configure GitHub Secrets

Add these secrets to your GitHub repository:

| Secret | Value |
|--------|-------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Output from step 2.1 |
| `GCP_SERVICE_ACCOUNT_STAGING` | `github-actions@sentrais-backbone-dev.iam.gserviceaccount.com` |
| `GCP_SERVICE_ACCOUNT_PROD` | `github-actions@sentrais-backbone.iam.gserviceaccount.com` |

### 2.4 Configure Environments

In GitHub repository settings, create two environments:

1. **staging**
   - No protection rules (auto-deploy)

2. **production**
   - Required reviewers (add team members)
   - Wait timer: 5 minutes (optional)

---

## 3. Cloud Build Setup (Alternative)

If using Cloud Build instead of GitHub Actions:

### 3.1 Create Cloud Build Trigger

```bash
# Connect repository (do this in Console first)
# Then create triggers:

# Staging trigger (develop branch)
gcloud builds triggers create github \
  --name="deploy-staging" \
  --repo-name="sentrais-backbone" \
  --repo-owner="YOUR_ORG" \
  --branch-pattern="^develop$" \
  --build-config="cloudbuild.yaml"

# Production trigger (main branch)
gcloud builds triggers create github \
  --name="deploy-production" \
  --repo-name="sentrais-backbone" \
  --repo-owner="YOUR_ORG" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml"
```

### 3.2 Grant Cloud Build Permissions

```bash
PROJECT_ID=sentrais-backbone
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/iam.serviceAccountUser"
```

---

## 4. Terraform State Backend

For team collaboration, configure remote state:

### 4.1 Create State Bucket

```bash
gsutil mb -p sentrais-backbone -l us-central1 gs://sentrais-backbone-terraform-state
gsutil versioning set on gs://sentrais-backbone-terraform-state
```

### 4.2 Update terraform/main.tf

Uncomment the backend configuration:

```hcl
terraform {
  backend "gcs" {
    bucket = "sentrais-backbone-terraform-state"
    prefix = "terraform/state"
  }
}
```

---

## 5. Deployment Workflow

### Development Flow

```
Feature Branch → PR → Tests Run → Merge to develop → Deploy to Staging
                                                           ↓
                                        Merge to main → Deploy to Production
```

### Commands

```bash
# Deploy to staging
git checkout develop
git merge feature/my-feature
git push origin develop

# Deploy to production
git checkout main
git merge develop
git push origin main
```

### Verify Deployment

```bash
# Get service URL
gcloud run services describe ingestion-api \
  --region us-central1 \
  --format 'value(status.url)'

# Test health endpoint
curl https://ingestion-api-xxx.run.app/health
```

---

## 6. Rollback Procedures

### Rollback Cloud Run

```bash
# List revisions
gcloud run revisions list --service=ingestion-api --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic ingestion-api \
  --region=us-central1 \
  --to-revisions=ingestion-api-PREVIOUS_REVISION=100
```

### Rollback Terraform

```bash
# Revert to previous commit
git revert HEAD
git push origin main

# Or manually apply previous state
terraform apply -var-file=environments/prod.tfvars
```

---

## 7. Monitoring

### Cloud Run Logs

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=ingestion-api" \
  --limit=50 \
  --format=json
```

### Build History

```bash
# GitHub Actions
gh run list --workflow=deploy.yml

# Cloud Build
gcloud builds list --limit=10
```

---

## Troubleshooting

### Authentication Errors

```bash
# Verify Workload Identity setup
gcloud iam workload-identity-pools providers describe github-provider \
  --project=sentrais-backbone \
  --location=global \
  --workload-identity-pool=github-pool
```

### Permission Denied

```bash
# Check service account roles
gcloud projects get-iam-policy sentrais-backbone \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions@" \
  --format="table(bindings.role)"
```

### Build Failures

1. Check Cloud Build logs in Console
2. Verify Dockerfile builds locally
3. Check service account permissions

---

## Security Checklist

- [ ] Workload Identity Federation configured (no service account keys)
- [ ] Production environment requires approval
- [ ] Secrets stored in GitHub Secrets / Secret Manager
- [ ] Terraform state bucket has versioning enabled
- [ ] Service accounts follow least-privilege principle
- [ ] API tokens rotated regularly

---

*Sentrais Engineering*
