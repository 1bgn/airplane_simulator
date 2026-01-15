import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_event.freezed.dart';

@freezed
sealed class GameEvent with _$GameEvent {
  const factory GameEvent.modelLoaded() = _ModelLoaded;
  const factory GameEvent.joystickChanged() = _JoystickChanged;

}