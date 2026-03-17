import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class WithdrawalAccountCardShimmer extends StatelessWidget {
  const WithdrawalAccountCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    Widget line({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon placeholder
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(w: 140, h: 14),
                        const SizedBox(height: 6),
                        line(w: 100, h: 12),
                        const SizedBox(height: 4),
                        line(w: 160, h: 10),
                      ],
                    ),
                  ),
                  // Menu icon placeholder
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              line(w: 200, h: 12),
            ],
          ),
        ),
      ),
    );
  }
}
