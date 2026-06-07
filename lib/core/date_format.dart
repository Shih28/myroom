/// Shared date helpers (centralized — the demo duplicated these across
/// `seed_data.dart` and `openai_service.dart`).
const List<String> kDow = ['日', '一', '二', '三', '四', '五', '六'];

String fmt2(int n) => n.toString().padLeft(2, '0');

/// `YYYY-MM-DD` for a [DateTime] (local).
String dateKeyOf(DateTime d) => '${d.year}-${fmt2(d.month)}-${fmt2(d.day)}';

/// Today's local date as `YYYY-MM-DD`.
String todayKey() => dateKeyOf(DateTime.now());
