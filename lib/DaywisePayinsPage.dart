import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'PayinSummaryService.dart';
import 'QRService.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';
import 'utils/app_spacing.dart';
import 'widget/dashboard_widgets.dart';

class DayWisePayinsPage extends StatefulWidget {
  final AppUser userMeta;

  const DayWisePayinsPage({super.key, required this.userMeta});

  @override
  State<DayWisePayinsPage> createState() => _DayWisePayinsPageState();
}

class _DayWisePayinsPageState extends State<DayWisePayinsPage> {
  final QrCodeService _qrCodeService = QrCodeService();
  final ScrollController _scrollController = ScrollController();

  bool get _isAdmin => widget.userMeta.role.toLowerCase() == 'admin';
  bool get _isSubadmin => widget.userMeta.role.toLowerCase() == 'subadmin';
  bool get _isEmployee => widget.userMeta.role.toLowerCase() == 'employee';

  // Filters
  List<AppUser> _users = [];
  List<QrCode> _qrCodes = [];
  String? _selectedUserId;
  String? _selectedQrId;
  bool _loadingUsers = false;
  bool _loadingQr = false;

  // Date range
  DateTime? _fromDate;
  DateTime? _toDate;

  // UI state
  bool _loading = false;
  bool _showFilters = true;
  bool _expanded = false;
  bool _showZeroDays = false;
  bool _showChart = true;

