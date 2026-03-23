import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/QRService.dart';
import 'package:admin_qr_manager/UsersService.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models/AppUser.dart';
import 'models/QrCode.dart';

class ManualHoldPage extends StatefulWidget {
  final AppUser userMeta;
  final QrCode? qrCode;
  final String? initialQrId;
  final AppUser? assignedUser;

  const ManualHoldPage({super.key, required this.userMeta, this.qrCode, this.initialQrId, this.assignedUser});

  @override
  State<ManualHoldPage> createState() => _ManualHoldPageState();
}

class _ManualHoldPageState extends State<ManualHoldPage> {
  final QrCodeService _qrService = QrCodeService();

  // Records
  List<dynamic> _records = [];
  bool _isLoading = false;
  String? _nextCursor;
  bool _hasMore = true;

  // Filter state
  bool showingFilters = false;
  String? selectedUserId;
  String? selectedQrCodeId;

  // Filter data
  List<AppUser> users = [];
  List<QrCode> qrCodes = [];
  bool loadingUsers = false;
  bool loadingQr = false;

  bool get _isFromQrCard => widget.qrCode != null;

  @override
  void initState() {
    super.initState();
    if (_isFromQrCard) {
      selectedQrCodeId = widget.qrCode!.qrId;
    } else if (widget.initialQrId != null) {
      selectedQrCodeId = widget.initialQrId;
    }
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    await _loadRecords();
    if (!_isFromQrCard) {
      await _fetchUsersAndQrCodes();
    }
  }

  Future<void> _fetchUsersAndQrCodes() async {
    final jwt = await AppWriteService().getJWT();

    setState(() => loadingUsers = true);
    try {
      final fetched = await UsersService.listUsers(jwtToken: jwt);
      users = fetched.appUsers;
    } catch (_) {}
    if (mounted) setState(() => loadingUsers = false);

    if (mounted) setState(() => loadingQr = true);
    try {
      qrCodes = await _qrService.getQrCodes(jwt);
    } catch (_) {}
    if (mounted) setState(() => loadingQr = false);
  }

  List<QrCode> get filteredQrCodes {
    if (selectedUserId == null) return qrCodes;
    return qrCodes.where((qr) => qr.assignedUserId == selectedUserId).toList();
  }

  Future<void> _reFetchWithCurrentFilters() async {
    _nextCursor = null;
    await _loadRecords();
  }

  Future<void> _loadRecords({bool loadMore = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final jwt = await AppWriteService().getJWT();
      final result = await _qrService.getManualHoldHistory(
        qrId: selectedQrCodeId,
        userId: selectedUserId,
        cursor: loadMore ? _nextCursor : null,
        limit: 25,
        jwtToken: jwt,
      );

      if (result['success'] == true) {
        final newRecords = result['records'] as List<dynamic>;
        setState(() {
          if (loadMore) {
            _records.addAll(newRecords);
          } else {
            _records = newRecords;
          }
          _nextCursor = result['nextCursor'];
          _hasMore = result['nextCursor'] != null;
        });
      } else {
        _showErrorDialog(result['error'] ?? 'Failed to load records');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('Request Failed'),
        content: Text(message),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  String _inr(num paise) => CurrencyUtils.formatIndianCurrency(paise / 100);

  String _resolveUser(String? userId) {
    if (userId == null || userId.isEmpty) return '-';
    // Check passed assignedUser first
    if (widget.assignedUser != null && widget.assignedUser!.id == userId) {
      return '${widget.assignedUser!.email} (${widget.assignedUser!.role})';
    }
    // Check users list loaded for filters
    try {
      final user = users.firstWhere((u) => u.id == userId);
      return '${user.email} (${user.role})';
    } catch (_) {
      return userId;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showQrDetailsDialog() {
    final qr = widget.qrCode;
    if (qr == null) return;

    String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.qr_code, size: 22),
              const SizedBox(width: 8),
              Expanded(child: SelectableText('QR: ${qr.qrId}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (qr.imageUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: qr.imageUrl,
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(
                            width: 180, height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => const Icon(Icons.error, size: 60),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qr.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          qr.isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: qr.isActive ? Colors.green : Colors.red),
                        ),
                      ),
                      if (qr.assignedUserId != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.person, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          widget.assignedUser != null
                              ? '${widget.assignedUser!.email} (${widget.assignedUser!.role})'
                              : qr.assignedUserId!,
                          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis,
                        )),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Today Pay-In', inr(qr.todayTotalPayIn ?? 0)),
                  _detailRow('Total Transactions', CurrencyUtils.formatIndianCurrencyWithoutSign(qr.totalTransactions ?? 0)),
                  _detailRow('Total Amount Received', inr(qr.totalPayInAmount ?? 0)),
                  _detailRow('Avail. for Withdrawal', inr(qr.amountAvailableForWithdrawal ?? 0)),
                  const Divider(height: 20),
                  _detailRow('Withdrawal Requested', inr(qr.withdrawalRequestedAmount ?? 0)),
                  _detailRow('Withdrawal Approved', inr(qr.withdrawalApprovedAmount ?? 0)),
                  _detailRow('Commission On-Hold', inr(qr.commissionOnHold ?? 0)),
                  _detailRow('Commission Paid', inr(qr.commissionPaid ?? 0)),
                  _detailRow('Amount On-Hold', inr(qr.amountOnHold ?? 0), highlight: true),
                  if (qr.createdAt != null) ...[
                    const Divider(height: 20),
                    _detailRow('Created', _formatDate(qr.createdAt)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: highlight ? Colors.orange.shade800 : Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: highlight ? Colors.orange.shade800 : null)),
        ],
      ),
    );
  }

