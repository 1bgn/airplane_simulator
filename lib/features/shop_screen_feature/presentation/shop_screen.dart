import 'package:aircraft_simulator/core/routes/app_router.dart';
import 'package:aircraft_simulator/features/shop_screen_feature/presentation/bloc/shop_screen_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShopScreen extends StatelessWidget {
  final List<(String, int)> items = [('airplane.glb', 10), ('airplane_2.glb', 20)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Магазин"),),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220, // макс. ширина карточки ~200 + отступы
          childAspectRatio: 1.0,   // квадратные карточки
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _ShopItem(assetName: item.$1, cost: item.$2);
        },
      ),
    );
  }
}

class _ShopItem extends StatefulWidget {
  final String assetName;
  final int cost;

  _ShopItem({super.key, required this.assetName, required this.cost});

  @override
  State<_ShopItem> createState() => _ShopItemState();
}

class _ShopItemState extends State<_ShopItem> {
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: Flutter3DViewer(
                src: 'assets/3d_models/${widget.assetName}',
                controller: _controller,
                enableTouch: false,
                progressBarColor: Colors.transparent,
                activeGestureInterceptor: true,
              ),
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star),
                SizedBox(width: 12),
                Text("${widget.cost}"),
              ],
            ),
            SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green,foregroundColor: Colors.white),
              onPressed: () {
                final bloc = context.read<ShopScreenBloc>();
                try{
                  bloc.buyAirplane(widget.assetName, widget.cost);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Вы успешно купили!!!'),
                    ),
                  );
                  Navigator.pushReplacementNamed(context, AppRouter.getInitialRoute());
                }catch(e){

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Купить не удалось, возможно не хватает звезд'),
                    ),
                  );
                }
              },
              child: Text("Купить"),
            ),
          ],
        ),
      ),
    );
  }
}
