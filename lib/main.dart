// lib/main.dart (Offline)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'app/navigation/route_observer.dart';
import 'features/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[ENV] Failed to load .env → $e');
  }

  final tmdbKey =
      (dotenv.env['TMDB_KEY'] ?? const String.fromEnvironment('TMDB_KEY'))
          .trim();
  final keyPresent = tmdbKey.isNotEmpty;
  final lang =
      dotenv.env['TMDB_LANG'] ??
      const String.fromEnvironment('TMDB_LANG', defaultValue: 'en-US');
  final region =
      dotenv.env['TMDB_REGION'] ??
      const String.fromEnvironment('TMDB_REGION', defaultValue: 'US');
  debugPrint('[ENV] TMDB_KEY present=$keyPresent');
  debugPrint('[ENV] LANG=$lang | REGION=$region');

  final themeCtrl = ThemeController();
  await themeCtrl.init();

  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exception}');
    if (kDebugMode) debugPrintStack(stackTrace: details.stack);
  };

  runZonedGuarded(() => runApp(FlickNestOfflineApp(themeCtrl: themeCtrl)), (
    error,
    stack,
  ) {
    debugPrint('[ZonedError] $error');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
  });
}

class AppScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  // remove glow
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class FlickNestOfflineApp extends StatelessWidget {
  final ThemeController themeCtrl;
  const FlickNestOfflineApp({super.key, required this.themeCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeCtrl,
      builder: (context, _) {
        final brand = themeCtrl.brandPrimary;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeCtrl.themeMode == ThemeMode.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: themeCtrl.themeMode == ThemeMode.dark
                ? Brightness.dark
                : Brightness.light,
          ),
        );

        final transitions = const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          },
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FlickNest (Offline)',
          theme: AppTheme.light(brand).copyWith(pageTransitionsTheme: transitions),
          darkTheme: AppTheme.dark(brand).copyWith(pageTransitionsTheme: transitions),
          themeMode: themeCtrl.themeMode,
          navigatorObservers: [routeObserver],
          scrollBehavior: AppScrollBehavior(),
          // Fix: pass themeCtrl to HomePage
          home: HomePage(themeCtrl: themeCtrl),
        );
      },
    );
  }
}