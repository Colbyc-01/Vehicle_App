import 'package:shared_preferences/shared_preferences.dart';

class GarageService {
  static Future<void> addVehicle(String label) async {
    final prefs = await SharedPreferences.getInstance();

    final list = prefs.getStringList('garage_list') ?? [];

    if (!list.contains(label)) {
      list.insert(0, label);
    }

    await prefs.setStringList('garage_list', list);
  }
}
