import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ for SystemNavigator
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:admin_qr_manager/AppWriteService.dart';
import 'DashboardScreenNew.dart';
import 'MyMetaApi.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // ✅ Single shared instance — don't re-instantiate inside methods
  final AppWriteService _appwrite = AppWriteService();

  String? errorMessage;
  bool isLoading = false;
  bool _obscurePassword = true;

  @override // ✅ Missing @override added
  void initState() {
    super.initState();
    _checkIsLoggedIn(); // ✅ Renamed to lowerCamelCase convention
  }

  @override
  void dispose() {
    emailController.dispose();   // ✅ Always dispose controllers
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkIsLoggedIn() async {
    try {
      final bool isLoggedIn = await _appwrite.isLoggedIn();
      if (!isLoggedIn) return;

      final user = await _appwrite.account.get();
      final String jwtToken = await _appwrite.getJWT(); // ✅ reuse instance

      final userMeta = await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: true,
      );

      if (userMeta != null) {
        _moveToDashboard(user, userMeta);
      }
    } catch (e) {
      // ✅ Silent auto-login failure is fine — user just stays on login screen
      debugPrint('Auto-login check failed: $e');
    }
  }

  void _moveToDashboard(models.User user, AppUser userMeta) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardScreenNew(user: user, userMeta: userMeta),
      ),
          (_) => false,
    );
  }

  Future<void> _startCheckThenLogin() async {
    while (true) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        final shouldRetry = await _showNoInternetDialog();
        if (!shouldRetry) return;
      } else {
        break;
      }
    }
    await _loginAdmin();
  }

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
            child: const Text('Cancel'),
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

  Future<void> _loginAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Email and password are required');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _appwrite.account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      final user = await _appwrite.account.get();
      final String jwtToken = await _appwrite.getJWT(); // ✅ reuse instance

      final userMeta = await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: true,
      );

      if (userMeta != null) {
        _moveToDashboard(user, userMeta);
      }
    } on AppwriteException catch (e) {
      debugPrint('AppwriteException: ${e.message}');

      final msg = e.message ?? 'Login failed. Please try again.';

      if (!mounted) return;

      setState(() => errorMessage = null);

      if (msg.contains('has been blocked')) {
        _showErrorDialog(
          title: 'Account Blocked',
          message: 'Your account has been blocked. Please contact support.',
        );
      } else {
        // ✅ Show dialog AND clear inline error to avoid double reporting
        _showErrorDialog(title: 'Login Failed', message: msg);
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      if (mounted) {
        _showErrorDialog(
          title: 'Error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ Extracted reusable error dialog
  void _showErrorDialog({required String title, required String message}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop(); // ✅ Correct way to exit app, not Navigator.pop()
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final formWidth = width < 480 ? width - 48 : 420.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmAndExit();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.96),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formWidth),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.payments_outlined,
                              color: Colors.blue, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Welcome to KitePay',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Sign in to access your account',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 22),

                        // Email
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'email@mail.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: emailController.text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => emailController.clear()),
                              tooltip: 'Clear',
                            )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                          isLoading ? null : _startCheckThenLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Inline error
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed:
                            isLoading ? null : _startCheckThenLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                                : const Text('Sign In',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Having trouble?',
                                style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _showSupportSheet(context),
                              child: const Text('Contact support'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Email: support@kitepay.app'),
            Text('Business hours: 10:00–18:00 IST'),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}