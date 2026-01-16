import 'package:flutter/foundation.dart';
import 'package:three_js/three_js.dart' as three;

class SpaceGameState extends ChangeNotifier {
  SpaceGameState({
    required this.goalScore,
    required this.totalSeconds,
  }) : timeLeft = totalSeconds;

  final int goalScore;
  final int totalSeconds;
  final List<three.Vector3> trajectory = [];


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
