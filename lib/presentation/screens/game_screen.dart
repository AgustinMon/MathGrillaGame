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
  bool _isInventoryCollapsed = false;

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

  void _centerGrid([Size? availableSize]) {
    if (!mounted) return;
    // La grilla se auto-ajusta al 100% del ancho en _buildGrid y se centra sola.
    // Solo reseteamos el controlador para asegurar que el usuario la vea correctamente
    // sin zoom ni desplazamientos extraños al iniciar un nivel.
    _transformationController.value = Matrix4.identity();
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-0815276588564171/1931750100', // Production ID
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Escuchamos eventos especiales para diálogos
    ref.listen(gameProvider, (previous, next) {
      if (next.isLevelComplete && !(previous?.isLevelComplete ?? false)) {
        // Ya se muestra el _buildVictoryOverlay en el Stack del body
      }
      if (next.isGameOver && !(previous?.isGameOver ?? false)) {
        _showGameOverDialog(context, ref, next, l10n);
      }
      
      if (next.levelNumber != previous?.levelNumber) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _centerGrid();
          });
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
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
          body: Stack(
            children: [
              SafeArea(
                bottom: false, 
                child: Column(
              children: [
                _buildHeader(context, gameState, ref, l10n),
                Expanded(
                  child: Container(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    width: double.infinity,
                    child: _buildGrid(context, gameState, ref, l10n),
                  ),
                ),
                _buildFooter(gameState, ref, l10n),
                const AdBanner(), 
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.indigo.shade200 : Colors.indigo.shade800;
    final textColor = isDark ? const Color(0xFFE0E0E0) : Colors.black87;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    final buttonBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    Widget buildCircularButton(IconData icon, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: buttonBg,
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withOpacity(isDark ? 0.6 : 0.3), width: 1.5),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      );
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  buildCircularButton(Icons.arrow_back, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TutorialScreen()))),
                  const SizedBox(width: 12),
                  buildCircularButton(Icons.refresh, () => ref.read(gameProvider.notifier).startNewLevel(state.levelNumber)),
                ],
              ),
              buildCircularButton(Icons.settings_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Vidas y Nivel
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${state.lives}',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${l10n.text('${state.difficulty}_mode')} ${state.levelNumber}',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              // Cartel de Combo en el centro (si aplica)
              if (state.comboCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Text(
                    'COMBO x${state.comboCount}',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ).animate().scale().shimmer()
              else
                const SizedBox.shrink(),
              // Tiempo
              GestureDetector(
                onTap: () => ref.read(gameProvider.notifier).togglePause(),
                child: Row(
                  children: [
                    Text(
                      '${(state.timeLeft ~/ 60).toString().padLeft(2, '0')}:${(state.timeLeft % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Icon(state.isTimerPaused ? Icons.play_arrow : Icons.pause, color: textColor, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye la cuadrícula dinámica del puzzle.
  Widget _buildGrid(BuildContext context, GameState state, WidgetRef ref, Translations l10n) {
    if (state.currentLevel == null) return const CircularProgressIndicator();

    final cells = state.currentLevel!.cells;
    final originalSize = state.currentLevel!.size;

    // 1. AUTO-RECORTE: Encontrar el área real del puzzle
    int minX = originalSize, maxX = 0, minY = originalSize, maxY = 0;
    bool hasContent = false;
    for (var cell in cells) {
      if (cell.type != CellType.empty) {
        minX = min(minX, cell.x);
        maxX = max(maxX, cell.x);
        minY = min(minY, cell.y);
        maxY = max(maxY, cell.y);
        hasContent = true;
      }
    }

    if (!hasContent) { minX = 0; maxX = 4; minY = 0; maxY = 4; }

    final int gridW = maxX - minX + 1;
    final int gridH = maxY - minY + 1;
    final spacing = 0.0; // Eliminamos el espacio para look de crucigrama clásico

    return LayoutBuilder(
      builder: (context, constraints) {
        // La grilla ocupa casi todo el ancho disponible, con un ligero margen
        final double availW = constraints.maxWidth - 16; 
        
        // El tamaño de celda se calcula para llenar el ancho del teléfono
        final double cellSize = (availW - (spacing * (gridW - 1))) / gridW;
        
        final double finalW = (cellSize * gridW) + (spacing * (gridW - 1));
        final double finalH = (cellSize * gridH) + (spacing * (gridH - 1));

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.symmetric(vertical: 800, horizontal: 200),
          minScale: 0.5,
          maxScale: 3.0,
          constrained: false,
          child: Container(
            width: finalW,
            height: max(finalH, constraints.maxHeight),
            alignment: Alignment.center,
            child: SizedBox(
              width: finalW,
              height: finalH,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridW,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: gridW * gridH,
                itemBuilder: (context, index) {
                  final x = minX + (index % gridW);
                  final y = minY + (index ~/ gridW);
                  final cell = cells.firstWhere(
                    (c) => c.x == x && c.y == y,
                    orElse: () => GridCell(x: x, y: y, type: CellType.empty),
                  );
                  
                  // Si la celda es totalmente vacía (fuera del camino del crucigrama), 
                  // no dibujamos nada para mantener la estética de crucigrama.
                  if (cell.type == CellType.empty) return const SizedBox.shrink();

                  return _buildCell(cell, state, ref, l10n, cellSize);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye una celda individual que puede aceptar piezas arrastradas.
  Widget _buildCell(GridCell cell, GameState state, WidgetRef ref, Translations l10n, double cellSize) {
    // Verificamos si esta celda es parte de una ecuación ya resuelta.
    final isSolved = state.solvedCells.contains('${cell.x},${cell.y}');

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
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
          child: MathTile(
            value: cell.currentValue ?? (cell.isFixed ? cell.value! : ''),
            size: cellSize,
            color: isSolved ? Colors.green : (cell.isFixed ? null : Colors.blueAccent),
            animateOnEntry: cell.currentValue != null,
          ),
        );
      },
    );
  }

  Widget _buildFooter(GameState state, WidgetRef ref, Translations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final footerTiles = List<String>.from(state.currentLevel?.footerTiles ?? [])..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final machineTiles = List<String>.from(state.machineTiles)..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    
    if (footerTiles.isEmpty && machineTiles.isEmpty && state.machineInputA == null && state.machineInputB == null) return const SizedBox.shrink();

    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isInventoryCollapsed = !_isInventoryCollapsed),
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 0) {
                    setState(() => _isInventoryCollapsed = true);
                  } else if (details.primaryVelocity! < 0) {
                    setState(() => _isInventoryCollapsed = false);
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent, // Asegura que se detecten los toques
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isInventoryCollapsed 
                ? const SizedBox(width: double.infinity)
                : Container(
                    constraints: const BoxConstraints(maxHeight: 350),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (footerTiles.isNotEmpty) _buildTileGrid(footerTiles, isMachine: false),
                          if (machineTiles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildTileGrid(machineTiles, isMachine: true),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ActionButton(
                                onTap: () => ref.read(gameProvider.notifier).undoMove(),
                                icon: Icons.undo,
                                color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
                              ),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _ActionButton(
                                    onTap: () => ref.read(gameProvider.notifier).useHint(),
                                    icon: Icons.lightbulb,
                                    color: Colors.amber.shade700,
                                    isFilled: true,
                                    badgeNumber: state.hintsRemaining,
                                  ),
                                  if (state.hintsRemaining == 0)
                                    Positioned(
                                      right: -5,
                                      top: -5,
                                      child: GestureDetector(
                                        onTap: _showRewardedAd,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileGrid(List<String> tiles, {required bool isMachine}) {
    final screenSize = MediaQuery.of(context).size;
    final double inventorySize = (screenSize.width / 9 * 0.85).clamp(40.0, 50.0);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: tiles.map((value) {
        return Draggable<Map<String, dynamic>>(
          data: {'value': value, 'isMachine': isMachine},
          feedback: MathTile(value: value, size: inventorySize + 5, color: isMachine ? Colors.pinkAccent : null, isInventory: true),
          childWhenDragging: Opacity(
            opacity: 0.2,
            child: MathTile(value: value, size: inventorySize, color: isMachine ? Colors.pinkAccent : null, isInventory: true),
          ),
          child: MathTile(value: value, size: inventorySize, color: isMachine ? Colors.pinkAccent : null, isInventory: true),
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


class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final bool isFilled;
  final int? badgeNumber;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.color,
    this.isFilled = false,
    this.badgeNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isFilled ? color.withOpacity(isDark ? 0.2 : 0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(isDark ? 0.6 : 0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          if (badgeNumber != null && badgeNumber! > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeNumber',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
