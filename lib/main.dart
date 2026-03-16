import 'package:admin_qr_manager/splashScreen.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Define light and dark themes
  ThemeData _lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'KitePay',
      // theme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      // ),
      darkTheme: _darkTheme(),
      themeMode: ThemeMode.light, // auto switch based on system theme
      home: SplashScreen(),
    );
  }
}