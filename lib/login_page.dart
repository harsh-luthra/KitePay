import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:admin_qr_manager/AppWriteService.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final appwrite = AppWriteService();

  void initState(){
    super.initState();
    print('Test');
    // CheckIfLoggedIn();
  }

  // void CheckIfLoggedIn() async {
  //   bool isLoggedIn = await appwrite.isLoggedIn();
  //
  //   if(!isLoggedIn){
  //     try{
  //       final session = await appwrite.account.createEmailPasswordSession(
  //         email: 'admin@example.com',
  //         password: 'Test@1234',
  //       );
  //       print('Session created: ${session.userId}');
  //     }on AppwriteException catch (e) {
  //       print("Login error: ${e.message}");
  //     }
  //   }
  //
  //   if(isLoggedIn){
  //     final user = await appwrite.account.get();
  //     print("Email: "+user.labels.toString());
  //   }
  //
  //   print(isLoggedIn);
  //
  // }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
