// ===== UI Page =====
import 'dart:async';

import 'package:admin_qr_manager/UsersService.dart';
import 'package:admin_qr_manager/models/AppUser.dart';
import 'package:admin_qr_manager/widget/CommissionCard.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'CommissionService.dart';
import 'models/Commission.dart';

class CommissionTransactionsPage extends StatefulWidget {
  final String? initialUserId;
  final AppUser userMeta;
  const CommissionTransactionsPage({super.key, this.initialUserId, required this.userMeta});
  @override
  State<CommissionTransactionsPage> createState() => _CommissionTransactionsPageState();
}

class _CommissionTransactionsPageState extends State<CommissionTransactionsPage> {
  // Data
  final List<Commission> _items = [];
  String? _nextCursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  // Filters
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _sourceIdCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _minAmtCtrl = TextEditingController();
  final TextEditingController _maxAmtCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _earningType; // null | 'admin' | 'subadmin'
  String _searchField = 'userId'; // 'userId' | 'sourceWithdrawalId'
  int _limit = 25;

  List<AppUser> _subadmins = [];
  AppUser? _selectedSubadmin;
  bool _loadingSubadmins = false;

  bool showingFilters = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) {
      _userIdCtrl.text = widget.initialUserId!;
    }
    if(widget.userMeta.role == "admin"){
      _loadSubadmins(); // load dropdown options
    }
    _fetch(firstLoad: true);
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _sourceIdCtrl.dispose();
    _searchCtrl.dispose();
    _minAmtCtrl.dispose();
    _maxAmtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubadmins() async {
    setState(() => _loadingSubadmins = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final list = await UsersService.listSubAdmins(jwt);
      setState(() {
        _subadmins = list;
        // If existing userId matches one, preselect:
        if (_userIdCtrl.text.isNotEmpty) {
          _selectedSubadmin = _subadmins.firstWhere(
                (u) => u.id == _userIdCtrl.text.trim(),
            orElse: () => _selectedSubadmin ?? (list.isNotEmpty ? list.first : null) as AppUser,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subadmins: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSubadmins = false);
    }
  }

  Map<String, AppUser> get _subadminById =>
      { for (final u in _subadmins) u.id: u };

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();

    DateTime _mid(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _addDays(DateTime d, int n) => _mid(d).add(Duration(days: n));

    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? (_fromDate ?? now));

    DateTime first = DateTime(now.year - 2, 1, 1);
    DateTime last = DateTime(now.year + 2, 12, 31);

    if (!isFrom && _fromDate != null) {
      final maxEnd = _addDays(_fromDate!, 29);
      if (maxEnd.isBefore(last)) last = maxEnd;
    }
    if (isFrom && _toDate != null) {
      final minStart = _addDays(_toDate!, -29);
      if (minStart.isAfter(first)) first = minStart;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;

    final p = _mid(picked);

    setState(() {
      if (isFrom) {
        _fromDate = p;
        if (_toDate == null) {
          _toDate = p;
        } else {
          if (_toDate!.isBefore(_fromDate!)) _toDate = _fromDate!;
          final maxEnd = _addDays(_fromDate!, 29);
          if (_toDate!.isAfter(maxEnd)) _toDate = maxEnd;
        }
      } else {
        if (_fromDate == null) {
          _fromDate = p;
          _toDate = p;
        } else {
          var candidate = p.isBefore(_fromDate!) ? _fromDate! : p;
          final maxEnd = _addDays(_fromDate!, 29);
          if (candidate.isAfter(maxEnd)) {
            candidate = maxEnd;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Range limited to 30 days. End date adjusted.')),
            );
          }
          _toDate = candidate;
        }
      }
    });
  }

  int? _toPaise(String s) {
    if (s.trim().isEmpty) return null;
    final n = num.tryParse(s.trim());
    if (n == null) return null;
    return (n * 100).round();
    // If inputs are already paise, remove *100
  }

  Future<void> _fetch({bool firstLoad = false}) async {
    if (_loading || _loadingMore) return;
    if (!firstLoad && (!_hasMore || _nextCursor == null)) return;

    setState(() {
      if (firstLoad) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final jwt = await AppWriteService().getJWT();
      final page = await CommissionService.fetchCommissions(
        userId: _userIdCtrl.text.isEmpty ? null : _userIdCtrl.text.trim(),
        earningType: _earningType,
        sourceWithdrawalId: _sourceIdCtrl.text.isEmpty ? null : _sourceIdCtrl.text.trim(),
        minAmount: _toPaise(_minAmtCtrl.text),
        maxAmount: _toPaise(_maxAmtCtrl.text),
        from: _fromDate,
        to: _toDate,
        cursor: firstLoad ? null : _nextCursor,
        limit: _limit,
        searchField: _searchCtrl.text.isEmpty ? null : _searchField,
        searchValue: _searchCtrl.text.isEmpty ? null : _searchCtrl.text.trim(),
        jwtToken: jwt,
      );

      setState(() {
        if (firstLoad) {
          _items
            ..clear()
            ..addAll(page.commissions);
        } else {
          final existing = _items.map((e) => e.id).toSet();
          _items.addAll(page.commissions.where((e) => !existing.contains(e.id)));
        }
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch commissions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _applyFilters() async {
    // safety check
    if (_fromDate != null && _toDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final span = _toDate!.difference(start).inDays + 1;
      if (span > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range of 30 days or less.')),
        );
        return;
      }
    }

    setState(() {
      _nextCursor = null;
      _hasMore = true;
    });
    await _fetch(firstLoad: true);
  }

  Widget _filters() {
    final df = DateFormat('yyyy-MM-dd');
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if(widget.userMeta.role == "admin")
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      value: _earningType,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Earning of: All')),
                        DropdownMenuItem(value: 'admin', child: Text('Earning of: admin')),
                        DropdownMenuItem(value: 'subAdmin', child: Text('Earning of: subAdmin')),
                      ],
                      onChanged: (v) => setState(() => _earningType = v),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                if(widget.userMeta.role == "admin" && _earningType == 'subAdmin')
                SizedBox(
                  width: 320,
                  child: _loadingSubadmins
                      ? const Center(child: LinearProgressIndicator())
                      : DropdownButtonFormField<AppUser>(
                    value: _selectedSubadmin,
                    isExpanded: true,
                    items: _subadmins.map((u) {
                      final label = '${u.name.isEmpty ? '(No name)' : u.name} • ${u.email}';
                      return DropdownMenuItem<AppUser>(
                        value: u,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (u) {
                      setState(() {
                        _selectedSubadmin = u;
                        _userIdCtrl.text = u?.id ?? '';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select SubAdmin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                // SizedBox(
                //   width: 280,
                //   child: TextField(
                //     controller: _sourceIdCtrl,
                //     decoration: const InputDecoration(
                //       labelText: 'Source Withdrawal ID',
                //       border: OutlineInputBorder(),
                //     ),
                //   ),
                // ),
                // SizedBox(
                //   width: 180,
                //   child: TextField(
                //     controller: _minAmtCtrl,
                //     keyboardType: TextInputType.number,
                //     decoration: const InputDecoration(
                //       labelText: 'Min Amount (₹)',
                //       border: OutlineInputBorder(),
                //     ),
                //   ),
                // ),
                // SizedBox(
                //   width: 180,
                //   child: TextField(
                //     controller: _maxAmtCtrl,
                //     keyboardType: TextInputType.number,
                //     decoration: const InputDecoration(
                //       labelText: 'Max Amount (₹)',
                //       border: OutlineInputBorder(),
                //     ),
                //   ),
                // ),
                // SizedBox(
                //   width: 220,
                //   child: DropdownButtonFormField<String>(
                //     value: _searchField,
                //     items: const [
                //       DropdownMenuItem(value: 'userId', child: Text('Search field: userId')),
                //       DropdownMenuItem(value: 'sourceWithdrawalId', child: Text('Search field: sourceWithdrawalId')),
                //     ],
                //     onChanged: (v) => setState(() => _searchField = v ?? 'userId'),
                //     decoration: const InputDecoration(border: OutlineInputBorder()),
                //   ),
                // ),
                // SizedBox(
                //   width: 260,
                //   child: TextField(
                //     controller: _searchCtrl,
                //     decoration: const InputDecoration(
                //       labelText: 'Search value',
                //       border: OutlineInputBorder(),
                //     ),
                //   ),
                // ),
                // SizedBox(
                //   width: 180,
                //   child: DropdownButtonFormField<int>(
                //     value: _limit,
                //     items: const [
                //       DropdownMenuItem(value: 10, child: Text('Limit: 10')),
                //       DropdownMenuItem(value: 25, child: Text('Limit: 25')),
                //       DropdownMenuItem(value: 50, child: Text('Limit: 50')),
                //     ],
                //     onChanged: (v) => setState(() => _limit = v ?? 25),
                //     decoration: const InputDecoration(border: OutlineInputBorder()),
                //   ),
                // ),
                Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_fromDate == null ? 'From date' : 'From: ${df.format(_fromDate!)}'),
                        onPressed: () => _pickDate(isFrom: true),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(_toDate == null ? 'To date' : 'To: ${df.format(_toDate!)}'),
                        onPressed: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                if (_fromDate != null && _toDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Range: ${_toDate!.difference(DateTime(_fromDate!.year,_fromDate!.month,_fromDate!.day)).inDays + 1} days',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply'),
                  onPressed: _applyFilters,
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userIdCtrl.clear();
                      _sourceIdCtrl.clear();
                      _searchCtrl.clear();
                      _minAmtCtrl.clear();
                      _maxAmtCtrl.clear();
                      _earningType = null;
                      _searchField = 'userId';
                      _fromDate = null;
                      _toDate = null;
                      _nextCursor = null;
                      _hasMore = true;
                    });
                    if (widget.initialUserId != null) {
                      _userIdCtrl.text = widget.initialUserId!;
                    }
                    _fetch(firstLoad: true);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Widget _row(Commission c) {
    final meta = _subadminById[c.userId];
    return CommissionCard(
      c: c,
      displayName: meta?.name,
      displayEmail: meta?.email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Transactions'),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Toggle Filters: '),
              Switch.adaptive(
                value: showingFilters,
                onChanged: (val) => setState(() => showingFilters = val),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (showingFilters) _filters(),
          Expanded(
            child: _loading
                ? ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 8,
              itemBuilder: (_, __) => const TransactionCardShimmer(),
            )
                : (_items.isEmpty
                ? RefreshIndicator(
              onRefresh: () => _fetch(firstLoad: true),
              child: ListView(
                padding: const EdgeInsets.only(top: 80),
                children: const [
                  Center(
                    child: Text(
                      'No commission transactions',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () => _fetch(firstLoad: true),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index < _items.length) return _row(_items[index]);

                  // Load-more sentinel
                  if (!_loadingMore) {
                    scheduleMicrotask(() => _fetch(firstLoad: false));
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
              ),
            )),
          ),
        ],
      ),
    );
  }

}
