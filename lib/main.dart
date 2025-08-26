import 'package:admin_qr_manager/adminLoginPage.dart';
import 'package:admin_qr_manager/splashScreen.dart';
import 'package:flutter/material.dart';
import 'package:admin_qr_manager/login_page.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';


void main() {
// Create <style> element
//   final style = web.document.createElement('style') as web.HTMLStyleElement;
//
//   style.innerHTML = '''
//     body {
//       cursor: url("assets/my_cursor.png") 8 8, auto !important;
//     }
//   '''.toJS; // ✅ convert Dart String to JS string
//
//   // Append to document head
//   web.document.head?.appendChild(style);
//
//   // Append to document head
//   web.document.head?.appendChild(style);

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