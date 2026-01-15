import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:three_js/three_js.dart' as three;

class ThreeSpaceScene extends StatefulWidget {
  const ThreeSpaceScene({super.key});

  @override
  State<ThreeSpaceScene> createState() => _ThreeSpaceSceneState();
}

class _ThreeSpaceSceneState extends State<ThreeSpaceScene> {
  late three.ThreeJS threeJs;

  three.Mesh? terrain;

  // Airplane: rig + model (rig handles yaw, model handles roll)
  three.Object3D? airplaneRig;
  three.Object3D? airplaneModel;

  // Terrain params
  final double terrainW = 2000.0;
  final double terrainH = 2000.0;
  final int terrainSegW = 240;
  final int terrainSegH = 240;

  // Flight state
  double planeX = 0.0;
  double planeZ = -800.0;
  final double flightY = 60.0; // fixed altitude

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

  // Collectibles (balls)
  int score = 0;
  three.Object3D? ballTemplate;
  final List<three.Object3D> balls = [];
  final int ballCount = 50;

  // Hover = доп.зазор над поверхностью, а не "высота центра"
  final double ballHover = 6.0;
  double _ballRadius = 0.0; // вычисляем из модели
  final double _groundEps = 0.5;

  final double pickupRadius = 28.0; // collision distance threshold
  final _rng = math.Random();

  // temps
  final three.Vector3 _tmpForward = three.Vector3(0, 0, 1);
  final three.Vector3 _tmpLookAt = three.Vector3(0, 0, 0);

  // ===== Challenge: 30 balls / 60 seconds =====
  static const int goalScore = 10;
  static const int totalSeconds = 60;

  int timeLeft = totalSeconds;
  Timer? _gameTimer;

