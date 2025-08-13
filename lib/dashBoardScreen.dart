import 'package:admin_qr_manager/TransactionPageNew.dart';
import 'package:admin_qr_manager/WithdrawalFormPage.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/services.dart';
import 'AppWriteService.dart';
import 'ManageUsersScreen.dart';
import 'ManageQrScreen.dart';
import 'ManageWithdrawals.dart';
import 'TransactionPage.dart';
import 'TransactionsPageOld.dart';
import 'adminLoginPage.dart'; // Your login screen file

final appwrite = AppWriteService();

class DashboardScreen extends StatelessWidget {
  // final List<String> userLabels;
  final User user;

  const DashboardScreen({
    super.key,
    required this.user,
  });

  void _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await appwrite.account.deleteSession(sessionId: 'current');

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              (route) => false,
        );
      } on AppwriteException catch (e) {
        print(e.message ?? 'Logout failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Logout failed')),
        );
      } catch (e){
        print(e.toString() ?? 'Logout failed');
      }
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
          if (exitConfirmed) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // title: Text(userLabels.contains('admin') ?'Admin Dashboard' : 'Dashboard'),
          title: Text('${user.name}\'s Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  if(user.labels.contains('user') || user.labels.contains('admin'))
                  _buildDashboardButton(
                    context,
                    icon: Icons.person,
                    label: 'Manage Users',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
                      );
                    },
                  ),
                  if(user.labels.contains('qr') || user.labels.contains('admin'))
                    _buildDashboardButton(
                    context,
                    icon: Icons.qr_code,
                    label: 'Manage All QR Codes',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageQrScreen()),
                      );
                    },
                  ),

                  _buildDashboardButton(
                    context,
                    icon: Icons.qr_code,
                    label: 'My QR Codes',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageQrScreen(userMode: true,userModeUserid: user.$id)),
                      );
                    },
                  ),

                  if(user.labels.contains('transactions') || user.labels.contains('admin'))
                    _buildDashboardButton(
                    context,
                    icon: Icons.receipt_long,
                    label: 'View All Transactions',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TransactionPageNew()),
                      );
                    },
                  ),

                  _buildDashboardButton(
                    context,
                    icon: Icons.receipt_long,
                    label: 'View My Transactions',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TransactionPageNew(userMode: true,userModeUserid: user.$id,)),
                      );
                    },
                  ),

                  if(user.labels.contains('withdrawal') || user.labels.contains('admin'))
                    _buildDashboardButton(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'All Withdrawals',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageWithdrawals()),
                        // MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                      );
                    },
                  ),

                  _buildDashboardButton(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'My Withdrawals',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageWithdrawals(userMode: true, userModeUserid: user.$id,)),
                        // MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                      );
                    },
                  ),

                  if(user.labels.contains('payout') || user.labels.contains('admin'))
                    _buildDashboardButton(
                    context,
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context,
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(200, 60),
      ),
    );
  }

}
