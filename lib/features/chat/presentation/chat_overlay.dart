import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mr_icon_button.dart';

/// AI Chat overlay (placeholder). Phase 1 binds `ChatRepo.watchMessages`;
/// Phase 2 wires the server-side chat function through `AiService`.
class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key});

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
                  Text('AI 助理',
                      style: AppText.display(size: 23, weight: FontWeight.w400)),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('AI Chat（即將推出）'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
