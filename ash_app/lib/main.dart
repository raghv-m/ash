import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart'; // Added Firebase core

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await StorageService.init();

  // Initialize notification service
  await NotificationService.init();

  // Request permissions
  await _requestPermissions();

  runApp(
    const ProviderScope(
      child: ASHApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Request microphone permission for voice features
  await Permission.microphone.request();

  // Request notification permission
  await Permission.notification.request();

  // Request calendar permission (Android)
  await Permission.calendarWriteOnly.request();
}

class ASHApp extends ConsumerWidget {
  const ASHApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeMode = themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
