import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'CommissionService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'utils/app_spacing.dart';
import 'widget/dashboard_widgets.dart';

class CommissionSummaryBoardPage extends StatefulWidget {
  const CommissionSummaryBoardPage({super.key, required this.userMeta});
  final AppUser userMeta;

  @override
  State<CommissionSummaryBoardPage> createState() => _CommissionSummaryBoardPageState();
}

class _CommissionSummaryBoardPageState extends State<CommissionSummaryBoardPage> {
  bool get _isAdmin => widget.userMeta.role.toLowerCase() == 'admin';
  final ScrollController _scrollController = ScrollController();

  // Filters
  String _roleFilter = 'subadmin';
  final List<AppUser> _allSubadmins = [];
  AppUser? _selectedSubadmin;
  bool _loadingUsers = false;

  // Date range
  DateTime? _fromDate;
  DateTime? _toDate;

  // Legacy mode support for the API
  String _mode = 'today';
  DateTime? _date;
  DateTime? _start;
  DateTime? _end;
  final int _lastDays = 7;

  // UI state
  bool _loading = false;
  bool _showFilters = true;
  bool _expanded = false;
  bool _showZeroDays = false;
  bool _showChart = true;

  // Results
  final Map<String, CommissionSummaryResult> _results = {};

  @override
  void initState() {
    super.initState();
    if (!_isAdmin) {
      _roleFilter = 'subadmin';
      _selectedSubadmin = widget.userMeta;
    } else {
      _roleFilter = 'admin';
    }
    if (_isAdmin) {
      _loadUsers();
    } else {
      _fetchSummaries();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        if (_isAdmin) {
          _selectedSubadmin ??= list.isNotEmpty ? list.first : null;
        } else {
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

  // Sync _mode/_start/_end/_date from _fromDate/_toDate for API compatibility
  void _syncModeFromDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_fromDate != null && _toDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);

      if (from == to && from == today) {
        _mode = 'today';
      } else if (from == to) {
        _mode = 'date';
        _date = from;
      } else {
        _mode = 'range';
        _start = from;
        _end = to;
      }
    } else {
      _mode = 'today';
    }
  }

