// core/router/app_router.dart
import 'package:aircraft_simulator/features/main_menu_screen_feature/presentation/main_menu_screen.dart';
import 'package:flutter/material.dart';
import '../../features/main_game_screen_feature/presentation/main_game_screen.dart';

class AppRouter {
  static String getInitialRoute() {
    return '/';
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => MainMenuScreen());
      case '/game':
        return MaterialPageRoute(builder: (_) =>  MainGameScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
