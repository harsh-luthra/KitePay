import 'dart:async';

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

  Future<void> connect({
    required String url,
    required String jwt,
    required List<String> qrIds,
  }) async {

    _connController.add(SocketStatus.connecting);

    // Reuse connection if alive
    if (isConnected) {
      subscribeQrIds(qrIds);
      _connController.add(SocketStatus.connected);
      return;
    }

    _socket ??= IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(<String>['websocket'])
          .setAuth({'token': jwt})
          .enableReconnection()
          .enableForceNew()
          .build(),
    );

    // Remove old listeners if reusing socket object across hot restarts
    if (_initialized) {
      _socket!
        ..off('connect')
        ..off('reconnect')
        ..off('txn:new')
        ..off('connect_error')
        ..off('error')
        ..off('disconnect');
    }

    _socket!
      ..onConnect((_) {
        subscribeQrIds(qrIds);
        _connController.add(SocketStatus.connected);
        print("socket Connected Single");
      })
      ..onReconnect((_) {
        subscribeQrIds(qrIds);
        _connController.add(SocketStatus.reconnected);
      })
      ..on('txn:new', (data) {
        print(data);
        // Ensure a Map payload for downstream consumers
        if (data is Map) {
          _txController.add(Map<String, dynamic>.from(data));
        } else {
          _txController.add({'raw': data});
        }
        // TODO: forward to a StreamController/BLoC/callback
      })
      ..onConnectError((err) {
        _connController.add(SocketStatus.error);
      })
      ..onError((err) {
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

  void unsubscribeQrIds(List<String> qrIds) {
    if (!isConnected) return;
    _socket!.emit('unsubscribe:qrs', {'qrIds': List<String>.from(qrIds)});
  }

  void dispose() {
    try {
      _socket
        ?..off('txn:new')
        ..dispose()
        ..close();
    } catch (_) {}
    _socket = null;
    _initialized = false;
    _connController.add(SocketStatus.disconnected);
  }

  void closeStreams() {
    _txController.close();
    _connController.close();
  }

}
