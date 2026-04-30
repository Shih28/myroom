import 'package:flutter/material.dart';
import 'package:myroom/models/note_item.dart';
import '../models/event.dart';
import '../models/todo_item.dart';
import '../models/idea.dart';
import '../models/recap_item.dart';
import '../theme.dart';

const kDow = ['日', '一', '二', '三', '四', '五', '六'];

const kEraLabel = {Era.past: '過去', Era.now: '現在', Era.future: '未來'};
const kEraColor = {
  Era.past: AppColors.amber,
  Era.now: AppColors.sage,
  Era.future: AppColors.blue,
};

const kCatColors = {
  '工作': AppColors.blue,
  '學習': AppColors.sage,
  '個人': AppColors.rose,
  '健康': AppColors.amber,
};

class ResourceItem {
  final String title;
  final String type;
  final Color color;
  final String desc;
  const ResourceItem({required this.title, required this.type, required this.color, required this.desc});
}

const kResources = [
  ResourceItem(title: '設計師的第一原則思考', type: '文章', color: AppColors.blue, desc: '從基礎重新思考設計決策，而非依賴慣例與模仿。'),
  ResourceItem(title: '原子習慣', type: '書籍', color: AppColors.sage, desc: '微小改變如何帶來巨大成果，建立可持續的行為系統。'),
  ResourceItem(title: 'Notion 個人知識管理', type: '案例', color: AppColors.amber, desc: '一位設計師如何用 Notion 管理靈感、專案與學習筆記。'),
  ResourceItem(title: '當我們談論創意時', type: '書籍', color: AppColors.rose, desc: '探索創意的本質與培養方式，適合想突破框架的人。'),
];

class SeedData {
  static List<CalendarEvent> get initEvents => [
    const CalendarEvent(id: 1, title: '週組會議', startYear: 2026, startMonth: 4, startDay: 24, startHour: 9, startMin: 0, endYear: 2026, endMonth: 4, endDay: 24, endHour: 10, endMin: 0, color: AppColors.sage),
    const CalendarEvent(id: 2, title: '英文課', startYear: 2026, startMonth: 4, startDay: 24, startHour: 14, startMin: 0, endYear: 2026, endMonth: 4, endDay: 24, endHour: 15, endMin: 30, color: AppColors.amber),
    const CalendarEvent(id: 3, title: '讀書計畫', startYear: 2026, startMonth: 4, startDay: 25, startHour: 20, startMin: 0, endYear: 2026, endMonth: 4, endDay: 25, endHour: 21, endMin: 0, color: AppColors.blue),
    const CalendarEvent(id: 4, title: '健身房', startYear: 2026, startMonth: 4, startDay: 26, startHour: 7, startMin: 30, endYear: 2026, endMonth: 4, endDay: 26, endHour: 8, endMin: 30, color: AppColors.rose),
    const CalendarEvent(id: 5, title: '專案截止', startYear: 2026, startMonth: 4, startDay: 28, startHour: 18, startMin: 0, endYear: 2026, endMonth: 4, endDay: 28, endHour: 18, endMin: 30, color: AppColors.amber),
    const CalendarEvent(id: 6, title: '團隊活動', startYear: 2026, startMonth: 4, startDay: 22, startHour: 0, startMin: 0, endYear: 2026, endMonth: 4, endDay: 24, endHour: 23, endMin: 59, color: AppColors.blue, allDay: true),
  ];

  static List<TodoCategory> get initCategories => [
    const TodoCategory(id: 1, name: '工作', color: AppColors.blue),
    const TodoCategory(id: 2, name: '學習', color: AppColors.sage),
    const TodoCategory(id: 3, name: '個人', color: AppColors.rose),
    const TodoCategory(id: 4, name: '健康', color: AppColors.amber)
  ];

  static List<TodoItem> get initTodos => [
    const TodoItem(id: 1, text: '整理研究筆記', done: false, cat: '學習', color: AppColors.sage, priority: 2),
    const TodoItem(id: 2, text: '回覆 Lucas 的信件', done: true, cat: '工作', color: AppColors.blue, priority: 1),
    const TodoItem(id: 3, text: '買燕麥和堅果', done: false, cat: '個人', color: AppColors.rose, priority: 4),
    const TodoItem(id: 4, text: '完成原型設計稿', done: false, cat: '工作', color: AppColors.blue, priority: 1),
    const TodoItem(id: 5, text: '預約牙醫', done: true, cat: '健康', color: AppColors.amber, priority: 3),
    const TodoItem(id: 6, text: '讀《原子習慣》第三章', done: false, cat: '學習', color: AppColors.sage, priority: 3),
  ];

  static List<Idea> get initIdeas => [
    const Idea(id: 1, text: '用 AI 自動整理待辦事項優先順序'),
    const Idea(id: 2, text: '為每週習慣設計視覺化熱力圖'),
    const Idea(id: 3, text: '靜心日記與情緒追蹤整合'),
  ];

