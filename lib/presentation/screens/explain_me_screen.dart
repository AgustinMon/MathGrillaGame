import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/translations.dart';
import '../widgets/math_tile.dart';
import '../../domain/entities/puzzle_level.dart';

class ExplainMeScreen extends ConsumerStatefulWidget {
  const ExplainMeScreen({super.key});

  @override
  ConsumerState<ExplainMeScreen> createState() => _ExplainMeScreenState();
}

class _ExplainMeScreenState extends ConsumerState<ExplainMeScreen> {
  int step = 0;
  
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    
    final List<String> explanations = [
      l10n.text('explanation_0'),
      l10n.text('explanation_1'),
      l10n.text('explanation_2'),
      l10n.text('explanation_3'),
      l10n.text('explanation_4'),
      l10n.text('explanation_5'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('explain_me_title'))),
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
          _buildExplanatoryModal(l10n, explanations),
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

  Widget _buildExplanatoryModal(Translations l10n, List<String> explanations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            explanations[step],
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
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
            child: Text(step < explanations.length - 1 ? l10n.text('next_button') : l10n.text('understood_button')),
          ),
        ],
      ),
    );
  }
}
