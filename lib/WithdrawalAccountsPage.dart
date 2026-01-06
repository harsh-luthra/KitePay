import 'package:admin_qr_manager/WithdrawalAccountsService.dart'; // Your service from previous
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/models/WithdrawalAccount.dart';
import 'package:flutter/material.dart';

class WithdrawalAccountsPage extends StatefulWidget {
  const WithdrawalAccountsPage({super.key});

  @override
  State<WithdrawalAccountsPage> createState() => _WithdrawalAccountsPageState();
}

class _WithdrawalAccountsPageState extends State<WithdrawalAccountsPage> {
  List<WithdrawalAccount> _accounts = [];
  bool _isLoading = true;
  String? _nextCursor;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts({bool refresh = false}) async {
    if (refresh) {
      _nextCursor = null;
      _accounts.clear();
    }
    setState(() => _isLoading = true);

    try {
      final jwtToken = await AppWriteService().getJWT();
      final paginated = await WithdrawalAccountsService.fetchWithdrawalAccountsPaginated(
        jwtToken: jwtToken,
        cursor: _nextCursor,
      );
      setState(() {
        _accounts.addAll(paginated.accounts);
        _nextCursor = paginated.nextCursor;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showSnackBar('Error loading accounts: $e');
    }
  }

  Future<void> _deleteAccount(String accountId) async {
    final bool? confirm = await _showConfirmDialog(
      title: 'Delete Account?',
      message: 'This action cannot be undone. Are you sure?',
    );
    if (!confirm!) return;

    try {
      final jwtToken = await AppWriteService().getJWT();
      await WithdrawalAccountsService.deleteWithdrawalAccount(
        jwtToken: jwtToken,
        accountId: accountId,
      );
      setState(() => _accounts.removeWhere((a) => a.id == accountId));
      _showSnackBar('Account deleted successfully');
    } catch (e) {
      _showSnackBar('Delete failed: $e');
    }
  }

  void _editAccount(WithdrawalAccount account) {
    _showAccountFormDialog(account: account, context: context, onSuccess: () => _loadAccounts(refresh: true),);
  }

  void _addNewAccount() {
    if(_accounts.length >= 5) {
      _showAccountLimitDialog();
      return;
    }
    _showAccountFormDialog(context: context, onSuccess: () => _loadAccounts(refresh: true),);
  }

  Future<void> _showAccountLimitDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 12),
            Text(
              'Account Limit Reached',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can only have 5 withdrawal accounts.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Edit existing accounts or delete unused ones to add new ones.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Current: 5/5 accounts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Got it'),
          ),
          // ElevatedButton.icon(
          //   onPressed: () {
          //     Navigator.pop(context);
          //     // Optional: Navigate to accounts page
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const WithdrawalAccountsPage()),
          //     ).then((_) => _loadWithdrawalAccounts());
          //   },
          //   icon: const Icon(Icons.account_balance_wallet),
          //   label: const Text('Manage Accounts'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.orange,
          //   ),
          // ),
        ],
      ),
    );
  }


  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal Accounts'),
        actions: [
          if(!_accounts.isEmpty)
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              onPressed: _addNewAccount,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
          ),
        ],
      ),
      body: _isLoading && _accounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? _EmptyState(onAdd: _addNewAccount)
          : RefreshIndicator(
        onRefresh: () => _loadAccounts(refresh: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _accounts.length + (_nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _accounts.length) {
              return _LoadMoreTile(
                isLoading: _isLoadingMore,
                onLoadMore: _loadMore,
              );
            }
            final account = _accounts[index];
            return _AccountCard(
              account: account,
              onEdit: () => _editAccount(account),
              onDelete: () => _deleteAccount(account.id!),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAccount,
        tooltip: 'Add Account',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    await _loadAccounts();
    setState(() => _isLoadingMore = false);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No Withdrawal Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Add your first UPI or bank account to request withdrawals.'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final WithdrawalAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUpi = account.mode == 'upi';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUpi ? Icons.payment : Icons.account_balance,
                  color: isUpi ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.holderName ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isUpi ? (account.upiId ?? 'No UPI') : (account.bankName ?? 'No Bank'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        '${account.mode.toUpperCase()} • ${account.updatedAt?.substring(0, 10) ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (!isUpi && account.accountNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '****${account.accountNumber!.substring(account.accountNumber!.length - 4)} • ${account.ifscCode}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            if (isUpi && account.upiId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  account.upiId!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreTile extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onLoadMore;
  const _LoadMoreTile({required this.isLoading, required this.onLoadMore});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListTile(
        leading: const Icon(Icons.more_horiz),
        title: const Text('Load more accounts'),
        onTap: onLoadMore,
      ),
    );
  }
}

// 🔹 Dialog Form (matches WithdrawalFormPage design)
void _showAccountFormDialog({WithdrawalAccount? account, required BuildContext context, VoidCallback? onSuccess}) {
  final isEdit = account != null;
  final notesController = TextEditingController(text: account?.notes);
  final upiIdController = TextEditingController(text: account?.upiId);
  final holderNameController = TextEditingController(text: account?.holderName);
  final accountNumberController = TextEditingController(text: account?.accountNumber);
  final ifscController = TextEditingController(text: account?.ifscCode);
  final bankNameController = TextEditingController(text: account?.bankName);

  String currentMode = account?.mode ?? 'upi';
  bool _isDialogLoading = false;

  // ✅ Form key for validation
  final _formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isEdit ? 'Edit Account' : 'Add Account'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey, // ✅ Form validation
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mode chips
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('UPI'),
                      selected: currentMode == 'upi',
                      onSelected: (val) => val ? setDialogState(() => currentMode = 'upi') : null,
                    ),
                    ChoiceChip(
                      label: const Text('Bank'),
                      selected: currentMode == 'bank',
                      onSelected: (val) => val ? setDialogState(() => currentMode = 'bank') : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Holder Name (common) - Required
                TextFormField(
                  controller: holderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) {
                    final trimmed = val?.trim();
                    if (trimmed == null || trimmed.isEmpty) return 'Holder name required';
                    if (trimmed.length > 100) return 'Max 100 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                if (currentMode == 'upi') ...[
                  // ✅ UPI ID Validation
                  TextFormField(
                    controller: upiIdController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID *',
                      hintText: 'johndoe@paytm',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (val) {
                      final trimmed = val?.trim();
                      if (trimmed == null || trimmed.isEmpty) return 'UPI ID required';
                      if (trimmed.length > 100) return 'Max 100 characters';
                      if (!RegExp(r'^[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+$').hasMatch(trimmed)) {
                        return 'Invalid format: name@bank';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  // ✅ Bank Account Number
                  TextFormField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (val) {
                      final trimmed = val?.trim();
                      if (trimmed == null || trimmed.isEmpty) return 'Account number required';
                      if (trimmed.length < 9 || trimmed.length > 18) {
                        return 'Must be 9-18 digits';
                      }
                      if (!RegExp(r'^\d{9,18}$').hasMatch(trimmed)) {
                        return 'Digits only (9-18 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ✅ IFSC Code Validation
                  TextFormField(
                    controller: ifscController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code *',
                      hintText: 'HDFC0001234',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    validator: (val) {
                      final trimmed = val?.trim().toUpperCase();
                      if (trimmed == null || trimmed.isEmpty) return 'IFSC required';
                      if (trimmed.length != 11) return 'Must be exactly 11 characters';
                      if (!RegExp(r'^[A-Z0-9]{11}$').hasMatch(trimmed)) {
                        return 'Only A-Z, 0-9 allowed (no spaces/symbols)';
                      }
                      return null;
                    },
                    // onChanged: (val) => ifscController.text = val.toUpperCase(),
                  ),
                  const SizedBox(height: 12),

                  // Bank Name (optional)
                  TextFormField(
                    controller: bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name *', // ✅ Asterisk
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                    validator: (val) {
                      final trimmed = val?.trim();
                      if (trimmed == null || trimmed.isEmpty) return 'Bank name required';
                      if (trimmed.length < 3) return 'Minimum 3 characters';
                      if (trimmed.length > 35) return 'Max 35 characters';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Notes (optional)
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Primary account, salary etc.',
                  ),
                  validator: (val) {
                    final trimmed = val?.trim();
                    if (trimmed != null && trimmed.length > 1000) return 'Max 1000 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isDialogLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: _isDialogLoading
                ? null
                : () async {
              // ✅ Validate form first
              if (!_formKey.currentState!.validate()) return;

              setDialogState(() => _isDialogLoading = true);

              try {
                final jwtToken = await AppWriteService().getJWT();
                final updates = {
                  'mode': currentMode,
                  'holderName': holderNameController.text.trim(),
                  if (currentMode == 'upi') 'upiId': upiIdController.text.trim(),
                  if (currentMode != 'upi') ...{
                    'accountNumber': accountNumberController.text.trim(),
                    'ifscCode': ifscController.text.trim().toUpperCase(),
                    'bankName': bankNameController.text.trim(),
                  },
                  if (notesController.text.trim().isNotEmpty) 'notes': notesController.text.trim(),
                };

                if (isEdit) {
                  await WithdrawalAccountsService.updateWithdrawalAccount(
                    jwtToken: jwtToken,
                    accountId: account!.id!,
                    updates: updates,
                  );
                } else {
                  await WithdrawalAccountsService.createWithdrawalAccount(
                    jwtToken: jwtToken,
                    account: WithdrawalAccount(
                      mode: currentMode,
                      holderName: holderNameController.text.trim(),
                      upiId: currentMode == 'upi' ? upiIdController.text.trim() : null,
                      accountNumber: currentMode == 'bank' ? accountNumberController.text.trim() : null,
                      ifscCode: currentMode == 'bank' ? ifscController.text.trim().toUpperCase() : null,
                      bankName: currentMode == 'bank' ? bankNameController.text.trim() : null,
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    ),
                  );
                }

                Navigator.pop(context);
                onSuccess?.call();
              } catch (e) {
                setDialogState(() => _isDialogLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            icon: _isDialogLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.save),
            label: Text(_isDialogLoading ? 'Saving...' : (isEdit ? 'Update' : 'Add')),
          ),
        ],
      ),
    ),
  );
}
