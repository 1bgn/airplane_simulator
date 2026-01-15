import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:three_js/three_js.dart' as three;
import 'package:three_js_controls/three_js_controls.dart';

class ThreeSpaceScene extends StatefulWidget {
  const ThreeSpaceScene({super.key});

  @override
  State<ThreeSpaceScene> createState() => _ThreeSpaceSceneState();
}

class _ThreeSpaceSceneState extends State<ThreeSpaceScene> {
  late three.ThreeJS threeJs;
  OrbitControls? controls;

  three.Object3D? airplane;
  three.Mesh? terrain;

  // Terrain params
  final double terrainW = 2000.0;
  final double terrainH = 2000.0;
  final int terrainSegW = 240;
  final int terrainSegH = 240;

  // Flight (straight line)
  double planeX = 0.0;
  double planeZ = -800.0;
  final double planeSpeed = 120.0; // world units per second

  // IMPORTANT: fixed flight altitude (no "bobbing")
  final double flightY = 60.0;

  // Camera: strictly behind
  final double followBack = 110.0;
  final double followUp = 35.0;

  // temps
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
  Widget build(BuildContext context) => Scaffold(body: threeJs.build());

  // One function for both mesh generation and any sampling if needed later
  double terrainHeight(double x, double z) {
    final h1 = 18.0 * math.sin(x * 0.010) * math.cos(z * 0.010);
    final h2 = 8.0 * math.sin(x * 0.035 + 1.7) * math.cos(z * 0.030 - 0.6);
    return h1 + h2;
  }

  three.Mesh buildTerrain() {
    final geo = three.PlaneGeometry(terrainW, terrainH, terrainSegW, terrainSegH);
    geo.rotateX(-math.pi / 2);

    // NOTE: three_js uses Attribute.position (not 'position')
    final pos =
    geo.getAttribute(three.Attribute.position) as three.BufferAttribute;

    for (int i = 0; i < pos.count; i++) {
      final x = (pos.getX(i) ?? 0).toDouble();
      final z = (pos.getZ(i) ?? 0).toDouble();
      pos.setY(i, terrainHeight(x, z));
    }

    pos.needsUpdate = true;
    geo.computeVertexNormals();

    final mat = three.MeshStandardMaterial.fromMap({
      'color': 0x556644,
      'roughness': 1.0,
      'metalness': 0.0,
    });

    final mesh = three.Mesh(geo, mat);
    mesh.receiveShadow = true;
    return mesh;
  }

  Future<void> setup() async {
    // Camera
    threeJs.camera = three.PerspectiveCamera(
      60,
      threeJs.width / threeJs.height,
      0.1,
      8000,
    );
    threeJs.camera.position.setValues(0, flightY + followUp, planeZ - followBack);
    threeJs.camera.up.setValues(0, 1, 0);

    // Scene
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x87B6FF);

    // Controls: locked (camera is fully driven by code)
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

    // Airplane
    final loader = three.GLTFLoader(flipY: true).setPath('assets/3d_models/');
    final airplaneGltf = await loader.fromAsset('airplane.glb');
    airplane = airplaneGltf?.scene;

    if (airplane != null) {
      airplane!.scale.setValues(0.35, 0.35, 0.35);
      threeJs.scene.add(airplane!);

      airplane!.position.setValues(planeX, flightY, planeZ);
      airplane!.lookAt(three.Vector3(planeX, flightY, planeZ + 10.0));
    }

    // Animation
    threeJs.addAnimationEvent((dt) {
      if (airplane == null) return;

      // Move straight along +Z
      planeZ += planeSpeed * dt;

      // Simple wrap (keeps you inside the same terrain tile)
      if (planeZ > terrainH * 0.5) {
        planeZ = -terrainH * 0.5;
      }

      // Fixed height: NO terrain sampling here
      airplane!.position.setValues(planeX, flightY, planeZ);

      // Fixed forward orientation (+Z): NO pitch/roll from terrain
      _tmpLookAt.setValues(planeX, flightY, planeZ + 15.0);
      airplane!.lookAt(_tmpLookAt);

      // Camera strictly behind (no smoothing)
      threeJs.camera.position.setValues(
        airplane!.position.x,
        airplane!.position.y + followUp,
        airplane!.position.z - followBack,
      );

      // Look at airplane via OrbitControls target
      controls!.target.setValues(
        airplane!.position.x,
        airplane!.position.y,
        airplane!.position.z,
      );
      controls!.update();
    });
  }
}
