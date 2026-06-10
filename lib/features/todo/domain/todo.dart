import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// Denormalized snapshot of a [TodoCategory] embedded into each todo.
/// (Kept fresh by the Phase 3 `categoryFanout` Cloud Function.)
class TodoCategoryRef {
  final String id;
  final String label;
  final Color color;

  const TodoCategoryRef({
    required this.id,
    required this.label,
    required this.color,
  });

  /// The default "無分類" sentinel reference embedded into new todos when the
  /// user does not pick a category.
  static const TodoCategoryRef undefined = TodoCategoryRef(
    id: kUndefinedCategoryId,
    label: '無分類',
    color: Color(0xFF9A8A7E),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'colorVal': color.toARGB32(),
  };

  factory TodoCategoryRef.fromMap(Map<String, dynamic>? m) {
    if (m == null) return undefined;
    return TodoCategoryRef(
      id: (m['id'] as String?) ?? kUndefinedCategoryId,
      label: (m['label'] as String?) ?? '無分類',
      color: Color((m['colorVal'] as int?) ?? 0xFF9A8A7E),
    );
  }
}

/// `users/{uid}/todos/{id}`.
class Todo {
  final String id;
  final String title;
  final bool isCompleted;
  final int sortOrder;
  final TodoCategoryRef category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
    this.category = TodoCategoryRef.undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Todo copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? sortOrder,
    TodoCategoryRef? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
    sortOrder: sortOrder ?? this.sortOrder,
    category: category ?? this.category,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Todo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Todo(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      isCompleted: (d['isCompleted'] as bool?) ?? false,
      sortOrder: (d['sortOrder'] as int?) ?? 0,
      category: TodoCategoryRef.fromMap(d['category'] as Map<String, dynamic>?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Client-writable DATA fields only. createdAt/updatedAt are injected by the
  /// repo.
  Map<String, dynamic> toJson() => {
    'title': title,
    'isCompleted': isCompleted,
    'sortOrder': sortOrder,
    'category': category.toMap(),
  };
}
