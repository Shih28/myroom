import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mr_icon_button.dart';

/// Smart Add overlay (placeholder). Phase 2 wires the multi-input
/// classification flow through `AiService`.
class AddOverlay extends StatelessWidget {
  const AddOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
              child: Row(
                children: [
                  MrIconButton(
                    icon: LucideIcons.x,
                    iconSize: 17,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text('新增',
                      style: AppText.display(size: 23, weight: FontWeight.w400)),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('Smart Add（即將推出）'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
