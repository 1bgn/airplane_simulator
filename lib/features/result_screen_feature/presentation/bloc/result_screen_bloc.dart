import 'package:aircraft_simulator/features/result_screen_feature/application/result_screen_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
part 'result_screen_bloc.freezed.dart';


@freezed
sealed class ResultEvent with _$ResultEvent {
  const factory ResultEvent.saveMoney( {required final int money}) = _SaveMoney;
}
@freezed
sealed class ResultState with _$ResultState {
  const factory ResultState.initial() = _Initial;

}
@injectable
class ResultScreenBloc extends Bloc<ResultEvent,ResultState>{
  //я специально упростил до сервиса не стал расписсывать domain,data, interfaces и тд
  final ResultScreenService _service;
  ResultScreenBloc(this._service):super(ResultState.initial()){
    on<ResultEvent>((e,s){
      e.map(saveMoney: (s){
        final currentMoney = _service.getMoney();
        _service.saveMoney(currentMoney+s.money);
      });
    });
  }
}