## Schedulify

Schedulify is a modern, offline-first weekly planner designed specifically for the Windows desktop environment. It functions as a non-intrusive widget that resides in your system tray, helping you organize your recurring weekly tasks and special events without the clutter of a full-screen calendar.

### Key Features

- **Weekly Recurrence Logic**: Tasks are designed to repeat weekly. Plan your routine once (e.g., "Gym every Monday"), and it stays there for every coming week.
- **Smart Conflict Detection**: Prevents you from scheduling overlapping tasks (e.g., adding a task at 14:00 when you are already busy between 13:30 - 14:30).
- **Offline-First & Persistent**: Powered by Isar Database. Your data lives locally on your machine. No internet connection required, no data lost on restart.
- **Native Notifications**: Receive rich Windows toast notifications with sound when a task is due, even if the app is minimized.
- **Special Days Engine**: Add birthdays, anniversaries, or deadlines via a custom calendar. The app highlights these days with a special banner and styling.
- **System Tray Integration**: Minimizes to the system tray (next to the clock) to keep your taskbar clean. Runs silently in the background.
- **Modern UI**:
  - Dark Mode optimized.
  - Custom Roboto typography.
  - Clean Lucide iconography.
  - Auto-sorting tasks by time.
- **Startup Support**: Option to automatically launch when Windows starts.

### Installation

You can download the latest version of Schedulify from the Releases Page.

1. Download the `.zip` file from releases.
2. Extract it to a folder.
3. Run `schedulify.exe`.

### Development (For Contributors)

If you want to build this project from source or contribute, follow these steps.

#### Prerequisites

- Flutter SDK (Latest Stable)
- Visual Studio (with C++ Desktop Development workload) for Windows runner.

#### Getting Started

1. Clone the repository:
   `git clone https://github.com/erenisci/schedulify.git`
   `cd schedulify`

2. Install dependencies:
   `flutter pub get`

3. Generate Database Code:
   Since this project uses Isar, you must run the build runner to generate the necessary serialization code (`task.g.dart`).
   `flutter pub run build_runner build --delete-conflicting-outputs`

4. Run the App:
   `flutter run -d windows`

#### Building a Production Release

To build the production Windows executable::

1. Clean build cache:
   `flutter clean`
   `flutter pub get`

2. Build a Windows release:
   `flutter build windows`

Your compiled application will appear in: `build/windows/x64/runner/Release`

### Tech Stack

- **Framework**: Flutter (Dart)
- **Database**: Isar (NoSQL, High Performance)
- **State Management**: `setState` & Controllers (Optimized for Widget Performance)
- **Window Management**: `window_manager`, `tray_manager`, `screen_retriever`
- **Notifications**: `local_notifier`
- **Assets**: `audioplayers` for custom sounds, `lucide_icons` for UI.

### Contributing

Contributions, issues, and feature requests are welcome!
Feel free to check the issues page.

1. Fork the Project
2. Create your Feature Branch (git checkout -b feature/AmazingFeature)
3. Commit your Changes (git commit -m 'Add some AmazingFeature')
4. Push to the Branch (git push origin feature/AmazingFeature)
5. Open a Pull Request

### License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