  static List<NoteCategory> get initNoteCategories => [
    const NoteCategory(id: 'undefined', label: '未分類', iconName: 'tag', color: Color(0xFFBFA97A), bg: Color(0xFFFFF8ED), sortOrder: 0),
    const NoteCategory(id: 'academic', label: '學業', iconName: 'pencil', color: Color(0xFFBF7A8E), bg: Color(0xFFF5EEF0), sortOrder: 1),
    const NoteCategory(id: 'sport', label: '運動', iconName: 'trophy', color: Color(0xFF7A8EBF) , bg: Color(0xFFEEF0F5), sortOrder: 2),
  ];

  static List<NoteItem> get initNotes => [
    NoteItem(id: 0, dateKey: '2026-04-20', content: '整理了 Figma 設計系統的規範，顏色與字型層級...', catId: 'academic', updatedAt: -1),
    NoteItem(id: 1, dateKey: '2026-04-12', content: '讀了關於認知負荷理論的章節，對 UI 設計很有啟發...', catId: 'academic', updatedAt: -1),
    NoteItem(id: 2, dateKey: '2026-04-10', content: '今天游了800公尺，比上次進步，換氣節奏更穩了...', catId: 'sport', updatedAt: -1),
    NoteItem(id: 3, dateKey: '2026-04-22', content: '今天完成了設計原型的第一版，花了比預期更多的時間在細節上。顏色系統和字型搭配反覆調整，最終找到了一個感覺「對」的組合。\n\n下一步要開始考慮互動動畫，讓整體體驗更流暢。', catId: 'academic', updatedAt: -1),
  ];

  static List<RecapItem> get timelineData => [
    const RecapItem(
      id: 'p1', era: Era.past,
      title: '學習 React Native',
      completedDate: '2025年11月',
      desc: '從零開始學習行動端開發，完成了第一個個人 App 雛形。雖然最終沒有上架，但對跨平台開發有了深刻理解。',
    ),
    const RecapItem(
      id: 'p2', era: Era.past,
      title: '21天閱讀挑戰',
      completedDate: '2026年1月',
      desc: '連續21天每天閱讀至少30分鐘，建立了穩定的閱讀習慣，共完成4本書。',
    ),
    const RecapItem(
      id: 'p3', era: Era.past,
      title: '個人網站重建',
      completedDate: '2026年2月',
      desc: '用 Next.js 重新設計個人作品集網站，從設計到上線獨立完成，收到不少正面回饋。',
      noteLink: 'diary',
    ),
    const RecapItem(
      id: 'p4', era: Era.past,
      title: '累積跑步 100km',
      completedDate: '2026年3月',
      desc: '花了三個月時間，逐步提升跑步距離，最終達成100公里的累積目標。',
    ),
    const RecapItem(
      id: 'n1', era: Era.now,
      title: 'MyRoom 原型設計',
      targetDate: '目標 2026年5月',
      desc: '設計一個整合行事曆、待辦、靈感、筆記與回顧的個人生產力工具，正在進行 Flutter 實作。',
      noteLink: 'note',
    ),
    const RecapItem(
      id: 'n2', era: Era.now,
      title: '每週閱讀3小時',
      targetDate: '持續進行中',
      desc: '維持每週固定閱讀時間，目前已連續8週達成目標，閱讀範疇涵蓋設計、心理學與科技。',
      noteLink: 'diary',
    ),
    const RecapItem(
      id: 'f1', era: Era.future,
      title: '打造自己的產品',
      targetDate: '2027年',
      desc: '希望能將 MyRoom 或其他想法發展成真正的產品，從設計到開發到營運，獨立完成一次完整的創業嘗試。',
    ),
    const RecapItem(
      id: 'f2', era: Era.future,
      title: '在海外生活一年',
      targetDate: '2028年',
      desc: '計畫在歐洲或日本生活至少一年，體驗不同的文化與工作方式，拓展視野與人生經驗。',
    ),
    const RecapItem(
      id: 'f3', era: Era.future,
      title: '成為 T型人才',
      targetDate: '長期目標',
      desc: '在設計領域深耕的同時，具備工程、商業分析等跨域能力，成為能夠獨立解決複雜問題的全端設計師。',
    ),
  ];
}

Map<String, int>? parseEventRange(String s) {
  final re = RegExp(
      r'(\d{1,2})\/(\d{1,2})\s+(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2})\/(\d{1,2})\s+(\d{1,2}):(\d{2})');
  final m = re.firstMatch(s);
  if (m == null) return null;
  return {
    'startMonth': int.parse(m.group(1)!),
    'startDay': int.parse(m.group(2)!),
    'startHour': int.parse(m.group(3)!),
    'startMin': int.parse(m.group(4)!),
    'endMonth': int.parse(m.group(5)!),
    'endDay': int.parse(m.group(6)!),
    'endHour': int.parse(m.group(7)!),
    'endMin': int.parse(m.group(8)!),
  };
}

String fmt2(int n) => n.toString().padLeft(2, '0');
String fmtHm(int h, int m) => '${fmt2(h)}:${fmt2(m)}';

/// Returns today as a YYYY-MM-DD string.
String todayKey() {
  final n = DateTime.now();
  return '${n.year}-${fmt2(n.month)}-${fmt2(n.day)}';
}
