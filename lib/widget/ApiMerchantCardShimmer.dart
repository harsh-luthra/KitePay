import 'package:flutter/material.dart';

class ApiMerchantCardShimmer extends StatelessWidget {
  const ApiMerchantCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shimmer: Name + Status pill
            Row(
              children: [
                // Name shimmer
                Container(
                  width: 180,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade300,
                        Colors.grey.shade100,
                        Colors.grey.shade300,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                const Spacer(),
                // Status pill shimmer
                Container(
                  width: 80,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade400,
                        Colors.grey.shade200,
                        Colors.grey.shade400,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details shimmer grid (responsive simulation)
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth > 600;
                return twoCols
                    ? Row(
                  children: [
                    Expanded(child: _detailShimmerRow(3)),
                    const SizedBox(width: 16),
                    Expanded(child: _detailShimmerRow(3)),
                  ],
                )
                    : Column(children: [_detailShimmerRow(6)]);
              },
            ),

            const SizedBox(height: 20),

            // Actions shimmer
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade300,
                          Colors.grey.shade100,
                          Colors.grey.shade300,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 100,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade300,
                        Colors.red.shade100,
                        Colors.red.shade300,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailShimmerRow(int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Label shimmer
            Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade200, Colors.grey.shade400],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Value shimmer (varying widths for realism)
            Container(
              width: 120 + (i * 20.0),  // 120-200px random-ish
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade100, Colors.grey.shade300],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
