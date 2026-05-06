import 'dart:math';
import '../entities/puzzle_level.dart';

class MathEngine {
  static final Random _random = Random();

  static PuzzleLevel generateLevel(int levelId) {
    int size = 5;
    if (levelId > 10) size = 7;
    if (levelId > 20) size = 9;

    List<GridCell> cells = [];
    List<String> footerTiles = [];

    // 1. Decidir operaciones permitidas según el nivel
    List<String> allowedOps = ['+', '-'];
    if (levelId >= 5) allowedOps.add('*');
    if (levelId >= 10) allowedOps.add('/');

    // 2. Generar operación horizontal base (Fila 2)
    _addOperation(cells, 0, 2, true, footerTiles, allowedOps, levelId);

    // 3. Intentar generar operación vertical que intersecte (Columna 2)
    // Buscamos el valor en la intersección (2,2)
    var intersectionCell = cells.firstWhere((c) => c.x == 2 && c.y == 2);
    _addIntersectingOperation(cells, 2, 0, false, footerTiles, allowedOps, levelId, intersectionCell.value!);

    // Mezclar las piezas del footer
    footerTiles.shuffle();

    return PuzzleLevel(
      id: levelId,
      size: size,
      cells: cells,
      footerTiles: footerTiles,
    );
  }

  static void _addOperation(List<GridCell> cells, int startX, int startY, bool horizontal, List<String> footer, List<String> allowedOps, int level) {
    var opData = _generateValidOp(allowedOps);
    List<String> parts = [opData.a.toString(), opData.op, opData.b.toString(), '=', opData.res.toString()];
    
    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      _createCell(cells, x, y, parts[i], footer, level);
    }
  }

  static void _addIntersectingOperation(List<GridCell> cells, int startX, int startY, bool horizontal, List<String> footer, List<String> allowedOps, int level, String intersectionValue) {
    int target = int.tryParse(intersectionValue) ?? 0;
    var opData = _generateValidOpWithTarget(allowedOps, target);
    
    List<String> parts = [opData.a.toString(), opData.op, opData.b.toString(), '=', opData.res.toString()];
    
    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      
      if (cells.any((c) => c.x == x && c.y == y)) continue;
      
      _createCell(cells, x, y, parts[i], footer, level);
    }
  }

  static void _createCell(List<GridCell> cells, int x, int y, String val, List<String> footer, int level) {
    CellType type = _getCellType(val);
    
    bool shouldBeFixed = false;
    if (type == CellType.operator || type == CellType.equals) {
      shouldBeFixed = true; 
    } else if (level <= 3 && _random.nextDouble() > 0.6) {
      shouldBeFixed = true; 
    }

    if (!shouldBeFixed) {
      footer.add(val);
    }

    cells.add(GridCell(
      x: x,
      y: y,
      type: type,
      value: val,
      currentValue: shouldBeFixed ? val : null,
      isFixed: shouldBeFixed,
    ));
  }

  static _OpData _generateValidOp(List<String> ops) {
    String op = ops[_random.nextInt(ops.length)];
    int a = _random.nextInt(15) + 1;
    int b = _random.nextInt(15) + 1;
    if (op == '-') { if (a < b) { int t = a; a = b; b = t; } }
    if (op == '/') { int res = _random.nextInt(10) + 1; b = _random.nextInt(9) + 1; a = res * b; }
    
    int res = 0;
    if (op == '+') res = a + b;
    if (op == '-') res = a - b;
    if (op == '*') res = a * b;
    if (op == '/') res = a ~/ b;
    
    return _OpData(a, op, b, res);
  }

  static _OpData _generateValidOpWithTarget(List<String> ops, int target) {
    String op = ops[_random.nextInt(ops.length)];
    int a, b = target, res;

    if (op == '+') { a = _random.nextInt(15) + 1; res = a + b; }
    else if (op == '-') { a = target + _random.nextInt(15); res = a - b; }
    else if (op == '*') { a = _random.nextInt(10) + 1; res = a * b; }
    else { 
      res = _random.nextInt(10) + 1; a = res * b;
    }
    return _OpData(a, op, b, res);
  }

  static CellType _getCellType(String val) {
    if (val == '=') return CellType.equals;
    if (['+', '-', '*', '/'].contains(val)) return CellType.operator;
    return CellType.number;
  }
}

class _OpData {
  final int a, b, res;
  final String op;
  _OpData(this.a, this.op, this.b, this.res);
}
