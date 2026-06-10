import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// `users/{uid}/events/{id}` — a calendar event.
///
/// Replaces the demo's six integer datetime columns with real [DateTime]s.
/// Events have **no** `updatedAt` field.
class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final Color color;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    required this.color,
    required this.createdAt,
  });

  factory CalendarEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    return CalendarEvent(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      description: d['description'] as String?,
      location: d['location'] as String?,
      startTime: (d['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (d['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAllDay: (d['isAllDay'] as bool?) ?? false,
      color: Color((d['color'] as int?) ?? 0xFF7B9E87),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Client-writable DATA fields only. `createdAt` is injected by the repo.
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'location': location,
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'isAllDay': isAllDay,
    'color': color.toARGB32(),
  };

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    Color? color,
    DateTime? createdAt,
  }) => CalendarEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    location: location ?? this.location,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isAllDay: isAllDay ?? this.isAllDay,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
  );
}