  Future<void> _showCreateHoldDialog() async {
    final qrId = widget.qrCode?.qrId ?? selectedQrCodeId;
    if (qrId == null || qrId.isEmpty) {
      _showErrorDialog('No QR selected');
      return;
    }

    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String action = 'hold';
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Manual Hold / Release'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              qrId,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'hold', label: Text('Hold'), icon: Icon(Icons.lock)),
                        ButtonSegment(value: 'release', label: Text('Release'), icon: Icon(Icons.lock_open)),
                      ],
                      selected: {action},
                      onSelectionChanged: (val) {
                        setDialogState(() => action = val.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Amount (Rs.) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                        helperText: 'Enter amount in Rupees',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () async {
                        final amountStr = amountCtrl.text.trim();
                        final rupees = double.tryParse(amountStr);
                        if (rupees == null || rupees <= 0) {
                          _showErrorDialog('Enter a valid amount in Rupees');
                          return;
                        }
                        final amountPaise = (rupees * 100).round();

                        setDialogState(() => submitting = true);
                        try {
                          final jwt = await AppWriteService().getJWT();
                          final result = await _qrService.manualHoldOnQr(
                            qrId: qrId,
                            amountPaise: amountPaise,
                            action: action,
                            reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null,
                            jwtToken: jwt,
                          );

                          if (result['success'] == true) {
                            _showSnack(result['message'] ?? 'Success');
                            Navigator.pop(ctx);
                            _loadRecords();
                          } else {
                            _showErrorDialog(result['error'] ?? 'Failed');
                          }
                        } catch (e) {
                          _showErrorDialog(e.toString());
                        } finally {
                          setDialogState(() => submitting = false);
                        }
                      },
                icon: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(action == 'hold' ? Icons.lock : Icons.lock_open),
                label: Text(submitting ? 'Processing...' : (action == 'hold' ? 'Place Hold' : 'Release Hold')),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── Filters panel (same pattern as ManageWithdrawalsNew) ───
  Widget _buildFilters() {
    final userHasQrCodes = selectedUserId == null || filteredQrCodes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // User filter
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('Filter User', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      loadingUsers
                          ? const LinearProgressIndicator(minHeight: 2)
                          : DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedUserId,
                              hint: const Text('Select User'),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('--------')),
                                ...users.map(
                                  (u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text('${u.name} (${u.email})', overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedUserId = value;
                                  selectedQrCodeId = null;
                                });
                                _reFetchWithCurrentFilters();
                              },
                            ),
                    ],
                  ),
                ),

                // QR filter
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('Filter QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      loadingQr
                          ? const LinearProgressIndicator(minHeight: 2)
                          : DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: selectedQrCodeId,
                              hint: const Text('Select QR Code'),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('--------')),
                                ...filteredQrCodes.map(
                                  (qr) => DropdownMenuItem(
                                    value: qr.qrId,
                                    child: Text('${qr.qrId} (${qr.totalTransactions})', overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => selectedQrCodeId = value);
                                _reFetchWithCurrentFilters();
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),

            if (selectedUserId != null && !userHasQrCodes)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No QR codes assigned to this user.', style: TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      selectedUserId = null;
                      selectedQrCodeId = null;
                    });
                    _reFetchWithCurrentFilters();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply'),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _reFetchWithCurrentFilters();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = widget.userMeta.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isFromQrCard ? 'Hold on ${widget.qrCode!.qrId}' : 'Manual Hold on QR'),
        actions: [
          if (_isFromQrCard)
            IconButton(
              onPressed: _showQrDetailsDialog,
              icon: const Icon(Icons.info_outline),
              tooltip: 'View QR Details',
            ),
          if (isAdmin && (_isFromQrCard || selectedQrCodeId != null))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _showCreateHoldDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Hold/Release'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters toggle (only from dashboard / sidebar, not from QR card)
          if (!_isFromQrCard) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Text('Filters: '),
                  Switch(
                    value: showingFilters,
                    onChanged: (val) => setState(() => showingFilters = val),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      _nextCursor = null;
                      _loadRecords();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            if (showingFilters) _buildFilters(),
          ],

          // Records list
          if (_isLoading && _records.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),

          Expanded(
            child: _isLoading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No hold records found', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          _nextCursor = null;
                          await _loadRecords();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _records.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _records.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : TextButton(
                                          onPressed: () => _loadRecords(loadMore: true),
                                          child: const Text('Load More'),
                                        ),
                                ),
                              );
                            }
                            return _buildRecordCard(_records[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(dynamic record) {
    final theme = Theme.of(context);
    final action = record['action'] ?? '';
    final isHold = action == 'hold';
    final color = isHold ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isHold ? Icons.lock : Icons.lock_open, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        isHold ? 'HOLD' : 'RELEASE',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _inr(record['amountPaise'] ?? 0),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
                const Spacer(),
                Text(
                  _formatDate(record['createdAt']),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('QR', record['qrId'] ?? '-', Icons.qr_code),
                _chip('Prev Hold', _inr(record['previousHold'] ?? 0), Icons.history),
                _chip('New Hold', _inr(record['newHold'] ?? 0), Icons.update),
                _chip('New Avail', _inr(record['newAvailable'] ?? 0), Icons.savings),
              ],
            ),
            if (record['reason'] != null && record['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record['reason'],
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Admin: ${record['adminName'] ?? record['adminId'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                if (record['assignedUserId'] != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.person, size: 13, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'User: ${_resolveUser(record['assignedUserId'])}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(value, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