  // Results
  PayinSummaryResult? _result;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (_isAdmin || _isEmployee) {
      await _fetchUsersAndQrCodes();
    } else if (_isSubadmin) {
      await _fetchUsersAndQrCodes();
    } else {
      // Regular user — fetch their own QR codes
      await _fetchUserQrCodes();
    }
    await _fetchSummary();
  }

  Future<void> _fetchUsersAndQrCodes() async {
    setState(() => _loadingUsers = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final fetched = await UsersService.listUsers(jwtToken: jwt);
      _users = fetched.appUsers;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingUsers = false);

    setState(() => _loadingQr = true);
    try {
      final jwt = await AppWriteService().getJWT();
      _qrCodes = await _qrCodeService.getAllQrCodes(jwtToken: jwt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load QR codes: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingQr = false);
  }

  Future<void> _fetchUserQrCodes() async {
    setState(() => _loadingQr = true);
    try {
      final jwt = await AppWriteService().getJWT();
      _qrCodes = await _qrCodeService.getAllUserQrCodes(userId: widget.userMeta.id, jwtToken: jwt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load QR codes: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingQr = false);
  }

  Future<void> _fetchSummary() async {
    setState(() => _loading = true);
    try {
      final jwt = await AppWriteService().getJWT();
      final result = await PayinSummaryService.fetchPayinSummary(
        from: _fromDate,
        to: _toDate,
        userId: _selectedUserId,
        qrId: _selectedQrId,
        jwtToken: jwt,
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch payin summary: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<QrCode> get _filteredQrCodes {
    if (_selectedUserId == null) return _qrCodes;
    return _qrCodes.where((qr) => qr.assignedUserId == _selectedUserId).toList();
  }

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Widget _buildFilterBar() {
    final isAdminOrEmployee = _isAdmin || _isEmployee;
    final canFilterUsers = isAdminOrEmployee || _isSubadmin;

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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // User dropdown (admin/subadmin)
                if (canFilterUsers)
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Filter User', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        _loadingUsers
                            ? const LinearProgressIndicator(minHeight: 2)
                            : DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedUserId,
                          hint: const Text('All Users'),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Users')),
                            ..._users.map(
                                  (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.name} (${u.email})', overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedUserId = value;
                              _selectedQrId = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // QR code dropdown
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('Filter QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      _loadingQr
                          ? const LinearProgressIndicator(minHeight: 2)
                          : DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedQrId,
                        hint: const Text('All QR Codes'),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All QR Codes')),
                          ..._filteredQrCodes.reversed.map(
                                (qr) => DropdownMenuItem(
                              value: qr.qrId,
                              child: Text(qr.qrId, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedQrId = value);
                        },
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
                        // ensure to >= from
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
                    _fetchSummary();
                  },
                ),
                ActionChip(
                  label: const Text('Yesterday'),
                  onPressed: () {
                    final y = DateTime.now().subtract(const Duration(days: 1));
                    setState(() { _fromDate = y; _toDate = y; });
                    _fetchSummary();
                  },
                ),
                ActionChip(
                  label: const Text('Last 7 Days'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() { _fromDate = now.subtract(const Duration(days: 6)); _toDate = now; });
                    _fetchSummary();
                  },
                ),
                ActionChip(
                  label: const Text('Last 30 Days'),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() { _fromDate = now.subtract(const Duration(days: 29)); _toDate = now; });
                    _fetchSummary();
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Fetch'),
                  onPressed: _fetchSummary,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      _selectedUserId = null;
                      _selectedQrId = null;
                      _fromDate = DateTime.now();
                      _toDate = DateTime.now();
                      _expanded = false;
                      _showZeroDays = false;
                    });
                    _fetchSummary();
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
    // Pick a clean round interval that gives ~4-5 gridlines
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

  Widget _buildChart(List<PayinSummaryDay> days) {
    if (days.isEmpty) return const SizedBox.shrink();

    final maxPaise = days.fold<int>(0, (m, d) => math.max(m, d.totalPaise));
    final maxRupees = maxPaise / 100.0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor = theme.colorScheme.primary;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = theme.colorScheme.onSurfaceVariant;

    // Each bar gets a fixed width slot so all dates are visible
    const double barSlotWidth = 44;
    final chartWidth = (days.length * barSlotWidth).toDouble().clamp(150.0, double.infinity);

    final chartHeight = days.length <= 3 ? 200.0 : days.length <= 10 ? 220.0 : 250.0;

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
                'Pay-In Trend (${days.length} days)',
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
                          tooltipRoundedRadius: 8,
                          fitInsideVertically: true,
                          fitInsideHorizontally: true,
                          tooltipMargin: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          getTooltipColor: (_) => isDark ? Colors.grey.shade800 : Colors.white,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final day = days[group.x];
                            return BarTooltipItem(
                              '${day.date}\n${_fmtRupees(day.totalPaise)}',
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
                              if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                              final date = days[idx].date;
                              final parts = date.split('-');
                              final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : date;
                              return SideTitleWidget(
                                meta: meta,
                                angle: days.length > 15 ? -0.5 : 0,
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
                      barGroups: List.generate(days.length, (i) {
                        final rupees = days[i].totalPaise / 100.0;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: rupees,
                              color: barColor,
                              width: days.length > 20 ? 12 : days.length > 10 ? 16 : days.length > 3 ? 20 : 26,
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

  Widget _buildMetrics() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DashboardMetricGrid(items: [
        DashboardMetricCard.money(
          title: 'Grand Total',
          paise: r.grandTotalPaise,
          icon: Icons.account_balance,
          color: Colors.indigo,
          showFull: true,
        ),
        DashboardMetricCard.money(
          title: 'Today',
          paise: r.todayPaise,
          icon: Icons.today,
          color: Colors.green,
          showFull: true,
        ),
        DashboardMetricCard.money(
          title: 'Yesterday',
          paise: r.yesterdayPaise,
          icon: Icons.history,
          color: Colors.orange,
          showFull: true,
        ),
        DashboardMetricCard.count(
          title: 'Days',
          value: r.days.length,
          icon: Icons.date_range,
          color: Colors.blueGrey,
          showFull: true,
        ),
      ]),
    );
  }

  Widget _buildDayCard(PayinSummaryDay day) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: date + total
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        day.date,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _fmtRupees(day.totalPaise),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green, fontSize: 15),
                  ),
                ),
              ],
            ),

            // QR breakdown
            if (day.qrs.isNotEmpty && (_expanded || day.qrs.length <= 3)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: day.qrs.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code, size: 12, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          e.key,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fmtRupees(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ] else if (day.qrs.isNotEmpty && !_expanded) ...[
              const SizedBox(height: 6),
              Text(
                '${day.qrs.length} QR codes',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daywise Pay-Ins'),
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
            label: const Text('QR Details'),
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
            onPressed: _fetchSummary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (_showFilters)
                  SliverToBoxAdapter(child: _buildFilterBar()),
                // Loading indicator
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  ),
                if (_result != null) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _buildMetrics()),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // Chart
                  if (_showChart)
                    SliverToBoxAdapter(
                      child: _buildChart(
                        (_showZeroDays
                            ? _result!.days
                            : _result!.days.where((d) => d.totalPaise > 0).toList()),
                      ),
                    ),
                ],
                if (!_loading && _result == null)
                  const SliverFillRemaining(
                    child: Center(child: Text('No data')),
                  )
                else if (_result != null)
                  () {
                    final days = (_showZeroDays
                        ? _result!.days
                        : _result!.days.where((d) => d.totalPaise > 0).toList())
                        .reversed.toList();
                    if (days.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('No data')),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildDayCard(days[i]),
                        childCount: days.length,
                      ),
                    );
                  }(),
              ],
            ),
    );
  }
}
