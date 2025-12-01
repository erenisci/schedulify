import 'dart:async';

import 'package:flutter/material.dart';

class TimeTicker with ChangeNotifier {
  late Timer _timer;

  TimeTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final timeTicker = TimeTicker();
