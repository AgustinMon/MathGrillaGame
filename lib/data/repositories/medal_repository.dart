import 'package:shared_preferences/shared_preferences.dart';

class MedalRepository {
  static const String _key = 'unlocked_medals';

  Future<List<String>> getUnlockedMedalIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> unlockMedal(String medalId) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = await getUnlockedMedalIds();
    if (!unlocked.contains(medalId)) {
      unlocked.add(medalId);
      await prefs.setStringList(_key, unlocked);
    }
  }
}
