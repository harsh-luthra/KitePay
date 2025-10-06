import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/widget/WithdrawalCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'UsersService.dart';
import 'WithdrawService.dart';
import 'WithdrawalFormPage.dart';
import 'models/AppUser.dart';
import 'models/WithdrawalRequest.dart';

// Generic page state to mirror TransactionPageNew style
class PageState<T> {
  List<T> items;
  String? nextCursor;
  bool hasMore;
  bool loadingMore;

  PageState({
    List<T>? items,
    this.nextCursor,
    this.hasMore = true,
    this.loadingMore = false,
  }) : items = items ?? [];
}

class ManageWithdrawalsNew extends StatefulWidget {
  final String? userModeUserid;
  final bool userMode;

  const ManageWithdrawalsNew({
    super.key,
    this.userModeUserid,
    this.userMode = false,
  });

  @override
  State<ManageWithdrawalsNew> createState() => _ManageWithdrawalsNewState();
}

class _ManageWithdrawalsNewState extends State<ManageWithdrawalsNew> {
  // Tabs: all, pending, approved, rejected
  String filter = 'all';

  // Per-tab pagination state
  final Map<String, PageState<WithdrawalRequest>> pages = {
    'all': PageState<WithdrawalRequest>(),
    'pending': PageState<WithdrawalRequest>(),
    'approved': PageState<WithdrawalRequest>(),
    'rejected': PageState<WithdrawalRequest>(),
  };

  // In-flight guards to prevent overlapping loads (refinement)
  final Map<String, bool> inFlight = {
    'all': false,
    'pending': false,
    'approved': false,
    'rejected': false,
  };

  // Users for display (requestedBy)
  List<AppUser> users = [];

