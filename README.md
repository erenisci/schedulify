# Schedulify

A modern, offline-first weekly planner built as a Windows desktop widget. Schedulify lives in your system tray and helps you manage recurring tasks and special events without the overhead of a full-screen calendar app.

---

## Features

| Feature                     | Description                                                                                                                                                |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Weekly Recurrence**       | Tasks repeat weekly by default. Set up your routine once — Schedulify keeps it for every coming week.                                                      |
| **Time Conflict Detection** | Prevents overlapping tasks. Trying to add a task at 14:00 when 13:30–14:30 is already taken? The app will warn you.                                        |
| **Offline-First Storage**   | Powered by Isar (embedded NoSQL). All data is stored locally — no internet required, no data lost on restart.                                              |
| **Native Notifications**    | Windows toast notifications with optional sound alert when a task is due, even while minimized to tray.                                                    |
| **Special Days**            | Track birthdays, anniversaries, or deadlines via the built-in calendar. Days with events are highlighted with styled amber cards directly in the day view. |
| **System Tray Integration** | Minimizes next to the clock. Right-click the tray icon to show or exit the app.                                                                            |
| **Auto-Launch on Startup**  | Optionally launch with Windows so your schedule is always one click away.                                                                                  |
| **Dark UI**                 | Optimized for dark environments. Roboto typography, Lucide icons, subtle progress bars for ongoing tasks.                                                  |

---

## Installation

Download the latest release from the [Releases](../../releases) page.

1. Download and extract the `.zip` file.
2. Run `schedulify.exe`.

No installer required — it's fully portable.

---

## Building from Source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (latest stable)
- Visual Studio 2022 with the **Desktop development with C++** workload

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/erenisci/schedulify.git
cd schedulify

# 2. Install dependencies
flutter pub get

# 3. Generate Isar schema code
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Run in debug mode
flutter run -d windows
```

### Production Build

```bash
flutter clean
flutter pub get
flutter build windows
```

Output: `build/windows/x64/runner/Release/`

---

## Running Tests

```bash
flutter test
```

Tests cover the core `Task` model logic — completion tracking and time accessor correctness.

---

## Tech Stack

| Layer             | Technology                                              |
| ----------------- | ------------------------------------------------------- |
| Framework         | Flutter 3 (Dart)                                        |
| Database          | [Isar](https://isar.dev) — embedded NoSQL, zero config  |
| Window Management | `window_manager`, `tray_manager`, `screen_retriever`    |
| Notifications     | `local_notifier` (Windows toast)                        |
| Audio             | `audioplayers`                                          |
| UI                | `lucide_icons`, Google Fonts (Roboto), `table_calendar` |
| Persistence       | `shared_preferences` (settings), Isar (task data)       |

---

## Project Structure

```
lib/
├── main.dart                  # Entry point, window positioning, theme setup
├── home_page.dart             # Main UI, weekly tabs, task management logic
├── task.dart                  # Task and SpecialDay data models (Isar collections)
├── services/
│   ├── database_service.dart  # Isar singleton — CRUD operations
│   ├── settings_service.dart  # SharedPreferences wrapper for user settings
│   └── time_ticker.dart       # ChangeNotifier timer for live UI updates
└── widgets/
    ├── task_card.dart         # Reusable task display card
    └── task_progress_bar.dart # Linear progress indicator for active tasks
```

---

## Contributing

Contributions, issues, and feature requests are welcome.

1. Fork the project
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
