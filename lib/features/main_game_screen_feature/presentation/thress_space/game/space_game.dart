import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:three_js/three_js.dart' as three;

import '../scene/terrain_generator.dart';
import '../utils/game_math.dart';
import 'space_game_state.dart';

class SpaceGame {
  SpaceGame({
    required this.state,
    required this.onGameOver,
  });

  final SpaceGameState state;
  final void Function({required bool won}) onGameOver;

  // three
  late three.ThreeJS _threeJs;

  three.Mesh? _terrain;

  three.Object3D? _airplaneRig;
  three.Object3D? _airplaneModel;

  three.Object3D? _ballTemplate;
  final List<three.Object3D> _balls = [];

  // Terrain params
  final double terrainW = 2000.0;
  final double terrainH = 2000.0;
  final int terrainSegW = 240;
  final int terrainSegH = 240;

  // Flight state
  double planeX = 0.0;
  double planeZ = -800.0;
  final double flightY = 60.0;

  final double planeSpeed = 120.0;

  // Heading (yaw) radians, 0 => +Z
  double yaw = 0.0;

  // Joystick input (-1..1)
  double _yawInput = 0.0;
  final double yawRate = 1.4; // rad/s at full deflection

  // Camera follow
  final double followBack = 110.0;
  final double followUp = 35.0;
  final double followLeft = 8.0;

  // Bank animation
  final double maxBankDeg = 18.0;
  final double bankSmooth = 0.12;
  double _bank = 0.0;

  // Collectibles
  final int ballCount = 50;
  final double pickupRadius = 28.0;

  // Hover = доп.зазор над поверхностью, а не "высота центра"
  final double ballHover = 6.0;
  double _ballRadius = 0.0;
  final double _groundEps = 0.5;

  final double targetBallRadius = 10.0;

  Timer? _timer;
  bool _disposed = false;

  final _rng = math.Random();

  // temps
  final three.Vector3 _tmpForward = three.Vector3(0, 0, 1);
  final three.Vector3 _tmpLookAt = three.Vector3(0, 0, 0);

  void setYawInput(double v) {
    if (state.ended) {
      _yawInput = 0.0;
      return;
    }
    _yawInput = v.clamp(-1.0, 1.0);
  }

  Future<void> setup(three.ThreeJS threeJs) async {
    _threeJs = threeJs;

    // Camera
    _threeJs.camera = three.PerspectiveCamera(
      60,
      _threeJs.width / _threeJs.height,
      1,
      4000,
    );
    _threeJs.camera.up.setValues(0, 1, 0);

    // Scene
    _threeJs.scene = three.Scene();
    _threeJs.scene.background = three.Color.fromHex32(0x4A90E2);

    // Light
    _threeJs.scene.add(three.AmbientLight(0xffffff, 0.55));
    final sun = three.DirectionalLight(0xffffff, 1.2);
    sun.position.setValues(300, 600, 200);
    _threeJs.scene.add(sun);

    // Terrain
    _terrain = TerrainGenerator(
      width: terrainW,
      height: terrainH,
      segW: terrainSegW,
      segH: terrainSegH,
      heightFn: terrainHeight,
    ).build();
    _threeJs.scene.add(_terrain!);

    // Airplane
    _airplaneRig = three.Object3D();
    _threeJs.scene.add(_airplaneRig!);

    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final airplaneGltf = await loader.fromAsset('airplane.glb');
    _airplaneModel = airplaneGltf?.scene;

    const offsetDeg = 13.0;
    if (_airplaneModel != null) {
      _airplaneModel!.scale.setValues(0.35, 0.35, 0.35);
      _airplaneModel!.rotation.y = offsetDeg * math.pi / 180.0;
      _airplaneRig!.add(_airplaneModel!);

      _resetFlightPose();
    }

    // Balls: load once, clone many
    final ballLoader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final ballGltf = await ballLoader.fromAsset('pokeball.glb');
    _ballTemplate = ballGltf?.scene;

    if (_ballTemplate != null) {
      _ballTemplate!.scale.setValues(1.0, 1.0, 1.0);

      var r0 = GameMath.computeRadiusWorld(_ballTemplate!);
      if (!r0.isFinite || r0 <= 0.0001) r0 = 1.0;

      final s = targetBallRadius / r0;
      _ballTemplate!.scale.setValues(s, s, s);

      _ballRadius = GameMath.computeRadiusWorld(_ballTemplate!);
      debugPrint('ball radius after scale = $_ballRadius, scale=$s');

      for (int i = 0; i < ballCount; i++) {
        final b = _ballTemplate!.clone(true);
        b.frustumCulled = false;
        _threeJs.scene.add(b);
        _balls.add(b);
      }

      _scatterBallsUniformOnTerrain();
    }

    restart();

    _threeJs.addAnimationEvent(_update);
  }

  void restart() {
    state.reset();
    _resetFlightState();
    _resetFlightPose();
    _scatterBallsUniformOnTerrain();
    _startTimer();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed || state.ended) return;

