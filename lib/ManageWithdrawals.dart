import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'UsersService.dart';
import 'WithdrawService.dart';
import 'WithdrawalFormPage.dart';
import 'models/AppUser.dart';
import 'models/WithdrawalRequest.dart';

class ManageWithdrawals extends StatefulWidget {
  final String? userModeUserid;
  final bool userMode;

  const ManageWithdrawals({super.key, this.userModeUserid, this.userMode = false});

  @override
  State<ManageWithdrawals> createState() => _ManageWithdrawalsState();
}

class _ManageWithdrawalsState extends State<ManageWithdrawals> {
  List<WithdrawalRequest> allRequests = [];
  String filter = 'all'; // all, pending, approved, rejected
  List<AppUser> users = [];
  bool loading = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    fetchWithdrawalData();
  }

  void fetchWithdrawalData(){
    if(!widget.userMode){
      _fetchUsers();
      fetchWithdrawalRequests();
    }else{
      fetchUserWithdrawalRequests();
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => loading = true);
    try {
      // users = await AdminUserService.listUsers(jwtToken: await AppWriteService().getJWT());
      final fetched = await UserService.listUsers(jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if(!mounted) return;
    setState(() => loading = false);
  }

  Future<void> fetchUserWithdrawalRequests() async {
    setState(() => loading = true);
    try {
      final requests = await WithdrawService.fetchUserWithdrawals(widget.userModeUserid!);
      setState(() {
        allRequests = requests;
      });
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch User Withdrawal Requests: $e')),
      );
    }
    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  Future<void> fetchWithdrawalRequests() async {
    setState(() => loading = true);
    try {
      final requests = await WithdrawService.fetchAllWithdrawals(await AppWriteService().getJWT());
      setState(() {
        allRequests = requests;
      });
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Withdrawal Requests: $e')),
      );
    }
    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  AppUser? getUserById(String id) {
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null; // if not found
    }
  }

  String? displayUserNameText(String? appUserId){
    if(appUserId == null){
      return "Unassigned";
    }
    AppUser? user = getUserById(appUserId);
    String displayText = user != null
        ? '${user.name} - ${user.email}' : 'Unknown user';
    return displayText;
  }

  List<WithdrawalRequest> get filteredRequests {
    if (filter == 'all') return allRequests;
    return allRequests.where((r) => r.status?.toLowerCase() == filter).toList();
  }

  Map<String, int> get counts {
    return {
      'all': allRequests.length,
      'pending': allRequests.where((r) => r.status == 'pending').length,
      'approved': allRequests.where((r) => r.status == 'approved').length,
      'rejected': allRequests.where((r) => r.status == 'rejected').length,
    };
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.yellow.shade500;
      case 'approved':
        return Colors.green.shade500;
      case 'rejected':
        return Colors.red.shade500;
      default:
        return Colors.grey.shade100;
    }
  }

  Widget buildFilterChip(String label, String value) {
    final count = counts[value] ?? 0;
    return ChoiceChip(
      label: Text('$label (${count})'),
      selected: filter == value,
      onSelected: (_) => setState(() => filter = value),
    );
  }

  String formatToIST(String istDateTimeString) {
    // Parse the IST string directly as local time
    final dateTime = DateTime.parse(istDateTimeString);

    // Format without adding any extra hours
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

  String formatIndianNumber(num amount) {
    final formatter = NumberFormat.decimalPattern('en_IN');
    return formatter.format(amount);
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
            // Top Row: Amount + Mode + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount & Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatIndianCurrency(r.amount),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      _buildInfoRow("Name", r.holderName),
                      _buildInfoRow('Requested By', displayUserNameText(r.userId) ?? 'Not Available'),
                      _buildInfoRow('QR Id', r.qrId),
                      // Text(
                      //   'Name: ${r.holderName ?? "-"}',
                      //   style: TextStyle(color: Colors.grey[700]),
                      // ),
                    ],
                  ),
                ),
                // Mode & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.mode.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        r.status!.toUpperCase(),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: getStatusColor(r.status!),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1),

            const SizedBox(height: 12),

            // UPI or Bank Details
            if (r.mode == 'upi') ...[
              _buildInfoRow("VPA", r.upiId),
            ] else ...[
              _buildInfoRow("Bank", r.bankName),
              _buildInfoRow("Acc No.", r.accountNumber),
              _buildInfoRow("IFSC", r.ifscCode),
            ],

            const SizedBox(height: 8),

            // Created At
            _buildInfoRow("Created", formatToIST(r.createdAt.toString())),

            // UTR or Rejection Reason
            if (r.status == 'approved' && r.utrNumber?.isNotEmpty == true)
              _buildInfoRow("UTR", r.utrNumber),
            if (r.status == 'rejected' && r.rejectionReason?.isNotEmpty == true)
              _buildInfoRow("Reason", r.rejectionReason),

            const SizedBox(height: 10),

            // Actions
            if (r.status == 'pending' && !widget.userMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _approveRequest(r),
                    icon: Icon(Icons.check, size: 16, color: Colors.white,),
                    label: Text('Approve', style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(context, r),
                    icon: Icon(Icons.close, size: 16, color: Colors.white,),
                    label: Text('Reject', style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(WithdrawalRequest request) async {
    final utrCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    String rupees(num p) => formatIndianCurrency(p);

    final utr = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          String? validate(String? v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'UTR number is required';
            if (s.length < 8) return 'UTR must be at least 8 characters';
            if (!RegExp(r'^[A-Za-z0-9-_/]+$').hasMatch(s)) {
              return 'Only letters, numbers and - _ / are allowed';
            }
            return null;
          }

          final valid = validate(utrCtrl.text) == null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Approve Withdrawal'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recap
                  Container(
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
                    controller: utrCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'UTR Number',
                      hintText: 'Enter bank UTR',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (utrCtrl.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setLocal(() => utrCtrl.clear()),
                            ),
                          IconButton(
                            tooltip: 'Paste',
                            icon: const Icon(Icons.content_paste),
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null) {
                                setLocal(() => utrCtrl.text = data!.text!.trim());
                              }
                            },
                          ),
                        ],
                      ),
                      helperText: 'Min 8 chars; letters/numbers allowed',
                    ),
                    validator: validate,
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
                  final (success, message) = await WithdrawService.approveWithdrawal(
                  jwtToken: await AppWriteService().getJWT(),
                  requestId: request.id!,
                  utrNumber: utrCtrl.text.trim(),
                  );
                  if (context.mounted) {
                  Navigator.pop(ctx, success ? utrCtrl.text.trim() : null);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  if (success) fetchWithdrawalRequests();
                  }
                  } catch (e) {
                  if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        });
      },
    );

    // no-op; handled inside dialog
  }

  void _showRejectDialog(BuildContext context, WithdrawalRequest request) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          String? validate(String? v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'Reason is required';
            if (s.length < 4) return 'Minimum 4 characters required';
            return null;
          }

          final valid = validate(reasonCtrl.text) == null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Reject Withdrawal'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Reason for rejection',
                  hintText: 'Provide a clear reason (will be visible to requester)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.comment_outlined),
                  suffixIcon: reasonCtrl.text.isNotEmpty
                      ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setLocal(() => reasonCtrl.clear()),
                  )
                      : null,
                  helperText: 'Minimum 4 characters',
                ),
                validator: validate,
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
                  final (success, message) = await WithdrawService.rejectWithdrawal(
                  jwtToken: await AppWriteService().getJWT(),
                  requestId: request.id!,
                  reason: reasonCtrl.text.trim(),
                  );
                  if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  if (success) fetchWithdrawalRequests();
                  }
                  } catch (e) {
                  if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        });
      },
    );
  }

  bool shouldSkipIndependenceDayDialog() {
    print("shouldSkipIndependenceDayDialog");
    final now = DateTime.now();
    // Check if today is 15 August
    if (now.month == 8 && now.day == 15) {
      // It's Independence Day → DO NOT skip the dialog
      return false;
    }
    // Any other day → SKIP showing dialog
    return true;
  }

  void showIndependenceDayDialog(BuildContext context) {
    final now = DateTime.now();

    // Check if today is 15 August
    if (now.month == 8 && now.day == 15) {
      // Show the dialog only on 15th August
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Notice"),
          content: const Text(
              "On the occasion of 15th August (Independence Day), "
                  "withdrawals will not be processed."
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
        if (pendingCount >= maxPending) {
          return true; // already at or above the max
        }
      }
    }
    return false;
  }

  Future<void> showMaxPendingDialog(BuildContext context, int maxPending) async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        // appBar: AppBar(title: const Text('Withdrawal Requests',)),
        appBar: AppBar(
          title: const Text('Withdrawal Requests'),
          actions: !loading ? [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if(shouldSkipIndependenceDayDialog() == false){
                  showIndependenceDayDialog(context);
                }else{
                  if (!hasReachedMaxPending(allRequests, AppConfig().maxWithdrawalRequests)) {
                    Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                    ).then((result) {
                      if (result == true) {
                        // ✅ Success callback
                        fetchWithdrawalData(); // for example, reload the list
                      }
                    });
                  } else {
                    showMaxPendingDialog(context, AppConfig().maxWithdrawalRequests);
                  }
                }
              },
            ),
            if(!widget.userMode)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: !loading ? fetchWithdrawalRequests : null,
              ),
            if(widget.userMode)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: !loading ? fetchUserWithdrawalRequests : null,
              ),
            // IconButton(
            //   icon: const Icon(Icons.refresh),
            //   onPressed: () => fetchWithdrawalRequests(),
            // ),
          ] : [],
        ),
          body: loading
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
                onRefresh: fetchWithdrawalRequests,
                child: filteredRequests.isEmpty
                    ? const Center(child: Text('No requests'))
                    : ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    return buildRequestCard(filteredRequests[index]);
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
