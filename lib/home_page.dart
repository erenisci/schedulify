import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/time_ticker.dart';
import 'task.dart';
import 'widgets/task_card.dart';

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class MouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class RepeatPicker extends StatelessWidget {
  final String value;
  final Function(String) onChanged;

  const RepeatPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final List<String> repeatOptions = const [
    "No Repeat",
    "Monthly",
    "Yearly",
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton2<String>(
      value: value,
      items: repeatOptions
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v!),
      buttonStyleData: const ButtonStyleData(
        height: 36,
        width: 150,
      ),
      dropdownStyleData: const DropdownStyleData(
        maxHeight: 200,
        width: 150,
        padding: EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WindowListener, TrayListener {
  late TabController _tabController;

  final DatabaseService _databaseService = DatabaseService();
  final SettingsService _settingsService = SettingsService();

  final DateTime _anchorDate = DateTime.now();
  List<Task> tasks = [];
  List<SpecialDay> specialDays = [];

  Timer? _notificationTimer;

  bool _minimizeToTray = true;
  bool _startOnBoot = false;
  bool _playCompletionSound = true;
  bool _enableNotifications = true;
  bool _playNotificationSound = true;
  bool _isExplicitExit = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  Task? _currentActiveTask;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('en_US', null);

    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: 0,
    );

    windowManager.addListener(this);
    trayManager.addListener(this);
    windowManager.setPreventClose(true);

    _initSystemTray();
    _initAudio();

    _loadStartupState();
    _loadSettings();
    _loadData();
    _loadAppVersion();
    _startNotificationChecker();
  }

  Future<void> _loadSettings() async {
    bool valMinimize =
        await _settingsService.getBool(SettingsService.keyMinimizeToTray);
    bool valCompSound =
        await _settingsService.getBool(SettingsService.keyPlayCompletionSound);
    bool valNotif =
        await _settingsService.getBool(SettingsService.keyEnableNotifications);
    bool valNotifSound = await _settingsService
        .getBool(SettingsService.keyPlayNotificationSound);

    if (mounted) {
      setState(() {
        _minimizeToTray = valMinimize;
        _playCompletionSound = valCompSound;
        _enableNotifications = valNotif;
        _playNotificationSound = valNotifSound;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = info.version);
    }
  }

  Future<void> _loadData() async {
    final loadedTasks = await _databaseService.getAllTasks();
    final loadedDays = await _databaseService.getSpecialDays();
    if (mounted) {
      setState(() {
        tasks = loadedTasks;
        specialDays = loadedDays;
      });

      _checkForActiveTask();
    }
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint("Audio Init Error: $e");
    }
  }

  Future<void> _initSystemTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );
    await trayManager.setToolTip('Schedulify');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show Schedulify'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Exit'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
    windowManager.restore();
  }

  @override
  void onTrayIconRightMouseDown() async {
    try {
      await trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('Tray error: $e');
    }
  }

  @override
  void onTrayIconRightMouseUp() async {
    try {
      await trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('Tray error: $e');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
      windowManager.restore();
    } else if (menuItem.key == 'exit_app') {
      _isExplicitExit = true;
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    if (_isExplicitExit) {
      await windowManager.destroy();
    } else if (_minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  Future<void> _loadStartupState() async {
    bool isEnabled = await LaunchAtStartup.instance.isEnabled();
    setState(() {
      _startOnBoot = isEnabled;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _notificationTimer?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startNotificationChecker() {
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        _checkScheduledTasks();
        _checkForActiveTask();
      },
    );
  }

  void _checkForActiveTask() {
    DateTime now = DateTime.now();
    List<Task> todaysTasks = _getTasksForDay(0);

    Task? activeTask;

    for (var task in todaysTasks) {
      if (task.time != null &&
          task.endTime != null &&
          !task.isCompletedOn(now)) {
        DateTime startDT = DateTime(
            now.year, now.month, now.day, task.time!.hour, task.time!.minute);
        DateTime endDT = DateTime(now.year, now.month, now.day,
            task.endTime!.hour, task.endTime!.minute);

        if (endDT.isBefore(startDT)) {
          endDT = endDT.add(const Duration(days: 1));
        }

        if (now.isAfter(startDT) && now.isBefore(endDT)) {
          activeTask = task;
          break;
        }
      }
    }

    if (_currentActiveTask != activeTask) {
      if (mounted) {
        setState(() {
          _currentActiveTask = activeTask;
        });
      }
    }
  }

  void _checkScheduledTasks() async {
    DateTime now = DateTime.now();
    List<Task> todaysTasks = _getTasksForDay(0);

    for (var task in todaysTasks) {
      bool isCompletedToday = task.isCompletedOn(now);

      if (task.isNotified) {
        // Reset the flag on day rollover so weekly tasks can notify again
        // on their next occurrence. If the current time is earlier than
        // the task's scheduled time, we have crossed midnight into a new day.
        if (task.time != null) {
          final taskMins = task.time!.hour * 60 + task.time!.minute;
          final nowMins = now.hour * 60 + now.minute;
          if (nowMins < taskMins) {
            task.isNotified = false;
            _databaseService.saveTask(task);
          }
        }
        continue;
      }

      if (task.time != null && !isCompletedToday && !task.isNotified) {
        if (task.time!.hour == now.hour && task.time!.minute == now.minute) {
          task.isNotified = true;
          _databaseService.saveTask(task);

          if (_enableNotifications) {
            if (_playNotificationSound) {
              _playSound('notification.mp3');
            }

            LocalNotification notification = LocalNotification(
              identifier: task.id.toString(),
              title: "Schedulify Reminder",
              body: "It's time for: ${task.title}",
              silent: true,
            );

            notification.onClick = () {
              windowManager.show();
              windowManager.focus();
              windowManager.restore();
            };

            notification.show();
          }
        }
      }
    }
  }

  Future<void> _playSound(String fileName) async {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  Future<void> _openCalendarDialog() async {
    DateTime focusedDay = DateTime.now();
    DateTime? selectedDay = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(selectedDay, day),
                      eventLoader: (day) => _getSpecialDaysForDate(day),
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.grey),
                        todayDecoration: BoxDecoration(
                            color: Color(0xFF6C63FF), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(
                            color: Color(0xFF03DAC6), shape: BoxShape.circle),
                        markerDecoration: BoxDecoration(
                            color: Colors.amber, shape: BoxShape.circle),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        leftChevronIcon:
                            Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: Colors.white),
                      ),
                      onDaySelected: (selected, focused) async {
                        setDialogState(() {
                          selectedDay = selected;
                          focusedDay = focused;
                        });
                        await _showEventsForDayDialog(selected);
                        await _loadData();
                        setDialogState(() {});
                      },
                      onPageChanged: (focused) {
                        focusedDay = focused;
                      },
                    ),
                    const Spacer(),
                    const Text("Select a date to manage events",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEventsForDayDialog(DateTime date) async {
    await showDialog(
        context: context,
        builder: (c) => AlertDialog(
                backgroundColor: const Color(0xFF252525),
                title: Text(DateFormat('MMMM d, y').format(date),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                    textAlign: TextAlign.center),
                content: SizedBox(
                    width: 300, height: 300, child: _buildEventList(date)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Close",
                          style: TextStyle(color: Colors.grey)))
                ]));
  }

  Widget _buildEventList(DateTime date) {
    List<SpecialDay> events = _getSpecialDaysForDate(date);

    return Column(
      children: [
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    "No events",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (c, i) => ListTile(
                    dense: true,
                    title: Text(
                      events[i].title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: events[i].time != null
                        ? Text(
                            events[i].time!.format(context),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      onPressed: () async {
                        await _databaseService.deleteSpecialDay(events[i].id);
                        await _loadData();

                        if (!mounted) return;

                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);

            Future.microtask(() async {
              if (!mounted) return;
              await _showSpecialDayForm(date);
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text("Add Event"),
        ),
      ],
    );
  }

  String repetitionToText(RepetitionType type) {
    switch (type) {
      case RepetitionType.none:
        return "No Repeat";
      case RepetitionType.monthly:
        return "Monthly";
      case RepetitionType.yearly:
        return "Yearly";
    }
  }

  RepetitionType textToRepetition(String text) {
    switch (text) {
      case "Monthly":
        return RepetitionType.monthly;
      case "Yearly":
        return RepetitionType.yearly;
      default:
        return RepetitionType.none;
    }
  }

  Future<void> _showSpecialDayForm(DateTime date,
      {SpecialDay? eventToEdit}) async {
    TextEditingController nameController =
        TextEditingController(text: eventToEdit?.title ?? "");

    TimeOfDay? start = eventToEdit?.time;
    TimeOfDay? end = eventToEdit?.endTime;

    TextEditingController startTimeController = TextEditingController();
    TextEditingController endTimeController = TextEditingController();

    bool hasTime = start != null;

    if (start != null) {
      startTimeController.text =
          "${start.hour.toString().padLeft(2, '0')}${start.minute.toString().padLeft(2, '0')}";
    }
    if (end != null) {
      endTimeController.text =
          "${end.hour.toString().padLeft(2, '0')}${end.minute.toString().padLeft(2, '0')}";
    }

    RepetitionType selectedRepetition =
        eventToEdit?.repetition ?? RepetitionType.none;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252525),
              title: Text(
                eventToEdit != null ? "Edit Event" : "Add Event",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Title",
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: repetitionToText(selectedRepetition),
                      items: ["No Repeat", "Monthly", "Yearly"]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedRepetition = textToRepetition(value!);
                        });
                      },
                      buttonStyleData: ButtonStyleData(
                        height: 36,
                        width: 150,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade700),
                        ),
                      ),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 180,
                        width: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        offset: const Offset(0, -4),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      menuItemStyleData: const MenuItemStyleData(
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: hasTime,
                        activeColor:
                            Theme.of(dialogContext).colorScheme.primary,
                        onChanged: (v) => setStateDialog(() => hasTime = v!),
                      ),
                      const Text("Time", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (hasTime)
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 18, color: Colors.grey[500]),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 50,
                              child:
                                  _buildTimeField(startTimeController, "Start"),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "-",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 50,
                              child: _buildTimeField(endTimeController, "End"),
                            ),
                            const SizedBox(width: 30),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;

                    TimeOfDay? s =
                        hasTime ? _parseTime(startTimeController.text) : null;
                    TimeOfDay? e =
                        hasTime ? _parseTime(endTimeController.text) : null;

                    if (eventToEdit != null) {
                      await _databaseService.deleteSpecialDay(eventToEdit.id);
                    }

                    await _databaseService.saveSpecialDay(
                      SpecialDay(
                        date: date,
                        title: nameController.text,
                        repetition: selectedRepetition,
                        time: s,
                        endTime: e,
                      ),
                    );

                    await _loadData();
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<SpecialDay> _getSpecialDaysForDate(DateTime targetDate) {
    return specialDays.where((day) {
      if (day.repetition == RepetitionType.none) {
        return isSameDay(day.date, targetDate);
      }
      if (day.repetition == RepetitionType.yearly) {
        return day.date.month == targetDate.month &&
            day.date.day == targetDate.day;
      }
      if (day.repetition == RepetitionType.monthly) {
        return day.date.day == targetDate.day;
      }
      return false;
    }).toList();
  }

  void _addTask(String title, TimeOfDay? startTime, TimeOfDay? endTime) async {
    DateTime selectedDate =
        _anchorDate.add(Duration(days: _tabController.index));
    final newTask = Task(
        title: title,
        date: selectedDate,
        recurrence: Recurrence.weekly,
        time: startTime,
        endTime: endTime);
    await _databaseService.saveTask(newTask);
    await _loadData();
  }

  void _updateTask(
      int id, String newTitle, TimeOfDay? newStart, TimeOfDay? newEnd) async {
    final taskIndex = tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final existingTask = tasks[taskIndex];
    existingTask.title = newTitle;
    existingTask.time = newStart;
    existingTask.endTime = newEnd;
    existingTask.isNotified = false;
    await _databaseService.saveTask(existingTask);
    await _loadData();
  }

  void _toggleTask(int id, DateTime targetDate) async {
    final taskIndex = tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final task = tasks[taskIndex];
    final dateKey = DateTime(targetDate.year, targetDate.month, targetDate.day);
    bool isCompletedForDate = task.isCompletedOn(targetDate);

    if (!isCompletedForDate) {
      if (_playCompletionSound) _playSound('complete.mp3');
      task.completedDates = [...task.completedDates, dateKey];
    } else {
      task.completedDates =
          task.completedDates.where((d) => !isSameDay(d, dateKey)).toList();
    }
    await _databaseService.saveTask(task);
    setState(() {});
  }

  void _deleteTask(int id) async {
    await _databaseService.deleteTask(id);
    await _loadData();
  }

  List<Task> _getTasksForDay(int dayOffset) {
    DateTime targetDate = _anchorDate.add(Duration(days: dayOffset));
    final targetDayStart =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    List<Task> filteredTasks = tasks.where((t) {
      final taskStart = DateTime(t.date.year, t.date.month, t.date.day);
      if (targetDayStart.isBefore(taskStart)) return false;
      if (t.recurrence == Recurrence.weekly) {
        return t.date.weekday == targetDate.weekday;
      } else {
        return isSameDay(t.date, targetDate);
      }
    }).toList();
    filteredTasks.sort((a, b) {
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return _toMinutes(a.time!).compareTo(_toMinutes(b.time!));
    });
    return filteredTasks;
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool _hasTimeConflict(DateTime date, TimeOfDay start, TimeOfDay end,
      {int? excludeTaskId}) {
    final tasksOnDate = _getTasksForDay(date.difference(_anchorDate).inDays)
        .where((t) => t.id != excludeTaskId)
        .toList();
    int newStart = _toMinutes(start);
    int newEnd = _toMinutes(end);
    for (var task in tasksOnDate) {
      if (task.time != null && task.endTime != null) {
        int existingStart = _toMinutes(task.time!);
        int existingEnd = _toMinutes(task.endTime!);
        if (newStart < existingEnd && newEnd > existingStart) return true;
      }
    }
    return false;
  }

  Future<void> _showTaskDialog({Task? taskToEdit}) async {
    bool isEditing = taskToEdit != null;
    TextEditingController titleController =
        TextEditingController(text: isEditing ? taskToEdit.title : "");
    String initialStart = "";
    if (isEditing && taskToEdit.time != null) {
      initialStart =
          "${taskToEdit.time!.hour.toString().padLeft(2, '0')}:${taskToEdit.time!.minute.toString().padLeft(2, '0')}";
    }
    String initialEnd = "";
    if (isEditing && taskToEdit.endTime != null) {
      initialEnd =
          "${taskToEdit.endTime!.hour.toString().padLeft(2, '0')}:${taskToEdit.endTime!.minute.toString().padLeft(2, '0')}";
    }
    TextEditingController startTimeController =
        TextEditingController(text: initialStart);
    TextEditingController endTimeController =
        TextEditingController(text: initialEnd);

    try {
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252525),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Text(isEditing ? "Edit Task" : "New Task",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: titleController,
                    autofocus: !isEditing,
                    style: const TextStyle(
                        fontWeight: FontWeight.w300, fontSize: 14),
                    decoration: const InputDecoration(
                        hintText: "What needs to be done?",
                        hintStyle:
                            TextStyle(color: Colors.grey, fontSize: 14))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.access_time, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 50,
                      child: _buildTimeField(startTimeController, "Start")),
                  const SizedBox(width: 10),
                  const Text("-",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(width: 10),
                  SizedBox(
                      width: 50,
                      child: _buildTimeField(endTimeController, "End")),
                  const SizedBox(width: 30),
                ]),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.grey, fontSize: 13))),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      TimeOfDay? start = _parseTime(startTimeController.text);
                      TimeOfDay? end = _parseTime(endTimeController.text);
                      DateTime targetDate = isEditing
                          ? taskToEdit.date
                          : _anchorDate
                              .add(Duration(days: _tabController.index));

                      if (start != null && end != null) {
                        if (_toMinutes(end) <= _toMinutes(start)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "End time must be after start time!")));
                          return;
                        }
                        if (_hasTimeConflict(targetDate, start, end,
                            excludeTaskId: isEditing ? taskToEdit.id : null)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text("Time conflict!"),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error));
                          return;
                        }
                      }
                      if (isEditing) {
                        _updateTask(
                            taskToEdit.id, titleController.text, start, end);
                      } else {
                        _addTask(titleController.text, start, end);
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white),
                  child: Text(isEditing ? "Save" : "Add",
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                ),
              ],
            );
          });
    } finally {
      titleController.dispose();
      startTimeController.dispose();
      endTimeController.dispose();
    }
  }

  Widget _buildTimeField(TextEditingController controller, String hint) {
    return TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
          TimeInputFormatter()
        ],
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8)));
  }

  TimeOfDay? _parseTime(String text) {
    if (text.isNotEmpty && text.contains(":")) {
      try {
        final parts = text.split(":");
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
                child: Padding(
                    padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      const Text("Settings",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      SwitchListTile(
                          title: const Text("Minimize to System Tray",
                              style: TextStyle(fontSize: 14)),
                          subtitle: Text("Hide to tray when clicking close (X)",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                          value: _minimizeToTray,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) {
                            setModalState(() => _minimizeToTray = value);
                            setState(() => _minimizeToTray = value);
                            _settingsService.setBool(
                                SettingsService.keyMinimizeToTray, value);
                          }),
                      SwitchListTile(
                          title: const Text("Launch on Startup",
                              style: TextStyle(fontSize: 14)),
                          subtitle: Text("Open when Windows starts",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                          value: _startOnBoot,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) async {
                            if (value) {
                              await LaunchAtStartup.instance.enable();
                            } else {
                              await LaunchAtStartup.instance.disable();
                            }
                            setModalState(() => _startOnBoot = value);
                            setState(() => _startOnBoot = value);
                          }),
                      const Divider(color: Colors.white10),
                      SwitchListTile(
                          title: const Text("Task Completion Sound",
                              style: TextStyle(fontSize: 14)),
                          subtitle: Text("Play sound when checking a box",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                          value: _playCompletionSound,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) {
                            setModalState(() => _playCompletionSound = value);
                            setState(() => _playCompletionSound = value);
                            _settingsService.setBool(
                                SettingsService.keyPlayCompletionSound, value);
                          }),
                      SwitchListTile(
                          title: const Text("Enable Notifications",
                              style: TextStyle(fontSize: 14)),
                          subtitle: Text("Show cards for scheduled tasks",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                          value: _enableNotifications,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) {
                            setModalState(() => _enableNotifications = value);
                            setState(() => _enableNotifications = value);
                            _settingsService.setBool(
                                SettingsService.keyEnableNotifications, value);
                          }),
                      SwitchListTile(
                          title: const Text("Notification Sound",
                              style: TextStyle(fontSize: 14)),
                          subtitle: Text("Play sound when notification appears",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                          value: _playNotificationSound,
                          onChanged: _enableNotifications
                              ? (bool value) {
                                  setModalState(
                                      () => _playNotificationSound = value);
                                  setState(
                                      () => _playNotificationSound = value);
                                  _settingsService.setBool(
                                      SettingsService.keyPlayNotificationSound,
                                      value);
                                }
                              : null,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero),
                      const Divider(color: Colors.white10),
                      ListTile(
                          leading:
                              const Icon(LucideIcons.info, color: Colors.white70),
                          title: const Text(
                              "Version", style: TextStyle(fontSize: 14)),
                          contentPadding: EdgeInsets.zero,
                          trailing: Text(
                              _appVersion.isEmpty ? '...' : _appVersion,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12))),
                      const SizedBox(height: 10),
                    ])));
          });
        });
  }

  String _getDayName(int dayOffset) {
    DateTime targetDay = _anchorDate.add(Duration(days: dayOffset));
    return DateFormat('EEEE', 'en_US').format(targetDay);
  }

  String _getDateString(int dayOffset) {
    DateTime targetDay = _anchorDate.add(Duration(days: dayOffset));
    return DateFormat('d MMMM', 'en_US').format(targetDay);
  }

  Widget _buildHeaderContent() {
    return const Expanded(
      child: Center(
        child: Text(
          "Schedulify",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(LucideIcons.settings),
                  tooltip: "Settings",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showSettingsPanel),
              _buildHeaderContent(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      onPressed: _openCalendarDialog,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.calendar),
                      tooltip: "Manage Special Days"),
                  const SizedBox(width: 3),
                ],
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelPadding: EdgeInsets.zero,
          onTap: (index) {
            setState(() {});
          },
          tabs: List.generate(7, (index) {
            return Tab(child: Text(_getDayName(index).substring(0, 3)));
          }),
        ),
      ),
      floatingActionButton: null,
      body: TabBarView(
        controller: _tabController,
        children: List.generate(7, (index) {
          return _buildDayContent(index);
        }),
      ),
    );
  }

  Widget _buildDayContent(int dayOffset) {
    final dailyTasks = _getTasksForDay(dayOffset);
    DateTime targetDate = _anchorDate.add(Duration(days: dayOffset));
    DateTime now = DateTime.now();
    bool isActuallyToday = isSameDay(targetDate, now);
    List<SpecialDay> dayEvents = _getSpecialDaysForDate(targetDate);

    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 0.0, top: 16.0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 0),
            child: Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getDayName(dayOffset),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600)),
                  Text(_getDateString(dayOffset),
                      style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                ],
              ),
              const Spacer(),
              if (isActuallyToday)
                AnimatedBuilder(
                  animation: timeTicker,
                  builder: (context, _) => const LiveClockWidget(),
                ),
              if (isActuallyToday) const SizedBox(width: 10),
              InkWell(
                onTap: () => _showTaskDialog(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.plus,
                      size: 24, color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (dayEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 16),
              child: Column(
                children: dayEvents.map((d) {
                  String? timeLabel;
                  if (d.time != null) {
                    timeLabel = d.time!.format(context);
                    if (d.endTime != null) {
                      timeLabel += ' – ${d.endTime!.format(context)}';
                    }
                  }

                  String? repeatLabel;
                  if (d.repetition == RepetitionType.monthly) {
                    repeatLabel = 'Monthly';
                  } else if (d.repetition == RepetitionType.yearly) {
                    repeatLabel = 'Yearly';
                  }

                  return GestureDetector(
                    onTap: () async {
                      await _showSpecialDayForm(d.date, eventToEdit: d);
                      await _loadData();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.star,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (timeLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      timeLabel,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (repeatLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                repeatLabel,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: dailyTasks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clipboardList,
                            size: 36, color: Colors.white12),
                        SizedBox(height: 12),
                        Text(
                          "No tasks for this day.",
                          style: TextStyle(
                              color: Colors.white38, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tap + to add one.",
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ScrollConfiguration(
                    behavior: MouseScrollBehavior(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 0, right: 16),
                      itemCount: dailyTasks.length,
                      itemBuilder: (context, index) {
                        final task = dailyTasks[index];
                        Color cardColor = const Color(0xFF2C2C2C);
                        bool isCompletedForDate =
                            task.isCompletedOn(targetDate);

                        return AnimatedBuilder(
                          animation: timeTicker,
                          builder: (context, _) {
                            return TaskCard(
                              task: task,
                              cardColor: cardColor,
                              isCompleted: isCompletedForDate,
                              isToday: isActuallyToday,
                              isEditable: true,
                              onToggle: isActuallyToday
                                  ? (_) => _toggleTask(task.id, targetDate)
                                  : null,
                              onEdit: () => _showTaskDialog(taskToEdit: task),
                              onDelete: () => _deleteTask(task.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (text.isEmpty) return newValue;
    String numbersOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbersOnly.length > 4) return oldValue;
    if (numbersOnly.isNotEmpty) {
      int first = int.parse(numbersOnly[0]);
      if (first > 2) return oldValue;
    }
    if (numbersOnly.length >= 2) {
      int first = int.parse(numbersOnly[0]);
      int second = int.parse(numbersOnly[1]);
      if (first == 2 && second > 3) return oldValue;
    }
    if (numbersOnly.length >= 3) {
      int third = int.parse(numbersOnly[2]);
      if (third > 5) return oldValue;
    }
    String formatted = numbersOnly;
    if (numbersOnly.length >= 3) {
      formatted = '${numbersOnly.substring(0, 2)}:${numbersOnly.substring(2)}';
    }
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final newNow = DateTime.now();
      if (newNow.minute != _now.minute) {
        setState(() {
          _now = newNow;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat('HH:mm').format(_now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.clock, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            timeString,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