      state.tick();
      if (state.timeLeft <= 0) {
        _finish(won: state.score >= state.goalScore);
      }
    });
  }

  void _finish({required bool won}) {
    if (state.ended) return;

    _timer?.cancel();
    _timer = null;
    _yawInput = 0.0;

    state.finish(won: won);
    onGameOver(won: won);
  }

  void _update(double dt) {
    if (_airplaneRig == null || _airplaneModel == null) return;
    if (state.ended) return;

    // 1) yaw from joystick
    yaw += _yawInput * yawRate * dt;

    // 2) forward vector
    final fx = math.sin(yaw);
    final fz = math.cos(yaw);
    _tmpForward.setValues(fx, 0, fz);

    // 3) move forward
    planeX += _tmpForward.x * planeSpeed * dt;
    planeZ += _tmpForward.z * planeSpeed * dt;

    // 4) wrap
    planeX = GameMath.wrap(planeX, -terrainW * 0.5, terrainW * 0.5);
    planeZ = GameMath.wrap(planeZ, -terrainH * 0.5, terrainH * 0.5);

    // 5) update rig position
    _airplaneRig!.position.setValues(planeX, flightY, planeZ);

    // 6) rig yaw via lookAt
    _tmpLookAt.setValues(
      planeX + _tmpForward.x * 15.0,
      flightY,
      planeZ + _tmpForward.z * 15.0,
    );
    _airplaneRig!.lookAt(_tmpLookAt);

    // 7) bank on model only
    final targetBank = (-_yawInput * (maxBankDeg * math.pi / 180.0));
    _bank = GameMath.lerp(_bank, targetBank, bankSmooth);
    _airplaneModel!.rotation.z = _bank;

    // 8) camera follow (manual)
    final lx = _tmpForward.z;
    final lz = -_tmpForward.x;

    _threeJs.camera.position.setValues(
      _airplaneRig!.position.x - _tmpForward.x * followBack + lx * followLeft,
      _airplaneRig!.position.y + followUp,
      _airplaneRig!.position.z - _tmpForward.z * followBack + lz * followLeft,
    );
    _threeJs.camera.lookAt(_tmpLookAt);

    // 9) collectibles: rotate + collision
    if (_balls.isNotEmpty) {
      int gained = 0;

      for (final b in _balls) {
        b.rotation.y += dt * 0.9;

        final d = GameMath.dist3(
          _airplaneRig!.position.x,
          _airplaneRig!.position.y,
          _airplaneRig!.position.z,
          b.position.x,
          b.position.y,
          b.position.z,
        );

        if (d <= pickupRadius) {
          gained += 1;
          _respawnBall(b);
        }
      }

      if (gained != 0) {
        state.addScore(gained);
        if (state.score >= state.goalScore) {
          _finish(won: true);
        }
      }
    }
  }

  // ===== Terrain height =====
  double terrainHeight(double x, double z) {
    final h1 = 18.0 * math.sin(x * 0.010) * math.cos(z * 0.010);
    final h2 = 8.0 * math.sin(x * 0.035 + 1.7) * math.cos(z * 0.030 - 0.6);
    return h1 + h2;
  }

  // ===== Balls placement =====
  bool _ballXZIsAboveGround(double x, double z) {
    final groundY = terrainHeight(x, z);
    final minCenterY = groundY + _ballRadius + ballHover + _groundEps;
    return flightY >= minCenterY;
  }

  void _scatterBallsUniformOnTerrain() {
    if (_balls.isEmpty) return;

    final cols = math.sqrt(ballCount).ceil();
    final rows = (ballCount / cols).ceil();

    final cellW = terrainW / cols;
    final cellH = terrainH / rows;

    int i = 0;
    for (int r = 0; r < rows && i < _balls.length; r++) {
      for (int c = 0; c < cols && i < _balls.length; c++) {
        final xCenter = -terrainW * 0.5 + (c + 0.5) * cellW;
        final zCenter = -terrainH * 0.5 + (r + 0.5) * cellH;

        double x = xCenter;
        double z = zCenter;

        const triesPerCell = 12;
        bool ok = false;

        for (int t = 0; t < triesPerCell; t++) {
          final rx = xCenter + GameMath.rand(_rng, -0.45 * cellW, 0.45 * cellW);
          final rz = zCenter + GameMath.rand(_rng, -0.45 * cellH, 0.45 * cellH);
          if (_ballXZIsAboveGround(rx, rz)) {
            x = rx;
            z = rz;
            ok = true;
            break;
          }
        }

        if (!ok) {
          x = xCenter;
          z = zCenter;
        }

        _balls[i].position.setValues(x, flightY, z);
        i++;
      }
    }
  }

  void _respawnBall(three.Object3D b) {
    const minFromPlane = 120.0;
    const tries = 80;

    double x = 0.0;
    double z = 0.0;
    bool found = false;

    for (int t = 0; t < tries; t++) {
      final rx = GameMath.rand(_rng, -terrainW * 0.5, terrainW * 0.5);
      final rz = GameMath.rand(_rng, -terrainH * 0.5, terrainH * 0.5);

      if (!_ballXZIsAboveGround(rx, rz)) continue;

      final d = GameMath.dist3(rx, flightY, rz, planeX, flightY, planeZ);
      if (d < minFromPlane) continue;

      x = rx;
      z = rz;
      found = true;
      break;
    }

    if (!found) {
      x = GameMath.rand(_rng, -terrainW * 0.5, terrainW * 0.5);
      z = GameMath.rand(_rng, -terrainH * 0.5, terrainH * 0.5);
    }

    b.position.setValues(x, flightY, z);
  }

  // ===== Reset flight =====
  void _resetFlightState() {
    planeX = 0.0;
    planeZ = -800.0;
    yaw = 0.0;
    _bank = 0.0;
    _yawInput = 0.0;
  }

  void _resetFlightPose() {
    if (_airplaneRig == null) return;

    _airplaneRig!.position.setValues(planeX, flightY, planeZ);
    _tmpLookAt.setValues(planeX, flightY, planeZ + 10.0);
    _airplaneRig!.lookAt(_tmpLookAt);

    if (_airplaneModel != null) {
      _airplaneModel!.rotation.z = 0.0;
    }
  }
}
