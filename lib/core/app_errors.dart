import 'package:flutter/material.dart';

import 'failures.dart';
import 'firebase_failure.dart';
import 'theme/app_theme.dart';

/// Set on `MaterialApp.router` so the banner can be shown from anywhere,
/// including outside the widget tree (repo error handlers, stream catchError).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The single funnel for every repo `Err` and stream `catchError`.
class AppErrors {
  AppErrors._();

  static void present(Object error) {
    final Failure f = error is Failure ? error : mapFirebase(error);
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearMaterialBanners()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppColors.surface,
          content: Text(
            f.userMessage,
            style: AppText.body(size: 13, color: AppColors.dark),
          ),
          leading: const Icon(Icons.error_outline, color: AppColors.rose, size: 20),
          actions: [
            TextButton(
              onPressed: () => messenger.hideCurrentMaterialBanner(),
              child: Text(
                '關閉',
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ),
          ],
        ),
      );
  }
}
