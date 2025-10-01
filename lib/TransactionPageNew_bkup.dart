import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/TransactionCard.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'AppWriteService.dart';
import 'QRService.dart';
import 'TransactionService.dart';
import 'UsersService.dart';
import 'models/QrCode.dart';
import 'models/Transaction.dart';

class TransactionPageNewBkup extends StatefulWidget {
  final String? filterUserId;
  final String? filterQrCodeId;
  final String? userModeUserid;

  final bool userMode;

  const TransactionPageNewBkup({
    super.key,
    this.filterUserId,
    this.filterQrCodeId,
    this.userModeUserid,
    this.userMode = false
  });

  @override
  State<TransactionPageNewBkup> createState() => _TransactionPageNewBkupState();
}

class _TransactionPageNewBkupState extends State<TransactionPageNewBkup> {
  final QrCodeService _qrCodeService = QrCodeService();
  String? _jwtToken;

  List<Transaction> allTransactions = [];
  List<Transaction> transactions = [];

  bool loading = false;

  bool loadingUsers = false;
  bool loadingQr = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];

  String? selectedUserId;
  String? selectedQrCodeId;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    selectedUserId = widget.filterUserId;
    selectedQrCodeId = widget.filterQrCodeId;
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => loading = true);
    _jwtToken = await AppWriteService().getJWT();

    if(widget.userMode){
      if(widget.filterQrCodeId == null){
        fetchOnlyUserQrCodes();
      }
    }else{
      if (widget.filterUserId == null && widget.filterQrCodeId == null) {
        fetchUsersQrCodes();
      }
    }

    if(widget.userMode){
      await fetchUserTransactions();
    }else{
      await fetchTransactions();
    }

    if(!mounted) return;
    setState(() => loading = false);
  }

  // Only Fetches User QrCodes in UserMode
  Future<void> fetchOnlyUserQrCodes() async {
    if(mounted) setState(() {loadingUsers = true;});

    if(mounted) setState(() {loadingQr = true;});
    try{
      qrCodes = await _qrCodeService.getUserQrCodes(widget.userModeUserid!, await AppWriteService().getJWT());
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch User Qr Codes: $e')),
      );
    }
    if(mounted) setState(() {loadingQr = false;});

  }


  Future<void> fetchUsersQrCodes() async {
    if(mounted) setState(() {loadingUsers = true;});

    try {
      final fetched = await UserService.listUsers(jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if(mounted) setState(() {loadingUsers = false;});

    if(mounted) setState(() {loadingQr = true;});
    try{
      qrCodes = await _qrCodeService.getQrCodes(_jwtToken);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Qr Codes: $e')),
      );
    }
    if(mounted) setState(() {loadingQr = false;});

  }

  Future<void> fetchTransactions() async {
    if(!loading && mounted){setState(() => loading = true);}
    try {
      final fetched = await TransactionService.fetchTransactions(userId: widget.filterUserId , qrId: widget.filterQrCodeId, jwtToken: _jwtToken!);
      // allTransactions = fetched; // FIX IT
      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Transactions: $e')),
      );
    }
    if(mounted){setState(() => loading = false);}
  }

  Future<void> fetchUserTransactions() async {
    if(!loading && mounted){setState(() => loading = true);}
    try {
      final fetched = await TransactionService.fetchUserTransactions(userId: widget.userModeUserid! , qrId: widget.filterQrCodeId, jwtToken: _jwtToken!);
      // allTransactions = fetched;
      applyFilters();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Transactions: $e')),
      );
    }
    if(mounted){setState(() => loading = false);}
  }

  void applyFilters() {
    List<Transaction> filtered = allTransactions;

    // If data is already fetched for a specific user from server, don't filter again
    if (widget.filterUserId != null) {
      // Just reverse and display all transactions fetched for the user
      setState(() {
        transactions = filtered.reversed.toList();
      });
      return;
    }

    // Otherwise apply frontend filters based on userId and qrCodeId
    if (selectedUserId != null) {
      final userQrCodeIds = qrCodes
          .where((qr) => qr.assignedUserId == selectedUserId)
          .map((qr) => qr.qrId)
          .whereType<String>()
          .toSet();

      if (selectedQrCodeId != null) {
        filtered = filtered
            .where((txn) => txn.qrCodeId == selectedQrCodeId)
            .toList();
      } else {
        filtered = filtered
            .where((txn) => userQrCodeIds.contains(txn.qrCodeId))
            .toList();
      }
    } else if (selectedQrCodeId != null) {
      filtered = filtered
          .where((txn) => txn.qrCodeId == selectedQrCodeId)
          .toList();
    }

    setState(() {
      transactions = filtered.reversed.toList();
    });
  }

  void resetFilters() {
    selectedUserId = null;
    selectedQrCodeId = null;
    applyFilters();
  }

  List<QrCode> get filteredQrCodes {
    if (selectedUserId == null) return qrCodes;
    return qrCodes.where((qr) => qr.assignedUserId == selectedUserId).toList();
  }

  String formatIndianCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? 'Transactions': 'All Transactions'),
          actions: [
            if (widget.filterUserId == null && widget.filterQrCodeId == null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => !widget.userMode ? fetchTransactions() : fetchUserTransactions(),
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
                        if(!widget.userMode) // if not admin don't show user filter DropDown
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
                              loadingUsers ? CircularProgressIndicator() :DropdownButtonFormField<String>(
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
                                  applyFilters();
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
                              loadingQr ? CircularProgressIndicator() :DropdownButtonFormField<String>(
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
                                  applyFilters();
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
                  return TransactionCard(txn: transactions[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
