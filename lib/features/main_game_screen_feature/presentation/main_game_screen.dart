import 'package:aircraft_simulator/core/di/init_di.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/thress_space/three_space_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MainGameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ThreeSpaceScene();
  }
}
