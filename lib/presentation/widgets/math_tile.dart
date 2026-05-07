import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MathTile extends StatelessWidget {
  final String value;
  final bool isDragging;
  final double size;

  const MathTile({
    super.key,
    required this.value,
    this.isDragging = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.secondaryPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
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
