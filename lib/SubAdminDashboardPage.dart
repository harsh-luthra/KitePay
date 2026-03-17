import 'dart:async';
import 'dart:convert';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'AppConstants.dart';
import 'AppWriteService.dart';
import 'utils/app_spacing.dart';
import 'widget/dashboard_widgets.dart';

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
            return const DashboardSkeleton(sectionCount: 9);
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

                // ═══ 1. ALL MANAGED QRs (indigo) ═══
                const DashboardSectionHeader(label: 'Managed QRs', color: Colors.indigo),

                DashboardSection(
                  title: 'All Managed QR — Overview',
                  accentColor: Colors.indigo,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Total QRs Assigned', value: data.totalQrsAssignedToMerchant, icon: Icons.assignment_ind, color: Colors.indigo, showFull: sf),
                      DashboardMetricCard.count(title: 'Total Transactions', value: data.totalTxCount, icon: Icons.swap_horiz, color: Colors.indigo.shade300, showFull: sf),
                      DashboardMetricCard.money(title: 'Total Pay-In', paise: data.totalAmountReceived, icon: Icons.account_balance_wallet, color: Colors.teal, showFull: sf),
                    ]),
                  ],
                ),

                DashboardSection(
                  title: 'All Managed QR — Payouts',
                  accentColor: Colors.indigo,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'Amount Paid', paise: data.totalAmountPaid, icon: Icons.outbox, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'Pending Withdrawals', paise: data.totalWithdrawalPendingAmount, icon: Icons.pending_actions, color: Colors.deepOrange, showFull: sf),
                      DashboardMetricCard.money(title: 'Total Available Amount', paise: data.totalAvailableAmount, icon: Icons.account_balance, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.money(title: 'Yesterday Pay-In', paise: data.yesterdayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Today Pay-In', paise: data.todayPayInAllQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Withdrawable Amount', paise: data.withdrawableAmount, icon: Icons.savings, color: Colors.cyan.shade700, showFull: sf),
                      DashboardMetricCard.money(title: 'Amount On Hold', paise: data.totalAmountOnHold, icon: Icons.lock_clock_outlined, color: Colors.deepOrangeAccent, showFull: sf),
                      DashboardMetricCard.money(title: 'Commission On Hold', paise: data.totalCommissionOnHold, icon: Icons.savings_outlined, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.money(title: 'Commission Paid', paise: data.totalCommissionPaid, icon: Icons.payments, color: Colors.purpleAccent, showFull: sf),
                    ]),
                  ],
                ),

                DashboardSection(
                  title: 'All Managed QR — Breakdown',
                  accentColor: Colors.indigo,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'QRs Active', value: data.qrCodesActive, icon: Icons.check_circle, color: Colors.green.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'QRs Disabled', value: data.qrCodesDisabled, icon: Icons.disabled_by_default, color: Colors.red.shade700, showFull: sf),
                    ]),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // ═══ 2. SELF ASSIGNED QRs (purple) ═══
                const DashboardSectionHeader(label: 'Self Assigned QRs', color: Colors.purple),

                DashboardSection(
                  title: 'Self Assigned QR — Overview',
                  accentColor: Colors.purple,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Self Total QRs', value: data.totalSelfAssignedQrs, icon: Icons.qr_code, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.count(title: 'Self Transactions', value: data.selfTotalTxCount, icon: Icons.swap_horiz, color: Colors.purple.shade300, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Total Pay-In', paise: data.selfTotalAmountReceived, icon: Icons.account_balance_wallet, color: Colors.teal, showFull: sf),
                    ]),
                  ],
                ),

                DashboardSection(
                  title: 'Self Assigned QR — Payouts',
                  accentColor: Colors.purple,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'Self Amount Paid', paise: data.selfTotalAmountPaid, icon: Icons.outbox, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Pending Withdrawals', paise: data.selfTotalWithdrawalPendingAmount, icon: Icons.pending_actions, color: Colors.deepOrange, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Total Available Amount', paise: data.selfTotalAvailableAmount, icon: Icons.account_balance, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Today Pay-In', paise: data.todayPayInSelfAssignedQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Yesterday Pay-In', paise: data.yesterdayPayInSelfAssignedQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Withdrawable Amount', paise: data.selfWithdrawableAmount, icon: Icons.savings, color: Colors.cyan.shade700, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Amount On Hold', paise: data.selfTotalAmountOnHold, icon: Icons.lock_clock_outlined, color: Colors.deepOrangeAccent, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Commission On Hold', paise: data.selfTotalCommissionOnHold, icon: Icons.savings_outlined, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.money(title: 'Self Commission Paid', paise: data.selfTotalCommissionPaid, icon: Icons.payments, color: Colors.purpleAccent, showFull: sf),
                    ]),
                  ],
                ),

                DashboardSection(
                  title: 'Self Assigned QR — Breakdown',
                  accentColor: Colors.purple,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'Self QRs Active', value: data.selfQrCodesActive, icon: Icons.check_circle, color: Colors.green.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'Self QRs Disabled', value: data.selfQrCodesDisabled, icon: Icons.disabled_by_default, color: Colors.red.shade700, showFull: sf),
                    ]),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // ═══ 3. USER ASSIGNED QRs (teal) ═══
                const DashboardSectionHeader(label: 'User Assigned QRs', color: Colors.teal),

                DashboardSection(
                  title: 'User Assigned QR — Overview',
                  accentColor: Colors.teal,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'User Total QRs', value: data.totalUserAssignedQrs, icon: Icons.qr_code, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.count(title: 'User Transactions', value: data.userTotalTxCount, icon: Icons.swap_horiz, color: Colors.teal.shade300, showFull: sf),
                      DashboardMetricCard.money(title: 'User Total Pay-In', paise: data.userTotalAmountReceived, icon: Icons.account_balance_wallet, color: Colors.teal, showFull: sf),
                    ]),
                  ],
                ),

                DashboardSection(
                  title: 'User Assigned QR — Payouts',
                  accentColor: Colors.teal,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.money(title: 'User Amount Paid', paise: data.userTotalAmountPaid, icon: Icons.outbox, color: Colors.green, showFull: sf),
                      DashboardMetricCard.money(title: 'User Pending Withdrawals', paise: data.userTotalWithdrawalPendingAmount, icon: Icons.pending_actions, color: Colors.deepOrange, showFull: sf),
                      DashboardMetricCard.money(title: 'User Total Available Amount', paise: data.userTotalAvailableAmount, icon: Icons.account_balance, color: Colors.teal, showFull: sf),
                      DashboardMetricCard.money(title: 'User Today Pay-In', paise: data.todayPayInUserAssignedQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'User Yesterday Pay-In', paise: data.yesterdayPayInUserAssignedQrs, icon: Icons.today_rounded, color: Colors.blueGrey, showFull: sf),
                      DashboardMetricCard.money(title: 'User Withdrawable Amount', paise: data.userWithdrawableAmount, icon: Icons.savings, color: Colors.cyan.shade700, showFull: sf),
                      DashboardMetricCard.money(title: 'User Amount On Hold', paise: data.userTotalAmountOnHold, icon: Icons.lock_clock_outlined, color: Colors.deepOrangeAccent, showFull: sf),
                      DashboardMetricCard.money(title: 'User Commission On Hold', paise: data.userTotalCommissionOnHold, icon: Icons.savings_outlined, color: Colors.purple, showFull: sf),
                      DashboardMetricCard.money(title: 'User Commission Paid', paise: data.userTotalCommissionPaid, icon: Icons.payments, color: Colors.purpleAccent, showFull: sf),
                    ]),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                DashboardSection(
                  title: 'User Assigned QR — Breakdown',
                  accentColor: Colors.teal,
                  children: [
                    DashboardMetricGrid(items: [
                      DashboardMetricCard.count(title: 'User QRs Active', value: data.userQrCodesActive, icon: Icons.check_circle, color: Colors.green.shade700, showFull: sf),
                      DashboardMetricCard.count(title: 'User QRs Disabled', value: data.userQrCodesDisabled, icon: Icons.disabled_by_default, color: Colors.red.shade700, showFull: sf),
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

// ===== Data model =====

class SubAdminDashboardData {
  // ── Managed QRs ───────────────────────────────────────────────────────────
  final int totalQrsAssignedToMerchant;
  final int todayPayInAllQrs;
  final int yesterdayPayInAllQrs;
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
  final int yesterdayPayInSelfAssignedQrs;
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
  final int yesterdayPayInUserAssignedQrs;
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

  // ── Meta ──────────────────────────────────────────────────────────────────
  final DateTime fetchedAt;

  const SubAdminDashboardData({
    required this.totalQrsAssignedToMerchant,
    required this.todayPayInAllQrs,
    required this.yesterdayPayInAllQrs,
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
    required this.yesterdayPayInSelfAssignedQrs,
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
    required this.yesterdayPayInUserAssignedQrs,
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

    required this.fetchedAt,
  });

  factory SubAdminDashboardData.fromJson(Map<String, dynamic> j) =>
      SubAdminDashboardData(
        // Managed QRs
        totalQrsAssignedToMerchant:    j['totalQrsAssignedToMerchant'],
        todayPayInAllQrs:              j['todayPayInAllQrs'],
        yesterdayPayInAllQrs:          j['yesterdayPayInAllQrs'],
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
        yesterdayPayInSelfAssignedQrs:     j['yesterdayPayInSelfAssignedQrs'],
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
        yesterdayPayInUserAssignedQrs:     j['yesterdayPayInUserAssignedQrs'],
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

        totalMerchantProfit:       j['totalMerchantProfit'],
        activeUsers:               j['activeUsers'],
        disabledUsers:             j['disabledUsers'],
        totalUsers:                j['totalUsers'],
        totalMembershipPurchased:  j['totalMembershipPurchased'],
        pendingMembershipUsers:    j['pendingMembershipUsers'],

        fetchedAt: DateTime.now(),
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
      'yesterdayPayInAllQrs':          raw['yesterdayPayInAllQrs']          ?? 0,
      'totalTxCount':                  raw['totalTxCount']                  ?? 0,
      'totalAmountReceived':           raw['totalAmountReceived']           ?? 0,
      'totalAvailableAmount':          raw['totalAvailableAmount']          ?? 0,
      'withdrawableAmount':            raw['withdrawableAmount']            ?? 0,
      'qrCodesActive':                 raw['qrCodesActive']                 ?? 0,
      'qrCodesDisabled':               raw['qrCodesDisabled']               ?? 0,
      'totalAmountPaid':               raw['totalAmountPaid']               ?? 0,
      'totalWithdrawalPendingAmount':  raw['totalWithdrawalPendingAmount']  ?? 0,
      'totalAmountOnHold':             raw['totalAmountOnHold']             ?? 0,
      'totalCommissionOnHold':         raw['totalCommissionOnHold']         ?? 0,
      'totalCommissionPaid':           raw['totalCommissionPaid']           ?? 0,

      // Self Assigned QRs
      'totalSelfAssignedQrs':              raw['totalSelfAssignedQrs']              ?? 0,
      'todayPayInSelfAssignedQrs':         raw['todayPayInSelfAssignedQrs']         ?? 0,
      'yesterdayPayInSelfAssignedQrs':     raw['yesterdayPayInSelfAssignedQrs']     ?? 0,
      'selfTotalTxCount':                  raw['selfTotalTxCount']                  ?? 0,
      'selfTotalAmountReceived':           raw['selfTotalAmountReceived']           ?? 0,
      'selfTotalAvailableAmount':          raw['selfTotalAvailableAmount']          ?? 0,
      'selfWithdrawableAmount':            raw['selfWithdrawableAmount']            ?? 0,
      'selfQrCodesActive':                 raw['selfQrCodesActive']                 ?? 0,
      'selfQrCodesDisabled':               raw['selfQrCodesDisabled']               ?? 0,
      'selfTotalAmountPaid':               raw['selfTotalAmountPaid']               ?? 0,
      'selfTotalWithdrawalPendingAmount':  raw['selfTotalWithdrawalPendingAmount']  ?? 0,
      'selfTotalAmountOnHold':             raw['selfTotalAmountOnHold']             ?? 0,
      'selfTotalCommissionOnHold':         raw['selfTotalCommissionOnHold']         ?? 0,
      'selfTotalCommissionPaid':           raw['selfTotalCommissionPaid']           ?? 0,

      // User Assigned QRs
      'totalUserAssignedQrs':              raw['totalUserAssignedQrs']              ?? 0,
      'todayPayInUserAssignedQrs':         raw['todayPayInUserAssignedQrs']         ?? 0,
      'yesterdayPayInUserAssignedQrs':     raw['yesterdayPayInUserAssignedQrs']     ?? 0,
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

      'totalMerchantProfit':       raw['totalMerchantProfit']       ?? 0,
      'activeUsers':               raw['activeUsers']               ?? 0,
      'disabledUsers':             raw['disabledUsers']             ?? 0,
      'totalUsers':                raw['totalUsers']                ?? 0,
      'totalMembershipPurchased':  raw['totalMembershipPurchased']  ?? 0,
      'pendingMembershipUsers':    raw['pendingMembershipUsers']    ?? 0,
    };

    return SubAdminDashboardData.fromJson(normalized);
  } catch (e) {
    throw Exception('Failed to fetch dashboard: $e');
  }
}