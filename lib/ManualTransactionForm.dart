import 'package:admin_qr_manager/TransactionService.dart';
import 'package:admin_qr_manager/widget/ManualTransactionShimmer.dart';
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
    if(mounted) {
      setState(() => loading = true);
    }
    _jwtToken = await AppWriteService().getJWT();

    final fetched = await UserService.listUsers(jwtToken: await AppWriteService().getJWT());
    users = fetched.appUsers;
    qrCodes = await _qrCodeService.getQrCodes(_jwtToken);

    // print(users.toString());
    // print(qrCodes.toString());

    if(mounted) {
      setState(() => loading = false);
    }
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

  Future<void> _showResultDialog(
      BuildContext context, {
        required String title,
        required String message,
        required bool success,
      }) {
    final color = success ? Colors.green : Colors.red;
    final icon = success ? Icons.check_circle : Icons.error;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (mounted) setState(() => loading = true);

      try {
        final success = await TransactionService.uploadManualTransaction(
          qrCodeId: qrCodeController.text.trim(),
          rrnNumber: rrnController.text.trim(),
          amount: double.tryParse(amountController.text.trim()) ?? 0.0,
          isoDate: timeDateValue!,
          jwtToken: _jwtToken!,
        );

        if (!mounted) return;

        if (success) {
          qrCodeController.clear();
          await _showResultDialog(
            context,
            title: 'Success',
            message: 'Transaction uploaded successfully.',
            success: true,
          );
        } else {
          await _showResultDialog(
            context,
            title: 'Failed',
            message: 'Upload did not complete. Please try again.',
            success: false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        await _showResultDialog(
          context,
          title: 'Error',
          message: 'Failed to upload: $e',
          success: false,
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;
    final isWide = MediaQuery.of(context).size.width >= 900;

    // // form completeness hint (0–4)
    // final filledCount = [
    //   qrCodeController.text.isNotEmpty,
    //   rrnController.text.length == 12,
    //   (double.tryParse(amountController.text) ?? 0) > 0,
    //   isoDateController.text.isNotEmpty
    // ].where((e) => e).length;

    return Scaffold(
      appBar: AppBar(title: const Text("Manual Transaction Upload")),
      body: loading
          ? const ManualTransactionShimmer()
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Filters card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.filter_alt_outlined, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        isWide
                            ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _userDropdown()),
                            const SizedBox(width: 12),
                            Expanded(child: _qrDropdown()),
                          ],
                        )
                            : Column(
                          children: [
                            _userDropdown(),
                            const SizedBox(height: 12),
                            _qrDropdown(),
                          ],
                        ),
                        if (selectedUserId != null && !userHasQrCodes)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('No QR codes assigned to this user.', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Transaction details card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.receipt_long, size: 18, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: qrCodeController,
                          readOnly: true,
                          enableInteractiveSelection: false,
                          showCursor: false,
                          decoration: const InputDecoration(
                            labelText: "QR Code ID",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.qr_code_2),
                            helperText: "Selected QR Code from the filter above",
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? "QR Code ID required" : null,
                          onTap: () => FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 12),

                        isWide
                            ? Row(
                          children: [
                            Expanded(child: _rrnField()),
                            const SizedBox(width: 12),
                            Expanded(child: _amountField()),
                          ],
                        )
                            : Column(
                          children: [
                            _rrnField(),
                            const SizedBox(height: 12),
                            _amountField(),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: isoDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Transaction Date & Time",
                            hintText: "Select date & time",
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Pick date & time',
                                  icon: const Icon(Icons.schedule),
                                  onPressed: () => _pickDateTime(context),
                                ),
                                if (isoDateController.text.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => isoDateController.clear()),
                                  ),
                              ],
                            ),
                            helperText: "IST-aligned timestamp will be sent to API",
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? "Date & Time required" : null,
                          onTap: () => _pickDateTime(context),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress hint + Submit button under the form
                Row(
                  children: [
                    // Expanded(
                    //   child: ClipRRect(
                    //     borderRadius: BorderRadius.circular(8),
                    //     child: LinearProgressIndicator(
                    //       value: (filledCount / 4).clamp(0, 1.0),
                    //       backgroundColor: Colors.grey.shade200,
                    //       minHeight: 6,
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: loading ? null : _submitForm,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text("Submit Transaction"),
                    ),
                  ],
                ),

                // const SizedBox(height: 12),
                // Align(
                //   alignment: Alignment.centerLeft,
                //   child: Text(
                //     'Fields completed: $filledCount / 4',
                //     style: const TextStyle(fontSize: 12, color: Colors.grey),
                //   ),
                // ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

// ==== Sub-widgets ====

  Widget _userDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Filter User', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedUserId,
          hint: const Text('Select User'),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('--------')),
            ...users.map((u) => DropdownMenuItem(
              value: u.id,
              child: Text('${u.name} (${u.email})', overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (value) {
            setState(() {
              selectedUserId = value;
              selectedQrCodeId = null;
              qrCodeController.clear();
            });
          },
        ),
        if (selectedUserId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'QRs: ${filteredQrCodes.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _qrDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Filter QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedQrCodeId,
          hint: const Text('Select QR Code'),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code_2),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('--------')),
            ...filteredQrCodes.map(
                  (qr) => DropdownMenuItem(
                value: qr.qrId,
                child: Text(qr.qrId ?? qr.assignedUserId ?? '', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedQrCodeId = value;
              qrCodeController.text = selectedQrCodeId ?? '';
            });
          },
        ),
      ],
    );
  }

  Widget _rrnField() {
    return TextFormField(
      controller: rrnController,
      decoration: const InputDecoration(
        labelText: "RRN Number",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.receipt),
        helperText: "12 digits, numeric only",
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) return "RRN Number required";
        if (v.length != 12) return "RRN Number must be 12 digits";
        return null;
      },
    );
  }

  Widget _amountField() {
    return TextFormField(
      controller: amountController,
      decoration: const InputDecoration(
        labelText: "Amount (₹)",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.currency_rupee),
        helperText: "Enter amount in rupees",
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return "Amount required";
        final parsed = double.tryParse(v);
        if (parsed == null || parsed <= 0) return "Enter valid amount";
        return null;
      },
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

// Sticky submit bar with progress indicator
class _StickySubmitBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSubmit;
  final int filledCount;
  final int totalCount;

  const _StickySubmitBar({
    required this.enabled,
    required this.onSubmit,
    required this.filledCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (filledCount / totalCount).clamp(0, 1.0);
    return Material(
      elevation: 6,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct == 0 ? null : pct as double,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: enabled ? onSubmit : null,
                icon: const Icon(Icons.cloud_upload),
                label: const Text("Submit Transaction"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

