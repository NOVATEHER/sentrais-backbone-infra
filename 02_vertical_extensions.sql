-- ============================================================================
-- SENTRAIS INTELLIGENCE BACKBONE - VERTICAL EXTENSIONS
-- Google BigQuery DDL
-- Version: 1.0.0
-- Description: Vertical-specific extension tables for domain intelligence
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SPORTS & ENTERTAINMENT EXTENSION
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_sports_entertainment` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,  -- Links to sentrasignals
  
  -- Event Context
  event_type STRING,  -- 'nfl_regular_season', 'nfl_playoffs', 'super_bowl', 'nba', 'mlb', 'mls', 'college'
  league STRING,
  season STRING,
  week_number INT64,
  
  -- Game State
  game_state STRING,  -- 'pre_game', 'Q1', 'Q2', 'halftime', 'Q3', 'Q4', 'overtime', 'post_game'
  game_clock STRING,
  home_team STRING,
  away_team STRING,
  current_score_home INT64,
  current_score_away INT64,
  
  -- Venue Operations
  venue_capacity INT64,
  current_attendance INT64,
  attendance_percentage FLOAT64,
  gates_open_time TIMESTAMP,
  gates_closed_time TIMESTAMP,
  
  -- Fan Experience
  fan_satisfaction_score FLOAT64,
  concession_wait_avg_minutes FLOAT64,
  restroom_wait_avg_minutes FLOAT64,
  
  -- Broadcast Implications
  broadcast_active BOOL,
  broadcast_networks ARRAY<STRING>,
  national_broadcast BOOL,
  broadcast_delay_minutes FLOAT64,
  
  -- VIP Considerations
  vip_attendance BOOL,
  vip_designations ARRAY<STRING>,  -- 'owner', 'commissioner', 'celebrity', 'political'
  
  -- Tailgate/External
  tailgate_active BOOL,
  tailgate_crowd_estimate INT64,
  parking_lot_capacity_pct FLOAT64,
  
  -- Weather Impact on Operations
  weather_delay BOOL,
  lightning_delay_minutes INT64,
  roof_status STRING,  -- 'open', 'closed', 'partial', 'n/a'
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, event_type, league
OPTIONS (
  description = 'Sports & Entertainment vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- LIVE EVENTS EXTENSION (Concerts, Festivals, etc.)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_live_events` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Event Details
  event_type STRING,  -- 'concert', 'festival', 'tour_stop', 'corporate_event', 'conference'
  event_genre STRING,  -- 'rock', 'pop', 'edm', 'country', 'hip_hop', 'classical'
  artist_headliner STRING,
  tour_name STRING,
  
  -- Multi-Stage/Area
  is_multi_stage BOOL,
  active_stages ARRAY<STRING>,
  stage_capacities JSON,
  
  -- Festival Specific
  festival_day INT64,  -- Day 1, 2, 3 of multi-day festival
  camping_active BOOL,
  camping_population INT64,
  
  -- Production
  production_status STRING,  -- 'load_in', 'sound_check', 'doors', 'opening_act', 'headliner', 'load_out'
  stage_changeover_active BOOL,
  pyrotechnics_planned BOOL,
  
  -- VIP/Premium
  vip_sections_active ARRAY<STRING>,
  vip_attendance INT64,
  premium_experience_issues ARRAY<STRING>,
  
  -- Crowd Dynamics
  mosh_pit_active BOOL,
  crowd_surf_incidents INT64,
  barrier_pressure_level INT64,  -- 1-5
  
  -- Age Demographics
  all_ages BOOL,
  age_restriction INT64,
  id_check_required BOOL,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, event_type
