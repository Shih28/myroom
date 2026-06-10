/// Result of `classifyMultiInput` (AI_proxy.md §5). The server returns one
/// normalized item per detected thing; the client maps each to a repo write.
/// Category fields are validated **ids** (`catId` / `noteCatId`) that the page
/// resolves to a denormalized snapshot from its category streams.
library;

/// One attachment in a Smart Add submission, sent to `classifyMultiInput` so the
/// model can route it to a `note` item via `attachment_indices`.
class AiAttachmentRef {
  final int i;
  final String type; // image | audio | file
  final String name;

  const AiAttachmentRef({
    required this.i,
    required this.type,
    required this.name,
  });

  Map<String, dynamic> toJson() => {'i': i, 'type': type, 'name': name};
}

sealed class ClassificationItem {
  const ClassificationItem();

  /// Parses one normalized item; returns null for an unknown discriminator.
  static ClassificationItem? fromJson(Map<String, dynamic> m) {
    switch (m['type'] as String?) {
      case 'todo':
        return ClassifiedTodo(
          text: (m['text'] as String?) ?? '',
          catId: (m['catId'] as String?) ?? 'undefined',
        );
      case 'todo_with_time':
        return ClassifiedTodoWithTime(
          text: (m['text'] as String?) ?? '',
          catId: (m['catId'] as String?) ?? 'undefined',
          start: _dt(m['start']),
          end: _dt(m['end']),
        );
      case 'idea':
        return ClassifiedIdea(text: (m['text'] as String?) ?? '');
      case 'note':
        return ClassifiedNote(
          dateKey: (m['dateKey'] as String?) ?? '',
          noteCatId: (m['noteCatId'] as String?) ?? 'undefined',
          content: (m['content'] as String?) ?? '',
          attachmentIndices: ((m['attachmentIndices'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList(),
        );
      case 'recap':
        return ClassifiedRecap(
          title: (m['title'] as String?) ?? '',
          description: (m['description'] as String?) ?? '',
        );
      default:
        return null;
    }
  }
}

/// Builds a **local** DateTime from the server's `{year,month,day,hour,minute}`
/// (the demo treated all event times as local-device wall-clock).
DateTime _dt(Object? raw) {
  final m = (raw as Map?)?.cast<String, dynamic>() ?? const {};
  return DateTime(
    (m['year'] as num?)?.toInt() ?? DateTime.now().year,
    (m['month'] as num?)?.toInt() ?? DateTime.now().month,
    (m['day'] as num?)?.toInt() ?? 1,
    (m['hour'] as num?)?.toInt() ?? 0,
    (m['minute'] as num?)?.toInt() ?? 0,
  );
}

class ClassifiedTodo extends ClassificationItem {
  final String text;
  final String catId;
  const ClassifiedTodo({required this.text, required this.catId});
}

class ClassifiedTodoWithTime extends ClassificationItem {
  final String text;
  final String catId;
  final DateTime start;
  final DateTime end;
  const ClassifiedTodoWithTime({
    required this.text,
    required this.catId,
    required this.start,
    required this.end,
  });
}

class ClassifiedIdea extends ClassificationItem {
  final String text;
  const ClassifiedIdea({required this.text});
}

class ClassifiedNote extends ClassificationItem {
  final String dateKey;
  final String noteCatId;
  final String content;
  final List<int> attachmentIndices;
  const ClassifiedNote({
    required this.dateKey,
    required this.noteCatId,
    required this.content,
    required this.attachmentIndices,
  });
}

class ClassifiedRecap extends ClassificationItem {
  final String title;
  final String description;
  const ClassifiedRecap({required this.title, required this.description});
}
