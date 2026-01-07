-- ============================================================================
-- SENTRAIS INTELLIGENCE BACKBONE - NIN PLAYBOOK SCHEMA
-- Google BigQuery DDL
-- Version: 1.0.0
-- Description: NIN Master Playbook and Cross-Vertical Learning Tables
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PLAYBOOK CATEGORIES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.playbook_categories` (
  category_id STRING NOT NULL,
  category_name STRING NOT NULL,
  category_description STRING,
  parent_category_id STRING,  -- For hierarchical categories
  is_universal BOOL DEFAULT FALSE,  -- Cross-vertical applicable
  verticals_applicable ARRAY<STRING>,  -- If not universal, which verticals
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
OPTIONS (
  description = 'Playbook category taxonomy'
);

-- Initial categories
INSERT INTO `sentrais_backbone.playbook_categories` (category_id, category_name, category_description, parent_category_id, is_universal, verticals_applicable)
VALUES
  -- Universal Patterns
  ('universal', 'Universal Patterns', 'Cross-vertical operational patterns', NULL, TRUE, NULL),
  ('crowd_dynamics', 'Crowd Dynamics', 'Crowd flow, density, and behavior management', 'universal', TRUE, NULL),
  ('communication_cascades', 'Communication Cascades', 'Multi-stakeholder notification and messaging', 'universal', TRUE, NULL),
  ('resource_staging', 'Resource Staging', 'Pre-positioning and dynamic allocation', 'universal', TRUE, NULL),
  ('weather_response', 'Weather Response', 'Meteorological event response patterns', 'universal', TRUE, NULL),
  ('cascading_failure', 'Cascading Failure Prevention', 'Single point of failure and graceful degradation', 'universal', TRUE, NULL),
  ('decision_making', 'Decision Making Under Uncertainty', 'Frameworks for incomplete information scenarios', 'universal', TRUE, NULL),
  
  -- Sports & Entertainment
  ('sports', 'Sports & Entertainment', 'Sports and entertainment-specific playbooks', NULL, FALSE, ARRAY['sports_entertainment']),
  ('game_day', 'Game Day Operations', 'Standard game day procedures', 'sports', FALSE, ARRAY['sports_entertainment']),
  ('broadcast', 'Broadcast Coordination', 'Media and broadcast-related procedures', 'sports', FALSE, ARRAY['sports_entertainment', 'mega_events']),
  
  -- Aviation
  ('aviation', 'Aviation & Transportation', 'Aviation-specific playbooks', NULL, FALSE, ARRAY['aviation_transportation']),
  ('checkpoint', 'Checkpoint Operations', 'TSA and security screening procedures', 'aviation', FALSE, ARRAY['aviation_transportation']),
  ('ground_ops', 'Ground Operations', 'Ground stop and delay management', 'aviation', FALSE, ARRAY['aviation_transportation']),
  
  -- Emergency Management
  ('emergency', 'Emergency Management', 'Emergency management playbooks', NULL, FALSE, ARRAY['federal_government', 'critical_infrastructure']),
  ('ics', 'ICS Integration', 'Incident Command System patterns', 'emergency', FALSE, ARRAY['federal_government', 'critical_infrastructure']),
  ('mass_care', 'Mass Care', 'Shelter and feeding operations', 'emergency', FALSE, ARRAY['federal_government']),
  
  -- Mega Events
  ('mega', 'Mega-Events', 'Large-scale international event playbooks', NULL, FALSE, ARRAY['mega_events']),
  ('multi_jurisdiction', 'Multi-Jurisdiction Coordination', 'Cross-jurisdictional operations', 'mega', FALSE, ARRAY['mega_events', 'federal_government']),
  ('international', 'International Protocol', 'Diplomatic and international considerations', 'mega', FALSE, ARRAY['mega_events']);

-- ----------------------------------------------------------------------------
-- NIN PLAYBOOKS (The Institutional Wisdom)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.playbooks` (
  playbook_id STRING NOT NULL,
  playbook_code STRING NOT NULL,  -- Human-readable code: WEATHER-INGRESS-001
  playbook_name STRING NOT NULL,
  playbook_description STRING,
  
  -- Classification
  category_id STRING NOT NULL,
  is_universal BOOL DEFAULT FALSE,
  verticals_applicable ARRAY<STRING>,
  
  -- Status
  status STRING DEFAULT 'draft',  -- draft, review, approved, deprecated
  version STRING DEFAULT '1.0',
  effective_date DATE,
  review_date DATE,
  
  -- Trigger Conditions (when does this playbook activate?)
  trigger_conditions JSON,
  /*
  Example trigger_conditions:
  {
    "conditions": [
      {"field": "weather.precipitation_eta_minutes", "operator": "<", "value": 60},
      {"field": "crowd.external_crowd_pct", "operator": ">", "value": 0.15},
      {"field": "operational_phase", "operator": "in", "value": ["pre_event", "ingress"]}
    ],
    "logic": "AND"
  }
  */
  
  -- Response Actions (what to do)
  response_actions JSON,
  /*
  Example response_actions:
  {
    "actions": [
      {"order": 1, "action": "Activate early door opening", "detail": "T-30 to T-15 earlier than scheduled", "owner": "Operations Chief"},
      {"order": 2, "action": "Open all available entry points", "owner": "Gate Supervisor"},
      {"order": 3, "action": "Activate covered holding areas", "owner": "Guest Services Lead"}
    ]
  }
  */
  
  -- Decision Authority
  decision_authority JSON,
  /*
  {
    "primary": "Operations Chief",
    "alternate": "Venue GM",
    "notification_required": ["Security Director", "Guest Services Lead"],
    "escalation_threshold": "If conditions worsen, escalate to Unified Command"
  }
  */
  
  -- Success Metrics
  success_metrics JSON,
  /*
  {
    "metrics": [
      {"metric": "External crowd reduction", "target": "<10% capacity before precipitation", "measurement": "Gate counts"},
      {"metric": "Weather-related injuries", "target": "Zero", "measurement": "Medical reports"},
      {"metric": "Guest satisfaction", "target": "No spike in complaints", "measurement": "Guest services log"}
    ]
  }
  */
  
  -- Evidence Base
  evidence_instances INT64 DEFAULT 0,  -- How many times has this been applied
  evidence_success_rate FLOAT64,  -- What % of applications were successful
  notable_applications ARRAY<STRING>,  -- Signal IDs of notable uses
  last_applied_at TIMESTAMP,
  
  -- Cross-Vertical Learning
  derived_from_verticals ARRAY<STRING>,  -- Which verticals contributed to this playbook
  cross_vertical_adaptations JSON,  -- How to adapt for other verticals
  
  -- Related Playbooks
  related_playbooks ARRAY<STRING>,  -- Playbook IDs
  prerequisite_playbooks ARRAY<STRING>,
  supersedes_playbooks ARRAY<STRING>,
  
  -- Documentation
  full_documentation_url STRING,
  training_materials_url STRING,
  
  -- Ownership
  owner_role STRING,
  owner_name STRING,
  contributors ARRAY<STRING>,
  
  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  approved_by STRING,
  approved_at TIMESTAMP
)
OPTIONS (
  description = 'NIN Master Playbook repository'
);

