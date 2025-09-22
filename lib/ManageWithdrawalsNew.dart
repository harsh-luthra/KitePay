import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:flutter/material.dart';
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
      final fetched = await AdminUserService.listUsers(
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
    inFlight['all'] = false; // ensure guard won't block
    pages['all'] =
        PageState<WithdrawalRequest>(); // clears items, nextCursor, hasMore
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

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRequestCard(WithdrawalRequest r) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatIndianCurrency(r.amount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildInfoRow("Name", r.holderName),
                      if(!widget.userMode)
                      _buildInfoRow(
                        'Requested By',
                        displayUserNameText(r.userId) ?? 'Not Available',
                      ),
                      _buildInfoRow('QR Id', r.qrId),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.mode.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        r.status!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: getStatusColor(r.status!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (r.mode == 'upi') ...[
              _buildInfoRow("VPA", r.upiId),
            ] else ...[
              _buildInfoRow("Bank", r.bankName),
              _buildInfoRow("Acc No.", r.accountNumber),
              _buildInfoRow("IFSC", r.ifscCode),
            ],
            const SizedBox(height: 8),
            _buildInfoRow("Created", formatToIST(r.createdAt.toString())),
            if (r.status == 'approved' && r.utrNumber?.isNotEmpty == true)
              _buildInfoRow("UTR", r.utrNumber),
            if (r.status == 'rejected' && r.rejectionReason?.isNotEmpty == true)
              _buildInfoRow("Reason", r.rejectionReason),
            const SizedBox(height: 10),
            if (r.status == 'pending' && !widget.userMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(r),
                    icon: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Approve',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(context, r),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
    final TextEditingController utrController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Enter UTR Number'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: utrController,
                decoration: const InputDecoration(labelText: 'UTR Number'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'UTR number is required';
                  }
                  if (value.trim().length < 8) {
                    return 'UTR number must be at least 8 characters';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, utrController.text.trim());
                  }
                },
                child: const Text('Approve'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final apiTuple = await _showBlockingProgress(
          context: context,
          message: 'Approving request...',
          future: WithdrawService.approveWithdrawal(
            jwtToken: await AppWriteService().getJWT(),
            requestId: request.id!,
            utrNumber: result,
          ),
        ); // returns (bool success, String message)

        final success = apiTuple.$1;
        final message = apiTuple.$2;

        await _showResultDialog(
          context,
          title: success ? 'Approved' : 'Approval failed',
          message: message,
          success: success,
        );

        if (success) {
          // 1) Refresh current tab immediately
          await _resetTab(filter, fetch: true);

          // 2) Force refresh All, even if currently on All
          await _refreshAllForced();

          // 3) Invalidate related tabs to lazy reload on next visit
          pages['pending'] = PageState<WithdrawalRequest>();
          pages['approved'] = PageState<WithdrawalRequest>();
          pages['rejected'] = PageState<WithdrawalRequest>();
          setState(() {});
        }
      } catch (e) {
        await _showResultDialog(
          context,
          title: 'Error',
          message: 'Failed to approve: $e',
          success: false,
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context, WithdrawalRequest request) {
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (alertContext) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Reason for rejection'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Reason is required';
              if (value.trim().length < 4) return 'Minimum 4 characters required';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(alertContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                // Show blocking progress (make sure it closes itself)
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

                // Close the reject dialog now that the operation completed
                if (success) {
                  Navigator.pop(alertContext); // dismiss this AlertDialog [web:228]
                }

                await _showResultDialog(
                  context,
                  title: success ? 'Rejected' : 'Rejection failed',
                  message: message,
                  success: success,
                );

                if (success) {
                  await _resetTab(filter, fetch: true);
                  await _refreshAllForced();
                  pages['pending'] = PageState<WithdrawalRequest>();
                  pages['approved'] = PageState<WithdrawalRequest>();
                  pages['rejected'] = PageState<WithdrawalRequest>();
                  if (mounted) setState(() {});
                }
              } catch (e) {
                // Ensure the reject dialog closes on error if desired
                // Navigator.pop(alertContext);
                await _showResultDialog(
                  context,
                  title: 'Error',
                  message: 'Failed to reject: $e',
                  success: false,
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
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

  Widget buildFilterChip(String label, String value) {
    final count = counts[value] ?? 0;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: filter == value,
      onSelected: (_) async {
        setState(() => filter = value);
        // Lazy load the tab if not loaded or invalidated
        final page = pages[value]!;
        if (page.items.isEmpty && inFlight[value] != true) {
          await fetchPage(status: value, firstLoad: true);
        }
      },
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
          actions:
              !loading
                  ? [
                    if(widget.userMode)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        if (shouldSkipIndependenceDayDialog() == false) {
                          showIndependenceDayDialog(context);
                        } else {
                          // Use "all" tab item list to check pending limit
                          final allList = pages['all']!.items;
                          if (!hasReachedMaxPending(
                            allList,
                            AppConfig().maxWithdrawalRequests,
                          )) {
                            final result = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => WithdrawalFormPage(),
                              ),
                            );
                            if (result == true) {
                              // On success: refresh current tab & invalidate others
                              await _resetTab(filter, fetch: true);
                              pages['all'] = PageState<WithdrawalRequest>();
                              pages['approved'] =
                                  PageState<WithdrawalRequest>();
                              pages['rejected'] =
                                  PageState<WithdrawalRequest>();
                              setState(() {});
                              _refreshAllForced();
                            }
                          } else {
                            showMaxPendingDialog(
                              context,
                              AppConfig().maxWithdrawalRequests,
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        // Refresh only active tab + All, using the refined flow
                        await _refreshCurrentTab();
                      },
                    ),
                  ]
                  : [],
        ),
        body:
            loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        buildFilterChip('ALL', 'all'),
                        buildFilterChip('PENDING', 'pending'),
                        buildFilterChip('APPROVED', 'approved'),
                        buildFilterChip('REJECTED', 'rejected'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshCurrentTab,
                        child:
                            visible.isEmpty
                                ? ListView(
                                  children: const [
                                    SizedBox(
                                      height: 200,
                                      child: Center(child: Text('No requests')),
                                    ),
                                  ],
                                )
                                : ListView.builder(
                                  controller: _scrollController,
                                  itemCount:
                                      visible.length +
                                      (current.loadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index < visible.length) {
                                      return buildRequestCard(visible[index]);
                                    }
                                    // Loading footer shimmer/indicator
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
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
