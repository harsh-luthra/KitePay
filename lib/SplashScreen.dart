import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'DashboardScreenNew.dart';
import 'MyMetaApi.dart';
import 'adminLoginPage.dart';

final appwrite = AppWriteService();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _startCheck();
  }

  Future<void> _startCheck() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      final shouldRetry = await _showNoInternetDialog();
      if (shouldRetry) {
        _startCheck();
        return;
      }
    }
    _checkLogin();
  }

  /// Returns true if user tapped Retry, false if they tapped Continue Offline.
  Future<bool> _showNoInternetDialog() async {
    final result = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No Internet'),
        content: const Text('Please check your internet connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Offline'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _checkLogin() async {
    setState(() => _checking = true);

    try {
      final user = await appwrite.account.get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      final jwtToken = await AppWriteService().getJWT();
      final userMeta = await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: false,
      );
      if (userMeta == null) throw Exception('Failed to load user metadata');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreenNew(user: user, userMeta: userMeta)),
            (route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      // Not logged in or network failed → show login
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _checking
            ? const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text("Checking login..."),
          ],
        )
            : const AdminLoginScreen(),
      ),
    );
  }
}
