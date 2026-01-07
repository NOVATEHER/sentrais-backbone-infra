# =============================================================================
# Sentrais Intelligence Backbone - Development Environment
# =============================================================================

project_id   = "sentrais-backbone-dev"
project_name = "Sentrais Intelligence Backbone (Dev)"
region       = "us-central1"
zone         = "us-central1-a"

artifact_registry_repository = "sentrais-repo"

labels = {
  project     = "sentrais-backbone"
  environment = "development"
  managed_by  = "terraform"
}
