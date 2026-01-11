import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:admin_qr_manager/WalletService.dart';
import '../models/Wallet.dart';
import '../models/WalletTransaction.dart';
import 'AppWriteService.dart';

class WalletRechargePage extends StatefulWidget {
  const WalletRechargePage({super.key});

  @override
  _WalletRechargePageState createState() => _WalletRechargePageState();
}

class _WalletRechargePageState extends State<WalletRechargePage> {
  Wallet? wallet;
  PaginatedWalletTransactions? transactionsData;
  bool isLoadingTransactions = true;
  bool isLoadingBalance = true;
  bool isRecharging = false;

  // bool showQR = false;
  // String? qrBase64;
  String? currentTransactionId;
  int expirySeconds = 0;
  Timer? _timer;
  String? nextCursor;
  bool hasMoreTransactions = true;

  int? qrExpirySeconds;
  bool _showingQRDialog = false;

  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([fetchBalance(), fetchTransactions()]);
    // await Future.wait([fetchBalance()]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> fetchBalance() async {
    try {
      setState(() => isLoadingBalance = true);
      wallet = await WalletService.getBalance(
        jwtToken: await AppWriteService().getJWT(),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load balance')));
    } finally {
      if (mounted) setState(() => isLoadingBalance = false);
    }
  }

  Future<void> fetchTransactions() async {
    try {
      setState(() => isLoadingTransactions = true);
      final data = await WalletService.getWalletTransactions(
        jwtToken: await AppWriteService().getJWT(),
        cursor: nextCursor,
      );
      setState(() {
        transactionsData = data;
        nextCursor = data.nextCursor;
        hasMoreTransactions = data.nextCursor != null;
        isLoadingTransactions = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load transactions')));
      setState(() => isLoadingTransactions = false);
    }
  }

  Future<void> loadMoreTransactions() async {
    if (!hasMoreTransactions || isLoadingTransactions) return;

    try {
      final data = await WalletService.getWalletTransactions(
        jwtToken: await AppWriteService().getJWT(),
        cursor: nextCursor,
      );
      setState(() {
        transactionsData?.transactions.addAll(data.transactions);
        nextCursor = data.nextCursor;
        hasMoreTransactions = data.nextCursor != null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more transactions')),
      );
    }
  }

  String formatIndianCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  void _showRechargeDialog() {
    _amountController.clear();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Recharge Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[1-9][0-9]*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [100, 200, 500, 1000, 2000, 5000]
                          .map(
                            (amt) => ElevatedButton(
                              onPressed:
                                  () => _amountController.text = amt.toString(),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: Size(80, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                '₹$amt',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(_amountController.text);
                  if (amt != null && amt >= 10) {
                    Navigator.pop(context);
                    _initiateRecharge(amt);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enter amount ≥ ₹10')),
                    );
                  }
                },
                child: Text('Pay Now'),
              ),
            ],
          ),
    );
  }

