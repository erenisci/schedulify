import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../task.dart';
import 'task_progress_bar.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color cardColor;
  final bool isCompleted;
  final bool isEditable;
  final ValueChanged<bool?>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isToday;

  const TaskCard({
    super.key,
    required this.task,
    required this.cardColor,
    required this.isCompleted,
    required this.isToday,
    this.isEditable = true,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String? timeRangeText;
    DateTime? startDT;
    DateTime? endDT;

    if (task.time != null) {
      final now = DateTime.now();
      startDT = DateTime(
          now.year, now.month, now.day, task.time!.hour, task.time!.minute);

      if (task.endTime != null) {
        timeRangeText =
            "${task.time!.format(context)} - ${task.endTime!.format(context)}";
        endDT = DateTime(now.year, now.month, now.day, task.endTime!.hour,
            task.endTime!.minute);
        if (endDT.isBefore(startDT)) {
          endDT = endDT.add(const Duration(days: 1));
        }
      } else {
        timeRangeText = task.time!.format(context);
      }
    }

    bool showProgress =
        isToday && startDT != null && endDT != null && !isCompleted;

    return Card(
      key: ValueKey(task.id),
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Tooltip(
              message: onToggle == null
                  ? 'Toggling is only available for today'
                  : '',
              child: Opacity(
                opacity: onToggle == null ? 0.4 : 1.0,
                child: Checkbox(
                  value: isCompleted,
                  activeColor: Theme.of(context).colorScheme.secondary,
                  onChanged: onToggle,
                ),
              ),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
            subtitle: timeRangeText != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock,
                            size: 12,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          timeRangeText,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400),
                        )
                      ],
                    ),
                  )
                : null,
            trailing: isEditable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil,
                            size: 16, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2,
                            size: 16, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                    ],
                  )
                : null,
          ),
          if (showProgress)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
              child: TaskProgressBar(startTime: startDT, endTime: endDT),
            ),
        ],
      ),
    );
  }
}
