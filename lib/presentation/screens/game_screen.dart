import 'dart:math';
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
import '../providers/settings_provider.dart';
import '../../core/utils/translations.dart';

/// Pantalla principal del juego donde se muestra la cuadrícula y se interactúa con las piezas.
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final ScrollController _footerScrollController = ScrollController();
  final TransformationController _transformationController = TransformationController();
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadRewardedAd();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerGrid();
    });
  }

  void _centerGrid() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    const canvasWidth = 1500.0;
    const canvasHeight = 1500.0;
    final x = (canvasWidth - size.width) / 2;
    final y = (canvasHeight - (size.height * 0.7)) / 2;
    _transformationController.value = Matrix4.identity();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      
      // Obtenemos el tamaño real del canvas desde el estado actual
      final gameState = ref.read(gameProvider);
      if (gameState.currentLevel == null) return;
      
      final gridSize = gameState.currentLevel!.size;
      final double cellSize = gridSize > 14 ? (gridSize > 20 ? 28 : 38) : (gridSize > 10 ? 45 : 65);
      final spacing = gridSize > 14 ? 1.0 : 2.0;
      final totalGridSize = (cellSize * gridSize) + (spacing * (gridSize - 1)) + 40; // + padding
      
      final canvasWidth = max(totalGridSize * 2, size.width);
      final canvasHeight = max(totalGridSize * 2, size.height);

      final x = (canvasWidth - size.width) / 2;
      final y = (canvasHeight - (size.height * 0.6)) / 2;

      _transformationController.value = Matrix4.identity()..translate(-x, -y);
    });
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;
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
    _footerScrollController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final refNotifier = ref.read(gameProvider.notifier);
    final l10n = ref.watch(translationsProvider);

    // Escuchamos eventos especiales para diálogos
    ref.listen(gameProvider, (previous, next) {
      if (next.isLevelComplete && !(previous?.isLevelComplete ?? false)) {
        _showWinDialog(context, ref, next, l10n);
      }
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        _showGameOverDialog(context, ref, next, l10n);
      }
      
      if (next.levelNumber != previous?.levelNumber) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerGrid();
        });
      }

      if (next.levelNumber == 1 && next.showTutorial && previous?.levelNumber != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTutorialDialog(context, l10n);
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, gameState, ref, l10n), // Barra superior con estadísticas.
                Expanded(
                  child: Center(child: _buildGrid(context, gameState, ref, l10n)), // El tablero de juego.
                ),
                _buildActionButtons(gameState, ref, l10n), // Botones de Deshacer y Pista
                if (gameState.difficulty == 'hard') _buildMachine(gameState, l10n), // Nueva máquina de fusión
                _buildFooter(gameState, l10n), // Inventario de piezas arrastrables.
                const AdBanner(), // Banner publicitario.
              ],
            ).animate(target: gameState.errorTrigger.toDouble()).shake(hz: 8, curve: Curves.easeInOut, offset: const Offset(4, 0)),
          ),
          // Superposición visual que se muestra al ganar el nivel.
          if (gameState.isLevelComplete) _buildVictoryOverlay(l10n),
          
          // Mensaje central animado (reemplaza SnackBar)
          if (gameState.message != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Text(
                  gameState.message!,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut).fadeOut(delay: 1.5.seconds),
            ),
        ],
      ),
    );
  }

  void _showTutorialDialog(BuildContext context, Translations l10n) {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), 
            side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
          ),
          title: Text(
            '¿CÓMO JUGAR?', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.bold)
          ),
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
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      'No volver a mostrar', 
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
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

  Widget _buildHeader(BuildContext context, GameState state, WidgetRef ref, Translations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Combo Badge (Solo si hay combo activo)
          if (state.comboCount > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.orange, Colors.redAccent]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)],
              ),
              child: Text(
                'COMBO x${state.comboCount}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut).shimmer(duration: 1.seconds),
          
          _StatItem(
            label: l10n.text('lives_label'),
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
                _StatItem(label: l10n.text('level_label'), value: '${state.levelNumber}'),
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

          Row(
            children: [
              _StatItem(
                label: l10n.text('time_label'),
                value: '${state.timeLeft}s',
                isWarning: state.timeLeft < 15,
              ),
              IconButton(
                icon: Icon(state.isTimerPaused ? Icons.play_arrow : Icons.pause, color: Colors.blueAccent, size: 18),
                onPressed: () => ref.read(gameProvider.notifier).togglePause(),
              ),
            ],
          ),

          _StatItem(
            label: 'SCORE',
            value: '${state.score}',
          ).animate(target: state.score.toDouble()).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 200.ms).then().scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),

          // Selector de Tema
          IconButton(
            icon: Icon(
              ref.watch(settingsProvider).themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              size: 20,
            ),
            onPressed: () => ref.read(settingsProvider.notifier).toggleTheme(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  /// Construye la cuadrícula dinámica del puzzle.
  Widget _buildGrid(BuildContext context, GameState state, WidgetRef ref, Translations l10n) {
    if (state.currentLevel == null) return const CircularProgressIndicator();

    final size = state.currentLevel!.size;
    // Tamaño de celda más generoso para que se vea bien
    final double cellSize = size > 14 ? (size > 20 ? 28 : 38) : (size > 10 ? 45 : 65);
    final spacing = size > 14 ? 1.0 : 2.0;
    final totalGridSize = (cellSize * size) + (spacing * (size - 1));
    final screenSize = MediaQuery.of(context).size;
    
    // Canvas proporcional al tamaño de la grilla
    final double canvasWidth = max(totalGridSize * 2, screenSize.width);
    final double canvasHeight = max(totalGridSize * 2, screenSize.height);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(600),
        minScale: 0.1,
        maxScale: 2.5,
        constrained: false, 
        child: Container(
          width: canvasWidth,
          height: canvasHeight,
          alignment: Alignment.center, // Centrado real
          child: Container(
            width: totalGridSize,
            height: totalGridSize,
            padding: const EdgeInsets.all(20),
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
                 return _buildCell(cell, state, ref, l10n);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Construye una celda individual que puede aceptar piezas arrastradas.
  Widget _buildCell(GridCell cell, GameState state, WidgetRef ref, Translations l10n) {
    if (cell.type == CellType.empty) return const SizedBox.shrink();

    final size = state.currentLevel?.size ?? 5;

    // Verificamos si esta celda es parte de una ecuación ya resuelta.
    final isSolved = state.solvedCells.contains('${cell.x},${cell.y}');

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
        // El valor viene en el mapa: {'value': String, 'isMachine': bool}
        final value = details.data['value'] as String;
        final notifier = ref.read(gameProvider.notifier);
        
        Map<String, dynamic>? fusionData;
        if (details.data['fromMachineResult'] == true) {
          fusionData = {
            'valA': state.machineLastInputA,
            'valB': state.machineLastInputB,
            'fromA': state.machineLastInputAFromMachine,
            'fromB': state.machineLastInputBFromMachine,
          };
        }

        notifier.placeTile(cell.x, cell.y, value, fusionData: fusionData);
        
        if (details.data['fromMachineResult'] == true) {
          notifier.useMachineResult();
        }
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
                  ? Colors.green.withOpacity(0.4)
                  : (cell.isFixed
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.15)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(size > 12 ? 4 : 8),
              border: Border.all(
                color: isSolved
                    ? Colors.greenAccent
                    : (candidateData.isNotEmpty ? Colors.blueAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
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
                    : (cell.isFixed 
                        ? Theme.of(context).colorScheme.onSurface 
                        : Colors.blueAccent),
                ),
              ),
            ),
          ).animate(target: isSolved ? 1 : 0).shimmer(duration: 1.seconds),
        );
      },
    );
  }

  Widget _buildFooter(GameState state, Translations l10n) {
    // Obtenemos y ordenamos ambos sets de piezas
    final footerTiles = List<String>.from(state.currentLevel?.footerTiles ?? [])..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final machineTiles = List<String>.from(state.machineTiles)..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    
    if (footerTiles.isEmpty && machineTiles.isEmpty && state.machineInputA == null && state.machineInputB == null) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180), // Un poco más alto para los dos grupos
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 2)),
      ),
      child: SingleChildScrollView(
        controller: _footerScrollController,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (footerTiles.isNotEmpty) ...[
                Text(l10n.text('numbers_label'), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildTileGrid(footerTiles, isMachine: false),
                const SizedBox(height: 16),
              ],
              if (machineTiles.isNotEmpty) ...[
                Text(l10n.text('ingredients_label'), style: const TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildTileGrid(machineTiles, isMachine: true),
              ],
            ],
          ),
        ),
    ).animate().slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildTileGrid(List<String> tiles, {required bool isMachine}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles.map((value) {
        return Draggable<Map<String, dynamic>>(
          data: {'value': value, 'isMachine': isMachine},
          feedback: MathTile(value: value, size: 50, color: isMachine ? Colors.pinkAccent : null),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: MathTile(value: value, size: 45, color: isMachine ? Colors.pinkAccent : null),
          ),
          child: MathTile(value: value, size: 45, color: isMachine ? Colors.pinkAccent : null),
        );
      }).toList(),
    );
  }

  Widget _buildMachine(GameState state, Translations l10n) {
    final notifier = ref.read(gameProvider.notifier);
    final valA = state.machineInputA;
    final valB = state.machineInputB;
    final canFuse = valA != null && valB != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pinkAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.pinkAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.text('fusion_machine'),
            style: const TextStyle(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMachineSlot(1, valA, state, notifier),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => notifier.toggleMachineOp(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    state.machineOp,
                    style: const TextStyle(color: Colors.pinkAccent, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ).animate(target: state.machineOp == '+' ? 0 : 1).rotate(begin: 0, end: 0.5),
              const SizedBox(width: 12),
              _buildMachineSlot(2, valB, state, notifier),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: canFuse ? () => notifier.fuseNumbers() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 20),
                    const SizedBox(width: 4),
                    Text(l10n.text('fusion_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ).animate(target: canFuse ? 1 : 0).shimmer(duration: 1.seconds).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
              if (state.machineResult != null) ...[
                const SizedBox(width: 20),
                const Icon(Icons.arrow_forward, color: Colors.pinkAccent, size: 24),
                const SizedBox(width: 20),
                _buildResultSlot(state.machineResult!, notifier, l10n),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => notifier.breakResult(),
                  icon: const Icon(Icons.undo, color: Colors.amberAccent, size: 18),
                  label: Text(l10n.text('undo_button'), style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ).animate().fadeIn().scale(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultSlot(String value, GameNotifier notifier, Translations l10n) {
    return Draggable<Map<String, dynamic>>(
      data: {'value': value, 'isMachine': false, 'fromMachineResult': true},
      feedback: MathTile(value: value, size: 50),
      childWhenDragging: const SizedBox(width: 50, height: 50),
      onDragCompleted: () => notifier.useMachineResult(),
      child: GestureDetector(
        onTap: () => notifier.breakResult(),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blueAccent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ).animate().shimmer(duration: 2.seconds).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0)),
    );
  }

  Widget _buildMachineSlot(int slot, String? value, GameState gameState, GameNotifier notifier) {
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => notifier.addToMachine(slot, details.data['value'], isMachineTile: details.data['isMachine'] ?? false),
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: () => notifier.removeFromMachine(slot),
          // En realidad, deberíamos trackear de dónde vino. Pero si es rosa, vuelve a rosa.
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: candidateData.isNotEmpty ? Colors.pinkAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Center(
              child: value != null
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pinkAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))],
                        ),
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white24, size: 30),
            ),
          ),
        );
      },
    );
  }

  /// Overlay de celebración que aparece al completar un nivel.
  Widget _buildVictoryOverlay(Translations l10n) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 200)
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 5.seconds)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut),
                const Icon(Icons.auto_awesome, color: Colors.white, size: 80)
                    .animate(onPlay: (c) => c.repeat())
                    .scale(duration: 1.seconds, curve: Curves.bounceOut),
              ],
            ),
            const SizedBox(height: 30),
            Text(
                  l10n.text('victory'),
                  style: const TextStyle(
                    fontSize: 55,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                    letterSpacing: 8,
                    shadows: [
                      Shadow(color: Colors.orange, blurRadius: 30),
                      Shadow(color: Colors.white, blurRadius: 10),
                    ],
                  ),
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 1.5.seconds, color: Colors.white),
            const SizedBox(height: 40),
            Text(
              '${l10n.text('next_level_label') ?? 'Pasas al nivel'} ${ref.read(gameProvider).levelNumber + 1}...',
              style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 1.seconds).slideY(begin: 0.5),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                ref.read(gameProvider.notifier).startNewLevel(ref.read(gameProvider).levelNumber + 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 10,
              ),
              child: Text(
                l10n.text('continue_button') ?? 'CONTINUAR',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ).animate().fadeIn(delay: 1.5.seconds).scale(curve: Curves.elasticOut),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Muestra el diálogo de victoria con la puntuación y el botón para el siguiente nivel.
  void _showWinDialog(BuildContext context, WidgetRef ref, GameState state, Translations l10n) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            l10n.text('victory'),
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech, color: Colors.amber, size: 80),
              const SizedBox(height: 20),
              Text(
                '${l10n.text('level_label')}: ${state.levelNumber}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${state.score}',
                style: const TextStyle(fontSize: 16),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: Text(l10n.text('next_level')),
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
    Translations l10n,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.text('game_over'),
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.text('try_again'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameProvider.notifier).startNewLevel(1);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(l10n.text('try_again')),
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
          style: TextStyle(
            fontSize: 10, 
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isWarning 
                ? Colors.redAccent 
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

extension GameScreenActions on _GameScreenState {
  Widget _buildActionButtons(GameState state, WidgetRef ref, Translations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón Deshacer (Solo Icono)
          GestureDetector(
            onTap: () => ref.read(gameProvider.notifier).undoMove(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: const Icon(Icons.undo, color: Colors.amber, size: 22),
            ),
          ),
          const SizedBox(width: 20),
          // Botón Pista (Lamparita)
          GestureDetector(
            onTap: () {
              if (state.hintsRemaining > 0) {
                ref.read(gameProvider.notifier).useHint();
              } else {
                _showAd();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: state.hintsRemaining > 0 ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.hintsRemaining > 0 ? Colors.blueAccent : Colors.redAccent, 
                  width: 1.5
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.hintsRemaining > 0 ? Icons.lightbulb : Icons.play_circle_fill,
                    size: 20,
                    color: state.hintsRemaining > 0 ? Colors.blueAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.hintsRemaining > 0 ? '${state.hintsRemaining}' : l10n.text('hints_label'),
                    style: TextStyle(
                      color: state.hintsRemaining > 0 ? Colors.blueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
          ).animate(target: state.hintsRemaining == 0 ? 1 : 0).shake(hz: 4, curve: Curves.easeInOut),
        ],
      ),
    );
  }
}
