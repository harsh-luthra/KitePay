import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Your imports
import 'AppWriteService.dart';
import 'CommissionService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';

class CommissionSummaryBoardPageBkup extends StatefulWidget {
  const CommissionSummaryBoardPageBkup({super.key, required this.userMeta});
  final AppUser userMeta;

  @override
  State<CommissionSummaryBoardPageBkup> createState() => _CommissionSummaryBoardPagBkupeState();
}

class _CommissionSummaryBoardPagBkupeState extends State<CommissionSummaryBoardPageBkup> {
  // Filters
  String _roleFilter = 'subadmin'; // 'admin' | 'subadmin'
  final List<AppUser> _allSubadmins = [];
  AppUser? _selectedSubadmin;      // single selection
  bool _loadingUsers = false;

  // Mode
  String _mode = 'today'; // today | date | range | last
  DateTime? _date;
  DateTime? _start;
  DateTime? _end;
  int _lastDays = 7;

  // UI state
  bool _loading = false;
  bool _expanded = false;

  // Results
  final Map<String, CommissionSummaryResult> _results = {}; // userId -> result

  @override
  void initState() {
    super.initState();
    if ((widget.userMeta.role).toLowerCase() == 'subadmin') {
      _roleFilter = 'subadmin';
      _selectedSubadmin = widget.userMeta;
    }else{
      _roleFilter = 'admin';
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final list = await UserService.listSubAdmins(jwt);
      setState(() {
        _allSubadmins
          ..clear()
          ..addAll(list);
        if ((widget.userMeta.role).toLowerCase() == 'admin') {
          _selectedSubadmin ??= list.isNotEmpty ? list.first : null;
        } else {
          // subadmin: ensure selection is self
          _selectedSubadmin = widget.userMeta;
        }
      });
      await _fetchSummaries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load subadmins: $e')));
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _fetchSummaries() async {
    final isAdmin = (widget.userMeta.role).toLowerCase() == 'admin';

    setState(() {
      _loading = true;
      _results.clear();
    });
    try {
      final jwt = await AppWriteService().getJWT();

      final ids = isAdmin
          ? (_roleFilter == 'admin'
          ? <String>[widget.userMeta.id]
          : (_selectedSubadmin != null ? <String>[_selectedSubadmin!.id] : <String>[]))
          : <String>[widget.userMeta.id]; // subadmin: only self

      if (ids.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      for (final id in ids) {
        CommissionSummaryResult res;
        switch (_mode) {
          case 'today':
            res = (await CommissionService.fetchCommissionSummary(userId: id, mode: 'today', jwtToken: jwt));
            break;
          case 'date':
            if (_date == null) throw Exception('Select a date');
            res = (await CommissionService.fetchCommissionSummary(userId: id, mode: 'date', date: _date, jwtToken: jwt));
            break;
          case 'range':
            if (_start == null || _end == null) throw Exception('Select start and end dates');
            res = (await CommissionService.fetchCommissionSummary(
                userId: id, mode: 'range', start: _start, end: _end, jwtToken: jwt));
            break;
          case 'last':
            res = (await CommissionService.fetchCommissionSummary(
                userId: id, mode: 'last', days: _lastDays, jwtToken: jwt));
            break;
          default:
            res = (await CommissionService.fetchCommissionSummary(userId: id, mode: 'today', jwtToken: jwt));
        }
        _results[id] = res;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch summary: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Future<void> _pickDate({required String kind}) async {
    final now = DateTime.now();
    final initial = kind == 'date'
        ? (_date ?? now)
        : kind == 'start'
        ? (_start ?? now)
        : (_end ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (kind == 'date') _date = picked;
        if (kind == 'start') _start = picked;
        if (kind == 'end') _end = picked;
      });
    }
  }

  Widget _filterBar() {
    final isAdmin = (widget.userMeta.role).toLowerCase() == 'admin';
    final df = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isAdmin) // Role picker visible only to admins
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _roleFilter,
                      items: const [
                        DropdownMenuItem(value: 'subadmin', child: Text('Role: Sub-admin')),
                        DropdownMenuItem(value: 'admin', child: Text('Role: Admin')),
                      ],
                      onChanged: (v) => setState(() {
                        _roleFilter = v ?? 'subadmin';
                        if (_roleFilter == 'admin') {
                          _selectedSubadmin = null;
                        } else if (_allSubadmins.isNotEmpty && _selectedSubadmin == null) {
                          _selectedSubadmin = _allSubadmins.first;
                        }
                      }),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),

                if (isAdmin && _roleFilter == 'subadmin')
                  SizedBox(
                    width: 380,
                    child: _loadingUsers
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<AppUser>(
                      value: _selectedSubadmin,
                      isExpanded: true,
                      items: _allSubadmins.map((u) {
                        final label = '${u.name.isEmpty ? '(No name)' : u.name} • ${u.email}';
                        return DropdownMenuItem<AppUser>(
                          value: u,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (u) => setState(() => _selectedSubadmin = u),
                      decoration: const InputDecoration(
                        labelText: 'Select Subadmin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                if (!isAdmin) // Subadmin: read-only identity chip
                  InputDecorator(
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Subadmin'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('${widget.userMeta.name} • ${widget.userMeta.email}',
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),

                // Mode
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _mode,
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'date', child: Text('Single Date')),
                      DropdownMenuItem(value: 'range', child: Text('Date Range')),
                      DropdownMenuItem(value: 'last', child: Text('Last N Days')),
                    ],
                    onChanged: (v) => setState(() => _mode = v ?? 'today'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),

                // Date pickers based on mode
                if (_mode == 'date')
                  SizedBox(
                    width: 200,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(_date == null ? 'Pick date' : df.format(_date!)),
                      onPressed: () => _pickDate(kind: 'date'),
                    ),
                  ),

                if (_mode == 'range') ...[
                  SizedBox(
                    width: 200,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(_start == null ? 'Start date' : df.format(_start!)),
                      onPressed: () => _pickDate(kind: 'start'),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(_end == null ? 'End date' : df.format(_end!)),
                      onPressed: () => _pickDate(kind: 'end'),
                    ),
                  ),
                ],

                if (_mode == 'last')
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<int>(
                      value: _lastDays,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                        DropdownMenuItem(value: 14, child: Text('Last 14 days')),
                        DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                      ],
                      onChanged: (v) => setState(() => _lastDays = v ?? 7),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),

                // Controls
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Fetch'),
                  onPressed: isAdmin
                      ? (_roleFilter == 'subadmin' && _selectedSubadmin == null ? null : _fetchSummaries)
                      : _fetchSummaries, // subadmin can always fetch own data
                ),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _mode = 'today';
                      _date = null;
                      _start = null;
                      _end = null;
                      _lastDays = 7;
                      _expanded = false;
                    });
                    _fetchSummaries();
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expanded view'),
                  selected: _expanded,
                  onSelected: (v) => setState(() => _expanded = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String userId, CommissionSummaryResult r, {String? title}) {
    final isAdmin = (widget.userMeta.role).toLowerCase() == 'admin';
    final match = _allSubadmins.where((u) => u.id == userId);
    final name = isAdmin && userId == widget.userMeta.id
        ? 'Admin'
        : (match.isEmpty ? (userId == widget.userMeta.id ? widget.userMeta.name : 'Subadmin') : match.first.name);
    final email = isAdmin && userId == widget.userMeta.id
        ? 'Admin Email'
        : (match.isEmpty ? (userId == widget.userMeta.id ? widget.userMeta.email : '') : match.first.email);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title ?? name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total: ${_fmtRupees(r.totalPaise)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Days line (compact tokens)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.days.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 6),
                      Text(_fmtRupees(d.commissionPaise),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),

            if (_expanded) ...[
              const SizedBox(height: 10),
              _expandedTable(r),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expandedTable(CommissionSummaryResult r) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: const [
                Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text('Commission', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          ...r.days.map((d) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(child: Text(d.date)),
                Expanded(child: Text(_fmtRupees(d.commissionPaise))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Summary Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSummaries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _results.isEmpty
                ? const Center(child: Text('No data'))
                : ListView(
              children:
              _results.entries.map((e) => _summaryCard(e.key, e.value)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
