import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'task.g.dart';

enum Recurrence { none, daily, weekly, monthly, yearly }

@collection
class Task {
  Id id = Isar.autoIncrement;

  late String title;
  late DateTime date;

  List<DateTime> completedDates = [];

  @enumerated
  Recurrence recurrence = Recurrence.none;

  int? startTimeInMinutes;
  int? endTimeInMinutes;

  bool isNotified = false;

  Task({
    this.id = Isar.autoIncrement,
    required this.title,
    required this.date,
    this.recurrence = Recurrence.none,
    TimeOfDay? time,
    TimeOfDay? endTime,
    this.isNotified = false,
    this.completedDates = const [],
  }) {
    this.time = time;
    this.endTime = endTime;
  }

  @ignore
  TimeOfDay? get time {
    if (startTimeInMinutes == null) return null;
    return TimeOfDay(
        hour: startTimeInMinutes! ~/ 60, minute: startTimeInMinutes! % 60);
  }

  set time(TimeOfDay? val) {
    if (val == null) {
      startTimeInMinutes = null;
    } else {
      startTimeInMinutes = val.hour * 60 + val.minute;
    }
  }

  @ignore
  TimeOfDay? get endTime {
    if (endTimeInMinutes == null) return null;
    return TimeOfDay(
        hour: endTimeInMinutes! ~/ 60, minute: endTimeInMinutes! % 60);
  }

  set endTime(TimeOfDay? val) {
    if (val == null) {
      endTimeInMinutes = null;
    } else {
      endTimeInMinutes = val.hour * 60 + val.minute;
    }
  }

  bool isCompletedOn(DateTime targetDate) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return completedDates.any((d) =>
        d.year == target.year &&
        d.month == target.month &&
        d.day == target.day);
  }
}

enum RepetitionType { none, monthly, yearly }

@collection
class SpecialDay {
  Id id = Isar.autoIncrement;

  late DateTime date;
  late String title;

  @enumerated
  RepetitionType repetition = RepetitionType.none;

  int? timeInMinutes;
  int? endTimeInMinutes;

  SpecialDay({
    this.id = Isar.autoIncrement,
    required this.date,
    required this.title,
    this.repetition = RepetitionType.none,
    TimeOfDay? time,
    TimeOfDay? endTime,
  }) {
    this.time = time;
    this.endTime = endTime;
  }

  @ignore
  TimeOfDay? get time {
    if (timeInMinutes == null) return null;
    return TimeOfDay(hour: timeInMinutes! ~/ 60, minute: timeInMinutes! % 60);
  }

  set time(TimeOfDay? val) {
    if (val == null) {
      timeInMinutes = null;
    } else {
      timeInMinutes = val.hour * 60 + val.minute;
    }
  }

  @ignore
  TimeOfDay? get endTime {
    if (endTimeInMinutes == null) return null;
    return TimeOfDay(
        hour: endTimeInMinutes! ~/ 60, minute: endTimeInMinutes! % 60);
  }

  set endTime(TimeOfDay? val) {
    if (val == null) {
      endTimeInMinutes = null;
    } else {
      endTimeInMinutes = val.hour * 60 + val.minute;
    }
  }
}
