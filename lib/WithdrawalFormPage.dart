import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/models/WithdrawalRequest.dart';
import 'package:flutter/material.dart';

import 'WithdrawService.dart';

class WithdrawalFormPage extends StatefulWidget {
  const WithdrawalFormPage({super.key});

  @override
  State<WithdrawalFormPage> createState() => _WithdrawalFormPageState();
}

class _WithdrawalFormPageState extends State<WithdrawalFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _mode = 'upi'; // 'upi' or 'bank'

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

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = await AppWriteService().account.get();
      String userId = user.$id;
      String name = user.name; // You can also let user enter name if needed

      if(_mode == 'upi'){
        name = _upiHolderNameController.text.trim(); // You can also let user enter name if needed
      }else {
        name = _bankHolderNameController.text.trim(); // You can also let user enter name if needed}
      }

      // Create the request object
      final withdrawalRequest = WithdrawalRequest(
        userId: userId,
        holderName: name,
        amount: int.tryParse(_amountController.text.trim()) ?? 0,
        mode: _mode,
        upiId: _mode == 'upi' ? _upiIdController.text.trim() : null,
        bankName: _mode == 'bank' ? _bankNameController.text.trim() : null,
        accountNumber: _mode == 'bank' ? _accountNumberController.text.trim() : null,
        ifscCode: _mode == 'bank' ? _ifscCodeController.text.trim().toUpperCase() : null,
      );

      // Send request via service
      final success = await WithdrawService.submitWithdrawRequest(withdrawalRequest);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Withdrawal request submitted')),
        );
        _formKey.currentState!.reset();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to submit request')),
        );
      }
    } catch (e) {
      print('❌ Error submitting withdrawal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = int.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
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
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter UPI ID' : null,
                ),
                TextFormField(
                  controller: _upiHolderNameController,
                  decoration: const InputDecoration(labelText: 'Account Holder Name'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter holder name' : null,
                ),
              ],

              // Bank Fields
              if (_mode == 'bank') ...[
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(labelText: 'Bank Account Number'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter account number' : null,
                ),
                TextFormField(
                  controller: _ifscCodeController,
                  decoration: const InputDecoration(labelText: 'IFSC Code'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter IFSC code' : null,
                ),
                TextFormField(
                  controller: _bankHolderNameController,
                  decoration: const InputDecoration(labelText: 'Account Holder Name'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter holder name' : null,
                ),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name (optional)'),
                ),
              ],

              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitForm,
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
