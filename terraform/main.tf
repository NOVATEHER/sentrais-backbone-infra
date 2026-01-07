# =============================================================================
# Sentrais Intelligence Backbone - Main Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "gcs" {
  #   bucket = "sentrais-backbone-terraform-state"
  #   prefix = "terraform/state"
  # }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# =============================================================================
# Enable Required APIs
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset(var.enable_apis)

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

# =============================================================================
# Artifact Registry Repository
# =============================================================================

resource "google_artifact_registry_repository" "sentrais_repo" {
  location      = var.region
  repository_id = var.artifact_registry_repository
  description   = "Sentrais container images"
  format        = "DOCKER"
  labels        = var.labels

  depends_on = [google_project_service.apis]
}

# =============================================================================
# Service Accounts
# =============================================================================

# Cloud Build Deployer service account
resource "google_service_account" "cloudbuild_deployer" {
  account_id   = "cloudbuild-deployer"
  display_name = "Cloud Build Deployer"
  description  = "Service account for Cloud Build deployments"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Ingestion API service account
resource "google_service_account" "ingestion_api" {
  account_id   = "ingestion-api"
  display_name = "Ingestion API Service"
  description  = "Service account for the Ingestion API"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# =============================================================================
# IAM Bindings - Cloud Build Deployer
# =============================================================================

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_deployer.email}"
}

resource "google_project_iam_member" "cloudbuild_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_deployer.email}"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_deployer.email}"
}

# =============================================================================
# IAM Bindings - Ingestion API
# =============================================================================

resource "google_project_iam_member" "ingestion_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ingestion_api.email}"
}

resource "google_project_iam_member" "ingestion_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.ingestion_api.email}"
}

# =============================================================================
# Output Values
# =============================================================================

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "artifact_registry_url" {
  description = "Artifact Registry URL for container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository}"
}

output "enabled_apis" {
  description = "List of enabled GCP APIs"
  value       = var.enable_apis
}

output "cloudbuild_deployer_email" {
  description = "Email of the Cloud Build Deployer service account"
  value       = google_service_account.cloudbuild_deployer.email
}

output "ingestion_api_email" {
  description = "Email of the Ingestion API service account"
  value       = google_service_account.ingestion_api.email
}
