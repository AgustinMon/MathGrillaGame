import 'package:flutter/material.dart';

class Medal {
  final String id;
  final String title;
  final String description;
  final dynamic iconData; // IconData o Asset path
  final bool isUnlocked;

  Medal({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    this.isUnlocked = false,
  });

  Medal copyWith({bool? isUnlocked}) {
    return Medal(
      id: id,
      title: title,
      description: description,
      iconData: iconData,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

final List<Medal> initialMedals = [
  Medal(
    id: 'first_step',
    title: 'Primer Paso',
    description: 'Completa tu primer nivel.',
    iconData: Icons.emoji_events,
  ),
  Medal(
    id: 'math_genius',
    title: 'Genio Matemático',
    description: 'Llega al nivel 10.',
    iconData: Icons.workspace_premium,
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
    iconData: Icons.bolt,
  ),
  Medal(
    id: 'expert_solver',
    title: 'Experto en Grillas',
    description: 'Completa un nivel en dificultad EXPERTO.',
    iconData: Icons.military_tech,
  ),
  Medal(
    id: 'weekly_warrior',
    title: 'Guerrero Semanal',
    description: 'Juega 3 días en una misma semana.',
    iconData: Icons.calendar_month,
  ),
  Medal(
    id: 'monthly_legend',
    title: 'Leyenda Mensual',
    description: 'Completa el desafío diario durante 15 días.',
    iconData: Icons.stars,
  ),
];
