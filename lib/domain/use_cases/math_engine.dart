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

    // Simple implementation for MVP: 
    // Fill the grid with some random operations in a crossword style.
    // For now, let's just generate a 5x5 with a few intersecting lines.
    
    // Example: Row 2: 5 + 3 = 8
    //          Col 2: 5 * 2 = 10
    
    _addOperation(cells, 0, 2, true, footerTiles); // Row 2
    _addOperation(cells, 2, 0, false, footerTiles); // Col 2

    // Shuffle footer tiles
    footerTiles.shuffle();

    return PuzzleLevel(
      id: levelId,
      size: size,
      cells: cells,
      footerTiles: footerTiles,
    );
  }

  static void _addOperation(List<GridCell> cells, int startX, int startY, bool horizontal, List<String> footer) {
    int a = _random.nextInt(20) + 1;
    int b = _random.nextInt(20) + 1;
    String op = ['+', '-', '*'][_random.nextInt(3)];
    int res;
    
    switch (op) {
      case '+': res = a + b; break;
      case '-': res = a + b; int tmp = a; a = res; res = tmp; break; // Ensure positive res
      case '*': res = a * b; break;
      default: res = a + b;
    }

    List<String> parts = [a.toString(), op, b.toString(), '=', res.toString()];
    
    for (int i = 0; i < parts.length; i++) {
      int x = horizontal ? startX + i : startX;
      int y = horizontal ? startY : startY + i;
      
      String val = parts[i];
      CellType type = _getCellType(val);
      
      // Check if cell already exists (intersection)
      var existing = cells.where((c) => c.x == x && c.y == y).toList();
      if (existing.isNotEmpty) {
        // Validation: if it intersects, it must have the same value
        // For simplicity in this procedural prototype, we'll just skip or force
        continue; 
      }

      bool isFixed = _random.nextBool() && type != CellType.number && type != CellType.result;
      
      if (!isFixed && (type == CellType.number || type == CellType.result)) {
        footer.add(val);
      }

      cells.add(GridCell(
        x: x,
        y: y,
        type: type,
        value: val,
        currentValue: isFixed ? val : null,
        isFixed: isFixed,
      ));
    }
  }

  static CellType _getCellType(String val) {
    if (val == '=') return CellType.equals;
    if (['+', '-', '*', '/'].contains(val)) return CellType.operator;
    return CellType.number;
  }
}
