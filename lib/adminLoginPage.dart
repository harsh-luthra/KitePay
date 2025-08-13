import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
// DashboardScreenNew
import 'package:admin_qr_manager/AppWriteService.dart'; // adjust path as needed
import 'DashboardScreenNew.dart';
import 'dashBoardScreen.dart'; // screen to redirect after login

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

  void initState(){
    super.initState();
    print('Test');
    CheckIsLoggedIn();
  }

  Future<void> CheckIsLoggedIn() async {
    bool isLoggedIn = await appwrite.isLoggedIn();
    if(isLoggedIn){
      print("Already logged In");

      final user = await appwrite.account.get();
      // final List<String> availableLabels = user.labels;
      // print("Email: "+user.labels.toString());

      if(user.labels.contains('admin')){
        // print("Admin logged in");
      }else{
        // print("User is Not Admin: "+user.labels.toString());
      }

      moveToDashBoard(user);
    }else{
      print("Not logged In");
    }
  }

  void moveToDashBoard(models.User user){
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DashboardScreenNew(user: user,)),
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

      moveToDashBoard(user);

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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final exitConfirmed = await _confirmExit(context);
          if (exitConfirmed && mounted) {
            Navigator.of(context).pop(); // Allows back
          }
        }
      },
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome to KitePay',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to access your account',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row(
                    //   children: [
                    //     Checkbox(
                    //       value: rememberMe,
                    //       onChanged: (value) {
                    //         setState(() {
                    //           rememberMe = value ?? false;
                    //         });
                    //       },
                    //     ),
                    //     const Text("Remember me for 30 days"),
                    //   ],
                    // ),
                    // TextButton(
                    //   onPressed: () {
                    //     // Implement forgot password flow
                    //   },
                    //   child: const Text("Forgot password?"),
                    // ),
                  ],
                ),
                const SizedBox(height: 8),
                if (errorMessage != null)
                  Text(errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 350,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _startCheckThenLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 24),
                // const Row(
                //   children: [
                //     Expanded(child: Divider()),
                //     Padding(
                //       padding: EdgeInsets.symmetric(horizontal: 8.0),
                //       child: Text("or continue with"),
                //     ),
                //     Expanded(child: Divider()),
                //   ],
                // ),
                // const SizedBox(height: 16),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     OutlinedButton.icon(
                //       onPressed: () {
                //         // Fingerprint auth logic
                //       },
                //       icon: const Icon(Icons.fingerprint),
                //       label: const Text("Fingerprint"),
                //     ),
                //     const SizedBox(width: 16),
                //     OutlinedButton.icon(
                //       onPressed: () {
                //         // Mobile app login logic
                //       },
                //       icon: const Icon(Icons.smartphone),
                //       label: const Text("Mobile App"),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 32),
                // TextButton(
                //   onPressed: () {
                //     // Navigate to registration page
                //   },
                //   child: const Text("Don’t have an account? Create account"),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
