import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/MyMetaApi.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/models/WithdrawalRequest.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:flutter/material.dart';

import 'AppConfig.dart';
import 'QRService.dart';
import 'WithdrawService.dart';
import 'WithdrawalAccountsPage.dart';
import 'WithdrawalAccountsService.dart';
import 'models/QrCode.dart';
import 'models/WithdrawalAccount.dart';

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

  QrCode? selectedQrCode;

  late AppUser UserMeta;
  double subAdminCommission = 0;

  List<WithdrawalAccount> _withdrawalAccounts = [];
  WithdrawalAccount? selectedAccount;
  bool _isLoadingAccounts = false;

  @override
  void initState() {
    super.initState();
    UserMeta = MyMetaApi.current!;
    subAdminCommission = UserMeta.commission ?? 0;
    _fetchOnlyUserQrCodes();
    _loadWithdrawalAccounts();
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

  Future<void> _loadWithdrawalAccounts() async {
    setState(() => _isLoadingAccounts = true);
    try {
      final jwtToken = await AppWriteService().getJWT();
      final paginated = await WithdrawalAccountsService.fetchWithdrawalAccountsPaginated(
        jwtToken: jwtToken,
      );
      setState(() {
        _withdrawalAccounts = paginated.accounts;
        _isLoadingAccounts = false;
      });
    } catch (e) {
      setState(() => _isLoadingAccounts = false);
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error loading accounts: $e')),
      );
    }
  }

  Future<void> _showAccountSelectionDialog() async {
    if (_withdrawalAccounts.isEmpty) {
      await _showNoAccountsDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Account for Withdrawal'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _withdrawalAccounts.length,
                  itemBuilder: (context, index) {
                    final acc = _withdrawalAccounts[index];
                    final isSelected = selectedAccount?.id == acc.id;

                    return InkWell(
                      onTap: () {
                        setState(() => selectedAccount = acc);
                        Navigator.pop(context);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: acc.mode == 'upi' ? Colors.green : Colors.blue,
                            child: Icon(
                              acc.mode == 'upi' ? Icons.payment : Icons.account_balance,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            acc.holderName ?? 'Unnamed',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${acc.mode.toUpperCase()} Account'),
                              if (acc.mode == 'upi' && acc.upiId != null)
                                Text(acc.upiId!, style: const TextStyle(fontSize: 12)),
                              if (acc.mode == 'bank' && acc.accountNumber != null)
                                Text('****${acc.accountNumber!.length >= 4 ? acc.accountNumber!.substring(acc.accountNumber!.length - 4) : acc.accountNumber!}',
                                    style: const TextStyle(fontSize: 12)),
                              if (acc.updatedAt != null)
                                Text('Updated: ${acc.updatedAt!.substring(0, 10)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WithdrawalAccountsPage(userMode: true, userMeta: UserMeta,)),
              ).then((_) {
                // Refresh accounts when returning
                if (mounted) {
                  _loadWithdrawalAccounts();
                }
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Manage Account'),
          ),
          ElevatedButton.icon(
            onPressed: selectedAccount == null
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Use Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoAccountsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('No Accounts'),
        content: const Text('Add a withdrawal account first to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WithdrawalAccountsPage(userMode: true, userMeta: UserMeta, )),
              ).then((_) {
                // Refresh accounts when returning
                if (mounted) {
                  _loadWithdrawalAccounts();
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOnlyUserQrCodes() async {
    if (mounted) {
      setState(() {
        _isLoadingUserQrs = true;
      });
    }

    try {
      final codes = await _qrCodeService.getUserAssignedQrCodes(
          await AppWriteService().getUserId(), await AppWriteService().getJWT());
      setState(() {
        List<QrCode> qrCodesFetched = codes;
        _qrCodesAssignedToMe = qrCodesFetched.where((q) => (q.assignedUserId ?? '').toLowerCase() == UserMeta.id).toList();
      });
      if (_qrCodesAssignedToMe.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
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
                final aAvail = (a.canWithdrawToday() ?? 0);
                final bAvail = (b.canWithdrawToday() ?? 0);
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
                          metricChip('Total Available', inr(qr.amountAvailableForWithdrawal ?? 0), Colors.green, Icons.savings),
                          metricChip('Withdrawable Amount', inr(qr.canWithdrawToday()), Colors.green, Icons.savings),
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
                                onDoubleTap: qr.isActive ? () {  // Also protect double-tap
                                  tempSelection = qr;
                                  setState(() => selectedQrCode = tempSelection);
                                  Navigator.pop(context);
                                  _scaffoldMessengerKey.currentState?.showSnackBar(
                                    SnackBar(content: Text('✅ Selected QR: ${qr.qrId}')),
                                  );
                                } : null,
                                onTap: () {
                                  if (!qr.isActive) {
                                    _showInactiveQrDialog(context);
                                    return;
                                  }
                                  setLocal(() => tempSelection = qr);
                                },
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

  void _showInactiveQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Inactive QR Code'),
          ],
        ),
        content: const Text(
          'Inactive QR codes cannot be used for withdrawal requests.\n\nPlease select an active QR code.',
          style: TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('OK'),
          ),
        ],
      ),
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

  void _submitFormNew() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final user = await AppWriteService().account.get();
    String userId = user.$id;
    _mode = selectedAccount!.mode;

    final int requestedAmount = int.tryParse(_amountController.text.trim()) ?? 0;

    try {
      final jwtToken = await AppWriteService().getJWT();
      final preview = await WithdrawService.fetchWithdrawCommissionPreview(
        jwtToken: jwtToken,
        userId: userId,
        qrId: selectedQrCode!.qrId,
        preAmount: requestedAmount.toDouble(),
      );

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
              "\nRequested: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(preAmountPaise / 100)}" "\nCommission $commissionRate% : ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(commissionPaise / 100)}" "\nOverhead: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(overheadPaise / 100)}" "\nAvailable Balance: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(available / 100)}""\nbalance Required: ₹${CurrencyUtils.formatIndianCurrencyWithoutSign(required / 100)}";
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

      if (proceed != true) {
        setState(() => _isSubmitting = false);
        return;
      }

// Proceed to submit the withdrawal request here

      // Step 3: Submit withdrawal request with verified commission + amount
      final withdrawalRequest = WithdrawalRequest(
        userId: userId,
        qrId: selectedQrCode?.qrId,
        holderName: selectedAccount!.holderName!,
        amount: netWithdrawalAmount,
        preAmount: requestedAmount,
        commission: commissionAmount,
        mode: _mode,
        upiId: _mode == 'upi' ? selectedAccount!.upiId! : null,
        bankName: _mode == 'bank' ? selectedAccount!.bankName!.trim() : null,
        accountNumber: _mode == 'bank' ? selectedAccount!.accountNumber!.trim() : null,
        ifscCode: _mode == 'bank' ? selectedAccount!.ifscCode!.trim().toUpperCase() : null,
      );

      final success = await WithdrawService.submitWithdrawRequest(jwtToken: jwtToken, request: withdrawalRequest, );

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

  int maxWithdrawableRupees(QrCode qr) {
    final int availablePaise = qr.canWithdrawToday() ?? 0;
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

                if (selectedAccount != null)
                  selectedAccountUI(selectedAccount!),
                if(selectedAccount == null)
                // Show "Select Account" prompt
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, color: Colors.orange, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Withdrawal Account',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Text('Choose UPI or bank account for payout'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _showAccountSelectionDialog,
                                  icon: const Icon(Icons.account_balance_wallet),
                                  label: const Text('Select Account'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
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
                            // helperText: selectedQrCode == null
                            helperText: selectedQrCode == null
                                ? 'Select QR first'
                                : selectedAccount == null
                                ? 'Select QR → Account → Amount'
                                : 'Min: ₹$minWithdrawalAmount • Max: ₹$maxWithdrawalAmount',
                          ),
                          validator: (val) {
                            if (selectedQrCode == null) return "Select QR first";
                            if (selectedAccount == null) return "Select withdrawal account first";
                            final text = val?.trim();
                            if (text == null || text.isEmpty) return 'Enter amount';
                            final int? amount = int.tryParse(text);
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount (positive integer rupees)';
                            }
                            final int availableRupees = ((selectedQrCode?.canWithdrawToday() ?? 0) / 100.0).floor();

                            if (availableRupees < 0) return 'Balance is negative: ₹$availableRupees';
                            if (amount < minWithdrawalAmount) return 'Minimum allowed: ₹$minWithdrawalAmount';
                            if (amount > maxWithdrawalAmount) return 'Maximum allowed: ₹$maxWithdrawalAmount';
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

  Widget selectedAccountUI(WithdrawalAccount selectedAccount){
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with mode icon
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: selectedAccount.mode == 'upi'
                        ? Colors.green
                        : Colors.blue,
                    radius: 20,
                    child: Icon(
                      selectedAccount.mode == 'upi'
                          ? Icons.payment
                          : Icons.account_balance,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAccount.holderName ?? 'Unnamed',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${selectedAccount.mode.toUpperCase()} Account',
                          style: TextStyle(
                            color: selectedAccount.mode == 'upi'
                                ? Colors.green
                                : Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showAccountSelectionDialog,
                    icon: const Icon(Icons.account_balance, size: 16),
                    label: const Text('Change Account', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details Row
              Row(
                children: [
                  // Left: Primary detail
                  Expanded(
                    child: _AccountDetailTile(
                      icon: selectedAccount.mode == 'upi'
                          ? Icons.alternate_email
                          : Icons.numbers,
                      label: selectedAccount.mode == 'upi' ? 'UPI ID' : 'Account',
                      value: selectedAccount.mode == 'upi'
                          ? (selectedAccount.upiId ?? '')
                          : (selectedAccount.accountNumber ?? ''),
                    ),
                  ),

                  // Right: Secondary detail
                  Expanded(
                    child: _AccountDetailTile(
                      icon: Icons.description,
                      label: 'IFSC${selectedAccount.mode == 'upi' ? '' : '*'}',
                      value: selectedAccount.ifscCode ?? 'N/A',
                    ),
                  ),
                ],
              ),

              if (selectedAccount.bankName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AccountDetailTile(
                    icon: Icons.account_balance,
                    label: 'Bank',
                    value: selectedAccount.bankName!,
                    isFullWidth: true,
                  ),
                ),

              if (selectedAccount.notes != null && selectedAccount.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _AccountDetailTile(
                    icon: Icons.note,
                    label: 'Notes',
                    value: selectedAccount.notes!,
                    isFullWidth: true,
                  ),
                ),
            ],
          ),
        ),
      );
  }

}

class _AccountDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isFullWidth;

  const _AccountDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                      'Withdrawable Amount',
                      inr(qr.canWithdrawToday()),
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
