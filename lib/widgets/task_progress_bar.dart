import 'package:flutter/material.dart';

class TaskProgressBar extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;

  const TaskProgressBar({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  double _calculateProgress() {
    final now = DateTime.now();
    final totalSeconds = endTime.difference(startTime).inSeconds;
    final passedSeconds = now.difference(startTime).inSeconds;

    if (totalSeconds == 0) return 0.0;
    if (passedSeconds <= 0) return 0.0;
    if (passedSeconds >= totalSeconds) return 1.0;

    return passedSeconds / totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
      ),
    );
  }
}
