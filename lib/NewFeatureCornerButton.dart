import 'package:flutter/material.dart';

class NewFeatureCornerButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final String badgeText;

  const NewFeatureCornerButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.badgeText = 'NEW',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: label,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
