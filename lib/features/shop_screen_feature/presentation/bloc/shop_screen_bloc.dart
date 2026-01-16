import 'package:aircraft_simulator/features/main_menu_screen_feature/application/main_menu_service.dart';
import 'package:aircraft_simulator/features/result_screen_feature/application/result_screen_service.dart';
import 'package:aircraft_simulator/features/shop_screen_feature/application/shop_screen_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'shop_screen_bloc.freezed.dart';


@freezed
sealed class ShopEvent with _$ShopEvent {
  const factory ShopEvent.buyAirplane({required String assetName,required int cost } ) = _BuyEvent;
}
@freezed
sealed class ShopState with _$ShopState{
  const factory ShopState.initial() = _Initial;

}
@injectable
class ShopScreenBloc extends Bloc<ShopEvent,ShopState>{
  final ShopScreenService _service;
  ShopScreenBloc(this._service):super(ShopState.initial()){
    on<ShopEvent>((e,s){
      e.map(buyAirplane: (e){
        buyAirplane(e.assetName, e.cost);
      });
    });
  }

  void buyAirplane(String assetName,int cost){
    final currentMoney = _service.getMoney();
    if(cost<currentMoney || true){
      _service.setAirplane(assetName);
      _service.saveMoney(currentMoney-cost);
    }else{
      throw Exception("Недостаточно денег");
    }
  }
}