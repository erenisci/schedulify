import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../task.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Isar? _isar;

  Future<Isar> get db async {
    if (_isar != null) {
      return _isar!;
    }
    _isar = await _initDB();
    return _isar!;
  }

  Future<Isar> _initDB() async {
    if (Isar.instanceNames.isNotEmpty) {
      return Isar.getInstance()!;
    }

    final dir = await getApplicationDocumentsDirectory();

    return await Isar.open(
      [TaskSchema, SpecialDaySchema],
      directory: dir.path,
      inspector: true,
    );
  }

  Future<List<Task>> getAllTasks() async {
    final isar = await db;
    return await isar.tasks.where().sortByDate().findAll();
  }

  Future<void> saveTask(Task task) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
  }

  Future<void> deleteTask(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.tasks.delete(id);
    });
  }

  Future<List<SpecialDay>> getSpecialDays() async {
    final isar = await db;
    return await isar.specialDays.where().findAll();
  }

  Future<void> saveSpecialDay(SpecialDay day) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.specialDays.put(day);
    });
  }

  Future<void> deleteSpecialDay(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.specialDays.delete(id);
    });
  }
}
