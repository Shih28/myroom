import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/ideas/data/pinned_resources/{id}` where the doc id is
/// `sha1(url)` for dedupe (see [FirebaseIdeaRepo.pin]).
class PinnedResource {
  final String id;
  final String title;
  final String type;
  final String description;
  final String url;
  final double sortOrder;
  final DateTime createdAt;

  const PinnedResource({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.url,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory PinnedResource.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return PinnedResource(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      type: (d['type'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      url: (d['url'] as String?) ?? '',
      sortOrder: (d['sortOrder'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// `createdAt` is injected by the repo.
  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'description': description,
    'url': url,
    'sortOrder': sortOrder,
  };
}
