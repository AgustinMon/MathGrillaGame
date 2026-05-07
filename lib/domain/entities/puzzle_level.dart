enum CellType { empty, number, operator, equals, result }

class GridCell {
  final int x;
  final int y;
  final CellType type;
  final String? value; // The "hidden" or "target" value
  String? currentValue; // What the user has placed
  final bool isFixed; // If the cell is pre-filled
  final bool isHorizontal; // Orientation for crossword logic

  GridCell({
    required this.x,
    required this.y,
    required this.type,
    this.value,
    this.currentValue,
    this.isFixed = false,
    this.isHorizontal = true,
  });

  bool get isCorrect => currentValue?.trim() == value?.trim();

  factory GridCell.fromJson(Map<String, dynamic> json) {
    return GridCell(
      x: json['x'],
      y: json['y'],
      type: CellType.values[json['type']],
      value: json['value'],
      currentValue: json['isFixed'] ? json['value'] : null,
      isFixed: json['isFixed'] ?? false,
      isHorizontal: json['isHorizontal'] ?? true,
    );
  }
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

  factory PuzzleLevel.fromJson(Map<String, dynamic> json) {
    return PuzzleLevel(
      id: json['id'],
      size: json['size'],
      cells: (json['cells'] as List).map((c) => GridCell.fromJson(c)).toList(),
      footerTiles: List<String>.from(json['footerTiles']),
    );
  }
}
