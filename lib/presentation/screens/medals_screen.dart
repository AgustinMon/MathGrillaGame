import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

class MedalsScreen extends ConsumerWidget {
  const MedalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Medallas'),
        backgroundColor: Colors.transparent,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: gameState.medals.length,
        itemBuilder: (context, index) {
          final medal = gameState.medals[index];
          return Container(
            decoration: BoxDecoration(
              color: medal.isUnlocked ? AppTheme.darkCard : Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: medal.isUnlocked ? AppTheme.primaryBlue : Colors.white12,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  medal.isUnlocked ? Icons.emoji_events : Icons.lock,
                  size: 60,
                  color: medal.isUnlocked ? Colors.amber : Colors.white24,
                ),
                const SizedBox(height: 12),
                Text(
                  medal.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: medal.isUnlocked ? Colors.white : Colors.white24,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    medal.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
