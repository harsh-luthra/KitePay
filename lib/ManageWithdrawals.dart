import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'WithdrawService.dart';
import 'WithdrawalFormPage.dart';
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

  bool loading = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    if(!widget.userMode){
      fetchWithdrawalRequests();
    }else{
      fetchUserWithdrawalRequests();
    }
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
                      _buildInfoRow("Name: ", r.holderName),
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
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(context, r),
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Reject'),
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

  void _approveRequest(WithdrawalRequest request) async {
    final TextEditingController _utrController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter UTR Number'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _utrController,
            decoration: InputDecoration(labelText: 'UTR Number'),
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
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, _utrController.text.trim());
              }
            },
            child: Text('Approve'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {

      final (success, message) = await WithdrawService.approveWithdrawal(
          jwtToken: await AppWriteService().getJWT(),
          requestId: request.id!,
          utrNumber: result,
      );

      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
      );

      if (success) fetchWithdrawalRequests();

    }
  }

  void _showRejectDialog(BuildContext context, WithdrawalRequest request) {
    final TextEditingController _reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Withdrawal'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _reasonController,
            decoration: InputDecoration(labelText: 'Reason for rejection'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Reason is required';
              }
              if (value.trim().length < 4) {
                return 'Minimum 4 characters required';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
              final (success, message) = await WithdrawService.rejectWithdrawal(
                  jwtToken: await AppWriteService().getJWT(),
                  requestId: request.id!,
                  reason: _reasonController.text.trim(),
                );
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

                if (success) fetchWithdrawalRequests();

              }
            },
            child: Text('Reject'),
          ),
        ],
      ),
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
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => WithdrawalFormPage()),
                  );
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
