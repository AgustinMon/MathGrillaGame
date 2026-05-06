import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../domain/entities/medal.dart';
import '../../domain/use_cases/math_engine.dart';
import '../../data/repositories/medal_repository.dart';
import '../../core/utils/sound_service.dart';

class GameState {
  final PuzzleLevel? currentLevel;
  final int score;
  final int lives;
  final int levelNumber;
  final int timeLeft;
  final bool isGameOver;
  final bool isLevelComplete;
  final Set<String> solvedCells; // Format: "x,y"
  final List<Medal> medals;

  GameState({
    this.currentLevel,
    this.score = 0,
    this.lives = 3,
    this.levelNumber = 1,
    this.timeLeft = 60,
    this.isGameOver = false,
    this.isLevelComplete = false,
    this.solvedCells = const {},
    this.medals = const [],
  });

  GameState copyWith({
    PuzzleLevel? currentLevel,
    int? score,
    int? lives,
    int? levelNumber,
    int? timeLeft,
    bool? isGameOver,
    bool? isLevelComplete,
    Set<String>? solvedCells,
    List<Medal>? medals,
  }) {
    return GameState(
      currentLevel: currentLevel ?? this.currentLevel,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      levelNumber: levelNumber ?? this.levelNumber,
      timeLeft: timeLeft ?? this.timeLeft,
      isGameOver: isGameOver ?? this.isGameOver,
      isLevelComplete: isLevelComplete ?? this.isLevelComplete,
      solvedCells: solvedCells ?? this.solvedCells,
      medals: medals ?? this.medals,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  Timer? _timer;

  GameNotifier() : super(GameState(medals: initialMedals)) {
    _loadMedals();
    startNewLevel(1);
  }

  Future<void> _loadMedals() async {
    final unlockedIds = await MedalRepository().getUnlockedMedalIds();
    final updatedMedals = state.medals.map((m) {
      return m.copyWith(isUnlocked: unlockedIds.contains(m.id));
    }).toList();
    state = state.copyWith(medals: updatedMedals);
  }

  void startNewLevel(int level) {
    final newLevel = MathEngine.generateLevel(level);
    state = state.copyWith(
      currentLevel: newLevel,
      levelNumber: level,
      timeLeft: 60 + (level * 5),
      isLevelComplete: false,
      isGameOver: false,
      lives: 3,
      solvedCells: {},
    );
    _startTimer();
    _checkWinCondition(); // Re-check to highlight fixed solved equations
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeLeft > 0) {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      } else {
        _timer?.cancel();
        state = state.copyWith(isGameOver: true);
      }
    });
  }

  void placeTile(int x, int y, String value) {
    if (state.currentLevel == null || state.isGameOver || state.isLevelComplete) return;

    final cellIndex = state.currentLevel!.cells.indexWhere((c) => c.x == x && c.y == y);
    if (cellIndex == -1) return;

    final cell = state.currentLevel!.cells[cellIndex];
    if (cell.isFixed) return;

    final updatedCells = List<GridCell>.from(state.currentLevel!.cells);
    updatedCells[cellIndex] = GridCell(
      x: x,
      y: y,
      type: cell.type,
      value: cell.value,
      currentValue: value,
      isFixed: false,
    );

    SoundService.playTileDrop();

    final updatedFooter = List<String>.from(state.currentLevel!.footerTiles);
    updatedFooter.remove(value);

    state = state.copyWith(
      currentLevel: PuzzleLevel(
        id: state.currentLevel!.id,
        size: state.currentLevel!.size,
        cells: updatedCells,
        footerTiles: updatedFooter,
      ),
    );

    _validateMove(x, y);
    _checkWinCondition();
  }

  void _validateMove(int x, int y) {
    if (state.currentLevel == null) return;

    final rowCells = state.currentLevel!.cells.where((c) => c.y == y && c.type != CellType.empty).toList();
    final colCells = state.currentLevel!.cells.where((c) => c.x == x && c.type != CellType.empty).toList();

    if (rowCells.length == 5) _checkOperation(rowCells);
    if (colCells.length == 5) _checkOperation(colCells);
  }

  void _checkOperation(List<GridCell> cells) {
    bool isFull = cells.every((c) => c.currentValue != null || c.isFixed);
    if (!isFull) return;

    bool isCorrect = cells.every((c) => c.isCorrect);
    if (!isCorrect) {
      if (state.lives > 0) {
        state = state.copyWith(
          lives: state.lives - 1,
          score: max(0, state.score - 20),
        );
        SoundService.playError();
        if (state.lives == 0) {
          state = state.copyWith(isGameOver: true);
        }
      }
    } else {
      state = state.copyWith(score: state.score + 10);
    }
  }

  void _checkWinCondition() {
    if (state.currentLevel == null) return;

    final size = state.currentLevel!.size;
    final Set<String> newlySolvedCells = {};

    // Check all possible horizontal 5-cell sequences
    for (int y = 0; y < size; y++) {
      for (int x = 0; x <= size - 5; x++) {
        final sequence = <GridCell>[];
        for (int i = 0; i < 5; i++) {
          sequence.add(_getCellAt(x + i, y));
        }
        if (sequence.every((c) => c.type != CellType.empty) && sequence.every((c) => c.isCorrect)) {
          for (var c in sequence) newlySolvedCells.add("${c.x},${c.y}");
        }
      }
    }

    // Check all possible vertical 5-cell sequences
    for (int x = 0; x < size; x++) {
      for (int y = 0; y <= size - 5; y++) {
        final sequence = <GridCell>[];
        for (int i = 0; i < 5; i++) {
          sequence.add(_getCellAt(x, y + i));
        }
        if (sequence.every((c) => c.type != CellType.empty) && sequence.every((c) => c.isCorrect)) {
          for (var c in sequence) newlySolvedCells.add("${c.x},${c.y}");
        }
      }
    }

    state = state.copyWith(solvedCells: newlySolvedCells);

    final allCorrect = state.currentLevel!.cells.every((c) => c.isCorrect || c.type == CellType.empty);
    if (allCorrect && state.currentLevel!.footerTiles.isEmpty && !state.isLevelComplete) {
      _timer?.cancel();
      SoundService.playWin();
      _checkMedals();
      state = state.copyWith(
        isLevelComplete: true,
        score: state.score + (state.levelNumber * 50) + (state.timeLeft * 2),
      );
    }
  }

  GridCell _getCellAt(int x, int y) {
    return state.currentLevel!.cells.firstWhere(
      (c) => c.x == x && c.y == y,
      orElse: () => GridCell(x: x, y: y, type: CellType.empty),
    );
  }

  void _checkMedals() async {
    final repo = MedalRepository();
    if (state.levelNumber == 1) await repo.unlockMedal('first_step');
    if (state.levelNumber == 10) await repo.unlockMedal('math_genius');
    if (state.timeLeft > 40) await repo.unlockMedal('speed_runner');
    _loadMedals();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});
