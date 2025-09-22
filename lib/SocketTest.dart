import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketTestApp extends StatefulWidget {
  @override
  _SocketTestAppState createState() => _SocketTestAppState();
}

class _SocketTestAppState extends State<SocketTestApp> {
  IO.Socket? socket;
  String status = 'Disconnected';
  List<String> messages = [];

  @override
  void initState() {
    super.initState();

    socket = IO.io(
      'https://kite-pay-api-v1.onrender.com', // Your server URL
      IO.OptionBuilder()
          .setTransports(['websocket']) // Connect manually for logging
          .build(),
    );

    socket!.on('connect', (_) {
      setState(() => status = 'Connected');
      print('Socket connected');
    });

    socket!.on('connect_error', (data) {
      setState(() => status = 'Connect Error: $data');
      print('Socket connect error: $data');
    });

    socket!.on('error', (data) {
      setState(() => status = 'Error: $data');
      print('Socket error: $data');
    });

    socket!.on('disconnect', (_) {
      setState(() => status = 'Disconnected');
      print('Socket disconnected');
    });

    socket!.on('txn:new', (data) {
      print('Received txn:new event: $data');
      setState(() {
        messages.add('txn:new: $data');
      });
    });

    // Connect socket after event listeners set
    socket!.connect();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket.io Debug',
      home: Scaffold(
        appBar: AppBar(title: Text('Socket.io Debug')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Connection status: $status'),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (_, i) => ListTile(title: Text(messages[i])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
