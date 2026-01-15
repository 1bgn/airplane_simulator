import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class MainGameScreen extends StatefulWidget {
  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  Flutter3DController controller = Flutter3DController();
  @override
  void initState() {
    super.initState();
    controller.onModelLoaded.addListener(() {
      print('model is loaded : ${controller.onModelLoaded.value}');
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Flutter3DViewer(
          src: "assets/3d_models/airplane.glb",

        ),
      ),
    );
  }
}
