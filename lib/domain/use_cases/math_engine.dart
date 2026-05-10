import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../entities/puzzle_level.dart';

class MathEngine {
  static final Random _random = Random();
  static Map<String, List<PuzzleLevel>> _levelsByDifficulty = {
    'easy': [],
    'medium': [],
    'hard': [],
  };

  /// Carga los niveles pre-diseñados desde los archivos JSON de assets.
  static Future<void> loadLevels() async {
    // Desactivamos la carga de niveles fijos para evitar números gigantes heredados de assets antiguos.
    _levelsByDifficulty = {'easy': [], 'medium': [], 'hard': []};
    debugPrint('✅ CRUCIMATH: Niveles fijos desactivados. Todo será procedural y controlado.');
  }

  /// Retorna la cantidad de niveles disponibles para una dificultad.
  static int getLevelsCount(String difficulty) {
    return _levelsByDifficulty[difficulty]?.length ?? 0;
  }

  /// Genera o recupera un nivel según el [levelId] y la [difficulty].
  static PuzzleLevel generateLevel(int levelId, {String difficulty = 'medium'}) {
    final list = _levelsByDifficulty[difficulty] ?? [];
    
    // Si tenemos el nivel pre-diseñado para esta dificultad, lo usamos.
    if (levelId > 0 && levelId <= list.length) {
      final level = list[levelId - 1];
      if (difficulty == 'hard') {
        return _applyHardModeSplitting(level);
      }
      return level;
    }

    // Fallback procedural con lógica escalada
    int size = 7; 
    if (difficulty == 'medium') size = 13; // Más grande para permitir más cruces
    if (difficulty == 'hard') size = 18;

    if (levelId >= 15) {
      size = (size * 1.4).toInt();
    } else if (levelId >= 8) {
      size = (size * 1.2).toInt();
    }
    size = size.clamp(7, 35);
    size = size.clamp(7, 30);

    // Intentamos generar un nivel con la densidad deseada.
    // Solo permitimos intersecciones para garantizar que todo esté conectado.
    for (int attempt = 0; attempt < 50; attempt++) {
      List<GridCell> cells = [];
      List<String> footerTiles = [];
      List<String> allowedOps = ['+', '-'];
      
      if (difficulty == 'medium') {
        allowedOps.add('*');
        if (levelId >= 3) allowedOps.add('/');
      } else if (difficulty == 'hard') {
        allowedOps.addAll(['*', '/']);
      } else {
        if (levelId >= 3) allowedOps.add('*');
        if (levelId >= 10) allowedOps.add('/');
      }

      // 1. Añadimos la primera operación en el centro
      _addOperation(cells, size ~/ 2 - 2, size ~/ 2, true, footerTiles, allowedOps, size, levelId, difficulty);

      if (levelId >= 3) allowedOps.add('*');
      if (levelId >= 10) allowedOps.add('/');

      // 2. Calculamos el objetivo de operaciones según dificultad
      int targetOps = 3;
      if (difficulty == 'medium') targetOps = 8 + (levelId ~/ 3);
      if (difficulty == 'hard') targetOps = 15 + (levelId ~/ 2);
      targetOps = targetOps.clamp(3, 30);
      
      int successfulOps = 1;

      for (int o = 0; o < targetOps * 2 && successfulOps < targetOps; o++) {
        var numberCells = cells.where((c) => c.type == CellType.number).toList()..shuffle();
        for (var target in numberCells) {
          int oldLen = cells.length;
          // Cruzamos la orientación de la celda objetivo
          _addIntersectingOperation(
            cells, target.x, target.y, !target.isHorizontal, footerTiles, allowedOps, 
            target.value!, size, levelId, difficulty,
          );
          if (cells.length > oldLen) {
            successfulOps++;
            break;
          }
        }
      }

      // Si el nivel tiene al menos el 70% de las operaciones deseadas, lo aceptamos.
      if (successfulOps >= (targetOps * 0.7).toInt().clamp(2, 20)) {
        footerTiles.shuffle();
        
        final baseLevel = PuzzleLevel(
          id: levelId,
          size: size,
          cells: cells,
          footerTiles: footerTiles,
        );

        if (difficulty == 'hard') {
          return _applyHardModeSplitting(baseLevel);
        }

        return baseLevel;
      }
    }

    // Si fallan todos los intentos de cruce, generamos un nivel con dos operaciones paralelas
    // para asegurar que al menos haya algo de juego.
    return _generateRobustSimpleLevel(levelId, size, difficulty);
  }

