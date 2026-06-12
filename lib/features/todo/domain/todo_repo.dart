import '../../../core/result.dart';
import 'todo.dart';
import 'todo_category.dart';

abstract class TodoRepo {
  // ── Todos ────────────────────────────────────────────────────────────────
  /// Streams all todos ordered by `sortOrder`.
  Stream<List<Todo>> watchTodos();

  /// Creates a todo; resolves to the new document id.
  Future<Result<String>> add(Todo todo);

  Future<Result<void>> update(Todo todo);

  Future<Result<void>> delete(String id);

  /// Persists a new ordering by writing `sortOrder = index` for each id in one
  /// batch.
  Future<Result<void>> reorder(List<String> orderedIds);

  // ── Todo categories ────────────────────────────────────────────────────────
  Stream<List<TodoCategory>> watchTodoCategories();

  Future<Result<void>> addTodoCategory(TodoCategory category);

  Future<Result<void>> updateTodoCategory(TodoCategory category);

  /// Deletes ONLY the category doc. The `categoryFanout` Cloud Function (Phase 3)
  /// reassigns affected todos to the `無分類` sentinel.
  Future<Result<void>> deleteTodoCategory(String id);
}
