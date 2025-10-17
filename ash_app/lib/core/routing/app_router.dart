import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/onboarding/tutorial_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/chat/chat_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';
  static const String tutorial = '/tutorial';
  static const String login = '/login';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String calendar = '/calendar';
  static const String settings = '/settings';
  static const String email = '/email';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      // case welcome:
      //   return MaterialPageRoute(
      //     builder: (_) => const WelcomeScreen(),
      //     settings: settings,
      //   );

      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );

      case tutorial:
        return MaterialPageRoute(
          builder: (_) => const TutorialScreen(),
          settings: settings,
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case chat:
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
          settings: settings,
        );

      case calendar:
        return MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
          settings: settings,
        );

      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }

  static void pushNamed(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void pushReplacementNamed(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void pushAndRemoveUntil(BuildContext context, String routeName,
      {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }

  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }
}
