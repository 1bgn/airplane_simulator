import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/event/game_event.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/main_game_bloc.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/scene/aircraft_scene.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/scene/earth_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class MainGameView extends StatelessWidget {
  const MainGameView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
             EarthScene(),
             AircraftScene(),

            Positioned(
              left: 24,
              bottom: 24,
              child: Joystick(
                period: const Duration(milliseconds: 16),
                listener: (details) {
                  context.read<MainGameBloc>().add(
                    GameEvent.joystickChanged(
                      x: details.x,
                      y: details.y,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
