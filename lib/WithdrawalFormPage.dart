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
    showDialog(
      context: context,
      barrierDismissible: false, // force selection
      builder: (alertContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Select QR Code for Withdrawal Request'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _qrCodesAssignedToMe.length,
                itemBuilder: (context, index) {
                  final qr = _qrCodesAssignedToMe[index];
                  return ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: Text("QR ${qr.qrId}"),
                    // adjust field
                    subtitle: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transactions: ${CurrencyUtils
                            .formatIndianCurrencyWithoutSign(qr.totalTransactions!)}'),
                        Text('Amount Received: ${CurrencyUtils
                            .formatIndianCurrency(qr.totalPayInAmount! / 100)}'),
                        Text(
                          'Amount Available For Withdrawal: ${CurrencyUtils.formatIndianCurrency((qr.amountAvailableForWithdrawal ?? 0) / 100)}',
                        ),
                        Text(qr.isActive ? "Active" : "InActive"),
                      ],
                    ),
                    selected: selectedQrCode?.qrId == qr.qrId,
                    iconColor: qr.isActive ? Colors.green : Colors.red,
                    onTap: () {
                      setState(() {
                        selectedQrCode = qr; // 🔹 save globally
                      });
                      Navigator.pop(context); // close dialog
                      _scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('✅ Selected QR: ${qr.qrId}')),
                      );
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('✅ Selected QR: ${qr.qrId}')),
                      // );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // 1) Close the dialog
                  Navigator.of(alertContext).pop();
                  // 2) Go back to the previous page/route
                  // Navigator.of(context).maybePop(); // safe back; use pop() if guaranteed
                  Navigator.pop(context, true); // also close page
                },
                child: const Text('Cancel'),
              ),
            ],
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

    final user = await AppWriteService().account.get();
    String userId = user.$id;

    String name = _mode == 'upi' ? _upiHolderNameController.text.trim() : _bankHolderNameController.text.trim();

    final int requestedAmount = int.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _isSubmitting = true);

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
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Withdrawal Request')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: _isLoadingUserQrs ? CircularProgressIndicator() : Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if(selectedQrCode != null)
                  QrCodeCard(selectedQrCode!),
                if(selectedQrCode != null)...[
                  // Text("Commission : $subAdminCommission %",),
                  // if(maxWithdrawableRupees(selectedQrCode!) >= 0)
                  //   Text("Can Withdraw: ${maxWithdrawableRupees(selectedQrCode!)}"),
                ],

                // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
                validator: (val) {

                  if(selectedQrCode == null){
                    return "QR CODE NOT SELECTED";
                  }

                  final text = val?.trim();
                  if (text == null || text.isEmpty) {
                    return 'Enter amount';
                  }

                  // Parse as int rupees
                  final int? amount = int.tryParse(text);
                  if (amount == null || amount <= 0) {
                    return 'Enter valid amount between $minWithdrawalAmount - $maxWithdrawalAmount';
                  }

                  // Convert available (paise) -> rupees
                  final int availableRupeesInt = ((selectedQrCode?.amountAvailableForWithdrawal ?? 0) / 100.0).floor();

                  if(availableRupeesInt < 0){
                    return 'Your Balance is Negative : $availableRupeesInt';
                  }

                  // Min/Max bounds in rupees
                  if (amount < minWithdrawalAmount) {
                    return 'Minimum Withdrawal Amount is: $minWithdrawalAmount';
                  }
                  if (amount > maxWithdrawalAmount) {
                    return 'Maximum Withdrawal Amount is: $maxWithdrawalAmount';
                  }

                  // Overhead-adjusted limit
                  final int maxWithdrawableWithOverhead = (availableRupeesInt - overheadBalanceRequired).clamp(0, availableRupeesInt);

                  // Overhead shortfall (covers all amounts >= min)
                  if ((amount + overheadBalanceRequired) > availableRupeesInt) {
                    final int extraReq = (amount + overheadBalanceRequired - availableRupeesInt).clamp(1, overheadBalanceRequired);
                    return 'Short by ₹$extraReq: max withdrawable is ₹$maxWithdrawableWithOverhead';
                  }

                  if (amount == maxWithdrawalAmount && (amount + overheadBalanceRequired) > availableRupeesInt) {
                    final int shortfall = (amount + overheadBalanceRequired) - availableRupeesInt;
                    final int maxWithdrawable = (availableRupeesInt - overheadBalanceRequired).clamp(0, maxWithdrawalAmount);
                    return 'Short by ₹$shortfall: max withdrawable is ₹$maxWithdrawable';
                  }

                  // Optional: direct available cap if no overhead issue but amount > available (rare when overhead small)
                  if (amount > availableRupeesInt) {
                    return 'Requested amount ₹$amount exceeds available ₹$availableRupeesInt';
                  }

                  return null;
                },
            ),

                if(_qrCodesAssignedToMe.isEmpty)
                  Text("No Qr Assigned to You So you can't Request Withdrawals"),

                const SizedBox(height: 16),

                // Mode Toggle
                Row(
                  children: [
                    const Text('Withdrawal Method:'),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('UPI'),
                      selected: _mode == 'upi',
                      onSelected: (val) {
                        if (val) setState(() => _mode = 'upi');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Bank'),
                      selected: _mode == 'bank',
                      onSelected: (val) {
                        if (val) setState(() => _mode = 'bank');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // UPI Fields
                if (_mode == 'upi') ...[
                  TextFormField(
                    controller: _upiIdController,
                    decoration: const InputDecoration(labelText: 'UPI ID'),
                    validator: (val) =>
                    val == null || val
                        .trim()
                        .isEmpty ? 'Enter UPI ID' : null,
                  ),
                  TextFormField(
                    controller: _upiHolderNameController,
                    decoration: const InputDecoration(
                        labelText: 'Account Holder Name'),
                    validator: (val) =>
                    val == null || val
                        .trim()
                        .isEmpty ? 'Enter holder name' : null,
                  ),
                ],

                // Bank Fields
                if (_mode == 'bank') ...[
                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                        labelText: 'Bank Account Number'),
                    validator: (val) =>
                    val == null || val
                        .trim()
                        .isEmpty ? 'Enter account number' : null,
                  ),
                  TextFormField(
                    controller: _ifscCodeController,
                    decoration: const InputDecoration(labelText: 'IFSC Code'),
                    validator: (val) =>
                    val == null || val
                        .trim()
                        .isEmpty ? 'Enter IFSC code' : null,
                  ),
                  TextFormField(
                    controller: _bankHolderNameController,
                    decoration: const InputDecoration(
                        labelText: 'Account Holder Name'),
                    validator: (val) =>
                    val == null || val
                        .trim()
                        .isEmpty ? 'Enter holder name' : null,
                  ),
                  TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                        labelText: 'Bank Name (optional)'),
                  ),
                ],

                const SizedBox(height: 30),

                // Submit Button
                if(_qrCodesAssignedToMe.isNotEmpty)
                ElevatedButton.icon (
                  onPressed: _isSubmitting ? null : _submitFormNew,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Submit Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget QrCodeCard(QrCode selectedQrCode){
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selected QR Code",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("ID: ${selectedQrCode?.qrId}"),
            Text('Transactions: ${CurrencyUtils.formatIndianCurrencyWithoutSign(selectedQrCode?.totalTransactions as num)}'),
            Text('Amount Received: ${CurrencyUtils.formatIndianCurrency(selectedQrCode!.totalPayInAmount! / 100)}'),
            Text(
              'Available For Withdrawal: ${CurrencyUtils.formatIndianCurrency((selectedQrCode!.amountAvailableForWithdrawal ?? 0) / 100)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Withdrawal Requested: ${CurrencyUtils.formatIndianCurrency((selectedQrCode!.withdrawalRequestedAmount ?? 0) / 100)}',
            ),
            Text(
              'Withdrawal Approved: ${CurrencyUtils.formatIndianCurrency((selectedQrCode!.withdrawalApprovedAmount ?? 0) / 100)}',
            ),
            Text(
              'Commission onHold: ${CurrencyUtils.formatIndianCurrency((selectedQrCode.commissionOnHold ?? 0) / 100)}',
            ),
            Text(
              'Commission Paid: ${CurrencyUtils.formatIndianCurrency((selectedQrCode.commissionPaid ?? 0) / 100)}',
            ),
            Text(
              'OnHold: ${CurrencyUtils.formatIndianCurrency((selectedQrCode!.amountOnHold ?? 0) / 100)}',
            ),
            Text(
              selectedQrCode!.isActive ? "Active" : "Inactive",
              style: TextStyle(
                color: selectedQrCode!.isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _showQrSelectionDialog,
              icon: _isSubmitting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.qr_code),
              label: const Text('Select Other QR Code'),
            ),
          ],
        ),
      ),
    );
  }

}
