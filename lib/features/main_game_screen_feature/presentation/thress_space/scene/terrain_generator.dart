import 'dart:math' as math;
import 'package:three_js/three_js.dart' as three;

typedef TerrainHeightFn = double Function(double x, double z);

class TerrainGenerator {
  TerrainGenerator({
    required this.width,
    required this.height,
    required this.segW,
    required this.segH,
    required this.heightFn,
  });

  final double width;
  final double height;
  final int segW;
  final int segH;
  final TerrainHeightFn heightFn;

  three.Mesh build() {
    final geo = three.PlaneGeometry(width, height, segW, segH);
    geo.rotateX(-math.pi / 2);

    final pos = geo.getAttribute(three.Attribute.position) as three.BufferAttribute;

    for (int i = 0; i < pos.count; i++) {
      final x = (pos.getX(i) ?? 0).toDouble();
      final z = (pos.getZ(i) ?? 0).toDouble();
      pos.setY(i, heightFn(x, z));
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
    mesh.frustumCulled = false;
    return mesh;
  }
}
