import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ManualTransactionShimmer extends StatelessWidget {
  const ManualTransactionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final hi = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    Widget block({double h = 44, double? w, BorderRadius? r}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: base,
        borderRadius: r ?? BorderRadius.circular(10),
        border: Border.all(color: base.withOpacity(0.7)),
      ),
    );

    Widget header({double w = 120}) => Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(width: 8),
        Container(
          width: w,
          height: 12,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filters card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header(w: 48), // Filters
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, cts) {
                      final isWide = cts.maxWidth > 720;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: _dropdownPlaceholder(block)),
                            const SizedBox(width: 12),
                            Expanded(child: _dropdownPlaceholder(block)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _dropdownPlaceholder(block),
                          const SizedBox(height: 12),
                          _dropdownPlaceholder(block),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Transaction details
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: hi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header(w: 140), // Transaction Details
                  const SizedBox(height: 12),

                  // QR Code ID full width
                  _inputWithIcon(block, iconSize: 18, hintW: 120),

                  const SizedBox(height: 12),

                  // RRN + Amount row
                  LayoutBuilder(
                    builder: (ctx, cts) {
                      final isWide = cts.maxWidth > 720;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: _inputWithIcon(block, iconSize: 18, hintW: 100)),
                            const SizedBox(width: 12),
                            Expanded(child: _inputWithIcon(block, iconSize: 18, hintW: 100)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _inputWithIcon(block, iconSize: 18, hintW: 100),
                          const SizedBox(height: 12),
                          _inputWithIcon(block, iconSize: 18, hintW: 100),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Date & Time full width
                  _inputWithIcon(block, iconSize: 18, hintW: 160),

                  const SizedBox(height: 16),

                  // Submit button placeholder
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 40,
                      width: 180,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownPlaceholder(Widget Function({double h, double? w, BorderRadius? r}) block) {
    return Row(
      children: [
        // prefix icon square
        Container(
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: block(h: 44)),
        const SizedBox(width: 8),
        // trailing arrow square
        Container(
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _inputWithIcon(Widget Function({double h, double? w, BorderRadius? r}) block,
      {double iconSize = 18, double hintW = 120}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: block(h: 44)),
      ],
    );
  }
}
