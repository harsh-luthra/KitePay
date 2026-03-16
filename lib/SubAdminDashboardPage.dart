import 'dart:async';
import 'dart:convert';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'AppConstants.dart';
import 'AppWriteService.dart';

class SubAdminDashboardPage extends StatefulWidget {
  final AppUser userMeta;
  final bool showUserTitle;

  const SubAdminDashboardPage({super.key, required this.userMeta, required this.showUserTitle});

  @override
  State<SubAdminDashboardPage> createState() => _SubAdminDashboardPageState();
}

class _SubAdminDashboardPageState extends State<SubAdminDashboardPage> {
  late Future<SubAdminDashboardData> _future;
  bool _refreshing = false;
  bool _showFullNumbers = false;

  @override
  void initState() {
    super.initState();
    _future = fetchSubadminDashboard(merchantId: widget.userMeta.id);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final data = await fetchSubadminDashboard(force: true, merchantId: widget.userMeta.id);
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
        title: Text(widget.showUserTitle
            ? 'Merchant Dashboard - ${widget.userMeta.email}'
            : 'Merchant Dashboard'),
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
            onPressed: _refreshing ? null : () { _refresh(); },
          ),
        ],
      ),
      body: FutureBuilder<SubAdminDashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _SubadminDashboardSkeleton();
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

                // ════════════════════════════════════════════════════════════
                // 1. ALL MANAGED QRs  (indigo)
                // ════════════════════════════════════════════════════════════
                _SectionHeader(label: 'Managed QRs', color: Colors.indigo),

                _Section(
                  title: 'All Managed QR — Overview',
                  accentColor: Colors.indigo,
                  children: [
                    _metricGrid([
                      _metric('Total QRs Assigned', data.totalQrsAssignedToMerchant, Icons.assignment_ind, Colors.indigo),
                      _metric('Total Transactions', data.totalTxCount, Icons.swap_horiz, Colors.indigo.shade300),
                      _money('Total Pay-In', data.totalAmountReceived, Icons.account_balance_wallet, Colors.teal),
                    ]),
                  ],
                ),

                _Section(
                  title: 'All Managed QR — Payouts',
                  accentColor: Colors.indigo,
                  children: [
                    _metricGrid([
                      _money('Amount Paid', data.totalAmountPaid, Icons.outbox, Colors.green),
                      _money('Pending Withdrawals', data.totalWithdrawalPendingAmount, Icons.pending_actions, Colors.deepOrange),
                      _money('Total Available Amount', data.totalAvailableAmount, Icons.account_balance, Colors.teal),
                      _money('Today Pay-In', data.todayPayInAllQrs, Icons.today_rounded, Colors.blueGrey),
                      _money('Withdrawable Amount', data.withdrawableAmount, Icons.savings, Colors.cyan.shade700),
                      _money('Amount On Hold', data.totalAmountOnHold, Icons.lock_clock_outlined, Colors.deepOrangeAccent),
                      _money('Commission On Hold', data.totalCommissionOnHold, Icons.savings_outlined, Colors.purple),
                      _money('Commission Paid', data.totalCommissionPaid, Icons.payments, Colors.purpleAccent),
                    ]),
                  ],
                ),

                _Section(
                  title: 'All Managed QR — Breakdown',
                  accentColor: Colors.indigo,
                  children: [
                    _metricGrid([
                      _metric('QRs Active', data.qrCodesActive, Icons.check_circle, Colors.green.shade700),
                      _metric('QRs Disabled', data.qrCodesDisabled, Icons.disabled_by_default, Colors.red.shade700),
                    ]),
                  ],
                ),

                const SizedBox(height: 6),

                // ════════════════════════════════════════════════════════════
                // 2. ALL SELF ASSIGNED QRs  (purple)
                // ════════════════════════════════════════════════════════════
                _SectionHeader(label: 'Self Assigned QRs', color: Colors.purple),

                _Section(
                  title: 'Self Assigned QR — Overview',
                  accentColor: Colors.purple,
                  children: [
                    _metricGrid([
                      _metric('Self Total QRs', data.totalSelfAssignedQrs, Icons.qr_code, Colors.purple),
                      _metric('Self Transactions', data.selfTotalTxCount, Icons.swap_horiz, Colors.purple.shade300),
                      _money('Self Total Pay-In', data.selfTotalAmountReceived, Icons.account_balance_wallet, Colors.teal),
                    ]),
                  ],
                ),

                _Section(
                  title: 'Self Assigned QR — Payouts',
                  accentColor: Colors.purple,
                  children: [
                    _metricGrid([
                      _money('Self Amount Paid', data.selfTotalAmountPaid, Icons.outbox, Colors.green),
                      _money('Self Pending Withdrawals', data.selfTotalWithdrawalPendingAmount, Icons.pending_actions, Colors.deepOrange),
                      _money('Self Total Available Amount', data.selfTotalAvailableAmount, Icons.account_balance, Colors.teal),
                      _money('Self Today Pay-In', data.todayPayInSelfAssignedQrs, Icons.today_rounded, Colors.blueGrey),
                      _money('Self Withdrawable Amount', data.selfWithdrawableAmount, Icons.savings, Colors.cyan.shade700),
                      _money('Self Amount On Hold', data.selfTotalAmountOnHold, Icons.lock_clock_outlined, Colors.deepOrangeAccent),
                      _money('Self Commission On Hold', data.selfTotalCommissionOnHold, Icons.savings_outlined, Colors.purple),
                      _money('Self Commission Paid', data.selfTotalAmountPaid, Icons.payments, Colors.purpleAccent),
                    ]),
                  ],
                ),

                _Section(
                  title: 'Self Assigned QR — Breakdown',
                  accentColor: Colors.purple,
                  children: [
                    _metricGrid([
                      _metric('Self QRs Active', data.selfQrCodesActive, Icons.check_circle, Colors.green.shade700),
                      _metric('Self QRs Disabled', data.selfQrCodesDisabled, Icons.disabled_by_default, Colors.red.shade700),
                    ]),
                  ],
                ),

                const SizedBox(height: 6),

                // ════════════════════════════════════════════════════════════
                // 3. ALL USER ASSIGNED QRs  (teal)
                // ════════════════════════════════════════════════════════════
                _SectionHeader(label: 'User Assigned QRs', color: Colors.teal),

                _Section(
                  title: 'User Assigned QR — Overview',
                  accentColor: Colors.purple,
                  children: [
                    _metricGrid([
                      _metric('User Total QRs', data.totalUserAssignedQrs, Icons.qr_code, Colors.purple),
                      _metric('User Transactions', data.userTotalTxCount, Icons.swap_horiz, Colors.purple.shade300),
                      _money('User Total Pay-In', data.userTotalAmountReceived, Icons.account_balance_wallet, Colors.teal),
                    ]),
                  ],
                ),

                _Section(
                  title: 'User Assigned QR — Payouts',
                  accentColor: Colors.teal,
                  children: [
                    _metricGrid([
                      _money('User Amount Paid', data.userTotalAmountPaid, Icons.outbox, Colors.green),
                      _money('User Pending Withdrawals', data.userTotalWithdrawalPendingAmount, Icons.pending_actions, Colors.deepOrange),
                      _money('User Total Available Amount', data.userTotalAvailableAmount, Icons.account_balance, Colors.teal),
                      _money('User Today Pay-In', data.todayPayInUserAssignedQrs, Icons.today_rounded, Colors.blueGrey),
                      _money('User Withdrawable Amount', data.userWithdrawableAmount, Icons.savings, Colors.cyan.shade700),
                      _money('User Amount On Hold', data.userTotalAmountOnHold, Icons.lock_clock_outlined, Colors.deepOrangeAccent),
                      _money('User Commission On Hold', data.userTotalCommissionOnHold, Icons.savings_outlined, Colors.purple),
                      _money('User Commission Paid', data.userTotalCommissionPaid, Icons.payments, Colors.purpleAccent),
                    ]),
                  ],
                ),

                const SizedBox(height: 6),

                _Section(
                  title: 'User Assigned QR — Breakdown',
                  accentColor: Colors.teal,
                  children: [
                    _metricGrid([
                      _metric('User QRs Active', data.userQrCodesActive, Icons.check_circle, Colors.green.shade700),
                      _metric('User QRs Disabled', data.userQrCodesDisabled, Icons.disabled_by_default, Colors.red.shade700),
                    ]),
                  ],
                ),

                // ════════════════════════════════════════════════════════════
                // 4. OTHER
                // ════════════════════════════════════════════════════════════
                // _Section(
                //   title: 'Merchant Profit',
                //   children: [
                //     _metricGrid([
                //       _money('Total Merchant Profit', data.totalMerchantProfit, Icons.wallet, Colors.orange),
                //     ]),
                //   ],
                // ),

                // _Section(
                //   title: 'Users & Merchants',
                //   children: [
                //     _metricGrid([
                //       _metric('Active Users', data.activeUsers, Icons.people_alt, Colors.green),
                //       _metric('Disabled Users', data.disabledUsers, Icons.person_off, Colors.red),
                //       _metric('Total Users', data.totalUsers, Icons.groups_2, Colors.indigo),
                //     ]),
                //   ],
                // ),
                //
                // _Section(
                //   title: 'Memberships',
                //   children: [
                //     _metricGrid([
                //       _metric('Plans Purchased', data.totalMembershipPurchased, Icons.card_membership, Colors.purple),
                //       _metric('Pending Membership Users', data.pendingMembershipUsers, Icons.person_add, Colors.blueGrey),
                //     ]),
                //   ],
                // ),

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
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.4,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: items,
      );
    });
  }

  Widget _metric(String title, int value, IconData icon, Color color) =>
      _metricCard(title: title, leading: Icon(icon, color: color), value: formatCount(value), color: color);

  Widget _money(String title, int paise, IconData icon, Color color) =>
      _metricCard(title: title, leading: Icon(icon, color: color), value: formatMoneyPaise(paise), color: color);

  Widget _metricCard({
    required String title,
    required Widget leading,
    required String value,
    required Color color,
  }) {
    return Tooltip(
      message: title,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: IconThemeData(size: 18, color: color),
                child: leading,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  String formatCount(num value) {
    if (_showFullNumbers) return NumberFormat.decimalPattern('en_IN').format(value);
    return NumberFormat.compact(locale: 'en_IN').format(value);
  }

  String formatMoneyPaise(int paise) {
    final rupees = paise / 100.0;
    if (_showFullNumbers) {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
    }
    return NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(rupees);
  }
}

// ===== Section group header =====

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.25), thickness: 1)),
        ],
      ),
    );
  }
}

