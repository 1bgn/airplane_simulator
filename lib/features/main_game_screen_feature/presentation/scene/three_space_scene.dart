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

  // Earth: use a pivot so we can re-center the model without losing world position
  final three.Object3D earthPivot = three.Object3D();
  three.Object3D? earthRoot; // loaded glTF scene (multi-object)

  three.Object3D? plane;

  // Debug
  double _dbgAcc = 0.0;

  // Planet center is the pivot's world position
  final three.Vector3 planetCenter = three.Vector3(0, 0, 0);

  // Orbit parameters
  final double orbitRadius = 380.0; // подгони под размер планеты
  final double altitude = 120.0;    // фикс высота над центром (Y)
  double orbitAngle = 0.0;
  double orbitAngularSpeed = 0.35;

  // Plane visuals
  double planeBank = 0.0;

  // Camera control (pitch only)
  double camPitch = 0.25;
  final double camPitchMin = -0.2;
  final double camPitchMax = 0.9;

  // Camera follow tuning
  final double cameraDistance = 240.0;
  final double cameraHeight = 60.0;
  final double follow = 0.12;
  final double lookAhead = 60.0;

  // Earth spin
  double earthSpin = 0.0;

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

    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      0.1,
      8000,
    );

    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x000010);

    threeJs.scene.add(three.AmbientLight(0xffffff, 0.75));
    final sun = three.DirectionalLight(0xffffff, 1.1);
    sun.position.setValues(50, 80, 30);
    threeJs.scene.add(sun);

    // Put planet pivot at world origin (the orbit center)
    earthPivot.position.setValues(planetCenter.x, planetCenter.y, planetCenter.z);
    threeJs.scene.add(earthPivot);

    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');

    // ---- Earth ----
    final earthGLB = await loader.fromAsset('earth.glb');
    if (earthGLB == null) {
      debugPrint('earth.glb not loaded');
      return;
    }

    earthRoot = earthGLB.scene;

    // Disable culling for all children (robustness for multi-object scenes). [web:160]
    earthRoot!.traverse((o) => o.frustumCulled = false);

    // Compute geo center and re-center INSIDE the pivot. [web:160]
    final center = three.Vector3(0, 0, 0);
    final bbox = three.BoundingBox().setFromObject(earthRoot!);
    bbox.getCenter(center);

    // Important: re-center by shifting the loaded root inside pivot,
    // NOT by setting earthRoot.position afterwards.
    earthRoot!.position.setValues(-center.x, -center.y, -center.z);

    // Attach to pivot
    earthPivot.add(earthRoot!);

    // ---- Plane ----
    final planeGLB = await loader.fromAsset('airplane.glb');
    if (planeGLB == null) {
      debugPrint('airplane.glb not loaded');
      return;
    }
    plane = planeGLB.scene;
    plane!.scale.setValues(1, 1, 1);
    threeJs.scene.add(plane!);

    // Start
    _setPlaneOnOrbit();
    _snapCamera();

    // Joystick overlay
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

    threeJs.addAnimationEvent((dt) {
      joystick?.update();
      _update(dt);
    });
  }

  void _setPlaneOnOrbit() {
    final p = plane;
    if (p == null) return;

    final x = planetCenter.x + math.cos(orbitAngle) * orbitRadius;
    final z = planetCenter.z + math.sin(orbitAngle) * orbitRadius;
    final y = planetCenter.y + altitude;

    p.position.setValues(x, y, z);
  }

  three.Vector3 _orbitTangentForward() {
    final tx = -math.sin(orbitAngle);
    final tz = math.cos(orbitAngle);
    final v = three.Vector3(tx, 0, tz);

    final len = math.sqrt(v.x * v.x + v.z * v.z);
    if (len > 1e-6) {
      v.x /= len;
      v.z /= len;
    }
    return v;
  }

  void _snapCamera() {
    final p = plane;
    if (p == null) return;

    final forward = _orbitTangentForward();

    threeJs.camera.position.setValues(
      p.position.x - forward.x * cameraDistance,
      p.position.y + cameraHeight,
      p.position.z - forward.z * cameraDistance,
    );

    threeJs.camera.lookAt(
      three.Vector3(
        p.position.x + forward.x * lookAhead,
        p.position.y + math.tan(camPitch) * 30.0,
        p.position.z + forward.z * lookAhead,
      ),
    );
  }

  void _update(double dt) {
    // Joystick -> x/y
    double x = 0.0;
    double y = 0.0;
    if (joystick != null && joystick!.isMoving) {
      final a = joystick!.radians;
      final i = joystick!.intensity.clamp(0.0, 1.0);
      x = math.cos(a) * i;
      y = math.sin(a) * i;
    }

    // X: turn/orbit speed (left/right)
    orbitAngularSpeed = 0.35 + (x * 0.9);
    orbitAngle += orbitAngularSpeed * dt;

    // Y: camera pitch only
    camPitch = (camPitch + (-y) * 0.9 * dt).clamp(camPitchMin, camPitchMax);

    // Plane position on orbit
    _setPlaneOnOrbit();

    final p = plane;
    if (p != null) {
      // Plane oriented along tangent
      final forward = _orbitTangentForward();
      final yaw = math.atan2(forward.x, forward.z);
      p.rotation.y = yaw;

      // bank for visuals
      planeBank = (planeBank + (x * 1.2 - planeBank) * 0.08).clamp(-0.6, 0.6);
      p.rotation.z = -planeBank;
      p.rotation.x = 0;
    }

    // Camera follow
    if (p != null) {
      final forward = _orbitTangentForward();

      final desiredX = p.position.x - forward.x * cameraDistance;
      final desiredZ = p.position.z - forward.z * cameraDistance;
      final desiredY = p.position.y + cameraHeight;

      threeJs.camera.position.x += (desiredX - threeJs.camera.position.x) * follow;
      threeJs.camera.position.y += (desiredY - threeJs.camera.position.y) * follow;
      threeJs.camera.position.z += (desiredZ - threeJs.camera.position.z) * follow;

      threeJs.camera.lookAt(
        three.Vector3(
          p.position.x + forward.x * lookAhead,
          p.position.y + math.tan(camPitch) * 30.0,
          p.position.z + forward.z * lookAhead,
        ),
      );
    }

    // Earth spin (rotate the pivot, keeps center stable)
    earthSpin += 0.15 * dt;
    earthPivot.rotation.y = earthSpin;

    // Logs 1/sec
    _dbgAcc += dt;
    if (_dbgAcc >= 1.0) {
      _dbgAcc = 0.0;
      final p = plane;
      if (p != null) {
        debugPrint(
          'plane pos: x=${p.position.x.toStringAsFixed(1)} y=${p.position.y.toStringAsFixed(1)} z=${p.position.z.toStringAsFixed(1)} '
              'orbitAngle=${orbitAngle.toStringAsFixed(2)} speed=${orbitAngularSpeed.toStringAsFixed(2)} camPitch=${camPitch.toStringAsFixed(2)}',
        );
      }
      debugPrint(
        'planetCenter: x=${planetCenter.x.toStringAsFixed(1)} y=${planetCenter.y.toStringAsFixed(1)} z=${planetCenter.z.toStringAsFixed(1)}',
      );
      debugPrint(
        'camera pos: x=${threeJs.camera.position.x.toStringAsFixed(1)} y=${threeJs.camera.position.y.toStringAsFixed(1)} z=${threeJs.camera.position.z.toStringAsFixed(1)}',
      );
    }
  }
}
