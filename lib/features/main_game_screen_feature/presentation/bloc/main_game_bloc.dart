import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/event/game_event.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/state/game_state.dart';
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class MainGameBloc extends Bloc<GameEvent, GameState> {
  MainGameBloc() : super(GameState.initial()) {
    on<GameEvent>((event, emit) async {
      await event.map(modelLoaded: (_) {
        emit(const GameState.flight(
          theta: 20,
          phi: 20,
          radius: 5,
          tx: 0, ty: 0, tz: 0,
        ));
      }, joystickChanged: (e) {

        state.maybeWhen(
          flight: (theta, phi, radius, tx, ty, tz) {

            emit(GameState.flight(
              theta: (theta + e.x * 2.0).clamp(-180.0, 180.0),
              phi: (phi + (-e.y) * 2.0).clamp(-85.0, 85.0),
              radius: radius,
              tx: tx, ty: ty, tz: tz,
            ));
          },
          orElse: () {},
        );
      });
    });
  }
}
