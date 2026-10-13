export const RealtimeEventType = {
  CHECK_IN_CONFIRMED: 'CHECK_IN_CONFIRMED',
  INCIDENT_CREATED: 'INCIDENT_CREATED',
  INCIDENT_ACKNOWLEDGED: 'INCIDENT_ACKNOWLEDGED',
  INCIDENT_RESOLVED: 'INCIDENT_RESOLVED',
  MONITORING_CONFIG_UPDATED: 'MONITORING_CONFIG_UPDATED',
  RELATIONSHIP_UPDATED: 'RELATIONSHIP_UPDATED',
  ACTIVITY_RECORDED: 'ACTIVITY_RECORDED',
} as const;

export type RealtimeEventType = (typeof RealtimeEventType)[keyof typeof RealtimeEventType];

export interface BaseRealtimeEvent {
  type: string;
  timestamp?: string;
}

export interface CheckInConfirmedEvent extends BaseRealtimeEvent {
  type: 'CHECK_IN_CONFIRMED';
  userId: string;
  checkInId: string;
  occurredAt: string;
  batteryLevel?: number;
  note?: string;
  userDisplayName?: string;
}

export interface IncidentCreatedEvent extends BaseRealtimeEvent {
  type: 'INCIDENT_CREATED';
  incident: any;
}

export interface IncidentAcknowledgedEvent extends BaseRealtimeEvent {
  type: 'INCIDENT_ACKNOWLEDGED';
  incidentId: string;
  acknowledgedBy: string;
  acknowledgedAt: string;
}

export interface IncidentResolvedEvent extends BaseRealtimeEvent {
  type: 'INCIDENT_RESOLVED';
  incidentId: string;
  resolvedBy: string;
  resolvedAt: string;
  resolutionNote?: string;
}

export interface MonitoringConfigUpdatedEvent extends BaseRealtimeEvent {
  type: 'MONITORING_CONFIG_UPDATED';
  relationshipId: string;
  config: any;
}

export interface RelationshipUpdatedEvent extends BaseRealtimeEvent {
  type: 'RELATIONSHIP_UPDATED';
  relationshipId: string;
  status: string;
}

export interface ActivityRecordedEvent extends BaseRealtimeEvent {
  type: 'ACTIVITY_RECORDED';
  userId: string;
  activityType: string;
  occurredAt: string;
}

export type RealtimeEvent =
  | CheckInConfirmedEvent
  | IncidentCreatedEvent
  | IncidentAcknowledgedEvent
  | IncidentResolvedEvent
  | MonitoringConfigUpdatedEvent
  | RelationshipUpdatedEvent
  | ActivityRecordedEvent
  | (BaseRealtimeEvent & Record<string, any>);