  Future<void> _fetchSummaries() async {
    _syncModeFromDates();
    final isAdmin = _isAdmin;

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

        if (mounted) setState(() => _loading = false);
        return;
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

  Widget _buildFilterBar() {
    final isAdmin = _isAdmin;

    return Card(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.allMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.filter_alt_outlined, size: 18, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('Filters', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),

            // Role & subadmin filters
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isAdmin)
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Filter Role', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DropdownButtonFormField<String>(
                          value: _roleFilter,
                          items: const [
                            DropdownMenuItem(value: 'subadmin', child: Text('Sub-admin')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'all', child: Text('ALL')),
                          ],
                          onChanged: (v) => setState(() {
                            _roleFilter = v ?? 'subadmin';
                            if (_roleFilter == 'admin') {
                              _selectedSubadmin = null;
                            } else if (_roleFilter == 'subadmin') {
                              if (_allSubadmins.isNotEmpty) _selectedSubadmin = _allSubadmins.first;
                            }
                          }),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isAdmin && _roleFilter == 'subadmin')
                  SizedBox(
                    width: 380,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Select Subadmin', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        _loadingUsers
                            ? const LinearProgressIndicator(minHeight: 2)
                            : DropdownButtonFormField<AppUser>(
                          value: _selectedSubadmin,
                          isExpanded: true,
                          items: _allSubadmins.map((u) {
                            final label = '${u.name.isEmpty ? '(No name)' : u.name} (${u.email})';
                            return DropdownMenuItem<AppUser>(
                              value: u,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (u) => setState(() => _selectedSubadmin = u),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!isAdmin)
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Subadmin', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        InputDecorator(
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text('${widget.userMeta.name} (${widget.userMeta.email})',
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Date range
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _datePickerChip(
                  label: 'From',
                  date: _fromDate,
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked;
                        if (_toDate != null && _toDate!.isBefore(picked)) {
                          _toDate = picked;
                        }
                      });
                    }
                  },
                  onClear: () => setState(() => _fromDate = null),
                ),
                _datePickerChip(
                  label: 'To',
                  date: _toDate,
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: _fromDate ?? DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _toDate = picked);
                    }
                  },
                  onClear: () => setState(() => _toDate = null),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Quick date presets + actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Today'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() { _fromDate = now; _toDate = now; });
                    _fetchSummaries();
                  },
                ),
                ActionChip(
                  label: const Text('Yesterday'),
                  onPressed: () {
                    final y = DateTime.now().subtract(const Duration(days: 1));
                    setState(() { _fromDate = y; _toDate = y; });
                    _fetchSummaries();
                  },
                ),
                ActionChip(
                  label: const Text('Last 7 Days'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() { _fromDate = now.subtract(const Duration(days: 6)); _toDate = now; });
                    _fetchSummaries();
                  },
                ),
                ActionChip(
                  label: const Text('Last 30 Days'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() { _fromDate = now.subtract(const Duration(days: 29)); _toDate = now; });
                    _fetchSummaries();
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Fetch'),
                  onPressed: () {
                    if (_roleFilter == 'subadmin' && _selectedSubadmin == null) return;
                    _fetchSummaries();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                      _expanded = false;
                      _showZeroDays = false;
                    });
                    _fetchSummaries();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerChip({
    required String label,
    required DateTime? date,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final df = DateFormat('yyyy-MM-dd');
    return InputChip(
      label: Text(date == null ? label : '$label: ${df.format(date)}'),
      avatar: const Icon(Icons.calendar_today, size: 16),
      onPressed: onPick,
      deleteIcon: date != null ? const Icon(Icons.close, size: 16) : null,
      onDeleted: date != null ? onClear : null,
    );
  }

  Widget _buildMetrics() {
    if (_results.isEmpty) return const SizedBox.shrink();

    // Calculate total across all results
    int grandTotal = 0;
    for (final r in _results.values) {
      grandTotal += r.totalPaise;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DashboardMetricGrid(items: [
        DashboardMetricCard.money(
          title: 'Total Commission',
          paise: grandTotal,
          icon: Icons.account_balance,
          color: Colors.indigo,
          showFull: true,
        ),
        DashboardMetricCard.count(
          title: 'Users',
          value: _results.keys.where((k) => k != '*ALL*').length,
          icon: Icons.people,
          color: Colors.teal,
          showFull: true,
        ),
      ]),
    );
  }

  Widget _summaryCard(String userId, CommissionSummaryResult r) {
    final theme = Theme.of(context);
    final isAdmin = _isAdmin;
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

    // Filter zero days
    final days = _showZeroDays
        ? r.days
        : r.days.where((d) => d.commissionPaise > 0).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _fmtRupees(r.totalPaise),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green, fontSize: 15),
                  ),
                ),
              ],
            ),

            if (days.isNotEmpty) ...[
              const SizedBox(height: 10),

              // Day cards (matching DaywisePayins style)
              ...days.reversed.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      d.date,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmtRupees(d.commissionPaise),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              )),
            ],

            if (_expanded && days.isNotEmpty) ...[
              const SizedBox(height: 6),
              _expandedTable(r, days),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expandedTable(CommissionSummaryResult r, List<CommissionSummaryDay> days) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: const [
                Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text('Commission', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          ...days.reversed.map((d) => Padding(
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

  // ── Chart helpers ──

  String _shortRupeeLabel(double value) {
    if (value >= 10000000) {
      final cr = value / 10000000;
      return cr == cr.roundToDouble() ? '${cr.toInt()}Cr' : '${cr.toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      final l = value / 100000;
      return l == l.roundToDouble() ? '${l.toInt()}L' : '${l.toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return value.toInt().toString();
  }

  double _niceInterval(double maxVal) {
    if (maxVal <= 0) return 1;
    final raw = maxVal / 5;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / mag;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * mag;
  }

  /// Aggregate commission by date from the *ALL* entry or first available result.
  List<CommissionSummaryDay> _chartDays() {
    // Prefer *ALL* aggregated entry
    if (_results.containsKey('*ALL*')) {
      return _results['*ALL*']!.days;
    }
    // Fallback: use the first result's days
    if (_results.isNotEmpty) {
      return _results.values.first.days;
    }
    return [];
  }

  Widget _buildChart(List<CommissionSummaryDay> days) {
    if (days.isEmpty) return const SizedBox.shrink();

    final filteredDays = _showZeroDays
        ? days
        : days.where((d) => d.commissionPaise > 0).toList();
    if (filteredDays.isEmpty) return const SizedBox.shrink();

    final maxPaise = filteredDays.fold<int>(0, (m, d) => math.max(m, d.commissionPaise));
    final maxRupees = maxPaise / 100.0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor = Colors.teal;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = theme.colorScheme.onSurfaceVariant;

    const double barSlotWidth = 44;
    final chartWidth = (filteredDays.length * barSlotWidth).clamp(150.0, double.infinity);
    final chartHeight = filteredDays.length <= 3 ? 200.0 : filteredDays.length <= 10 ? 220.0 : 250.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Text(
                'Commission Trend (${filteredDays.length} days)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              height: chartHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: SizedBox(
                  width: chartWidth,
                  child: BarChart(
                    duration: Duration.zero,
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxRupees > 0 ? maxRupees * 1.05 : 1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideVertically: true,
                          fitInsideHorizontally: true,
                          tooltipRoundedRadius: 8,
                          tooltipMargin: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          getTooltipColor: (_) => isDark ? Colors.grey.shade800 : Colors.white,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final day = filteredDays[group.x];
                            return BarTooltipItem(
                              '${day.date}\n${_fmtRupees(day.commissionPaise)}',
                              TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= filteredDays.length) return const SizedBox.shrink();
                              final date = filteredDays[idx].date;
                              final parts = date.split('-');
                              final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : date;
                              return SideTitleWidget(
                                meta: meta,
                                angle: filteredDays.length > 15 ? -0.5 : 0,
                                child: Text(label, style: TextStyle(fontSize: 9, color: labelColor)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 58,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Text(_shortRupeeLabel(value), style: TextStyle(fontSize: 10, color: labelColor));
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _niceInterval(maxRupees),
                        getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.8),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(filteredDays.length, (i) {
                        final rupees = filteredDays[i].commissionPaise / 100.0;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: rupees,
                              color: barColor,
                              width: filteredDays.length > 20 ? 12 : filteredDays.length > 10 ? 16 : filteredDays.length > 3 ? 20 : 26,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, CommissionSummaryResult>> _sortedEntries() {
    final entries = _results.entries.toList();
    final adminId = widget.userMeta.id;

    entries.sort((a, b) {
      final aAll = a.key == '*ALL*' ? 0 : 1;
      final bAll = b.key == '*ALL*' ? 0 : 1;
      if (aAll != bAll) return aAll - bAll;

      final aAdmin = a.key == adminId ? 0 : 1;
      final bAdmin = b.key == adminId ? 0 : 1;
      if (aAdmin != bAdmin) return aAdmin - bAdmin;

      final byAmount = b.value.totalPaise.compareTo(a.value.totalPaise);
      if (byAmount != 0) return byAmount;

      String nameOf(String id) {
        if (id == '*ALL*') return 'All Users';
        if (id == adminId) return 'Admin';
        final m = _allSubadmins.where((u) => u.id == id);
        return (m.isEmpty ? '' : m.first.name).toLowerCase();
      }

      return nameOf(a.key).compareTo(nameOf(b.key));
    });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedEntries();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Summary'),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filters: '),
              Switch.adaptive(
                value: _showFilters,
                onChanged: (val) => setState(() => _showFilters = val),
              ),
            ],
          ),
          FilterChip(
            label: const Text('Chart'),
            selected: _showChart,
            onSelected: (v) => setState(() => _showChart = v),
          ),
          const SizedBox(width: 4),
          FilterChip(
            label: const Text('0 Days'),
            selected: _showZeroDays,
            onSelected: (v) => setState(() => _showZeroDays = v),
          ),
          const SizedBox(width: 4),
          FilterChip(
            label: const Text('Table'),
            selected: _expanded,
            onSelected: (v) => setState(() => _expanded = v),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Scroll to top',
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSummaries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const CommissionSummarySkeleton()
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (_showFilters)
                  SliverToBoxAdapter(child: _buildFilterBar()),
                if (_results.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _buildMetrics()),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  if (_showChart)
                    SliverToBoxAdapter(child: _buildChart(_chartDays())),
                ],
                if (_results.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No data')),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate(
                      sorted.map((e) => _summaryCard(e.key, e.value)).toList(),
                    ),
                  ),
              ],
            ),
    );
  }
}
