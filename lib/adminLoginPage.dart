import 'dart:async';
import 'dart:convert';

import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
// DashboardScreenNew
import 'package:admin_qr_manager/AppWriteService.dart'; // adjust path as needed
import 'AppConfig.dart';
import 'AppConstants.dart';
import 'DashboardScreenNew.dart';
import 'MyMetaApi.dart';
import 'package:http/http.dart' as http;

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();

}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;

  final appwrite = AppWriteService();

  bool _obscurePassword = true; // Add this to your State

  void initState() {
    super.initState();
    print('Test');
    CheckIsLoggedIn();
  }

  Future<void> CheckIsLoggedIn() async {
    // await loadConfig();
    bool isLoggedIn = await appwrite.isLoggedIn();
    if(isLoggedIn){
      print("Already logged In");

      final user = await appwrite.account.get();
      // final List<String> availableLabels = user.labels;
      // print("Email: "+user.labels.toString());

      if(user.labels.contains('admin')){
        print("Admin logged in");
      }else{
        // print("User is Not Admin: "+user.labels.toString());
      }

     String jwtToken = await AppWriteService().getJWT();

      final userMeta = await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: true, // set true to force re-fetch
      );

      // print(userMeta.toString());

      // loadConfig();

      moveToDashBoard(user, userMeta!);
    }else{
      print("Not logged In");
    }
  }

  void moveToDashBoard(models.User user, AppUser userMeta){
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DashboardScreenNew(user: user,userMeta: userMeta)),
            (_) => false, // removes all previous routes
      );
    }
  }

  Future<void> _startCheckThenLogin() async {
    while (true) {
      final connectivityResult = await Connectivity().checkConnectivity();
      print(connectivityResult.toString());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        await _showNoInternetDialog();
      } else {
        break;
      }

    }

    loginAdmin();
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

  Future<void> loginAdmin() async {
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

    final appwrite = AppWriteService();

    try {
      final session = await appwrite.account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      final user = await appwrite.account.get();

      String jwtToken = await AppWriteService().getJWT();

      final userMeta = await MyMetaApi.getMyMetaData(
        jwtToken: jwtToken,
        refresh: true, // set true to force re-fetch
      );

      // print(userMeta.toString());

      moveToDashBoard(user, userMeta!);

    } on AppwriteException catch (e) {
      print(e.message);

      setState(() {
        errorMessage = e.message ?? 'Login failed';
      });

      if (e.message!.contains('has been blocked')) {
        // 👇 Show blocked user dialog
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Blocked'),
                content: const Text(
                    'Your account has been blocked. Please contact support.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }else{
        if(e.message != null){
          String? msg = e.message;
          showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  title: const Text('Login Failed'),
                  content: Text(
                      msg!),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }


    } catch (e) {
      print(e);
      setState(() {
        errorMessage = 'An unexpected error occurred';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final formWidth = width < 480 ? width - 48 : 420.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final exitConfirmed = await _confirmExit(context);
          if (exitConfirmed && mounted) Navigator.of(context).pop();
        }
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand header
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.payments_outlined, color: Colors.blue, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Welcome to KitePay', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Sign in to access your account', style: TextStyle(color: Colors.grey)),
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
                            suffixIcon: (emailController.text.isNotEmpty)
                                ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => emailController.clear()),
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
                          onSubmitted: (_) => isLoading ? null : _startCheckThenLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            // helperText: 'Use your admin or assigned account credentials',
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Error message (if any)
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: Colors.red),
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

                        // Primary button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _startCheckThenLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Help row (optional)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Having trouble?', style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: isLoading ? null : () => _showSupportSheet(context),
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
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Need help?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
