import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/puzzle_level.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/translations.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'medals_screen.dart';
import 'explain_me_screen.dart';
import 'level_editor_screen.dart';
import 'stats_screen.dart';
import '../../data/repositories/stats_repository.dart';
import '../../domain/use_cases/math_engine.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConsent();
    });
  }

  void _checkConsent() {
    final settings = ref.read(settingsProvider);
    if (settings.consentAccepted == null && settings.geography != 'global') {
      _showConsentDialog();
    }
  }

  void _showConsentDialog() {
    final l10n = ref.read(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.text('privacy_title'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.text('privacy_content'),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setConsent(false);
              Navigator.pop(context);
            },
            child: Text(
              l10n.text('reject'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setConsent(true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              elevation: 0,
            ),
            child: Text(
              l10n.text('accept'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final difficulty = ref.watch(gameProvider).difficulty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Fondo con círculos de color muy suaves
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(isDark ? 0.03 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(isDark ? 0.02 : 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Header minimalista
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildHeaderAction(
                        Icons.insights_rounded,
                        isDark ? Colors.cyanAccent : Colors.blueGrey,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderAction(
                        Icons.emoji_events_outlined,
                        Colors.amber.shade600,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MedalsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderAction(
                        Icons.settings_outlined,
                        isDark ? Colors.white70 : Colors.blueGrey,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Logo / Título
                  Column(
                    children: [
                      Image.asset(
                            'assets/images/title_logo.png',
                            height: 100,
                            fit: BoxFit.contain,
                          )
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .scale(begin: const Offset(0.95, 0.95)),
                      const SizedBox(height: 8),
                      Text(
                        l10n.text('challenge_your_mind'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: primaryColor.withOpacity(0.3),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Selector de Dificultad
                  _buildThemedDifficultySelector(
                    difficulty,
                    isDark,
                    cardBg,
                    l10n,
                  ),

                  const SizedBox(height: 40),

                  // Botón PLAY
                  _buildPremiumPlayButton(context, l10n),

                  const SizedBox(height: 24),

                  // Label "OTRAS FORMAS DE JUGAR"
                  Text(
                    l10n.text('other_ways_to_play'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Modo Optimizar
                  _buildThemedCardAction(
                    l10n.text('optimize_mode_title'),
                    null,
                    const Color(0xFF10B981),
                    cardBg,
                    isDark,
                    () async {
                      final statsRepo = StatsRepository();
                      final lastLevel = await statsRepo.getLastCompletedOptimizeLevel();
                      final totalLevels = MathEngine.getOptimizeLevelsCount();
                      
                      // Si ya terminó todo, vuelve al 1 o se queda en el último. 
                      // Por ahora, si terminó el 100, que juegue el 100 de nuevo o el 1.
                      int levelToStart = lastLevel + 1;
                      if (levelToStart > totalLevels) levelToStart = 1;
                      
                      ref.read(gameProvider.notifier).startOptimizeLevel(levelToStart);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GameScreen(),
                          ),
                        );
                      }
                    },
                    tag: l10n.text('challenge_tag'),
                    customIcon: Container(
                      width: 24,
                      height: 24,
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: 24,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade400,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 6,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade400,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Acciones secundarias
                  _buildThemedCardAction(
                    l10n.text('game_of_the_day'),
                    Icons.calendar_today_rounded,
                    Colors.amber.shade400,
                    cardBg,
                    isDark,
                    () {
                      ref.read(gameProvider.notifier).startDailyChallenge();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildThemedCardAction(
                    l10n.text('my_grids'),
                    Icons.auto_awesome_motion_rounded,
                    Colors.amber.shade400,
                    cardBg,
                    isDark,
                    () => _showMyGridsList(context, l10n),
                  ),

                  const SizedBox(height: 24),

                  // Modos Inferiores
                  Row(
                    children: [
                      Expanded(
                        child: _buildSimpleModeButton(
                          l10n.text('explain_me'),
                          Icons.help_outline_rounded,
                          isDark ? Colors.white54 : const Color(0xFF64748B),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExplainMeScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSimpleModeButton(
                          l10n.text('editor'),
                          Icons.edit_rounded,
                          Colors.amber.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LevelEditorScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),


                  const Spacer(flex: 2),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color.withOpacity(0.7), size: 26),
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildThemedDifficultySelector(
    String current,
    bool isDark,
    Color cardBg,
    Translations l10n,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: Colors.black, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: ['easy', 'medium', 'hard'].map((d) {
          final isSelected = current == d;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(gameProvider.notifier).changeDifficulty(d),
              child: AnimatedContainer(
                duration: 250.ms,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    l10n.text('${d}_mode'),
                    style: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPremiumPlayButton(BuildContext context, Translations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
          onTap: () {
            ref.read(gameProvider.notifier).startNewLevel(1);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: isDark ? null : Border.all(color: Colors.black, width: 4),
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade600.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                l10n.text('play_now'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2500.ms, color: Colors.white12);
  }

  Widget _buildThemedCardAction(
    String label,
    IconData? icon,
    Color color,
    Color cardBg,
    bool isDark,
    VoidCallback onTap, {
    String? tag,
    Widget? customIcon,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 64,
            clipBehavior: Clip.antiAlias, // Clip the ribbon
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: isDark ? null : Border.all(color: Colors.black, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center, // Center contents vertically
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (customIcon != null)
                      customIcon
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon!, color: color, size: 26),
                      ),
                    const SizedBox(width: 16),
                    Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ],
                ),
              ),
                if (tag != null)
                  Positioned(
                    right: -25,
                    top: 10,
                    child: Transform.rotate(
                      angle: 0.785398, // 45 degrees
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade400,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleModeButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: Theme.of(context).brightness == Brightness.dark 
              ? BorderSide.none 
              : const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }

  void _showMyGridsList(BuildContext context, Translations l10n) async {
    final prefs = await SharedPreferences.getInstance();
    final String? gridsJson = prefs.getString('my_custom_grids');
    final List<dynamic> savedGrids = gridsJson != null
        ? json.decode(gridsJson)
        : [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text('my_grids'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: savedGrids.isEmpty
                  ? Center(
                      child: Text(
                        l10n.text('no_saved_grids'),
                        style: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: savedGrids.length,
                      itemBuilder: (context, i) {
                        final g = savedGrids[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            leading: const Icon(
                              Icons.grid_on_rounded,
                              color: Color(0xFF8B5CF6),
                            ),
                            title: Text(
                              '${l10n.text('grid_label')} ${g['width']}x${g['height']}',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF10B981),
                              size: 30,
                            ),
                            onTap: () {
                              final List<GridCell> levelCells =
                                  (g['cells'] as List)
                                      .map(
                                        (c) => GridCell(
                                          x: c['x'],
                                          y: c['y'],
                                          type: CellType.values[c['type']],
                                          value: c['value'],
                                          isFixed: c['isFixed'] ?? true,
                                        ),
                                      )
                                      .toList();
                              final customLevel = PuzzleLevel(
                                id: g['id'],
                                size: g['width'] > g['height']
                                    ? g['width']
                                    : g['height'],
                                cells: levelCells,
                                footerTiles: [],
                              );
                              ref
                                  .read(gameProvider.notifier)
                                  .loadCustomLevel(customLevel);
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedMedalsCarousel(List<dynamic> medals, bool isDark) {
    final unlocked = medals.where((m) => m.isUnlocked).toList();
    if (unlocked.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 64,
          child: Center(
            child: ListView.builder(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: unlocked.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final medal = unlocked[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Tooltip(
                    message: medal.title,
                    child: Hero(
                      tag: 'medal_${medal.id}',
                      child: medal.unlockedAsset != null
                          ? Image.asset(
                              medal.unlockedAsset!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                            )
                          : Icon(
                              medal.iconData as IconData,
                              size: 28,
                              color: Colors.amber,
                            ),
                    ),
                  ),
                ).animate().scale(
                  delay: (index * 100).ms,
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

