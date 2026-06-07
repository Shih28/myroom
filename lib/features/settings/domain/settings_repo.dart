import '../../../core/result.dart';
import 'app_settings.dart';

abstract class SettingsRepo {
  /// Streams `users/{uid}/settings/app`; emits [AppSettings.defaults] until the
  /// doc exists (e.g. while `provisionUser` is still running).
  Stream<AppSettings> watchSettings();

  /// Partial patch — only the provided fields are written (merge).
  Future<Result<void>> updateSettings({
    String? selfIntro,
    String? rules,
    bool? autoEnrich,
    String? tz,
    bool? tutorialSeen,
  });
}
