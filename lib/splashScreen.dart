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
    while (true) {
      final connectivityResult = await Connectivity().checkConnectivity();
      print(connectivityResult.toString());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        await _showNoInternetDialog();
      } else {
        break;
      }

    }

    _checkLogin();
  }

  Future<void> _showNoInternetDialog() async {
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No Internet'),
        content: const Text('Please check your internet connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }

  Future<void> _checkLogin() async {
    setState(() => _checking = true);

    try {
      final user = await appwrite.account.get();
      // final List<String> availableLabels = user.labels;
      // Logged in → go to dashboard
      if (!mounted) return;

      String jwtToken = await AppWriteService().getJWT();
      AppUser userMeta = (await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: false, // set true to force re-fetch
      ))!;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreenNew(user: user , userMeta: userMeta,)),
            (route) => false,
      );

    } catch (e) {
      // Not logged in → stay on login
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
