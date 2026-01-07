-- ============================================================================
-- SENTRAIS INTELLIGENCE BACKBONE - MULTI-TENANCY & DATA GOVERNANCE
-- Google BigQuery DDL
-- Version: 1.0.0
-- Description: Client isolation, data sharing policies, and access control
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DATA SHARING POLICIES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.data_sharing_policies` (
  policy_id STRING NOT NULL,
  client_id STRING NOT NULL,
  engagement_id STRING,  -- NULL means applies to all engagements for client
  
  -- Sharing Permissions
  allow_cross_vertical_learning BOOL DEFAULT FALSE,  -- Can anonymized data train cross-vertical models?
  allow_benchmark_inclusion BOOL DEFAULT FALSE,  -- Can data be included in benchmarks?
  allow_pattern_extraction BOOL DEFAULT FALSE,  -- Can patterns be extracted (anonymized)?
  allow_playbook_derivation BOOL DEFAULT FALSE,  -- Can playbooks be derived from this data?
  
  -- Anonymization Requirements
  require_full_anonymization BOOL DEFAULT TRUE,
  anonymization_delay_days INT64 DEFAULT 90,  -- Days before data can be used
  
  -- Exclusions
  excluded_categories ARRAY<STRING>,  -- Categories never shared (e.g., 'vip', 'security_threat')
  excluded_signal_types ARRAY<STRING>,
  
  -- Time Bounds
  effective_date DATE NOT NULL,
  expiration_date DATE,
  
  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  created_by STRING,
  approved_by STRING,
  approved_at TIMESTAMP
)
OPTIONS (
  description = 'Data sharing and anonymization policies by client'
);

-- ----------------------------------------------------------------------------
-- CLIENT DATA VIEWS (Row-Level Security Simulation)
-- ----------------------------------------------------------------------------

-- Create authorized views for each major client type
-- These would be used with IAM policies in production

-- NFL Engagement View (EVERGAME / NFL IT)
CREATE OR REPLACE VIEW `sentrais_backbone.v_client_nfl` AS
SELECT *
FROM `sentrais_backbone.sentrasignals`
WHERE client_id IN (
  SELECT client_id FROM `sentrais_backbone.clients` 
  WHERE client_name LIKE '%NFL%' OR client_type = 'league'
);

-- View for anonymized cross-vertical learning data
CREATE OR REPLACE VIEW `sentrais_analytics.v_anonymized_signals` AS
SELECT
  signal_id,
  signal_timestamp,
  -- Anonymize source
  'ANONYMIZED' as source_system,
  vertical_id,
  'ANONYMIZED' as engagement_id,
  'ANONYMIZED' as client_id,
  
  -- Keep operational data
  signal_type,
  category,
  subcategory,
  severity,
  confidence,
  -- Generic description without specifics
  REGEXP_REPLACE(description, r'[A-Z][a-z]+ Stadium|[A-Z]+ Arena|Team [A-Z]+', '[VENUE/TEAM]') as description,
  
  -- Generalize location
  ST_SNAPTOGRID(location_geo, 0.01) as location_geo_generalized,  -- ~1km grid
  location_zone,
  
  operational_phase,
  
  -- Keep decision/outcome structure, anonymize specifics
  CASE WHEN decision_made IS NOT NULL THEN 'Decision recorded' ELSE NULL END as decision_made,
  decision_maker_role,  -- Keep role, not individual
  options_considered,
  effectiveness_score,
  
  -- NIN data (key for learning)
  nin_phase,
  playbook_id,
  pattern_tags,
  cross_vertical_relevance,
  
  signal_date
FROM `sentrais_backbone.sentrasignals` s
JOIN `sentrais_backbone.data_sharing_policies` p 
  ON s.client_id = p.client_id
WHERE 
  p.allow_cross_vertical_learning = TRUE
  AND s.signal_date <= DATE_SUB(CURRENT_DATE(), INTERVAL p.anonymization_delay_days DAY)
  AND s.is_anonymized = FALSE
  AND s.pii_present = FALSE
  AND s.category NOT IN UNNEST(p.excluded_categories);

-- ----------------------------------------------------------------------------
-- API ACCESS TOKENS
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.api_tokens` (
  token_id STRING NOT NULL,
  token_hash STRING NOT NULL,  -- Store hash, not actual token
  
  -- Ownership
  client_id STRING NOT NULL,
  engagement_id STRING,  -- NULL = all engagements
  
  -- Permissions
  permissions ARRAY<STRING>,  -- 'read', 'write', 'admin'
  allowed_verticals ARRAY<STRING>,
  allowed_categories ARRAY<STRING>,
  
  -- Rate Limits
  rate_limit_per_minute INT64 DEFAULT 60,
  rate_limit_per_day INT64 DEFAULT 10000,
  
  -- Status
  is_active BOOL DEFAULT TRUE,
  
  -- Validity
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  expires_at TIMESTAMP,
  last_used_at TIMESTAMP,
  
  -- Audit
  created_by STRING,
  revoked_at TIMESTAMP,
  revoked_by STRING,
  revocation_reason STRING
)
OPTIONS (
  description = 'API access tokens for client systems'
);

