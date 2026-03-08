import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await localNotifier.setup(
    appName: 'Schedulify',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  LaunchAtStartup.instance.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
  );

  const double appWidth = 450;
  const double appHeight = 750;
  // Margin from the right and bottom edges of the usable screen area.
  // These account for the Windows taskbar and desktop padding.
  const double windowMarginRight = 5.0;
  const double windowMarginBottom = 50.0;

  WindowOptions windowOptions = const WindowOptions(
    size: Size(appWidth, appHeight),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: "Schedulify",
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    Size usableSize = primaryDisplay.visibleSize ?? primaryDisplay.size;
    Offset usablePos = primaryDisplay.visiblePosition ?? const Offset(0, 0);

    double newX = usablePos.dx + usableSize.width - appWidth - windowMarginRight;
    double newY = usablePos.dy + usableSize.height - appHeight - windowMarginBottom;

    await windowManager
        .setBounds(Rect.fromLTWH(newX, newY, appWidth, appHeight));

    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);

    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Schedulify',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF03DAC6),
        ),
        cardColor: const Color(0xFF2C2C2C),
      ),
      home: const HomePage(),
    );
  }
}
