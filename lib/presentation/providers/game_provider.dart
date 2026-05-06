import 'dart:async';
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
  final List<int> solvedRows;
  final List<int> solvedCols;
  final List<Medal> medals;

  GameState({
    this.currentLevel,
    this.score = 0,
    this.lives = 3,
    this.levelNumber = 1,
    this.timeLeft = 60,
    this.isGameOver = false,
    this.isLevelComplete = false,
    this.solvedRows = const [],
    this.solvedCols = const [],
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
    List<int>? solvedRows,
    List<int>? solvedCols,
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
      solvedRows: solvedRows ?? this.solvedRows,
      solvedCols: solvedCols ?? this.solvedCols,
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
      timeLeft: 60 + (level * 5), // Increase time with level
      isLevelComplete: false,
    );
    _startTimer();
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
    if (state.currentLevel == null) return;

    final cellIndex = state.currentLevel!.cells.indexWhere((c) => c.x == x && c.y == y);
    if (cellIndex == -1) return;

    final cell = state.currentLevel!.cells[cellIndex];
    if (cell.isFixed) return;

    // Update cell
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

    // Remove from footer
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

    // Check if the row or column where the tile was placed is now "invalid"
    // An operation is "full" when all non-empty cells have a currentValue
    final rowCells = state.currentLevel!.cells.where((c) => c.y == y).toList();
    final colCells = state.currentLevel!.cells.where((c) => c.x == x).toList();

    _checkOperation(rowCells);
    _checkOperation(colCells);
  }

  void _checkOperation(List<GridCell> cells) {
    bool isFull = cells.every((c) => c.currentValue != null || c.isFixed);
    if (!isFull) return;

    bool isCorrect = cells.every((c) => c.isCorrect);
    if (!isCorrect) {
      // Penalty: Loss of life
      if (state.lives > 0) {
        state = state.copyWith(lives: state.lives - 1);
        SoundService.playError();
        if (state.lives == 0) {
          state = state.copyWith(isGameOver: true);
        }
      }
    }
  }

  void _checkWinCondition() {
    if (state.currentLevel == null) return;

    final size = state.currentLevel!.size;
    final List<int> newlySolvedRows = [];
    final List<int> newlySolvedCols = [];

    // Check rows
    for (int y = 0; y < size; y++) {
      final rowCells = state.currentLevel!.cells.where((c) => c.y == y).toList();
      if (rowCells.isNotEmpty && rowCells.every((c) => c.isCorrect)) {
        newlySolvedRows.add(y);
      }
    }

    // Check cols
    for (int x = 0; x < size; x++) {
      final colCells = state.currentLevel!.cells.where((c) => c.x == x).toList();
      if (colCells.isNotEmpty && colCells.every((c) => c.isCorrect)) {
        newlySolvedCols.add(x);
      }
    }

    // Bonus: If multiple rows/cols solved at once
    int comboCount = 0;
    if (newlySolvedRows.length > state.solvedRows.length) {
      comboCount += (newlySolvedRows.length - state.solvedRows.length);
    }
    if (newlySolvedCols.length > state.solvedCols.length) {
      comboCount += (newlySolvedCols.length - state.solvedCols.length);
    }

    if (comboCount > 1) {
      state = state.copyWith(score: state.score + (comboCount * 50));
    }

    if (newlySolvedRows.length > state.solvedRows.length || newlySolvedCols.length > state.solvedCols.length) {
      SoundService.playSuccess();
    }

    final allCorrect = state.currentLevel!.cells.every((c) => c.isCorrect || c.type == CellType.empty);
    
    state = state.copyWith(
      solvedRows: newlySolvedRows,
      solvedCols: newlySolvedCols,
    );

    if (allCorrect && state.currentLevel!.footerTiles.isEmpty) {
      _timer?.cancel();
      SoundService.playWin();
      _checkMedals();
      state = state.copyWith(
        isLevelComplete: true,
        score: state.score + 100 + state.timeLeft,
      );
    }
  }

  void _checkMedals() async {
    final repo = MedalRepository();
    
    // Level 1 medal
    if (state.levelNumber == 1) {
      await repo.unlockMedal('first_step');
    }

    // Level 10 medal
    if (state.levelNumber == 10) {
      await repo.unlockMedal('math_genius');
    }

    // Speed Runner
    if (state.timeLeft > 40) { // Assuming 60s start
       await repo.unlockMedal('speed_runner');
    }

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
