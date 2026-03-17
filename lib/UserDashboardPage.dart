import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppConstants.dart';
import 'AppWriteService.dart';
import 'models/AppUser.dart';
import 'utils/app_spacing.dart';
import 'widget/dashboard_widgets.dart';

import 'package:http/http.dart' as http;

class UserDashboardPage extends StatefulWidget {
  final AppUser userMeta;
  final bool showUserTitle;

  const UserDashboardPage({super.key, required this.userMeta, required this.showUserTitle});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  late Future<UserDashboardData> _future;
  bool _refreshing = false;
  bool _showFullNumbers = false;

  @override
  void initState() {
    super.initState();
    _future = fetchUserDashboard(userId: widget.userMeta.id);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final data = await fetchUserDashboard(userId: widget.userMeta.id);
      if (!mounted) return;
      setState(() {
        _future = Future.value(data);
        _refreshing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showUserTitle ? 'User Dashboard - ${widget.userMeta.email}' : 'User Dashboard'),
        actions: [
          IconButton(
            tooltip: _showFullNumbers ? 'Show compact numbers' : 'Show full numbers',
            icon: Icon(_showFullNumbers ? Icons.filter_9_plus : Icons.filter_list),
            onPressed: () => setState(() => _showFullNumbers = !_showFullNumbers),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: _refreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : () { _refresh(); },
          ),
        ],
      ),
      body: FutureBuilder<UserDashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const DashboardSkeleton(sectionCount: 4);
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text('Failed to load: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final data = snap.data!;
          final sf = _showFullNumbers;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: AppSpacing.allLg,
              children: [
                DashboardSection(
                  title: 'Overview',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Total Txns', value: data.totalTxCount, icon: Icons.swap_horiz, color: Colors.indigo, showFull: sf),
                      DashboardMetricCard.money(title: 'Total Pay-In', paise: data.totalAmountPayIn, icon: Icons.account_balance_wallet, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.count(title: 'Total QRs', value: data.totalQrs, icon: Icons.qr_code_2, color: Colors.blueGrey, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'QR Status',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'QRs Active', value: data.qrCodesActive, icon: Icons.check_circle, color: Colors.green.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'QRs Disabled', value: data.qrCodesDisabled, icon: Icons.disabled_by_default, color: Colors.red.shade700, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Payouts',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'Today Available Amount', paise: data.totalAvailableAmount, icon: Icons.account_balance, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'Yesterday Pay-In', paise: data.yesterdayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Today Pay-In', paise: data.todayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Withdrawable Amount', paise: data.withdrawableAmount, icon: Icons.account_balance_wallet, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'On Hold', paise: data.totalAmountOnHold, icon: Icons.lock_clock_outlined, color: Colors.deepOrange, showFull: sf),
                      DashboardMetricCard.money(title: 'Approved Withdrawals', paise: data.totalWithdrawalApprovedAmount, icon: Icons.outbox, color: Colors.blue, showFull: sf),
                      DashboardMetricCard.money(title: 'Pending Withdrawals', paise: data.totalWithdrawalPendingAmount, icon: Icons.pending_actions, color: Colors.orange, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Commission',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'Commission On Hold', paise: data.totalCommissionOnHold, icon: Icons.savings_outlined, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.money(title: 'Commission Paid', paise: data.totalCommissionPaid, icon: Icons.payments, color: Colors.purpleAccent, showFull: sf),
                    ]),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(data.fetchedAt)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}


class UserDashboardData {
  final int totalQrs;
  final int todayPayInAllQrs;
  final int yesterdayPayInAllQrs;
  final int qrCodesActive;
  final int qrCodesDisabled;
  final int totalTxCount;
  final int totalAmountPayIn;
  final int totalWithdrawalApprovedAmount;
  final int totalWithdrawalPendingAmount;
  final int totalAvailableAmount;
  final int withdrawableAmount;
  final int totalAmountOnHold;
  final int totalCommissionOnHold;
  final int totalCommissionPaid;

  // Meta
  final DateTime fetchedAt;

  const UserDashboardData({
    required this.totalQrs,
    required this.todayPayInAllQrs,
    required this.yesterdayPayInAllQrs,
    required this.qrCodesActive,
    required this.qrCodesDisabled,
    required this.totalTxCount,
    required this.totalAmountPayIn,
    required this.totalWithdrawalApprovedAmount,
    required this.totalWithdrawalPendingAmount,
    required this.totalAvailableAmount,
    required this.withdrawableAmount,
    required this.totalAmountOnHold,
    required this.totalCommissionOnHold,
    required this.totalCommissionPaid,
    required this.fetchedAt,
  });

  factory UserDashboardData.fromJson(Map<String, dynamic> j) => UserDashboardData(
    totalQrs: j['totalQrs'] ?? 0,
    todayPayInAllQrs: j['todayPayInAllQrs'] ?? 0,
    yesterdayPayInAllQrs: j['yesterdayPayInAllQrs'] ?? 0,
    qrCodesActive: j['qrCodesActive'] ?? 0,
    qrCodesDisabled: j['qrCodesDisabled'] ?? 0,
    totalTxCount: j['totalTxCount'] ?? 0,
    totalAmountPayIn: j['totalAmountPayIn'] ?? 0,
    withdrawableAmount: j['withdrawableAmount'] ?? 0,
    totalWithdrawalApprovedAmount: j['totalWithdrawalApprovedAmount'] ?? 0,
    totalWithdrawalPendingAmount: j['totalWithdrawalPendingAmount'] ?? 0,
    totalAvailableAmount: j['totalAvailableAmount'] ?? 0,
    totalAmountOnHold: j['totalAmountOnHold'] ?? 0,
    totalCommissionOnHold: j['totalCommissionOnHold'] ?? 0,
    totalCommissionPaid: j['totalCommissionPaid'] ?? 0,
    fetchedAt: DateTime.now(),
  );
}

Future<UserDashboardData> fetchUserDashboard({required String userId}) async {
  final jwt = await AppWriteService().getJWT();
  final uri = Uri.parse('${AppConstants.baseApiUrl}/admin/dashboard/user/$userId');
  final resp = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $jwt', 'Accept': 'application/json'},
  );
  if (resp.statusCode != 200) {
    throw Exception('Failed to fetch user dashboard: ${resp.statusCode} ${resp.body}');
  }
  final Map<String, dynamic> raw = json.decode(resp.body) as Map<String, dynamic>;
  // Normalize nulls
  final normalized = <String, dynamic>{
    'totalQrs': raw['totalQrs'] ?? 0,
    'todayPayInAllQrs': raw['todayPayInAllQrs'] ?? 0,
    'yesterdayPayInAllQrs': raw['yesterdayPayInAllQrs'] ?? 0,
    'qrCodesActive': raw['qrCodesActive'] ?? 0,
    'qrCodesDisabled': raw['qrCodesDisabled'] ?? 0,
    'totalTxCount': raw['totalTxCount'] ?? 0,
    'totalAmountPayIn': raw['totalAmountPayIn'] ?? 0,
    'totalWithdrawalApprovedAmount': raw['totalWithdrawalApprovedAmount'] ?? 0,
    'totalWithdrawalPendingAmount': raw['totalWithdrawalPendingAmount'] ?? 0,
    'totalAvailableAmount': raw['totalAvailableAmount'] ?? 0,
    'withdrawableAmount': raw['withdrawableAmount'] ?? 0,
    'totalAmountOnHold': raw['totalAmountOnHold'] ?? 0,
    'totalCommissionOnHold': raw['totalCommissionOnHold'] ?? 0,
    'totalCommissionPaid': raw['totalCommissionPaid'] ?? 0,
  };

  return UserDashboardData.fromJson(normalized);
}
