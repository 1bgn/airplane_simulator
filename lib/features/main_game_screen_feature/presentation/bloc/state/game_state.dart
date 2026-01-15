import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';

@freezed
sealed class GameState with _$GameState {
  const factory GameState.initial() = _Initial;
  const factory GameState.flight(
    double theta,
    double phi,
    double radius,
    double tx,
    double ty,
    double tz,
  ) = _Flight;
}
