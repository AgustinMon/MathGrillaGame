import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../providers/game_provider.dart';
import 'settings_screen.dart';
import 'medals_screen.dart';
import 'leaderboard_screen.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/math_tile.dart';
import '../widgets/ad_banner.dart';
import '../providers/settings_provider.dart';
import 'tutorial_screen.dart';
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

  double _getGridSize(int gridSize, double screenWidth) {
    final cellSize = screenWidth / (gridSize > 14 ? (gridSize > 22 ? 22 : 14) : 10);
    final spacing = gridSize > 20 ? 1.0 : 2.0;
    return (cellSize * gridSize) + (spacing * (gridSize - 1));
  }

  void _centerGrid([Size? availableSize]) {
    if (!mounted) return;
    final gameState = ref.read(gameProvider);
    if (gameState.currentLevel == null) return;

    final screenSize = MediaQuery.of(context).size;
    final viewSize = availableSize ?? screenSize;
    final gridSize = gameState.currentLevel!.size;
    final totalGridSize = _getGridSize(gridSize, screenSize.width);
    
    // Calculamos el offset horizontal para que el centro de la grilla coincida con el centro de la pantalla
    final x = (max(totalGridSize, viewSize.width) - viewSize.width) / 2;
    // Siempre pegado arriba
    final y = 0.0; 

    _transformationController.value = Matrix4.identity()..translate(-x, -y);
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

  void _showRewardedAd() {
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
        // Ya se muestra el _buildVictoryOverlay en el Stack del body
      }
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        _showGameOverDialog(context, ref, next, l10n);
      }
      
      if (next.levelNumber != previous?.levelNumber) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _centerGrid();
        });
      }

      if (next.levelNumber == 1 && next.showTutorial && previous?.levelNumber != 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTutorialDialog(context, l10n);
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TutorialScreen()));
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.dark : Brightness.light,
          statusBarBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                bottom: false, // El inventario ya maneja su propio margen inferior
                child: Column(
              children: [
                _buildHeader(context, gameState, ref, l10n), // Barra superior con estadísticas.
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildGrid(context, gameState, ref, l10n),
                  ), // El tablero de juego.
                ),
                _buildActionButtons(gameState, ref, l10n), // Botones de Deshacer y Pista
                if (gameState.difficulty == 'hard') _buildMachine(gameState, l10n), // Nueva máquina de fusión
                _buildFooter(gameState, l10n), // Inventario de piezas arrastrables.
                const AdBanner(), // Banner publicitario.
              ],
            ).animate(target: gameState.errorTrigger.toDouble()).shake(hz: 8, curve: Curves.easeInOut, offset: const Offset(4, 0)),
          ),
          // Superposición visual que se muestra al ganar el nivel.
          if (gameState.isLevelComplete) _buildVictoryOverlay(gameState, l10n),
          
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
      ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primaryColor = isLight ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.5) : Colors.black26,
        border: Border(bottom: BorderSide(color: primaryColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _StatItem(
                label: l10n.text('lives_label'),
                value: '${state.lives}',
                isWarning: state.lives < 2,
                color: Colors.redAccent, 
              ).animate(target: state.lifeLostTrigger.toDouble())
               .shake(duration: 500.ms, hz: 10, offset: const Offset(5, 0))
               .tint(color: Colors.red, duration: 200.ms).then().tint(color: Colors.transparent),
              const SizedBox(width: 15),
              _StatItem(
                label: 'NIVEL',
                value: state.isDailyChallenge ? 'DIA' : '${state.levelNumber}',
                color: primaryColor,
              ),
              const SizedBox(width: 15),
              _StatItem(
                label: 'PUNTOS',
                value: '${state.score}',
                color: primaryColor,
              ),
            ],
          ),
          
          Row(
            children: [
              _StatItem(
                label: l10n.text('time_label'),
                value: '${state.timeLeft}s',
                isWarning: state.isTimerCountDown && state.timeLeft < 15,
                color: primaryColor,
              ),
              IconButton(
                icon: Icon(state.isTimerPaused ? Icons.play_arrow : Icons.pause, color: primaryColor, size: 20),
                onPressed: () => ref.read(gameProvider.notifier).togglePause(),
              ),
            ],
          ),

          IconButton(
            icon: Icon(Icons.settings, color: primaryColor),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  /// Construye la cuadrícula dinámica del puzzle.
  Widget _buildGrid(BuildContext context, GameState state, WidgetRef ref, Translations l10n) {
    if (state.currentLevel == null) return const CircularProgressIndicator();

    final size = state.currentLevel!.size;
    final screenSize = MediaQuery.of(context).size;
    final spacing = size > 20 ? 1.0 : 2.0;
    final totalGridSize = _getGridSize(size, screenSize.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        final viewHeight = constraints.maxHeight;
        final containerWidth = max(totalGridSize, viewWidth);
        final containerHeight = max(totalGridSize, viewHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.fromLTRB(800, 0, 800, 1500),
          minScale: 0.1,
          maxScale: 4.0,
          constrained: false,
          child: Container(
            width: containerWidth,
            height: containerHeight,
            alignment: Alignment.topCenter,
            color: Colors.transparent,
            child: Container(
              width: totalGridSize,
              height: totalGridSize,
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
        );
      },
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
                  ? Colors.green.withOpacity(0.3)
                  : (Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFFFFDD0) // Cream
                      : const Color(0xFF2D2D2D)), // Darker pastel
              borderRadius: BorderRadius.circular(size > 12 ? 2 : 4),
              border: Border.all(
                color: isSolved
                    ? Colors.greenAccent
                    : (cell.isFixed
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                width: isSolved ? 2.0 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                cell.currentValue ?? (cell.isFixed ? cell.value! : ''),
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontSize: (size > 30 ? 6 : (size > 25 ? 8 : (size > 20 ? 10 : (size > 12 ? 14 : 18)))) 
                    * ref.watch(settingsProvider).tileScale
                    * ((cell.currentValue?.length ?? cell.value?.length ?? 0) > 2 ? 0.8 : 1.0),
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

    final scrollbarLeft = ref.watch(settingsProvider).scrollbarOnLeft;

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      constraints: const BoxConstraints(maxHeight: 140), 
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.9) : Colors.black54,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: isLight ? Colors.black12 : Colors.white.withOpacity(0.1), width: 2)),
      ),
      child: Directionality(
        textDirection: scrollbarLeft ? TextDirection.rtl : TextDirection.ltr,
        child: RawScrollbar(
          controller: _footerScrollController,
          thumbColor: AppTheme.primaryBlue.withOpacity(0.5),
          radius: const Radius.circular(20),
          thickness: 6,
          thumbVisibility: true,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              controller: _footerScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (footerTiles.isNotEmpty) ...[
                    Text(l10n.text('numbers_label'), style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
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
          ),
        ),
      ),
    ).animate().slideY(begin: 1, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildTileGrid(List<String> tiles, {required bool isMachine}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tiles.map((value) {
        return Draggable<Map<String, dynamic>>(
          data: {'value': value, 'isMachine': isMachine},
          feedback: MathTile(value: value, size: 40, color: isMachine ? Colors.pinkAccent : null),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: MathTile(value: value, size: 35, color: isMachine ? Colors.pinkAccent : null),
          ),
          child: MathTile(value: value, size: 35, color: isMachine ? Colors.pinkAccent : null),
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

  Widget _buildVictoryOverlay(GameState state, Translations l10n) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Estrellas de fondo girando
                ...List.generate(5, (i) => 
                  Icon(Icons.star, color: Colors.amber.withOpacity(0.3), size: 250 - (i * 30))
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: (5 + i).seconds)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut)
                ),
                
                const Icon(Icons.emoji_events, color: Colors.amber, size: 120)
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .then()
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 2.seconds),
                
                const Icon(Icons.auto_awesome, color: Colors.white, size: 160)
                    .animate(onPlay: (c) => c.repeat())
                    .fadeOut(duration: 1.seconds)
                    .scale(duration: 1.seconds, begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5)),
              ],
            ),
            const SizedBox(height: 30),
            Text(
                  l10n.text('victory'),
                  style: GoogleFonts.roboto(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                    letterSpacing: 4,
                    shadows: [
                      const Shadow(color: Colors.orange, blurRadius: 30, offset: Offset(4, 4)),
                      const Shadow(color: Colors.white, blurRadius: 10),
                    ],
                  ),
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 1.5.seconds, color: Colors.white),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  '${state.timeLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).scale(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                ref.read(gameProvider.notifier).startNewLevel(state.levelNumber + 1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                elevation: 15,
                shadowColor: Colors.amberAccent,
              ),
              child: const Text(
                'SIGUIENTE',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ).animate().fadeIn(delay: 1.seconds).scale(curve: Curves.elasticOut),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }


  /// Muestra el diálogo cuando el jugador pierde todas las vidas o se queda sin tiempo.
  void _showGameOverDialog(
    BuildContext context,
    WidgetRef ref,
    GameState state,
    Translations l10n,
  ) {
    final bool isTimeUp = state.timeLeft <= 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 2)),
        title: Text(
          l10n.text('game_over'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isTimeUp ? Icons.timer_off : Icons.heart_broken, color: Colors.redAccent, size: 64),
            const SizedBox(height: 20),
            Text(
              isTimeUp ? '¡Te quedaste sin tiempo!' : '¡Te quedaste sin vidas!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '¿Quieres intentarlo de nuevo?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('SALIR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(gameProvider.notifier).startNewLevel(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(l10n.text('try_again')),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
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
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    this.isWarning = false,
    this.color,
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isWarning 
                ? Colors.redAccent 
                : (color ?? Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

extension GameScreenActions on _GameScreenState {
  Widget _buildActionButtons(GameState state, WidgetRef ref, Translations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botón Deshacer
            _ActionButton(
              onTap: () => ref.read(gameProvider.notifier).undoMove(),
              icon: Icons.undo,
              color: Colors.amber,
            ),
            const SizedBox(width: 12),
            // Botón Pista con opción de video si se agotan
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.hintsRemaining == 0)
                  GestureDetector(
                    onTap: _showRewardedAd,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent, width: 1),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.greenAccent, size: 16),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds, curve: Curves.easeInOut).shimmer(duration: 2.seconds),
                _ActionButton(
                  onTap: () => ref.read(gameProvider.notifier).useHint(),
                  icon: Icons.lightbulb,
                  label: 'HINT: ${state.hintsRemaining}',
                  color: state.hintsRemaining > 0 ? Colors.blueAccent : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Combo Badge
            if (state.comboCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.redAccent]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Text(
                  'x${state.comboCount}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ).animate().scale().shimmer(),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String? label;
  final Color color;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label!,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
