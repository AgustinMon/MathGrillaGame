import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreEntry {
  final String name;
  final int score;
  final DateTime date;

  ScoreEntry({required this.name, required this.score, required this.date});

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'date': date.toIso8601String(),
  };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
    name: json['name'],
    score: json['score'],
    date: DateTime.parse(json['date']),
  );
}

class ScoreRepository {
  static const String _key = 'leaderboard';

  Future<void> saveScore(ScoreEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = await getScores();
    scores.add(entry);
    scores.sort((a, b) => b.score.compareTo(a.score));
    
    // Keep only top 10
    final topScores = scores.take(10).toList();
    
    await prefs.setString(_key, jsonEncode(topScores.map((e) => e.toJson()).toList()));
  }

  Future<List<ScoreEntry>> getScores() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    
    final List decoded = jsonDecode(data);
    return decoded.map((e) => ScoreEntry.fromJson(e)).toList();
  }
}
