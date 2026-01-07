"""
Sentrais Intelligence Backbone - Ingestion API Service
=======================================================

FastAPI service for ingesting operational intelligence from client systems.
Designed to run on Google Cloud Run.

Author: Sentrais Engineering
Version: 1.0.0
"""

import os
import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Header, Query, Path, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from google.cloud import bigquery
from google.cloud import pubsub_v1
import hashlib
import json

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "sentrais-backbone")
DATASET_ID = os.getenv("BQ_DATASET_ID", "sentrais_backbone")
PUBSUB_TOPIC = os.getenv("PUBSUB_TOPIC", "sentrasignal-ingestion")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

# ============================================================================
# LIFESPAN & CLIENTS
# ============================================================================

bq_client: Optional[bigquery.Client] = None
pubsub_publisher: Optional[pubsub_v1.PublisherClient] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup clients."""
    global bq_client, pubsub_publisher
    
    # Initialize clients
    bq_client = bigquery.Client(project=PROJECT_ID)
    pubsub_publisher = pubsub_v1.PublisherClient()
    
    yield
    
    # Cleanup
    if bq_client:
        bq_client.close()

# ============================================================================
# FASTAPI APP
# ============================================================================

app = FastAPI(
    title="Sentrais Intelligence Backbone API",
    description="API for ingesting operational intelligence from client systems",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if ENVIRONMENT == "development" else ["https://*.sentrais.io"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# PYDANTIC MODELS
# ============================================================================

class Location(BaseModel):
    lat: Optional[float] = None
    lng: Optional[float] = None
    semantic: Optional[str] = None
    zone: Optional[str] = None

class Entity(BaseModel):
    type: str  # person, crowd, asset, system, organization, vehicle
    id: Optional[str] = None
    name: Optional[str] = None
    role: Optional[str] = None
    count: Optional[int] = None
    status: Optional[str] = None

class Decision(BaseModel):
    decision_made: Optional[str] = None
    decision_maker_role: Optional[str] = None
    decision_maker_id: Optional[str] = None
    options_considered: Optional[List[str]] = None
    rationale: Optional[str] = None
    expected_outcome: Optional[str] = None

class Outcome(BaseModel):
    actual_outcome: Optional[str] = None
    outcome_delta: Optional[str] = None
    cascading_effects: Optional[List[str]] = None
    time_to_resolution_minutes: Optional[int] = None
    effectiveness_score: Optional[int] = Field(None, ge=1, le=5)

class NinClassification(BaseModel):
    nin_phase: Optional[str] = None
    playbook_id: Optional[str] = None
    pattern_tags: Optional[List[str]] = None
    cross_vertical_relevance: Optional[List[str]] = None

class SentraSignalCreate(BaseModel):
    """Schema for creating a new SentraSignal."""
    
    signal_timestamp: Optional[datetime] = None
    source_system: Optional[str] = None
    vertical_id: Optional[str] = None
    engagement_id: Optional[str] = None
    
    signal_type: str = Field(..., description="Type of signal")
    category: str = Field(..., description="Operational category")
    subcategory: Optional[str] = None
    severity: Optional[int] = Field(None, ge=1, le=5)
    confidence: Optional[float] = Field(None, ge=0, le=1)
    description: Optional[str] = None
    
    location: Optional[Location] = None
    operational_phase: Optional[str] = None
    event_id: Optional[str] = None
    incident_id: Optional[str] = None
    
    conditions: Optional[Dict[str, Any]] = None
    entities: Optional[List[Entity]] = None
    related_signal_ids: Optional[List[str]] = None
    
    decision: Optional[Decision] = None
    outcome: Optional[Outcome] = None
    nin_classification: Optional[NinClassification] = None
    
    raw_payload: Optional[Dict[str, Any]] = None
    
    @validator('signal_type')
    def validate_signal_type(cls, v):
        valid_types = ['observation', 'anomaly', 'threshold_breach', 'decision', 
                      'outcome', 'trend', 'prediction', 'escalation', 'resolution']
        if v not in valid_types:
            raise ValueError(f'signal_type must be one of {valid_types}')
        return v
    
    @validator('operational_phase')
    def validate_phase(cls, v):
        if v is None:
            return v
        valid_phases = ['planning', 'pre_event', 'ingress', 'active', 'egress', 
                       'post_event', 'steady_state', 'escalation', 'response', 'recovery']
        if v not in valid_phases:
            raise ValueError(f'operational_phase must be one of {valid_phases}')
        return v

class SentraSignalResponse(SentraSignalCreate):
    """Response schema for SentraSignal."""
    signal_id: str
    client_id: str
    ingestion_timestamp: datetime

class SignalBatchRequest(BaseModel):
    """Batch request for multiple signals."""
    signals: List[SentraSignalCreate] = Field(..., min_items=1, max_items=100)
    engagement_id: Optional[str] = None  # Default for all signals
    event_id: Optional[str] = None  # Default for all signals

class SignalBatchResponse(BaseModel):
    """Response for batch signal submission."""
    created: int
    signal_ids: List[str]
    errors: Optional[List[Dict[str, Any]]] = None

class SignalOutcomeUpdate(BaseModel):
    """Schema for updating signal outcome."""
    outcome: Outcome
    lesson_extracted: Optional[bool] = False

class TokenInfo(BaseModel):
    """Token validation response."""
    client_id: str
    engagement_id: Optional[str]
    permissions: List[str]
    rate_limit_remaining: int
    rate_limit_reset: datetime

class EventCreate(BaseModel):
    """Schema for creating an event."""
    event_name: str
    event_type: Optional[str] = None
    venue_name: Optional[str] = None
    venue_capacity: Optional[int] = None
    scheduled_start: datetime
    scheduled_end: Optional[datetime] = None
    expected_attendance: Optional[int] = None
    metadata: Optional[Dict[str, Any]] = None

class IncidentCreate(BaseModel):
    """Schema for creating an incident."""
    incident_name: Optional[str] = None
    incident_type: str
    severity: int = Field(..., ge=1, le=5)
    location: Optional[Location] = None
    event_id: Optional[str] = None

class PlaybookMatch(BaseModel):
    """Playbook matching request."""
    conditions: Dict[str, Any]
    signal_id: Optional[str] = None
    vertical_id: Optional[str] = None
    include_cross_vertical: bool = True

# ============================================================================
# AUTHENTICATION & AUTHORIZATION
# ============================================================================

async def validate_token(x_sentrais_token: str = Header(...)) -> TokenInfo:
    """
    Validate API token and return client context.
    
    In production, this would:
    1. Hash the token
    2. Look up in api_tokens table
    3. Verify not expired
    4. Check rate limits
    5. Return client context
    """
    if not x_sentrais_token:
        raise HTTPException(status_code=401, detail="Missing API token")
    
    # Hash token for lookup
    token_hash = hashlib.sha256(x_sentrais_token.encode()).hexdigest()
    
    # In production, query BigQuery for token validation
    # For now, simulate with environment-based check
    if ENVIRONMENT == "development":
        # Development mode - accept any token with dev- prefix
        if x_sentrais_token.startswith("dev-"):
            return TokenInfo(
                client_id="dev-client",
                engagement_id="dev-engagement",
                permissions=["read", "write"],
                rate_limit_remaining=1000,
                rate_limit_reset=datetime.now(timezone.utc)
            )
    
    # Production token validation
    query = f"""
        SELECT 
            client_id, 
            engagement_id, 
            permissions, 
            rate_limit_per_minute,
            is_active,
            expires_at
        FROM `{PROJECT_ID}.{DATASET_ID}.api_tokens`
        WHERE token_hash = @token_hash
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("token_hash", "STRING", token_hash)
        ]
    )
    
    try:
        results = bq_client.query(query, job_config=job_config).result()
        row = next(iter(results), None)
        
        if not row:
            raise HTTPException(status_code=401, detail="Invalid API token")
        
        if not row.is_active:
            raise HTTPException(status_code=401, detail="Token has been revoked")
        
        if row.expires_at and row.expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="Token has expired")
        
        return TokenInfo(
            client_id=row.client_id,
            engagement_id=row.engagement_id,
            permissions=list(row.permissions) if row.permissions else ["read"],
            rate_limit_remaining=row.rate_limit_per_minute,  # Simplified
            rate_limit_reset=datetime.now(timezone.utc)
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Token validation error: {str(e)}")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def generate_signal_id() -> str:
    """Generate a unique signal ID."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    unique = uuid.uuid4().hex[:8].upper()
    return f"SS-{timestamp}-{unique}"

async def publish_to_pubsub(topic: str, data: dict):
    """Publish message to Pub/Sub for async processing."""
    topic_path = pubsub_publisher.topic_path(PROJECT_ID, topic)
    message = json.dumps(data).encode("utf-8")
    future = pubsub_publisher.publish(topic_path, message)
    return future.result()

async def insert_signal_to_bigquery(signal: dict, token: TokenInfo):
    """Insert a signal into BigQuery."""
    table_id = f"{PROJECT_ID}.{DATASET_ID}.sentrasignals"
    
    # Prepare row for insertion
    row = {
        "signal_id": signal["signal_id"],
        "signal_timestamp": signal.get("signal_timestamp") or datetime.now(timezone.utc).isoformat(),
        "ingestion_timestamp": datetime.now(timezone.utc).isoformat(),
        "source_system": signal.get("source_system", "API"),
        "vertical_id": signal.get("vertical_id", "unknown"),
        "engagement_id": signal.get("engagement_id") or token.engagement_id,
        "client_id": token.client_id,
        "signal_type": signal["signal_type"],
        "category": signal["category"],
        "subcategory": signal.get("subcategory"),
        "severity": signal.get("severity"),
        "confidence": signal.get("confidence"),
        "description": signal.get("description"),
        "location_lat": signal.get("location", {}).get("lat") if signal.get("location") else None,
        "location_lng": signal.get("location", {}).get("lng") if signal.get("location") else None,
        "location_semantic": signal.get("location", {}).get("semantic") if signal.get("location") else None,
        "location_zone": signal.get("location", {}).get("zone") if signal.get("location") else None,
        "operational_phase": signal.get("operational_phase"),
        "event_id": signal.get("event_id"),
        "incident_id": signal.get("incident_id"),
        "conditions": json.dumps(signal.get("conditions")) if signal.get("conditions") else None,
        "entities": json.dumps(signal.get("entities")) if signal.get("entities") else None,
        "related_signal_ids": signal.get("related_signal_ids"),
        "decision_made": signal.get("decision", {}).get("decision_made") if signal.get("decision") else None,
        "decision_maker_role": signal.get("decision", {}).get("decision_maker_role") if signal.get("decision") else None,
        "decision_rationale": signal.get("decision", {}).get("rationale") if signal.get("decision") else None,
        "expected_outcome": signal.get("decision", {}).get("expected_outcome") if signal.get("decision") else None,
        "nin_phase": signal.get("nin_classification", {}).get("nin_phase") if signal.get("nin_classification") else None,
        "playbook_id": signal.get("nin_classification", {}).get("playbook_id") if signal.get("nin_classification") else None,
        "pattern_tags": signal.get("nin_classification", {}).get("pattern_tags") if signal.get("nin_classification") else None,
        "raw_payload": json.dumps(signal.get("raw_payload")) if signal.get("raw_payload") else None,
        "signal_date": datetime.now(timezone.utc).date().isoformat(),
        "created_by": f"api:{token.client_id}",
    }
    
    errors = bq_client.insert_rows_json(table_id, [row])
    if errors:
        raise Exception(f"BigQuery insert errors: {errors}")
    
    return row

# ============================================================================
# ENDPOINTS - HEALTH
# ============================================================================

@app.get("/health", tags=["Health"])
async def health_check():
    """API health check."""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "version": "1.0.0",
        "environment": ENVIRONMENT
    }

@app.get("/v1/diagnostics/token", tags=["Health"])
async def validate_token_endpoint(token: TokenInfo = Depends(validate_token)):
    """Validate token and return permissions."""
    return token

# ============================================================================
# ENDPOINTS - SIGNALS
# ============================================================================

@app.post("/v1/signals", response_model=SignalBatchResponse, tags=["Signals"])
async def submit_signals(
    request: SignalBatchRequest,
    background_tasks: BackgroundTasks,
    token: TokenInfo = Depends(validate_token)
):
    """Submit one or more SentraSignals."""
    
    if "write" not in token.permissions:
        raise HTTPException(status_code=403, detail="Write permission required")
    
    created_ids = []
    errors = []
    
    for idx, signal in enumerate(request.signals):
        try:
            signal_dict = signal.dict()
            signal_dict["signal_id"] = generate_signal_id()
            
            # Apply defaults from batch request
            if request.engagement_id and not signal_dict.get("engagement_id"):
                signal_dict["engagement_id"] = request.engagement_id
            if request.event_id and not signal_dict.get("event_id"):
                signal_dict["event_id"] = request.event_id
            
            # Insert to BigQuery
            await insert_signal_to_bigquery(signal_dict, token)
            created_ids.append(signal_dict["signal_id"])
            
            # Publish to Pub/Sub for async processing (pattern matching, etc.)
            background_tasks.add_task(
                publish_to_pubsub,
                PUBSUB_TOPIC,
                {
                    "signal_id": signal_dict["signal_id"],
                    "action": "new_signal",
                    "client_id": token.client_id
                }
            )
            
        except Exception as e:
            errors.append({"index": idx, "error": str(e)})
    
    return SignalBatchResponse(
        created=len(created_ids),
        signal_ids=created_ids,
        errors=errors if errors else None
    )

@app.get("/v1/signals", tags=["Signals"])
async def query_signals(
    token: TokenInfo = Depends(validate_token),
    engagement_id: Optional[str] = None,
    signal_type: Optional[str] = None,
    category: Optional[str] = None,
    severity_min: Optional[int] = Query(None, ge=1, le=5),
    severity_max: Optional[int] = Query(None, ge=1, le=5),
    start_time: Optional[datetime] = None,
    end_time: Optional[datetime] = None,
    event_id: Optional[str] = None,
    incident_id: Optional[str] = None,
    limit: int = Query(100, le=1000),
    cursor: Optional[str] = None
):
    """Query signals for the authenticated client."""
    
    # Build query with client isolation
    conditions = [f"client_id = '{token.client_id}'"]
    
    if engagement_id:
        conditions.append(f"engagement_id = '{engagement_id}'")
    if signal_type:
        conditions.append(f"signal_type = '{signal_type}'")
    if category:
        conditions.append(f"category = '{category}'")
    if severity_min:
        conditions.append(f"severity >= {severity_min}")
    if severity_max:
        conditions.append(f"severity <= {severity_max}")
    if start_time:
        conditions.append(f"signal_timestamp >= '{start_time.isoformat()}'")
    if end_time:
        conditions.append(f"signal_timestamp <= '{end_time.isoformat()}'")
    if event_id:
        conditions.append(f"event_id = '{event_id}'")
    if incident_id:
        conditions.append(f"incident_id = '{incident_id}'")
    
    where_clause = " AND ".join(conditions)
    
    query = f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.sentrasignals`
        WHERE {where_clause}
        ORDER BY signal_timestamp DESC
        LIMIT {limit}
    """
    
    try:
        results = bq_client.query(query).result()
        signals = [dict(row) for row in results]
        
        return {
            "signals": signals,
            "total_count": len(signals),
            "cursor": None  # Implement cursor-based pagination
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

@app.get("/v1/signals/{signal_id}", tags=["Signals"])
async def get_signal(
    signal_id: str = Path(...),
    token: TokenInfo = Depends(validate_token)
):
    """Get a specific signal."""
    
    query = f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.sentrasignals`
        WHERE signal_id = @signal_id AND client_id = @client_id
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("signal_id", "STRING", signal_id),
            bigquery.ScalarQueryParameter("client_id", "STRING", token.client_id)
        ]
    )
    
    try:
        results = bq_client.query(query, job_config=job_config).result()
        row = next(iter(results), None)
        
        if not row:
            raise HTTPException(status_code=404, detail="Signal not found")
        
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

@app.patch("/v1/signals/{signal_id}", tags=["Signals"])
async def update_signal_outcome(
    signal_id: str = Path(...),
    update: SignalOutcomeUpdate = ...,
    token: TokenInfo = Depends(validate_token)
):
    """Update a signal with outcome data."""
    
    if "write" not in token.permissions:
        raise HTTPException(status_code=403, detail="Write permission required")
    
    # Build update query
    update_fields = []
    if update.outcome.actual_outcome:
        update_fields.append(f"actual_outcome = '{update.outcome.actual_outcome}'")
    if update.outcome.outcome_delta:
        update_fields.append(f"outcome_delta = '{update.outcome.outcome_delta}'")
    if update.outcome.effectiveness_score:
        update_fields.append(f"effectiveness_score = {update.outcome.effectiveness_score}")
    if update.outcome.time_to_resolution_minutes:
        update_fields.append(f"time_to_resolution_minutes = {update.outcome.time_to_resolution_minutes}")
    if update.lesson_extracted is not None:
        update_fields.append(f"lesson_extracted = {update.lesson_extracted}")
    
    update_fields.append(f"updated_at = CURRENT_TIMESTAMP()")
    update_fields.append(f"updated_by = 'api:{token.client_id}'")
    
    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    # Note: BigQuery doesn't support UPDATE directly in streaming mode
    # In production, use BigQuery's DML or merge statements
    # For now, return the update acknowledgment
    
    return {"status": "updated", "signal_id": signal_id}

# ============================================================================
# ENDPOINTS - EVENTS
# ============================================================================

@app.post("/v1/events", tags=["Events"])
async def create_event(
    event: EventCreate,
    token: TokenInfo = Depends(validate_token)
):
    """Create a new event."""
    
    if "write" not in token.permissions:
        raise HTTPException(status_code=403, detail="Write permission required")
    
    event_id = f"EVT-{uuid.uuid4().hex[:12].upper()}"
    
    row = {
        "event_id": event_id,
        "engagement_id": token.engagement_id,
        "client_id": token.client_id,
        "vertical_id": "unknown",  # Would be derived from engagement
        "event_name": event.event_name,
        "event_type": event.event_type,
        "venue_name": event.venue_name,
        "venue_capacity": event.venue_capacity,
        "scheduled_start": event.scheduled_start.isoformat(),
        "scheduled_end": event.scheduled_end.isoformat() if event.scheduled_end else None,
        "expected_attendance": event.expected_attendance,
        "status": "scheduled",
        "metadata": json.dumps(event.metadata) if event.metadata else None,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    table_id = f"{PROJECT_ID}.{DATASET_ID}.events"
    errors = bq_client.insert_rows_json(table_id, [row])
    
    if errors:
        raise HTTPException(status_code=500, detail=f"Insert error: {errors}")
    
    return {"event_id": event_id, **event.dict()}

@app.get("/v1/events", tags=["Events"])
async def list_events(
    token: TokenInfo = Depends(validate_token),
    status: Optional[str] = None,
    start_after: Optional[datetime] = None,
    start_before: Optional[datetime] = None
):
    """List events for the authenticated client."""
    
    conditions = [f"client_id = '{token.client_id}'"]
    
    if status:
        conditions.append(f"status = '{status}'")
    if start_after:
        conditions.append(f"scheduled_start >= '{start_after.isoformat()}'")
    if start_before:
        conditions.append(f"scheduled_start <= '{start_before.isoformat()}'")
    
    where_clause = " AND ".join(conditions)
    
    query = f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.events`
        WHERE {where_clause}
        ORDER BY scheduled_start DESC
        LIMIT 100
    """
    
    results = bq_client.query(query).result()
    events = [dict(row) for row in results]
    
    return {"events": events}

# ============================================================================
# ENDPOINTS - INCIDENTS
# ============================================================================

@app.post("/v1/incidents", tags=["Incidents"])
async def create_incident(
    incident: IncidentCreate,
    background_tasks: BackgroundTasks,
    token: TokenInfo = Depends(validate_token)
):
    """Create a new incident."""
    
    if "write" not in token.permissions:
        raise HTTPException(status_code=403, detail="Write permission required")
    
    incident_id = f"INC-{uuid.uuid4().hex[:12].upper()}"
    
    row = {
        "incident_id": incident_id,
        "engagement_id": token.engagement_id,
        "client_id": token.client_id,
        "vertical_id": "unknown",
        "incident_name": incident.incident_name,
        "incident_type": incident.incident_type,
        "severity": incident.severity,
        "location_semantic": incident.location.semantic if incident.location else None,
        "location_lat": incident.location.lat if incident.location else None,
        "location_lng": incident.location.lng if incident.location else None,
        "event_id": incident.event_id,
        "detected_at": datetime.now(timezone.utc).isoformat(),
        "status": "active",
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    table_id = f"{PROJECT_ID}.{DATASET_ID}.incidents"
    errors = bq_client.insert_rows_json(table_id, [row])
    
    if errors:
        raise HTTPException(status_code=500, detail=f"Insert error: {errors}")
    
    # Trigger playbook matching for high-severity incidents
    if incident.severity >= 3:
        background_tasks.add_task(
            publish_to_pubsub,
            "incident-created",
            {
                "incident_id": incident_id,
                "severity": incident.severity,
                "client_id": token.client_id
            }
        )
    
    return {"incident_id": incident_id, **incident.dict()}

@app.get("/v1/incidents", tags=["Incidents"])
async def list_incidents(
    token: TokenInfo = Depends(validate_token),
    status: Optional[str] = None,
    severity_min: Optional[int] = Query(None, ge=1, le=5)
):
    """List incidents for the authenticated client."""
    
    conditions = [f"client_id = '{token.client_id}'"]
    
    if status:
        conditions.append(f"status = '{status}'")
    if severity_min:
        conditions.append(f"severity >= {severity_min}")
    
    where_clause = " AND ".join(conditions)
    
    query = f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.incidents`
        WHERE {where_clause}
        ORDER BY detected_at DESC
        LIMIT 100
    """
    
    results = bq_client.query(query).result()
    incidents = [dict(row) for row in results]
    
    return {"incidents": incidents}

# ============================================================================
# ENDPOINTS - PLAYBOOKS
# ============================================================================

@app.post("/v1/playbooks/match", tags=["Playbooks"])
async def match_playbooks(
    request: PlaybookMatch,
    token: TokenInfo = Depends(validate_token)
):
    """
    Find matching playbooks for current conditions.
    
    This is the core SIPE engine entry point.
    """
    
    # In production, this would:
    # 1. Parse conditions
    # 2. Query playbooks table for matching trigger conditions
    # 3. Score each match
    # 4. Include cross-vertical playbooks if requested
    # 5. Return ranked matches
    
    # For now, return example matches
    query = f"""
        SELECT 
            playbook_id,
            playbook_code,
            playbook_name,
            playbook_description,
            trigger_conditions,
            evidence_success_rate,
            evidence_instances,
            is_universal,
            verticals_applicable
        FROM `{PROJECT_ID}.{DATASET_ID}.playbooks`
        WHERE status = 'approved'
        LIMIT 10
    """
    
    try:
        results = bq_client.query(query).result()
        playbooks = [dict(row) for row in results]
        
        # Simple matching logic (would be much more sophisticated in production)
        matches = []
        for pb in playbooks:
            # Calculate match score based on conditions
            match_score = 0.5  # Placeholder
            
            matches.append({
                "playbook_id": pb["playbook_id"],
                "playbook_code": pb["playbook_code"],
                "playbook_name": pb["playbook_name"],
                "match_score": match_score,
                "conditions_matched": [],
                "source_vertical": pb.get("verticals_applicable", ["universal"])[0] if pb.get("verticals_applicable") else "universal",
                "evidence_success_rate": pb.get("evidence_success_rate", 0)
            })
        
        # Sort by match score
        matches.sort(key=lambda x: x["match_score"], reverse=True)
        
        return {"matches": matches[:5]}  # Top 5 matches
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Playbook matching error: {str(e)}")

@app.get("/v1/playbooks/{playbook_id}", tags=["Playbooks"])
async def get_playbook(
    playbook_id: str = Path(...),
    token: TokenInfo = Depends(validate_token)
):
    """Get playbook details."""
    
    query = f"""
        SELECT *
        FROM `{PROJECT_ID}.{DATASET_ID}.playbooks`
        WHERE playbook_id = @playbook_id
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("playbook_id", "STRING", playbook_id)
        ]
    )
    
    try:
        results = bq_client.query(query, job_config=job_config).result()
        row = next(iter(results), None)
        
        if not row:
            raise HTTPException(status_code=404, detail="Playbook not found")
        
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

@app.post("/v1/playbooks/{playbook_id}/apply", tags=["Playbooks"])
async def apply_playbook(
    playbook_id: str = Path(...),
    signal_id: str = ...,
    actions_taken: Optional[List[str]] = None,
    adaptations_made: Optional[str] = None,
    token: TokenInfo = Depends(validate_token)
):
    """Record playbook application."""
    
    if "write" not in token.permissions:
        raise HTTPException(status_code=403, detail="Write permission required")
    
    application_id = f"PBA-{uuid.uuid4().hex[:12].upper()}"
    
    row = {
        "application_id": application_id,
        "playbook_id": playbook_id,
        "signal_id": signal_id,
        "engagement_id": token.engagement_id,
        "client_id": token.client_id,
        "vertical_id": "unknown",
        "applied_at": datetime.now(timezone.utc).isoformat(),
        "applied_by": f"api:{token.client_id}",
        "actions_taken": json.dumps(actions_taken) if actions_taken else None,
        "adaptations_made": json.dumps({"description": adaptations_made}) if adaptations_made else None,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    table_id = f"{PROJECT_ID}.{DATASET_ID}.playbook_applications"
    errors = bq_client.insert_rows_json(table_id, [row])
    
    if errors:
        raise HTTPException(status_code=500, detail=f"Insert error: {errors}")
    
    return {"application_id": application_id, "status": "recorded"}

# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
