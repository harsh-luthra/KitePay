import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TransactionCardShimmer extends StatelessWidget {
  const TransactionCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (index) => _shimmerRow()),
          ),
        ),
      ),
    );
  }

  Widget _shimmerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Icon placeholder (matches Icon size 18 in real card with some padding)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          // Label placeholder ("Amount:", etc.)
          Container(
            width: 80,
            height: 12,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 6),
          // Value placeholder (full width)
          Expanded(
            child: Container(
              height: 12,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
