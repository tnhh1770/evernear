import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  String? _token;
  bool _isDisposed = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_token == token && _isConnected) return;
    _token = token;
    _reconnectAttempts = 0;
    _establishConnection();
  }

  void _establishConnection() {
    if (_token == null || _token!.isEmpty || _isDisposed) return;

    _cleanupSocket();

    try {
      final url = ApiEndpoints.wsUrl(_token!);
      debugPrint('[RealtimeService] Connecting to $url');
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _onDataReceived(data);
        },
        onError: (error) {
          debugPrint('[RealtimeService] WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[RealtimeService] WebSocket closed');
          _isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      debugPrint('[RealtimeService] Failed to establish connection: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _onDataReceived(dynamic data) {
    if (data is String) {
      if (data == 'PONG' || data.trim() == 'pong') return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          debugPrint('[RealtimeService] Event received: ${decoded['type']}');
          _eventController.add(decoded);
        }
      } catch (e) {
        debugPrint('[RealtimeService] Error decoding message: $e');
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'PING'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (_token == null || _isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final backoffSeconds = (_reconnectAttempts * 2).clamp(2, 15);
    debugPrint(
        '[RealtimeService] Scheduling reconnect in ${backoffSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      if (_token != null && !_isDisposed) {
        _establishConnection();
      }
    });
  }

  void disconnect() {
    _token = null;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _cleanupSocket();
    debugPrint('[RealtimeService] Disconnected');
  }

  void _cleanupSocket() {
    _heartbeatTimer?.cancel();
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
  }
}
