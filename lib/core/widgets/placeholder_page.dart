import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Empty-state placeholder used for tab content during Phase 0. Replaced by the
/// real feature pages in Phase 1.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          Text(label, style: AppText.body(size: 14, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text('即將推出', style: AppText.caption(size: 11)),
        ],
      ),
    );
  }
}
