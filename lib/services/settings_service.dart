import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String keyMinimizeToTray = 'minimize_to_tray';
  static const String keyPlayCompletionSound = 'play_completion_sound';
  static const String keyEnableNotifications = 'enable_notifications';
  static const String keyPlayNotificationSound = 'play_notification_sound';

  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool> getBool(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }
}
