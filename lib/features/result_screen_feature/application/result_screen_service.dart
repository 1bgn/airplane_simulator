import 'package:injectable/injectable.dart';

import '../../../core/storage/shared_prefs_service.dart';
import '../../../core/storage/storage_keys.dart';

@injectable
class ResultScreenService {
  Future<void> saveMoney(int money) async {
    final prefs = SharedPrefsService.instance;
    await prefs.setInt(StorageKeys.userMoney, money);
  }
  int getMoney(){
    final prefs = SharedPrefsService.instance;
    return prefs.getInt(StorageKeys.userMoney)??0;
  }
}