  static PuzzleLevel _generateRobustSimpleLevel(int levelId, int size, String difficulty) {
    List<GridCell> cells = [];
    List<String> footerTiles = [];
    List<String> allowedOps = ['+', '-'];
    if (levelId >= 3) allowedOps.add('*');
    
    _addOperation(cells, 1, 1, true, footerTiles, allowedOps, size, levelId, difficulty);
    _addOperation(cells, 1, 3, true, footerTiles, allowedOps, size, levelId, difficulty);
    
    return PuzzleLevel(id: levelId, size: size, cells: cells, footerTiles: footerTiles);
  }

  /// Añade una operación matemática simple (a op b = res) a la lista de celdas.
  static void _addOperation(
    List<GridCell> cells,
    int startX,
    int startY,
    bool horizontal,
    List<String> footer,
    List<String> allowedOps,
    int size,
    int levelId,
    String difficulty,
  ) {
    var opData = _generateValidOp(allowedOps, levelId);
    List<String> parts = [
      opData.a.toString(),
      opData.op,
      opData.b.toString(),
      '=',
      opData.res.toString(),
    ];

    // Verificamos si la operación completa cabe dentro de los límites del tablero.
    if (!_fits(startX, startY, horizontal, parts.length, size)) return;

    // Decidimos qué números serán fijos ANTES de crear las celdas para asegurar que al menos uno vaya al footer.
    List<int> numberIndices = [0, 2, 4];
    List<int> fixedIndices = [];
    double fixedProb = (difficulty == 'easy') ? 0.3 : (difficulty == 'medium' ? 0.2 : 0.1);
    
    for (int idx in numberIndices) {
      if (_random.nextDouble() < fixedProb) {
        fixedIndices.add(idx);
      }
    }
    
    // Regla de Oro: Nunca fijar los 3 números de una ecuación.
    // En Medium/Hard, máximo 1 número fijo por ecuación nueva.
    int maxFixed = (difficulty == 'easy') ? 2 : 1;
    while (fixedIndices.length > maxFixed) {
      fixedIndices.removeAt(_random.nextInt(fixedIndices.length));
    }
    // Asegurar al menos uno NO fijo siempre
    if (fixedIndices.length >= 3) fixedIndices.removeAt(0);

    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      bool forceFixed = fixedIndices.contains(i);
      bool forceFooter = numberIndices.contains(i) && !fixedIndices.contains(i);
      
      _createAndAddCell(cells, x, y, parts[i], footer, levelId, horizontal, difficulty, 
          forceFixed: forceFixed, forceFooter: forceFooter);
    }
  }

  /// Añade una operación que intersecta con una celda numérica existente.
  static void _addIntersectingOperation(
    List<GridCell> cells,
    int intersectX,
    int intersectY,
    bool horizontal,
    List<String> footer,
    List<String> ops,
    String targetValue,
    int size,
    int levelId,
    String difficulty,
  ) {
    int tVal = int.tryParse(targetValue) ?? 0;
    
    // Intentamos cruzar por las 3 posiciones posibles de la nueva ecuación:
    // 0: target es 'a', 1: target es 'b', 2: target es 'res'
    // Barajamos las posiciones para mayor variedad
    var positions = [0, 1, 2]..shuffle();
    
    for (int pos in positions) {
      _OpData? opData = _generateOpWithTarget(ops, tVal, pos, levelId);
      if (opData == null) continue;

      List<String> parts = [
        opData.a.toString(),
        opData.op,
        opData.b.toString(),
        '=',
        opData.res.toString(),
      ];

      // Calculamos el inicio según la posición de la intersección
      int intersectionIndex = (pos == 0) ? 0 : (pos == 1 ? 2 : 4);
      int adjustedStartX = horizontal ? intersectX - intersectionIndex : intersectX;
      int adjustedStartY = horizontal ? intersectY : intersectY - intersectionIndex;

      if (!_fits(adjustedStartX, adjustedStartY, horizontal, parts.length, size)) continue;

      // Verificación de conflictos
      bool conflict = false;
      for (int i = 0; i < parts.length; i++) {
        int x = horizontal ? adjustedStartX + i : adjustedStartX;
        int y = horizontal ? adjustedStartY : adjustedStartY + i;
        var existing = cells.where((c) => c.x == x && c.y == y).toList();
        if (existing.isNotEmpty && existing.first.value != parts[i]) {
          conflict = true;
          break;
        }
      }
      if (conflict) continue;

      // Si llegamos aquí, la posición es válida. Añadimos y terminamos.
      // Decidimos qué números adicionales (los que no son la intersección) serán fijos.
      List<int> numberIndices = [0, 2, 4];
      int intersectIdx = (pos == 0) ? 0 : (pos == 1 ? 2 : 4);
      List<int> otherIndices = numberIndices.where((idx) => idx != intersectIdx).toList();
      
      List<int> fixedIndices = [];
      // La intersección ya tiene su estado (fijo o no), así que solo decidimos para los otros 2.
      double fixedProb = (difficulty == 'easy') ? 0.25 : (difficulty == 'medium' ? 0.15 : 0.05);
      
      for (int idx in otherIndices) {
        if (_random.nextDouble() < fixedProb) fixedIndices.add(idx);
      }

      // Verificamos si la intersección ya es fija
      var existingIntersect = cells.firstWhere((c) => c.x == intersectX && c.y == intersectY);
      int totalFixedInEq = fixedIndices.length + (existingIntersect.isFixed ? 1 : 0);
      
      // Aplicamos límites de dificultad
      int maxFixed = (difficulty == 'easy') ? 2 : 1;
      while (totalFixedInEq > maxFixed && fixedIndices.isNotEmpty) {
        fixedIndices.removeAt(0);
        totalFixedInEq--;
      }

      for (int i = 0; i < parts.length; i++) {
        int x = horizontal ? adjustedStartX + i : adjustedStartX;
        int y = horizontal ? adjustedStartY : adjustedStartY + i;
        var existing = cells.where((c) => c.x == x && c.y == y).toList();
        if (existing.isEmpty) {
          bool forceFixed = fixedIndices.contains(i);
          bool forceFooter = numberIndices.contains(i) && !fixedIndices.contains(i);
          _createAndAddCell(cells, x, y, parts[i], footer, levelId, horizontal, difficulty,
              forceFixed: forceFixed, forceFooter: forceFooter);
        }
      }
      return; // Operación añadida con éxito
    }
  }

  /// Genera una op que contiene el valor [t] en la posición [pos].
  static _OpData? _generateOpWithTarget(List<String> ops, int t, int pos, int levelId) {
    int maxNum = (20 + (levelId * 2)).clamp(10, 100);
    String op = ops[_random.nextInt(ops.length)];
    int a = 0, b = 0, res = 0;

    for (int retry = 0; retry < 50; retry++) {
      if (pos == 0) { // Target es 'a'
        a = t; b = _random.nextInt(maxNum) + 1;
        if (op == '/') { b = (_random.nextInt(9) + 2).clamp(2, a > 0 ? a : 10); a = (a ~/ b) * b; }
      } else if (pos == 1) { // Target es 'b'
        b = t; a = _random.nextInt(maxNum) + 1;
        if (op == '/') { a = b * (_random.nextInt(10) + 1); }
        if (op == '-' && a < b) a = b + _random.nextInt(maxNum);
      } else { // Target es 'res'
        res = t;
        if (op == '+') { a = _random.nextInt(res.clamp(1, 1000)); b = res - a; }
        else if (op == '-') { b = _random.nextInt(maxNum); a = res + b; }
        else if (op == '*') { 
          var factors = []; for(int i=1; i<=res; i++) if(res%i==0) factors.add(i);
          if (factors.isEmpty) return null; a = factors[_random.nextInt(factors.length)]; b = res ~/ a;
        } else { b = (_random.nextInt(10) + 1); a = res * b; }
      }

      if (op == '+') res = a + b; 
      if (op == '-') res = a - b; 
      if (op == '*') res = a * b; 
      if (op == '/') { if (b == 0) b = 1; res = a ~/ b; }
      
      // Validar límites de 3 cifras (999) y lógica
      if (res >= 0 && res <= 999 && a >= 0 && a <= 999 && b >= 0 && b <= 999) {
        // Para multiplicación, evitar que ambos sean grandes para mantenerlo mentalmente factible
        if (op == '*' && (a > 50 || b > 50)) continue;
        return _OpData(a, op, b, res);
      }
    }
    return null;
  }

  /// Comprueba si una secuencia de celdas cabe en el tablero actual.
  static bool _fits(int x, int y, bool horiz, int len, int size) {
    if (horiz) {
      return x >= 0 && x + len <= size && y >= 0 && y < size;
    } else {
      return x >= 0 && x < size && y >= 0 && y + len <= size;
    }
  }

  /// Crea una celda individual y decide si su valor estará oculto (en el footer) o fijo.
  static void _createAndAddCell(
    List<GridCell> cells,
    int x,
    int y,
    String val,
    List<String> footer,
    int levelId,
    bool isHorizontal,
    String difficulty, {
    bool? forceFixed,
    bool? forceFooter,
  }) {
    CellType type = _getCellType(val);
    
    // FILTRO DE SEGURIDAD ABSOLUTO: Si por algún motivo llega un número > 999, abortamos la celda.
    if (type == CellType.number) {
      int? numVal = int.tryParse(val);
      if (numVal != null && (numVal > 999 || numVal < 0)) return;
    }

    bool shouldBeFixed = false;

    // Los operadores (+, -, =, etc) siempre son fijos y visibles.
    if (type == CellType.operator || type == CellType.equals) {
      shouldBeFixed = true;
    } else {
      if (forceFixed == true) {
        shouldBeFixed = true;
      } else if (forceFooter == true) {
        shouldBeFixed = false;
      } else {
        // Fallback (solo para celdas que no pasaron por la lógica de ecuación, si las hay)
        double fixedProb = (difficulty == 'easy') ? 0.2 : 0.1;
        shouldBeFixed = _random.nextDouble() < fixedProb;
      }
    }

    // Si el número no es fijo, se añade a la lista de piezas que el jugador debe colocar.
    if (!shouldBeFixed) footer.add(val);

    cells.add(
      GridCell(
        x: x,
        y: y,
        type: type,
        value: val,
        currentValue: shouldBeFixed ? val : null,
        isFixed: shouldBeFixed,
        isHorizontal: isHorizontal,
      ),
    );
  }

  /// Genera una operación matemática válida aleatoria.
  /// La dificultad escala con el [levelId].
  static _OpData _generateValidOp(List<String> ops, int levelId) {
    int maxNum = (10 + (levelId * 2)).clamp(10, 100);
    
    while (true) {
      String op = ops[_random.nextInt(ops.length)];
      int a = _random.nextInt(maxNum) + 1;
      int b = _random.nextInt(maxNum) + 1;
      int res = 0;

      if (op == '+') res = a + b;
      if (op == '-') { if (a < b) { int temp = a; a = b; b = temp; } res = a - b; }
      if (op == '*') { 
        // Para multiplicación, limitar para que sea mentalmente posible y < 1000
        a = _random.nextInt(30) + 2;
        b = _random.nextInt(15) + 2;
        res = a * b; 
      }
      if (op == '/') {
        b = _random.nextInt(12) + 2;
        a = b * (_random.nextInt(15) + 1);
        res = a ~/ b;
      }

      if (res >= 0 && res <= 999 && a >= 0 && a <= 999 && b >= 0 && b <= 999) {
        if (op == '*' && (a > 50 || b > 50)) continue;
        return _OpData(a, op, b, res);
      }
    }
  }

  /// Genera una operación matemática que contenga un número específico (target).
  /// La dificultad escala con el [levelId].
  static _OpData? _generateValidOpWithTarget(
    List<String> ops,
    int target,
    bool targetIsA,
    int levelId,
  ) {
    int maxNum = (20 + (levelId * 4)).clamp(10, 100);

    List<String> shuffledOps = List.from(ops)..shuffle();
    for (var op in shuffledOps) {
      for (int i = 0; i < 50; i++) {
        int a, b, res;
        if (targetIsA) {
          a = target;
          b = _random.nextInt(maxNum) + 1;
          if (op == '*' && b == 1) continue;
          if (op == '/' && (b == 1 || a % b != 0)) continue;
          if (op == '-' && a < b) continue;
        } else {
          b = target;
          a = _random.nextInt(maxNum) + 1;
          if (op == '*' && a == 1) continue;
          if (op == '/' && (b == 1 || a % b != 0)) continue;
          if (op == '-' && a < b) continue;
        }

        res = 0;
        if (op == '+') res = a + b;
        if (op == '-') res = a - b;
        if (op == '*') res = a * b;
        if (op == '/') res = a ~/ b;

        if (res < 0 || res > 999) continue;
        if (res == target) continue;
        // Evitamos redundancia en niveles altos.
        if (levelId > 20 && (a < 5 || b < 5) && (op == '+' || op == '-')) continue;

        return _OpData(a, op, b, res);
      }
    }
    return null;
  }

  static PuzzleLevel _applyHardModeSplitting(PuzzleLevel level) {
    List<String> machineTiles = [];
    List<String> newFooter = [];
    int splitCount = 0;
    bool hasSplit = false;
    
    for (var tile in level.footerTiles) {
      int? val = int.tryParse(tile);
      // Limitamos a un máximo de 3 splits (6 números rosas) para que no sea frustrante
      if (val != null && val > 2 && splitCount < 3 && (_random.nextDouble() < 0.7 || !hasSplit)) {
        int a = _random.nextInt(val - 1) + 1;
        int b = val - a;
        machineTiles.add(a.toString());
        machineTiles.add(b.toString());
        hasSplit = true;
        splitCount++;
      } else {
        newFooter.add(tile);
      }
    }
    
    return PuzzleLevel(
      id: level.id,
      size: level.size,
      cells: level.cells,
      footerTiles: newFooter,
      machineTiles: machineTiles,
    );
  }

  static CellType _getCellType(String val) {
    if (val == '=') return CellType.equals;
    if (['+', '-', '*', '/'].contains(val)) return CellType.operator;
    return CellType.number;
  }
}

/// Estructura interna para manejar los datos de una operación temporalmente.
class _OpData {
  final int a, b, res;
  final String op;
  _OpData(this.a, this.op, this.b, this.res);
}
