-- ============================================================================
-- SENTRAIS INTELLIGENCE BACKBONE - CORE SCHEMA
-- Google BigQuery DDL
-- Version: 1.0.0
-- Description: Core tables for the Sentrais Unified Frame and Intelligence System
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DATASET CREATION
-- ----------------------------------------------------------------------------

-- Main operational dataset
CREATE SCHEMA IF NOT EXISTS `sentrais_backbone`
OPTIONS (
  description = 'Sentrais Intelligence Backbone - Unified Frame for Operational Intelligence',
  location = 'US'  -- Multi-region for redundancy
);

-- Analytics dataset for cross-vertical learning
CREATE SCHEMA IF NOT EXISTS `sentrais_analytics`
OPTIONS (
  description = 'Sentrais Analytics - Cross-Vertical Learning and Pattern Recognition',
  location = 'US'
);

-- ----------------------------------------------------------------------------
-- ENUM/LOOKUP TABLES
-- ----------------------------------------------------------------------------

-- Verticals served by Sentrais
CREATE TABLE IF NOT EXISTS `sentrais_backbone.dim_verticals` (
  vertical_id STRING NOT NULL,
  vertical_name STRING NOT NULL,
  vertical_description STRING,
  tam_estimate_billions FLOAT64,
  is_active BOOL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS (
  description = 'Dimension table for Sentrais market verticals'
);

-- Initial vertical data
INSERT INTO `sentrais_backbone.dim_verticals` (vertical_id, vertical_name, vertical_description, tam_estimate_billions)
VALUES
  ('sports_entertainment', 'Sports & Entertainment', 'Leagues, Venue Management, City Resilience', 8.5),
  ('live_events', 'Live Events Intelligence', 'Concerts/Tours, VIP/Premium, Production, Venue Tech', 80.0),
  ('aviation_transportation', 'Aviation & Transportation', 'Airport operations, TSA checkpoint intelligence, emergency preparedness', 15.0),
  ('federal_government', 'Federal Government', 'FEMA, DHS, CISA, DoD installations, state/local emergency management', 5.0),
  ('mega_events', 'Mega-Events', 'FIFA 2026, Olympics, Host cities, LOCs, stadium operators, multi-agency coordination', 3.5),
  ('critical_infrastructure', 'Critical Infrastructure', 'Energy, Communications, Water, Healthcare systems', 10.0);

-- Signal types taxonomy
CREATE TABLE IF NOT EXISTS `sentrais_backbone.dim_signal_types` (
  signal_type_id STRING NOT NULL,
  signal_type_name STRING NOT NULL,
  signal_type_description STRING,
  requires_decision BOOL DEFAULT FALSE,
  requires_outcome BOOL DEFAULT FALSE
)
OPTIONS (
  description = 'Taxonomy of signal types captured in the system'
);

INSERT INTO `sentrais_backbone.dim_signal_types` (signal_type_id, signal_type_name, signal_type_description, requires_decision, requires_outcome)
VALUES
  ('observation', 'Observation', 'Raw situational awareness data point', FALSE, FALSE),
  ('anomaly', 'Anomaly', 'Deviation from expected patterns or baselines', FALSE, FALSE),
  ('threshold_breach', 'Threshold Breach', 'Predefined limit exceeded', TRUE, TRUE),
  ('decision', 'Decision', 'Action taken or not taken by human or system', TRUE, TRUE),
  ('outcome', 'Outcome', 'Result of a decision or event', FALSE, FALSE),
  ('trend', 'Trend', 'Pattern emerging over time', FALSE, FALSE),
  ('prediction', 'Prediction', 'Forecasted future state or event', TRUE, TRUE),
  ('escalation', 'Escalation', 'Situation requiring elevated response', TRUE, TRUE),
  ('resolution', 'Resolution', 'Closure of an incident or situation', FALSE, TRUE);

-- Categories taxonomy
CREATE TABLE IF NOT EXISTS `sentrais_backbone.dim_categories` (
  category_id STRING NOT NULL,
  category_name STRING NOT NULL,
  category_description STRING,
  parent_category_id STRING  -- For hierarchical categories
)
OPTIONS (
  description = 'Taxonomy of operational categories'
);

INSERT INTO `sentrais_backbone.dim_categories` (category_id, category_name, category_description, parent_category_id)
VALUES
  ('crowd', 'Crowd Management', 'Crowd flow, density, behavior', NULL),
  ('crowd_ingress', 'Ingress Operations', 'Entry and arrival management', 'crowd'),
  ('crowd_egress', 'Egress Operations', 'Exit and departure management', 'crowd'),
  ('crowd_density', 'Density Management', 'Crowd density monitoring and control', 'crowd'),
  ('weather', 'Weather', 'Meteorological conditions and impacts', NULL),
  ('weather_precipitation', 'Precipitation', 'Rain, snow, hail events', 'weather'),
  ('weather_lightning', 'Lightning', 'Electrical storm management', 'weather'),
  ('weather_temperature', 'Temperature Extremes', 'Heat and cold management', 'weather'),
  ('security', 'Security', 'Physical and cyber security', NULL),
  ('security_screening', 'Screening Operations', 'Entry screening and checkpoints', 'security'),
  ('security_threat', 'Threat Management', 'Threat detection and response', 'security'),
  ('infrastructure', 'Infrastructure', 'Physical and technical infrastructure', NULL),
  ('infrastructure_power', 'Power Systems', 'Electrical infrastructure', 'infrastructure'),
  ('infrastructure_comms', 'Communications', 'Communication systems', 'infrastructure'),
  ('infrastructure_it', 'IT Systems', 'Information technology infrastructure', 'infrastructure'),
  ('medical', 'Medical', 'Health and medical services', NULL),
  ('resource', 'Resource Management', 'Personnel, equipment, supplies', NULL),
  ('personnel', 'Personnel', 'Staff and workforce', NULL),
  ('transportation', 'Transportation', 'Movement and logistics', NULL),
  ('vip', 'VIP/Dignitary', 'High-value individual management', NULL);

-- Operational phases
CREATE TABLE IF NOT EXISTS `sentrais_backbone.dim_operational_phases` (
  phase_id STRING NOT NULL,
  phase_name STRING NOT NULL,
  phase_description STRING,
  typical_duration_hours FLOAT64,
  phase_order INT64
)
OPTIONS (
  description = 'Operational phases for event and incident lifecycle'
);

INSERT INTO `sentrais_backbone.dim_operational_phases` (phase_id, phase_name, phase_description, typical_duration_hours, phase_order)
VALUES
  ('planning', 'Planning', 'Pre-event planning and preparation phase', 720, 1),
  ('pre_event', 'Pre-Event', 'Day-of setup and final preparations', 8, 2),
  ('ingress', 'Ingress', 'Arrival and entry operations', 4, 3),
  ('active', 'Active', 'Main event or steady-state operations', 4, 4),
  ('egress', 'Egress', 'Departure and exit operations', 3, 5),
  ('post_event', 'Post-Event', 'Closeout and demobilization', 4, 6),
  ('steady_state', 'Steady State', 'Normal operations (non-event)', NULL, 0),
  ('escalation', 'Escalation', 'Elevated response posture', NULL, 10),
  ('response', 'Response', 'Active incident response', NULL, 11),
  ('recovery', 'Recovery', 'Return to normal operations', NULL, 12);

-- ----------------------------------------------------------------------------
-- CLIENT & ENGAGEMENT TABLES
-- ----------------------------------------------------------------------------

-- Client organizations
CREATE TABLE IF NOT EXISTS `sentrais_backbone.clients` (
  client_id STRING NOT NULL,
  client_name STRING NOT NULL,
  client_type STRING,  -- 'league', 'venue', 'city', 'federal', 'corporate'
  primary_vertical_id STRING,
  contract_start_date DATE,
  contract_end_date DATE,
  is_active BOOL DEFAULT TRUE,
  data_sharing_consent BOOL DEFAULT FALSE,  -- Can their data inform cross-vertical learning?
  data_anonymization_required BOOL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
)
OPTIONS (
  description = 'Client organizations served by Sentrais'
);

-- Client projects/engagements
CREATE TABLE IF NOT EXISTS `sentrais_backbone.engagements` (
  engagement_id STRING NOT NULL,
  client_id STRING NOT NULL,
  engagement_name STRING NOT NULL,
  engagement_type STRING,  -- 'platform', 'advisory', 'hybrid'
  vertical_id STRING NOT NULL,
  source_system STRING,  -- 'EVERGAME', 'CiviGrid', 'eVenu', 'NFL_IT', etc.
  start_date DATE,
  end_date DATE,
  is_active BOOL DEFAULT TRUE,
  arr_value FLOAT64,  -- Annual recurring revenue
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
)
OPTIONS (
  description = 'Client engagements and projects'
);

-- ----------------------------------------------------------------------------
-- CORE SENTRASIGNAL TABLE
-- ----------------------------------------------------------------------------

-- The atomic unit of intelligence
CREATE TABLE IF NOT EXISTS `sentrais_backbone.sentrasignals` (
  -- Identity
  signal_id STRING NOT NULL,
  signal_timestamp TIMESTAMP NOT NULL,
  ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  source_system STRING NOT NULL,  -- EVERGAME, CiviGrid, eVenu, NFL_IT, Manual, API
  vertical_id STRING NOT NULL,
  engagement_id STRING NOT NULL,
  client_id STRING NOT NULL,
  
  -- Situation
  signal_type STRING NOT NULL,  -- observation, anomaly, threshold_breach, decision, outcome, trend, prediction
  category STRING NOT NULL,  -- crowd, weather, security, infrastructure, medical, resource, personnel
  subcategory STRING,
  severity INT64,  -- 1-5 (1=info, 5=critical)
  confidence FLOAT64,  -- 0.0-1.0
  description STRING,
  
  -- Location
  location_geo GEOGRAPHY,  -- Native BigQuery geography type
  location_lat FLOAT64,
  location_lng FLOAT64,
  location_semantic STRING,  -- Human-readable location
  location_zone STRING,  -- Zone/sector identifier
  
  -- Operational Context
  operational_phase STRING,
  event_id STRING,  -- Links to specific event if applicable
  incident_id STRING,  -- Links to incident if applicable
  
  -- Conditions at time of signal
  conditions JSON,
  
  -- Entities involved
  entities JSON,  -- Array of {type, id, name, role, count}
  
  -- Related signals
  related_signal_ids ARRAY<STRING>,
  parent_signal_id STRING,  -- For signal chains
  
  -- Decision (if signal_type = 'decision' or requires decision)
  decision_made STRING,
  decision_maker_role STRING,
  decision_maker_id STRING,
  options_considered ARRAY<STRING>,
  decision_rationale STRING,
  expected_outcome STRING,
  
  -- Outcome (populated after the fact)
  actual_outcome STRING,
  outcome_delta STRING,  -- Difference from expected
  cascading_effects ARRAY<STRING>,
  time_to_resolution_minutes INT64,
  effectiveness_score INT64,  -- 1-5
  
  -- NIN Classification
  nin_phase STRING,
  playbook_id STRING,  -- If this maps to a known playbook
  pattern_tags ARRAY<STRING>,
  cross_vertical_relevance ARRAY<STRING>,
  lesson_extracted BOOL DEFAULT FALSE,
  
  -- Data governance
  is_anonymized BOOL DEFAULT FALSE,
  pii_present BOOL DEFAULT FALSE,
  classification_level STRING DEFAULT 'internal',  -- public, internal, confidential, restricted
  
  -- Raw data preservation
  raw_payload JSON,
  
  -- Partitioning and clustering support
  signal_date DATE,  -- For partitioning
  
  -- Audit
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING
)
PARTITION BY signal_date
CLUSTER BY client_id, vertical_id, category
OPTIONS (
  description = 'Core SentraSignal table - atomic unit of operational intelligence',
  require_partition_filter = FALSE
);

-- ----------------------------------------------------------------------------
-- SIGNAL RELATIONSHIPS TABLE
-- ----------------------------------------------------------------------------

-- For complex signal relationships beyond parent/child
CREATE TABLE IF NOT EXISTS `sentrais_backbone.signal_relationships` (
  relationship_id STRING NOT NULL,
  source_signal_id STRING NOT NULL,
  target_signal_id STRING NOT NULL,
  relationship_type STRING NOT NULL,  -- 'caused_by', 'resulted_in', 'correlated_with', 'supersedes', 'part_of'
  confidence FLOAT64,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  created_by STRING
)
OPTIONS (
  description = 'Relationships between SentraSignals for causal analysis'
);

-- ----------------------------------------------------------------------------
-- EVENTS TABLE (Scheduled events: games, concerts, etc.)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.events` (
  event_id STRING NOT NULL,
  engagement_id STRING NOT NULL,
  client_id STRING NOT NULL,
  vertical_id STRING NOT NULL,
  
  event_name STRING NOT NULL,
  event_type STRING,  -- 'nfl_regular_season', 'nfl_playoffs', 'super_bowl', 'concert', 'festival', 'conference'
  event_subtype STRING,
  
  venue_id STRING,
  venue_name STRING,
  venue_capacity INT64,
  
  scheduled_start TIMESTAMP,
  scheduled_end TIMESTAMP,
  actual_start TIMESTAMP,
  actual_end TIMESTAMP,
  
  expected_attendance INT64,
  actual_attendance INT64,
  
  weather_conditions JSON,
  
  -- Event-specific metadata
  metadata JSON,
  
  -- Broadcast/media
  is_broadcast BOOL DEFAULT FALSE,
  broadcast_networks ARRAY<STRING>,
  
  -- Status
  status STRING DEFAULT 'scheduled',  -- scheduled, active, completed, cancelled, postponed
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
PARTITION BY DATE(scheduled_start)
CLUSTER BY client_id, vertical_id, event_type
OPTIONS (
  description = 'Scheduled events tracked by Sentrais'
);

-- ----------------------------------------------------------------------------
-- INCIDENTS TABLE (Unscheduled incidents requiring response)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.incidents` (
  incident_id STRING NOT NULL,
  engagement_id STRING,
  client_id STRING,
  vertical_id STRING NOT NULL,
  event_id STRING,  -- If incident occurs during an event
  
  incident_name STRING,
  incident_type STRING NOT NULL,  -- 'weather', 'security', 'medical', 'infrastructure', 'crowd', 'cyber'
  incident_subtype STRING,
  
  severity INT64,  -- 1-5
  
  -- Location
  location_geo GEOGRAPHY,
  location_semantic STRING,
  affected_area_radius_meters FLOAT64,
  
  -- Timeline
  detected_at TIMESTAMP NOT NULL,
  acknowledged_at TIMESTAMP,
  response_started_at TIMESTAMP,
  contained_at TIMESTAMP,
  resolved_at TIMESTAMP,
  closed_at TIMESTAMP,
  
  -- ICS Structure (for emergency management)
  ics_type INT64,  -- ICS incident type 1-5
  unified_command BOOL DEFAULT FALSE,
  incident_commander_role STRING,
  
  -- Impact
  people_affected INT64,
  assets_affected ARRAY<STRING>,
  estimated_impact_dollars FLOAT64,
  
  -- Response
  resources_deployed JSON,
  mutual_aid_activated BOOL DEFAULT FALSE,
  mutual_aid_agreements ARRAY<STRING>,
  
  -- Root cause
  root_cause STRING,
  contributing_factors ARRAY<STRING>,
  
  -- After action
  lessons_learned ARRAY<STRING>,
  improvement_actions ARRAY<STRING>,
  
  status STRING DEFAULT 'active',  -- active, contained, resolved, closed
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
PARTITION BY DATE(detected_at)
CLUSTER BY vertical_id, incident_type, severity
OPTIONS (
  description = 'Incidents requiring operational response'
);

-- ----------------------------------------------------------------------------
-- VIEWS FOR COMMON QUERIES
-- ----------------------------------------------------------------------------

-- Active signals in the last 24 hours by vertical
CREATE OR REPLACE VIEW `sentrais_backbone.v_recent_signals_by_vertical` AS
SELECT 
  vertical_id,
  category,
  signal_type,
  severity,
  COUNT(*) as signal_count,
  AVG(confidence) as avg_confidence
FROM `sentrais_backbone.sentrasignals`
WHERE signal_timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY vertical_id, category, signal_type, severity
ORDER BY vertical_id, signal_count DESC;

-- Decision effectiveness by client
CREATE OR REPLACE VIEW `sentrais_backbone.v_decision_effectiveness` AS
SELECT 
  client_id,
  engagement_id,
  COUNT(*) as total_decisions,
  AVG(effectiveness_score) as avg_effectiveness,
  COUNTIF(effectiveness_score >= 4) as successful_decisions,
  COUNTIF(effectiveness_score <= 2) as unsuccessful_decisions
FROM `sentrais_backbone.sentrasignals`
WHERE signal_type = 'decision' AND effectiveness_score IS NOT NULL
GROUP BY client_id, engagement_id;

-- Cross-vertical pattern frequency
CREATE OR REPLACE VIEW `sentrais_analytics.v_cross_vertical_patterns` AS
SELECT 
  pattern_tag,
  ARRAY_AGG(DISTINCT vertical_id) as verticals_observed,
  COUNT(*) as occurrence_count,
  AVG(effectiveness_score) as avg_effectiveness
FROM `sentrais_backbone.sentrasignals`,
UNNEST(pattern_tags) as pattern_tag
WHERE pattern_tags IS NOT NULL
GROUP BY pattern_tag
HAVING ARRAY_LENGTH(ARRAY_AGG(DISTINCT vertical_id)) > 1
ORDER BY occurrence_count DESC;
