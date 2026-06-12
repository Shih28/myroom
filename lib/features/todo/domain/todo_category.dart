import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// `users/{uid}/todo_categories/{id}` — a todo's own category.
///
/// Unlike note categories, todo categories carry **no `iconName`**.
class TodoCategory {
  final String id;
  final String label;
  final Color color;
  final int sortOrder;

  const TodoCategory({
    required this.id,
    required this.label,
    required this.color,
    this.sortOrder = 0,
  });

  TodoCategory copyWith({
    String? id,
    String? label,
    Color? color,
    int? sortOrder,
  }) =>
      TodoCategory(
        id: id ?? this.id,
        label: label ?? this.label,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  factory TodoCategory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return TodoCategory(
      id: doc.id,
      label: (d['label'] as String?) ?? '',
      color: Color((d['colorVal'] as int?) ?? 0xFF9A8A7E),
      sortOrder: (d['sortOrder'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'colorVal': color.toARGB32(),
        'sortOrder': sortOrder,
      };
}
