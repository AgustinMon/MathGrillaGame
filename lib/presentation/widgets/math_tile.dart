import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

class MathTile extends ConsumerWidget {
  final String value;
  final bool isDragging;
  final double size;
  final Color? color;

  const MathTile({
    super.key,
    required this.value,
    this.isDragging = false,
    this.size = 60,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scaledSize = size * settings.tileScale;

    return Container(
      width: scaledSize,
      height: scaledSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color ?? AppTheme.primaryBlue,
            color?.withOpacity(0.8) ?? AppTheme.secondaryPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(scaledSize * 0.2),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppTheme.primaryBlue).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, scaledSize * 0.06),
          ),
        ],
      ),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Text(
            value,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(
              fontSize: scaledSize * 0.35,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
