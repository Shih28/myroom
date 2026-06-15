import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/tutorial_overlay.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/domain/settings_repo.dart';

/// The StatefulShellRoute builder — the outer chrome around the swipe surface.
/// The page strip (tabs + Add overlay), top bar, page title and bottom nav all
/// live in `SwipeShell` (the route's `navigatorContainerBuilder`), rendered via
/// [navigationShell]. This wrapper only owns the one-time tz patch and the
/// first-run tutorial gate.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _tzChecked = false;
  bool _tutorialDismissed = false;

  /// Patch `settings/app.tz` to the device timezone once, after the first real
  /// settings snapshot arrives (Auth.md §3).
  Future<void> _maybePatchTimezone(AppSettings settings) async {
    if (_tzChecked) return;
    _tzChecked = true;
    try {
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      if (deviceTz.isNotEmpty && deviceTz != settings.tz && mounted) {
        await context.read<SettingsRepo>().updateSettings(tz: deviceTz);
      }
    } catch (_) {
      // Device tz unavailable (e.g. unsupported platform) — keep the default.
    }
  }

  void _dismissTutorial() {
    setState(() => _tutorialDismissed = true);
    context.read<SettingsRepo>().updateSettings(tutorialSeen: true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings?>();

    if (settings != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybePatchTimezone(settings);
      });
    }

    final showTutorial =
        settings != null && !settings.tutorialSeen && !_tutorialDismissed;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // The tutorial scrim is only semi-transparent and doesn't absorb
            // pointers, so block interaction with the shell (incl. the bottom
            // nav) underneath while it shows.
            IgnorePointer(
              ignoring: showTutorial,
              child: widget.navigationShell,
            ),
            if (showTutorial) TutorialOverlay(onDone: _dismissTutorial),
          ],
        ),
      ),
    );
  }
}
