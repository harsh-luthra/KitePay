import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Your imports
import 'AppWriteService.dart';
import 'CommissionService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';

class CommissionSummaryBoardPage extends StatefulWidget {
  const CommissionSummaryBoardPage({super.key, required this.userMeta});
  final AppUser userMeta;

  @override
  State<CommissionSummaryBoardPage> createState() => _CommissionSummaryBoardPageState();
}

class _CommissionSummaryBoardPageState extends State<CommissionSummaryBoardPage> {
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
    if ((widget.userMeta.role).toLowerCase() == 'admin') {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final list = await UsersService.listSubAdmins(jwt);
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

    setState(() { _loading = true; _results.clear(); });

    try {
      final jwt = await AppWriteService().getJWT();

      // ALL fast path
      final isAll = isAdmin && _roleFilter == 'all';
      if (isAll) {
        late AllSummaryResult allRes;
        switch (_mode) {
          case 'today':
            allRes = await CommissionService.fetchCommissionSummaryAll(mode: 'today', jwtToken: jwt);
            break;
          case 'date':
            if (_date == null) throw Exception('Select a date');
            allRes = await CommissionService.fetchCommissionSummaryAll(mode: 'date', date: _date, jwtToken: jwt);
            break;
          case 'range':
            if (_start == null || _end == null) throw Exception('Select start and end dates');
            allRes = await CommissionService.fetchCommissionSummaryAll(mode: 'range', start: _start, end: _end, jwtToken: jwt);
            break;
          case 'last':
            allRes = await CommissionService.fetchCommissionSummaryAll(mode: 'last', days: _lastDays, jwtToken: jwt);
            break;
        }

        // aggregated
        _results['*ALL*'] = CommissionSummaryResult(
          userId: '*ALL*',
          start: allRes.start,
          end: allRes.end,
          totalPaise: allRes.totalPaise,
          days: allRes.days.map((d) =>
              CommissionSummaryDay(date: d.date, commissionPaise: d.totalPaise)).toList(),
        );

        allRes.perUser.forEach((userId, series) {
          _results[userId] = CommissionSummaryResult(
            userId: userId,
            start: allRes.start,
            end: allRes.end,
            totalPaise: series.totalPaise,
            days: series.days.map((d) =>
                CommissionSummaryDay(date: d.date, commissionPaise: d.paise)).toList(),
          );
        });

        setState(() { _loading = false; });

        if (mounted) setState(() => _loading = false);
        return; // IMPORTANT: stop here so we don't fall into per-user logic
      }

      // Per-user flow (admin/subadmin)
      final ids = isAdmin
          ? (_roleFilter == 'admin'
          ? <String>[widget.userMeta.id]
          : (_selectedSubadmin != null ? <String>[_selectedSubadmin!.id] : <String>[]))
          : <String>[widget.userMeta.id];

      if (ids.isEmpty) { if (mounted) setState(() => _loading = false); return; }

      for (final id in ids) {
        CommissionSummaryResult res;
        switch (_mode) {
          case 'today':
            res = await CommissionService.fetchCommissionSummary(userId: id, mode: 'today', jwtToken: jwt);
            break;
          case 'date':
            if (_date == null) throw Exception('Select a date');
            res = await CommissionService.fetchCommissionSummary(userId: id, mode: 'date', date: _date, jwtToken: jwt);
            break;
          case 'range':
            if (_start == null || _end == null) throw Exception('Select start and end dates');
            res = await CommissionService.fetchCommissionSummary(userId: id, mode: 'range', start: _start, end: _end, jwtToken: jwt);
            break;
          case 'last':
            res = await CommissionService.fetchCommissionSummary(userId: id, mode: 'last', days: _lastDays, jwtToken: jwt);
            break;
          default:
            res = await CommissionService.fetchCommissionSummary(userId: id, mode: 'today', jwtToken: jwt);
        }
        _results[id] = res;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch summary: $e')));
      setState(() => _loading = false);
    }
  }

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Future<void> _pickDate({required String kind}) async {
    final now = DateTime.now();

    DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime _addDays(DateTime d, int n) => _atMidnight(d).add(Duration(days: n));

    final initial = kind == 'date'
        ? (_date ?? now)
        : kind == 'start'
        ? (_start ?? now)
        : (_end ?? (_start ?? now));

    DateTime first = DateTime(now.year - 2, 1, 1);
    DateTime last = DateTime(now.year + 2, 12, 31);

    // If picking end and we have a start, constrain the calendar max to start+29
    if (kind == 'end' && _start != null) {
      final maxEnd = _addDays(_start!, 29);
      if (maxEnd.isBefore(last)) last = maxEnd;
    }
    // If picking start and we have an end, constrain calendar min to end-29 (optional UX)
    if (kind == 'start' && _end != null) {
      final minStart = _addDays(_end!, -29);
      if (minStart.isAfter(first)) first = minStart;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked == null) return;
    final p = _atMidnight(picked);

    setState(() {
      if (kind == 'date') {
        _date = p;
        return;
      }

      if (kind == 'start') {
        _start = p;
        if (_end == null) {
          _end = p;
        } else {
          // Ensure end >= start
          if (_end!.isBefore(_start!)) _end = _start!;
          // Enforce 30-day inclusive window
          final maxEnd = _addDays(_start!, 29);
          if (_end!.isAfter(maxEnd)) _end = maxEnd;
        }
        return;
      }

      if (kind == 'end') {
        if (_start == null) {
          _start = p;
          _end = p;
        } else {
          // Enforce end >= start
          var candidate = p.isBefore(_start!) ? _start! : p;
          // Enforce 30-day inclusive window
          final maxEnd = _addDays(_start!, 29);
          if (candidate.isAfter(maxEnd)) {
            candidate = maxEnd;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Range limited to 30 days. End date adjusted.')),
            );
          }
          _end = candidate;
        }
      }
    });
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
                        DropdownMenuItem(value: 'all', child: Text('Role: ALL')),
                      ],
                      onChanged: (v) => setState(() {
                        _roleFilter = v ?? 'subadmin';
                        if (_roleFilter == 'admin') {
                          _selectedSubadmin = null;
                        } else if (_roleFilter == 'subadmin') {
                          if (_allSubadmins.isNotEmpty) _selectedSubadmin = _allSubadmins.first;
                        } // if 'all' keep as-is
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
                  onPressed: () {
                    final isAdmin = (widget.userMeta.role).toLowerCase() == 'admin';
                    if (!isAdmin && _roleFilter == 'subadmin' && _selectedSubadmin == null) return;
                    _fetchSummaries();
                  },
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
                if (_start != null && _end != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Range: ${_end!.difference(DateTime(_start!.year,_start!.month,_start!.day)).inDays + 1} days',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String userId, CommissionSummaryResult r, {String? title}) {
    final isAdmin = (widget.userMeta.role).toLowerCase() == 'admin';
    final isAllKey = userId == '*ALL*';
    final match = _allSubadmins.where((u) => u.id == userId);

    final name = isAllKey
        ? 'All Users'
        : (isAdmin && userId == widget.userMeta.id
        ? widget.userMeta.name
        : (match.isEmpty ? (userId == widget.userMeta.id ? widget.userMeta.name : 'Subadmin') : match.first.name));

    final email = isAllKey
        ? ''
        : (isAdmin && userId == widget.userMeta.id
        ? widget.userMeta.email
        : (match.isEmpty ? (userId == widget.userMeta.id ? widget.userMeta.email : '') : match.first.email));

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
    final sorted = _sortedEntries();
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
              children: sorted.map((e) => _summaryCard(e.key, e.value)).toList(),
            )
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, CommissionSummaryResult>> _sortedEntries() {
    final entries = _results.entries.toList();
    final adminId = widget.userMeta.id;

    entries.sort((a, b) {
      // 1) All Users first
      final aAll = a.key == '*ALL*' ? 0 : 1;
      final bAll = b.key == '*ALL*' ? 0 : 1;
      if (aAll != bAll) return aAll - bAll;

      // 2) Admin second
      final aAdmin = a.key == adminId ? 0 : 1;
      final bAdmin = b.key == adminId ? 0 : 1;
      if (aAdmin != bAdmin) return aAdmin - bAdmin;

      // 3) Others by totalPaise desc
      final byAmount = b.value.totalPaise.compareTo(a.value.totalPaise);
      if (byAmount != 0) return byAmount;

      // Stable tie-breaker: by display name/email ascending
      String nameOf(String id) {
        if (id == '*ALL*') return 'All Users';
        if (id == adminId) return 'Admin';
        final m = _allSubadmins.where((u) => u.id == id);
        return (m.isEmpty ? '' : m.first.name).toLowerCase();
      }

      String emailOf(String id) {
        if (id == '*ALL*') return '';
        if (id == adminId) return 'Admin Email';
        final m = _allSubadmins.where((u) => u.id == id);
        return (m.isEmpty ? '' : m.first.email).toLowerCase();
      }

      final n = nameOf(a.key).compareTo(nameOf(b.key));
      if (n != 0) return n;
      return emailOf(a.key).compareTo(emailOf(b.key));
    });

    return entries;
  }


}
