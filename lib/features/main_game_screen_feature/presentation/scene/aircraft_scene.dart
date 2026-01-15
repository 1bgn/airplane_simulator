import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/event/game_event.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/main_game_bloc.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/state/game_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AircraftScene extends StatefulWidget{
  AircraftScene({super.key});

  @override
  State<AircraftScene> createState() => _AircraftSceneState();
}

class _AircraftSceneState extends State<AircraftScene> {
  final Flutter3DController controller = Flutter3DController();

  @override
  void initState() {
    super.initState();
    controller.onModelLoaded.addListener(() {


    });
  }

  @override
  Widget build(BuildContext context) {
    return     BlocListener<MainGameBloc,GameState>(
      listener: (BuildContext context, state) {  },
      child: Flutter3DViewer(
        src: "assets/3d_models/airplane.glb",
        controller:  controller,
      ),
    );
  }
}