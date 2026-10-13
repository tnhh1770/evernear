class ApiEndpoints {
  // Configurable base URL. Default to localhost:3001 for local testing / emulator
  static String baseUrl = 'http://127.0.0.1:3001/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String profile = '/auth/me';
  static const String googleAuth = '/auth/google';
  static const String appleAuth = '/auth/apple';
  static const String firebaseAuth = '/auth/firebase';
  static const String deleteAccount = '/users/me';
  static const String updateProfile = '/users/me';
  static const String changePassword = '/auth/change-password';

  // Devices
  static const String devices = '/devices';
  static String revokeDevice(String id) => '/devices/$id/revoke';
  static String deleteDevice(String id) => '/devices/$id';

  // Activities & Heartbeat
  static const String heartbeat = '/heartbeat';
  static const String heartbeatAlias = '/activities/heartbeat';
  static const String activities = '/activities';
  static const String activitiesBatch = '/activities/batch';

  // Check-ins
  static const String checkIns = '/check-ins';
  static const String checkInHistory = '/check-ins';

  // Monitoring & Relationships
  static const String relationships = '/monitoring/relationships';
  static const String inviteCode = '/monitoring/relationships/invite-code';
  static const String acceptInvite = '/monitoring/relationships/accept';
  static String monitoringConfig(String id) => '/monitoring/$id/config';
  static String pauseMonitoring(String id) => '/monitoring/$id/pause';
  static String resumeMonitoring(String id) => '/monitoring/$id/resume';

  // Incidents
  static const String incidents = '/incidents';
  static String incidentDetail(String id) => '/incidents/$id';
  static String acknowledgeIncident(String id) => '/incidents/$id/acknowledge';
  static String resolveIncident(String id) => '/incidents/$id/resolve';

  // Locations
  static const String locations = '/locations';
  static String latestLocation([String? userId]) =>
      userId != null ? '/locations/latest?userId=$userId' : '/locations/latest';

  // WebSocket Real-time URL
  static String wsUrl(String token) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portPart/ws?token=$token';
  }
}
