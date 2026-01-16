// core/router/app_router.dart
import 'package:aircraft_simulator/core/di/init_di.dart';
import 'package:aircraft_simulator/features/main_menu_screen_feature/presentation/bloc/main_menu_screen_bloc.dart';
import 'package:aircraft_simulator/features/main_menu_screen_feature/presentation/main_menu_screen.dart';
import 'package:aircraft_simulator/features/result_screen_feature/presentation/bloc/result_screen_bloc.dart';
import 'package:aircraft_simulator/features/result_screen_feature/presentation/result_screen.dart';
import 'package:aircraft_simulator/features/rules_screen_feature/presentation/rules_screen.dart';
import 'package:aircraft_simulator/features/shop_screen_feature/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/main_game_screen_feature/presentation/main_game_screen.dart';
import '../../features/shop_screen_feature/presentation/bloc/shop_screen_bloc.dart';

class AppRouter {
  static String getInitialRoute() {
    return '/';
  }
  static const  String gameRoute = "/game";
  static const String resultRoute = "/result";
  static const String shopRoute = "/shop";
  static const String rulesRoute = "/rules";


  static Route<dynamic> generateRoute(RouteSettings settings) {
    final Map<dynamic,dynamic>? args = settings.arguments!=null?settings.arguments! as Map<dynamic,dynamic>:null;

    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => BlocProvider<MainMenuScreenBloc>(create: (c)=>getIt(),child: MainMenuScreen(),));
      case gameRoute:
        return MaterialPageRoute(builder: (_) =>  MainGameScreen());
      case rulesRoute:
        return MaterialPageRoute(builder: (_) =>  RulesScreen());
      case shopRoute:
        return MaterialPageRoute(builder: (_) =>  BlocProvider<ShopScreenBloc>(child: ShopScreen(),create: (c)=>getIt(),));
      case resultRoute:
        return MaterialPageRoute(builder: (_) =>  BlocProvider<ResultScreenBloc>(create: (BuildContext context) =>getIt(),
        child: ResultScreen(timeLeft: args!["time"],trajectory: args["trajectory"], score: args["score"],goalScore: args['goalScore'],isWon: args["isWon"],)));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
