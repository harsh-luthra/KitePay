import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'AppWriteService.dart';
import 'QRService.dart';
import 'TransactionService.dart';
import 'UsersService.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

class TransactionPage extends StatefulWidget {
  final String? filterUserId;
  final String? filterQrCodeId;

  const TransactionPage({
    super.key,
    this.filterUserId,
    this.filterQrCodeId,
  });

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final QrCodeService _qrCodeService = QrCodeService();
  String? _jwtToken; // Placeholder for the JWT token

  List<Transaction> allTransactions = []; // All fetched once
  List<Transaction> transactions = []; // Filtered version for display

  bool loading = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];
  List<QrCode> userQrCodes = []; // Filtered based on selectedUser

  String? selectedUserId;
  String? selectedQrCodeId;

  @override
  void initState() {
    super.initState();
    selectedUserId = widget.filterUserId;
    selectedQrCodeId = widget.filterQrCodeId;
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => loading = true);
    _jwtToken = await AppwriteService().getJWT();
    if (widget.filterUserId == null && widget.filterQrCodeId == null) {
      // Only load users/qrCodes if filters are not pre-set
      users = await AdminUserService.listUsers(_jwtToken!);
      qrCodes = await _qrCodeService.getQrCodes(_jwtToken);
    }

    await loadTransactions();
    setState(() => loading = false);
  }

  Future<void> loadTransactions() async {
    transactions = await TransactionService.fetchTransactions(
      userId: selectedUserId,
      qrId: selectedQrCodeId,
      jwtToken: _jwtToken!
    );
    transactions = transactions.reversed.toList();
    setState(() {});
  }

  void resetFilters() {
    selectedUserId = null;
    selectedQrCodeId = null;
    loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          if (widget.filterUserId == null && widget.filterQrCodeId == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadTransactions,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (widget.filterUserId == null && widget.filterQrCodeId == null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Filter User',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedUserId,
                              hint: const Text('Select User'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('--------'),
                                ),
                                ...users.map((user) => DropdownMenuItem(
                                  value: user.id,
                                  child: Text(user.name),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedUserId = value;
                                  selectedQrCodeId = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Filter QR Code',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedQrCodeId,
                              hint: const Text('Select QR Code'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('--------'),
                                ),
                                ...filteredQrCodes.map((qr) => DropdownMenuItem(
                                  value: qr.qrId,
                                  child: Text(qr.qrId ?? qr.assignedUserId ?? ''),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedQrCodeId = value;
                                });

                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (selectedUserId != null && !userHasQrCodes)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'No QR codes assigned to this user.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions found.'))
            : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount: ₹${txn.amount / 100}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('QR Code ID: ${txn.qrCodeId}'),
                        Text('Payment ID: ${txn.paymentId}'),
                        Text('RRN Number: ${txn.rrnNumber}'),
                        Text('VPA: ${txn.vpa}'),
                        Text('Created At: ${txn.createdAt.toLocal()}'),
                        Text('Transaction ID: ${txn.id}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QrCode> get filteredQrCodes {
    if (selectedUserId == null) return qrCodes;
    return qrCodes.where((qr) => qr.assignedUserId == selectedUserId).toList();
  }


}