  // Global loading for first visible load and user list
  bool loading = false;
  bool loadingUsers = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Scroll/infinite pagination (mirrors TransactionPageNew)
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Preload users (admin mode only), then load first page for current filter
    fetchInitial(); // first visible page load
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchInitial() async {
    setState(() => loading = true);
    try {
      if (!widget.userMode) {
        await _fetchUsers();
        // print("Fetching users");
      }
      // First page for current tab
      await fetchPage(status: filter, firstLoad: true);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to load withdrawals: $e')),
      );
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _fetchUsers() async {
    setState(() => loadingUsers = true);
    try {
      final fetched = await UsersService.listUsers(
        jwtToken: await AppWriteService().getJWT(),
      );
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if (!mounted) return;
    setState(() => loadingUsers = false);
  }

  // Fetch a page for a given status tab, with inFlight guard
  Future<void> fetchPage({
    required String status,
    bool firstLoad = false,
  }) async {
    final page = pages[status]!;

    // If this is an explicit first load (after reset or mutation),
    // start from scratch to avoid stale cursor/hasMore.
    if (firstLoad) {
      page.nextCursor = null; // ensure first page
      page.hasMore = true; // reset pagination gate
    } else {
      // For incremental loads, respect guards
      if (page.loadingMore || !page.hasMore) return;
    }

    // Prevent duplicate concurrent calls for this tab
    if (inFlight[status] == true) return;
    inFlight[status] = true;

    // Loading flags
    if (firstLoad && page.items.isEmpty) {
      setState(() => loading = true);
    } else {
      setState(() => page.loadingMore = true);
    }

    try {
      final bool isAll = status == 'all';

      final resp = widget.userMode
          ? await WithdrawService.fetchUserWithdrawalsPaginated(
        jwtToken: await AppWriteService().getJWT(),
        userId: widget.userModeUserid!, // required in user mode
        status: isAll ? null : status, // null => All
        cursor: page.nextCursor, // null on firstLoad
        // limit: 20,                               // optional override
      )
          : await WithdrawService.fetchWithdrawalsPaginated(
        jwtToken: await AppWriteService().getJWT(),
        status: isAll ? null : status,
        cursor: page.nextCursor,
        // limit: 20,
      );

      final existingIds = page.items.map((e) => e.id)
          .whereType<String>()
          .toSet();
      final newOnes = resp.requests.where((r) =>
      r.id != null && !existingIds.contains(r.id));
      if (firstLoad && page.items.isEmpty) {
        page.items = newOnes.toList();
      } else {
        page.items.addAll(newOnes);
      }

      page.nextCursor = resp.nextCursor;
      page.hasMore = resp.nextCursor != null;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch $status withdrawals: $e')),
      );
    } finally {
      inFlight[status] = false;
      if (!mounted) return;
      setState(() {
        if (firstLoad && loading) loading = false;
        page.loadingMore = false;
      });
    }
  }


    // Helper to reset a tab state and optionally fetch immediately
  Future<void> _resetTab(String status, {bool fetch = false}) async {
    pages[status] = PageState<WithdrawalRequest>();
    setState(() {});
    if (fetch) {
      await fetchPage(status: status, firstLoad: true);
    }
  }

  // Refresh current + All, with safe resets
  Future<void> _refreshCurrentTab() async {
    // Reset and refetch current tab
    await _resetTab(filter, fetch: true);

    // Reset All tab and refetch only if not already on All
    if (filter != 'all') {
      await _resetTab('all', fetch: true);
    }
  }

  Future<void> _refreshAllForced() async {
    // Fully reset All and force a fresh first page fetch
    await _resetTab(filter, fetch: true);
    pages['pending'] = PageState<WithdrawalRequest>();
    pages['approved'] = PageState<WithdrawalRequest>();
    pages['rejected'] = PageState<WithdrawalRequest>();
    inFlight['all'] = false; // ensure guard won't block
    pages['all'] = PageState<WithdrawalRequest>(); // clears items, nextCursor, hasMore
    setState(() {});
    await fetchPage(status: 'all', firstLoad: true);
  }

  // Scroll listener to mirror TransactionPageNew’s infinite scroll
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      fetchPage(status: filter);
    }
  }

  // Utilities
  AppUser? getUserById(String id) {
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (_) {
      return null;
    }
  }

  String? displayUserNameText(String? appUserId) {
    if (appUserId == null) {
      return "Unassigned";
    }
    final user = getUserById(appUserId);
    return user != null ? '${user.name} - ${user.email}' : 'Unknown user';
  }

  Map<String, int> get counts {
    final all = pages['all']!.items;
    return {
      'all': all.length,
      'pending': all.where((r) => r.status == 'pending').length,
      'approved': all.where((r) => r.status == 'approved').length,
      'rejected': all.where((r) => r.status == 'rejected').length,
    };
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade500;
      case 'approved':
        return Colors.green.shade500;
      case 'rejected':
        return Colors.red.shade500;
      default:
        return Colors.grey.shade100;
    }
  }

  String formatToIST(String istDateTimeString) {
    final dateTime = DateTime.parse(istDateTimeString);
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  String formatIndianCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Future<T> _showBlockingProgress<T>({
    required BuildContext context,
    required String message,
    required Future<T> future,
  }) async {
    // Non-dismissible dialog with back blocked
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
    ); // [2][1][5]

    try {
      final result = await future;
      if (Navigator.of(context).canPop())
        Navigator.of(context).pop(); // close loading
      return result;
    } catch (e) {
      if (Navigator.of(context).canPop())
        Navigator.of(context).pop(); // close loading on error
      rethrow;
    }
  }

  Future<void> _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool success = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    ); // [14]
  }

  Future<void> _showApproveDialog(WithdrawalRequest request) async {
    final utrController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    String rupees(num p) => formatIndianCurrency(p);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !submitting, // avoid closing while submitting
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        String? validateUtr(String? v) {
          final s = v?.trim() ?? '';
          if (s.isEmpty) return 'UTR number is required';
          if (s.length < 8) return 'UTR must be at least 8 characters';
          if (!RegExp(r'^[A-Za-z0-9\-_/]+$').hasMatch(s)) {
            return 'Only letters, numbers and - _ / are allowed';
          }
          return null;
        }
        final valid = validateUtr(utrController.text) == null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Approve Withdrawal'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recap box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debit: ${rupees(request.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('QR: ${request.qrId}'),
                      if (request.userId != null)
                        Text('Requested By: ${displayUserNameText(request.userId) ?? request.userId}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: utrController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,  // only 0-9
                    LengthLimitingTextInputFormatter(18),    // adjust if your UTR max differs
                  ],
                  decoration: InputDecoration(
                    labelText: 'UTR Number',
                    hintText: 'Enter digits only',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    helperText: 'Min 8 digits; digits 0-9 only',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (utrController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear),
                            onPressed: submitting ? null : () => setLocal(() => utrController.clear()),
                          ),
                        IconButton(
                          tooltip: 'Paste',
                          icon: const Icon(Icons.content_paste),
                          onPressed: submitting
                              ? null
                              : () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              final onlyDigits = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
                              setLocal(() => utrController.text = onlyDigits);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'UTR is required';
                    if (s.length < 8) return 'UTR must be at least 8 digits';
                    if (!RegExp(r'^\d+$').hasMatch(s)) return 'Digits 0-9 only';
                    return null;
                  },
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (!valid || submitting)
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                setLocal(() => submitting = true);
                try {
                  final apiTuple = await _showBlockingProgress(
                    context: context,
                    message: 'Approving request...',
                    future: WithdrawService.approveWithdrawal(
                      jwtToken: await AppWriteService().getJWT(),
                      requestId: request.id!,
                      utrNumber: utrController.text.trim(),
                    ),
                  );
                  final success = apiTuple.$1;
                  final message = apiTuple.$2;

                  if (context.mounted) {
                    Navigator.pop(ctx, success ? utrController.text.trim() : null);
                    await _showResultDialog(
                      context,
                      title: success ? 'Approved' : 'Approval failed',
                      message: message,
                      success: success,
                    );
                    if (success) {
                      await _resetTab(filter, fetch: true);
                      await _refreshAllForced();
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    await _showResultDialog(
                      context,
                      title: 'Error',
                      message: 'Failed to approve: $e',
                      success: false,
                    );
                  }
                } finally {
                  if (context.mounted) setLocal(() => submitting = false);
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Approve'),
            ),
          ],
        );
      }),
    );

    // result handling is inside dialog
  }

  void _showRejectDialog(BuildContext context, WithdrawalRequest request) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        String? validateReason(String? v) {
          final s = v?.trim() ?? '';
          if (s.isEmpty) return 'Reason is required';
          if (s.length < 4) return 'Minimum 4 characters required';
          return null;
        }
        final valid = validateReason(reasonController.text) == null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Reject Withdrawal'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Provide a clear reason (visible to requester)',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.comment_outlined),
                helperText: 'Minimum 4 characters',
                suffixIcon: reasonController.text.isNotEmpty
                    ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: submitting ? null : () => setLocal(() => reasonController.clear()),
                )
                    : null,
              ),
              validator: validateReason,
              onChanged: (_) => setLocal(() {}),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
              onPressed: (!valid || submitting)
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                setLocal(() => submitting = true);
                try {
                  final apiTuple = await _showBlockingProgress(
                    context: context,
                    message: 'Rejecting request...',
                    future: WithdrawService.rejectWithdrawal(
                      jwtToken: await AppWriteService().getJWT(),
                      requestId: request.id!,
                      reason: reasonController.text.trim(),
                    ),
                  );
                  final success = apiTuple.$1;
                  final message = apiTuple.$2;

                  if (context.mounted) {
                    Navigator.pop(ctx); // close dialog
                    await _showResultDialog(
                      context,
                      title: success ? 'Rejected' : 'Rejection failed',
                      message: message,
                      success: success,
                    );
                    if (success) {
                      await _resetTab(filter, fetch: true);
                      await _refreshAllForced();
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    await _showResultDialog(
                      context,
                      title: 'Error',
                      message: 'Failed to reject: $e',
                      success: false,
                    );
                  }
                } finally {
                  if (context.mounted) setLocal(() => submitting = false);
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Reject'),
            ),
          ],
        );
      }),
    );
  }

  bool shouldSkipIndependenceDayDialog() {
    final now = DateTime.now();
    if (now.month == 8 && now.day == 15) {
      return false;
    }
    return true;
  }

  void showIndependenceDayDialog(BuildContext context) {
    final now = DateTime.now();
    if (now.month == 8 && now.day == 15) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Notice"),
              content: const Text(
                "On the occasion of 15th August (Independence Day), withdrawals will not be processed.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    }
  }

  bool hasReachedMaxPending(List<WithdrawalRequest> requests, int maxPending) {
    int pendingCount = 0;
    for (final r in requests) {
      if (r.status == 'pending') {
        pendingCount++;
        if (pendingCount >= maxPending) return true;
      }
    }
    return false;
  }

  Future<void> showMaxPendingDialog(
    BuildContext context,
    int maxPending,
  ) async {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Request Limit Reached"),
            content: Text(
              "You already have the maximum number of pending requests allowed ($maxPending).",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  Color getStatusColorBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'pending':  return Colors.amber.shade800;
      default:         return Colors.blueGrey;
    }
  }

  Widget buildFilterChip(String label, String value) {
    final count = counts[value] ?? 0;
    final selected = filter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      surfaceTintColor: Colors.transparent,
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
      ),
      onSelected: (_) async {
        if (filter == value) return;
        setState(() => filter = value);
        final page = pages[value]!;
        if (page.items.isEmpty && inFlight[value] != true) {
          await fetchPage(status: value, firstLoad: true);
        }
      },
    );
  }

  Widget _buildInfoRow(String label, String? value, {bool copyable = false}) {
    final text = (value?.isNotEmpty == true) ? value!.trim() : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label
          copyable
              ? SelectableText('$label: ', style: const TextStyle(fontWeight: FontWeight.w600))
              : Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),

          // Value
          Expanded(
            child: copyable
                ? SelectableText(text, style: const TextStyle(color: Colors.black87))
                : Text(text, style: const TextStyle(color: Colors.black87), overflow: TextOverflow.ellipsis),
          ),

          // Copy icon only if copyable and has a real value
          if (copyable && text != '-' && text.isNotEmpty)
            IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(12),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget buildRequestCard(WithdrawalRequest r) {
    final statusBg = getStatusColorBg(r.status ?? 'pending');
    final credit = formatIndianCurrency(r.preAmount);
    final commission = formatIndianCurrency(r.commission);
    final debit = formatIndianCurrency(r.amount);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Mode + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(r.mode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    (r.status ?? '').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: statusBg,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Amount strip
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: LayoutBuilder(
                builder: (_, cts) {
                  final threeCols = cts.maxWidth > 520;
                  final children = [
                    _amountPill('Credit', credit, Icons.trending_up, Colors.green.shade700),
                    _amountPill('Commission', commission, Icons.percent, Colors.indigo),
                    _amountPill('Debit', debit, Icons.trending_down, Colors.red.shade700),
                  ];
                  if (threeCols) {
                    return Row(
                      children: [
                        Expanded(child: children[0]),
                        const SizedBox(width: 8),
                        Expanded(child: children[1]),
                        const SizedBox(width: 8),
                        Expanded(child: children[2]),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        children[0],
                        const SizedBox(height: 6),
                        children[1],
                        const SizedBox(height: 6),
                        children[2],
                      ],
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 10),

            // Details grid
            LayoutBuilder(
              builder: (_, cts) {
                final twoCols = cts.maxWidth > 620;
                final details = [
                  _buildInfoRow("Name", r.holderName),
                  if (!widget.userMode)
                    _buildInfoRow("Requested By", displayUserNameText(r.userId) ?? 'Not Available'),
                  _buildInfoRow("QR Id", r.qrId, copyable: true),
                  if (r.mode == 'upi') _buildInfoRow("VPA", r.upiId , copyable: true),
                  if (r.mode != 'upi') _buildInfoRow("Bank", r.bankName , copyable: true),
                  if (r.mode != 'upi') _buildInfoRow("Acc No.", r.accountNumber , copyable: true),
                  if (r.mode != 'upi') _buildInfoRow("IFSC", r.ifscCode , copyable: true),
                  _buildInfoRow("Requested at", formatToIST(r.createdAt.toString())),
                  if (r.status == 'approved' && r.utrNumber?.isNotEmpty == true)
                    _buildInfoRow("UTR", r.utrNumber , copyable: true),
                  if (r.status == 'rejected' && r.rejectionReason?.isNotEmpty == true)
                    _buildInfoRow("Reason", r.rejectionReason),
                ];

                if (!twoCols) return Column(children: details);
                // Two-column flowing grid
                return Wrap(
                  spacing: 24,
                  runSpacing: 6,
                  children: details.map((w) => SizedBox(width: (cts.maxWidth - 24) / 2, child: w)).toList(),
                );
              },
            ),

            const SizedBox(height: 10),
            if (r.status == 'pending' && !widget.userMode)
              _cardActions(r),
          ],
        ),
      ),
    );
  }

  Widget _amountPill(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: color)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardActions(WithdrawalRequest r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FilledButton.icon(
          onPressed: () => _showApproveDialog(r),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Approve'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _showRejectDialog(context, r),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Reject'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = pages[filter]!;
    final visible = current.items;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Withdrawal Requests'),
          actions: !loading ? [
            if (widget.userMode)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'New Request',
                onPressed: () async {
                  if (shouldSkipIndependenceDayDialog() == false) {
                    showIndependenceDayDialog(context);
                    return;
                  }
                  final allList = pages['all']!.items;
                  if (!hasReachedMaxPending(allList, AppConfig().maxWithdrawalRequests)) {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                    );
                    if (ok == true) {
                      await _resetTab(filter, fetch: true);
                      pages['all'] = PageState<WithdrawalRequest>();
                      pages['approved'] = PageState<WithdrawalRequest>();
                      pages['rejected'] = PageState<WithdrawalRequest>();
                      setState(() {});
                      _refreshAllForced();
                    }
                  } else {
                    showMaxPendingDialog(context, AppConfig().maxWithdrawalRequests);
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refreshAllForced,
            ),
          ] : [],
        ),
        body: loading
            ? ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 8,
          itemBuilder: (_, __) => const WithdrawalCardShimmer(),
        )
            : Column(
          children: [
            const SizedBox(height: 10),
            // Filter toolbar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  buildFilterChip('ALL', 'all'),
                  const SizedBox(width: 8),
                  buildFilterChip('PENDING', 'pending'),
                  const SizedBox(width: 8),
                  buildFilterChip('APPROVED', 'approved'),
                  const SizedBox(width: 8),
                  buildFilterChip('REJECTED', 'rejected'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshCurrentTab,
                child: visible.isEmpty
                    ? ListView(
                  children: const [
                    SizedBox(height: 200, child: Center(child: Text('No requests'))),
                  ],
                )
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: visible.length + (current.loadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < visible.length) {
                      return buildRequestCard(visible[index]);
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading more...')
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
