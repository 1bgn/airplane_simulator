import 'dart:math' as math;
import 'package:three_js/three_js.dart' as three;

class GameMath {
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  static double rand(math.Random rng, double a, double b) => a + (b - a) * rng.nextDouble();

  static double dist3(
      double ax,
      double ay,
      double az,
      double bx,
      double by,
      double bz,
      ) {
    final dx = ax - bx;
    final dy = ay - by;
    final dz = az - bz;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  static double computeRadiusWorld(three.Object3D obj) {
    obj.updateMatrixWorld(true);
    final bb = three.BoundingBox().setFromObject(obj, true);
    final bs = three.BoundingSphere();
    bb.getBoundingSphere(bs);
    return bs.radius;
  }

  static double wrap(double v, double min, double max) {
    final range = max - min;
    if (range <= 0) return min;
    while (v < min) v += range;
    while (v > max) v -= range;
    return v;
  }
}
