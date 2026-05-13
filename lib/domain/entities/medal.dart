import 'package:flutter/material.dart';

class Medal {
  final String id;
  final String title;
  final String description;
  final dynamic iconData; // IconData (para Velocista) o null si usa assets
  final String? unlockedAsset;
  final String? lockedAsset;
  final bool isUnlocked;

  Medal({
    required this.id,
    required this.title,
    required this.description,
    this.iconData,
    this.unlockedAsset,
    this.lockedAsset,
    this.isUnlocked = false,
  });

  Medal copyWith({bool? isUnlocked}) {
    return Medal(
      id: id,
      title: title,
      description: description,
      iconData: iconData,
      unlockedAsset: unlockedAsset,
      lockedAsset: lockedAsset,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

final List<Medal> initialMedals = [
  Medal(
    id: 'first_step',
    title: 'Primer Paso',
    description: 'Completa tu primer nivel.',
    unlockedAsset: 'assets/images/trophies_final/trophy_first_step.png',
    lockedAsset: 'assets/images/trophies_final/trophy_first_step_locked.png',
  ),
  Medal(
    id: 'math_genius',
    title: 'Genio Matemático',
    description: 'Llega al nivel 10.',
    unlockedAsset: 'assets/images/trophies_final/trophy_math_genius.png',
    lockedAsset: 'assets/images/trophies_final/trophy_math_genius_locked.png',
  ),
  Medal(
    id: 'speed_runner',
    title: 'Velocista',
    description: 'Resuelve un nivel en menos de 20 segundos.',
    iconData: Icons.timer,
  ),
  Medal(
    id: 'combo_king',
    title: 'Rey del Combo',
    description: 'Logra un combo de x5.',
    unlockedAsset: 'assets/images/trophies_final/trophy_combo_king.png',
    lockedAsset: 'assets/images/trophies_final/trophy_combo_king_locked.png',
  ),
  Medal(
    id: 'expert_solver',
    title: 'Experto en Grillas',
    description: 'Completa un nivel en dificultad EXPERTO.',
    unlockedAsset: 'assets/images/trophies_final/trophy_expert_solver.png',
    lockedAsset: 'assets/images/trophies_final/trophy_expert_solver_locked.png',
  ),
  Medal(
    id: 'weekly_warrior',
    title: 'Guerrero Semanal',
    description: 'Juega 3 días en una misma semana.',
    unlockedAsset: 'assets/images/trophies_final/trophy_weekly_warrior.png',
    lockedAsset: 'assets/images/trophies_final/trophy_weekly_warrior_locked.png',
  ),
  Medal(
    id: 'monthly_legend',
    title: 'Leyenda Mensual',
    description: 'Completa el desafío diario durante 15 días.',
    unlockedAsset: 'assets/images/trophies_final/trophy_monthly_legend.png',
    lockedAsset: 'assets/images/trophies_final/trophy_monthly_legend_locked.png',
  ),
  Medal(
    id: 'optimize_25',
    title: 'Aprendiz de Optimizador',
    description: 'Completa el 25% de los niveles de Optimización.',
    iconData: Icons.trending_up_rounded,
  ),
  Medal(
    id: 'optimize_50',
    title: 'Estratega de Sumas',
    description: 'Completa el 50% de los niveles de Optimización.',
    iconData: Icons.psychology_rounded,
  ),
  Medal(
    id: 'optimize_75',
    title: 'Maestro del Cálculo',
    description: 'Completa el 75% de los niveles de Optimización.',
    iconData: Icons.workspace_premium_rounded,
  ),
  Medal(
    id: 'optimize_100',
    title: 'Leyenda de la Grilla',
    description: '¡Has completado todos los niveles de Optimización!',
    iconData: Icons.military_tech_rounded,
  ),
];
