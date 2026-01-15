import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_controls/three_js_controls.dart' hide Joystick;

class ThreeSpaceScene extends StatefulWidget {
  const ThreeSpaceScene({super.key});

  @override
  State<ThreeSpaceScene> createState() => _ThreeSpaceSceneState();
}

class _ThreeSpaceSceneState extends State<ThreeSpaceScene> {
  late three.ThreeJS threeJs;
  OrbitControls? controls;

  three.Mesh? terrain;

  // New: container + model (to separate yaw vs roll)
  three.Object3D? airplaneRig;
  three.Object3D? airplaneModel;

  // Terrain params
  final double terrainW = 2000.0;
  final double terrainH = 2000.0;
  final int terrainSegW = 240;
  final int terrainSegH = 240;

  // Flight
  double planeX = 0.0;
  double planeZ = -800.0;

  // Fixed altitude (no bobbing)
  final double flightY = 60.0;

  // Speed
  final double planeSpeed = 120.0;

  // Heading (yaw) radians, 0 => +Z
  double yaw = 0.0;

  // Joystick input (-1..1)
  double _yawInput = 0.0;

  // Turn rate (rad/s at full deflection)
  final double yawRate = 1.4;
// Camera: strictly behind current forward vector


// NEW: side offset (positive => left)
  final double followLeft = 28.0;
  // Bank (roll) animation
  final double maxBankDeg = 18.0;     // max tilt
  final double bankSmooth = 0.12;     // 0..1 per frame-like smoothing
  double _bank = 0.0;                // current bank angle (rad)

  // Camera: strictly behind current forward vector
  final double followBack = 110.0;
  final double followUp = 35.0;

  // temps
  final three.Vector3 _tmpForward = three.Vector3(0, 0, 1);
  final three.Vector3 _tmpLookAt = three.Vector3(0, 0, 0);

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
    controls?.dispose();
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
                  _yawInput = -details.x; // [-1..1]
                },
              ),
            ),
          ),
        ],
      ),
    );
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
    geo.computeBoundingSphere(); // [web:131]

    final mat = three.MeshStandardMaterial.fromMap({
      'color': 0x2ECC71,
      'roughness': 1.0,
      'metalness': 0.0,
    });

    final mesh = three.Mesh(geo, mat);

    // Если всё равно будет пропадать — просто отключи frustum culling для террейна
    mesh.frustumCulled = false; // [web:124]

    return mesh;
  }


  double _wrap(double v, double min, double max) {
    final range = max - min;
    if (range <= 0) return min;
    while (v < min) v += range;
    while (v > max) v -= range;
    return v;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Future<void> setup() async {
    // Camera
    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      0.1,
      8000,
    );
    threeJs.camera.up.setValues(0, 1, 0);

    // Scene
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x4A90E2);


    // Controls: locked (camera fully driven by code)
    controls = OrbitControls(threeJs.camera, threeJs.globalKey)
      ..enableDamping = false
      ..enableRotate = false
      ..enablePan = false
      ..enableZoom = false;

    // Light
    threeJs.scene.add(three.AmbientLight(0xffffff, 0.55));
    final sun = three.DirectionalLight(0xffffff, 1.2);
    sun.position.setValues(300, 600, 200);
    threeJs.scene.add(sun);

    // Terrain
    terrain = buildTerrain();
    threeJs.scene.add(terrain!);

    // Airplane: rig + model
    airplaneRig = three.Object3D();
    threeJs.scene.add(airplaneRig!);

    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final airplaneGltf = await loader.fromAsset('airplane.glb');
    airplaneModel = airplaneGltf?.scene;

    if (airplaneModel != null) {
      airplaneModel!.scale.setValues(0.35, 0.35, 0.35);

      // IMPORTANT: model is child, so we can roll it without breaking yaw from rig
      airplaneRig!.add(airplaneModel!);

      airplaneRig!.position.setValues(planeX, flightY, planeZ);

      // initial yaw via lookAt (rig only) [web:16]
      _tmpLookAt.setValues(planeX, flightY, planeZ + 10.0);
      airplaneRig!.lookAt(_tmpLookAt);
    }

    // Animation
    threeJs.addAnimationEvent((dt) {
      if (airplaneRig == null || airplaneModel == null) return;

      // 1) Update yaw from joystick
      yaw += _yawInput * yawRate * dt;

      // 2) Forward vector from yaw (no pitch)
      final fx = math.sin(yaw);
      final fz = math.cos(yaw);
      _tmpForward.setValues(fx, 0, fz);

      // 3) Move in heading direction
      planeX += _tmpForward.x * planeSpeed * dt;
      planeZ += _tmpForward.z * planeSpeed * dt;

      // Wrap into one tile
      planeX = _wrap(planeX, -terrainW * 0.5, terrainW * 0.5);
      planeZ = _wrap(planeZ, -terrainH * 0.5, terrainH * 0.5);

      // 4) Fixed altitude: move rig
      airplaneRig!.position.setValues(planeX, flightY, planeZ);

      // 5) Yaw: rig looks forward [web:16]
      _tmpLookAt.setValues(
        planeX + _tmpForward.x * 15.0,
        flightY,
        planeZ + _tmpForward.z * 15.0,
      );
      airplaneRig!.lookAt(_tmpLookAt);

      // 6) Bank animation on model (roll around local Z) after lookAt-style yaw [web:49]
      final targetBank = (-_yawInput * (maxBankDeg * math.pi / 180.0));
      _bank = _lerp(_bank, targetBank, bankSmooth);
      airplaneModel!.rotation.z = _bank;
      final lx = _tmpForward.z;
      final lz = -_tmpForward.x;
      // 7) Camera strictly behind (relative to forward)
      threeJs.camera.position.setValues(
        airplaneRig!.position.x - _tmpForward.x * followBack + lx * followLeft,
        airplaneRig!.position.y + followUp,
        airplaneRig!.position.z - _tmpForward.z * followBack + lz * followLeft,
      );

      controls!.target.setValues(
        airplaneRig!.position.x,
        airplaneRig!.position.y,
        airplaneRig!.position.z,
      );
      controls!.update();
    });
  }
}
