import 'dart:math';
import '../entities/puzzle_level.dart';

class MathEngine {
  static final Random _random = Random();

  static PuzzleLevel generateLevel(int levelId) {
    int size = 5;
    if (levelId >= 4) size = 7;
    if (levelId >= 8) size = 9;

    List<GridCell> cells = [];
    List<String> footerTiles = [];

    List<String> allowedOps = ['+', '-'];
    if (levelId >= 5) allowedOps.add('*');
    if (levelId >= 10) allowedOps.add('/');

    // Generar estructura base (una cruz)
    _addOperation(cells, 0, 2, true, footerTiles, allowedOps);
    
    var intersectionCell = cells.firstWhere((c) => c.x == 2 && c.y == 2);
    _addIntersectingOperation(cells, 2, 0, false, footerTiles, allowedOps, intersectionCell.value!);

    // Si nivel >= 4, añadir más complejidad de forma segura
    if (levelId >= 4) {
      var resultCellH = cells.firstWhere((c) => c.x == 4 && c.y == 2);
      _addIntersectingOperation(cells, 4, 2, false, footerTiles, allowedOps, resultCellH.value!);
      
      var resultCellV = cells.firstWhere((c) => c.x == 2 && c.y == 4);
      _addIntersectingOperation(cells, 0, 4, true, footerTiles, allowedOps, resultCellV.value!);
    }

    footerTiles.shuffle();

    return PuzzleLevel(
      id: levelId,
      size: size,
      cells: cells,
      footerTiles: footerTiles,
    );
  }

  static void _addOperation(List<GridCell> cells, int startX, int startY, bool horizontal, List<String> footer, List<String> allowedOps) {
    var opData = _generateValidOp(allowedOps);
    List<String> parts = [opData.a.toString(), opData.op, opData.b.toString(), '=', opData.res.toString()];
    
    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      _createAndAddCell(cells, x, y, parts[i], footer);
    }
  }

  static void _addIntersectingOperation(List<GridCell> cells, int startX, int startY, bool horizontal, List<String> footer, List<String> allowedOps, String targetVal) {
    int target = int.tryParse(targetVal) ?? 0;
    
    // Decidimos si el target será el primer número (a) o el segundo (b)
    bool targetIsA = _random.nextBool();
    var opData = _generateValidOpWithTarget(allowedOps, target, targetIsA);
    
    List<String> parts = [opData.a.toString(), opData.op, opData.b.toString(), '=', opData.res.toString()];
    
    int intersectionIndex = targetIsA ? 0 : 2;
    int adjustedStartX = horizontal ? startX - intersectionIndex : startX;
    int adjustedStartY = horizontal ? startY : startY - intersectionIndex;

    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? adjustedStartX + i : adjustedStartX;
      int y = horizontal ? adjustedStartY : adjustedStartY + i;

      if (x < 0 || y < 0 || x >= 9 || y >= 9) continue;

      var existing = cells.where((c) => c.x == x && c.y == y).toList();
      if (existing.isNotEmpty) {
        if (existing.first.value == parts[i]) continue;
        else return; // Abortar si hay conflicto matemático
      }
      
      _createAndAddCell(cells, x, y, parts[i], footer);
    }
  }

  static void _createAndAddCell(List<GridCell> cells, int x, int y, String val, List<String> footer) {
    CellType type = _getCellType(val);
    bool shouldBeFixed = false;

    if (type == CellType.operator || type == CellType.equals) {
      shouldBeFixed = true;
    } else {
      // 20% de probabilidad de que el número sea fijo (pista)
      if (_random.nextDouble() < 0.2) shouldBeFixed = true;
    }

    if (!shouldBeFixed) footer.add(val);

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
    int a = _random.nextInt(20) + 1;
    int b = _random.nextInt(20) + 1;
    
    if (op == '-') { if (a < b) { int t = a; a = b; b = t; } }
    if (op == '/') { int res = _random.nextInt(10) + 1; b = _random.nextInt(9) + 1; a = res * b; }
    
    int res = 0;
    if (op == '+') res = a + b;
    if (op == '-') res = a - b;
    if (op == '*') res = a * b;
    if (op == '/') res = b != 0 ? a ~/ b : 0;
    
    return _OpData(a, op, b, res);
  }

  static _OpData _generateValidOpWithTarget(List<String> ops, int target, bool targetIsA) {
    String op = ops[_random.nextInt(ops.length)];
    int a, b, res;

    if (targetIsA) {
      a = target;
      b = _random.nextInt(20) + 1;
      if (op == '-') { if (a < b) b = _random.nextInt(a + 1); }
      if (op == '/') { b = _random.nextInt(9) + 1; a = (a ~/ b) * b; }
    } else {
      b = target;
      a = _random.nextInt(20) + 1;
      if (op == '-') { if (a < b) a = b + _random.nextInt(20); }
      if (op == '/') { int tempRes = _random.nextInt(10) + 1; a = tempRes * b; }
    }

    res = 0;
    if (op == '+') res = a + b;
    if (op == '-') res = a - b;
    if (op == '*') res = a * b;
    if (op == '/') res = b != 0 ? a ~/ b : 0;
    
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
