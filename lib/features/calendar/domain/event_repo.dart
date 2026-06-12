import 'package:flutter/material.dart';

import '../../../core/result.dart';
import 'event.dart';

abstract class EventRepo {
  /// Streams events ordered by `startTime` ascending. When [window] is given,
  /// only events whose `startTime` falls within it are streamed.
  Stream<List<CalendarEvent>> watchEvents({DateTimeRange? window});

  Future<Result<void>> add(CalendarEvent event);

  Future<Result<void>> update(CalendarEvent event);

  Future<Result<void>> delete(String id);
}
