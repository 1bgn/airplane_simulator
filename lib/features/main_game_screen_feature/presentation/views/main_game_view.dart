import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/scene/aircraft_scene.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/scene/earth_scene.dart';
import 'package:flutter/material.dart';

class MainGameView extends StatelessWidget {
  const MainGameView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children:  [
            EarthScene(),
            AircraftScene(),
          ],
        ),
      ),
    );
  }
}
