import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'medals_screen.dart';
import '../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';

class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          
          // Símbolos matemáticos flotantes de fondo
          ...List.generate(10, (index) {
            final symbols = ['+', '-', '×', '÷', '=', '%', '√'];
            final random = index * 7;
            return Positioned(
              left: (random % 300).toDouble(),
              top: (random % 600).toDouble(),
              child: Opacity(
                opacity: 0.03,
                child: Text(
                  symbols[index % symbols.length],
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).moveY(
              begin: 0, end: 20, duration: (2000 + random % 1000).ms, curve: Curves.easeInOut
            ).then().moveY(begin: 20, end: 0);
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
                        style: TextStyle(
                          fontFamily: 'Luckiest Guy',
                          fontSize: 64,
                          height: 0.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: AppTheme.primaryBlue.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 10),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.5, 0.5)),
                      Text(
                        'MATH',
                        style: TextStyle(
                          fontFamily: 'Luckiest Guy',
                          fontSize: 80,
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
                  _buildDifficultySelector(ref, difficulty),

                  const SizedBox(height: 40),
                  
                  // Botón Jugar Premium
                  _buildPlayButton(context),
                  
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector(WidgetRef ref, String currentDifficulty) {
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
}
