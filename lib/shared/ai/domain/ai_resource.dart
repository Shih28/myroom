/// A learning resource returned by `fetchRecommendations` (AI_proxy.md §5). The
/// Explore tab renders these and lets the user pin one (→ `PinnedResource`).
class AiResource {
  final String title;
  final String type; // 書籍 | 文章 | 工具 | 課程 | 網站
  final String description;
  final String url;

  const AiResource({
    required this.title,
    required this.type,
    required this.description,
    required this.url,
  });

  factory AiResource.fromJson(Map<String, dynamic> m) => AiResource(
    title: (m['title'] as String?) ?? '',
    type: (m['type'] as String?) ?? '',
    description: (m['description'] as String?) ?? '',
    url: (m['url'] as String?) ?? '',
  );
}
