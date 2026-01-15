import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:three_js/three_js.dart' as three;

import 'game/space_game.dart';
import 'game/space_game_state.dart';

class ThreeSpaceScene extends StatefulWidget {
  const ThreeSpaceScene({super.key});

  @override
  State<ThreeSpaceScene> createState() => _ThreeSpaceSceneState();
}

class _ThreeSpaceSceneState extends State<ThreeSpaceScene> {
  late final three.ThreeJS _threeJs;
  late final SpaceGameState _state;
  late final SpaceGame _game;

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();

    _state = SpaceGameState(
      goalScore: 10,
      totalSeconds: 60,
    );

    _game = SpaceGame(
      state: _state,
      onGameOver: _onGameOver,
    );

    _threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
    );
  }

  Future<void> _setup() => _game.setup(_threeJs);

  @override
  void dispose() {
    _game.dispose();
    _threeJs.dispose();
    three.loading.clear();
    _state.dispose();
    super.dispose();
  }

  void _onGameOver({required bool won}) {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: _state,
          builder: (_, __) {
            return AlertDialog(
              title: Text(won ? 'Победа!' : 'Время вышло'),
              content: Text(
                'Собрано: ${_state.score} / ${_state.goalScore}\n'
                    'Осталось времени: ${_state.timeLeft.clamp(0, _state.totalSeconds)} c',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _dialogShown = false;
                    _game.restart();
                  },
                  child: const Text('Заново'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _dialogShown = false;
                  },
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _threeJs.build(),

          // HUD
          Positioned(
            left: 20,
            top: 40,
            child: AnimatedBuilder(
              animation: _state,
              builder: (_, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: Colors.black54,
                  child: Text(
                    'Score: ${_state.score} / ${_state.goalScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                );
              },
            ),
          ),

          Positioned(
            left: 20,
            top: 85,
            child: AnimatedBuilder(
              animation: _state,
              builder: (_, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: Colors.black54,
                  child: Text(
                    'Time: ${_state.timeLeft.clamp(0, _state.totalSeconds)}s',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              },
            ),
          ),

          // Joystick
          Positioned(
            left: 20,
            bottom: 20,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Joystick(
                mode: JoystickMode.horizontal,
                period: const Duration(milliseconds: 16),
                listener: (details) {
                  _game.setYawInput(-details.x);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
