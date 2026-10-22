import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

enum SyncItemType {
  checkIn,
  activity,
  heartbeat,
}

enum SyncFlushStatus {
  success,
  empty,
  networkUnavailable,
  alreadyRunning,
  partialError,
}

class SyncQueueItem {
  final String id;
  final SyncItemType type;
  final String endpoint;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;
  final int retryCount;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.payload,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  SyncQueueItem copyWith({int? retryCount}) {
    return SyncQueueItem(
      id: id,
      type: type,
      endpoint: endpoint,
      payload: payload,
      enqueuedAt: enqueuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'endpoint': endpoint,
        'payload': payload,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] as String,
        type: SyncItemType.values.firstWhere((e) => e.name == json['type']),
        endpoint: json['endpoint'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

class SyncFlushResult {
  final SyncFlushStatus status;
  final int processedCount;
  final int remainingCount;
  final String? errorMessage;

  SyncFlushResult({
    required this.status,
    this.processedCount = 0,
    this.remainingCount = 0,
    this.errorMessage,
  });

  @override
  String toString() =>
      'SyncFlushResult(status: $status, processed: $processedCount, remaining: $remainingCount)';
}

class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  static const String _queueKey = 'evernear_offline_sync_queue';
  static const String _legacyQueueKey = 'carely_offline_sync_queue';
  static const int maxActivities = 200;
  static const int maxCheckIns = 100;

  final ApiClient _apiClient = ApiClient();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _connectivityDebounceTimer;
  bool _isFlushing = false;
  bool _isListening = false;

  // In-memory queue cache to avoid full JSON decode/encode churn on every enqueue
  List<SyncQueueItem>? _cachedQueue;
  String? _lastRaw;

  bool get isFlushing => _isFlushing;

  /// Start listening to network changes to automatically trigger queue flush
  void startListeningToNetwork() {
    if (_isListening) return;
    _isListening = true;

    try {
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline) {
          debugPrint(
              '[SyncQueueService] Network transition detected (online). Debouncing flush for 2 seconds...');
          _connectivityDebounceTimer?.cancel();
          _connectivityDebounceTimer = Timer(const Duration(seconds: 2), () {
            debugPrint(
                '[SyncQueueService] Network stable. Triggering debounced queue flush...');
            flush();
          });
        } else {
          _connectivityDebounceTimer?.cancel();
        }
      }, onError: (err) {
        debugPrint('[SyncQueueService] Error on connectivity stream: $err');
      });
    } catch (e) {
      debugPrint('[SyncQueueService] Failed to listen to connectivity: $e');
    }
  }

  void stopListeningToNetwork() {
    _connectivityDebounceTimer?.cancel();
    _connectivityDebounceTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _isListening = false;
  }

  Future<void> _enqueueLock = Future.value();

  /// Enqueue an event into local offline persistent storage
  Future<void> enqueue({
    required String id,
    required SyncItemType type,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) {
    final next = _enqueueLock.then((_) => _enqueueInternal(
          id: id,
          type: type,
          endpoint: endpoint,
          payload: payload,
        ));
    _enqueueLock = next.catchError((_) {});
    return next;
  }

  Future<void> _enqueueInternal({
    required String id,
    required SyncItemType type,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _readQueue(prefs);

    // Idempotency deduplication: remove item if same id already enqueued
    items.removeWhere((item) => item.id == id);

    // Feature 57: Coalesce reachability heartbeats at enqueue time so only the latest is stored
    if (type == SyncItemType.heartbeat) {
      items.removeWhere((item) => item.type == SyncItemType.heartbeat);
    }

    // Bounded queue limits (SYNC-02): Prune oldest items to prevent unbounded memory growth
    if (type == SyncItemType.activity) {
      final activities =
          items.where((i) => i.type == SyncItemType.activity).toList();
      if (activities.length >= maxActivities) {
        activities.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
        final pruneCount = (activities.length - maxActivities) + 1;
        final pruneIds = activities.take(pruneCount).map((a) => a.id).toSet();
        items.removeWhere((i) => pruneIds.contains(i.id));
      }
    } else if (type == SyncItemType.checkIn) {
      final checkIns =
          items.where((i) => i.type == SyncItemType.checkIn).toList();
      if (checkIns.length >= maxCheckIns) {
        checkIns.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
        final pruneCount = (checkIns.length - maxCheckIns) + 1;
        final pruneIds = checkIns.take(pruneCount).map((a) => a.id).toSet();
        items.removeWhere((i) => pruneIds.contains(i.id));
      }
    }

    final newItem = SyncQueueItem(
      id: id,
      type: type,
      endpoint: endpoint,
      payload: payload,
      enqueuedAt: DateTime.now(),
    );

    items.add(newItem);
    await _writeQueue(prefs, items);
    debugPrint(
        '[SyncQueueService] Enqueued item $id (type: ${type.name}). Queue length: ${items.length}');
  }

  /// Safely remove successful items and increment retryCount for failed items under mutex lock.
  Future<List<SyncQueueItem>> _removeSuccessfulFromQueue(
    Set<String> successfulIds, {
    Set<String>? attemptedFailedIds,
  }) {
    final next = _enqueueLock.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await _readQueue(prefs);
      final remaining = <SyncQueueItem>[];
      for (final item in currentQueue) {
        if (successfulIds.contains(item.id)) {
          continue;
        }
        if (attemptedFailedIds != null && attemptedFailedIds.contains(item.id)) {
          remaining.add(item.copyWith(retryCount: item.retryCount + 1));
        } else {
          remaining.add(item);
        }
      }
      await _writeQueue(prefs, remaining);
      return remaining;
    });
    _enqueueLock = next.then((_) {}).catchError((_) {});
    return next;
  }

  /// Check whether an error is caused by network connectivity loss, timeout, or rate-limiting
  static bool isNetworkOrOfflineError(dynamic error) {
    if (error is! DioException) return false;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    if (error.type == DioExceptionType.unknown &&
        error.error is SocketException) {
      return true;
    }

    // Rate-limited (429) or Temporary server errors (500, 502, 503, 504)
    final statusCode = error.response?.statusCode;
    if (statusCode != null && (statusCode == 429 || statusCode >= 500)) {
      return true;
    }

    return false;
  }

  /// Flush queue and replay items to backend in FIFO order
  Future<SyncFlushResult> flush() async {
    if (_isFlushing) {
      debugPrint(
          '[SyncQueueService] Flush already in progress, skipping concurrent run');
      return SyncFlushResult(status: SyncFlushStatus.alreadyRunning);
    }

    _isFlushing = true;
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOnline =
          connectivityResults.any((r) => r != ConnectivityResult.none);
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        final items = await _readQueue(prefs);
        return SyncFlushResult(
          status: SyncFlushStatus.networkUnavailable,
          remainingCount: items.length,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      var items = await _readQueue(prefs);
      if (items.isEmpty) {
        return SyncFlushResult(status: SyncFlushStatus.empty);
      }

      // Sort FIFO by enqueued timestamp
      items.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
      debugPrint(
          '[SyncQueueService] Starting flush for ${items.length} items...');

      int processedCount = 0;
      final successfulIds = <String>{};
      final attemptedFailedIds = <String>{};
      bool networkDropped = false;

      // 1. Group and replay Activities in Chunks of 20 (SYNC-03)
      final activityItems =
          items.where((i) => i.type == SyncItemType.activity).toList();
      if (activityItems.isNotEmpty) {
        const chunkSize = 20;
        for (var i = 0; i < activityItems.length; i += chunkSize) {
          final chunk = activityItems.sublist(
            i,
            (i + chunkSize < activityItems.length)
                ? i + chunkSize
                : activityItems.length,
          );
          try {
            final batchPayload = {
              'activities': chunk.map((a) => a.payload).toList(),
            };
            final response = await _apiClient.dio.post(
              ApiEndpoints.activitiesBatch,
              data: batchPayload,
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              for (final act in chunk) {
                successfulIds.add(act.id);
                processedCount++;
              }
              debugPrint(
                  '[SyncQueueService] Successfully replayed ${chunk.length} activities chunk');
            }
          } catch (e) {
            debugPrint(
                '[SyncQueueService] Failed to replay activities chunk: $e');
            if (isNetworkOrOfflineError(e)) {
              networkDropped = true;
              for (final act in chunk) {
                attemptedFailedIds.add(act.id);
              }
              break; // Stop further replay on network drop or rate limit
            } else {
              // Unrecoverable 4xx client error (except 429): purge chunk to avoid poison queue
              for (final act in chunk) {
                successfulIds.add(act.id);
              }
            }
          }
        }
      }

      // 2. Replay Check-ins sequentially (FIFO order)
      if (!networkDropped) {
        final checkInItems =
            items.where((i) => i.type == SyncItemType.checkIn).toList();
        for (final checkIn in checkInItems) {
          try {
            final response = await _apiClient.dio.post(
              ApiEndpoints.checkIns,
              data: checkIn.payload,
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              successfulIds.add(checkIn.id);
              processedCount++;
              debugPrint(
                  '[SyncQueueService] Replayed check-in ${checkIn.id} successfully');
            }
          } catch (e) {
            debugPrint(
                '[SyncQueueService] Check-in replay error for ${checkIn.id}: $e');
            if (isNetworkOrOfflineError(e)) {
              // Stop replay on network disconnect to preserve FIFO order
              networkDropped = true;
              attemptedFailedIds.add(checkIn.id);
              break;
            } else {
              // Unrecoverable 4xx error (except 429): remove from queue
              successfulIds.add(checkIn.id);
            }
          }
        }
      }

      // 3. Replay coalesced Heartbeat (only the latest)
      if (!networkDropped) {
        final heartbeatItems =
            items.where((i) => i.type == SyncItemType.heartbeat).toList();
        if (heartbeatItems.isNotEmpty) {
          final latestHeartbeat = heartbeatItems.last;
          bool heartbeatSucceeded = false;
          bool heartbeatPermanentError = false;
          try {
            final response = await _apiClient.dio.post(
              ApiEndpoints.heartbeat,
              data: latestHeartbeat.payload,
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              heartbeatSucceeded = true;
              debugPrint(
                  '[SyncQueueService] Replayed coalesced latest heartbeat successfully');
            }
          } catch (e) {
            debugPrint('[SyncQueueService] Heartbeat replay skipped: $e');
            if (isNetworkOrOfflineError(e)) {
              attemptedFailedIds.add(latestHeartbeat.id);
            } else {
              // Unrecoverable 4xx error: remove to avoid poison queue
              heartbeatPermanentError = true;
            }
          }

          if (heartbeatSucceeded || heartbeatPermanentError) {
            // Remove all previous heartbeats only on success or permanent 4xx error
            for (final hb in heartbeatItems) {
              successfulIds.add(hb.id);
              if (heartbeatSucceeded) {
                processedCount++;
              }
            }
          }
        }
      }

      // Update remaining items in queue atomically under mutex
      items = await _removeSuccessfulFromQueue(successfulIds,
          attemptedFailedIds: attemptedFailedIds);

      debugPrint(
          '[SyncQueueService] Flush finished. Processed: $processedCount, Remaining: ${items.length}');
      return SyncFlushResult(
        status: items.isEmpty
            ? SyncFlushStatus.success
            : SyncFlushStatus.partialError,
        processedCount: processedCount,
        remainingCount: items.length,
      );
    } catch (e) {
      debugPrint('[SyncQueueService] Unexpected error during flush: $e');
      return SyncFlushResult(
        status: SyncFlushStatus.partialError,
        errorMessage: e.toString(),
      );
    } finally {
      _isFlushing = false;
    }
  }

  Future<int> getQueueLength() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _readQueue(prefs);
    return items.length;
  }

  Future<void> clearQueue() {
    final next = _enqueueLock.then((_) async {
      _cachedQueue = [];
      _lastRaw = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_legacyQueueKey);
    });
    _enqueueLock = next.catchError((_) {});
    return next;
  }

  Future<List<SyncQueueItem>> _readQueue(SharedPreferences prefs,
      {bool forceReload = false}) async {
    try {
      await prefs.reload();
    } catch (_) {}
    final raw = prefs.getString(_queueKey) ?? prefs.getString(_legacyQueueKey);
    if (!forceReload && raw == _lastRaw && _cachedQueue != null) {
      return List<SyncQueueItem>.from(_cachedQueue!);
    }
    _lastRaw = raw;
    if (raw == null || raw.isEmpty) {
      _cachedQueue = [];
      return [];
    }
    try {
      final List list = jsonDecode(raw) as List;
      _cachedQueue = list
          .map((json) => SyncQueueItem.fromJson(json as Map<String, dynamic>))
          .toList();
      return List<SyncQueueItem>.from(_cachedQueue!);
    } catch (e) {
      debugPrint('[SyncQueueService] Error parsing queue JSON: $e');
      _cachedQueue = [];
      return [];
    }
  }

  Future<void> _writeQueue(
      SharedPreferences prefs, List<SyncQueueItem> items) async {
    final raw = jsonEncode(items.map((i) => i.toJson()).toList());
    _lastRaw = raw;
    _cachedQueue = List<SyncQueueItem>.from(items);
    await prefs.setString(_queueKey, raw);
    await prefs.setString(_legacyQueueKey, raw);
  }
}
