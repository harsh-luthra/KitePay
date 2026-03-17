import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_spacing.dart';

// ===== Number formatting helpers =====

String formatCount(num value, {required bool showFull}) {
  if (showFull) {
    return NumberFormat.decimalPattern('en_IN').format(value);
  }
  return NumberFormat.compact(locale: 'en_IN').format(value);
}

String formatMoneyPaise(int paise, {required bool showFull}) {
  final rupees = paise / 100.0;
  if (showFull) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }
  return NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(rupees);
}

// ===== Metric Grid =====

class DashboardMetricGrid extends StatelessWidget {
  final List<Widget> items;
  const DashboardMetricGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cts) {
      final w = cts.maxWidth;
      final cross = w > 1400 ? 5 : w > 1100 ? 4 : w > 800 ? 3 : w > 520 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cross,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.4,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: items,
      );
    });
  }
}

// ===== Metric Card =====

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final Widget leading;
  final String value;
  final Color color;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.leading,
    required this.value,
    required this.color,
  });

  /// Count metric (e.g. "Total Transactions", 42)
  factory DashboardMetricCard.count({
    Key? key,
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required bool showFull,
  }) {
    return DashboardMetricCard(
      key: key,
      title: title,
      leading: Icon(icon, color: color),
      value: formatCount(value, showFull: showFull),
      color: color,
    );
  }

  /// Money metric (paise → ₹)
  factory DashboardMetricCard.money({
    Key? key,
    required String title,
    required int paise,
    required IconData icon,
    required Color color,
    required bool showFull,
  }) {
    return DashboardMetricCard(
      key: key,
      title: title,
      leading: Icon(icon, color: color),
      value: formatMoneyPaise(paise, showFull: showFull),
      color: color,
    );
  }

  /// Count + amount combo (e.g. "Chargebacks", 5 • ₹1,200)
  factory DashboardMetricCard.moneyPair({
    Key? key,
    required String title,
    required int count,
    required int paise,
    required IconData icon,
    required Color color,
    required bool showFull,
  }) {
    final cnt = formatCount(count, showFull: showFull);
    final amt = formatMoneyPaise(paise, showFull: showFull);
    return DashboardMetricCard(
      key: key,
      title: title,
      leading: Icon(icon, color: color),
      value: '$cnt • $amt',
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: title,
      child: Container(
        padding: AppSpacing.allSm,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: IconThemeData(size: 18, color: color),
                child: leading,
              ),
            ),
            AppSpacing.gapHSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Section Card =====

class DashboardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accentColor;

  const DashboardSection({
    super.key,
    required this.title,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Colors.blueGrey;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.allMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.dashboard_customize, size: 16, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: accentColor == null ? null : color,
                ),
              ),
            ]),
            AppSpacing.gapSm,
            ...children,
          ],
        ),
      ),
    );
  }
}

// ===== Section Group Header (colored divider label) =====

class DashboardSectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const DashboardSectionHeader({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppSpacing.gapHSm,
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          AppSpacing.gapHSm,
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.25), thickness: 1),
          ),
        ],
      ),
    );
  }
}

// ===== Shimmer helpers =====

Color _shimmerBase(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300;

Color _shimmerHighlight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade100;

// ===== Dashboard Skeleton =====

class DashboardSkeleton extends StatelessWidget {
  final int sectionCount;
  const DashboardSkeleton({super.key, this.sectionCount = 4});

  @override
  Widget build(BuildContext context) {
    final base = _shimmerBase(context);
    final hi = _shimmerHighlight(context);

    Widget metricBox() => Container(
      height: 68,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: hi, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 60, height: 10, decoration: BoxDecoration(color: hi, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 80, height: 14, decoration: BoxDecoration(color: hi, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );

    Widget sectionTitle() => Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Container(width: 100, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
      ],
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: ListView(
        padding: AppSpacing.allLg,
        children: List.generate(
          sectionCount,
          (_) => Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle(),
                  AppSpacing.gapSm,
                  GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 3.4,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    children: List.generate(4, (_) => metricBox()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Wallet Page Skeleton =====

class WalletPageSkeleton extends StatelessWidget {
  const WalletPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = _shimmerBase(context);
    final hi = _shimmerHighlight(context);

    Widget line({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Balance card area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  line(w: 100, h: 14),
                  const SizedBox(height: 12),
                  line(w: 160, h: 32),
                  const SizedBox(height: 8),
                  line(w: 140, h: 12),
                  const SizedBox(height: 24),
                  Container(
                    width: 200,
                    height: 40,
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20)),
                  ),
                ],
              ),
            ),
            // Transactions list area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      line(w: 160, h: 18),
                      line(w: 60, h: 14),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(5, (_) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                line(w: 80, h: 14),
                                const SizedBox(height: 6),
                                line(w: 120, h: 10),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              line(w: 60, h: 14),
                              const SizedBox(height: 6),
                              line(w: 50, h: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Commission Summary Skeleton =====

class CommissionSummarySkeleton extends StatelessWidget {
  const CommissionSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = _shimmerBase(context);
    final hi = _shimmerHighlight(context);

    Widget line({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
    );

    Widget chip({double w = 100}) => Container(
      height: 30,
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: ListView(
        children: List.generate(3, (_) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          line(w: 120, h: 14),
                          const SizedBox(height: 4),
                          line(w: 160, h: 10),
                        ],
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 28,
                      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(10)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    chip(w: 110),
                    chip(w: 95),
                    chip(w: 120),
                    chip(w: 105),
                    chip(w: 90),
                  ],
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }
}
