import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/event/game_event.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/main_game_bloc.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/state/game_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AircraftScene extends StatefulWidget {
  const AircraftScene({super.key});

  @override
  State<AircraftScene> createState() => _AircraftSceneState();
}

class _AircraftSceneState extends State<AircraftScene> {
  final Flutter3DController controller = Flutter3DController();

  @override
  void initState() {
    super.initState();

    controller.onModelLoaded.addListener(() {
      if (controller.onModelLoaded.value) {
        context.read<MainGameBloc>().add(const GameEvent.modelLoaded()); // [web:2]
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MainGameBloc, GameState>(
      listenWhen: (prev, curr) {
        final p = prev.maybeWhen(
          flight: (theta, phi, radius, tx, ty, tz) => (theta, phi, radius, tx, ty, tz),
          orElse: () => null,
        );
        final c = curr.maybeWhen(
          flight: (theta, phi, radius, tx, ty, tz) => (theta, phi, radius, tx, ty, tz),
          orElse: () => null,
        );
        return p != c;
      },
      listener: (context, state) {
        state.maybeWhen(
          flight: (theta, phi, radius, tx, ty, tz) {
            controller.setCameraOrbit(theta, phi, radius);
            controller.setCameraTarget(tx, ty, tz);
          },
          orElse: () {},
        );
      },
      child: Flutter3DViewer(
        src: "assets/3d_models/airplane.glb",
        controller: controller,
        enableTouch: false,
      ),
    );
  }
}
