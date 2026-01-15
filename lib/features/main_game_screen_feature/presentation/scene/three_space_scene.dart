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
  final three.Vector3 _fwd = three.Vector3(0, 0, 1);
  final three.Vector3 _right = three.Vector3(1, 0, 0);
  final three.Vector3 _camPos = three.Vector3(0, 0, 0);
  final three.Object3D earthPivot = three.Object3D();
  three.Object3D? earthRoot;
  three.Object3D? plane;

  double _dbgAcc = 0.0;

  final three.Vector3 planetCenter = three.Vector3(0, 0, 0);

  final double planetRadius = 380.0;
  final double altitude = 120.0;

  // Great-circle orbit axis (normal of orbit plane). X => проход через полюса.
  final three.Vector3 orbitAxis = three.Vector3(1, 0, 0);

  // Vector from center to plane
  final three.Vector3 posVec = three.Vector3(0, 1, 0);

  double orbitAngularSpeed = 0.25;

  // Plane visuals
  double planeBank = 0.0;

  // Camera (fixed relative to plane, horizon fixed to world)
  final double cameraDistance = 240.0;
  final double cameraHeight = 60.0;
  final double lookAhead = 80.0;

  // Camera pitch
  double camPitch = 0.0;
  final double camPitchMin = -0.35;
  final double camPitchMax = 0.35;
  final double camPitchSpeed = 0.9;

  // Earth spin
  double earthSpin = 0.0;

  // Temps
  final three.Quaternion _q = three.Quaternion();
  final three.Vector3 _upPlane = three.Vector3(0, 1, 0);
  final three.Vector3 _posNext = three.Vector3(0, 0, 0);
  final three.Vector3 _targetPlane = three.Vector3(0, 0, 0);

  // Reused vectors (no allocations each frame)
  final three.Vector3 _lookAtCam = three.Vector3(0, 0, 0);

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

    // Fixed horizon for camera lookAt. [web:19]
    threeJs.camera.up.setValues(0, 1, 0);

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

    // init radius
    posVec.normalize();
    final r = planetRadius + altitude;
    posVec.x *= r;
    posVec.y *= r;
    posVec.z *= r;

    // initial transforms and camera
    _applyPlaneTransform(1 / 60.0);
    _updateCameraFixed();

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

  void _applyPlaneTransform(double dt) {
    final p = plane;
    if (p == null) return;

    // Position
    p.position.setValues(
      planetCenter.x + posVec.x,
      planetCenter.y + posVec.y,
      planetCenter.z + posVec.z,
    );

    // Plane up = radial
    _upPlane.setValues(posVec.x, posVec.y, posVec.z);
    _upPlane.normalize();

    // Target = next position (direction of motion) for stable heading at poles. [web:44]
    _posNext.setValues(posVec.x, posVec.y, posVec.z);
    final dAngNext = orbitAngularSpeed * (dt > 0 ? dt : 1 / 60.0);
    _q.setFromAxisAngle(orbitAxis, dAngNext);
    _posNext.applyQuaternion(_q);

    _targetPlane.setValues(
      planetCenter.x + _posNext.x,
      planetCenter.y + _posNext.y,
      planetCenter.z + _posNext.z,
    );

    p.up.setValues(_upPlane.x, _upPlane.y, _upPlane.z);
    p.lookAt(_targetPlane);

    // bank
    p.rotation.z = -planeBank;
  }


  void _addScaled(three.Vector3 out, three.Vector3 v, double s) {
    out.x += v.x * s;
    out.y += v.y * s;
    out.z += v.z * s;
  }

  void _crossInto(three.Vector3 out, three.Vector3 a, three.Vector3 b) {
    final ax = a.x, ay = a.y, az = a.z;
    final bx = b.x, by = b.y, bz = b.z;
    out.x = ay * bz - az * by;
    out.y = az * bx - ax * bz;
    out.z = ax * by - ay * bx;
  }
  void _updateCameraFixed() {
    final p = plane;
    if (p == null) return;

    // 1) up = радиальный "вверх" от центра планеты
    _upPlane.setValues(posVec.x, posVec.y, posVec.z);
    _upPlane.normalize();

    // 2) forward = касательная (направление движения)
    _fwd.setValues(
      _targetPlane.x - p.position.x,
      _targetPlane.y - p.position.y,
      _targetPlane.z - p.position.z,
    );
    _fwd.normalize();

    // 3) right = forward x up
    _crossInto(_right, _fwd, _upPlane);
    final rl = math.sqrt(_right.x * _right.x + _right.y * _right.y + _right.z * _right.z);
    if (rl < 1e-6) {
      // редкий вырожденный случай: если вдруг forward || up, просто не обновляем камеру
      return;
    }
    _right.x /= rl; _right.y /= rl; _right.z /= rl;

    // 4) re-orthogonalize forward = up x right
    _crossInto(_fwd, _upPlane, _right);
    _fwd.normalize();

    // 5) camera position: позади и выше в базисе (forward/up), а не по world Y
    _camPos.setValues(p.position.x, p.position.y, p.position.z);
    _addScaled(_camPos, _fwd, -cameraDistance);
    _addScaled(_camPos, _upPlane, cameraHeight);

    threeJs.camera.position.setValues(_camPos.x, _camPos.y, _camPos.z);

    // 6) lookAt: вперёд + небольшой pitch по локальному up
    final pitchUp = math.tan(camPitch) * 50.0;

    _lookAtCam.setValues(p.position.x, p.position.y, p.position.z);
    _addScaled(_lookAtCam, _fwd, lookAhead);
    _addScaled(_lookAtCam, _upPlane, pitchUp);

    // Вариант A: “горизонт фиксирован в мире”
    threeJs.camera.up.setValues(0, 1, 0);

    // Вариант B: “горизонт по планете” (обычно выглядит естественнее на сфере)
    // threeJs.camera.up.setValues(_upPlane.x, _upPlane.y, _upPlane.z);

    threeJs.camera.lookAt(_lookAtCam); // up влияет на roll при lookAt [web:11]
  }



  void _update(double dt) {
    dt = dt.clamp(1.0 / 120.0, 1.0 / 30.0);

    double x = 0.0;
    double y = 0.0;
    if (joystick != null && joystick!.isMoving) {
      final a = joystick!.radians;
      final i = joystick!.intensity.clamp(0.0, 1.0);
      x = math.cos(a) * i;
      y = math.sin(a) * i;
    }

    // Orbit speed
    orbitAngularSpeed = 0.25 + x * 1.2;

    // Camera pitch
    camPitch = (camPitch + (-y) * camPitchSpeed * dt).clamp(camPitchMin, camPitchMax);

    // Move along orbit axis-angle. [web:67]
    final dAng = orbitAngularSpeed * dt;
    _q.setFromAxisAngle(orbitAxis, dAng);
    posVec.applyQuaternion(_q);

    // keep constant radius
    posVec.normalize();
    final r = planetRadius + altitude;
    posVec.x *= r;
    posVec.y *= r;
    posVec.z *= r;

    // plane bank
    planeBank = (planeBank + (x * 0.9 - planeBank) * 0.10).clamp(-0.7, 0.7);

    _applyPlaneTransform(dt);
    _updateCameraFixed();

    // Earth spin
    earthSpin += 0.15 * dt;
    earthPivot.rotation.y = earthSpin;

    _dbgAcc += dt;
    if (_dbgAcc >= 1.0) {
      _dbgAcc = 0.0;
      final dist = math.sqrt(posVec.x * posVec.x + posVec.y * posVec.y + posVec.z * posVec.z);
      debugPrint('dist=${dist.toStringAsFixed(1)} target=${(planetRadius + altitude).toStringAsFixed(1)} camPitch=${camPitch.toStringAsFixed(2)}');
    }
  }
}
