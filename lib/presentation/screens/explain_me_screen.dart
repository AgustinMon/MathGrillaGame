import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/math_tile.dart';
import '../../domain/entities/puzzle_level.dart';

class ExplainMeScreen extends StatefulWidget {
  const ExplainMeScreen({super.key});

  @override
  State<ExplainMeScreen> createState() => _ExplainMeScreenState();
}

class _ExplainMeScreenState extends State<ExplainMeScreen> {
  int step = 0;
  
  final List<String> explanations = [
    "¡Bienvenido al modo 'Explícame'! Vamos a aprender cómo deducir las piezas.",
    "Mira esta fila: '_ + 4 = 5'. ¿Qué número sumado a 4 da 5?",
    "¡Exacto! Es el 1. Colocamos el 1 aquí.",
    "Ahora mira esta columna que cruza el 1: '1 * _ = 3'.",
    "Si tenemos 1 y el resultado es 3, el número debe ser 3. 1 * 3 = 3.",
    "Al cruzar ecuaciones, los números deben servir para ambas. ¡Esa es la clave!",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo Explícame')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildDemoGrid(),
                if (step > 0) _buildHighlight(),
              ],
            ),
          ),
          _buildExplanatoryModal(),
        ],
      ),
    );
  }

  Widget _buildDemoGrid() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cell(step >= 2 ? "1" : "", isTarget: step == 1),
                _op("+"),
                _cell("4"),
                _op("="),
                _cell("5"),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _op("*", vert: true),
                const SizedBox(width: 50 * 4),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cell(step >= 4 ? "3" : "", isTarget: step == 3),
                const SizedBox(width: 50 * 4),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _op("=", vert: true),
                const SizedBox(width: 50 * 4),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cell("3"),
                const SizedBox(width: 50 * 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String val, {bool isTarget = false}) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isTarget ? Colors.yellow.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
        border: Border.all(color: isTarget ? Colors.orange : Colors.blueAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: val.isEmpty 
          ? null 
          : MathTile(value: val, size: 40, animateOnEntry: true),
      ),
    ).animate(target: isTarget ? 1 : 0).shimmer();
  }

  Widget _op(String val, {bool vert = false}) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.all(2),
      child: Center(child: Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildHighlight() {
    // Simplified highlight
    return Container();
  }

  Widget _buildExplanatoryModal() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            explanations[step],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ).animate(key: ValueKey(step)).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (step < explanations.length - 1) {
                  step++;
                } else {
                  Navigator.pop(context);
                }
              });
            },
            child: Text(step < explanations.length - 1 ? 'Siguiente' : '¡Entendido!'),
          ),
        ],
      ),
    );
  }
}
