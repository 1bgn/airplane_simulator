import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

class ThreeSpaceScene extends StatefulWidget {
  const ThreeSpaceScene({super.key});

  @override
  State<ThreeSpaceScene> createState() => _ThreeSpaceSceneState();
}

class _ThreeSpaceSceneState extends State<ThreeSpaceScene> {
  late three.ThreeJS threeJs;
  three.Joystick? joystick;

  three.Object3D? earthRoot; // earth.glb may contain multiple objects
  three.Object3D? plane;

  // Debug
  double _dbgAcc = 0.0;

  // Flight
  double yaw = 0.0;
  double pitchVisual = 0.0;

  // Tunables
  final double speed = 25.0;      // units/sec
  final double planeBaseY = 35.0; // constant altitude
  final double yawSpeed = 1.6;    // rad/sec per joystick x
  final double pitchSpeed = 1.0;  // rad/sec per joystick y

  // Camera (chase)
  final double cameraDistance = 220.0;
  final double cameraHeight = 55.0;
  final double lookAhead = 80.0;
  final double follow = 0.10;

  // Earth follows plane on X/Z, but stays low on Y
  final double earthFixedY = -220.0;
  final double earthAhead = 520.0; // always ahead of plane
  final double earthScale = 80.0;

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
    threeJs.dispose();
    three.loading.clear();
    joystick?.dispose();
    super.dispose();
  }
  void _normalizeObjectToSize(three.Object3D obj, double targetSize) {
    // Box3.setFromObject traverses children and computes overall bounds. [web:160]
    final box = three.BoundingBox().setFromObject(obj);
    final size = three.Vector3(0, 0, 0);
    box.getSize(size);

    final maxDim = math.max(size.x, math.max(size.y, size.z));
    if (maxDim <= 0) return;

    final s = targetSize / maxDim;
    obj.scale.x *= s;
    obj.scale.y *= s;
    obj.scale.z *= s;
  }
  @override
  Widget build(BuildContext context) => threeJs.build();

  Future<void> setup() async {
    joystick = threeJs.width < 850
        ? three.Joystick(
      size: 150,
      margin: const EdgeInsets.only(left: 35, bottom: 35),
      screenSize: Size(threeJs.width, threeJs.height),
      listenableKey: threeJs.globalKey,
    )
        : null;

    // Camera
    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      0.1,
      5000,
    );

    // Scene
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x000010);

    // Lights
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.75));
    final sun = three.DirectionalLight(0xffffff, 1.1);
    sun.position.setValues(50, 80, 30);
    threeJs.scene.add(sun);

    // Loader
    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/'); // [web:145]

    // Earth
    final earthGLB = await loader.fromAsset('earth.glb');
    if (earthGLB == null) {
      debugPrint('earth.glb not loaded (check pubspec.yaml assets)');
      return;
    }
    earthRoot = earthGLB.scene;
    earthRoot!.scale.setValues(earthScale, earthScale, earthScale);

    // Helps with multi-object scenes that may get culled due to odd bounds. [web:160]
    earthRoot!.traverse((obj) {
      obj.frustumCulled = false;
    });
    _normalizeObjectToSize(earthRoot!, 400);
    threeJs.scene.add(earthRoot!);

    // Plane
    final planeGLB = await loader.fromAsset('airplane.glb');
    if (planeGLB == null) {
      debugPrint('airplane.glb not loaded (check pubspec.yaml assets)');
      return;
    }
    plane = planeGLB.scene;
    plane!.position.setValues(0, planeBaseY, 0);
    plane!.scale.setValues(1, 1, 1);
    threeJs.scene.add(plane!);

    // Initial placements so Earth is visible immediately
    earthRoot!.position.setValues(
      plane!.position.x,
      earthFixedY,
      plane!.position.z + earthAhead,
    );

    // Initial camera behind plane (plane forward is +Z)
    final forward0 = three.Vector3(0, 0, 1);
    threeJs.camera.position.setValues(
      plane!.position.x - forward0.x * cameraDistance,
      plane!.position.y + cameraHeight,
      plane!.position.z - forward0.z * cameraDistance,
    );
    threeJs.camera.lookAt(plane!.position);

    // Joystick overlay like example
    threeJs.renderer?.autoClear = false;
    if (joystick != null) {
      threeJs.postProcessor = ([double? dt]) {
        threeJs.renderer!.setViewport(0, 0, threeJs.width, threeJs.height);
        threeJs.renderer!.clear();
        threeJs.renderer!.render(threeJs.scene, threeJs.camera);
        threeJs.renderer!.clearDepth();
        threeJs.renderer!.render(joystick!.scene, joystick!.camera);
      };
    }

    // Animation loop
    threeJs.addAnimationEvent((dt) {
      joystick?.update();
      _update(dt);
    });
  }

  void _update(double dt) {
    final p = plane;
    if (p == null) return;

    // Joystick polar -> x/y
    double x = 0.0;
    double y = 0.0;
    if (joystick != null && joystick!.isMoving) {
      final a = joystick!.radians;
      final i = joystick!.intensity.clamp(0.0, 1.0);
      x = math.cos(a) * i;
      y = math.sin(a) * i;
    }

    // Update yaw + visual pitch (no altitude change)
    yaw += x * yawSpeed * dt;
    pitchVisual = (pitchVisual + (-y) * pitchSpeed * dt).clamp(-0.6, 0.6);

    p.rotation.y = yaw;
    p.rotation.x = pitchVisual;
    p.rotation.z = 0;

    // Forward direction on X/Z plane only
    final forward = three.Vector3(0, 0, 1);
    forward.applyEuler(three.Euler(0, yaw, 0));

    // Move plane forward + keep constant altitude
    p.position.x += forward.x * speed * dt;
    p.position.z += forward.z * speed * dt;
    p.position.y = planeBaseY;

    // Earth follows plane on X/Z (fixed Y), stays ahead so it’s in view
    final e = earthRoot;
    if (e != null) {
      e.position.x = p.position.x;
      e.position.y = earthFixedY;
      e.position.z = p.position.z + earthAhead;
      e.rotation.y += 0.05 * dt;
    }

    // Camera behind plane
    final desiredX = p.position.x - forward.x * cameraDistance;
    final desiredY = p.position.y + cameraHeight;
    final desiredZ = p.position.z - forward.z * cameraDistance;

    threeJs.camera.position.x += (desiredX - threeJs.camera.position.x) * follow;
    threeJs.camera.position.y += (desiredY - threeJs.camera.position.y) * follow;
    threeJs.camera.position.z += (desiredZ - threeJs.camera.position.z) * follow;

    // Look ahead (so Earth ahead is also likely visible)
    threeJs.camera.lookAt(
      three.Vector3(
        p.position.x + forward.x * lookAhead,
        p.position.y,
        p.position.z + forward.z * lookAhead,
      ),
    );

    // Debug logs 1/sec
    _dbgAcc += dt;
    if (_dbgAcc >= 1.0) {
      _dbgAcc = 0.0;

      debugPrint(
        'plane pos: x=${p.position.x.toStringAsFixed(1)} '
            'y=${p.position.y.toStringAsFixed(1)} '
            'z=${p.position.z.toStringAsFixed(1)}',
      );

      final er = earthRoot;
      if (er != null) {
        debugPrint(
          'earth pos: x=${er.position.x.toStringAsFixed(1)} '
              'y=${er.position.y.toStringAsFixed(1)} '
              'z=${er.position.z.toStringAsFixed(1)}',
        );
      }

      debugPrint(
        'camera pos: x=${threeJs.camera.position.x.toStringAsFixed(1)} '
            'y=${threeJs.camera.position.y.toStringAsFixed(1)} '
            'z=${threeJs.camera.position.z.toStringAsFixed(1)}',
      );
    }
  }
}
