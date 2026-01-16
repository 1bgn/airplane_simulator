import 'dart:math' as math;

import 'package:aircraft_simulator/core/routes/app_router.dart';
import 'package:aircraft_simulator/features/result_screen_feature/presentation/bloc/result_screen_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:three_js/three_js.dart' as three;

class ResultScreen extends StatelessWidget {
  final int timeLeft;
  final int score;
  final int goalScore;
  final bool isWon;
  final List<three.Vector3> trajectory;

  const ResultScreen({
    super.key,
    required this.timeLeft,
    required this.score,
    required this.isWon,
    required this.trajectory,
    required this.goalScore,
  });
  int get wonMoney => score*(60-timeLeft);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isWon ? 'Победа!' : 'Время вышло'),
                Text('Собрано: $score / $goalScore'),
                Text('Осталось времени: $timeLeft c'),
                Text('Вы выиграли: $wonMoney монет'),
                const SizedBox(height: 20),
                // Виджет с траекторией
                if (trajectory.isNotEmpty)
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: _TrajectoryPainter(trajectory),
                    ),
                  ),
                MaterialButton(color: Colors.green,onPressed: (){
                  final bloc = context.read<ResultScreenBloc>();
                  bloc.add(ResultEvent.saveMoney(money: wonMoney));
                  Navigator.pushReplacementNamed(context, AppRouter.getInitialRoute());
                },child: Text("Завершить",style: TextStyle(color: Colors.white),),)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final List<three.Vector3> trajectory;

  _TrajectoryPainter(this.trajectory);

  @override
  void paint(Canvas canvas, Size size) {
    if (trajectory.length < 2) return;

    // Находим bounding box по XZ
    double minX = trajectory.first.x;
    double maxX = trajectory.first.x;
    double minZ = trajectory.first.z;
    double maxZ = trajectory.first.z;

    for (final p in trajectory) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }

    final spanX = (maxX - minX).abs();
    final spanZ = (maxZ - minZ).abs();
    final span = (spanX == 0 && spanZ == 0) ? 1.0 : (spanX > spanZ ? spanX : spanZ);

    // отступы от краёв
    const padding = 10.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;
    final scale = span == 0 ? 1.0 : math.min(drawW, drawH) / span;

    // ось Z инвертируем, чтобы движение "вперёд" шло вверх
    Offset toOffset(three.Vector3 v) {
      final dx = (v.x - minX - spanX / 2);
      final dz = (v.z - minZ - spanZ / 2);

      return Offset(
        size.width / 2 + dx * scale,
        size.height / 2 - dz * scale,
      );
    }

    final path = Path();
    path.moveTo(
      toOffset(trajectory.first).dx,
      toOffset(trajectory.first).dy,
    );
    for (int i = 1; i < trajectory.length; i++) {
      final o = toOffset(trajectory[i]);
      path.lineTo(o.dx, o.dy);
    }

    final paintPath = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paintPath);

    // точка старта
    final start = toOffset(trajectory.first);
    final end = toOffset(trajectory.last);

    final startPaint = Paint()..color = Colors.green;
    final endPaint = Paint()..color = Colors.red;

    canvas.drawCircle(start, 4, startPaint);
    canvas.drawCircle(end, 4, endPaint);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.trajectory != trajectory;
  }
}
