import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/game_provider.dart';
import 'settings_screen.dart';
import 'medals_screen.dart';
import 'leaderboard_screen.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/math_tile.dart';
import '../widgets/ad_banner.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);

    // Escuchar cambios para mostrar diálogos de éxito o derrota
    ref.listen(gameProvider, (previous, next) {
      if (next.isLevelComplete && !(previous?.isLevelComplete ?? false)) {
        _showWinDialog(context, ref, next);
      }
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        _showGameOverDialog(context, ref, next);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, gameState),
                Expanded(
                  child: Center(
                    child: _buildGrid(context, gameState, ref),
                  ),
                ),
                _buildFooter(gameState),
                const AdBanner(),
              ],
            ),
          ),
          if (gameState.isLevelComplete) _buildVictoryOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(label: 'LIVES', value: '${state.lives}', isWarning: state.lives < 2),
          _StatItem(label: 'LEVEL', value: '${state.levelNumber}'),
          _StatItem(label: 'TIME', value: '${state.timeLeft}s', isWarning: state.timeLeft < 10),
          _StatItem(label: 'SCORE', value: '${state.score}'),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amberAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MedalsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard, color: AppTheme.secondaryPurple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2);
  }

  Widget _buildGrid(BuildContext context, GameState state, WidgetRef ref) {
    if (state.currentLevel == null) return const CircularProgressIndicator();

    final size = state.currentLevel!.size;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: size,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: size * size,
          itemBuilder: (context, index) {
            final x = index % size;
            final y = index ~/ size;
            final cell = state.currentLevel!.cells.firstWhere(
              (c) => c.x == x && c.y == y,
              orElse: () => GridCell(x: x, y: y, type: CellType.empty),
            );

            return _buildCell(cell, state, ref);
          },
        ),
      ),
    );
  }

  Widget _buildCell(GridCell cell, GameState state, WidgetRef ref) {
    if (cell.type == CellType.empty) return const SizedBox.shrink();

    final isSolved = state.solvedRows.contains(cell.y) || state.solvedCols.contains(cell.x);

    return DragTarget<String>(
      onAccept: (value) {
        ref.read(gameProvider.notifier).placeTile(cell.x, cell.y, value);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: isSolved 
                ? Colors.green.withOpacity(0.3) 
                : (cell.isFixed ? Colors.white10 : Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSolved 
                  ? Colors.greenAccent 
                  : (candidateData.isNotEmpty ? Colors.blue : Colors.white24),
              width: isSolved ? 3 : 2,
            ),
          ),
          child: Center(
            child: Text(
              cell.currentValue ?? (cell.isFixed ? cell.value! : ''),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSolved 
                    ? Colors.white 
                    : (cell.isFixed ? Colors.white : Colors.blueAccent),
              ),
            ),
          ),
        ).animate(target: isSolved ? 1 : 0).shimmer(duration: 1.seconds);
      },
    );
  }

  Widget _buildFooter(GameState state) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: state.currentLevel?.footerTiles.length ?? 0,
        itemBuilder: (context, index) {
          final val = state.currentLevel!.footerTiles[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Draggable<String>(
              data: val,
              feedback: MathTile(value: val, isDragging: true),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: MathTile(value: val),
              ),
              child: MathTile(value: val),
            ),
          );
        },
      ),
    ).animate().slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildVictoryOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡EXCELENTE!',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 4,
                shadows: [Shadow(color: Colors.orange, blurRadius: 20)],
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).then().shimmer(duration: 1.seconds),
            const SizedBox(height: 20),
            const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 80)
                .animate(onPlay: (controller) => controller.repeat())
                .scale(duration: 1.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2))
                .rotate(duration: 2.seconds),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _showWinDialog(BuildContext context, WidgetRef ref, GameState state) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('¡Nivel Completado!', style: TextStyle(color: AppTheme.primaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 60),
              const SizedBox(height: 20),
              Text('Puntuación: ${state.score}', style: const TextStyle(fontSize: 20)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(gameProvider.notifier).startNewLevel(state.levelNumber + 1);
              },
              child: const Text('Siguiente Nivel'),
            ),
          ],
        ),
      );
    });
  }

  void _showGameOverDialog(BuildContext context, WidgetRef ref, GameState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('¡Game Over!', style: TextStyle(color: AppTheme.neonRed)),
        content: const Text('Te has quedado sin vidas o tiempo.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameProvider.notifier).startNewLevel(1);
            },
            child: const Text('Reintentar desde Nivel 1'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _StatItem({required this.label, required this.value, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isWarning ? Colors.redAccent : Colors.white,
          ),
        ),
      ],
    );
  }
}
