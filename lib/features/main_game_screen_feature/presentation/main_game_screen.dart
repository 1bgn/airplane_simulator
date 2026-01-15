import 'package:aircraft_simulator/core/di/init_di.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/main_game_bloc.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/views/main_game_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MainGameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => getIt<MainGameBloc>(),
      child: MainGameView(),
    );
  }
}
