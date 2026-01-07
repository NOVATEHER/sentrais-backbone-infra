# =============================================================================
# Sentrais Intelligence Backbone - BigQuery Tables
# =============================================================================

# -----------------------------------------------------------------------------
# Datasets
# -----------------------------------------------------------------------------

resource "google_bigquery_dataset" "backbone" {
  dataset_id  = "sentrais_backbone"
  description = "Core operational data for Sentrais Intelligence Backbone"
  location    = var.region
  project     = var.project_id
  labels      = var.labels

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id  = "sentrais_analytics"
  description = "Analytics and cross-vertical learning data"
  location    = var.region
  project     = var.project_id
  labels      = var.labels

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Core Tables - sentrasignals
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "sentrasignals" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "sentrasignals"
  project             = var.project_id
  deletion_protection = true
  description         = "Core SentraSignal events - atomic unit of operational intelligence"

  time_partitioning {
    type  = "DAY"
    field = "signal_timestamp"
  }

  clustering = ["client_id", "vertical_id", "signal_type"]

  schema = jsonencode([
    { name = "signal_id", type = "STRING", mode = "REQUIRED", description = "Unique signal identifier" },
    { name = "signal_timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "When the signal was generated" },
    { name = "ingestion_timestamp", type = "TIMESTAMP", mode = "REQUIRED", description = "When the signal was ingested" },
    { name = "source_system", type = "STRING", mode = "REQUIRED", description = "Source system (EVERGAME, CiviGrid, etc.)" },
    { name = "vertical_id", type = "STRING", mode = "REQUIRED", description = "Vertical identifier" },
    { name = "engagement_id", type = "STRING", mode = "NULLABLE", description = "Engagement identifier" },
    { name = "client_id", type = "STRING", mode = "REQUIRED", description = "Client identifier" },
    { name = "signal_type", type = "STRING", mode = "REQUIRED", description = "Type of signal" },
    { name = "category", type = "STRING", mode = "REQUIRED", description = "Signal category" },
    { name = "severity", type = "INT64", mode = "REQUIRED", description = "Severity level (1-5)" },
    { name = "confidence", type = "FLOAT64", mode = "REQUIRED", description = "Confidence score (0-1)" },
    { name = "description", type = "STRING", mode = "NULLABLE", description = "Signal description" },
    { name = "location", type = "JSON", mode = "NULLABLE", description = "Location data (geo + semantic)" },
    { name = "operational_phase", type = "STRING", mode = "NULLABLE", description = "Current operational phase" },
    { name = "event_id", type = "STRING", mode = "NULLABLE", description = "Related event ID" },
    { name = "incident_id", type = "STRING", mode = "NULLABLE", description = "Related incident ID" },
    { name = "conditions", type = "JSON", mode = "NULLABLE", description = "Contextual conditions" },
    { name = "entities", type = "JSON", mode = "NULLABLE", description = "Related entities" },
    { name = "decision_made", type = "STRING", mode = "NULLABLE", description = "Decision made (if applicable)" },
    { name = "decision_maker_role", type = "STRING", mode = "NULLABLE", description = "Role of decision maker" },
    { name = "rationale", type = "STRING", mode = "NULLABLE", description = "Decision rationale" },
    { name = "expected_outcome", type = "STRING", mode = "NULLABLE", description = "Expected outcome" },
    { name = "actual_outcome", type = "STRING", mode = "NULLABLE", description = "Actual outcome (post-hoc)" },
    { name = "outcome_delta", type = "STRING", mode = "NULLABLE", description = "Difference from expected" },
    { name = "effectiveness_score", type = "INT64", mode = "NULLABLE", description = "Effectiveness (1-5)" },
    { name = "nin_phase", type = "STRING", mode = "NULLABLE", description = "NIN operational phase" },
    { name = "playbook_id", type = "STRING", mode = "NULLABLE", description = "Associated playbook" },
    { name = "pattern_tags", type = "STRING", mode = "REPEATED", description = "Pattern classification tags" },
    { name = "raw_payload", type = "JSON", mode = "NULLABLE", description = "Original raw payload" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Core Tables - events
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "events" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "events"
  project             = var.project_id
  deletion_protection = true
  description         = "Scheduled events (games, concerts, ceremonies)"

  time_partitioning {
    type  = "DAY"
    field = "event_start"
  }

  clustering = ["client_id", "vertical_id"]

  schema = jsonencode([
    { name = "event_id", type = "STRING", mode = "REQUIRED" },
    { name = "client_id", type = "STRING", mode = "REQUIRED" },
    { name = "vertical_id", type = "STRING", mode = "REQUIRED" },
    { name = "engagement_id", type = "STRING", mode = "NULLABLE" },
    { name = "event_name", type = "STRING", mode = "REQUIRED" },
    { name = "event_type", type = "STRING", mode = "REQUIRED" },
    { name = "venue_id", type = "STRING", mode = "NULLABLE" },
    { name = "venue_name", type = "STRING", mode = "NULLABLE" },
    { name = "event_start", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "event_end", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "expected_attendance", type = "INT64", mode = "NULLABLE" },
    { name = "actual_attendance", type = "INT64", mode = "NULLABLE" },
    { name = "status", type = "STRING", mode = "REQUIRED" },
    { name = "metadata", type = "JSON", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Core Tables - incidents
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "incidents" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "incidents"
  project             = var.project_id
  deletion_protection = true
  description         = "Incidents requiring response"

  time_partitioning {
    type  = "DAY"
    field = "incident_start"
  }

  clustering = ["client_id", "incident_type"]

  schema = jsonencode([
    { name = "incident_id", type = "STRING", mode = "REQUIRED" },
    { name = "client_id", type = "STRING", mode = "REQUIRED" },
    { name = "event_id", type = "STRING", mode = "NULLABLE" },
    { name = "incident_type", type = "STRING", mode = "REQUIRED" },
    { name = "severity", type = "INT64", mode = "REQUIRED" },
    { name = "status", type = "STRING", mode = "REQUIRED" },
    { name = "description", type = "STRING", mode = "NULLABLE" },
    { name = "location", type = "JSON", mode = "NULLABLE" },
    { name = "incident_start", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "incident_end", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "resolution", type = "STRING", mode = "NULLABLE" },
    { name = "playbooks_applied", type = "STRING", mode = "REPEATED" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Core Tables - playbooks
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "playbooks" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "playbooks"
  project             = var.project_id
  deletion_protection = true
  description         = "NIN Master Playbook definitions"

  schema = jsonencode([
    { name = "playbook_id", type = "STRING", mode = "REQUIRED" },
    { name = "playbook_code", type = "STRING", mode = "REQUIRED" },
    { name = "playbook_name", type = "STRING", mode = "REQUIRED" },
    { name = "category_id", type = "STRING", mode = "REQUIRED" },
    { name = "is_universal", type = "BOOL", mode = "REQUIRED" },
    { name = "verticals_applicable", type = "STRING", mode = "REPEATED" },
    { name = "trigger_conditions", type = "JSON", mode = "REQUIRED" },
    { name = "response_actions", type = "JSON", mode = "REQUIRED" },
    { name = "decision_authority", type = "JSON", mode = "NULLABLE" },
    { name = "success_metrics", type = "JSON", mode = "NULLABLE" },
    { name = "evidence_instances", type = "INT64", mode = "NULLABLE" },
    { name = "evidence_success_rate", type = "FLOAT64", mode = "NULLABLE" },
    { name = "status", type = "STRING", mode = "REQUIRED" },
    { name = "version", type = "INT64", mode = "REQUIRED" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Core Tables - clients
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "clients" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "clients"
  project             = var.project_id
  deletion_protection = true
  description         = "Client organizations"

  schema = jsonencode([
    { name = "client_id", type = "STRING", mode = "REQUIRED" },
    { name = "client_name", type = "STRING", mode = "REQUIRED" },
    { name = "vertical_id", type = "STRING", mode = "REQUIRED" },
    { name = "status", type = "STRING", mode = "REQUIRED" },
    { name = "allow_cross_vertical_learning", type = "BOOL", mode = "REQUIRED" },
    { name = "allow_benchmark_inclusion", type = "BOOL", mode = "REQUIRED" },
    { name = "anonymization_delay_days", type = "INT64", mode = "REQUIRED" },
    { name = "excluded_categories", type = "STRING", mode = "REPEATED" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Core Tables - api_tokens
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "api_tokens" {
  dataset_id          = google_bigquery_dataset.backbone.dataset_id
  table_id            = "api_tokens"
  project             = var.project_id
  deletion_protection = true
  description         = "API authentication tokens"

  schema = jsonencode([
    { name = "token_hash", type = "STRING", mode = "REQUIRED" },
    { name = "client_id", type = "STRING", mode = "REQUIRED" },
    { name = "engagement_id", type = "STRING", mode = "NULLABLE" },
    { name = "permissions", type = "STRING", mode = "REPEATED" },
    { name = "rate_limit_per_minute", type = "INT64", mode = "REQUIRED" },
    { name = "is_active", type = "BOOL", mode = "REQUIRED" },
    { name = "expires_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "last_used_at", type = "TIMESTAMP", mode = "NULLABLE" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Analytics Tables - abstract_patterns
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "abstract_patterns" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "abstract_patterns"
  project             = var.project_id
  deletion_protection = true
  description         = "Cross-vertical abstract patterns"

  schema = jsonencode([
    { name = "pattern_id", type = "STRING", mode = "REQUIRED" },
    { name = "pattern_name", type = "STRING", mode = "REQUIRED" },
    { name = "pattern_description", type = "STRING", mode = "NULLABLE" },
    { name = "detection_rules", type = "JSON", mode = "REQUIRED" },
    { name = "verticals_observed", type = "STRING", mode = "REPEATED" },
    { name = "occurrence_count", type = "INT64", mode = "REQUIRED" },
    { name = "confidence_score", type = "FLOAT64", mode = "REQUIRED" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Analytics Tables - benchmarks
# -----------------------------------------------------------------------------

resource "google_bigquery_table" "benchmarks" {
  dataset_id          = google_bigquery_dataset.analytics.dataset_id
  table_id            = "benchmarks"
  project             = var.project_id
  deletion_protection = true
  description         = "Cross-vertical performance benchmarks"

  time_partitioning {
    type  = "MONTH"
    field = "period_start"
  }

  schema = jsonencode([
    { name = "benchmark_id", type = "STRING", mode = "REQUIRED" },
    { name = "metric_name", type = "STRING", mode = "REQUIRED" },
    { name = "vertical_id", type = "STRING", mode = "NULLABLE" },
    { name = "period_start", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "period_end", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "sample_size", type = "INT64", mode = "REQUIRED" },
    { name = "p25", type = "FLOAT64", mode = "NULLABLE" },
    { name = "p50", type = "FLOAT64", mode = "NULLABLE" },
    { name = "p75", type = "FLOAT64", mode = "NULLABLE" },
    { name = "p90", type = "FLOAT64", mode = "NULLABLE" },
    { name = "mean", type = "FLOAT64", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])

  labels = var.labels
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "backbone_dataset_id" {
  description = "BigQuery backbone dataset ID"
  value       = google_bigquery_dataset.backbone.dataset_id
}

output "analytics_dataset_id" {
  description = "BigQuery analytics dataset ID"
  value       = google_bigquery_dataset.analytics.dataset_id
}
