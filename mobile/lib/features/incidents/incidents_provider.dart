import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/enums.dart';
import '../../core/models/incident_model.dart';
import '../../core/models/check_in_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/realtime_service.dart';
import '../../core/storage/local_storage.dart';

enum NotificationFeedType { incident, checkIn }

class NotificationFeedItem {
  final String id;
  final NotificationFeedType type;
  final DateTime timestamp;
  final IncidentModel? incident;
  final CheckInModel? checkIn;

  NotificationFeedItem.incident(this.incident)
      : id = 'inc-${incident!.id}',
        type = NotificationFeedType.incident,
        timestamp = incident.triggeredAt,
        checkIn = null;

  NotificationFeedItem.checkIn(this.checkIn)
      : id = 'chk-${checkIn!.id}',
        type = NotificationFeedType.checkIn,
        timestamp = checkIn.occurredAt,
        incident = null;
}

class IncidentsProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  StreamSubscription? _realtimeSub;

  List<IncidentModel> _incidents = [];
  List<CheckInModel> _checkIns = [];
  Set<String> _readItemIds = {};
  bool _initialReadLoaded = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorMessageKey;
  String? _currentUserId;

  IncidentsProvider() {
    _loadCurrentUserId();
    _loadReadIds();
    _initRealtime();
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await LocalStorage.getUserId();
  }

  String? get currentUserId => _currentUserId;

  Future<void> _loadReadIds() async {
    _readItemIds = await LocalStorage.getReadNotificationIds();
    _initialReadLoaded = true;
    notifyListeners();
  }

  bool isRead(String id) {
    if (_readItemIds.contains(id)) return true;
    if (id.startsWith('chk-') && _currentUserId != null) {
      final rawId = id.substring(4);
      for (final c in _checkIns) {
        if (c.id == rawId && c.userId == _currentUserId) {
          return true;
        }
      }
    }
    return false;
  }

  int get unreadCount =>
      allNotifications.where((item) => !isRead(item.id)).length;

  Future<void> markAsRead(String id) async {
    if (!_readItemIds.contains(id)) {
      _readItemIds.add(id);
      await LocalStorage.saveReadNotificationId(id);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final allIds = allNotifications.map((e) => e.id).toSet();
    _readItemIds.addAll(allIds);
    await LocalStorage.saveReadNotificationIds(allIds);
    notifyListeners();
  }

  List<IncidentModel> get incidents => _incidents;
  List<CheckInModel> get checkIns => _checkIns;
  List<CheckInModel> get incomingCheckIns =>
      _checkIns.where((c) => _currentUserId == null || c.userId != _currentUserId).toList();

  List<NotificationFeedItem> get allNotifications {
    final List<NotificationFeedItem> items = [
      ...incidents.map((i) => NotificationFeedItem.incident(i)),
      ...incomingCheckIns.map((c) => NotificationFeedItem.checkIn(c)),
    ];
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  bool get isLoading => _isLoading;
  String? get errorMessageKey => _errorMessageKey;
  String? get errorMessage {
    if (_errorMessageKey != null) {
      return AppLocalizations.staticTr(_errorMessageKey!, fallback: _errorMessage);
    }
    return _errorMessage;
  }

  List<IncidentModel> get activeIncidents => _incidents
      .where((i) =>
          i.status == IncidentStatus.OPEN ||
          i.status == IncidentStatus.TRIGGERED ||
          i.status == IncidentStatus.ESCALATED)
      .toList();

  List<IncidentModel> get resolvedIncidents => _incidents
      .where((i) =>
          i.status == IncidentStatus.RESOLVED ||
          i.status == IncidentStatus.ACKNOWLEDGED ||
          i.status == IncidentStatus.CANCELLED ||
          i.status == IncidentStatus.FALSE_ALARM)
      .toList();

  Future<void> fetchIncidents() async {
    _isLoading = true;
    _errorMessage = null;
    _errorMessageKey = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.incidents);
      if (response.statusCode == 200) {
        final List list = response.data as List;
        _incidents = list.map((json) => IncidentModel.fromJson(json)).toList();
      }
    } catch (e) {
      _errorMessageKey = 'incidents_error_load_failed';
      _errorMessage = 'Could not load incidents list.';
      debugPrint('[IncidentsProvider] Fetch incidents error: $e');
    }

    try {
      final checkInResponse = await _apiClient.dio.get(ApiEndpoints.checkIns);
      if (checkInResponse.statusCode == 200 && checkInResponse.data is List) {
        final List list = checkInResponse.data as List;
        _checkIns = list
            .map((json) => CheckInModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (ce) {
      debugPrint('[IncidentsProvider] Fetch check-ins error: $ce');
    }

    final currentId = _currentUserId ?? await LocalStorage.getUserId();
    _currentUserId = currentId;

    if (_initialReadLoaded) {
      bool needSave = false;
      if (_readItemIds.isEmpty) {
        for (final inc in resolvedIncidents) {
          _readItemIds.add('inc-${inc.id}');
          needSave = true;
        }
      }
      for (final chk in _checkIns) {
        if (currentId != null && chk.userId == currentId) {
          if (!_readItemIds.contains('chk-${chk.id}')) {
            _readItemIds.add('chk-${chk.id}');
            needSave = true;
          }
        }
      }
      if (needSave) {
        await LocalStorage.saveReadNotificationIds(_readItemIds);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<IncidentModel?> getIncidentDetail(String incidentId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.incidentDetail(incidentId));
      if (response.statusCode == 200) {
        return IncidentModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('[IncidentsProvider] Get detail error: $e');
    }
    return null;
  }

  Future<bool> acknowledgeIncident(String incidentId) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.acknowledgeIncident(incidentId),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchIncidents();
        return true;
      }
    } catch (e) {
      debugPrint('[IncidentsProvider] Acknowledge error: $e');
    }
    return false;
  }

  Future<bool> resolveIncident(String incidentId, {String? resolutionNote}) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.resolveIncident(incidentId),
        data: {
          'status': IncidentStatus.RESOLVED.name,
          if (resolutionNote != null && resolutionNote.isNotEmpty)
            'note': resolutionNote,
          if (resolutionNote != null && resolutionNote.isNotEmpty)
            'resolutionNote': resolutionNote,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchIncidents();
        return true;
      }
    } catch (e) {
      debugPrint('[IncidentsProvider] Resolve error: $e');
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
      case 'INCIDENT_CREATED':
        final incidentData = event['incident'];
        if (incidentData is Map) {
          final newIncident =
              IncidentModel.fromJson(Map<String, dynamic>.from(incidentData));
          if (!_incidents.any((i) => i.id == newIncident.id)) {
            _incidents.insert(0, newIncident);
            notifyListeners();
          }
        } else {
          fetchIncidents();
        }
        break;

      case 'INCIDENT_ACKNOWLEDGED':
        final incidentId = event['incidentId']?.toString();
        final ackedBy = event['acknowledgedBy']?.toString();
        final ackedAt =
            DateTime.tryParse(event['acknowledgedAt']?.toString() ?? '') ??
                DateTime.now();

        if (incidentId != null) {
          _incidents = _incidents.map((inc) {
            if (inc.id == incidentId) {
              return inc.copyWith(
                status: IncidentStatus.ACKNOWLEDGED,
                acknowledgedAt: ackedAt,
                acknowledgedByUserId: ackedBy,
              );
            }
            return inc;
          }).toList();
          notifyListeners();
        }
        break;

      case 'INCIDENT_RESOLVED':
        final incidentId = event['incidentId']?.toString();
        final resolvedBy = event['resolvedBy']?.toString();
        final resolvedAt =
            DateTime.tryParse(event['resolvedAt']?.toString() ?? '') ??
                DateTime.now();
        final note = event['resolutionNote']?.toString();

        if (incidentId != null) {
          _incidents = _incidents.map((inc) {
            if (inc.id == incidentId) {
              return inc.copyWith(
                status: IncidentStatus.RESOLVED,
                resolvedAt: resolvedAt,
                resolvedByUserId: resolvedBy,
                resolutionNote: note ?? inc.resolutionNote,
              );
            }
            return inc;
          }).toList();
          notifyListeners();
        }
        break;

      case 'CHECK_IN_CONFIRMED':
        final userId = event['userId']?.toString() ?? '';
        final occurredStr = event['occurredAt']?.toString();
        final occurredAt = DateTime.tryParse(occurredStr ?? '') ?? DateTime.now();
        final rawCheckInId = event['checkInId']?.toString();
        final checkInId = (rawCheckInId != null && rawCheckInId.isNotEmpty)
            ? rawCheckInId
            : 'chk-${DateTime.now().millisecondsSinceEpoch}';

        final newCheckIn = CheckInModel(
          id: checkInId,
          userId: userId,
          occurredAt: occurredAt,
          batteryLevel: event['batteryLevel'] is int ? event['batteryLevel'] as int : null,
          note: event['note']?.toString(),
          createdAt: DateTime.now(),
          userDisplayName: event['userDisplayName']?.toString(),
        );

        if (!_checkIns.any((c) => c.id == newCheckIn.id)) {
          _checkIns.insert(0, newCheckIn);
          final currentId = _currentUserId ?? await LocalStorage.getUserId();
          if (userId.isNotEmpty && currentId != null && userId == currentId) {
            _readItemIds.add('chk-${newCheckIn.id}');
            await LocalStorage.saveReadNotificationId('chk-${newCheckIn.id}');
          }
          notifyListeners();
        }
        fetchIncidents();
        break;
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
