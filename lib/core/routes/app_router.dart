// core/router/app_router.dart
import 'package:aircraft_simulator/features/main_menu_screen_feature/presentation/main_menu_screen.dart';
import 'package:aircraft_simulator/features/result_screen_feature/presentation/result_screen.dart';
import 'package:flutter/material.dart';
import '../../features/main_game_screen_feature/presentation/main_game_screen.dart';

class AppRouter {
  static String getInitialRoute() {
    return '/';
  }
  static const  String gameRoute = "/game";
  static const String resultRoute = "/result";


  static Route<dynamic> generateRoute(RouteSettings settings) {
    final Map<dynamic,dynamic>? args = settings.arguments!=null?settings.arguments! as Map<dynamic,dynamic>:null;

    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => MainMenuScreen());
      case gameRoute:
        return MaterialPageRoute(builder: (_) =>  MainGameScreen());
      case resultRoute:
        return MaterialPageRoute(builder: (_) =>  ResultScreen(timeLeft: args!["time"],trajectory: args["trajectory"], score: args["score"],goalScore: args['goalScore'],isWon: args["isWon"],));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
