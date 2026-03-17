import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'AppConstants.dart';
import 'AppWriteService.dart';
import 'utils/app_spacing.dart';
import 'widget/dashboard_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<DashboardData> _future;
  bool _refreshing = false;
  bool _showFullNumbers = false;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = fetchDashboard();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    try {
      final data = await fetchDashboard(force: true);
      if (!mounted) return;
      setState(() {
        _future = Future.value(data);
        _refreshing = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _future = Future.error(e);
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: _showFullNumbers ? 'Show compact numbers' : 'Show full numbers',
            icon: Icon(_showFullNumbers ? Icons.filter_9_plus : Icons.filter_list),
            onPressed: () => setState(() => _showFullNumbers = !_showFullNumbers),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: _refreshing
                ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
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
                      DashboardMetricCard.count(title: 'Total Transactions', value: data.totalTxCount, icon: Icons.swap_horiz, color: Colors.indigo, showFull: sf),
                      DashboardMetricCard.money(title: 'Total Pay-In', paise: data.totalAmountReceived, icon: Icons.account_balance_wallet, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.money(title: 'Today Pay-In', paise: data.todayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Yesterday Pay-In', paise: data.yesterdayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Admin Profit', paise: data.totalAdminProfit, icon: Icons.leaderboard, color: Colors.deepPurple, showFull: sf),
                      DashboardMetricCard.money(title: 'Merchant Profit', paise: data.totalMerchantProfit, icon: Icons.wallet, color: Colors.orange, showFull: sf),
                      DashboardMetricCard.count(title: 'QR Codes Uploaded', value: data.totalQrsUploaded, icon: Icons.qr_code_2, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.count(title: 'QRs Assigned to Merchant', value: data.totalQrsAssignedToMerchant, icon: Icons.assignment_ind, color: Colors.cyan, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'QR Breakdown',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Pine-labs QRs', value: data.totalPinelabsQrs, icon: Icons.qr_code_scanner, color: Colors.green, showFull: sf),
                      DashboardMetricCard.count(title: 'Paytm QRs', value: data.totalPaytmQrs, icon: Icons.qr_code_scanner, color: Colors.blue, showFull: sf),
                      DashboardMetricCard.count(title: 'Other QRs', value: data.totalOtherQrs, icon: Icons.qr_code_scanner, color: Colors.grey, showFull: sf),
                      DashboardMetricCard.count(title: 'QRs Active', value: data.qrCodesActive, icon: Icons.check_circle, color: Colors.green.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'QRs Disabled', value: data.qrCodesDisabled, icon: Icons.disabled_by_default, color: Colors.red.shade700, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Transaction Types',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Manual Txns', value: data.totalManualTx, icon: Icons.edit_note, color: Colors.amber.shade800, showFull: sf),
                      DashboardMetricCard.count(title: 'API Txns', value: data.totalApiTx, icon: Icons.cloud_done, color: Colors.lightBlue, showFull: sf),
                      DashboardMetricCard.moneyPair(title: 'Chargebacks', count: data.chargebackCount, paise: data.chargebackAmount, icon: Icons.report, color: Colors.red.shade600, showFull: sf),
                      DashboardMetricCard.moneyPair(title: 'Cyber', count: data.cyberCount, paise: data.cyberAmount, icon: Icons.warning_amber, color: Colors.pink.shade600, showFull: sf),
                      DashboardMetricCard.moneyPair(title: 'Refunds', count: data.refundCount, paise: data.refundAmount, icon: Icons.undo, color: Colors.orange.shade700, showFull: sf),
                      DashboardMetricCard.moneyPair(title: 'Failed', count: data.failedCount, paise: data.failedAmount, icon: Icons.cancel_outlined, color: Colors.grey.shade700, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Payouts',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'Amount Paid', paise: data.totalAmountPaid, icon: Icons.outbox, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'Pending Withdrawals', paise: data.totalWithdrawalPendingAmount, icon: Icons.pending_actions, color: Colors.deepOrange, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Users & Merchants',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Active Users', value: data.activeUsers, icon: Icons.people_alt, color: Colors.green, showFull: sf),
                      DashboardMetricCard.count(title: 'Disabled Users', value: data.disabledUsers, icon: Icons.person_off, color: Colors.red, showFull: sf),
                      DashboardMetricCard.count(title: 'Merchant Active', value: data.merchantActive, icon: Icons.store, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.count(title: 'Merchant Pending', value: data.merchantPending, icon: Icons.hourglass_bottom, color: Colors.amber, showFull: sf),
                      DashboardMetricCard.count(title: 'Merchant Disabled', value: data.merchantDisabled, icon: Icons.storefront_outlined, color: Colors.red.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'Total Users', value: data.totalUsers, icon: Icons.groups_2, color: Colors.indigo, showFull: sf),
                    ]),
                  ],
                ),
                DashboardSection(
                  title: 'Memberships',
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Plans Purchased', value: data.totalMembershipPurchased, icon: Icons.card_membership, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.count(title: 'Pending Membership Users', value: data.pendingMembershipUsers, icon: Icons.person_add, color: Colors.blueGrey, showFull: sf),
                    ]),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastUpdated)}',
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


// ===== Data model + API (mock now) =====

class DashboardData {
  // Overview
  final int totalTxCount;
  final int totalAmountReceived;
  final int todayPayInAllQrs;
  final int yesterdayPayInAllQrs;
  final int totalAdminProfit;
  final int totalMerchantProfit;
  final int totalQrsUploaded;
  final int totalQrsAssignedToMerchant;

  // QR breakdown
  final int totalPinelabsQrs;
  final int totalPaytmQrs;
  final int totalOtherQrs;
  final int qrCodesActive;
  final int qrCodesDisabled;

  // Transaction types
  final int totalManualTx;
  final int totalApiTx;
  final int chargebackCount;
  final int chargebackAmount;
  final int cyberCount;
  final int cyberAmount;
  final int refundCount;
  final int refundAmount;
  final int failedCount;
  final int failedAmount;

  // Payouts
  final int totalAmountPaid;
  final int totalWithdrawalPendingAmount;

  // Users/Merchants
  final int activeUsers;
  final int disabledUsers;
  final int merchantActive;
  final int merchantPending;
  final int merchantDisabled;
  final int totalUsers;

  // Memberships
  final int totalMembershipPurchased;
  final int pendingMembershipUsers;

  const DashboardData({
    required this.totalTxCount,
    required this.totalAmountReceived,
    required this.todayPayInAllQrs,
    required this.yesterdayPayInAllQrs,
    required this.totalAdminProfit,
    required this.totalMerchantProfit,
    required this.totalQrsUploaded,
    required this.totalQrsAssignedToMerchant,
    required this.totalPinelabsQrs,
    required this.totalPaytmQrs,
    required this.totalOtherQrs,
    required this.qrCodesActive,
    required this.qrCodesDisabled,
    required this.totalManualTx,
    required this.totalApiTx,
    required this.chargebackCount,
    required this.chargebackAmount,
    required this.cyberCount,
    required this.cyberAmount,
    required this.refundCount,
    required this.refundAmount,
    required this.failedCount,
    required this.failedAmount,
    required this.totalAmountPaid,
    required this.totalWithdrawalPendingAmount,
    required this.activeUsers,
    required this.disabledUsers,
    required this.merchantActive,
    required this.merchantPending,
    required this.merchantDisabled,
    required this.totalUsers,
    required this.totalMembershipPurchased,
    required this.pendingMembershipUsers,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
      totalTxCount: j['totalTxCount'],
      totalAmountReceived: j['totalAmountReceived'],
      todayPayInAllQrs: j['todayPayInAllQrs'],
      yesterdayPayInAllQrs: j['yesterdayPayInAllQrs'],
      totalAdminProfit: j['totalAdminProfit'],
      totalMerchantProfit: j['totalMerchantProfit'],
      totalQrsUploaded: j['totalQrsUploaded'],
      totalQrsAssignedToMerchant: j['totalQrsAssignedToMerchant'],
      totalPinelabsQrs: j['totalPinelabsQrs'],
      totalPaytmQrs: j['totalPaytmQrs'],
      totalOtherQrs: j['totalOtherQrs'],
      qrCodesActive: j['qrCodesActive'],
      qrCodesDisabled : j['qrCodesDisabled'],
      totalManualTx: j['totalManualTx'],
      totalApiTx: j['totalApiTx'],
      chargebackCount: j['chargebackCount'],
      chargebackAmount: j['chargebackAmount'],
      cyberCount: j['cyberCount'],
      cyberAmount: j['cyberAmount'],
      refundCount: j['refundCount'],
      refundAmount: j['refundAmount'],
      failedCount: j['failedCount'],
      failedAmount: j['failedAmount'],
      totalAmountPaid: j['totalAmountPaid'],
      totalWithdrawalPendingAmount: j['totalWithdrawalPendingAmount'],
      activeUsers: j['activeUsers'],
      disabledUsers: j['disabledUsers'],
      merchantActive: j['merchantActive'],
      merchantPending: j['merchantPending'],
      merchantDisabled: j['merchantDisabled'],
      totalUsers: j['totalUsers'],
      totalMembershipPurchased: j['totalMembershipPurchased'],
      pendingMembershipUsers: j['pendingMembershipUsers'],
     );
}

Future<DashboardData> fetchDashboard({bool force = false}) async {
  final jwt = await AppWriteService().getJWT();
  final uri = Uri.parse('${AppConstants.baseApiUrl}/admin/dashboard/counters');
  final resp = await http.get(uri, headers: {'Authorization': 'Bearer $jwt', 'Accept': 'application/json'});

  if (resp.statusCode != 200) {
    throw Exception('Failed to fetch dashboard: ${resp.statusCode} ${resp.body}');
  }

  final raw = json.decode(resp.body) as Map<String, dynamic>;
  final data = {
    'totalTxCount': raw['totalTxCount'] ?? 0,
    'totalAmountReceived': raw['totalAmountReceived'] ?? 0,
    'todayPayInAllQrs': raw['todayPayInAllQrs'] ?? 0,
    'yesterdayPayInAllQrs': raw['yesterdayPayInAllQrs'] ?? 0,
    'totalAdminProfit': raw['totalAdminProfit'] ?? 0,
    'totalMerchantProfit': raw['totalMerchantProfit'] ?? 0,
    'totalQrsUploaded': raw['totalQrsUploaded'] ?? 0,
    'totalQrsAssignedToMerchant': raw['totalQrsAssignedToMerchant'] ?? 0,
    'totalPinelabsQrs': raw['totalPinelabsQrs'] ?? 0,
    'totalPaytmQrs': raw['totalPaytmQrs'] ?? 0,
    'totalOtherQrs': raw['totalOtherQrs'] ?? 0,
    'qrCodesActive': raw['qrCodesActive'] ?? 0,
    'qrCodesDisabled': raw['qrCodesDisabled'] ?? 0,
    'totalManualTx': raw['totalManualTx'] ?? 0,
    'totalApiTx': raw['totalApiTx'] ?? 0,
    'chargebackCount': raw['chargebackCount'] ?? 0,
    'chargebackAmount': raw['chargebackAmount'] ?? 0,
    'cyberCount': raw['cyberCount'] ?? 0,
    'cyberAmount': raw['cyberAmount'] ?? 0,
    'refundCount': raw['refundCount'] ?? 0,
    'refundAmount': raw['refundAmount'] ?? 0,
    'failedCount': raw['failedCount'] ?? 0,
    'failedAmount': raw['failedAmount'] ?? 0,
    'totalAmountPaid': raw['totalAmountPaid'] ?? 0,
    'totalWithdrawalPendingAmount': raw['totalWithdrawalPendingAmount'] ?? 0,
    'activeUsers': raw['activeUsers'] ?? 0,
    'disabledUsers': raw['disabledUsers'] ?? 0,
    'merchantActive': raw['merchantActive'] ?? 0,
    'merchantPending': raw['merchantPending'] ?? 0,
    'merchantDisabled': raw['merchantDisabled'] ?? 0,
    'totalUsers': raw['totalUsers'] ?? 0,
    'totalMembershipPurchased': raw['totalMembershipPurchased'] ?? 0,
    'pendingMembershipUsers': raw['pendingMembershipUsers'] ?? 0,
  };

  return DashboardData.fromJson(data);
}
