// core/storage/shared_prefs_service.dart
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
@LazySingleton()
class SharedPrefsService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance => _prefs!;
}

