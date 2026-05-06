enum CellType { empty, number, operator, equals, result }

class GridCell {
  final int x;
  final int y;
  final CellType type;
  final String? value; // The "hidden" or "target" value
  String? currentValue; // What the user has placed
  bool isFixed; // If the cell is pre-filled

  GridCell({
    required this.x,
    required this.y,
    required this.type,
    this.value,
    this.currentValue,
    this.isFixed = false,
  });

  bool get isCorrect => currentValue == value;
}

class PuzzleLevel {
  final int id;
  final int size; // Grid size (e.g., 5x5)
  final List<GridCell> cells;
  final List<String> footerTiles; // Numbers/operators available to drag

  PuzzleLevel({
    required this.id,
    required this.size,
    required this.cells,
    required this.footerTiles,
  });
}
