import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/event/game_event.dart';
import 'package:aircraft_simulator/features/main_game_screen_feature/presentation/bloc/state/game_state.dart';
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
@injectable
class MainGameBloc extends Bloc<GameEvent,GameState>{
  MainGameBloc():super(GameState.initial());

}