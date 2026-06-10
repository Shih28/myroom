import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/achievements/{id}` — the past / current / future summary for a
/// period. The `*ExportStoragePath` fields are fn-written
/// (`exportAchievement`); the client never writes them.
class Achievement {
  final String id;
  final String pastContent;
  final String currentContent;
  final String futureContent;

  /// fn-written (`exportAchievement`) — read-only on the client.
  final String? pastExportStoragePath;
  final String? currentExportStoragePath;
  final String? futureExportStoragePath;
  final DateTime createdAt;

  Achievement({
    required this.id,
    this.pastContent = '',
    this.currentContent = '',
    this.futureContent = '',
    this.pastExportStoragePath,
    this.currentExportStoragePath,
    this.futureExportStoragePath,
    required this.createdAt,
  });

  factory Achievement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Achievement(
      id: doc.id,
      pastContent: (d['pastContent'] as String?) ?? '',
      currentContent: (d['currentContent'] as String?) ?? '',
      futureContent: (d['futureContent'] as String?) ?? '',
      pastExportStoragePath: d['pastExportStoragePath'] as String?,
      currentExportStoragePath: d['currentExportStoragePath'] as String?,
      futureExportStoragePath: d['futureExportStoragePath'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Client-writable data fields only. No `createdAt` (repo injects it) and no
  /// `*ExportStoragePath` (fn-only).
  Map<String, dynamic> toJson() => {
    'pastContent': pastContent,
    'currentContent': currentContent,
    'futureContent': futureContent,
  };

  Achievement copyWith({
    String? pastContent,
    String? currentContent,
    String? futureContent,
  }) => Achievement(
    id: id,
    pastContent: pastContent ?? this.pastContent,
    currentContent: currentContent ?? this.currentContent,
    futureContent: futureContent ?? this.futureContent,
    pastExportStoragePath: pastExportStoragePath,
    currentExportStoragePath: currentExportStoragePath,
    futureExportStoragePath: futureExportStoragePath,
    createdAt: createdAt,
  );
}
