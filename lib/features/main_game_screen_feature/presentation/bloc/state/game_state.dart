import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';

@freezed
sealed class GameState with _$GameState {
  const factory GameState.initial() = _Initial;
  const factory GameState.flight({
    required double theta,
    required   double phi,
    required   double radius,
    required  double tx,
    required   double ty,
    required   double tz,
  }) = _Flight;
}