// ===== Section card =====

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accentColor;
  const _Section({required this.title, required this.children, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Colors.blueGrey;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.dashboard_customize, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: accentColor == null ? null : color,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ===== Skeleton =====

class _SubadminDashboardSkeleton extends StatelessWidget {
  const _SubadminDashboardSkeleton();

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
        ...List.generate(
          9,
              (_) => Card(
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
          ),
        ),
      ],
    );
  }
}

// ===== Data model =====

class SubAdminDashboardData {
  // ── Managed QRs ───────────────────────────────────────────────────────────
  final int totalQrsAssignedToMerchant;
  final int todayPayInAllQrs;
  final int totalTxCount;
  final int totalAmountReceived;
  final int totalAvailableAmount;
  final int withdrawableAmount;
  final int qrCodesActive;
  final int qrCodesDisabled;
  final int totalAmountPaid;
  final int totalWithdrawalPendingAmount;
  final int totalAmountOnHold;
  final int totalCommissionOnHold;
  final int totalCommissionPaid;

  // ── Self Assigned QRs ─────────────────────────────────────────────────────
  final int totalSelfAssignedQrs;
  final int todayPayInSelfAssignedQrs;
  final int selfTotalTxCount;
  final int selfTotalAmountReceived;
  final int selfTotalAvailableAmount;
  final int selfWithdrawableAmount;
  final int selfQrCodesActive;
  final int selfQrCodesDisabled;
  final int selfTotalAmountPaid;
  final int selfTotalWithdrawalPendingAmount;
  final int selfTotalAmountOnHold;
  final int selfTotalCommissionOnHold;
  final int selfTotalCommissionPaid;

