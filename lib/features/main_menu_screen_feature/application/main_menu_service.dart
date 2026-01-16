
import 'package:injectable/injectable.dart';

import '../../../core/storage/shared_prefs_service.dart';
import '../../../core/storage/storage_keys.dart';

@injectable
class MainMenuScreenService {
  String getAirplane(){
    final prefs = SharedPrefsService.instance;
    return prefs.getString(StorageKeys.currentAirplane)??"airplane.gbl";
  }
  int getMoney(){
    final prefs = SharedPrefsService.instance;
    return prefs.getInt(StorageKeys.userMoney)??0;
  }
}