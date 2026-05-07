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
    for (var diff in ['easy', 'medium', 'hard']) {
      try {
        final String jsonStr = await rootBundle.loadString('assets/levels_$diff.json');
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _levelsByDifficulty[diff] = jsonList.map((j) => PuzzleLevel.fromJson(j)).toList();
        debugPrint('✅ CRUCIMATH: Cargados ${_levelsByDifficulty[diff]!.length} niveles para $diff.');
      } catch (e) {
        debugPrint('❌ CRUCIMATH: Error cargando niveles para $diff: $e');
      }
    }
  }

  /// Genera o recupera un nivel según el [levelId] y la [difficulty].
  static PuzzleLevel generateLevel(int levelId, {String difficulty = 'medium'}) {
    final list = _levelsByDifficulty[difficulty] ?? [];
    
    // Si tenemos el nivel pre-diseñado para esta dificultad, lo usamos.
    if (levelId > 0 && levelId <= list.length) {
      return list[levelId - 1];
    }

    // Fallback procedural con lógica escalada
    int size = 7; // Mínimo 7 para permitir cruces decentes
    if (levelId >= 20) {
      size = 18;
    } else if (levelId >= 10) {
      size = 12;
    } else if (levelId >= 5) {
      size = 9;
    }

    // Intentamos generar un nivel con la densidad deseada.
    // Solo permitimos intersecciones para garantizar que todo esté conectado.
    for (int attempt = 0; attempt < 50; attempt++) {
      List<GridCell> cells = [];
      List<String> footerTiles = [];
      List<String> allowedOps = ['+', '-'];
      
      if (levelId >= 3) allowedOps.add('*');
      if (levelId >= 10) allowedOps.add('/');

      // 1. Colocamos la primera operación central.
      _addOperation(cells, 0, _random.nextInt(size - 4), true, footerTiles, allowedOps, size, levelId);

      // 2. Añadimos el resto de operaciones asegurando que se crucen.
      int targetOps = 3 + (levelId ~/ 2).clamp(0, 10);
      int successfulOps = 1;

      for (int o = 0; o < targetOps * 2 && successfulOps < targetOps; o++) {
        var numberCells = cells.where((c) => c.type == CellType.number).toList()..shuffle();
        for (var target in numberCells) {
          int oldLen = cells.length;
          // Cruzamos la orientación de la celda objetivo
          _addIntersectingOperation(
            cells, target.x, target.y, !target.isHorizontal, footerTiles, allowedOps, 
            target.value!, size, levelId,
          );
          if (cells.length > oldLen) {
            successfulOps++;
            break;
          }
        }
      }

      // Si el nivel tiene al menos 2 o 3 operaciones, lo aceptamos.
      if (successfulOps >= (levelId < 5 ? 2 : 3)) {
        footerTiles.shuffle();
        return PuzzleLevel(
          id: levelId,
          size: size,
          cells: cells,
          footerTiles: footerTiles,
        );
      }
    }

    // Si fallan todos los intentos de cruce, generamos un nivel con dos operaciones paralelas
    // para asegurar que al menos haya algo de juego.
    return _generateRobustSimpleLevel(levelId, size);
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

    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      _createAndAddCell(cells, x, y, parts[i], footer, levelId, horizontal);
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
      for (int i = 0; i < parts.length; i++) {
        int x = horizontal ? adjustedStartX + i : adjustedStartX;
        int y = horizontal ? adjustedStartY : adjustedStartY + i;
        var existing = cells.where((c) => c.x == x && c.y == y).toList();
        if (existing.isEmpty) {
          _createAndAddCell(cells, x, y, parts[i], footer, levelId, horizontal);
        }
      }
      return; // Operación añadida con éxito
    }
  }

  /// Genera una op que contiene el valor [t] en la posición [pos].
  static _OpData? _generateOpWithTarget(List<String> ops, int t, int pos, int levelId) {
    int maxNum = 20 + (levelId * 5);
    String op = ops[_random.nextInt(ops.length)];
    int a = 0, b = 0, res = 0;

    if (pos == 0) { // Target es 'a'
      a = t; b = _random.nextInt(maxNum) + 1;
      if (op == '/') { b = _random.nextInt(9) + 2; a = (a ~/ b) * b; if (a == 0) return null; }
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
      } else { b = _random.nextInt(10) + 1; a = res * b; }
      return _OpData(a, op, b, res);
    }

    if (op == '+') res = a + b; 
    if (op == '-') res = a - b; 
    if (op == '*') res = a * b; 
    if (op == '/') { if (b == 0) b = 1; res = a ~/ b; }
    
    return _OpData(a, op, b, res);
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
  ) {
    CellType type = _getCellType(val);
    bool shouldBeFixed = false;

    // Los operadores (+, -, =, etc) siempre son fijos y visibles.
    if (type == CellType.operator || type == CellType.equals) {
      shouldBeFixed = true;
    } else {
      // La probabilidad de dar pistas (números fijos) disminuye con el nivel.
      double fixedProb = 0.3 / (1 + (levelId / 10));
      if (_random.nextDouble() < fixedProb) shouldBeFixed = true;
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
    // Aumentamos el rango de los números según el nivel.
    int maxNum = 10 + (levelId * 3);
    if (maxNum > 200) maxNum = 200; // Cap de dificultad razonable.

    for (int i = 0; i < 100; i++) {
      String op = ops[_random.nextInt(ops.length)];
      int a = _random.nextInt(maxNum) + 2;
      int b = _random.nextInt(maxNum) + 2;

      if (op == '-' && a < b) { int t = a; a = b; b = t; }
      if (op == '/' ) {
        int res = _random.nextInt(maxNum ~/ 5 + 5) + 1;
        b = _random.nextInt(12) + 2; 
        a = res * b;
      }
      
      if (op == '*' && (a == 1 || b == 1)) continue;

      int res = 0;
      if (op == '+') res = a + b;
      if (op == '-') res = a - b;
      if (op == '*') res = a * b;
      if (op == '/') res = a ~/ b;

      // Filtramos resultados demasiado grandes o negativos.
      if (res < 0 || res > 500) continue;
      // Evitamos resultados demasiado simples en niveles altos.
      if (levelId > 10 && res < 10 && _random.nextDouble() < 0.8) continue;

      return _OpData(a, op, b, res);
    }
    return _OpData(10, '+', 10, 20); 
  }

  /// Genera una operación matemática que contenga un número específico (target).
  /// La dificultad escala con el [levelId].
  static _OpData? _generateValidOpWithTarget(
    List<String> ops,
    int target,
    bool targetIsA,
    int levelId,
  ) {
    int maxNum = 20 + (levelId * 4);
    if (maxNum > 300) maxNum = 300;

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

        if (res < 0 || res > 500) continue;
        if (res == target) continue;
        // Evitamos redundancia en niveles altos.
        if (levelId > 20 && (a < 5 || b < 5) && (op == '+' || op == '-')) continue;

        return _OpData(a, op, b, res);
      }
    }
    return null;
  }

  static PuzzleLevel _generateRobustSimpleLevel(int levelId, int size) {
    List<GridCell> cells = [];
    List<String> footer = [];
    _addOperation(cells, 0, 1, true, footer, ['+', '-'], size, levelId);
    _addOperation(cells, 0, 3, true, footer, ['+', '-'], size, levelId);
    return PuzzleLevel(id: levelId, size: size, cells: cells, footerTiles: footer);
  }

  static PuzzleLevel _generateSimpleLevel(int id, int size) {
     List<GridCell> cells = [];
     List<String> footer = [];
     _addOperation(cells, 0, 2, true, footer, ['+', '-'], size, id);
     return PuzzleLevel(id: id, size: size, cells: cells, footerTiles: footer);
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
