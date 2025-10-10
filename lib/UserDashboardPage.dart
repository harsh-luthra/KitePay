import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppConstants.dart';
import 'AppWriteService.dart';
import 'models/AppUser.dart';

import 'package:http/http.dart' as http;

class UserDashboardPage extends StatefulWidget {
  final AppUser userMeta;
  const UserDashboardPage({super.key, required this.userMeta});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  late Future<UserDashboardData> _future;
  bool _refreshing = false;

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
        title: const Text('User Dashboard'),
        actions: [
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
            return const _UserDashboardSkeleton();
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  title: 'Overview',
                  children: [
                    _metricGrid([
                      _metric('Total Txns', data.totalTxCount, Icons.swap_horiz, Colors.indigo),
                      _money('Total Pay-In', data.totalAmountPayIn, Icons.account_balance_wallet, Colors.teal),
                      _metric('Total QRs', data.totalQrs, Icons.qr_code_2, Colors.blueGrey),
                    ]),
                  ],
                ),
                _Section(
                  title: 'QR Status',
                  children: [
                    _metricGrid([
                      _metric('QRs Active', data.qrCodesActive, Icons.check_circle, Colors.green.shade700),
                      _metric('QRs Disabled', data.qrCodesDisabled, Icons.disabled_by_default, Colors.red.shade700),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Payouts',
                  children: [
                    _metricGrid([
                      _money('Available Amount', data.totalAvailableAmount, Icons.account_balance, Colors.green),
                      _money('On Hold', data.totalAmountOnHold, Icons.lock_clock_outlined, Colors.deepOrange),
                      _money('Approved Withdrawals', data.totalWithdrawalApprovedAmount, Icons.outbox, Colors.blue),
                      _money('Pending Withdrawals', data.totalWithdrawalPendingAmount, Icons.pending_actions, Colors.orange),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Commission',
                  children: [
                    _metricGrid([
                      _money('Commission On Hold', data.totalCommissionOnHold, Icons.savings_outlined, Colors.purple),
                      _money('Commission Paid', data.totalCommissionPaid, Icons.payments, Colors.purpleAccent),
                    ]),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== Metric widgets =====

  Widget _metricGrid(List<Widget> items) {
    return LayoutBuilder(builder: (ctx, cts) {
      final w = cts.maxWidth;
      final cross = w > 1400 ? 5 : w > 1100 ? 4 : w > 800 ? 3 : w > 520 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cross,
        mainAxisSpacing: 8,       // was 12
        crossAxisSpacing: 8,      // was 12
        childAspectRatio: 3.4,    // was 2.6
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: items,
      );
    });
  }

  Widget _metric(String title, int value, IconData icon, Color color) {
    return _metricCard(
      title: title,
      leading: Icon(icon, color: color),
      value: NumberFormat.compact().format(value),
      color: color,
    );
  }

  Widget _money(String title, int paise, IconData icon, Color color) {
    final rupees = paise / 100.0;
    final formatted = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(rupees);
    return _metricCard(title: title, leading: Icon(icon, color: color), value: formatted, color: color);
  }

  Widget _moneyPair(String title, int count, int paise, Color color, IconData icon) {
    final rupees = paise / 100.0;
    final amt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(rupees);
    return _metricCard(
      title: title,
      leading: Icon(icon, color: color),
      value: '$count • $amt',
      color: color,
    );
  }

  Widget _metricCard({
    required String title,
    required Widget leading,
    required String value,
    required Color color,
  }) {
    return Tooltip(
      message: title,
      child: Container(
        padding: const EdgeInsets.all(8), // was 12
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10), // was 12
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,             // was 38
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: IconTheme(                     // smaller icon
                data: IconThemeData(size: 18, color: color),
                child: leading,
              ),
            ),
            const SizedBox(width: 8),              // was 12
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.black54), // was 12
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), // was 6
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), // was 18
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10), // was 14
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), // was 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.dashboard_customize, size: 16, color: Colors.blueGrey), // was 18
              const SizedBox(width: 6), // was 8
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), // smaller
            ]),
            const SizedBox(height: 8), // was 12
            ...children,
          ],
        ),
      ),
    );
  }
}


class _UserDashboardSkeleton extends StatelessWidget {
  const _UserDashboardSkeleton();
  @override
  Widget build(BuildContext context) {
    // Similar to _SubadminDashboardSkeleton
    return const Center(child: CircularProgressIndicator());
  }
}

class UserDashboardData {
  // QR breakdown
  final int totalQrs;
  final int qrCodesActive;
  final int qrCodesDisabled;

  // Transactions
  final int totalTxCount;       // sum of qr.totalTransactions
  final int totalAmountPayIn;   // sum of qr.totalPayInAmount (paise)

  // Payouts
  final int totalWithdrawalApprovedAmount; // sum of qr.withdrawalApprovedAmount (paise)
  final int totalWithdrawalPendingAmount;  // sum of qr.withdrawalRequestedAmount (paise)
  final int totalAvailableAmount;          // sum of qr.amountAvailableForWithdrawal (paise)
  final int totalAmountOnHold;             // sum of qr.amountOnHold (paise)

  // Commission
  final int totalCommissionOnHold; // sum of qr.commissionOnHold (paise)
  final int totalCommissionPaid;   // sum of qr.commissionPaid (paise)

  const UserDashboardData({
    required this.totalQrs,
    required this.qrCodesActive,
    required this.qrCodesDisabled,
    required this.totalTxCount,
    required this.totalAmountPayIn,
    required this.totalWithdrawalApprovedAmount,
    required this.totalWithdrawalPendingAmount,
    required this.totalAvailableAmount,
    required this.totalAmountOnHold,
    required this.totalCommissionOnHold,
    required this.totalCommissionPaid,
  });

  factory UserDashboardData.fromJson(Map<String, dynamic> j) => UserDashboardData(
    totalQrs: j['totalQrs'] ?? 0,
    qrCodesActive: j['qrCodesActive'] ?? 0,
    qrCodesDisabled: j['qrCodesDisabled'] ?? 0,
    totalTxCount: j['totalTxCount'] ?? 0,
    totalAmountPayIn: j['totalAmountPayIn'] ?? 0,
    totalWithdrawalApprovedAmount: j['totalWithdrawalApprovedAmount'] ?? 0,
    totalWithdrawalPendingAmount: j['totalWithdrawalPendingAmount'] ?? 0,
    totalAvailableAmount: j['totalAvailableAmount'] ?? 0,
    totalAmountOnHold: j['totalAmountOnHold'] ?? 0,
    totalCommissionOnHold: j['totalCommissionOnHold'] ?? 0,
    totalCommissionPaid: j['totalCommissionPaid'] ?? 0,
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
    'qrCodesActive': raw['qrCodesActive'] ?? 0,
    'qrCodesDisabled': raw['qrCodesDisabled'] ?? 0,
    'totalTxCount': raw['totalTxCount'] ?? 0,
    'totalAmountPayIn': raw['totalAmountPayIn'] ?? 0,
    'totalWithdrawalApprovedAmount': raw['totalWithdrawalApprovedAmount'] ?? 0,
    'totalWithdrawalPendingAmount': raw['totalWithdrawalPendingAmount'] ?? 0,
    'totalAvailableAmount': raw['totalAvailableAmount'] ?? 0,
    'totalAmountOnHold': raw['totalAmountOnHold'] ?? 0,
    'totalCommissionOnHold': raw['totalCommissionOnHold'] ?? 0,
    'totalCommissionPaid': raw['totalCommissionPaid'] ?? 0,
  };
  return UserDashboardData.fromJson(normalized);
}
