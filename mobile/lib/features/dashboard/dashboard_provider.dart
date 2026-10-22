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
import '../auth/auth_provider.dart';

class DashboardProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  static const _uuid = Uuid();
  StreamSubscription? _realtimeSub;

  List<RelationshipModel> _allRelationships = [];
  List<RelationshipModel> _monitoredByMe = []; // Relationships where current user is monitor
  List<RelationshipModel> _monitoringMe = []; // Relationships where current user is monitored
  Map<String, RelationshipModel> _monitoredByMeMap = {};

  bool _isLoading = false;
  String? _errorMessage;
  String? _errorMessageKey;
  int _activeIncidentsCount = 0;
  int _unreadNotificationsCount = 0;
  bool _lastCheckInOffline = false;
  Map<String, double>? _lastCheckInLocation;
  DateTime? _lastCheckInLocationAt;
  bool _lastCheckInLocationEnabled = true;
  String? _currentUserId;

  DashboardProvider() {
    _loadCurrentUserId();
    _initRealtime();
    AuthProvider.addLogoutCallback(clearState);
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await LocalStorage.getUserId();
    try {
      final selfConfig = await LocalStorage.getSelfMonitoringConfig();
      if (selfConfig != null) {
        if (selfConfig['locationEnabled'] is bool) {
          _lastCheckInLocationEnabled = selfConfig['locationEnabled'] as bool;
        }
        final savedLoc = selfConfig['lastCheckInLocation'];
        if (savedLoc is Map) {
          final lat = (savedLoc['latitude'] as num?)?.toDouble();
          final lng = (savedLoc['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _lastCheckInLocation = {'latitude': lat, 'longitude': lng};
          }
        }
      }
    } catch (_) {}
  }

  Map<String, double>? get lastCheckInLocation => _lastCheckInLocation;
  DateTime? get lastCheckInLocationAt => _lastCheckInLocationAt;
  bool get lastCheckInLocationEnabled => _lastCheckInLocationEnabled;
  String? get formattedLastCheckInLocation {
    if (_lastCheckInLocation == null) return null;
    final lat = _lastCheckInLocation!['latitude'];
    final lng = _lastCheckInLocation!['longitude'];
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
  }

  String? get currentUserId => _currentUserId;
  List<RelationshipModel> get allRelationships => _allRelationships;
  List<RelationshipModel> get monitoredByMe => _monitoredByMe;
  List<RelationshipModel> get monitoringMe => _monitoringMe;
  Map<String, RelationshipModel> get monitoredByMeMap => _monitoredByMeMap;
  RelationshipModel? getMonitoredRelationship(String monitoredUserId) =>
      _monitoredByMeMap[monitoredUserId];
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
  bool _userHasSelectedTab = false;
  int get selectedTabIndex => _selectedTabIndex;
  void setSelectedTabIndex(int index) {
    _userHasSelectedTab = true;
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
    final safeCount = count < 0 ? 0 : count;
    _unreadNotificationsCount = safeCount;
    if (_activeIncidentsCount > safeCount) {
      _activeIncidentsCount = safeCount;
    }
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

      // Parallelize relationships and active incidents requests to eliminate sequential waterfall
      final responses = await Future.wait([
        _apiClient.dio.get(ApiEndpoints.relationships),
        _apiClient.dio.get(
          ApiEndpoints.incidents,
          queryParameters: {'status': 'OPEN'},
        ),
      ]);

      final relResponse = responses[0];
      final incidentResponse = responses[1];

      if (relResponse.statusCode == 200) {
        if (relResponse.data is Map<String, dynamic> || relResponse.data is Map) {
          final data = relResponse.data as Map;
          final List rawMonitoring = (data['monitoring'] as List?) ?? [];
          final List rawMonitoredBy = (data['monitoredBy'] as List?) ?? [];

          _monitoredByMe = rawMonitoring
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .where((r) =>
                  r.status == RelationshipStatus.ACCEPTED &&
                  r.monitoredUser != null)
              .toList();

          _monitoringMe = rawMonitoredBy
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .where((r) =>
                  r.status == RelationshipStatus.ACCEPTED &&
                  r.monitorUser != null)
              .toList();

          _allRelationships = [
            ...rawMonitoring
                .map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>))
                .where((r) => r.monitoredUser != null),
            ...rawMonitoredBy
                .map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>))
                .where((r) => r.monitorUser != null),
          ];
        } else if (relResponse.data is List) {
          final List list = relResponse.data as List;
          _allRelationships = list
              .map((json) => RelationshipModel.fromJson(json as Map<String, dynamic>))
              .where((r) => r.monitoredUser != null || r.monitorUser != null)
              .toList();

          _monitoringMe = _allRelationships
              .where((r) =>
                  r.monitoredUserId == currentUserId &&
                  r.status == RelationshipStatus.ACCEPTED &&
                  r.monitorUser != null)
              .toList();

          _monitoredByMe = _allRelationships
              .where((r) =>
                  (r.monitorUserId == currentUserId || r.monitorId == currentUserId) &&
                  r.status == RelationshipStatus.ACCEPTED &&
                  r.monitoredUser != null)
              .toList();
        }
        _monitoredByMeMap = {for (final r in _monitoredByMe) r.monitoredUserId: r};
      }

      if (incidentResponse.statusCode == 200) {
        final List incList = incidentResponse.data is List ? incidentResponse.data as List : const [];
        final readIds = await LocalStorage.getReadNotificationIds();
        final dismissedIds = await LocalStorage.getDismissedNotificationIds();
        int unreadOpenCount = 0;
        for (final item in incList) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            final notifKey = 'inc-$id';
            if (id.isNotEmpty && !readIds.contains(notifKey) && !dismissedIds.contains(notifKey)) {
              unreadOpenCount++;
            }
          } else {
            unreadOpenCount++;
          }
        }
        _activeIncidentsCount = unreadOpenCount;
      }

      // Role-based initial tab routing:
      // If the user has not explicitly navigated and is ONLY a Guardian (no one monitors them),
      // default them to Tab 1 (Family / MonitorView) instead of Tab 0 (Self / MonitoredView).
      if (!_userHasSelectedTab) {
        if (_monitoringMe.isEmpty && _monitoredByMe.isNotEmpty) {
          _selectedTabIndex = 1;
        } else {
          _selectedTabIndex = 0;
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

  void clearState() {
    _allRelationships = [];
    _monitoredByMe = [];
    _monitoringMe = [];
    _monitoredByMeMap = {};
    _isLoading = false;
    _errorMessage = null;
    _errorMessageKey = null;
    _activeIncidentsCount = 0;
    _unreadNotificationsCount = 0;
    _lastCheckInOffline = false;
    _lastCheckInLocation = null;
    _lastCheckInLocationAt = null;
    _currentUserId = null;
    _userHasSelectedTab = false;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  Future<bool> isLocationSharingEnabled() async {
    if (_monitoringMe.isNotEmpty && _monitoringMe.first.config != null) {
      return _monitoringMe.first.config!.locationEnabled;
    }
    try {
      final selfConfig = await LocalStorage.getSelfMonitoringConfig();
      if (selfConfig != null && selfConfig['locationEnabled'] is bool) {
        return selfConfig['locationEnabled'] as bool;
      }
    } catch (_) {}
    return true;
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

    final allowLocation = await isLocationSharingEnabled();
    _lastCheckInLocationEnabled = allowLocation;

    double? lat;
    double? lng;
    if (allowLocation) {
      lat = latitude;
      lng = longitude;
      if (lat == null || lng == null) {
        final loc = await PermissionService().getSingleShotLocation();
        if (loc != null) {
          lat = loc['latitude'];
          lng = loc['longitude'];
        }
      }
    }

    if (lat != null && lng != null) {
      _lastCheckInLocation = {'latitude': lat, 'longitude': lng};
      _lastCheckInLocationAt = DateTime.now();
      try {
        final selfConfig =
            await LocalStorage.getSelfMonitoringConfig() ?? <String, dynamic>{};
        selfConfig['lastCheckInLocation'] = {'latitude': lat, 'longitude': lng};
        await LocalStorage.saveSelfMonitoringConfig(selfConfig);
      } catch (_) {}
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
        final incident = event['incident'];
        final targetUserId = incident is Map ? (incident['monitoredUserId'] ?? incident['userId'])?.toString() : null;
        final currentId = _currentUserId ?? await LocalStorage.getUserId();
        if (targetUserId != null && targetUserId != currentId) {
          _unreadNotificationsCount = unreadNotificationsCount + 1;
        }
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
        fetchDashboardData();
        break;

      case 'INCIDENT_ESCALATED':
        final relId = event['relationshipId']?.toString();
        if (relId != null) {
          _monitoredByMe = _monitoredByMe.map((rel) {
            if (rel.id == relId) {
              final updatedConfig = rel.config?.copyWith(
                currentState: MonitoringState.ESCALATED,
              );
              return rel.copyWith(config: updatedConfig);
            }
            return rel;
          }).toList();
        }
        notifyListeners();
        fetchDashboardData();
        break;

      case 'CHECK_IN_PROMPT':
        fetchDashboardData();
        break;

      case 'INCIDENT_ACKNOWLEDGED':
        notifyListeners();
        fetchDashboardData();
        break;

      case 'INCIDENT_RESOLVED':
        if (_activeIncidentsCount > 0) {
          _activeIncidentsCount--;
        }
        if (_unreadNotificationsCount > 0) {
          _unreadNotificationsCount--;
        }
        notifyListeners();
        fetchDashboardData();
        break;

      case 'MONITORING_CONFIG_UPDATED':
      case 'RELATIONSHIP_UPDATED':
        fetchDashboardData();
        break;
    }
  }

  @override
  void dispose() {
    AuthProvider.removeLogoutCallback(clearState);
    _realtimeSub?.cancel();
    super.dispose();
  }
}