  Future<void> _initiateRecharge(double amount) async {
    setState(() => isRecharging = true);
    try {
      final response = await WalletService.recharge(
        jwtToken: await AppWriteService().getJWT(),
        amount: amount,
      );

      _showQRDialogNonDismissible(
        qrBase64: response.qrBase64,
        transactionId: response.transactionId,
        expirySeconds: response.expirySeconds,
        amount: amount,  // 🔥 Pass amount
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recharge failed: $e')));
    } finally {
      setState(() => isRecharging = false);
    }
  }


  // void _startTimer() {
  //   _timer?.cancel();
  //   _timer = Timer.periodic(Duration(seconds: 1), (timer) {
  //     if (expirySeconds > 0) {
  //       setState(() => expirySeconds--);
  //     } else {
  //       timer.cancel();
  //       setState(() => showQR = false);
  //       fetchBalance(); // Refresh balance
  //       fetchTransactions(); // Refresh transactions
  //     }
  //   });
  // }

  // Future<void> _cancelQR() async {
  //   if (currentTransactionId == null) return;
  //   try {
  //     await WalletService.cancelRecharge(
  //       jwtToken: await AppWriteService().getJWT(),
  //       transactionId: currentTransactionId!,
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Cancel failed')));
  //   }
  //   setState(() {
  //     showQR = false;
  //     qrBase64 = null;
  //     currentTransactionId = null;
  //   });
  //   _timer?.cancel();
  // }

  Future<void> _showQRDialogNonDismissible({
    required String qrBase64,
    required String transactionId,
    required int expirySeconds,
    required double amount,
  }) async {
    String cleanBase64 = qrBase64;
    if (cleanBase64.startsWith('data:image/png;base64,')) {
      cleanBase64 = cleanBase64.substring('data:image/png;base64,'.length);
    }
    final imageBytes = base64Decode(cleanBase64);

    currentTransactionId = transactionId;
    qrExpirySeconds = expirySeconds;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        int localExpirySeconds = expirySeconds;
        Timer? dialogTimer;

        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              if (dialogTimer == null && localExpirySeconds > 0) {
                dialogTimer = Timer.periodic(Duration(seconds: 1), (timer) {
                  if (localExpirySeconds > 0) {
                    localExpirySeconds--;
                    setDialogState(() {});
                    if (mounted) setState(() => qrExpirySeconds = localExpirySeconds);
                  } else {
                    timer.cancel();
                    dialogTimer = null;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      _onQRExpired();
                    }
                  }
                });
              }

              final timeLeft = Duration(seconds: localExpirySeconds);
              return Dialog(
                insetPadding: EdgeInsets.all(20), // 🔥 Back to uniform compact padding
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                  child: SingleChildScrollView(
                    child: Container(
                      width: 400,
                      // 🔥 REMOVED: width: double.infinity, constraints: BoxConstraints(maxWidth: 400)
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(blurRadius: 30, color: Colors.black26)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header (compact)
                          Container(
                            padding: EdgeInsets.all(14), // 🔥 Slightly reduced
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pay to Kitepay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                      // Text('yourapp.com', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Text(formatIndianCurrency(amount), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // QR Code
                          Container(
                            width: 220,
                            height: 220,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!, width: 1),
                            ),
                            child: Image.memory(imageBytes, fit: BoxFit.contain),
                          ),
                          SizedBox(height: 12),

                          // Amount
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Amount', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                                Text(formatIndianCurrency(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),

                          // Timer
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, color: Colors.orange[700], size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '${timeLeft.inMinutes.toString().padLeft(2, '0')}:${(timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                ),
                                Text(' remaining', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // Red Cancel Button (compact width)
                          SizedBox(
                            width: double.infinity, // 🔥 Fits container naturally
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[500]!,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _showCancelConfirmation(dialogContext, dialogTimer),
                              child: Text('Cancel Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SizedBox(height: 12),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Scan with GPay, PhonePe or any UPI app',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ).then((_) => setState(() => _showingQRDialog = false));
  }



  Future<void> _cancelQRDialog(BuildContext dialogContext, Timer? qrTimer) async {
    // 1. Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          contentPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Cancelling transaction...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                currentTransactionId!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 2. Cancel QR timer
      qrTimer?.cancel();

      // 3. Call cancel API
      await WalletService.cancelRecharge(
        jwtToken: await AppWriteService().getJWT(),
        transactionId: currentTransactionId!,
      );

      print('✅ Transaction cancelled successfully');
    } catch (e) {
      print('❌ Cancel API failed: $e');
      // Don't throw - user already sees success
    } finally {
      // 4. Close BOTH dialogs (loading + QR)
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(); // Close QR dialog
      }

      // 5. Reset state
      setState(() {
        currentTransactionId = null;
        qrExpirySeconds = null;
        _showingQRDialog = false;
      });

      // 6. Refresh data
      await Future.wait([fetchBalance(), fetchTransactions()]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction cancelled'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  void _onQRExpired() {
    setState(() {
      currentTransactionId = null;
      qrExpirySeconds = null;
    });
    fetchBalance();
    fetchTransactions();
  }

  Future<void> _showCancelConfirmation(
      BuildContext dialogContext,
      Timer? qrTimer
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            SizedBox(width: 12),
            Text('Confirm Cancel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this recharge?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '₹${_amountController.text} will not be added to your wallet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // No
            child: Text('Continue Payment', style: TextStyle(color: Colors.green[700])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Yes
            child: Text('Cancel Payment', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // If confirmed, proceed with cancel
    if (confirmed == true) {
      _cancelQRDialog(dialogContext, qrTimer);
    }
  }


  // Widget _buildQRSection() {
  //   if (!showQR || qrBase64 == null) return SizedBox();
  //
  //   // 🔥 CRITICAL: Remove data URI prefix
  //   String cleanBase64 = qrBase64!;
  //   if (cleanBase64.startsWith('data:image/png;base64,')) {
  //     cleanBase64 = cleanBase64.substring('data:image/png;base64,'.length);
  //   } else if (cleanBase64.startsWith('data:image;base64,')) {
  //     cleanBase64 = cleanBase64.substring('data:image;base64,'.length);
  //   }
  //
  //   final imageBytes = base64Decode(cleanBase64); // ✅ Now works!
  //
  //   final timeLeft = Duration(seconds: expirySeconds);
  //   return Container(
  //     padding: EdgeInsets.all(16),
  //     margin: EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
  //     ),
  //     child: Column(
  //       children: [
  //         Image.memory(imageBytes, height: 250, width: 250),
  //         SizedBox(height: 16),
  //         Text(
  //           '${timeLeft.inMinutes}:${(timeLeft.inSeconds % 60)
  //               .toString()
  //               .padLeft(2, '0')}',
  //           style: Theme
  //               .of(context)
  //               .textTheme
  //               .headlineMedium
  //               ?.copyWith(color: Colors.red),
  //         ),
  //         SizedBox(height: 16),
  //         ElevatedButton(
  //           onPressed: _cancelQR,
  //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //           child: Text('Cancel'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([fetchBalance(), fetchTransactions()]),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Balance Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Wallet Balance',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    if (isLoadingBalance)
                      CircularProgressIndicator()
                    else
                      Text(
                        formatIndianCurrency(wallet?.balance ?? 0),
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    SizedBox(height: 4),
                    if (wallet != null)
                      Text(
                        'Available: ${formatIndianCurrency(wallet!.availableBalance)}',
                        style: TextStyle(fontSize: 14, color: Colors.green),
                      ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed:
                            isRecharging || isLoadingBalance
                                ? null
                                : _showRechargeDialog,
                        child: Text(
                          isRecharging ? 'Processing...' : 'Recharge',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // _buildQRSection(),
              // Transactions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: fetchTransactions,
                          child: Text('Refresh'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    if (isLoadingTransactions)
                      Center(child: CircularProgressIndicator())
                    else if ((transactionsData?.transactions ?? []).isEmpty)
                      Center(child: Text('No transactions found'))
                    else
                      Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: transactionsData!.transactions.length,
                            itemBuilder: (context, index) {
                              final txn = transactionsData!.transactions[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(
                                      txn.status,
                                    ),
                                    child: Icon(
                                      txn.isCredit
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                    ),
                                  ),
                                  title: Text(
                                    txn.type
                                        .toString()
                                        .split('.')
                                        .last
                                        .toUpperCase(),
                                  ),
                                  subtitle: Text(
                                    '${txn.status.toString().split('.').last.toUpperCase()} • ${DateFormat('MMM dd').format(txn.createdAt.toLocal())}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatIndianCurrency(txn.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              txn.isCredit
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (txn.commission != null)
                                        Text(
                                          'Comm: ₹${txn.commission!.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (hasMoreTransactions)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: ElevatedButton(
                                onPressed: loadMoreTransactions,
                                child: Text('Load More'),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(WalletTransactionStatus status) {
    switch (status) {
      case WalletTransactionStatus.success:
        return Colors.green;
      case WalletTransactionStatus.failed:
        return Colors.red;
      case WalletTransactionStatus.cancelled:
      case WalletTransactionStatus.expired:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
