import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StatsRepository {
  static const String _gamesPlayedKey = 'stats_games_played';
  static const String _gamesWonKey = 'stats_games_won';
  static const String _totalScoreKey = 'stats_total_score';
  static const String _bestComboKey = 'stats_best_combo';
  static const String _totalTimeKey = 'stats_total_time';
  static const String _bestTimeKey = 'stats_best_time';
  static const String _bestTimeEqKey = 'stats_best_time_eq';
  static const String _hourDataKey = 'stats_hour_data';

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

  Future<void> saveGameCompletionMetrics(int timeTakenSeconds, int equationCount, int hourOfDay) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Add to total time
    final currentTotalTime = prefs.getInt(_totalTimeKey) ?? 0;
    await prefs.setInt(_totalTimeKey, currentTotalTime + timeTakenSeconds);

    // Update best time
    final currentBestTime = prefs.getInt(_bestTimeKey) ?? 999999;
    if (timeTakenSeconds < currentBestTime) {
      await prefs.setInt(_bestTimeKey, timeTakenSeconds);
      await prefs.setInt(_bestTimeEqKey, equationCount);
    }

    // Update hour data
    final hourDataStr = prefs.getString(_hourDataKey) ?? '{}';
    final Map<String, dynamic> hourData = json.decode(hourDataStr);
    final hourStr = hourOfDay.toString();
    
    if (hourData.containsKey(hourStr)) {
      hourData[hourStr]['totalTime'] = (hourData[hourStr]['totalTime'] ?? 0) + timeTakenSeconds;
      hourData[hourStr]['count'] = (hourData[hourStr]['count'] ?? 0) + 1;
    } else {
      hourData[hourStr] = {
        'totalTime': timeTakenSeconds,
        'count': 1,
      };
    }
    await prefs.setString(_hourDataKey, json.encode(hourData));
  }

  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'gamesPlayed': prefs.getInt(_gamesPlayedKey) ?? 0,
      'gamesWon': prefs.getInt(_gamesWonKey) ?? 0,
      'totalScore': prefs.getInt(_totalScoreKey) ?? 0,
      'bestCombo': prefs.getInt(_bestComboKey) ?? 0,
      'totalTime': prefs.getInt(_totalTimeKey) ?? 0,
      'bestTime': prefs.getInt(_bestTimeKey) ?? 0,
      'bestTimeEq': prefs.getInt(_bestTimeEqKey) ?? 0,
      'hourData': prefs.getString(_hourDataKey) ?? '{}',
    };
  }
}