OPTIONS (
  description = 'Live Events vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- AVIATION & TRANSPORTATION EXTENSION
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_aviation_transportation` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Facility Info
  facility_type STRING,  -- 'airport', 'transit_hub', 'seaport', 'rail_station', 'bus_terminal'
  facility_code STRING,  -- 'ATL', 'JFK', etc.
  terminal STRING,
  concourse STRING,
  
  -- TSA/Checkpoint Operations
  checkpoint_id STRING,
  checkpoint_type STRING,  -- 'standard', 'precheck', 'clear', 'crew'
  lanes_open INT64,
  lanes_total INT64,
  current_wait_minutes INT64,
  projected_wait_minutes INT64,
  throughput_per_hour INT64,
  
  -- Passenger Volume
  passenger_count INT64,
  passenger_forecast INT64,
  load_factor FLOAT64,
  
  -- Flight Operations
  flights_on_time INT64,
  flights_delayed INT64,
  flights_cancelled INT64,
  ground_stop_active BOOL,
  ground_delay_program_active BOOL,
  gdp_average_delay_minutes INT64,
  
  -- Specific Flight Impact
  impacted_flights ARRAY<STRING>,  -- Flight numbers
  
  -- Security
  tsa_threat_level STRING,  -- 'low', 'elevated', 'high', 'severe'
  security_incident_active BOOL,
  terminal_evacuation BOOL,
  
  -- Baggage Operations
  baggage_claim_id STRING,
  bags_processed INT64,
  mishandled_bags INT64,
  
  -- Ground Transportation
  taxi_queue_length INT64,
  rideshare_wait_minutes INT64,
  parking_capacity_pct FLOAT64,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, facility_type, facility_code
OPTIONS (
  description = 'Aviation & Transportation vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- FEDERAL/EMERGENCY MANAGEMENT EXTENSION
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_federal_emergency` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Incident Classification
  incident_type STRING,  -- 'hurricane', 'wildfire', 'earthquake', 'flood', 'tornado', 'cyber', 'cbrn', 'civil_unrest', 'mass_casualty'
  incident_subtype STRING,
  
  -- FEMA Structure
  fema_region INT64,  -- 1-10
  declaration_type STRING,  -- 'none', 'emergency', 'major_disaster'
  declaration_number STRING,  -- DR-XXXX
  
  -- ICS Structure
  ics_incident_type INT64,  -- 1-5
  unified_command BOOL,
  incident_commander STRING,
  operations_section_chief STRING,
  planning_section_chief STRING,
  logistics_section_chief STRING,
  finance_section_chief STRING,
  
  -- Branches Activated
  branches_activated ARRAY<STRING>,
  divisions_activated ARRAY<STRING>,
  groups_activated ARRAY<STRING>,
  
  -- Federal Coordination
  federal_agencies_involved ARRAY<STRING>,  -- 'FEMA', 'DHS', 'CISA', 'FBI', 'ATF', 'SECRET_SERVICE', 'COAST_GUARD', 'DOD'
  nrf_esf_activated ARRAY<STRING>,  -- Emergency Support Functions 1-15
  
  -- State/Local Coordination
  state_eoc_activated BOOL,
  county_eoc_activated BOOL,
  city_eoc_activated BOOL,
  
  -- Mutual Aid
  emac_activated BOOL,  -- Emergency Management Assistance Compact
  emac_request_number STRING,
  mutual_aid_states ARRAY<STRING>,
  
  -- Critical Infrastructure
  ci_sectors_affected ARRAY<STRING>,  -- 'energy', 'water', 'communications', 'transportation', 'healthcare', 'financial'
  lifeline_status JSON,  -- Status of each FEMA community lifeline
  
  -- Resource Management
  resource_requests_pending INT64,
  resource_requests_filled INT64,
  mission_assignments_issued INT64,
  
  -- Mass Care
  shelters_open INT64,
  shelter_population INT64,
  feeding_operations_active BOOL,
  meals_served INT64,
  
  -- Search and Rescue
  usar_teams_deployed INT64,
  search_grid_pct_complete FLOAT64,
  rescues_completed INT64,
  
  -- Public Information
  pio_active BOOL,
  jic_activated BOOL,  -- Joint Information Center
  press_conferences_held INT64,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, incident_type, fema_region
OPTIONS (
  description = 'Federal/Emergency Management vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- MEGA-EVENTS EXTENSION (FIFA, Olympics, etc.)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_mega_events` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Event Classification
  mega_event_type STRING,  -- 'fifa_world_cup', 'olympics_summer', 'olympics_winter', 'super_bowl', 'world_series', 'ncaa_final_four'
  event_year INT64,
  
  -- Host Information
  host_country STRING,
  host_city STRING,
  host_venue STRING,
  
  -- Match/Competition Details
  match_id STRING,
  competition_phase STRING,  -- 'group_stage', 'round_of_16', 'quarter_final', 'semi_final', 'final'
  teams_involved ARRAY<STRING>,
  countries_involved ARRAY<STRING>,
  
  -- LOC Coordination
  loc_liaison_active BOOL,
  fifa_liaison_active BOOL,
  ioc_liaison_active BOOL,
  
  -- City/Government Coordination
  city_eoc_status STRING,  -- 'monitoring', 'partial_activation', 'full_activation'
  state_coordination_active BOOL,
  federal_coordination ARRAY<STRING>,  -- 'secret_service', 'fbi', 'dhs', 'state_department'
  
  -- International Considerations
  embassy_notifications_sent BOOL,
  embassies_notified ARRAY<STRING>,
  diplomatic_security_active BOOL,
  head_of_state_attendance BOOL,
  heads_of_state ARRAY<STRING>,
  
  -- Media/Broadcast
  media_credentialed INT64,
  broadcast_countries INT64,
  global_viewership_estimate INT64,
  media_center_active BOOL,
  
  -- Fan Experience
  fan_fest_active BOOL,
  fan_fest_attendance INT64,
  official_viewing_parties ARRAY<STRING>,
  
  -- Transportation
  event_day_road_closures BOOL,
  public_transit_enhanced BOOL,
  park_and_ride_active BOOL,
  special_event_zone_active BOOL,
  
  -- Security Posture
  nsse_designation BOOL,  -- National Special Security Event
  security_zone_level STRING,
  credentialing_system STRING,
  anti_drone_active BOOL,
  maritime_security_zone BOOL,
  airspace_restrictions ARRAY<STRING>,  -- TFR details
  
  -- Economic Impact Tracking
  hotel_occupancy_pct FLOAT64,
  visitor_spending_estimate FLOAT64,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, mega_event_type, host_city
OPTIONS (
  description = 'Mega-Events vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- CRITICAL INFRASTRUCTURE EXTENSION
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_critical_infrastructure` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Sector Classification
  ci_sector STRING,  -- 16 CI sectors: 'energy', 'water', 'communications', 'healthcare', 'financial', etc.
  subsector STRING,
  
  -- Asset Information
  asset_id STRING,
  asset_name STRING,
  asset_type STRING,
  asset_criticality INT64,  -- 1-5
  
  -- Operational Status
  operational_status STRING,  -- 'normal', 'degraded', 'impaired', 'offline', 'destroyed'
  capacity_pct FLOAT64,
  redundancy_available BOOL,
  backup_systems_active BOOL,
  
  -- Cyber Status
  cyber_status STRING,  -- 'normal', 'elevated', 'under_attack', 'compromised'
  cyber_incident_type STRING,  -- 'ransomware', 'ddos', 'intrusion', 'data_breach'
  
  -- Energy Specific
  generation_capacity_mw FLOAT64,
  current_load_mw FLOAT64,
  grid_frequency_hz FLOAT64,
  renewable_pct FLOAT64,
  
  -- Water Specific
  treatment_capacity_mgd FLOAT64,  -- Million gallons per day
  current_demand_mgd FLOAT64,
  water_quality_status STRING,
  pressure_psi FLOAT64,
  
  -- Communications Specific
  network_type STRING,  -- 'cellular', 'landline', 'internet', 'broadcast', 'firstnet'
  coverage_pct FLOAT64,
  congestion_level FLOAT64,
  
  -- Healthcare Specific
  bed_capacity INT64,
  beds_available INT64,
  icu_capacity INT64,
  icu_available INT64,
  er_wait_minutes INT64,
  surge_capacity_activated BOOL,
  
  -- Dependencies
  upstream_dependencies ARRAY<STRING>,
  downstream_dependencies ARRAY<STRING>,
  cascading_impact_risk INT64,  -- 1-5
  
  -- Restoration
  estimated_restoration_time_hours FLOAT64,
  restoration_priority INT64,
  mutual_aid_requested BOOL,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, ci_sector
OPTIONS (
  description = 'Critical Infrastructure vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- VENUE OPERATIONS EXTENSION (eVenu)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_venue_operations` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Venue Info
  venue_type STRING,  -- 'stadium', 'arena', 'amphitheater', 'convention_center', 'theater', 'club'
  venue_capacity INT64,
  venue_age_years INT64,
  
  -- Gate/Entry Operations
  gates_total INT64,
  gates_open INT64,
  magnetometers_total INT64,
  magnetometers_active INT64,
  entry_throughput_per_hour INT64,
  avg_entry_time_seconds INT64,
  
  -- Zone Status
  zone_id STRING,
  zone_type STRING,  -- 'ga', 'reserved', 'premium', 'suite', 'field', 'backstage'
  zone_capacity INT64,
  zone_current_count INT64,
  zone_density_pct FLOAT64,
  
  -- F&B Operations
  concession_stands_open INT64,
  concession_stands_total INT64,
  mobile_ordering_active BOOL,
  avg_transaction_time_seconds INT64,
  top_selling_items ARRAY<STRING>,
  inventory_alerts ARRAY<STRING>,
  
  -- Parking
  parking_lots_open INT64,
  parking_capacity_total INT64,
  parking_current_count INT64,
  parking_revenue FLOAT64,
  
  -- Suite Operations
  suites_occupied INT64,
  suites_total INT64,
  suite_service_issues ARRAY<STRING>,
  
  -- ADA Compliance
  ada_requests_fulfilled INT64,
  ada_requests_pending INT64,
  wheelchair_available INT64,
  
  -- Facilities
  hvac_status STRING,
  lighting_status STRING,
  sound_system_status STRING,
  video_board_status STRING,
  wifi_status STRING,
  wifi_connected_devices INT64,
  cellular_coverage_status STRING,
  
  -- Cleaning/Environmental
  restroom_cleanliness_score FLOAT64,
  cleaning_crew_deployed INT64,
  environmental_issues ARRAY<STRING>,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, venue_type
OPTIONS (
  description = 'Venue Operations (eVenu) vertical extension for SentraSignals'
);

-- ----------------------------------------------------------------------------
-- CIVIC/GOVERNMENT OPERATIONS EXTENSION (CiviGrid)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sentrais_backbone.ext_civic_government` (
  extension_id STRING NOT NULL,
  signal_id STRING NOT NULL,
  
  -- Government Level
  government_level STRING,  -- 'federal', 'state', 'county', 'city', 'tribal'
  jurisdiction STRING,
  department STRING,
  
  -- Civic Event Type
  civic_event_type STRING,  -- 'parade', 'protest', 'inauguration', 'state_funeral', 'civic_ceremony', 'public_meeting'
  permit_number STRING,
  permit_type STRING,
  
  -- Public Safety
  public_safety_posture STRING,  -- 'normal', 'elevated', 'high', 'emergency'
  law_enforcement_deployed INT64,
  fire_ems_deployed INT64,
  national_guard_activated BOOL,
  national_guard_personnel INT64,
  
  -- Crowd Management
  estimated_crowd INT64,
  crowd_sentiment STRING,  -- 'peaceful', 'tense', 'volatile', 'violent'
  counter_protest_present BOOL,
  separation_barriers_deployed BOOL,
  
  -- Traffic/Roads
  road_closures ARRAY<STRING>,
  detour_routes_active BOOL,
  traffic_control_points INT64,
  
  -- Public Communications
  public_alert_issued BOOL,
  alert_type STRING,  -- 'wireless_emergency_alert', 'eas', 'social_media', 'press_release'
  languages_used ARRAY<STRING>,
  
  -- Constituent Services
  constituent_complaints INT64,
  service_requests INT64,
  311_call_volume INT64,
  
  -- Budget/Resources
  event_budget FLOAT64,
  overtime_costs FLOAT64,
  mutual_aid_costs FLOAT64,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY signal_id, government_level, civic_event_type
OPTIONS (
  description = 'Civic/Government Operations (CiviGrid) vertical extension for SentraSignals'
);
