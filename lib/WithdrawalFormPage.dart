import 'package:admin_qr_manager/AppWriteService.dart';
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

  final max_withdrawal_amount = AppConfig().maxWithdrawalAmount;
  final min_withdrawal_amount = AppConfig().minWithdrawalAmount;

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
  List<QrCode> _qrCodes = [];
  bool _isLoadingUserQrs = true;

  // 🔹 Global selected QR (can be accessed anywhere)
  QrCode? selectedQrCode;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
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
      final codes = await _qrCodeService.getUserQrCodes(
          await AppWriteService().getUserId()!);
      setState(() {
        _qrCodes = codes;
      });
      if (_qrCodes.isNotEmpty) {
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Select QR Code for Withdrawal Request'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _qrCodes.length,
              itemBuilder: (context, index) {
                final qr = _qrCodes[index];
                return ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text("QR ${qr.qrId}"),
                  // adjust field
                  subtitle: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transactions: ${CurrencyUtils
                          .formatIndianCurrencyWithoutSign(qr
                          .totalTransactions!)}'),
                      Text('Amount Received: ${CurrencyUtils
                          .formatIndianCurrency(qr.totalPayInAmount! / 100)}'),
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


  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = await AppWriteService().account.get();
      String userId = user.$id;
      String name = user.name; // You can also let user enter name if needed

      if (_mode == 'upi') {
        name = _upiHolderNameController.text
            .trim(); // You can also let user enter name if needed
      } else {
        name = _bankHolderNameController.text
            .trim(); // You can also let user enter name if needed}
      }

      // Create the request object
      final withdrawalRequest = WithdrawalRequest(
        userId: userId,
        qrId: selectedQrCode?.qrId,
        holderName: name,
        amount: int.tryParse(_amountController.text.trim()) ?? 0,
        mode: _mode,
        upiId: _mode == 'upi' ? _upiIdController.text.trim() : null,
        bankName: _mode == 'bank' ? _bankNameController.text.trim() : null,
        accountNumber: _mode == 'bank'
            ? _accountNumberController.text.trim()
            : null,
        ifscCode: _mode == 'bank' ? _ifscCodeController.text.trim()
            .toUpperCase() : null,
      );

      // Send request via service
      final success = await WithdrawService.submitWithdrawRequest(
          withdrawalRequest);

      if (success) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('✅ Withdrawal request submitted')),
        );
        _formKey.currentState!.reset();
      } else {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('❌ Failed to submit request')),
        );
      }
    } catch (e) {
      print('❌ Error submitting withdrawal: $e');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
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
                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  validator: (val) {
                    if (val == null || val
                        .trim()
                        .isEmpty) {
                      return 'Enter amount';
                    }
                    final num = int.tryParse(val.trim());
                    if (num == null || num <= 0) return 'Enter valid amount between $min_withdrawal_amount - $max_withdrawal_amount';
                    if(num < min_withdrawal_amount) return 'Minimum Withdrawal Amount is: $min_withdrawal_amount';
                    if(num > max_withdrawal_amount) return 'Maximum Withdrawal Amount is: $max_withdrawal_amount';
                    return null;
                  },
                ),

                if(_qrCodes.isEmpty)
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
                if(_qrCodes.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
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
