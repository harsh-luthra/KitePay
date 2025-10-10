import 'package:admin_qr_manager/splashScreen.dart';
import 'package:flutter/material.dart';
import 'package:pwa_update_listener/pwa_update_listener.dart';
import 'dart:html' as html;

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

// A shell that listens for PWA updates and prompts reload
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  void _showUpdateSnack(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Expanded(child: Text('A new version is available')),
            TextButton(
              onPressed: () => html.window.location.reload(),
              child: const Text('UPDATE'),
            ),
          ],
        ),
        duration: const Duration(days: 365), // persistent until user decides
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PwaUpdateListener(
      onReady: () => _showUpdateSnack(rootNavigatorKey.currentContext!),
      // onInit, onUpdate, onError can be handled if needed
      child: child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _lightTheme() => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  ThemeData _darkTheme() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'KitePay',
        darkTheme: _darkTheme(),
        themeMode: ThemeMode.light,
        home: SplashScreen(),
      ),
    );
  }
}
