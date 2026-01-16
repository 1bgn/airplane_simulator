import 'package:aircraft_simulator/core/di/init_di.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/main_game_screen.dart';
import 'package:flutter/material.dart';

import 'core/routes/app_router.dart';

void main() {
  configureDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subscription App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.getInitialRoute(),
    );
  }
}


