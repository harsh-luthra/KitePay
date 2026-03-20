import 'dart:async';

import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/models/QrCode.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum SocketStatus { connecting, connected, reconnected, disconnected, error }

class SocketManager {
  SocketManager._();
  static final SocketManager instance = SocketManager._(); // singleton [1]

  IO.Socket? _socket;
  bool _initialized = false;

  bool get isConnected => _socket?.connected == true;

  // Broadcast so multiple listeners can subscribe
  final _txController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get txStream => _txController.stream;

  // Connection status broadcast
  final _connController = StreamController<SocketStatus>.broadcast();
  Stream<SocketStatus> get connectionStream => _connController.stream;

  // QR alert broadcast
  final _qrAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get qrAlertController => _qrAlertController.stream;

  // Qr Limit Alert broadcast
  final _qrLimitAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get qrLimitAlertController => _qrLimitAlertController.stream;

  // Transaction status change broadcast
  final _txStatusChangeController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get txStatusChangeStream => _txStatusChangeController.stream;

  // Force Refresh broadcast
  final _forceRefreshController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get forceRefreshController => _forceRefreshController.stream;


  Future<void> connect({
    required String url,
    required String jwt,
    required List<String> qrIds,
    required AppUser userMeta,
  }) async {

    _connController.add(SocketStatus.connecting);

    // Reuse connection if alive
    if (isConnected) {
      subscribeQrIds(qrIds);
      _connController.add(SocketStatus.connected);
      return;
    }

    final opts = IO.OptionBuilder()
        .setTransports(<String>['websocket'])
        .setAuth({'token': jwt})
        .enableReconnection()
        .enableForceNew()
        .build();
    // Fix: socket_io_client expects List<String> but build() produces List<dynamic>
    if (opts['transports'] is List && opts['transports'] is! List<String>) {
      opts['transports'] = (opts['transports'] as List).cast<String>();
    }
    _socket ??= IO.io(url, opts);

    // Remove old listeners if reusing socket object across hot restarts
    if (_initialized) {
      _socket!
        ..off('connect')
        ..off('reconnect')
        ..off('txn:new')
        ..off('txn:statusChange')
        ..off('connect_error')
        ..off('error')
        ..off('disconnect');
    }

    _socket!
      ..onConnect((_) async {
        subscribeQrIds(qrIds);
        if (userMeta.role == 'admin') {
          subscribeQrAlert();
        }
        _connController.add(SocketStatus.connected);
      })
      ..onReconnect((_) {
        subscribeQrIds(qrIds);
        _connController.add(SocketStatus.reconnected);
      })
      ..on('txn:new', (data) {
        if (data is Map) {
          _txController.add(Map<String, dynamic>.from(data));
        } else {
          _txController.add({'raw': data});
        }
      })
      ..on('txn:statusChange', (data) {
        if (data is Map) {
          _txStatusChangeController.add(Map<String, dynamic>.from(data));
        } else {
          _txStatusChangeController.add({'raw': data});
        }
      })
      ..on('qrsAlert', (data) {
        if (data is Map) {
          _qrAlertController.add(Map<String, dynamic>.from(data));
        } else {
          _qrAlertController.add({'raw': data});
        }
      })
      ..on('qrLimitAlert', (data) {
        if (data is Map) {
          _qrLimitAlertController.add(Map<String, dynamic>.from(data));
        } else {
          _qrLimitAlertController.add({'raw': data});
        }
      })
      ..on('forceRefresh', (data) {
        if (data is Map) {
          _forceRefreshController.add(Map<String, dynamic>.from(data));
        } else {
          _forceRefreshController.add({'raw': data});
        }
      })
      ..onConnectError((_) {
        _connController.add(SocketStatus.error);
      })
      ..onError((_) {
        _connController.add(SocketStatus.error);
      })
      ..onDisconnect((_) {
        _connController.add(SocketStatus.disconnected);
      });

    _initialized = true;
  }

  void subscribeQrIds(List<String> qrIds) {
    if (!isConnected) return;
    _socket!.emit('subscribe:qrs', {'qrIds': List<String>.from(qrIds)});
  }

  void subscribeQrAlert() {
    if (!isConnected) return;
    _socket!.emit('subscribe:qrsAlert', 'qrId');
  }

  void sendQrCodeAlert(QrCode qr) {
    if (!isConnected) return;
    _socket!.emit('send:qrsAlert', qr.toJson());
  }

  void emitQrLimitAlert(Map<String, dynamic> data) {
    _qrLimitAlertController.add(Map<String, dynamic>.from(data));
  }

  void unsubscribeQrIds(List<String> qrIds) {
    if (!isConnected) return;
    _socket!.emit('unsubscribe:qrs', {'qrIds': List<String>.from(qrIds)});
  }

  void dispose() {
    try {
      _socket
        ?..off('txn:new')
        ..off('txn:statusChange')
        ..dispose();
    } catch (_) {}
    _socket = null;
    _initialized = false;
    _connController.add(SocketStatus.disconnected);
  }
}
