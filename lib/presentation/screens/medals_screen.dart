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
        title: const Text('Sala de Trofeos'),
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
          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: medal.isUnlocked ? theme.colorScheme.surface : theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: medal.isUnlocked ? AppTheme.primaryBlue : theme.colorScheme.onSurface.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  medal.isUnlocked ? (medal.iconData as IconData) : Icons.lock,
                  size: 60,
                  color: medal.isUnlocked ? Colors.amber : theme.colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  medal.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: medal.isUnlocked ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    medal.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5)),
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
