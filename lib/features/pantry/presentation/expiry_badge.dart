import 'package:flutter/material.dart';

import '../domain/expiry.dart';

class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.expiry, this.size = 44});

  final Expiry expiry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = expiry.color(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(
        expiry.badge,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.33),
      ),
    );
  }
}