  // ── User Assigned QRs ─────────────────────────────────────────────────────
  final int totalUserAssignedQrs;
  final int todayPayInUserAssignedQrs;
  final int userTotalTxCount;
  final int userTotalAmountReceived;
  final int userTotalAvailableAmount;
  final int userWithdrawableAmount;
  final int userQrCodesActive;
  final int userQrCodesDisabled;
  final int userTotalAmountPaid;
  final int userTotalWithdrawalPendingAmount;
  final int userTotalAmountOnHold;
  final int userTotalCommissionOnHold;
  final int userTotalCommissionPaid;

  // ── Other ─────────────────────────────────────────────────────────────────
  final int totalMerchantProfit;
  final int activeUsers;
  final int disabledUsers;
  final int totalUsers;
  final int totalMembershipPurchased;
  final int pendingMembershipUsers;

  const SubAdminDashboardData({
    required this.totalQrsAssignedToMerchant,
    required this.todayPayInAllQrs,
    required this.totalTxCount,
    required this.totalAmountReceived,
    required this.totalAvailableAmount,
    required this.withdrawableAmount,
    required this.qrCodesActive,
    required this.qrCodesDisabled,
    required this.totalAmountPaid,
    required this.totalWithdrawalPendingAmount,
    required this.totalAmountOnHold,
    required this.totalCommissionOnHold,
    required this.totalCommissionPaid,


    required this.totalSelfAssignedQrs,
    required this.todayPayInSelfAssignedQrs,
    required this.selfTotalTxCount,
    required this.selfTotalAmountReceived,
    required this.selfTotalAvailableAmount,
    required this.selfWithdrawableAmount,
    required this.selfQrCodesActive,
    required this.selfQrCodesDisabled,
    required this.selfTotalAmountPaid,
    required this.selfTotalWithdrawalPendingAmount,
    required this.selfTotalAmountOnHold,
    required this.selfTotalCommissionOnHold,
    required this.selfTotalCommissionPaid,


    required this.totalUserAssignedQrs,
    required this.todayPayInUserAssignedQrs,
    required this.userTotalTxCount,
    required this.userTotalAmountReceived,
    required this.userTotalAvailableAmount,
    required this.userWithdrawableAmount,
    required this.userQrCodesActive,
    required this.userQrCodesDisabled,
    required this.userTotalAmountPaid,
    required this.userTotalWithdrawalPendingAmount,
    required this.userTotalAmountOnHold,
    required this.userTotalCommissionOnHold,
    required this.userTotalCommissionPaid,


    required this.totalMerchantProfit,
    required this.activeUsers,
    required this.disabledUsers,
    required this.totalUsers,
    required this.totalMembershipPurchased,
    required this.pendingMembershipUsers,
  });

