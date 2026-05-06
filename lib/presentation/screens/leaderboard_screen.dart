import 'package:flutter/material.dart';
import '../../data/repositories/score_repository.dart';
import '../../core/theme/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<ScoreEntry>>(
        future: ScoreRepository().getScores(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final scores = snapshot.data!;
          if (scores.isEmpty) return const Center(child: Text('No hay puntajes aún.'));

          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final entry = scores[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: index == 0 ? Colors.amber : AppTheme.primaryBlue,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${entry.score}', style: const TextStyle(fontSize: 18, color: AppTheme.secondaryPurple)),
              );
            },
          );
        },
      ),
    );
  }
}
