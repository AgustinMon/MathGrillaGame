enum CellType { empty, number, operator, equals, result }

class GridCell {
  final int x;
  final int y;
  final CellType type;
  final String? value; // The "target" value or a valid solution value
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
      value: json['value']?.toString(),
      currentValue: (json['isFixed'] ?? false) ? json['value']?.toString() : null,
      isFixed: json['isFixed'] ?? false,
      isHorizontal: json['isHorizontal'] ?? true,
    );
  }

  GridCell copyWith({
    int? x,
    int? y,
    CellType? type,
    String? value,
    String? currentValue,
    bool? isFixed,
    bool? isHorizontal,
  }) {
    return GridCell(
      x: x ?? this.x,
      y: y ?? this.y,
      type: type ?? this.type,
      value: value ?? this.value,
      currentValue: currentValue ?? this.currentValue,
      isFixed: isFixed ?? this.isFixed,
      isHorizontal: isHorizontal ?? this.isHorizontal,
    );
  }
}

class LevelScoring {
  final int minScore;
  final int maxScore;
  final Map<String, int> thresholds;
  final int solutionsCount;

  LevelScoring({
    required this.minScore,
    required this.maxScore,
    required this.thresholds,
    this.solutionsCount = 0,
  });

  factory LevelScoring.fromJson(Map<String, dynamic> json) {
    return LevelScoring(
      minScore: json['min_score'] ?? 0,
      maxScore: json['max_score'] ?? 0,
      thresholds: Map<String, int>.from(json['thresholds'] ?? {}),
      solutionsCount: json['solutions_count'] ?? 0,
    );
  }
}

class PuzzleLevel {
  final int id;
  final int size;
  final List<GridCell> cells;
  final List<String> footerTiles;
  final List<String> machineTiles;
  final LevelScoring? scoring;
  final String? mode;
  final String? objective;

  PuzzleLevel({
    required this.id,
    required this.size,
    required this.cells,
    required this.footerTiles,
    this.machineTiles = const [],
    this.scoring,
    this.mode,
    this.objective,
  });

  factory PuzzleLevel.fromJson(Map<String, dynamic> json) {
    return PuzzleLevel(
      id: json['id'],
      size: json['size'],
      cells: (json['cells'] as List).map((c) => GridCell.fromJson(c)).toList(),
      footerTiles: List<String>.from(json['footerTiles'] ?? []),
      machineTiles: List<String>.from(json['machineTiles'] ?? []),
      scoring: json['scoring'] != null ? LevelScoring.fromJson(json['scoring']) : null,
      mode: json['mode'],
      objective: json['objective'],
    );
  }

  PuzzleLevel copyWith({
    int? id,
    int? size,
    List<GridCell>? cells,
    List<String>? footerTiles,
    List<String>? machineTiles,
    LevelScoring? scoring,
    String? mode,
    String? objective,
  }) {
    return PuzzleLevel(
      id: id ?? this.id,
      size: size ?? this.size,
      cells: cells ?? this.cells,
      footerTiles: footerTiles ?? this.footerTiles,
      machineTiles: machineTiles ?? this.machineTiles,
      scoring: scoring ?? this.scoring,
      mode: mode ?? this.mode,
      objective: objective ?? this.objective,
    );
  }
}