  factory SubAdminDashboardData.fromJson(Map<String, dynamic> j) =>
      SubAdminDashboardData(
        // Managed QRs
        totalQrsAssignedToMerchant:    j['totalQrsAssignedToMerchant'],
        todayPayInAllQrs:              j['todayPayInAllQrs'],
        totalTxCount:                  j['totalTxCount'],
        totalAmountReceived:           j['totalAmountReceived'],
        totalAvailableAmount:          j['totalAvailableAmount'],
        withdrawableAmount:            j['withdrawableAmount'],
        qrCodesActive:                 j['qrCodesActive'],
        qrCodesDisabled:               j['qrCodesDisabled'],
        totalAmountPaid:               j['totalAmountPaid'],
        totalWithdrawalPendingAmount:  j['totalWithdrawalPendingAmount'],
        totalAmountOnHold:             j['totalAmountOnHold'],
        totalCommissionOnHold:             j['totalCommissionOnHold'],
        totalCommissionPaid:             j['totalCommissionPaid'],

        // Self Assigned QRs
        totalSelfAssignedQrs:              j['totalSelfAssignedQrs'],
        todayPayInSelfAssignedQrs:         j['todayPayInSelfAssignedQrs'],
        selfTotalTxCount:                  j['selfTotalTxCount'],
        selfTotalAmountReceived:           j['selfTotalAmountReceived'],
        selfTotalAvailableAmount:          j['selfTotalAvailableAmount'],
        selfWithdrawableAmount:            j['selfWithdrawableAmount'],
        selfQrCodesActive:                 j['selfQrCodesActive'],
        selfQrCodesDisabled:               j['selfQrCodesDisabled'],
        selfTotalAmountPaid:               j['selfTotalAmountPaid'],
        selfTotalWithdrawalPendingAmount:  j['selfTotalWithdrawalPendingAmount'],
        selfTotalAmountOnHold:             j['selfTotalAmountOnHold'],
        selfTotalCommissionOnHold:         j['selfTotalCommissionOnHold'],
        selfTotalCommissionPaid:           j['selfTotalCommissionPaid'],

        // User Assigned QRs
        totalUserAssignedQrs:              j['totalUserAssignedQrs'],
        todayPayInUserAssignedQrs:         j['todayPayInUserAssignedQrs'],
        userTotalTxCount:                  j['userTotalTxCount'],
        userTotalAmountReceived:           j['userTotalAmountReceived'],
        userTotalAvailableAmount:          j['userTotalAvailableAmount'],
        userWithdrawableAmount:            j['userWithdrawableAmount'],
        userQrCodesActive:                 j['userQrCodesActive'],
        userQrCodesDisabled:               j['userQrCodesDisabled'],
        userTotalAmountPaid:               j['userTotalAmountPaid'],
        userTotalWithdrawalPendingAmount:  j['userTotalWithdrawalPendingAmount'],
        userTotalAmountOnHold:             j['userTotalAmountOnHold'],
        userTotalCommissionOnHold:         j['userTotalCommissionOnHold'],
        userTotalCommissionPaid:           j['userTotalCommissionPaid'],

        // Other
        totalMerchantProfit:       j['totalMerchantProfit'],
        activeUsers:               j['activeUsers'],
        disabledUsers:             j['disabledUsers'],
        totalUsers:                j['totalUsers'],
        totalMembershipPurchased:  j['totalMembershipPurchased'],
        pendingMembershipUsers:    j['pendingMembershipUsers'],
      );
}

