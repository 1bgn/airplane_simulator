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

  final three.Object3D earthPivot = three.Object3D();
  three.Object3D? earthRoot;
  three.Object3D? plane;

  // Debug
  double _dbgAcc = 0.0;

  final three.Vector3 planetCenter = three.Vector3(0, 0, 0);

  final double planetRadius = 380.0;
  final double altitude = 120.0;

  // Great-circle orbit axis (normal of orbit plane).
  // X axis => orbit plane is YZ, so you pass through north/south poles.
  final three.Vector3 orbitAxis = three.Vector3(1, 0, 0);

  // Vector from center to plane (rotated around orbitAxis each frame)
  final three.Vector3 posVec = three.Vector3(0, 1, 0);

  double orbitAngularSpeed = 0.8;

  // Plane visuals
  double planeBank = 0.0;

  // Camera follow
  final double cameraDistance = 240.0;
  final double cameraHeight = 60.0;
  final double follow = 0.12;
  final double lookAhead = 80.0;

  // Earth spin
  double earthSpin = 0.0;

  // Temps
  final three.Quaternion _q = three.Quaternion();
  final three.Vector3 _up = three.Vector3(0, 1, 0);
  final three.Vector3 _posNext = three.Vector3(0, 0, 0);
  final three.Vector3 _target = three.Vector3(0, 0, 0);

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

    earthPivot.position.setValues(planetCenter.x, planetCenter.y, planetCenter.z);
    threeJs.scene.add(earthPivot);

    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');

    final earthGLB = await loader.fromAsset('earth.glb');
    if (earthGLB == null) return;
    earthRoot = earthGLB.scene;
    earthRoot!.traverse((o) => o.frustumCulled = false);

    final center = three.Vector3(0, 0, 0);
    final bbox = three.BoundingBox().setFromObject(earthRoot!);
    bbox.getCenter(center);
    earthRoot!.position.setValues(-center.x, -center.y, -center.z);
    earthPivot.add(earthRoot!);

    final planeGLB = await loader.fromAsset('airplane.glb');
    if (planeGLB == null) return;
    plane = planeGLB.scene;
    plane!.scale.setValues(1, 1, 1);
    threeJs.scene.add(plane!);

    // init posVec length = R + alt (manual multiplyScalar)
    posVec.normalize();
    final r = planetRadius + altitude;
    posVec.x *= r;
    posVec.y *= r;
    posVec.z *= r;

    _applyTransforms(0.0);
    _snapCamera();

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

  void _applyTransforms(double dt) {
    final p = plane;
    if (p == null) return;

    // Position
    p.position.setValues(
      planetCenter.x + posVec.x,
      planetCenter.y + posVec.y,
      planetCenter.z + posVec.z,
    );

    // Up = radial
    _up.setValues(posVec.x, posVec.y, posVec.z);
    _up.normalize();

    // Compute a stable "where we will be next", then look at that point.
    // This avoids lookAt flipping near poles because direction is derived from motion, not from cross-products. [web:44][web:67]
    _posNext.setValues(posVec.x, posVec.y, posVec.z);
    final dAng = orbitAngularSpeed * (dt > 0 ? dt : 1 / 60.0);
    _q.setFromAxisAngle(orbitAxis, dAng);
    _posNext.applyQuaternion(_q);

    _target.setValues(
      planetCenter.x + _posNext.x,
      planetCenter.y + _posNext.y,
      planetCenter.z + _posNext.z,
    );

    p.up.setValues(_up.x, _up.y, _up.z);
    p.lookAt(_target);

    // Visual bank (roll)
    p.rotation.z = -planeBank;
  }

  void _snapCamera() {
    final p = plane;
    if (p == null) return;

    // Approx forward: towards target computed from next position
    final fx = _target.x - p.position.x;
    final fy = _target.y - p.position.y;
    final fz = _target.z - p.position.z;
    final fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    final fdx = fl < 1e-6 ? 0.0 : fx / fl;
    final fdy = fl < 1e-6 ? 0.0 : fy / fl;
    final fdz = fl < 1e-6 ? 1.0 : fz / fl;

    threeJs.camera.position.setValues(
      p.position.x - fdx * cameraDistance,
      p.position.y + cameraHeight,
      p.position.z - fdz * cameraDistance,
    );

    threeJs.camera.lookAt(
      three.Vector3(
        p.position.x + fdx * lookAhead,
        p.position.y + fdy * lookAhead,
        p.position.z + fdz * lookAhead,
      ),
    );
  }

  void _update(double dt) {
    double x = 0.0;
    double y = 0.0;
    if (joystick != null && joystick!.isMoving) {
      final a = joystick!.radians;
      final i = joystick!.intensity.clamp(0.0, 1.0);
      x = math.cos(a) * i;
      y = math.sin(a) * i;
    }

    // Speed along orbit (x)
    orbitAngularSpeed = 0.8 + x * 1.6;

    // Optional: tilt orbit axis a bit (y) BUT keep ability to pass through poles:
    // rotate axis around Z; small effect, safe.
    if (y.abs() > 1e-4) {
      final tilt = (-y) * 0.6 * dt;
      _q.setFromAxisAngle(three.Vector3(0, 0, 1), tilt);
      orbitAxis.applyQuaternion(_q);
      orbitAxis.normalize();
    }

    // Advance position vector around orbit axis. [web:67]
    final dAng = orbitAngularSpeed * dt;
    _q.setFromAxisAngle(orbitAxis, dAng);
    posVec.applyQuaternion(_q);

    // Keep exact radius (manual multiplyScalar)
    posVec.normalize();
    final r = planetRadius + altitude;
    posVec.x *= r;
    posVec.y *= r;
    posVec.z *= r;

    // Bank visuals from x
    planeBank = (planeBank + (x * 0.9 - planeBank) * 0.10).clamp(-0.7, 0.7);

    _applyTransforms(dt);

    // Camera follow (same motion-derived forward)
    final p = plane;
    if (p != null) {
      final fx = _target.x - p.position.x;
      final fy = _target.y - p.position.y;
      final fz = _target.z - p.position.z;
      final fl = math.sqrt(fx * fx + fy * fy + fz * fz);
      final fdx = fl < 1e-6 ? 0.0 : fx / fl;
      final fdy = fl < 1e-6 ? 0.0 : fy / fl;
      final fdz = fl < 1e-6 ? 1.0 : fz / fl;

      final desiredX = p.position.x - fdx * cameraDistance;
      final desiredZ = p.position.z - fdz * cameraDistance;
      final desiredY = p.position.y + cameraHeight;

      threeJs.camera.position.x += (desiredX - threeJs.camera.position.x) * follow;
      threeJs.camera.position.y += (desiredY - threeJs.camera.position.y) * follow;
      threeJs.camera.position.z += (desiredZ - threeJs.camera.position.z) * follow;

      threeJs.camera.lookAt(
        three.Vector3(
          p.position.x + fdx * lookAhead,
          p.position.y + fdy * lookAhead,
          p.position.z + fdz * lookAhead,
        ),
      );
    }

    // Earth spin
    earthSpin += 0.15 * dt;
    earthPivot.rotation.y = earthSpin;

    _dbgAcc += dt;
    if (_dbgAcc >= 1.0) {
      _dbgAcc = 0.0;
      final dist = math.sqrt(posVec.x * posVec.x + posVec.y * posVec.y + posVec.z * posVec.z);
      debugPrint('dist=${dist.toStringAsFixed(1)} target=${(planetRadius + altitude).toStringAsFixed(1)} axis=(${orbitAxis.x.toStringAsFixed(2)},${orbitAxis.y.toStringAsFixed(2)},${orbitAxis.z.toStringAsFixed(2)})');
    }
  }
}
