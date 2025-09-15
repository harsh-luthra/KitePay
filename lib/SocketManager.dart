import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketManager {
  SocketManager._();
  static final SocketManager instance = SocketManager._(); // singleton [1]

  IO.Socket? _socket;
  bool _initialized = false;

  bool get isConnected => _socket?.connected == true;

  // Broadcast so multiple listeners can subscribe
  final _txController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get txStream => _txController.stream;

  Future<void> connect({
    required String url,
    required String jwt,
    required List<String> qrIds,
  }) async {
    // Reuse connection if alive
    if (isConnected) {
      subscribeQrIds(qrIds);
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
        print("socket Connected Single");
      })
      ..onReconnect((_) => subscribeQrIds(qrIds))
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
        // handle auth/network failure
      })
      ..onError((err) {})
      ..onDisconnect((_) {});

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
  }

  void closeStreams() {
    _txController.close();
  }

}
