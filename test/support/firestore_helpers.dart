import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Writes [data] to a throwaway doc and reads it back as a real
/// [DocumentSnapshot], so model `fromFirestore` factories can be exercised
/// against genuine Firestore semantics (Timestamps, nested maps, missing keys).
Future<DocumentSnapshot<Map<String, dynamic>>> snapshotOf(
  Map<String, dynamic> data, {
  String? id,
}) async {
  final fs = FakeFirebaseFirestore();
  final col = fs.collection('t');
  final ref = id == null ? col.doc() : col.doc(id);
  await ref.set(data);
  return ref.get();
}

/// A fixed [Timestamp] for deterministic round-trip assertions.
final ts2026 = Timestamp.fromDate(DateTime.utc(2026, 6, 9, 12, 30));
