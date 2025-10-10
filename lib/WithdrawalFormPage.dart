import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/MyMetaApi.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/models/WithdrawalRequest.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:flutter/material.dart';

import 'AppConfig.dart';
import 'QRService.dart';
import 'WithdrawService.dart';
import 'models/QrCode.dart';

class WithdrawalFormPage extends StatefulWidget {
  const WithdrawalFormPage({super.key});

  @override
  State<WithdrawalFormPage> createState() => _WithdrawalFormPageState();
}

class _WithdrawalFormPageState extends State<WithdrawalFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _mode = 'upi'; // 'upi' or 'bank'

  final maxWithdrawalAmount = AppConfig().maxWithdrawalAmount;
  final minWithdrawalAmount = AppConfig().minWithdrawalAmount;
  final overheadBalanceRequired = AppConfig().overheadBalanceRequired;

  // Common
  final _amountController = TextEditingController();

  // UPI
  final _upiIdController = TextEditingController();
  final _upiHolderNameController = TextEditingController();

  // Bank
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankHolderNameController = TextEditingController();
  final _bankNameController = TextEditingController();

  bool _isSubmitting = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<
      ScaffoldMessengerState>();

  final QrCodeService _qrCodeService = QrCodeService();
  List<QrCode> _qrCodesAssignedToMe = [];
  bool _isLoadingUserQrs = true;

  // 🔹 Global selected QR (can be accessed anywhere)
  QrCode? selectedQrCode;

  late AppUser UserMeta;
  double subAdminCommission = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    UserMeta = MyMetaApi.current!;
    subAdminCommission = UserMeta.commission!;
    // print(subAdminCommission);
    _fetchOnlyUserQrCodes();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiIdController.dispose();
    _upiHolderNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankHolderNameController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchOnlyUserQrCodes() async {
    if (mounted) {
      setState(() {
        _isLoadingUserQrs = true;
      });
    }

    try {
      final codes = await _qrCodeService.getUserAssignedQrCodes(
          await AppWriteService().getUserId()!, await AppWriteService().getJWT());
      setState(() {
        List<QrCode> qrCodesFetched = codes;
        _qrCodesAssignedToMe = qrCodesFetched.where((q) => (q.assignedUserId ?? '').toLowerCase() == UserMeta.id).toList();
      });
      if (_qrCodesAssignedToMe.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print("Loaded User Qr codes");
            _showQrSelectionDialog();
          }
        });
      }else{
        _showNoQrDialog();
      }
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch User Qr Codes: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isLoadingUserQrs = false;
    });
  }

  void _showQrSelectionDialog() {
    final controller = TextEditingController();
    QrCode? tempSelection = selectedQrCode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (alertContext) {
        List<QrCode> filtered = List.from(_qrCodesAssignedToMe);
        void applyFilter(String query) {
          setState(() {}); // if you want outer page to rebuild; otherwise skip
        }

        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setLocal) {
              List<QrCode> list = _qrCodesAssignedToMe;

              // filter by query
              final q = controller.text.trim().toLowerCase();
              if (q.isNotEmpty) {
                list = list.where((qr) {
                  final id = (qr.qrId ?? '').toLowerCase();
                  final assigned = (qr.assignedUserId ?? '').toLowerCase();
                  return id.contains(q) || assigned.contains(q);
                }).toList();
              }

              // sort: active first, then by available desc
              list.sort((a, b) {
                final aActive = a.isActive ? 0 : 1;
                final bActive = b.isActive ? 0 : 1;
                if (aActive != bActive) return aActive - bActive;
                final aAvail = (a.amountAvailableForWithdrawal ?? 0);
                final bAvail = (b.amountAvailableForWithdrawal ?? 0);
                return bAvail.compareTo(aAvail);
              });

              String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);
              String count(num n) => CurrencyUtils.formatIndianCurrencyWithoutSign(n);

              Widget metricChip(String label, String value, Color color, IconData icon) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(fontSize: 11, color: color)),
                      const SizedBox(width: 4),
                      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }

              Widget selectionSubtitle(QrCode qr) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          metricChip('Txns', count(qr.totalTransactions ?? 0), Colors.teal, Icons.receipt_long),
                          metricChip('Today', inr(qr.todayTotalPayIn ?? 0), Colors.indigo, Icons.today),
                          metricChip('Received', inr(qr.totalPayInAmount ?? 0), Colors.deepPurple, Icons.account_balance_wallet),
                          metricChip('Available', inr(qr.amountAvailableForWithdrawal ?? 0), Colors.green, Icons.savings),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          metricChip('Pending Req', inr(qr.withdrawalRequestedAmount ?? 0), Colors.orange, Icons.pending_actions),
                          metricChip('Approved', inr(qr.withdrawalApprovedAmount ?? 0), Colors.blueGrey, Icons.verified),
                          metricChip('Comm On-Hold', inr(qr.commissionOnHold ?? 0), Colors.amber.shade800, Icons.lock_clock),
                          metricChip('Comm Paid', inr(qr.commissionPaid ?? 0), Colors.cyan.shade700, Icons.payments),
                          metricChip('Amt On-Hold', inr(qr.amountOnHold ?? 0), Colors.red.shade600, Icons.lock),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Select QR Code for Withdrawal Request'),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search row
                      // TextField(
                      //   controller: controller,
                      //   decoration: InputDecoration(
                      //     isDense: true,
                      //     prefixIcon: const Icon(Icons.search),
                      //     hintText: 'Search by QR ID or Assigned User',
                      //     suffixIcon: controller.text.isNotEmpty
                      //         ? IconButton(
                      //       icon: const Icon(Icons.clear),
                      //       onPressed: () {
                      //         controller.clear();
                      //         setLocal(() {});
                      //       },
                      //     )
                      //         : null,
                      //     border: const OutlineInputBorder(),
                      //   ),
                      //   onChanged: (_) => setLocal(() {}),
                      //   onSubmitted: (_) => setLocal(() {}),
                      // ),
                      // const SizedBox(height: 10),

                      // List
                      Flexible(
                        child: Scrollbar(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final qr = list[index];
                              final selected = tempSelection?.qrId == qr.qrId;
                              final statusColor = qr.isActive ? Colors.green : Colors.red;

                              return InkWell(
                                onDoubleTap: () {
                                  tempSelection = qr;
                                  // commit selection
                                  setState(() => selectedQrCode = tempSelection);
                                  Navigator.pop(context);
                                  _scaffoldMessengerKey.currentState?.showSnackBar(
                                    SnackBar(content: Text('✅ Selected QR: ${qr.qrId}')),
                                  );
                                },
                                onTap: () => setLocal(() => tempSelection = qr),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: statusColor,
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(qr.isActive ? Icons.qr_code_sharp : Icons.qr_code_sharp, size: 25, color: statusColor),
                                      SizedBox(width: 20,),
                                      Text(
                                        qr.qrId ?? '(no id)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: selected ? Theme.of(context).colorScheme.primary : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: selectionSubtitle(qr),
                                  // subtitle: Padding(
                                  //   padding: const EdgeInsets.only(top: 6),
                                  //   child: Wrap(
                                  //     spacing: 8,
                                  //     runSpacing: 6,
                                  //     children: [
                                  //       metricChip('Txns', count(qr.totalTransactions ?? 0), Colors.teal, Icons.receipt_long),
                                  //       metricChip('Received', inr(qr.totalPayInAmount ?? 0), Colors.indigo, Icons.account_balance_wallet),
                                  //       metricChip('Available', inr(qr.amountAvailableForWithdrawal ?? 0), Colors.green, Icons.savings),
                                  //       Container(
                                  //         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  //         decoration: BoxDecoration(
                                  //           color: (qr.isActive ? Colors.green : Colors.red).withOpacity(0.08),
                                  //           borderRadius: BorderRadius.circular(12),
                                  //         ),
                                  //         child: Text(
                                  //           qr.isActive ? 'ACTIVE' : 'INACTIVE',
                                  //           style: TextStyle(
                                  //             fontSize: 11,
                                  //             fontWeight: FontWeight.w600,
                                  //             color: statusColor,
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                  trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                                  selected: selected,
                                  selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                                  iconColor: statusColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(alertContext).pop();
                      Navigator.pop(context, true);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: tempSelection == null
                        ? null
                        : () {
                      setState(() => selectedQrCode = tempSelection);
                      Navigator.pop(context);
                      _scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('✅ Selected QR: ${selectedQrCode?.qrId}')),
                      );
                    },
                    label: const Text('Select'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  void _showNoQrDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "No QR Codes Found",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "You don’t have any QR codes linked to your account yet. "
                "Please contact support or an admin to get one before making withdrawals.",
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

  Future<void> showResultDialog(
      BuildContext context, {
        required String title,
        required String message,
        required bool success,
      }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // force OK
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, success); // close dialog
                if (success) {
                  Navigator.pop(context, success); // also close page
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = await AppWriteService().account.get();
    String userId = user.$id;
    String name = user.name;

    if (_mode == 'upi') {
      name = _upiHolderNameController.text.trim();
    } else {
      name = _bankHolderNameController.text.trim();
    }

    final int requestedAmount = int.tryParse(_amountController.text.trim()) ?? 0;
    final double commissionPercent = subAdminCommission ?? 0;
    final double commissionRaw = requestedAmount * commissionPercent / 100;
    final int commissionAmount = commissionRaw.ceil(); // always rounds up
    final int netWithdrawalAmount = requestedAmount + commissionAmount;

    bool proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Withdrawal amount: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(requestedAmount as num)}"),
              Text("Commission (${commissionPercent.toStringAsFixed(1)}%): ₹$commissionAmount"),
              Divider(thickness: 1),
              Text("Final credited amount: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(netWithdrawalAmount as num)}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm Withdrawal'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!proceed) return;

    setState(() => _isSubmitting = true);

    try {
      // Compose the request as in your code
      final withdrawalRequest = WithdrawalRequest(
        userId: userId,
        qrId: selectedQrCode?.qrId,
        holderName: name,
        amount: netWithdrawalAmount,
        preAmount: requestedAmount,
        commission: commissionAmount,
        mode: _mode,
        upiId: _mode == 'upi' ? _upiIdController.text.trim() : null,
        bankName: _mode == 'bank' ? _bankNameController.text.trim() : null,
        accountNumber: _mode == 'bank' ? _accountNumberController.text.trim() : null,
        ifscCode: _mode == 'bank' ? _ifscCodeController.text.trim().toUpperCase() : null,
      );

      await WithdrawService.fetchWithdrawCommissionPreview(userId: UserMeta.id,qrId: selectedQrCode!.qrId,preAmount: requestedAmount.toDouble());

      final success = await WithdrawService.submitWithdrawRequest(withdrawalRequest);

      if (success) {
        _formKey.currentState!.reset();
        await showResultDialog(
          context,
          title: "✅ Success",
          message: "Withdrawal request submitted successfully.",
          success: true,
        );
      } else {
        await showResultDialog(
          context,
          title: "❌ Failed",
          message: "Failed to submit withdrawal request.",
          success: false,
        );
      }
    } catch (e) {
      await showResultDialog(
        context,
        title: "❌ Error",
        message: "Error submitting withdrawal: ${e.toString()}",
        success: false,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _submitFormNew() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final user = await AppWriteService().account.get();
    String userId = user.$id;

    String name = _mode == 'upi' ? _upiHolderNameController.text.trim() : _bankHolderNameController.text.trim();

    final int requestedAmount = int.tryParse(_amountController.text.trim()) ?? 0;

    try {
      final preview = await WithdrawService.fetchWithdrawCommissionPreview(
        userId: userId,
        qrId: selectedQrCode!.qrId,
        preAmount: requestedAmount.toDouble(),
      );

      print(preview);

      if (preview == null) {
        await showResultDialog(
          context,
          title: "❌ Error",
          message: "Failed to fetch commission preview.",
          success: false,
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (preview.containsKey('error')) {
        String errorMsg = preview['error'] ?? "Unknown error";

        if (errorMsg.toLowerCase().contains('exceeds')) {
          final preAmountPaise = preview['preAmountPaise'] ?? 0;
          final commissionRate = preview['commissionRate'] ?? 0;
          final commissionPaise = preview['commissionPaise'] ?? 0;
          final overheadPaise = preview['overheadPaise'] ?? 0;
          final available = preview['amountAvailableForWithdrawal'] ?? 0;
          final required = preview['withdrawalToCheck'] ?? 0;

          errorMsg +=
              "\nRequested: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(preAmountPaise / 100)}" +
                  "\nCommission $commissionRate% : ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(commissionPaise / 100)}" +
                  "\nOverhead: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(overheadPaise / 100)}" +
                  "\nAvailable Balance: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(available / 100)}"+
                  "\nbalance Required: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(required / 100)}";
        }

        await showResultDialog(
          context,
          title: "❌ Error",
          message: errorMsg,
          success: false,
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final double commissionPercent = preview['commissionRate'];
      final int commissionAmount = preview['commissionRs'];
      final int netWithdrawalAmount = requestedAmount + commissionAmount;

      // Optional: show error details (like excess amounts) if provided
      if (preview.containsKey('error') && preview['error'].contains('exceeds')) {
        await showResultDialog(
          context,
          title: "❌ Error",
          message: preview['error'] +
              "\nRequested: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(requestedAmount)}" +
              "\nAvailable: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(preview['amountAvailable'])}",
          success: false,
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Withdrawal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Withdrawal amount: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(requestedAmount)}"),
                Text("Commission (${commissionPercent.toStringAsFixed(1)}%): ₹$commissionAmount"),
                Divider(thickness: 1),
                Text("Final debited amount: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(netWithdrawalAmount)}"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm Withdrawal'),
              ),
            ],
          );
        },
      );

      if (!proceed!) {
        setState(() => _isSubmitting = false);
        return;
      }

// Proceed to submit the withdrawal request here

      // Step 3: Submit withdrawal request with verified commission + amount
      final withdrawalRequest = WithdrawalRequest(
        userId: userId,
        qrId: selectedQrCode?.qrId,
        holderName: name,
        amount: netWithdrawalAmount,
        preAmount: requestedAmount,
        commission: commissionAmount,
        mode: _mode,
        upiId: _mode == 'upi' ? _upiIdController.text.trim() : null,
        bankName: _mode == 'bank' ? _bankNameController.text.trim() : null,
        accountNumber: _mode == 'bank' ? _accountNumberController.text.trim() : null,
        ifscCode: _mode == 'bank' ? _ifscCodeController.text.trim().toUpperCase() : null,
      );

      final success = await WithdrawService.submitWithdrawRequest(withdrawalRequest);

      if (success) {
        _formKey.currentState!.reset();
        await showResultDialog(
          context,
          title: "✅ Success",
          message: "Withdrawal request submitted successfully.",
          success: true,
        );
      } else {
        await showResultDialog(
          context,
          title: "❌ Failed",
          message: "Failed to submit withdrawal request.",
          success: false,
        );
      }
    } catch (e) {
      await showResultDialog(
        context,
        title: "❌ Error",
        message: "Error submitting withdrawal: ${e.toString()}",
        success: false,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // int checkCanWithdraw(QrCode qr){
  //   final int availableRupeesInt = ((selectedQrCode?.amountAvailableForWithdrawal ?? 0) / 100.0).floor();
  //   int withdrawAmount = availableRupeesInt - (minWithdrawalAmount + overheadBalanceRequired);
  //   if(withdrawAmount >= 0){
  //     return (availableRupeesInt - (withdrawAmount + overheadBalanceRequired));
  //   }
  //   return -1;
  // }

  int maxWithdrawableRupees(QrCode qr) {
    // Assuming amountAvailableForWithdrawal is in paise (int)
    final int availablePaise = qr.amountAvailableForWithdrawal ?? 0;
    // Convert paise -> rupees using integer division (truncate paise)
    final int availableRupees = availablePaise ~/ 100; // integer division [web:142]

    // Amount that could be withdrawn while leaving the overhead
    final int afterOverhead = availableRupees - overheadBalanceRequired;

    // If we can't withdraw at least the minimum, say 0 is withdrawable
    if (afterOverhead < minWithdrawalAmount) return 0;

    // Respect the configured max cap
    final int capped = afterOverhead.clamp(minWithdrawalAmount, maxWithdrawalAmount);

    // Also never exceed what's actually available after reserving overhead
    final int hardCap = (availableRupees - overheadBalanceRequired);
    return capped.clamp(minWithdrawalAmount, hardCap);
  }

  @override
  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Withdrawal Request')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: _isLoadingUserQrs
                ? const Center(child: CircularProgressIndicator())
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected QR card (if any)
                if (selectedQrCode != null) _SelectedQrCard(
                  qr: selectedQrCode!,
                  onSelectOther: _isSubmitting ? null : _showQrSelectionDialog,
                ),
                if (selectedQrCode == null)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "No QR selected. Choose a QR to request a withdrawal.",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _showQrSelectionDialog,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Select QR Code'),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Amount section
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.currency_rupee, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text('Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            hintText: 'Enter amount in rupees',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: const Icon(Icons.payments_outlined),
                            helperText: selectedQrCode == null
                                ? 'Select a QR first to see limits'
                                : 'Min: ₹$minWithdrawalAmount • Max: ₹$maxWithdrawalAmount • Overhead: ₹$overheadBalanceRequired',
                          ),
                          validator: (val) {
                            if (selectedQrCode == null) return "Select a QR code first";
                            final text = val?.trim();
                            if (text == null || text.isEmpty) return 'Enter amount';
                            final int? amount = int.tryParse(text);
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount (positive integer rupees)';
                            }
                            final int availableRupees = ((selectedQrCode?.amountAvailableForWithdrawal ?? 0) / 100.0).floor();
                            if (availableRupees < 0) return 'Balance is negative: ₹$availableRupees';
                            if (amount < minWithdrawalAmount) return 'Minimum allowed: ₹$minWithdrawalAmount';
                            if (amount > maxWithdrawalAmount) return 'Maximum allowed: ₹$maxWithdrawalAmount';

                            // final int maxWithdrawableWithOverhead = (availableRupees - overheadBalanceRequired).clamp(0, availableRupees);
                            // if ((amount + overheadBalanceRequired) > availableRupees) {
                            //   final int extraReq = (amount + overheadBalanceRequired - availableRupees).clamp(1, overheadBalanceRequired);
                            //   return 'Short by ₹$extraReq. Max withdrawable now: ₹$maxWithdrawableWithOverhead';
                            // }
                            if (amount > availableRupees) {
                              return 'Requested amount: ₹$amount exceeds available: ₹$availableRupees';
                            }
                            return null;
                          },
                        ),
                        if (_qrCodesAssignedToMe.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              "No QR assigned to this account. Withdrawal not allowed.",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Method section
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text('Withdrawal Method', style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          children: [
                            ChoiceChip(
                              label: const Text('UPI'),
                              selected: _mode == 'upi',
                              onSelected: (val) => val ? setState(() => _mode = 'upi') : null,
                            ),
                            ChoiceChip(
                              label: const Text('Bank'),
                              selected: _mode == 'bank',
                              onSelected: (val) => val ? setState(() => _mode = 'bank') : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == 'upi'
                              ? 'UPI is usually faster. Ensure UPI ID and name match the bank records.'
                              : 'Bank transfer may take longer. Ensure IFSC and account details are correct.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // UPI fields
                if (_mode == 'upi')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.account_circle_outlined, size: 18, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Text('UPI Details', style: TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _upiIdController,
                            decoration: const InputDecoration(
                              labelText: 'UPI ID',
                              hintText: 'name@bank',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.alternate_email),
                              helperText: 'Example: username@okaxis · Avoid spaces',
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter UPI ID' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _upiHolderNameController,
                            decoration: const InputDecoration(
                              labelText: 'Account Holder Name',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter holder name' : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bank fields
                if (_mode == 'bank')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.account_balance_outlined, size: 18, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Text('Bank Details', style: TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Bank Account Number',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter account number' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _ifscCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'IFSC Code',
                              hintText: 'e.g., HDFC0001234',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.qr_code_2_outlined),
                              helperText: '11 characters · 4 letters + 0 + 6 digits',
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter IFSC code' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _bankHolderNameController,
                            decoration: const InputDecoration(
                              labelText: 'Account Holder Name',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter holder name' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _bankNameController,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name (optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.account_balance),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Submit
                if (_qrCodesAssignedToMe.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitFormNew,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      label: const Text('Submit Request'),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ======= Selected QR Card (improved design) =======
class _SelectedQrCard extends StatelessWidget {
  final QrCode qr;
  final VoidCallback? onSelectOther;
  const _SelectedQrCard({required this.qr, required this.onSelectOther});

  String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);

  @override
  Widget build(BuildContext context) {
    final statusColor = qr.isActive ? Colors.green : Colors.red;
    final statusBg = qr.isActive ? Colors.green.shade50 : Colors.red.shade50;

    Widget metric(String label, String value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget token(String k, String v, {Color? tint}) {
      final c = tint ?? Colors.blueGrey;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.06),
          border: Border.all(color: c.withOpacity(0.16)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
            Text(v, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: QR ID + status chip
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'QR: ${qr.qrId}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(qr.isActive ? Icons.check_circle : Icons.cancel, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(qr.isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Metrics grid (compact)
// Metrics row (overflow-safe)
            LayoutBuilder(
              builder: (ctx, cts) {
                final w = cts.maxWidth;
                // target tile width ~ 220, clamp to min 160 on narrow
                final target = w >= 1000 ? 240 : w >= 760 ? 220 : w >= 520 ? 200 : 160;
                final labelSmall = w < 380; // shrink labels on very small widths

                Widget metricTile(String label, String value, IconData icon, Color color) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(minWidth: 150, maxWidth: target.toDouble()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelSmall ? label.replaceAll('Available', 'Avail').replaceAll('Received', 'Recv') : label,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    metricTile(
                      'Txns',
                      CurrencyUtils.formatIndianCurrencyWithoutSign(qr.totalTransactions ?? 0),
                      Icons.receipt_long,
                      Colors.teal,
                    ),
                    metricTile(
                      'Amount Received',
                      inr(qr.totalPayInAmount ?? 0),
                      Icons.account_balance_wallet,
                      Colors.indigo,
                    ),
                    metricTile(
                      'Available',
                      inr(qr.amountAvailableForWithdrawal ?? 0),
                      Icons.savings,
                      Colors.green,
                    ),
                    metricTile(
                      'On-Hold',
                      inr(qr.amountOnHold ?? 0),
                      Icons.lock_clock,
                      Colors.orange,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            // Compact tokens row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                token('Requested', inr(qr.withdrawalRequestedAmount ?? 0), tint: Colors.deepPurple),
                token('Approved', inr(qr.withdrawalApprovedAmount ?? 0), tint: Colors.teal),
                token('Comm Hold', inr(qr.commissionOnHold ?? 0), tint: Colors.amber.shade800),
                token('Comm Paid', inr(qr.commissionPaid ?? 0), tint: Colors.cyan.shade700),
              ],
            ),

            const SizedBox(height: 10),

            // Slim action
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onSelectOther,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Change QR', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
