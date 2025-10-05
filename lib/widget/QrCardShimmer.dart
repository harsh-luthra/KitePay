import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class QrCardShimmer extends StatelessWidget {
  const QrCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final hi = Colors.grey.shade100;

    Widget line({double w = 140, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
    );

    Widget smallIcon({double s = 24}) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: base, shape: BoxShape.circle),
    );

    Widget statCard({double w = 220, double h = 72}) => Container(
      width: w,
      height: h,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    Widget ledgerChip({double w = 120}) => Container(
      height: 18,
      width: w,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(10)),
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Left QR + Right content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: QR preview box with small dl btn
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: base,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Right: Header + grid + ledger + meta + actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: QR ID line
                        line(w: 260, h: 14),
                        const SizedBox(height: 12),

                        // 2x2 stat grid
                        LayoutBuilder(
                          builder: (ctx, cts) {
                            final isWide = cts.maxWidth > 560;
                            final item = statCard(w: isWide ? (cts.maxWidth - 12) / 2 : cts.maxWidth, h: 70);
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [item, item, item, item],
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Ledger band
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: base.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ledgerChip(w: 120),
                              ledgerChip(w: 120),
                              ledgerChip(w: 160),
                              ledgerChip(w: 140),
                              ledgerChip(w: 140),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Meta row (created at etc.)
                        Row(
                          children: [
                            smallIcon(s: 18),
                            const SizedBox(width: 8),
                            line(w: 160, h: 10),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Actions row: small icons (assign, users, view, delete)
                        Row(
                          children: [
                            smallIcon(), const SizedBox(width: 10),
                            smallIcon(), const SizedBox(width: 10),
                            smallIcon(), const SizedBox(width: 10),
                            smallIcon(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 16),

              // Footer: assigned user name/email
              Row(
                children: [
                  smallIcon(s: 18),
                  const SizedBox(width: 8),
                  Expanded(child: line(w: double.infinity, h: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26.0),
                child: line(w: 200, h: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