// ===== API fetch =====

Future<SubAdminDashboardData> fetchSubadminDashboard({
  required String merchantId,
  bool force = false,
}) async {
  try {
    final jwt = await AppWriteService().getJWT();
    final uri = Uri.parse('${AppConstants.baseApiUrl}/admin/dashboard/subadmin/$merchantId');
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $jwt', 'Accept': 'application/json'},
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch dashboard: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> raw = json.decode(resp.body) as Map<String, dynamic>;

    final normalized = <String, dynamic>{
      // Managed QRs
      'totalQrsAssignedToMerchant':    raw['totalQrsAssignedToMerchant']    ?? 0,
      'todayPayInAllQrs':              raw['todayPayInAllQrs']              ?? 0,
      'totalTxCount':                  raw['totalTxCount']                  ?? 0,
      'totalAmountReceived':           raw['totalAmountReceived']           ?? 0,
      'totalAvailableAmount':          raw['totalAvailableAmount']          ?? 0,
      'withdrawableAmount':            raw['withdrawableAmount']            ?? 0,
      'qrCodesActive':                 raw['qrCodesActive']                 ?? 0,
      'qrCodesDisabled':               raw['qrCodesDisabled']               ?? 0,
      'totalAmountPaid':               raw['totalAmountPaid']               ?? 0,
      'totalWithdrawalPendingAmount':  raw['totalWithdrawalPendingAmount']  ?? 0,
      'totalAmountOnHold':             raw['totalAmountOnHold']             ?? 0,
      'totalCommissionOnHold':             raw['totalCommissionOnHold']             ?? 0,
      'totalCommissionPaid':             raw['totalCommissionPaid']             ?? 0,

      // Self Assigned QRs
      'totalSelfAssignedQrs':              raw['totalSelfAssignedQrs']              ?? 0,
      'todayPayInSelfAssignedQrs':         raw['todayPayInSelfAssignedQrs']         ?? 0,
      'selfTotalTxCount':                  raw['selfTotalTxCount']                  ?? 0,
      'selfTotalAmountReceived':           raw['selfTotalAmountReceived']           ?? 0,
      'selfTotalAvailableAmount':          raw['selfTotalAvailableAmount']          ?? 0,
      'selfWithdrawableAmount':            raw['selfWithdrawableAmount']            ?? 0,
      'selfQrCodesActive':                 raw['selfQrCodesActive']                 ?? 0,
      'selfQrCodesDisabled':               raw['selfQrCodesDisabled']               ?? 0,
      'selfTotalAmountPaid':               raw['selfTotalAmountPaid']               ?? 0,
      'selfTotalWithdrawalPendingAmount':  raw['selfTotalWithdrawalPendingAmount']  ?? 0,
      'selfTotalAmountOnHold':             raw['selfTotalAmountOnHold']             ?? 0,
      'selfTotalCommissionOnHold':             raw['selfTotalCommissionOnHold']             ?? 0,
      'selfTotalCommissionPaid':             raw['selfTotalCommissionPaid']             ?? 0,

      // User Assigned QRs
      'totalUserAssignedQrs':              raw['totalUserAssignedQrs']              ?? 0,
      'todayPayInUserAssignedQrs':         raw['todayPayInUserAssignedQrs']         ?? 0,
      'userTotalTxCount':                  raw['userTotalTxCount']                  ?? 0,
      'userTotalAmountReceived':           raw['userTotalAmountReceived']           ?? 0,
      'userTotalAvailableAmount':          raw['userTotalAvailableAmount']          ?? 0,
      'userWithdrawableAmount':            raw['userWithdrawableAmount']            ?? 0,
      'userQrCodesActive':                 raw['userQrCodesActive']                 ?? 0,
      'userQrCodesDisabled':               raw['userQrCodesDisabled']               ?? 0,
      'userTotalAmountPaid':               raw['userTotalAmountPaid']               ?? 0,
      'userTotalWithdrawalPendingAmount':  raw['userTotalWithdrawalPendingAmount']  ?? 0,
      'userTotalAmountOnHold':             raw['userTotalAmountOnHold']             ?? 0,
      'userTotalCommissionOnHold':             raw['userTotalCommissionOnHold']             ?? 0,
      'userTotalCommissionPaid':             raw['userTotalCommissionPaid']             ?? 0,

      // Other
      'totalMerchantProfit':       raw['totalMerchantProfit']       ?? 0,
      'activeUsers':               raw['activeUsers']               ?? 0,
      'disabledUsers':             raw['disabledUsers']             ?? 0,
      'totalUsers':                raw['totalUsers']                ?? 0,
      'totalMembershipPurchased':  raw['totalMembershipPurchased']  ?? 0,
      'pendingMembershipUsers':    raw['pendingMembershipUsers']    ?? 0,
    };

    return SubAdminDashboardData.fromJson(normalized);
  } catch (e) {
    throw Exception('Failed to fetch dashboard');
  }
}