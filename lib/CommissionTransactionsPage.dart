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
  bool get _isAdmin => widget.userMeta.role.toLowerCase() == 'admin';

  final ScrollController _scrollController = ScrollController();

  // Data
  final List<Commission> _items = [];
  String? _nextCursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  // Filters
  final TextEditingController _userIdCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _earningType;
  final int _limit = 25;

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
    if (_isAdmin) {
      _loadSubadmins();
    }
    _fetch(firstLoad: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubadmins() async {
    setState(() => _loadingSubadmins = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final list = await UsersService.listSubAdmins(jwt);
      setState(() {
        _subadmins = list;
        if (_userIdCtrl.text.isNotEmpty) {
          final match = _subadmins.where((u) => u.id == _userIdCtrl.text.trim());
          _selectedSubadmin = match.isNotEmpty
              ? match.first
              : (_selectedSubadmin ?? (list.isNotEmpty ? list.first : null));
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

    DateTime mid(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime addDays(DateTime d, int n) => mid(d).add(Duration(days: n));

    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? (_fromDate ?? now));

    DateTime first = DateTime(now.year - 2, 1, 1);
    DateTime last = DateTime(now.year + 2, 12, 31);

    if (!isFrom && _fromDate != null) {
      final maxEnd = addDays(_fromDate!, 29);
      if (maxEnd.isBefore(last)) last = maxEnd;
    }
    if (isFrom && _toDate != null) {
      final minStart = addDays(_toDate!, -29);
      if (minStart.isAfter(first)) first = minStart;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;

    final p = mid(picked);

    setState(() {
      if (isFrom) {
        _fromDate = p;
        if (_toDate == null) {
          _toDate = p;
        } else {
          if (_toDate!.isBefore(_fromDate!)) _toDate = _fromDate!;
          final maxEnd = addDays(_fromDate!, 29);
          if (_toDate!.isAfter(maxEnd)) _toDate = maxEnd;
        }
      } else {
        if (_fromDate == null) {
          _fromDate = p;
          _toDate = p;
        } else {
          var candidate = p.isBefore(_fromDate!) ? _fromDate! : p;
          final maxEnd = addDays(_fromDate!, 29);
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
        from: _fromDate,
        to: _toDate,
        cursor: firstLoad ? null : _nextCursor,
        limit: _limit,
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
    final hasActiveFilters = _earningType != null || _fromDate != null || _toDate != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isAdmin)
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      value: _earningType,
                      decoration: const InputDecoration(
                        labelText: 'Earning of',
                        prefixIcon: Icon(Icons.monetization_on_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'subAdmin', child: Text('SubAdmin')),
                      ],
                      onChanged: (v) => setState(() => _earningType = v),
                    ),
                  ),
                if (_isAdmin && _earningType == 'subAdmin')
                  SizedBox(
                    width: 280,
                    child: _loadingSubadmins
                        ? const LinearProgressIndicator(minHeight: 2)
                        : DropdownButtonFormField<AppUser>(
                      value: _selectedSubadmin,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'SubAdmin',
                        prefixIcon: Icon(Icons.supervisor_account_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
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
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Date row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InputChip(
                  label: Text(_fromDate == null ? 'From' : 'From: ${df.format(_fromDate!)}', style: const TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.date_range, size: 16),
                  onPressed: () => _pickDate(isFrom: true),
                  onDeleted: _fromDate != null ? () => setState(() => _fromDate = null) : null,
                ),
                InputChip(
                  label: Text(_toDate == null ? 'To' : 'To: ${df.format(_toDate!)}', style: const TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.date_range, size: 16),
                  onPressed: () => _pickDate(isFrom: false),
                  onDeleted: _toDate != null ? () => setState(() => _toDate = null) : null,
                ),
                if (_fromDate != null && _toDate != null)
                  Text(
                    '${_toDate!.difference(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)).inDays + 1} days',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (_fromDate != null || _toDate != null)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Dates', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() { _fromDate = null; _toDate = null; });
                      _applyFilters();
                    },
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasActiveFilters)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () {
                      setState(() {
                        _userIdCtrl.clear();
                        _earningType = null;
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
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.filter_alt, size: 18),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _applyFilters,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Scroll to top',
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
              }
            },
          ),
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
      body: _loading
          ? ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 8,
              itemBuilder: (_, __) => const TransactionCardShimmer(),
            )
          : RefreshIndicator(
              onRefresh: () => _fetch(firstLoad: true),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (showingFilters)
                    SliverToBoxAdapter(child: _filters()),
                  if (_items.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No commission transactions',
                          style: TextStyle(color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < _items.length) return _row(_items[index]);

                          if (!_loadingMore) {
                            WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(firstLoad: false));
                          }
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        childCount: _items.length + (_hasMore ? 1 : 0),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

}
