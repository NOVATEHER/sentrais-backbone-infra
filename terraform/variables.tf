# =============================================================================
# Sentrais Intelligence Backbone - Terraform Variables
# =============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "sentrais-backbone"
}

variable "project_name" {
  description = "GCP Project display name"
  type        = string
  default     = "Sentrais Intelligence Backbone"
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Default GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "sentrais-repo"
}

variable "enable_apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default = [
    "bigquery.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "sentrais-backbone"
    environment = "production"
    managed_by  = "terraform"
  }
}
