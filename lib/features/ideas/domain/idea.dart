import 'package:cloud_firestore/cloud_firestore.dart';

/// A link surfaced by the Phase 2 `enrichIdea` trigger alongside [Idea.aiSummary].
class IdeaLink {
  final String title;
  final String url;

  const IdeaLink({required this.title, required this.url});

  factory IdeaLink.fromMap(Map<String, dynamic> m) => IdeaLink(
        title: (m['title'] as String?) ?? '',
        url: (m['url'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {'title': title, 'url': url};
}

/// `users/{uid}/ideas/data/user_ideas/{id}`.
///
/// The client only ever writes [text]; [aiSummary], [aiStatus] and [links] are
/// populated exclusively by the Phase 2 `enrichIdea` trigger (security rules
/// forbid the client from writing them), so [toJson] returns only `{text}`.
class Idea {
  final String id;
  final String text;
  final String? aiSummary;
  final String aiStatus;
  final List<IdeaLink> links;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Idea({
    required this.id,
    required this.text,
    this.aiSummary,
    this.aiStatus = 'none',
    this.links = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Idea.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Idea(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      aiSummary: d['aiSummary'] as String?,
      aiStatus: (d['aiStatus'] as String?) ?? 'none',
      links: ((d['links'] as List?) ?? const [])
          .map((e) => IdeaLink.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Only the client-writable data field. `aiSummary` / `aiStatus` / `links`
  /// are fn-only; `createdAt` / `updatedAt` are injected by the repo.
  Map<String, dynamic> toJson() => {'text': text};
}