-- ----------------------------------------------------------------------------
-- PLAYBOOK APPLICATIONS (Track every time a playbook is used)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.playbook_applications` (
  application_id STRING NOT NULL,
  playbook_id STRING NOT NULL,
  signal_id STRING NOT NULL,  -- The signal that triggered this playbook
  engagement_id STRING NOT NULL,
  client_id STRING NOT NULL,
  vertical_id STRING NOT NULL,
  
  -- Application Context
  applied_at TIMESTAMP NOT NULL,
  applied_by STRING,  -- Role or system
  
  -- Trigger Match
  trigger_match_score FLOAT64,  -- How well did conditions match (0-1)
  trigger_conditions_met JSON,  -- Which specific conditions were met
  
  -- Execution
  actions_taken JSON,  -- Which actions from the playbook were actually executed
  actions_skipped JSON,  -- Which were skipped and why
  adaptations_made JSON,  -- Any modifications to standard playbook
  
  -- Outcome
  outcome_signal_id STRING,  -- Link to outcome signal
  effectiveness_score INT64,  -- 1-5
  success_metrics_achieved JSON,  -- How each metric performed
  
  -- Learnings
  deviations_from_playbook STRING,  -- What was different
  improvement_suggestions ARRAY<STRING>,
  should_update_playbook BOOL DEFAULT FALSE,
  
  -- Cross-Vertical
  novel_pattern_detected BOOL DEFAULT FALSE,
  pattern_description STRING,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(applied_at)
CLUSTER BY playbook_id, vertical_id, client_id
OPTIONS (
  description = 'Track every application of a playbook'
);

-- ----------------------------------------------------------------------------
-- ABSTRACT PATTERNS (Cross-Vertical Learning Engine)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_analytics.abstract_patterns` (
  pattern_id STRING NOT NULL,
  pattern_name STRING NOT NULL,
  pattern_description STRING,
  
  -- Pattern Definition
  pattern_type STRING,  -- 'crowd_movement', 'resource_allocation', 'communication', 'escalation', 'recovery'
  
  -- Abstract Definition (domain-agnostic)
  abstract_definition JSON,
  /*
  {
    "core_challenge": "Large population movement under time pressure",
    "key_variables": ["population_size", "time_constraint", "capacity", "flow_rate"],
    "success_factors": ["early_warning", "multiple_pathways", "communication"],
    "failure_modes": ["bottleneck", "panic", "misinformation"]
  }
  */
  
  -- Domain-Specific Manifestations
  manifestations JSON,
  /*
  {
    "sports_entertainment": {
      "example": "Stadium crowd surge at gates during delayed opening",
      "specific_variables": {"population": "ticket_holders", "pathways": "gates", "capacity": "venue_capacity"}
    },
    "emergency_management": {
      "example": "Hurricane evacuation route surge",
      "specific_variables": {"population": "evacuees", "pathways": "evacuation_routes", "capacity": "road_capacity"}
    },
    "aviation": {
      "example": "Terminal evacuation after security incident",
      "specific_variables": {"population": "passengers", "pathways": "exits", "capacity": "terminal_capacity"}
    }
  }
  */
  
  -- Evidence
  occurrences_count INT64 DEFAULT 0,
  verticals_observed ARRAY<STRING>,
  example_signal_ids ARRAY<STRING>,
  
  -- Related Playbooks
  related_playbooks ARRAY<STRING>,
  
  -- Machine Learning
  ml_model_id STRING,  -- If there's a trained model for this pattern
  detection_confidence_threshold FLOAT64,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
OPTIONS (
  description = 'Abstract operational patterns for cross-vertical learning'
);

-- ----------------------------------------------------------------------------
-- PATTERN MATCHES (When a signal matches an abstract pattern)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_analytics.pattern_matches` (
  match_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  pattern_id STRING NOT NULL,
  
  -- Match Quality
  match_confidence FLOAT64,  -- 0-1
  match_method STRING,  -- 'rule_based', 'ml_classification', 'human_tagged'
  
  -- Context
  vertical_id STRING,
  engagement_id STRING,
  
  -- Cross-Vertical Insights
  similar_signals_other_verticals ARRAY<STRING>,  -- Signal IDs from other verticals with same pattern
  suggested_playbooks ARRAY<STRING>,  -- Playbooks from other verticals that might apply
  
  -- Learning
  novel_variation BOOL DEFAULT FALSE,  -- Is this a new variation of the pattern?
  variation_description STRING,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY pattern_id, vertical_id
OPTIONS (
  description = 'Matches between signals and abstract patterns'
);

-- ----------------------------------------------------------------------------
-- LESSONS LEARNED
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.lessons_learned` (
  lesson_id STRING NOT NULL,
  
  -- Source
  source_signal_ids ARRAY<STRING>,  -- Signals that generated this lesson
  source_engagement_id STRING,
  source_client_id STRING,
  source_vertical_id STRING,
  source_incident_id STRING,
  source_event_id STRING,
  
  -- Lesson Content
  lesson_title STRING NOT NULL,
  lesson_description STRING NOT NULL,
  lesson_type STRING,  -- 'success', 'failure', 'improvement', 'warning', 'best_practice'
  
  -- Impact
  impact_level STRING,  -- 'low', 'medium', 'high', 'critical'
  lives_affected INT64,
  financial_impact FLOAT64,
  
  -- Root Cause (for failures/improvements)
  root_cause STRING,
  contributing_factors ARRAY<STRING>,
  
  -- Recommendations
  recommendations ARRAY<STRING>,
  immediate_actions ARRAY<STRING>,
  long_term_actions ARRAY<STRING>,
  
  -- Implementation
  implemented BOOL DEFAULT FALSE,
  implemented_in_playbooks ARRAY<STRING>,  -- Playbook IDs updated
  implementation_date DATE,
  
  -- Cross-Vertical
  applicable_to_verticals ARRAY<STRING>,
  pattern_ids ARRAY<STRING>,  -- Abstract patterns this lesson relates to
  
  -- Status
  status STRING DEFAULT 'pending',  -- pending, reviewed, approved, implemented, archived
  
  -- Ownership
  submitted_by STRING,
  reviewed_by STRING,
  approved_by STRING,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
PARTITION BY DATE(created_at)
CLUSTER BY source_vertical_id, lesson_type
OPTIONS (
  description = 'Lessons learned from operational signals and incidents'
);

-- ----------------------------------------------------------------------------
-- BENCHMARKS (What "good" looks like)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_analytics.benchmarks` (
  benchmark_id STRING NOT NULL,
  benchmark_name STRING NOT NULL,
  benchmark_description STRING,
  
  -- Scope
  vertical_id STRING,  -- NULL for universal benchmarks
  category STRING,
  metric_name STRING NOT NULL,
  
  -- Benchmark Values
  benchmark_value FLOAT64 NOT NULL,
  benchmark_unit STRING,
  percentile INT64,  -- Which percentile does this represent (e.g., 50 = median, 90 = top performers)
  
  -- Context Requirements
  applicable_conditions JSON,
  /*
  {
    "event_type": ["nfl_regular_season", "nfl_playoffs"],
    "venue_capacity_min": 50000,
    "weather": "any"
  }
  */
  
  -- Evidence
  sample_size INT64,  -- How many data points
  data_source STRING,
  calculation_method STRING,
  confidence_interval_low FLOAT64,
  confidence_interval_high FLOAT64,
  
  -- Validity
  effective_date DATE,
  expiration_date DATE,
  last_calculated_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP
)
OPTIONS (
  description = 'Operational benchmarks by vertical and category'
);

-- Example benchmarks
INSERT INTO `sentrais_analytics.benchmarks` (benchmark_id, benchmark_name, benchmark_description, vertical_id, category, metric_name, benchmark_value, benchmark_unit, percentile, sample_size)
VALUES
  ('BM-001', 'NFL Ingress Rate', 'Gate throughput rate for NFL venues', 'sports_entertainment', 'crowd_ingress', 'guests_per_hour_per_lane', 850, 'guests/hour', 50, 156),
  ('BM-002', 'NFL Top Performer Ingress', 'Top performing venue gate throughput', 'sports_entertainment', 'crowd_ingress', 'guests_per_hour_per_lane', 1100, 'guests/hour', 90, 156),
  ('BM-003', 'TSA Standard Wait', 'TSA checkpoint wait time standard', 'aviation_transportation', 'checkpoint', 'wait_time_minutes', 15, 'minutes', 50, 2400),
  ('BM-004', 'Incident Acknowledgment', 'Time to acknowledge critical incident', NULL, 'incident_response', 'acknowledgment_time_minutes', 5, 'minutes', 50, 89),
  ('BM-005', 'Weather Response Time', 'Time from weather alert to response initiation', NULL, 'weather_response', 'response_initiation_minutes', 8, 'minutes', 75, 234);

-- ----------------------------------------------------------------------------
-- VIEWS FOR PLAYBOOK ANALYTICS
-- ----------------------------------------------------------------------------

-- Playbook effectiveness by vertical
CREATE OR REPLACE VIEW `sentrais_analytics.v_playbook_effectiveness` AS
SELECT 
  p.playbook_id,
  p.playbook_code,
  p.playbook_name,
  p.category_id,
  pa.vertical_id,
  COUNT(*) as applications,
  AVG(pa.effectiveness_score) as avg_effectiveness,
  COUNTIF(pa.effectiveness_score >= 4) as successful_applications,
  COUNTIF(pa.improvement_suggestions IS NOT NULL) as applications_with_suggestions
FROM `sentrais_backbone.playbooks` p
JOIN `sentrais_backbone.playbook_applications` pa ON p.playbook_id = pa.playbook_id
GROUP BY p.playbook_id, p.playbook_code, p.playbook_name, p.category_id, pa.vertical_id;

-- Cross-vertical pattern insights
CREATE OR REPLACE VIEW `sentrais_analytics.v_cross_vertical_insights` AS
SELECT 
  ap.pattern_name,
  ap.pattern_type,
  ARRAY_LENGTH(ap.verticals_observed) as verticals_count,
  ap.verticals_observed,
  ap.occurrences_count,
  ARRAY_LENGTH(ap.related_playbooks) as playbook_count
FROM `sentrais_analytics.abstract_patterns` ap
WHERE ARRAY_LENGTH(ap.verticals_observed) > 1
ORDER BY ap.occurrences_count DESC;

-- Recent lessons requiring review
CREATE OR REPLACE VIEW `sentrais_backbone.v_lessons_pending_review` AS
SELECT 
  lesson_id,
  lesson_title,
  lesson_type,
  impact_level,
  source_vertical_id,
  submitted_by,
  created_at
FROM `sentrais_backbone.lessons_learned`
WHERE status = 'pending'
ORDER BY 
  CASE impact_level 
    WHEN 'critical' THEN 1 
    WHEN 'high' THEN 2 
    WHEN 'medium' THEN 3 
    ELSE 4 
  END,
  created_at ASC;
