import 'package:admin_qr_manager/TransactionService.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'QRService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';

class ManualTransactionForm extends StatefulWidget {
  const ManualTransactionForm({super.key});

  @override
  State<ManualTransactionForm> createState() => _ManualTransactionFormState();
}

class _ManualTransactionFormState extends State<ManualTransactionForm> {
  final _formKey = GlobalKey<FormState>();

  final qrCodeController = TextEditingController();
  final rrnController = TextEditingController();
  final amountController = TextEditingController();
  final isoDateController = TextEditingController();

  // final isoDateController = TextEditingController(
  //   text: DateTime.now().toIso8601String(),
  // );

  // final payloadController = TextEditingController();
  // final paymentIdController = TextEditingController();
  // final vpaController = TextEditingController();

  final QrCodeService _qrCodeService = QrCodeService();

  String? _jwtToken; // Placeholder for the JWT token

  bool loading = false;

  List<AppUser> users = [];
  List<QrCode> qrCodes = [];
  List<QrCode> userQrCodes = []; // Filtered based on selectedUser

  String? selectedUserId;
  String? selectedQrCodeId;

  String? timeDateValue;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => loading = true);
    _jwtToken = await AppWriteService().getJWT();

    final fetched = await UserService.listUsers(jwtToken: await AppWriteService().getJWT());
    users = fetched.appUsers;
    qrCodes = await _qrCodeService.getQrCodes(_jwtToken);

    // print(users.toString());
    // print(qrCodes.toString());

    setState(() => loading = false);
  }

  @override
  void dispose() {
    qrCodeController.dispose();
    rrnController.dispose();
    amountController.dispose();
    isoDateController.dispose();
    // payloadController.dispose();
    // paymentIdController.dispose();
    // vpaController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);

      final transactionData = {
        "qrCodeId": qrCodeController.text.trim(),
        "rrnNumber": rrnController.text.trim(),
        "amount": double.tryParse(amountController.text.trim()) ?? 0.0,
        "isoDate": timeDateValue, // 👈 auto-generate ISO date
      };

      // print("📤 Sending transaction: $transactionData");

      try {
        final success = await TransactionService.uploadManualTransaction(
          qrCodeId: qrCodeController.text.trim(),
          rrnNumber: rrnController.text.trim(),
          amount: double.tryParse(amountController.text.trim()) ?? 0.0,
          isoDate: timeDateValue!,
          jwtToken: _jwtToken!,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Transaction uploaded successfully")),
          );

          // Clear fields after success
          qrCodeController.clear();
          rrnController.clear();
          amountController.clear();
          isoDateController.clear();
        }
      } catch (e) {
        print("❌ Upload failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: $e")),
        );
      } finally {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Manual Transaction Upload")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(   // ✅ Wrap with Form
          key: _formKey,
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
                              child: Text('${user.name} (${user.email})'),
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
                              qrCodeController.text = selectedQrCodeId ?? '';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 25,),
              if (selectedUserId != null && !userHasQrCodes)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'No QR codes assigned to this user.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextFormField(
                controller: qrCodeController,
                decoration: const InputDecoration(
                  labelText: "QR Code ID",
                ),
                readOnly: true, // ✅ always non-editable
                enableInteractiveSelection: false, // ✅ disable copy/paste
                showCursor: false, // ✅ hide cursor
                validator: (value) =>
                value == null || value.isEmpty ? "QR Code ID required" : null,
                onTap: () {
                  // prevent keyboard
                  FocusScope.of(context).unfocus();
                },
              ),
              TextFormField(
                controller: rrnController,
                decoration: const InputDecoration(labelText: "RRN Number"),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // ✅ Only numbers allowed
                  LengthLimitingTextInputFormatter(12),   // ✅ Max 12 digits
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "RRN Number required";
                  }
                  if (value.length != 12) {
                    return "RRN Number must be 12 digits";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Amount required";
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) return "Enter valid amount";
                  return null;
                },
              ),
              TextFormField(
                controller: isoDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Transaction Date & Time",
                  hintText: "Select date & time",
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Date & Time required" : null,
                onTap: () => _pickDateTime(context),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Submit Transaction"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (pickedTime == null) return;

    // Build LOCAL DateTime from user's selection
    final localDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Convert local time to UTC for proper storage
    final utcDateTime = localDateTime.toUtc();

    // print('User selected (local): ${localDateTime.toString()}');
    // print('Saving as UTC: ${utcDateTime.toIso8601String()}');

    timeDateValue = utcDateTime.toIso8601String();

    isoDateController.text = DateFormat('dd MMM yyyy, hh:mm a').format(localDateTime.toLocal());

    // isoDateController.text = utcDateTime.toIso8601String();
  }


  List<QrCode> get filteredQrCodes {
    if (selectedUserId == null) return qrCodes;
    return qrCodes.where((qr) => qr.assignedUserId == selectedUserId).toList();
  }

}
