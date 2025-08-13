import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'QRService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';

class TransactionsPageOld extends StatefulWidget {
  final String? userId;
  final String? qrId;

  const TransactionsPageOld({super.key, this.userId, this.qrId});

  @override
  State<TransactionsPageOld> createState() => _TransactionsPageOldState();
}

class _TransactionsPageOldState extends State<TransactionsPageOld> {
  final QrCodeService _qrCodeService = QrCodeService();
  String? _jwtToken; // Placeholder for the JWT token

  List<Map<String, dynamic>> transactions = [];
  // List<Map<String, dynamic>> users = [];
  // List<Map<String, dynamic>> qrCodes = [];

  List<QrCode> qrCodes = [];
  List<AppUser> users = [];

  String? selectedUserId;
  String? selectedQrId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedUserId = widget.userId;
    selectedQrId = widget.qrId;
    fetchDropdownData();
    fetchTransactions();
  }

  Future<void> fetchDropdownData() async {
    _jwtToken = await AppWriteService().getJWT();
    // Replace with your actual API logic
    final fetchedUsers = await AdminUserService.listUsers(await AppWriteService().getJWT());
    final fetchedQRCodes = await _qrCodeService.getQrCodes(_jwtToken);
    setState(() {
      users = fetchedUsers;
      qrCodes = fetchedQRCodes;
    });
  }

  Future<void> fetchTransactions() async {
    setState(() => isLoading = true);
    final data = await fetchTransactionsFromAPI(
      userId: selectedUserId,
      qrId: selectedQrId,
    );
    setState(() {
      transactions = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: buildUserDropdown()),
                const SizedBox(width: 8),
                Expanded(child: buildQrDropdown()),
                IconButton(
                  onPressed: fetchTransactions,
                  icon: const Icon(Icons.search),
                )
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (transactions.isEmpty)
            const Expanded(child: Center(child: Text("No transactions found")))
          else
            Expanded(child: buildTransactionList()),
        ],
      ),
    );
  }

  Widget buildUserDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(labelText: "Filter by User"),
      value: selectedUserId,
      items: [
        const DropdownMenuItem(value: null, child: Text("All Users")),
        ...users.map((u) => DropdownMenuItem(
          value: u.id,
          child: Text(u.name ?? u.email ?? u.id),
        )),
      ],
      onChanged: (val) {
        setState(() => selectedUserId = val);
      },
    );
  }

  Widget buildQrDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(labelText: "Filter by QR Code"),
      value: selectedQrId,
      items: [
        const DropdownMenuItem(value: null, child: Text("All QR Codes")),
        ...qrCodes.map((qr) => DropdownMenuItem(
          value: qr.qrId,
          child: Text(qr.qrId),
        )),
      ],
      onChanged: (val) {
        setState(() => selectedQrId = val);
      },
    );
  }

  Widget buildTransactionList() {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final createdAt = DateFormat('dd MMM yyyy, hh:mm a').format(
            DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now());
        return ListTile(
          title: Text('₹${(tx['amount'] ?? 0) / 100} - ${tx['vpa'] ?? "VPA"}'),
          subtitle: Text('QR: ${tx['qrCodeId']} | RRN: ${tx['rrnNumber'] ?? "-"}'),
          trailing: Text(createdAt),
        );
      },
    );
  }

  // Mock placeholders
  Future<List<Map<String, dynamic>>> fetchUsersFromAPI() async => [];
  Future<List<Map<String, dynamic>>> fetchQRCodesFromAPI() async => [];
  Future<List<Map<String, dynamic>>> fetchTransactionsFromAPI({
    String? userId,
    String? qrId,
  }) async => [];

}
