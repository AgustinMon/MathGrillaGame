import 'package:shared_preferences/shared_preferences.dart';

class StatsRepository {
  static const String _gamesPlayedKey = 'stats_games_played';
  static const String _gamesWonKey = 'stats_games_won';
  static const String _totalScoreKey = 'stats_total_score';
  static const String _bestComboKey = 'stats_best_combo';

  Future<void> incrementGamesPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_gamesPlayedKey) ?? 0;
    await prefs.setInt(_gamesPlayedKey, current + 1);
  }

  Future<void> incrementGamesWon() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_gamesWonKey) ?? 0;
    await prefs.setInt(_gamesWonKey, current + 1);
  }

  Future<void> addScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalScoreKey) ?? 0;
    await prefs.setInt(_totalScoreKey, current + score);
  }

  Future<void> updateBestCombo(int combo) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_bestComboKey) ?? 0;
    if (combo > current) {
      await prefs.setInt(_bestComboKey, combo);
    }
  }

  Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'gamesPlayed': prefs.getInt(_gamesPlayedKey) ?? 0,
      'gamesWon': prefs.getInt(_gamesWonKey) ?? 0,
      'totalScore': prefs.getInt(_totalScoreKey) ?? 0,
      'bestCombo': prefs.getInt(_bestComboKey) ?? 0,
    };
  }
}
