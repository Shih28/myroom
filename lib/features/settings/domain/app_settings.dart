import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants.dart';

/// `users/{uid}/settings/app` — the per-user preferences singleton.
class AppSettings {
  final String selfIntro;
  final String rules;
  final bool autoEnrich;
  final String tz;
  final bool tutorialSeen;

  const AppSettings({
    this.selfIntro = '',
    this.rules = '',
    this.autoEnrich = true,
    this.tz = kDefaultTimezone,
    this.tutorialSeen = false,
  });

  static const AppSettings defaults = AppSettings();

  factory AppSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null) return defaults;
    return AppSettings(
      selfIntro: (d['selfIntro'] as String?) ?? '',
      rules: (d['rules'] as String?) ?? '',
      autoEnrich: (d['autoEnrich'] as bool?) ?? true,
      tz: (d['tz'] as String?) ?? kDefaultTimezone,
      tutorialSeen: (d['tutorialSeen'] as bool?) ?? false,
    );
  }
}
