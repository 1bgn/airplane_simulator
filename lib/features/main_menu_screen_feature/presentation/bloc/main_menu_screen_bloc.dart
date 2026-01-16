import 'package:aircraft_simulator/features/main_menu_screen_feature/application/main_menu_service.dart';
import 'package:aircraft_simulator/features/result_screen_feature/application/result_screen_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'main_menu_screen_bloc.freezed.dart';


@freezed
sealed class MenuEvent with _$MenuEvent {
  const factory MenuEvent.init( ) = _Init;
}
@freezed
sealed class MenuState with _$MenuState {
  const factory MenuState.initial() = _Initial;

}
@injectable
class MainMenuScreenBloc extends Bloc<MenuEvent,MenuState>{
  final MainMenuScreenService _service;
  MainMenuScreenBloc(this._service):super(MenuState.initial());

  int get currentMoney => _service.getMoney();
  String get currentAirplane => _service.getAirplane();
}