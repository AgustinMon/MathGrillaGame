import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'medals_screen.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';

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
    final settings = ref.read(settingsProvider);
    final isUE = settings.geography == 'ue';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.primaryBlue, width: 2)),
        title: Text(
          isUE ? 'Privacidad (GDPR - UE)' : 'Privacidad (CCPA - USA)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUE 
            ? 'Para cumplir con las normas de la UE, necesitamos tu consentimiento para mostrarte anuncios personalizados.' 
            : 'Para cumplir con las normas de USA, te informamos que recolectamos datos para mejorar tu experiencia.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setConsent(false);
              Navigator.pop(context);
            },
            child: const Text('RECHAZAR', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setConsent(true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('ACEPTAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final difficulty = ref.watch(gameProvider).difficulty;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con degradado animado y patrón de cuadrícula
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.darkBg, const Color(0xFF1A1D2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Símbolos matemáticos flotantes de fondo repartidos por toda la pantalla
          ...List.generate(15, (index) {
            final symbols = ['+', '-', '×', '÷', '=', '%', '√'];
            final screenSize = MediaQuery.of(context).size;
            
            // Distribución pseudo-aleatoria basada en el índice y tamaño de pantalla
            final left = (index * 0.17 * screenSize.width) % screenSize.width;
            final top = (index * 0.13 * screenSize.height) % screenSize.height;
            final rotation = (index * 45).toDouble();
            
            return Positioned(
              left: left,
              top: top,
              child: Transform.rotate(
                angle: rotation * (3.14159 / 180),
                child: Opacity(
                  opacity: 0.04,
                  child: Text(
                    symbols[index % symbols.length],
                    style: const TextStyle(
                      fontSize: 80, 
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).moveY(
              begin: 0, end: 30, duration: (3000 + (index * 500) % 2000).ms, curve: Curves.easeInOut
            ).then().moveY(begin: 30, end: 0);
          }),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Botones de Ajustes y Medallas en la esquina
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 28),
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => MedalsScreen())
                        ),
                      ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54, size: 28),
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const SettingsScreen())
                        ),
                      ).animate().rotate(duration: 1000.ms, curve: Curves.easeInOut),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Título con estilo de juego
                  Column(
                    children: [
                      Text(
                        'CRUCI',
                        style: GoogleFonts.roboto(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 0.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: AppTheme.primaryBlue.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 10),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.5, 0.5)),
                      Text(
                        'MATH',
                        style: GoogleFonts.roboto(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          height: 0.8,
                          color: AppTheme.primaryBlue,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(6, 6), blurRadius: 10),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms).scale(begin: const Offset(0.5, 0.5)),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Selector de Dificultad mejorado
                  _buildDifficultySelector(difficulty),

                  const SizedBox(height: 40),
                  
                  // Botón Jugar Premium
                  _buildPlayButton(context),

                  const SizedBox(height: 20),
                  
                  // Botón Juego del Día
                  _buildDailyChallengeButton(context),
                  
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector(String currentDifficulty) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: ['easy', 'medium', 'hard'].map((d) {
          final isSelected = currentDifficulty == d;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(gameProvider.notifier).changeDifficulty(d),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: isSelected ? [
                    BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)
                  ] : [],
                ),
                child: Text(
                  d.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate(delay: 1000.ms).fadeIn().moveY(begin: 30);
  }

  Widget _buildPlayButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      ),
      child: Container(
        width: double.infinity,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryBlue, Color(0xFF0088FF)],
          ),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: const Center(
          child: Text(
            '¡A JUGAR!',
            style: TextStyle(
              fontFamily: 'Luckiest Guy',
              fontSize: 28,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: Colors.white24)
     .animate(delay: 1500.ms).fadeIn().moveY(begin: 50);
  }

  Widget _buildDailyChallengeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ref.read(gameProvider.notifier).startDailyChallenge();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.amberAccent.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, color: Colors.amberAccent, size: 24),
            const SizedBox(width: 12),
            const Text(
              'JUEGO DEL DÍA',
              style: TextStyle(
                fontFamily: 'Luckiest Guy',
                fontSize: 20,
                color: Colors.amberAccent,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 1200.ms).slideX(begin: -0.1);
  }
}
