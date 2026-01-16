import 'package:aircraft_simulator/core/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:shimmer/shimmer.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final Flutter3DController _controller = Flutter3DController();

  @override
  void initState() {
    super.initState();
    _controller.onModelLoaded.addListener((){
      _controller.startRotation(rotationSpeed: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 3D фон на весь экран
          Positioned.fill(
            child: IgnorePointer(
              child: Flutter3DViewer(
                src: 'assets/3d_models/airplane.glb',
                controller: _controller,
                enableTouch: false,
                progressBarColor: Colors.transparent,
                activeGestureInterceptor: true,
              ),
            ),
          ),

          // Небольшое затемнение для читаемости кнопок
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),

          // UI поверх
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Shimmer.fromColors(baseColor: Colors.green,                   highlightColor: Colors.white,
                  child: Text("AircraftSimulator",style: TextStyle(fontSize: 46,color: Colors.white,fontWeight: FontWeight.bold),)),
                  SizedBox(height: 24,),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      style:      ElevatedButton.styleFrom(backgroundColor: Colors.green,foregroundColor: Colors.white)  ,
                      onPressed: () => Navigator.pushNamed(context, AppRouter.gameRoute),
                      child: const Text('Начать игру'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      style:      ElevatedButton.styleFrom(backgroundColor: Colors.green,foregroundColor: Colors.white)  ,
                      onPressed: SystemNavigator.pop,
                      child: const Text('Выход'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