-- ----------------------------------------------------------------------------
-- API USAGE TRACKING
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.api_usage_log` (
  log_id STRING NOT NULL,
  token_id STRING NOT NULL,
  
  -- Request Details
  request_timestamp TIMESTAMP NOT NULL,
  endpoint STRING NOT NULL,
  method STRING NOT NULL,  -- GET, POST, PUT, DELETE
  
  -- Context
  client_id STRING,
  engagement_id STRING,
  
  -- Payload Summary
  signals_submitted INT64,
  signals_retrieved INT64,
  query_parameters JSON,
  
  -- Response
  response_code INT64,
  response_time_ms INT64,
  error_message STRING,
  
  -- Source
  source_ip STRING,
  user_agent STRING
)
PARTITION BY DATE(request_timestamp)
CLUSTER BY client_id, endpoint
OPTIONS (
  description = 'API usage tracking for rate limiting and auditing'
);

-- ----------------------------------------------------------------------------
-- DATA LINEAGE TRACKING
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.data_lineage` (
  lineage_id STRING NOT NULL,
  
  -- Source
  source_type STRING NOT NULL,  -- 'api_ingestion', 'manual_entry', 'system_generated', 'ml_inference', 'pattern_match'
  source_system STRING,
  source_signal_ids ARRAY<STRING>,
  
  -- Target
  target_type STRING NOT NULL,  -- 'signal', 'playbook', 'pattern', 'benchmark', 'lesson'
  target_id STRING NOT NULL,
  
  -- Transformation
  transformation_type STRING,  -- 'aggregation', 'anonymization', 'enrichment', 'classification'
  transformation_details JSON,
  
  -- Timestamp
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
OPTIONS (
  description = 'Data lineage for audit and compliance'
);

-- ----------------------------------------------------------------------------
-- AUDIT LOG
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.audit_log` (
  audit_id STRING NOT NULL,
  
  -- Action
  action_type STRING NOT NULL,  -- 'create', 'read', 'update', 'delete', 'export', 'share'
  resource_type STRING NOT NULL,  -- 'signal', 'playbook', 'client', 'engagement', 'policy'
  resource_id STRING NOT NULL,
  
  -- Actor
  actor_type STRING NOT NULL,  -- 'user', 'api_token', 'system'
  actor_id STRING NOT NULL,
  actor_role STRING,
  
  -- Context
  client_id STRING,
  engagement_id STRING,
  
  -- Details
  action_details JSON,
  previous_state JSON,  -- For updates
  new_state JSON,  -- For updates
  
  -- Source
  source_ip STRING,
  user_agent STRING,
  
  -- Timestamp
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY action_type, resource_type, client_id
OPTIONS (
  description = 'Comprehensive audit log for all system actions'
);

-- ----------------------------------------------------------------------------
-- CLIENT ISOLATION VERIFICATION QUERY
-- ----------------------------------------------------------------------------

-- This query can be run periodically to verify client data isolation
CREATE OR REPLACE VIEW `sentrais_backbone.v_isolation_verification` AS
SELECT 
  s.client_id,
  c.client_name,
  COUNT(*) as signal_count,
  COUNTIF(s.is_anonymized) as anonymized_count,
  COUNTIF(s.pii_present) as pii_count,
  MIN(s.signal_date) as earliest_signal,
  MAX(s.signal_date) as latest_signal
FROM `sentrais_backbone.sentrasignals` s
JOIN `sentrais_backbone.clients` c ON s.client_id = c.client_id
GROUP BY s.client_id, c.client_name;

-- ----------------------------------------------------------------------------
-- COMPLIANCE REPORTS
-- ----------------------------------------------------------------------------

-- Data sharing compliance report
CREATE OR REPLACE VIEW `sentrais_backbone.v_data_sharing_compliance` AS
SELECT 
  c.client_id,
  c.client_name,
  p.allow_cross_vertical_learning,
  p.allow_benchmark_inclusion,
  p.anonymization_delay_days,
  COUNT(DISTINCT s.signal_id) as total_signals,
  COUNTIF(s.signal_date <= DATE_SUB(CURRENT_DATE(), INTERVAL p.anonymization_delay_days DAY)) as signals_eligible_for_sharing,
  p.effective_date,
  p.expiration_date
FROM `sentrais_backbone.clients` c
LEFT JOIN `sentrais_backbone.data_sharing_policies` p ON c.client_id = p.client_id
LEFT JOIN `sentrais_backbone.sentrasignals` s ON c.client_id = s.client_id
GROUP BY c.client_id, c.client_name, p.allow_cross_vertical_learning, 
         p.allow_benchmark_inclusion, p.anonymization_delay_days,
         p.effective_date, p.expiration_date;
