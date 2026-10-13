import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/relationship_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_translator.dart';
import '../../core/network/realtime_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/sync_queue_service.dart';
import '../../core/storage/local_storage.dart';

class DashboardProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  static const _uuid = Uuid();
  StreamSubscription? _realtimeSub;

  List<RelationshipModel> _allRelationships = [];
  List<RelationshipModel> _monitoredByMe = []; // Relationships where current user is monitor
  List<RelationshipModel> _monitoringMe = []; // Relationships where current user is monitored

  bool _isLoading = false;
  String? _errorMessage;
  String? _errorMessageKey;
  int _activeIncidentsCount = 0;
  int _unreadNotificationsCount = 0;
  bool _lastCheckInOffline = false;
  String? _currentUserId;

  DashboardProvider() {
    _loadCurrentUserId();
    _initRealtime();
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await LocalStorage.getUserId();
  }

  String? get currentUserId => _currentUserId;
  List<RelationshipModel> get allRelationships => _allRelationships;
  List<RelationshipModel> get monitoredByMe => _monitoredByMe;
  List<RelationshipModel> get monitoringMe => _monitoringMe;
  bool get isLoading => _isLoading;
  String? get errorMessageKey => _errorMessageKey;
  String? get errorMessage {
    if (_errorMessageKey != null) {
      return AppLocalizations.staticTr(_errorMessageKey!, fallback: _errorMessage);
    }
    return _errorMessage;
  }

  String? getErrorMessage(BuildContext context) {
    if (_errorMessageKey != null) {
      return context.tr(_errorMessageKey!, fallback: _errorMessage);
    }
    return _errorMessage;
  }
  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;
  void setSelectedTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  int get activeIncidentsCount => _activeIncidentsCount;
  int get unreadNotificationsCount =>
      _unreadNotificationsCount > 0 ? _unreadNotificationsCount : activeIncidentsCount;
  bool get lastCheckInOffline => _lastCheckInOffline;

  void incrementUnreadNotifications() {
    _unreadNotificationsCount = unreadNotificationsCount + 1;
    notifyListeners();
  }

  void setUnreadNotificationsCount(int count) {
    _unreadNotificationsCount = count;
    notifyListeners();
  }

  void clearUnreadNotifications() {
    _unreadNotificationsCount = 0;
    _activeIncidentsCount = 0;
    notifyListeners();
  }

  // Active state for Monitored view (if user is monitored by someone)
  MonitoringState get myCurrentState {
    if (_monitoringMe.isEmpty) return MonitoringState.ACTIVE;
    // Return highest severity state if multiple
    for (final rel in _monitoringMe) {
      final state = rel.config?.currentState;
      if (state == MonitoringState.ESCALATED ||
          state == MonitoringState.ALERT_TRIGGERED) {
        return state ?? MonitoringState.ESCALATED;
      }
      if (state == MonitoringState.WARNING ||
          state == MonitoringState.GRACE_PERIOD ||
          state == MonitoringState.CHECK_IN_PENDING) {
        return state ?? MonitoringState.WARNING;
      }
      if (state == MonitoringState.CHECK_IN_REQUIRED) {
        return MonitoringState.CHECK_IN_REQUIRED;
      }
    }
    return _monitoringMe.first.config?.currentState ?? MonitoringState.ACTIVE;
  }

  DateTime? get myLastActivityAt {
    if (_monitoringMe.isEmpty) return null;
    return _monitoringMe.first.config?.lastMeaningfulActivityAt;
  }

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    _errorMessageKey = null;
    notifyListeners();

    try {
      final currentUserId = await LocalStorage.getUserId();
      _currentUserId = currentUserId;
      final relResponse = await _apiClient.dio.get(ApiEndpoints.relationships);

      if (relResponse.statusCode == 200) {
        if (relResponse.data is Map<String, dynamic> || relResponse.data is Map) {
          final data = relResponse.data as Map;
          final List rawMonitoring = (data['monitoring'] as List?) ?? [];
          final List rawMonitoredBy = (data['monitoredBy'] as List?) ?? [];

          _monitoredByMe = rawMonitoring
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .where((r) => r.status == RelationshipStatus.ACCEPTED)
              .toList();

          _monitoringMe = rawMonitoredBy
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .where((r) => r.status == RelationshipStatus.ACCEPTED)
              .toList();

          _allRelationships = [
            ...rawMonitoring.map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>)),
            ...rawMonitoredBy.map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>)),
          ];
        } else if (relResponse.data is List) {
          final List list = relResponse.data as List;
          _allRelationships = list
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .toList();

          _monitoringMe = _allRelationships
              .where((r) => r.monitoredUserId == currentUserId && r.status == RelationshipStatus.ACCEPTED)
              .toList();

          _monitoredByMe = _allRelationships
              .where((r) =>
                  (r.monitorUserId == currentUserId || r.monitorId == currentUserId) &&
                  r.status == RelationshipStatus.ACCEPTED)
              .toList();
        }
      }

      // Fetch active incidents (Backend uses OPEN instead of TRIGGERED)
      final incidentResponse = await _apiClient.dio.get(
        ApiEndpoints.incidents,
        queryParameters: {'status': 'OPEN'},
      );
      if (incidentResponse.statusCode == 200) {
        final List incList = incidentResponse.data as List;
        _activeIncidentsCount = incList.length;
        if (_unreadNotificationsCount < _activeIncidentsCount) {
          _unreadNotificationsCount = _activeIncidentsCount;
        }
      }
    } catch (e) {
      _errorMessageKey = 'dashboard_error_load_failed';
      _errorMessage = 'Could not load data. Please try again.';
      debugPrint('[DashboardProvider] Fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendCheckIn({
    String? note,
    int? batteryLevel,
    double? latitude,
    double? longitude,
  }) async {
    _lastCheckInOffline = false;
    final deviceId = await LocalStorage.getDeviceId() ??
        await LocalStorage.getOrCreateDeviceUid();
    final eventId = _uuid.v4();

    double? lat = latitude;
    double? lng = longitude;
    if (lat == null || lng == null) {
      final loc = await PermissionService().getSingleShotLocation();
      if (loc != null) {
        lat = loc['latitude'];
        lng = loc['longitude'];
      }
    }

    final payload = {
      'eventId': eventId,
      'deviceId': deviceId,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (note != null && note.isNotEmpty) 'note': note,
      if (lat != null && lng != null)
        'location': {'latitude': lat, 'longitude': lng},
    };

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.checkIns,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map && response.data['deviceId'] != null) {
          await LocalStorage.saveDeviceId(response.data['deviceId'].toString());
        }
        // Refresh dashboard data immediately to reflect ACTIVE state
        await fetchDashboardData();
        return true;
      }
      return false;
    } catch (e) {
      if (SyncQueueService.isNetworkOrOfflineError(e)) {
        await SyncQueueService().enqueue(
          id: eventId,
          type: SyncItemType.checkIn,
          endpoint: ApiEndpoints.checkIns,
          payload: payload,
        );
        _lastCheckInOffline = true;
        debugPrint('[DashboardProvider] Check-in enqueued offline: $eventId');
        return true;
      }
      debugPrint('[DashboardProvider] Check-in error: $e');
      return false;
    }
  }

  Future<String?> generateInviteCode({String? label}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.inviteCode,
        data: {if (label != null) 'label': label},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (response.data['invitationCode'] ?? response.data['inviteCode']) as String?;
      }
    } catch (e) {
      debugPrint('[DashboardProvider] Generate invite code error: $e');
    }
    return null;
  }

  Future<bool> acceptInviteCode(String code) async {
    _errorMessage = null;
    _errorMessageKey = null;
    try {
      final cleanCode = code.trim().toUpperCase();
      final response = await _apiClient.dio.post(
        ApiEndpoints.acceptInvite,
        data: {
          'invitationCode': cleanCode,
          'inviteCode': cleanCode,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDashboardData();
        return true;
      }
    } catch (e) {
      _errorMessageKey = ApiErrorTranslator.toKey(e);
      _errorMessage = ApiErrorTranslator.translate(e);
      debugPrint('[DashboardProvider] Accept invite error: $e');
    }
    return false;
  }

  Future<bool> createRelationship({required String monitoredUserEmail, String? label}) async {
    _errorMessage = null;
    _errorMessageKey = null;
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.relationships,
        data: {
          'monitoredUserEmail': monitoredUserEmail.trim(),
          if (label != null && label.isNotEmpty) 'label': label.trim(),
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDashboardData();
        return true;
      }
    } catch (e) {
      _errorMessageKey = ApiErrorTranslator.toKey(e);
      _errorMessage = ApiErrorTranslator.translate(e);
      debugPrint('[DashboardProvider] Create relationship error: $e');
    }
    return false;
  }

  Future<bool> pauseMonitoring(String relationshipId, {int durationMinutes = 120}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.pauseMonitoring(relationshipId),
        data: {'durationMinutes': durationMinutes},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDashboardData();
        return true;
      }
    } catch (e) {
      debugPrint('[DashboardProvider] Pause monitoring error: $e');
    }
    return false;
  }

  Future<bool> resumeMonitoring(String relationshipId) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.resumeMonitoring(relationshipId),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDashboardData();
        return true;
      }
    } catch (e) {
      debugPrint('[DashboardProvider] Resume monitoring error: $e');
    }
    return false;
  }

  void _initRealtime() {
    _realtimeSub = RealtimeService().eventStream.listen((event) {
      _handleRealtimeEvent(event);
    });
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) async {
    final type = event['type']?.toString();
    if (type == null) return;

    switch (type) {
      case 'CHECK_IN_CONFIRMED':
        final userId = event['userId']?.toString();
        final occurredStr = event['occurredAt']?.toString();
        final occurredAt = DateTime.tryParse(occurredStr ?? '') ?? DateTime.now();

        if (userId != null) {
          _monitoredByMe = _monitoredByMe.map((rel) {
            if (rel.monitoredUserId == userId) {
              final updatedConfig = rel.config?.copyWith(
                lastMeaningfulActivityAt: occurredAt,
                currentState: MonitoringState.ACTIVE,
              );
              return rel.copyWith(config: updatedConfig);
            }
            return rel;
          }).toList();

          _monitoringMe = _monitoringMe.map((rel) {
            if (rel.monitoredUserId == userId) {
              final updatedConfig = rel.config?.copyWith(
                lastMeaningfulActivityAt: occurredAt,
                currentState: MonitoringState.ACTIVE,
              );
              return rel.copyWith(config: updatedConfig);
            }
            return rel;
          }).toList();
        }

        if (_activeIncidentsCount > 0) {
          _activeIncidentsCount--;
        }
        final currentId = _currentUserId ?? await LocalStorage.getUserId();
        if (userId != null && userId.isNotEmpty && currentId != null && userId != currentId) {
          _unreadNotificationsCount = unreadNotificationsCount + 1;
        }
        notifyListeners();
        break;

      case 'ACTIVITY_RECORDED':
        final userId = (event['userId'] ?? event['monitoredUserId'])?.toString();
        final occurredStr = event['occurredAt']?.toString();
        final occurredAt = DateTime.tryParse(occurredStr ?? '') ?? DateTime.now();

        if (userId != null) {
          _monitoredByMe = _monitoredByMe.map((rel) {
            if (rel.monitoredUserId == userId) {
              final updatedConfig = rel.config?.copyWith(
                lastMeaningfulActivityAt: occurredAt,
              );
              return rel.copyWith(config: updatedConfig);
            }
            return rel;
          }).toList();
          notifyListeners();
        }
        break;

      case 'INCIDENT_CREATED':
        _activeIncidentsCount++;
        _unreadNotificationsCount = unreadNotificationsCount + 1;
        final incident = event['incident'];
        final targetUserId = incident is Map ? incident['monitoredUserId']?.toString() : null;
        if (targetUserId != null) {
          _monitoredByMe = _monitoredByMe.map((rel) {
            if (rel.monitoredUserId == targetUserId) {
              final updatedConfig = rel.config?.copyWith(
                currentState: MonitoringState.ALERT_TRIGGERED,
              );
              return rel.copyWith(config: updatedConfig);
            }
            return rel;
          }).toList();
        }
        notifyListeners();
        break;

      case 'INCIDENT_RESOLVED':
        if (_activeIncidentsCount > 0) {
          _activeIncidentsCount--;
        }
        if (_unreadNotificationsCount > 0) {
          _unreadNotificationsCount--;
        }
        notifyListeners();
        break;

      case 'MONITORING_CONFIG_UPDATED':
      case 'RELATIONSHIP_UPDATED':
        fetchDashboardData();
        break;
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
