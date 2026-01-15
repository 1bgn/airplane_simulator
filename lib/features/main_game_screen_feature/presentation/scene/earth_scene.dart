import 'package:flutter/cupertino.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class EarthScene extends StatefulWidget{
   EarthScene({super.key});

  @override
  State<EarthScene> createState() => _EarthSceneState();
}

class _EarthSceneState extends State<EarthScene> {
  final Flutter3DController controller = Flutter3DController();

  @override
  void initState() {
    super.initState();
    controller.onModelLoaded.addListener(() {
      // controller.startRotation(rotationSpeed: );
      controller.setCameraOrbit(20, 20, 1.5);


    });
  }

  @override
  Widget build(BuildContext context) {
  return     Flutter3DViewer(
    src: "assets/3d_models/earth.glb",
    controller:  controller,
  );
  }
}