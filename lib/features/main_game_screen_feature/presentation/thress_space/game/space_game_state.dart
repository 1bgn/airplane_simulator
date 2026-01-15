import 'package:flutter/foundation.dart';

class SpaceGameState extends ChangeNotifier {
  SpaceGameState({
    required this.goalScore,
    required this.totalSeconds,
  }) : timeLeft = totalSeconds;

  final int goalScore;
  final int totalSeconds;

  int score = 0;
  int timeLeft;

  bool ended = false;
  bool won = false;

  void reset() {
    score = 0;
    timeLeft = totalSeconds;
    ended = false;
    won = false;
    notifyListeners();
  }

  void tick() {
    if (ended) return;
    timeLeft -= 1;
    notifyListeners();
  }

  void addScore(int delta) {
    if (ended) return;
    score += delta;
    notifyListeners();
  }

  void finish({required bool won}) {
    if (ended) return;
    ended = true;
    this.won = won;
    notifyListeners();
  }
}