  bool _gameEnded = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: setup,
    );
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          threeJs.build(),

          // Score HUD
          Positioned(
            left: 20,
            top: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black54,
              child: Text(
                'Score: $score / $goalScore',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

          // Timer HUD
          Positioned(
            left: 20,
            top: 85,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black54,
              child: Text(
                'Time: ${timeLeft.clamp(0, totalSeconds)}s',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
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
                  if (_gameEnded) {
                    _yawInput = 0.0;
                    return;
                  }
                  _yawInput = -details.x; // [-1..1]
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Timer / Game end =====
  void _startChallenge() {
    _gameTimer?.cancel();
    _gameEnded = false;
    _dialogShown = false;

    setState(() {
      score = 0;
      timeLeft = totalSeconds;
    });

    // Optional: re-scatter balls on restart
    _scatterBallsUniformOnTerrain();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameEnded) return;

      setState(() => timeLeft -= 1);

      if (timeLeft <= 0) {
        _finishChallenge(won: score >= goalScore);
      }
    });
  }

  void _finishChallenge({required bool won}) {
    if (_gameEnded) return;
    _gameEnded = true;

    _gameTimer?.cancel();
    _gameTimer = null;
    _yawInput = 0.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogShown) return;
      _dialogShown = true;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text(won ? 'Победа!' : 'Время вышло'),
            content: Text(
              'Собрано: $score / $goalScore\n'
                  'Осталось времени: ${timeLeft.clamp(0, totalSeconds)} c',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _startChallenge();
                },
                child: const Text('Заново'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          );
        },
      );
    });
  }

  double terrainHeight(double x, double z) {
    final h1 = 18.0 * math.sin(x * 0.010) * math.cos(z * 0.010);
    final h2 = 8.0 * math.sin(x * 0.035 + 1.7) * math.cos(z * 0.030 - 0.6);
    return h1 + h2;
  }

  three.Mesh buildTerrain() {
    final geo = three.PlaneGeometry(terrainW, terrainH, terrainSegW, terrainSegH);
    geo.rotateX(-math.pi / 2);

    final pos = geo.getAttribute(three.Attribute.position) as three.BufferAttribute;

    for (int i = 0; i < pos.count; i++) {
      final x = (pos.getX(i) ?? 0).toDouble();
      final z = (pos.getZ(i) ?? 0).toDouble();
      pos.setY(i, terrainHeight(x, z));
    }

    pos.needsUpdate = true;
    geo.computeVertexNormals();
    geo.computeBoundingBox();
    geo.computeBoundingSphere();

    final mat = three.MeshStandardMaterial.fromMap({
      'color': 0x2ECC71,
      'roughness': 1.0,
      'metalness': 0.0,
      'side': three.DoubleSide,
    });

    final mesh = three.Mesh(geo, mat);

    // If terrain disappears sometimes, disable frustum culling
    mesh.frustumCulled = false;

    return mesh;
  }

  double _wrap(double v, double min, double max) {
    final range = max - min;
    if (range <= 0) return min;
    while (v < min) v += range;
    while (v > max) v -= range;
    return v;
  }

  final double targetBallRadius = 10.0;

  double _computeRadiusWorld(three.Object3D obj) {
    obj.updateMatrixWorld(true);

    final bb = three.BoundingBox().setFromObject(obj, true);
    final bs = three.BoundingSphere();
    bb.getBoundingSphere(bs);
    return bs.radius;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _rand(double a, double b) => a + (b - a) * _rng.nextDouble();

  double _dist3(double ax, double ay, double az, double bx, double by, double bz) {
    final dx = ax - bx;
    final dy = ay - by;
    final dz = az - bz;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Равномерная раскладка по террейну:
  /// - делим тайл на grid-ячейки
  /// - в каждой ячейке берём случайную точку (jitter)
  /// - ставим шар на высоту полёта (как самолёт), но только если он не пересечёт террейн
  void _scatterBallsUniformOnTerrain() {
    if (balls.isEmpty) return;

    final cols = math.sqrt(ballCount).ceil();
    final rows = (ballCount / cols).ceil();

    final cellW = terrainW / cols;
    final cellH = terrainH / rows;

    int i = 0;
    for (int r = 0; r < rows && i < balls.length; r++) {
      for (int c = 0; c < cols && i < balls.length; c++) {
        final xCenter = -terrainW * 0.5 + (c + 0.5) * cellW;
        final zCenter = -terrainH * 0.5 + (r + 0.5) * cellH;

        double x = xCenter;
        double z = zCenter;

        const triesPerCell = 12;
        bool ok = false;

        for (int t = 0; t < triesPerCell; t++) {
          final rx = xCenter + _rand(-0.45 * cellW, 0.45 * cellW);
          final rz = zCenter + _rand(-0.45 * cellH, 0.45 * cellH);
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

        final y = flightY; // Y совпадает с самолётом
        balls[i].position.setValues(x, y, z);
        i++;
      }
    }
  }

  bool _ballXZIsAboveGround(double x, double z) {
    // хотим, чтобы низ шара был выше поверхности (или хотя бы не ниже)
    final groundY = terrainHeight(x, z);
    final minCenterY = groundY + _ballRadius + ballHover + _groundEps;
    return flightY >= minCenterY;
  }

  /// Респавн равномерно по всему тайлу (а не "впереди самолёта"),
  /// плюс пытаемся не спавнить слишком близко к самолёту.
  void _respawnBall(three.Object3D b) {
    const minFromPlane = 120.0;
    const tries = 80;

    double x = 0.0;
    double z = 0.0;
    bool found = false;

    for (int t = 0; t < tries; t++) {
      final rx = _rand(-terrainW * 0.5, terrainW * 0.5);
      final rz = _rand(-terrainH * 0.5, terrainH * 0.5);

      if (!_ballXZIsAboveGround(rx, rz)) continue;

      final d = _dist3(rx, flightY, rz, planeX, flightY, planeZ);
      if (d < minFromPlane) continue;

      x = rx;
      z = rz;
      found = true;
      break;
    }

    if (!found) {
      // fallback — просто куда-то в тайл
      x = _rand(-terrainW * 0.5, terrainW * 0.5);
      z = _rand(-terrainH * 0.5, terrainH * 0.5);
    }

    b.position.setValues(x, flightY, z);
  }

  Future<void> setup() async {
    // Camera
    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      1,
      4000,
    );
    threeJs.camera.up.setValues(0, 1, 0);

    // Scene
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x4A90E2);

    // Light
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.55));
    final sun = three.DirectionalLight(0xffffff, 1.2);
    sun.position.setValues(300, 600, 200);
    threeJs.scene.add(sun);

    // Terrain
    terrain = buildTerrain();
    threeJs.scene.add(terrain!);

    // Airplane
    airplaneRig = three.Object3D();
    threeJs.scene.add(airplaneRig!);

    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final airplaneGltf = await loader.fromAsset('airplane.glb');
    airplaneModel = airplaneGltf?.scene;
    const offsetDeg = 13.0;

    if (airplaneModel != null) {
      airplaneModel!.scale.setValues(0.35, 0.35, 0.35);
      airplaneModel!.rotation.y = offsetDeg * math.pi / 180.0;
      airplaneRig!.add(airplaneModel!);

      airplaneRig!.position.setValues(planeX, flightY, planeZ);

      _tmpLookAt.setValues(planeX, flightY, planeZ + 10.0);
      airplaneRig!.lookAt(_tmpLookAt);
    }

    // Balls: load once, clone many
    final ballLoader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final ballGltf = await ballLoader.fromAsset('pokeball.glb');
    ballTemplate = ballGltf?.scene;

    if (ballTemplate != null) {
      // 1) reset scale, to measure "native" radius
      ballTemplate!.scale.setValues(1.0, 1.0, 1.0);

      // 2) measure current radius
      var r0 = _computeRadiusWorld(ballTemplate!);
      if (!r0.isFinite || r0 <= 0.0001) r0 = 1.0;

      // 3) scale to target radius
      final s = targetBallRadius / r0;
      ballTemplate!.scale.setValues(s, s, s);

      // 4) store real world radius after scaling
      _ballRadius = _computeRadiusWorld(ballTemplate!);

      debugPrint('ball radius after scale = $_ballRadius, scale=$s');

      // 5) clone
      for (int i = 0; i < ballCount; i++) {
        final b = ballTemplate!.clone(true);
        b.frustumCulled = false;
        threeJs.scene.add(b);
        balls.add(b);
      }

      // 6) scatter on terrain
      _scatterBallsUniformOnTerrain();
    }

    // Start challenge AFTER scene is ready
    _startChallenge();

    // Animation
    threeJs.addAnimationEvent((dt) {
      if (airplaneRig == null || airplaneModel == null) return;
      if (_gameEnded) return;

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
      planeX = _wrap(planeX, -terrainW * 0.5, terrainW * 0.5);
      planeZ = _wrap(planeZ, -terrainH * 0.5, terrainH * 0.5);

      // 5) update rig position
      airplaneRig!.position.setValues(planeX, flightY, planeZ);

      // 6) rig yaw via lookAt
      _tmpLookAt.setValues(
        planeX + _tmpForward.x * 15.0,
        flightY,
        planeZ + _tmpForward.z * 15.0,
      );
      airplaneRig!.lookAt(_tmpLookAt);

      // 7) bank on model only
      final targetBank = (-_yawInput * (maxBankDeg * math.pi / 180.0));
      _bank = _lerp(_bank, targetBank, bankSmooth);
      airplaneModel!.rotation.z = _bank;

      // 8) camera follow (manual)
      final lx = _tmpForward.z;
      final lz = -_tmpForward.x;

      threeJs.camera.position.setValues(
        airplaneRig!.position.x - _tmpForward.x * followBack + lx * followLeft,
        airplaneRig!.position.y + followUp,
        airplaneRig!.position.z - _tmpForward.z * followBack + lz * followLeft,
      );
      threeJs.camera.lookAt(_tmpLookAt);

      // 9) collectibles: rotate + collision by distance
      if (balls.isNotEmpty) {
        int gained = 0;

        for (final b in balls) {
          b.rotation.y += dt * 0.9;

          final d = _dist3(
            airplaneRig!.position.x,
            airplaneRig!.position.y,
            airplaneRig!.position.z,
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
          setState(() => score += gained);

          if (score >= goalScore) {
            _finishChallenge(won: true);
          }
        }
      }
    });
  }
}
