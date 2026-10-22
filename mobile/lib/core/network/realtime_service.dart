import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_endpoints.dart';

class RealtimeService with WidgetsBindingObserver {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  String? _token;
  bool _isDisposed = false;
  bool _isConnected = false;
  bool _isPaused = false;
  int _reconnectAttempts = 0;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool get isConnected => _isConnected;
  bool get isPaused => _isPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      pause();
    } else if (state == AppLifecycleState.resumed) {
      resume();
    }
  }

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _cleanupSocket();
    _isConnected = false;
    debugPrint('[RealtimeService] Paused WebSocket & reconnect timer (background/paused)');
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    debugPrint('[RealtimeService] Resuming WebSocket connection (app foregrounded)');
    if (_token != null && !_isDisposed) {
      _reconnectAttempts = 0;
      _establishConnection();
    }
  }

  void connect(String token) {
    if (_token == token && _isConnected) return;
    _token = token;
    _reconnectAttempts = 0;
    if (!_isPaused) {
      _establishConnection();
    }
  }

  void _establishConnection() {
    if (_token == null || _token!.isEmpty || _isDisposed || _isPaused) return;

    _cleanupSocket();

    try {
      final url = ApiEndpoints.wsUrl(_token!);
      debugPrint('[RealtimeService] Connecting to WebSocket (token sanitized)');
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
    try {
      String text;
      if (data is String) {
        text = data;
      } else if (data is List<int>) {
        text = utf8.decode(data);
      } else {
        text = data.toString();
      }

      if (text == 'PONG' || text.trim() == 'pong') return;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        debugPrint('[RealtimeService] Event received: ${decoded['type']}');
        _eventController.add(decoded);
      }
    } catch (e) {
      debugPrint('[RealtimeService] Error decoding message: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_isPaused) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isPaused) {
        timer.cancel();
        return;
      }
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'PING'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (_token == null || _isDisposed || _isPaused) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final backoffSeconds = (_reconnectAttempts * 2).clamp(2, 15);
    debugPrint(
        '[RealtimeService] Scheduling reconnect in ${backoffSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      if (_token != null && !_isDisposed && !_isPaused) {
        _establishConnection();
      }
    });
  }

  void disconnect() {
    _token = null;
    _isConnected = false;
    _isPaused = false;
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
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    disconnect();
    _eventController.close();
  }
}

