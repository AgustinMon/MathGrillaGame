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
    final settings = ref.read(settingsProvider);
    final isUE = settings.geography == 'ue';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        Colors.amber[700]!,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MedalsScreen()),
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

                  // Acciones secundarias
                  _buildThemedCardAction(
                    l10n.text('game_of_the_day'),
                    Icons.calendar_today_rounded,
                    const Color(0xFFF59E0B),
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
                    const Color(0xFF8B5CF6),
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
                          Icons.psychology_outlined,
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
                          isDark ? Colors.white54 : const Color(0xFF64748B),
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

                  // Link de Política de Privacidad
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.text('privacy_policy_title')),
                          content: SingleChildScrollView(
                            child: Text(l10n.text('privacy_policy_content')),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(l10n.text('understood_button')),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      l10n.text('privacy_policy_title'),
                      style: TextStyle(
                        fontSize: 10,
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.4),
                        decoration: TextDecoration.underline,
                        decorationColor: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.2),
                      ),
                    ),
                  ),
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
    IconData icon,
    Color color,
    Color cardBg,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
}
