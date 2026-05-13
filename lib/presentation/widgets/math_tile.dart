import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';

class MathTile extends ConsumerWidget {
  final String value;
  final bool isDragging;
  final double size;
  final Color? color;
  final bool animateOnEntry;
  final bool isInventory;

  const MathTile({
    super.key,
    required this.value,
    this.isDragging = false,
    this.size = 60,
    this.color,
    this.animateOnEntry = true,
    this.isInventory = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scaledSize = size * settings.tileScale;

    // Efecto de inercia/peso: El texto se ajusta según el tamaño de forma más robusta
    double fontSize =
        scaledSize *
        (value.length > 3 ? 0.25 : (value.length > 2 ? 0.3 : 0.45));

    // Agrandamos los símbolos un poco más para que resalten
    if (value.trim().isNotEmpty && int.tryParse(value.trim()) == null) {
      fontSize += 4;
    } else if (isInventory &&
        value.trim().length < 3 &&
        int.tryParse(value.trim()) != null) {
      // Achicamos los números del inventario de 1 y 2 cifras (1 punto)
      fontSize -= 1;
    }

    // Reducción adicional pedida por el usuario para tamaño normal y grande
    if (settings.tileScale >= 1.0) {
      fontSize -= 1;
    }
    final bool isEmpty = value.trim().isEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores basados en el nuevo diseño clásico y claro
    Color bgColor;
    Color borderColor;
    Color textColor;
    double borderWidth = 1.0;

    if (isEmpty) {
      // Celda vacía en la grilla
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      borderColor = isDark ? Colors.white54 : Colors.black87;
      textColor = Colors.transparent;
    } else if (isInventory) {
      // Fichas en el inventario
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      borderColor = isDark
          ? const Color(0xFF3A332C)
          : Colors.blue.shade600; // Marrón igual a la grilla para el borde
      textColor = isDark
          ? Colors.white
          : Colors.indigo.shade900; // Blanco para el texto
      borderWidth = 1.5;
    } else {
      // Celda con texto en la grilla (fija o colocada)
      bgColor = isDark
          ? const Color(0xFF3A332C)
          : const Color(0xFF318CE7); // Marrón oscuro o Azul Francia
      borderColor = isDark
          ? Colors.white54
          : const Color(0xFF1F6EBD); // Borde azul oscuro en modo claro
      textColor = isDark ? const Color(0xFFE0E0E0) : Colors.white;

      // Si explícitamente se pasa un color verde de resuelto, podemos teñir suavemente
      if (color == Colors.green) {
        bgColor = isDark
            ? const Color(0xFF1B5E20)
            : const Color(0xFFE8F5E9); // Verde muy suave
      } else if (color == Colors.yellow.shade700) {
        bgColor = isDark
            ? const Color(0xFF5A4A00)
            : const Color(0xFFFFF9C4); // Amarillo oscuro suave
        borderColor = isDark ? Colors.amber.shade700 : Colors.amber.shade900;
      }
    }

    Widget tile = Container(
      width: scaledSize,
      height: scaledSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2), // Bordes casi cuadrados
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Text(
            value,
            overflow: TextOverflow.visible,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.0,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400, // Fuente normal, no extra bold
              color: textColor,
            ),
          ),
        ),
      ),
    );

    if (animateOnEntry) {
      tile = tile
          .animate(
            onPlay: (controller) {
              // Haptic feedback al "caer"
              HapticFeedback.lightImpact();
            },
          )
          .scale(
            begin: const Offset(1.5, 1.5),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.bounceOut,
          )
          .fadeIn(duration: 200.ms)
          .shake(hz: 4, duration: 400.ms, curve: Curves.easeInOut);
    }

    return tile;
  }
}
