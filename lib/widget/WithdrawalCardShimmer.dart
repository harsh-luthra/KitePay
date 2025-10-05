import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class WithdrawalCardShimmer extends StatelessWidget {
  const WithdrawalCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    Widget pill({double w = 84, double h = 24}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
    );

    Widget line({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
    );

    Widget metric() => Container(
      height: 58,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(color: hi, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                line(w: 72, h: 10),
                const SizedBox(height: 6),
                line(w: 54, h: 12),
              ],
            ),
          ),
        ],
      ),
    );

    Widget detailRow(double w1, double w2) => Row(
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        line(w: w1, h: 12),
        const SizedBox(width: 12),
        line(w: w2, h: 12),
      ],
    );

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: method + status
              Row(
                children: [
                  pill(w: 56, h: 22), // UPI/BANK
                  const Spacer(),
                  pill(w: 92, h: 22), // PENDING/APPROVED/REJECTED
                ],
              ),
              const SizedBox(height: 10),

              // Metric strip: Credit | Commission | Debit
              LayoutBuilder(builder: (ctx, cts) {
                final isWide = cts.maxWidth > 620;
                final child = Row(
                  children: [
                    Expanded(child: metric()),
                    const SizedBox(width: 10),
                    Expanded(child: metric()),
                    const SizedBox(width: 10),
                    Expanded(child: metric()),
                  ],
                );
                if (isWide) return child;
                return Column(
                  children: [
                    metric(),
                    const SizedBox(height: 8),
                    metric(),
                    const SizedBox(height: 8),
                    metric(),
                  ],
                );
              }),

              const SizedBox(height: 12),

              // Details two-column
              LayoutBuilder(
                builder: (ctx, cts) {
                  final twoCols = cts.maxWidth > 640;
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(w: 120, h: 12), // Name:
                      const SizedBox(height: 8),
                      detailRow(60, 120),  // QR Id : value
                      const SizedBox(height: 8),
                      detailRow(40, 140),  // VPA/AccNo: value
                      const SizedBox(height: 8),
                      detailRow(40, 160),  // UTR/IFSC/Reason: value
                    ],
                  );

                  final right = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(w: 140, h: 12), // Requested By:
                      const SizedBox(height: 8),
                      detailRow(40, 160),  // Email/Bank
                      const SizedBox(height: 8),
                      detailRow(40, 160),  // VPA/Bank name
                      const SizedBox(height: 8),
                      detailRow(60, 140),  // Reason/UTR
                    ],
                  );

                  if (!twoCols) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: 8),
                        right,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 24),
                      Expanded(child: right),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),

              // Created row
              Row(
                children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 8),
                  line(w: 200, h: 10),
                ],
              ),

              const SizedBox(height: 12),
              // Actions row
              Row(
                children: [
                  // Approve
                  Container(
                    height: 36,
                    width: 110,
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(width: 10),
                  // Reject
                  Container(
                    height: 36,
                    width: 110,
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
                  ),
                  const Spacer(),
                  // trailing small copy icons placeholders
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Container(width: 24, height: 24, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
