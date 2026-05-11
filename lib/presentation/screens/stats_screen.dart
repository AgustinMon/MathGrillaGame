import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/stats_repository.dart';
import '../providers/settings_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final displayPlayerName = settings.playerName.trim().isNotEmpty ? settings.playerName.trim() : 'Jugador';

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TU PERFIL',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: StatsRepository().getStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;
          final played = stats['gamesPlayed'] ?? 0;
          final won = stats['gamesWon'] ?? 0;
          final score = stats['totalScore'] ?? 0;
          final combo = stats['bestCombo'] ?? 0;
          
          final totalTime = stats['totalTime'] ?? 0;
          final bestTime = stats['bestTime'] ?? 0;
          final bestTimeEq = stats['bestTimeEq'] ?? 0;
          final hourDataStr = stats['hourData'] as String? ?? '{}';
          
          final winRate = played > 0 ? (won / played * 100).toStringAsFixed(1) : '0.0';
          
          // Calcular el promedio de tiempo
          String avgTimeText = "0s";
          if (won > 0) {
            int avgSeconds = (totalTime / won).round();
            avgTimeText = "${avgSeconds}s";
            if (avgSeconds >= 60) {
              avgTimeText = "${avgSeconds ~/ 60}m ${avgSeconds % 60}s";
            }
          }

          // Formatear el mejor tiempo
          String bestTimeText = "N/A";
          if (bestTime > 0 && bestTime < 999999) {
            bestTimeText = "${bestTime}s ($bestTimeEq cuentas)";
            if (bestTime >= 60) {
              bestTimeText = "${bestTime ~/ 60}m ${bestTime % 60}s ($bestTimeEq cuentas)";
            }
          }
          
          // Determinar el horario más rápido
          String fastestHourText = "N/A";
          try {
            final Map<String, dynamic> hourData = json.decode(hourDataStr);
            double bestAvg = double.infinity;
            String bestHour = "";
            hourData.forEach((hour, data) {
              int hTime = data['totalTime'] ?? 0;
              int hCount = data['count'] ?? 0;
              if (hCount > 0) {
                double avg = hTime / hCount;
                if (avg < bestAvg) {
                  bestAvg = avg;
                  bestHour = hour;
                }
              }
            });
            if (bestHour.isNotEmpty) {
              int h = int.parse(bestHour);
              fastestHourText = "${h.toString().padLeft(2, '0')}:00";
            }
          } catch (e) {
            // Ignorar errores de parseo JSON
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(displayPlayerName),
                const SizedBox(height: 32),
                _buildStatCard(
                  title: 'PARTIDAS JUGADAS',
                  mainText: '$played',
                  subText: 'Has completado $won exitosamente ($winRate% de victoria).',
                  icon: Icons.videogame_asset,
                  accentColor: Colors.amberAccent,
                  delay: 200.ms,
                ),
                _buildStatCard(
                  title: 'DESEMPEÑO Y TIEMPOS',
                  mainText: 'Récords',
                  subText: '⏱️ Promedio: $avgTimeText\n⚡ Mejor tiempo: $bestTimeText\n🕰️ Horario más rápido: $fastestHourText',
                  icon: Icons.timer,
                  accentColor: Colors.pinkAccent,
                  delay: 300.ms,
                ),
                _buildStatCard(
                  title: 'PUNTUACIÓN TOTAL',
                  mainText: '$score',
                  subText: 'Puntos acumulados a lo largo de tu trayectoria resolviendo grillas.',
                  icon: Icons.military_tech,
                  accentColor: Colors.cyanAccent,
                  delay: 400.ms,
                ),
                _buildStatCard(
                  title: 'MEJOR COMBO',
                  mainText: 'x$combo',
                  subText: 'El mayor encadenamiento de ecuaciones resueltas rápidamente.',
                  icon: Icons.local_fire_department,
                  accentColor: Colors.orangeAccent,
                  delay: 600.ms,
                ),
                const SizedBox(height: 40),
                Center(
                  child: Opacity(
                    opacity: 0.5,
                    child: Text(
                      'CRUCIMATH • ESTADÍSTICAS',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $name',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate().fadeIn().slideX(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Tus patrones de maestría esta semana.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white54,
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String mainText,
    required String subText,
    required IconData icon,
    required Color accentColor,
    required Duration delay,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.1), width: 1),
        gradient: LinearGradient(
          colors: [
            AppTheme.darkCard,
            accentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                icon,
                size: 120,
                color: accentColor.withOpacity(0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: accentColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    mainText,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subText,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.2, curve: Curves.easeOutQuad);
  }
}
