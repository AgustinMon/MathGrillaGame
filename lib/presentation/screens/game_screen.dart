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

/// Pantalla principal del juego donde se muestra la cuadrícula y se interactúa con las piezas.
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID para recompensado
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showAd() {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El anuncio no está listo todavía, intenta en unos segundos')),
      );
      return;
    }
    
    ref.read(gameProvider.notifier).toggleTimer(true); // Pausamos el tiempo

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
        ref.read(gameProvider.notifier).toggleTimer(false); // Reanudamos el tiempo
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
        ref.read(gameProvider.notifier).toggleTimer(false);
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      ref.read(gameProvider.notifier).addHints(2); // Recompensa de 2 pistas
    });
    _rewardedAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final refNotifier = ref.read(gameProvider.notifier);

    // Escuchar cambios en el estado para reaccionar a eventos de fin de nivel.
    ref.listen(gameProvider, (previous, next) {
      if (next.message != null && next.message != previous?.message) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
            backgroundColor: next.message!.contains('Algo') ? Colors.redAccent : Colors.green,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      if (next.isLevelComplete && !(previous?.isLevelComplete ?? false)) {
        _showWinDialog(context, ref, next);
      }
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        _showGameOverDialog(context, ref, next);
      }
      
      // Mostrar tutorial si es Nivel 1 y está habilitado
      if (next.levelNumber == 1 && next.showTutorial && previous?.levelNumber != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTutorialDialog(context);
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, gameState, ref), // Barra superior con estadísticas.
                Expanded(
                  child: Center(child: _buildGrid(context, gameState, ref)), // El tablero de juego.
                ),
                _buildFooter(gameState), // Inventario de piezas arrastrables.
                const AdBanner(), // Banner publicitario.
              ],
            ),
          ),
          // Superposición visual que se muestra al ganar el nivel.
          if (gameState.isLevelComplete) _buildVictoryOverlay(),
        ],
      ),
    );
  }

  void _showTutorialDialog(BuildContext context) {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
          title: const Text('¿CÓMO JUGAR?', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primaryBlue, fontSize: 28)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTutorialStep(Icons.drag_indicator, 'Arrastra números a la grilla'),
              _buildTutorialStep(Icons.grid_on, 'Forma ecuaciones (Ej: 2 + 2 = 4)'),
              _buildTutorialStep(Icons.timer, '¡Resuelve todo antes del límite!'),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setDialogState(() => dontShowAgain = !dontShowAgain),
                child: Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      onChanged: (val) => setDialogState(() => dontShowAgain = val ?? false),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    const Text('No volver a mostrar', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () {
                  if (dontShowAgain) {
                    ref.read(gameProvider.notifier).setTutorialVisible(false);
                  }
                  Navigator.pop(context);
                },
                child: const Text('¡LISTO!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildTutorialStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GameState state, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(
            label: 'LIVES',
            value: '${state.lives}',
            isWarning: state.lives < 2,
          ),
          
          // Nivel con botón de refresco integrado de forma elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _StatItem(label: 'LVL', value: '${state.levelNumber}'),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                  onPressed: () => ref.read(gameProvider.notifier).startNewLevel(state.levelNumber),
                ),
              ],
            ),
          ),

          _StatItem(
            label: 'TIME',
            value: '${state.timeLeft}s',
            isWarning: state.timeLeft < 15,
          ),

          // Botón de Pistas / Anuncio Recompensado
          GestureDetector(
            onTap: () {
              if (state.hintsRemaining > 0) {
                ref.read(gameProvider.notifier).useHint();
              } else {
                _showAd();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.hintsRemaining > 0 ? Colors.amber.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.hintsRemaining > 0 ? Colors.amber.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.hintsRemaining > 0 ? Icons.lightbulb : Icons.play_circle_fill,
                    size: 16,
                    color: state.hintsRemaining > 0 ? Colors.amber : Colors.blueAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.hintsRemaining > 0 ? '${state.hintsRemaining}' : 'AD',
                    style: TextStyle(
                      color: state.hintsRemaining > 0 ? Colors.amber : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(target: state.hintsRemaining == 0 ? 1 : 0).shake(hz: 4, curve: Curves.easeInOut),
          
          // Iconos de acciones secundarias - Movidos a la portada
          const SizedBox(width: 40), // Espacio para mantener el balance visual si es necesario
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  /// Construye la cuadrícula dinámica del puzzle.
  Widget _buildGrid(BuildContext context, GameState state, WidgetRef ref) {
    if (state.currentLevel == null) return const CircularProgressIndicator();

    final size = state.currentLevel!.size;
    // Tamaño de celda más adaptativo para evitar desbordamientos masivos
    final double cellSize = size > 14 ? (size > 20 ? 22 : 32) : (size > 10 ? 40 : 55);
    final spacing = size > 14 ? 1.0 : 2.0;
    final totalGridSize = (cellSize * size) + (spacing * (size - 1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(150), // Más margen para niveles grandes
        minScale: 0.1,
        maxScale: 2.0,
        constrained: false, // PERMITIR QUE EL CONTENIDO DESBORDE PARA QUE NO SE CORTE
        child: Container(
          width: totalGridSize,
          height: totalGridSize,
          padding: const EdgeInsets.all(20), // Margen interno para que no pegue a los bordes del visor
            child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
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
      ),
    ),
  );
}

  /// Construye una celda individual que puede aceptar piezas arrastradas.
  Widget _buildCell(GridCell cell, GameState state, WidgetRef ref) {
    if (cell.type == CellType.empty) return const SizedBox.shrink();

    final size = state.currentLevel?.size ?? 5;

    // Verificamos si esta celda es parte de una fila o columna ya resuelta.
    final isSolved =
        state.solvedRows.contains(cell.y) || state.solvedCols.contains(cell.x);

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        // Cuando el usuario suelta una pieza aquí, notificamos al provider.
        ref.read(gameProvider.notifier).placeTile(cell.x, cell.y, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: () {
            // Si el usuario toca la celda, quitamos la pieza (si no es fija).
            ref.read(gameProvider.notifier).removeTile(cell.x, cell.y);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSolved
                  ? Colors.green.withOpacity(0.4) // Más vibrante
                  : (cell.isFixed
                        ? Colors.white.withOpacity(0.15) // Más visible
                        : Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(size > 12 ? 4 : 8),
              border: Border.all(
                color: isSolved
                    ? Colors.greenAccent
                    : (candidateData.isNotEmpty ? Colors.blueAccent : Colors.white30),
                width: isSolved ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: Text(
                cell.currentValue ?? (cell.isFixed ? cell.value! : ''),
                style: TextStyle(
                  fontSize: size > 25 ? 10 : (size > 20 ? 12 : (size > 12 ? 16 : 20)),
                  fontWeight: FontWeight.bold,
                  color: isSolved
                      ? Colors.white
                      : (cell.isFixed ? Colors.white : Colors.blueAccent),
                ),
              ),
            ),
          ).animate(target: isSolved ? 1 : 0).shimmer(duration: 1.seconds),
        );
      },
    );
  }

  Widget _buildFooter(GameState state) {
    final footerTiles = state.currentLevel?.footerTiles ?? [];
    if (footerTiles.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 2)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 60, // Tamaño máximo de cada celda del inventario
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: footerTiles.length,
          itemBuilder: (context, index) {
            final value = footerTiles[index];
            return Draggable<String>(
              data: value,
              feedback: MathTile(value: value, size: 50),
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: MathTile(value: value, size: 45),
              ),
              child: MathTile(value: value, size: 45),
            );
          },
        ),
      ),
    ).animate().slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Overlay de celebración que aparece al completar un nivel.
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
                )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 1.seconds),
            const SizedBox(height: 20),
            const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 80)
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  duration: 1.seconds,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                )
                .rotate(duration: 2.seconds),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Muestra el diálogo de victoria con la puntuación y el botón para el siguiente nivel.
  void _showWinDialog(BuildContext context, WidgetRef ref, GameState state) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text(
            '¡Nivel Completado!',
            style: TextStyle(color: AppTheme.primaryBlue),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 60),
              const SizedBox(height: 20),
              Text(
                'Puntuación: ${state.score}',
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(gameProvider.notifier)
                    .startNewLevel(state.levelNumber + 1);
              },
              child: const Text('Siguiente Nivel'),
            ),
          ],
        ),
      );
    });
  }

  /// Muestra el diálogo cuando el jugador pierde todas las vidas o se queda sin tiempo.
  void _showGameOverDialog(
    BuildContext context,
    WidgetRef ref,
    GameState state,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          '¡Game Over!',
          style: TextStyle(color: AppTheme.neonRed),
        ),
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

  /// Diálogo de debug para saltar niveles.
  void _showSkipLevelDialog(BuildContext context, WidgetRef ref, int current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Debug: Saltar Nivel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Elige el nivel al que quieres saltar:'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [1, 5, 10, 15, 20].map((l) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(gameProvider.notifier).skipLevel(l);
                      },
                      child: Text('$l'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameProvider.notifier).skipLevel(current + 1);
            },
            child: const Text('Siguiente (+1)'),
          ),
        ],
      ),
    );
  }
}

/// Widget pequeño para mostrar un ítem de estadística (vidas, tiempo, etc).
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _StatItem({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
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
