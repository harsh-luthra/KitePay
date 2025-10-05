import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class UsersCardShimmer extends StatelessWidget {
  const UsersCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final hi = Colors.grey.shade100;

    Widget line({double w = 140, double h = 12, BorderRadius? r}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: r ?? BorderRadius.circular(6)),
    );

    Widget chip({double w = 56}) => Container(
      height: 24,
      width: w,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14)),
    );

    Widget iconCircle({double s = 28}) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: base, shape: BoxShape.circle),
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
              // Top row: avatar + name/email + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  // name + email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(w: 120, h: 14),
                        const SizedBox(height: 6),
                        line(w: 180, h: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // status pill (Active/Inactive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12)),
                    child: const SizedBox(width: 56, height: 12),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // meta rows
              Row(children: [iconCircle(s: 16), const SizedBox(width: 8), line(w: 110, h: 10)]),
              const SizedBox(height: 6),
              Row(children: [iconCircle(s: 16), const SizedBox(width: 8), line(w: 80, h: 10)]),
              const SizedBox(height: 6),
              Row(children: [iconCircle(s: 16), const SizedBox(width: 8), line(w: 120, h: 10)]),

              const SizedBox(height: 10),
              // chips row (SelfQr, users)
              Row(children: [chip(w: 64), const SizedBox(width: 8), chip(w: 56)]),

              const SizedBox(height: 12),
              // bottom row: Status: + switch placeholder + trailing action icons
              Row(
                children: [
                  line(w: 48, h: 12),
                  const SizedBox(width: 10),
                  // switch track placeholder
                  Container(
                    width: 46,
                    height: 26,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const Spacer(),
                  // trailing actions (block, edit, %, restore, delete, pass)
                  iconCircle(), const SizedBox(width: 8),
                  iconCircle(), const SizedBox(width: 8),
                  iconCircle(), const SizedBox(width: 8),
                  iconCircle(), const SizedBox(width: 8),
                  iconCircle(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
