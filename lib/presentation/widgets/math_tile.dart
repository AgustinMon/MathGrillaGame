import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MathTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color ?? AppTheme.primaryBlue,
            color?.withOpacity(0.8) ?? AppTheme.secondaryPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppTheme.primaryBlue).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Text(
            value,
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
