import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<DashboardData> _future;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _future = fetchDashboard();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final data = await fetchDashboard(force: true);
      if (mounted) {
        setState(() => _future = Future.value(data));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _refreshing ? const CircularProgressIndicator(strokeWidth: 2) : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _DashboardSkeleton();
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
                      _metric('Total Transactions', data.totalTxCount, Icons.swap_horiz, Colors.indigo),
                      _money('Total Received', data.totalAmountReceived, Icons.account_balance_wallet, Colors.teal),
                      _money('Admin Profit', data.totalAdminProfit, Icons.leaderboard, Colors.deepPurple),
                      _money('Merchant Profit', data.totalMerchantProfit, Icons.wallet, Colors.orange),
                      _metric('QR Codes Uploaded', data.totalQrsUploaded, Icons.qr_code_2, Colors.blueGrey),
                      _metric('QRs Assigned to Merchant', data.totalQrsAssignedToMerchant, Icons.assignment_ind, Colors.cyan),
                    ]),
                  ],
                ),
                _Section(
                  title: 'QR Breakdown',
                  children: [
                    _metricGrid([
                      _metric('Pinelab QRs', data.totalPinelabQrs, Icons.qr_code_scanner, Colors.green),
                      _metric('Paytm QRs', data.totalPaytmQrs, Icons.qr_code_scanner, Colors.blue),
                      _metric('Other QRs', data.totalOtherQrs, Icons.qr_code_scanner, Colors.grey),
                      _metric('QRs Active', data.qrCodesActive, Icons.check_circle, Colors.green.shade700),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Transaction Types',
                  children: [
                    _metricGrid([
                      _metric('Manual Txns', data.totalManualTx, Icons.edit_note, Colors.amber.shade800),
                      _metric('API Txns', data.totalApiTx, Icons.cloud_done, Colors.lightBlue),
                      _moneyPair('Chargebacks', data.chargebackCount, data.chargebackAmount, Colors.red.shade600, Icons.report),
                      _moneyPair('Cyber', data.cyberCount, data.cyberAmount, Colors.pink.shade600, Icons.warning_amber),
                      _moneyPair('Refunds', data.refundCount, data.refundAmount, Colors.orange.shade700, Icons.undo),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Payouts',
                  children: [
                    _metricGrid([
                      _money('Amount Paid', data.totalAmountPaid, Icons.outbox, Colors.green),
                      _money('Pending Withdrawals', data.totalWithdrawalPendingAmount, Icons.pending_actions, Colors.deepOrange),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Users & Merchants',
                  children: [
                    _metricGrid([
                      _metric('Active Users', data.activeUsers, Icons.people_alt, Colors.green),
                      _metric('Disabled Users', data.disabledUsers, Icons.person_off, Colors.red),
                      _metric('Merchant Active', data.merchantActive, Icons.store, Colors.teal),
                      _metric('Merchant Pending', data.merchantPending, Icons.hourglass_bottom, Colors.amber),
                      _metric('Merchant Disabled', data.merchantDisabled, Icons.storefront_outlined, Colors.red.shade700),
                      _metric('Total Users', data.totalUsers, Icons.groups_2, Colors.indigo),
                    ]),
                  ],
                ),
                _Section(
                  title: 'Memberships',
                  children: [
                    _metricGrid([
                      _metric('Plans Purchased', data.totalMembershipPurchased, Icons.card_membership, Colors.purple),
                      _metric('Pending Membership Users', data.pendingMembershipUsers, Icons.person_add, Colors.blueGrey),
                    ]),
                  ],
                ),
                const SizedBox(height: 24),
                // Footer last updated
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

// ===== Sections and skeleton =====

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

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget shimmerBox() => Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...List.generate(4, (_) => Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: List.generate(4, (_) => shimmerBox()),
            ),
          ),
        )),
      ],
    );
  }
}

// ===== Data model + API (mock now) =====

class DashboardData {
  // Overview
  final int totalTxCount;
  final int totalAmountReceived;
  final int totalAdminProfit;
  final int totalMerchantProfit;
  final int totalQrsUploaded;
  final int totalQrsAssignedToMerchant;

  // QR breakdown
  final int totalPinelabQrs;
  final int totalPaytmQrs;
  final int totalOtherQrs;
  final int qrCodesActive;

  // Transaction types
  final int totalManualTx;
  final int totalApiTx;
  final int chargebackCount;
  final int chargebackAmount;
  final int cyberCount;
  final int cyberAmount;
  final int refundCount;
  final int refundAmount;

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
    required this.totalAdminProfit,
    required this.totalMerchantProfit,
    required this.totalQrsUploaded,
    required this.totalQrsAssignedToMerchant,
    required this.totalPinelabQrs,
    required this.totalPaytmQrs,
    required this.totalOtherQrs,
    required this.qrCodesActive,
    required this.totalManualTx,
    required this.totalApiTx,
    required this.chargebackCount,
    required this.chargebackAmount,
    required this.cyberCount,
    required this.cyberAmount,
    required this.refundCount,
    required this.refundAmount,
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
      totalAdminProfit: j['totalAdminProfit'],
      totalMerchantProfit: j['totalMerchantProfit'],
      totalQrsUploaded: j['totalQrsUploaded'],
      totalQrsAssignedToMerchant: j['totalQrsAssignedToMerchant'],
      totalPinelabQrs: j['totalPinelabQrs'],
      totalPaytmQrs: j['totalPaytmQrs'],
      totalOtherQrs: j['totalOtherQrs'],
      qrCodesActive: j['qrCodesActive'],
      totalManualTx: j['totalManualTx'],
      totalApiTx: j['totalApiTx'],
      chargebackCount: j['chargebackCount'],
      chargebackAmount: j['chargebackAmount'],
      cyberCount: j['cyberCount'],
      cyberAmount: j['cyberAmount'],
      refundCount: j['refundCount'],
      refundAmount: j['refundAmount'],
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

// Change this to your real endpoint later
Future<DashboardData> fetchDashboard({bool force = false}) async {
  await Future.delayed(const Duration(milliseconds: 450)); // simulate latency

  // TODO: Switch to real API
  // final jwt = await AppWriteService.instance.getJwt();
  // final resp = await http.get(
  //   Uri.parse('${AppConstants.baseUrl}/admin/dashboard/summary'),
  //   headers: {'Authorization': 'Bearer $jwt'},
  // );
  // if (resp.statusCode != 200) throw Exception(resp.body);
  // final jsonMap = json.decode(resp.body) as Map<String, dynamic>;
  // return DashboardData.fromJson(jsonMap);

  // Dummy data (paise for money fields)
  return DashboardData(
    totalTxCount: 128_540,
    totalAmountReceived: 45_75_34_550,       // ₹4,57,53,455.50
    totalAdminProfit: 1_84_55_430,           // ₹18,455,430.00
    totalMerchantProfit: 2_42_11_220,        // ₹24,211,220.00
    totalQrsUploaded: 9_842,
    totalQrsAssignedToMerchant: 8_130,
    totalPinelabQrs: 3_420,
    totalPaytmQrs: 4_100,
    totalOtherQrs: 2_322,
    qrCodesActive: 7_950,
    totalManualTx: 18_250,
    totalApiTx: 110_290,
    chargebackCount: 320,
    chargebackAmount: 12_45_600,
    cyberCount: 210,
    cyberAmount: 8_75_900,
    refundCount: 1_120,
    refundAmount: 23_40_000,
    totalAmountPaid: 29_11_400,
    totalWithdrawalPendingAmount: 7_65_800,
    activeUsers: 15_420,
    disabledUsers: 420,
    merchantActive: 2_310,
    merchantPending: 185,
    merchantDisabled: 160,
    totalUsers: 18_500,
    totalMembershipPurchased: 1_240,
    pendingMembershipUsers: 95,
  );
}
