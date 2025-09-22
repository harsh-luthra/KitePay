import 'dart:async';

import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/MyMetaApi.dart';
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

  // Connection status broadcast
  final _qrAlertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get qrAlertController => _qrAlertController.stream;

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

    _socket ??= IO.io(
      url,
      IO.OptionBuilder()
            .setTransports(<String>['websocket'])
          .setAuth({'token': jwt})
          .enableReconnection()
          .enableForceNew()
          .build(),
    );

    // socket = IO.io(
    //   'https://kite-pay-api-v1.onrender.com', // Your server URL
    //   IO.OptionBuilder()
    //       .setTransports(['websocket']) // Connect manually for logging
    //       .build(),
    // );

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
      ..onConnect((_) async {
        subscribeQrIds(qrIds);
        if(userMeta.role == 'admin'){
          subscribeQrAlert();
        }
        _connController.add(SocketStatus.connected);
        print("socket Connected Single");
      })
      ..onReconnect((_) {
        subscribeQrIds(qrIds);
        _connController.add(SocketStatus.reconnected);
      })
      ..on('txn:new', (data) {
        // print(data);
        // Ensure a Map payload for downstream consumers
        if (data is Map) {
          _txController.add(Map<String, dynamic>.from(data));
        } else {
          _txController.add({'raw': data});
        }
        // TODO: forward to a StreamController/BLoC/callback
      })
      ..on('qrsAlert', (data) {
        // print('QR ALERT:'+ data.toString());
        // QrCode qrCode = QrCode.fromJson(data);
        // print(qrCode.toString());
        if (data is Map) {
          _qrAlertController.add(Map<String, dynamic>.from(data));
        } else {
          _qrAlertController.add({'raw': data});
        }
        // TODO: forward to a StreamController/BLoC/callback
      })
      ..onConnectError((err) {
        _connController.add(SocketStatus.error);
        print(err);
      })
      ..onError((err) {
        _connController.add(SocketStatus.error);
        print(err);
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
    // print("Sedning Qr Alert: "+qr.toString());
    _socket!.emit('send:qrsAlert', qr.toJson());
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
    _qrAlertController.close();
  }

}
