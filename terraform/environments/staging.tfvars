# =============================================================================
# Sentrais Intelligence Backbone - Staging Environment
# =============================================================================
# Deployed from: develop branch

project_id   = "sentrais-backbone-dev"
project_name = "Sentrais Intelligence Backbone (Staging)"
region       = "us-central1"
zone         = "us-central1-a"

artifact_registry_repository = "sentrais-repo"

labels = {
  project     = "sentrais-backbone"
  environment = "staging"
  managed_by  = "terraform"
}
