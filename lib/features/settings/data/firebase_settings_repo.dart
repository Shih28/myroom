import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app_errors.dart';
import '../../../core/constants.dart';
import '../../../core/firebase_failure.dart';
import '../../../core/result.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repo.dart';

class FirebaseSettingsRepo implements SettingsRepo {
  FirebaseSettingsRepo(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection('users')
      .doc(_uid)
      .collection('settings')
      .doc(kSettingsDocId);

  @override
  Stream<AppSettings> watchSettings() => _doc.snapshots().map(
    (d) => d.exists ? AppSettings.fromFirestore(d) : AppSettings.defaults,
  );

  @override
  Future<Result<void>> updateSettings({
    String? selfIntro,
    String? rules,
    bool? autoEnrich,
    String? tz,
    bool? tutorialSeen,
  }) async {
    final patch = <String, dynamic>{
      'selfIntro': ?selfIntro,
      'rules': ?rules,
      'autoEnrich': ?autoEnrich,
      'tz': ?tz,
      'tutorialSeen': ?tutorialSeen,
    };
    if (patch.isEmpty) return const Ok(null);
    try {
      await _doc.set(patch, SetOptions(merge: true));
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }
}
