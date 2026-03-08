// Unit tests for Schedulify core model logic.
//
// These tests cover the Task model's completion tracking and time accessors,
// which are critical to the weekly planner's correctness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedulify/task.dart';

void main() {
  group('Task.isCompletedOn', () {
    test('returns false when completedDates is empty', () {
      final task = Task(
        title: 'Test Task',
        date: DateTime(2024, 1, 1),
      );
      expect(task.isCompletedOn(DateTime(2024, 1, 1)), isFalse);
    });

    test('returns true when the target date is in completedDates', () {
      final target = DateTime(2024, 3, 15);
      final task = Task(
        title: 'Test Task',
        date: DateTime(2024, 1, 1),
        completedDates: [DateTime(2024, 3, 15, 14, 30)],
      );
      expect(task.isCompletedOn(target), isTrue);
    });

    test('returns false when a different date is in completedDates', () {
      final task = Task(
        title: 'Test Task',
        date: DateTime(2024, 1, 1),
        completedDates: [DateTime(2024, 3, 16)],
      );
      expect(task.isCompletedOn(DateTime(2024, 3, 15)), isFalse);
    });

    test('ignores the time component when matching dates', () {
      final task = Task(
        title: 'Test Task',
        date: DateTime(2024, 1, 1),
        completedDates: [DateTime(2024, 3, 15, 23, 59, 59)],
      );
      expect(task.isCompletedOn(DateTime(2024, 3, 15, 0, 0, 0)), isTrue);
    });
  });

  group('Task time accessors', () {
    test('time getter returns null when startTimeInMinutes is null', () {
      final task = Task(title: 'Test', date: DateTime(2024, 1, 1));
      expect(task.time, isNull);
    });

    test('time setter stores the correct total-minutes value', () {
      final task = Task(title: 'Test', date: DateTime(2024, 1, 1));
      task.time = const TimeOfDay(hour: 9, minute: 30);
      expect(task.startTimeInMinutes, equals(9 * 60 + 30));
    });

    test('time setter clears startTimeInMinutes when set to null', () {
      final task = Task(
        title: 'Test',
        date: DateTime(2024, 1, 1),
        time: const TimeOfDay(hour: 8, minute: 0),
      );
      task.time = null;
      expect(task.startTimeInMinutes, isNull);
    });

    test('endTime getter reconstructs TimeOfDay from stored minutes', () {
      final task = Task(
        title: 'Test',
        date: DateTime(2024, 1, 1),
        endTime: const TimeOfDay(hour: 17, minute: 45),
      );
      expect(task.endTime?.hour, equals(17));
      expect(task.endTime?.minute, equals(45));
    });
  });
}
