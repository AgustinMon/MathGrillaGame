import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../domain/entities/medal.dart';
import '../../domain/use_cases/math_engine.dart';
import '../../data/repositories/medal_repository.dart';
import '../../core/utils/sound_service.dart';

/// Representa el estado actual del juego en un momento dado.
class GameState {
  final PuzzleLevel? currentLevel; // El nivel que se está jugando actualmente.
  final int score; // Puntuación total acumulada.
  final int lives; // Vidas restantes (generalmente 3).
  final int levelNumber; // Número del nivel actual.
  final int timeLeft; // Segundos restantes para completar el nivel.
  final bool isGameOver; // Indica si el jugador ha perdido.
  final bool isLevelComplete; // Indica si el jugador ha ganado el nivel actual.
  final Set<String> solvedCells; // Celdas que forman parte de una ecuación correcta (formato "x,y").
  final Set<int> solvedRows; // Filas que han sido completadas correctamente.
  final Set<int> solvedCols; // Columnas que han sido completadas correctamente.
  final List<Medal> medals; // Lista de medallas/logros del jugador.
  final String? message; // Mensaje temporal de feedback (ej: "¡Casi! Revisa tus cálculos").
  final String difficulty; // Dificultad actual ('easy', 'medium', 'hard').
  final int hintsRemaining; // Pistas disponibles.
  final bool isTimerPaused; // Indica si el tiempo está pausado (ej: viendo un anuncio).
  final bool showTutorial; // Indica si se debe mostrar el tutorial al iniciar el Nivel 1.
  final String? machineInputA;
  final String? machineInputB;
  final String machineOp;
  final List<String> machineTiles;
  final bool machineInputAFromMachine;
  final bool machineInputBFromMachine;
  final String? machineResult;
  final String? machineLastInputA;
  final String? machineLastInputB;
  final bool machineLastInputAFromMachine;
  final bool machineLastInputBFromMachine;
  final String? machineLastOp;
  final int comboCount;
  final DateTime? lastSolveTime;
  final int errorTrigger; // Incrementado para disparar sacudida de pantalla
  final Map<String, Map<String, dynamic>> fusedTilesData;
  final List<Map<String, dynamic>> moveHistory; // Historial para deshacer

  GameState({
    this.currentLevel,
    this.score = 0,
    this.lives = 3,
    this.levelNumber = 1,
    this.timeLeft = 60,
    this.isGameOver = false,
    this.isLevelComplete = false,
    this.solvedCells = const {},
    this.solvedRows = const {},
    this.solvedCols = const {},
    this.medals = const [],
    this.message,
    this.difficulty = 'medium',
    this.hintsRemaining = 2,
    this.isTimerPaused = false,
    this.showTutorial = true,
    this.machineInputA,
    this.machineInputB,
    this.machineOp = '+',
    this.machineTiles = const [],
    this.machineInputAFromMachine = false,
    this.machineInputBFromMachine = false,
    this.machineResult,
    this.machineLastInputA,
    this.machineLastInputB,
    this.machineLastInputAFromMachine = false,
    this.machineLastInputBFromMachine = false,
    this.machineLastOp,
    this.fusedTilesData = const {},
    this.comboCount = 0,
    this.lastSolveTime,
    this.errorTrigger = 0,
    this.moveHistory = const [],
  });

  /// Crea una copia del estado actual permitiendo modificar solo algunos campos.
  GameState copyWith({
    PuzzleLevel? currentLevel,
    int? score,
    int? lives,
    int? levelNumber,
    int? timeLeft,
    bool? isGameOver,
    bool? isLevelComplete,
    Set<String>? solvedCells,
    Set<int>? solvedRows,
    Set<int>? solvedCols,
    List<Medal>? medals,
    String? message,
    String? difficulty,
    int? hintsRemaining,
    bool? isTimerPaused,
    bool? showTutorial,
    String? machineInputA,
    String? machineInputB,
    bool clearMachineA = false,
    bool clearMachineB = false,
    String? machineOp,
    List<String>? machineTiles,
    bool? machineInputAFromMachine,
    bool? machineInputBFromMachine,
    String? machineResult,
    bool clearMachineResult = false,
    String? machineLastInputA,
    String? machineLastInputB,
    bool? machineLastInputAFromMachine,
    bool? machineLastInputBFromMachine,
    String? machineLastOp,
    int? comboCount,
    DateTime? lastSolveTime,
    int? errorTrigger,
    Map<String, Map<String, dynamic>>? fusedTilesData,
    List<Map<String, dynamic>>? moveHistory,
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
      solvedRows: solvedRows ?? this.solvedRows,
      solvedCols: solvedCols ?? this.solvedCols,
      medals: medals ?? this.medals,
      message: message,
      difficulty: difficulty ?? this.difficulty,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
      isTimerPaused: isTimerPaused ?? this.isTimerPaused,
      showTutorial: showTutorial ?? this.showTutorial,
      machineInputA: clearMachineA ? null : (machineInputA ?? this.machineInputA),
      machineInputB: clearMachineB ? null : (machineInputB ?? this.machineInputB),
      machineOp: machineOp ?? this.machineOp,
      machineTiles: machineTiles ?? this.machineTiles,
      machineInputAFromMachine: machineInputAFromMachine ?? this.machineInputAFromMachine,
      machineInputBFromMachine: machineInputBFromMachine ?? this.machineInputBFromMachine,
      machineResult: clearMachineResult ? null : (machineResult ?? this.machineResult),
      machineLastInputA: machineLastInputA ?? this.machineLastInputA,
      machineLastInputB: machineLastInputB ?? this.machineLastInputB,
      machineLastInputAFromMachine: machineLastInputAFromMachine ?? this.machineLastInputAFromMachine,
      machineLastInputBFromMachine: machineInputBFromMachine ?? this.machineLastInputBFromMachine,
      machineLastOp: machineLastOp ?? this.machineLastOp,
      fusedTilesData: fusedTilesData ?? this.fusedTilesData,
      comboCount: comboCount ?? this.comboCount,
      lastSolveTime: lastSolveTime ?? this.lastSolveTime,
      errorTrigger: errorTrigger ?? this.errorTrigger,
      moveHistory: moveHistory ?? this.moveHistory,
    );
  }
}

/// Maneja la lógica del negocio y las actualizaciones del estado del juego.
class GameNotifier extends StateNotifier<GameState> {
  Timer? _timer;

  GameNotifier() : super(GameState(medals: initialMedals)) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final showTutorial = prefs.getBool('showTutorial') ?? true;
    state = state.copyWith(showTutorial: showTutorial);
    _loadMedals();
    startNewLevel(1);
  }

  /// Carga las medallas desbloqueadas desde el repositorio local.
  Future<void> _loadMedals() async {
    final unlockedIds = await MedalRepository().getUnlockedMedalIds();
    final updatedMedals = state.medals.map((m) {
      return m.copyWith(isUnlocked: unlockedIds.contains(m.id));
    }).toList();
    state = state.copyWith(medals: updatedMedals);
  }

  /// Inicializa un nuevo nivel, reseteando temporizadores, vidas y el tablero.
  void startNewLevel(int level) {
    final newLevel = MathEngine.generateLevel(level, difficulty: state.difficulty);
    
    // Tiempo dinámico: 60s base + 4s por cada celda que el usuario debe completar.
    int emptyCellsCount = newLevel.cells.where((c) => !c.isFixed).length;
    int calculatedTime = 60 + (emptyCellsCount * 4);
    
    // Multiplicadores de dificultad para mayor reto.
    if (state.difficulty == 'medium') calculatedTime = (calculatedTime * 1.2).toInt();
    if (state.difficulty == 'hard') calculatedTime = (calculatedTime * 1.5).toInt();

    state = state.copyWith(
      currentLevel: newLevel,
      levelNumber: level,
      timeLeft: calculatedTime,
      isLevelComplete: false,
      isGameOver: false,
      lives: 3,
      solvedCells: {},
      solvedRows: {},
      solvedCols: {},
      message: null,
      hintsRemaining: state.difficulty == 'hard' ? 3 : 2,
      isTimerPaused: false,
      machineInputA: null,
      machineInputB: null,
      machineOp: '+',
      machineTiles: newLevel.machineTiles,
      machineInputAFromMachine: false,
      machineInputBFromMachine: false,
    );
    _startTimer();
    _checkWinCondition();
  }

  void changeDifficulty(String newDifficulty) {
    state = state.copyWith(difficulty: newDifficulty);
    // Regeneramos el nivel 1 con la nueva dificultad para que esté listo.
    startNewLevel(1);
  }

  /// Inicia el temporizador de cuenta regresiva del nivel.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.isTimerPaused || state.isGameOver || state.isLevelComplete) return;
      
      if (state.timeLeft > 0) {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      } else {
        _timer?.cancel();
        state = state.copyWith(isGameOver: true);
      }
    });
  }

  /// Coloca una pieza de número en una posición específica del tablero.
  void placeTile(int x, int y, String value, {Map<String, dynamic>? fusionData}) {
    if (state.currentLevel == null || state.isGameOver || state.isLevelComplete)
      return;

    final cellIndex = state.currentLevel!.cells.indexWhere(
      (c) => c.x == x && c.y == y,
    );
    if (cellIndex == -1) return;

    final cell = state.currentLevel!.cells[cellIndex];
    if (cell.isFixed) return;

    // Actualizamos la lista de celdas con el nuevo valor colocado.
    // Si la celda ya tenía un valor puesto por el usuario, lo devolvemos al footer.
    final updatedFooter = List<String>.from(state.currentLevel!.footerTiles);
    if (cell.currentValue != null) {
      updatedFooter.add(cell.currentValue!);
    }

    // Actualizamos las celdas con el nuevo valor.
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

    // Quitamos la nueva pieza del footer.
    updatedFooter.remove(value);

    // Registramos en el historial
    final newHistory = List<Map<String, dynamic>>.from(state.moveHistory);
    newHistory.add({'x': x, 'y': y});
    
    state = state.copyWith(
      moveHistory: newHistory,
      currentLevel: PuzzleLevel(
        id: state.currentLevel!.id,
        size: state.currentLevel!.size,
        cells: updatedCells,
        footerTiles: updatedFooter,
        machineTiles: state.machineTiles,
      ),
    );

    // Guardamos metadata si es una pieza fusionada
    if (fusionData != null) {
      final newFusedData = Map<String, Map<String, dynamic>>.from(state.fusedTilesData);
      newFusedData["$x,$y"] = fusionData;
      state = state.copyWith(fusedTilesData: newFusedData);
    }

    // Validamos si el movimiento completó una operación y chequeamos si ganó el nivel.
    _validateMove(x, y);
    _checkWinCondition();
  }

  /// Quita una pieza del tablero y la devuelve al footer.
  void removeTile(int x, int y) {
    if (state.currentLevel == null || state.isGameOver || state.isLevelComplete)
      return;

    final cellIndex = state.currentLevel!.cells.indexWhere(
      (c) => c.x == x && c.y == y,
    );
    if (cellIndex == -1) return;

    final cell = state.currentLevel!.cells[cellIndex];
    if (cell.isFixed || cell.currentValue == null) return;

    final updatedFooter = List<String>.from(state.currentLevel!.footerTiles);
    final updatedCells = List<GridCell>.from(state.currentLevel!.cells);
    final tileValue = cell.currentValue!;
    final posKey = "$x,$y";

    // Si era una pieza fusionada, se descompone
    if (state.fusedTilesData.containsKey(posKey)) {
      final data = state.fusedTilesData[posKey]!;
      final valA = data['valA'] as String?;
      final valB = data['valB'] as String?;
      final fromMachineA = data['fromA'] as bool? ?? false;
      final fromMachineB = data['fromB'] as bool? ?? false;

      // Quitamos la metadata
      final newFusedData = Map<String, Map<String, dynamic>>.from(state.fusedTilesData);
      newFusedData.remove(posKey);

      // Devolvemos los ingredientes originales a la máquina
      if (valA != null) addToMachine(1, valA, isMachineTile: fromMachineA);
      if (valB != null) addToMachine(2, valB, isMachineTile: fromMachineB);

      state = state.copyWith(
        fusedTilesData: newFusedData,
        message: 'Pieza descompuesta en sus ingredientes.',
      );
      // NO la añadimos al updatedFooter
    } else {
      updatedFooter.add(tileValue);
    }

    updatedCells[cellIndex] = GridCell(
      x: x,
      y: y,
      type: cell.type,
      value: cell.value,
      currentValue: null,
      isFixed: false,
    );

    state = state.copyWith(
      currentLevel: PuzzleLevel(
        id: state.currentLevel!.id,
        size: state.currentLevel!.size,
        cells: updatedCells,
        footerTiles: updatedFooter,
        machineTiles: state.machineTiles,
      ),
    );
    // Quitamos del historial si existía manualmente
    final newHistory = state.moveHistory.where((m) => m['x'] != x || m['y'] != y).toList();
    state = state.copyWith(moveHistory: newHistory);

    _checkWinCondition();
  }

  /// Alterna el estado de pausa del juego.
  void togglePause() {
    state = state.copyWith(isTimerPaused: !state.isTimerPaused);
  }

  /// Deshace el último movimiento realizado en la grilla.
  void undoMove() {
    if (state.moveHistory.isEmpty || state.isTimerPaused) return;
    
    final lastMove = state.moveHistory.last;
    removeTile(lastMove['x'], lastMove['y']);
  }

  /// Valida si la fila o columna donde se puso la pieza está completa y es correcta.
  void _validateMove(int x, int y) {
    if (state.currentLevel == null) return;

    // Obtenemos todas las celdas de la fila y columna impactadas, ordenadas.
    final rowCells = state.currentLevel!.cells
        .where((c) => c.y == y && c.type != CellType.empty)
        .toList()..sort((a, b) => a.x.compareTo(b.x));
        
    final colCells = state.currentLevel!.cells
        .where((c) => c.x == x && c.type != CellType.empty)
        .toList()..sort((a, b) => a.y.compareTo(b.y));

    // Buscamos secuencias de 5 celdas (a op b = res)
    for (int i = 0; i <= rowCells.length - 5; i++) {
      final sub = rowCells.sublist(i, i + 5);
      if (sub[3].type == CellType.equals) {
        _checkOperation(sub, isHorizontal: true);
      }
    }
    
    for (int i = 0; i <= colCells.length - 5; i++) {
      final sub = colCells.sublist(i, i + 5);
      if (sub[3].type == CellType.equals) {
        _checkOperation(sub, isHorizontal: false);
      }
    }
  }

  /// Comprueba si una secuencia de 5 celdas forma una operación matemática válida.
  /// Si es incorrecta, penaliza al jugador quitándole una vida.
  void _checkOperation(List<GridCell> cells, {required bool isHorizontal}) {
    bool isFull = cells.every((c) => c.currentValue != null || c.isFixed);
    if (!isFull) return;

    // Validación Matemática Real
    try {
      final valA = int.tryParse(cells[0].currentValue ?? '');
      final op = cells[1].currentValue;
      final valB = int.tryParse(cells[2].currentValue ?? '');
      final valRes = int.tryParse(cells[4].currentValue ?? '');

      if (valA == null || op == null || valB == null || valRes == null) return;

      final bool isMathCorrect = _isMathCorrect(cells);
      final newSolvedCells = Set<String>.from(state.solvedCells);
      for (var c in cells) {
        newSolvedCells.add('${c.x},${c.y}');
      }

      if (isMathCorrect) {
        final now = DateTime.now();
        int points = 100;
        int newCombo = 1;
        
        if (state.lastSolveTime != null) {
          final diff = now.difference(state.lastSolveTime!).inSeconds;
          if (diff < 10) { // Si resuelve en menos de 10s, combo!
            newCombo = state.comboCount + 1;
            points *= newCombo;
          }
        }

        if (isHorizontal) {
          state = state.copyWith(
            solvedRows: {...state.solvedRows, cells[0].y},
            solvedCells: newSolvedCells,
            score: state.score + points,
            comboCount: newCombo,
            lastSolveTime: now,
            message: newCombo > 1 ? 'COMBO x$newCombo! +$points' : '¡Excelente!',
            timeLeft: state.timeLeft + (state.difficulty == 'easy' ? 0 : 10),
          );
        } else {
          state = state.copyWith(
            solvedCols: {...state.solvedCols, cells[0].x},
            solvedCells: newSolvedCells,
            score: state.score + points,
            comboCount: newCombo,
            lastSolveTime: now,
            message: newCombo > 1 ? 'COMBO x$newCombo! +$points' : '¡Excelente!',
            timeLeft: state.timeLeft + (state.difficulty == 'easy' ? 0 : 10),
          );
        }
        SoundService.playSuccess();
      } else {
        // Si el cálculo es incorrecto
        if (state.lives > 0) {
          state = state.copyWith(
            lives: state.lives - 1,
            score: max(0, state.score - 50),
            errorTrigger: state.errorTrigger + 1,
            comboCount: 0, // Reset combo on error
            message: 'Algo no está bien...',
          );
          SoundService.playError();
          if (state.lives == 0) {
            state = state.copyWith(isGameOver: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Error validando operación: $e');
    }

    // Limpiamos el mensaje después de unos segundos.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) state = state.copyWith(message: null);
    });
  }

  /// Limpia el mensaje de feedback manualmente.
  void clearMessage() {
    state = state.copyWith(message: null);
  }

  /// Escanea todo el tablero buscando ecuaciones resueltas para actualizar el estado visual
  /// y detectar si el nivel ha sido completado totalmente.
  void _checkWinCondition() {
    if (state.currentLevel == null) return;

    final cells = state.currentLevel!.cells;
    final size = state.currentLevel!.size;
    final Set<String> newlySolvedCells = {};
    final Set<int> newlySolvedRows = {};
    final Set<int> newlySolvedCols = {};

    // Comprobamos cada fila
    for (int y = 0; y < size; y++) {
      final rowCells = cells.where((c) => c.y == y && c.type != CellType.empty).toList()..sort((a, b) => a.x.compareTo(b.x));
      
      for (int i = 0; i <= rowCells.length - 5; i++) {
        final sub = rowCells.sublist(i, i + 5);
        if (sub[3].type == CellType.equals && _isMathCorrect(sub)) {
          newlySolvedRows.add(y);
          for (var c in sub) newlySolvedCells.add("${c.x},${c.y}");
        }
      }
    }

    // Comprobamos cada columna
    for (int x = 0; x < size; x++) {
      final colCells = cells.where((c) => c.x == x && c.type != CellType.empty).toList()..sort((a, b) => a.y.compareTo(b.y));

      for (int i = 0; i <= colCells.length - 5; i++) {
        final sub = colCells.sublist(i, i + 5);
        if (sub[3].type == CellType.equals && _isMathCorrect(sub)) {
          newlySolvedCols.add(x);
          for (var c in sub) newlySolvedCells.add("${c.x},${c.y}");
        }
      }
    }

    state = state.copyWith(
      solvedCells: newlySolvedCells,
      solvedRows: newlySolvedRows,
      solvedCols: newlySolvedCols,
    );

    // Condición de victoria: todas las celdas que NO están vacías deben estar en newlySolvedCells
    final allOperationCells = cells.where((c) => c.type != CellType.empty).toList();
    final allGridCorrect = allOperationCells.isNotEmpty && allOperationCells.every((c) => newlySolvedCells.contains("${c.x},${c.y}"));
    
    final footerEmpty = state.currentLevel!.footerTiles.isEmpty;
    final gridFull = cells.every((c) => c.currentValue != null || c.type == CellType.empty || c.isFixed);

    if (allGridCorrect && footerEmpty && !state.isLevelComplete) {
      _timer?.cancel();
      SoundService.playWin();
      _checkMedals();
      state = state.copyWith(
        isLevelComplete: true,
        score: state.score + (state.levelNumber * 50) + (state.timeLeft * 2),
        message: '¡Nivel Completado!',
      );
    } else if (gridFull && footerEmpty && !allGridCorrect) {
      // Si el tablero está lleno y el inventario vacío pero algo está mal.
      state = state.copyWith(message: 'El tablero está lleno pero hay errores. ¡Revisa bien!');
    }
  }

  bool _isMathCorrect(List<GridCell> cells) {
    if (cells.length < 5) return false;
    // Extraemos valores asegurándonos de usar currentValue si existe, o value si es fijo.
    final valAStr = cells[0].currentValue ?? (cells[0].isFixed ? cells[0].value : null);
    final op = cells[1].currentValue ?? (cells[1].isFixed ? cells[1].value : null);
    final valBStr = cells[2].currentValue ?? (cells[2].isFixed ? cells[2].value : null);
    final valResStr = cells[4].currentValue ?? (cells[4].isFixed ? cells[4].value : null);

    if (valAStr == null || op == null || valBStr == null || valResStr == null) return false;

    final valA = int.tryParse(valAStr);
    final valB = int.tryParse(valBStr);
    final valRes = int.tryParse(valResStr);

    if (valA == null || valB == null || valRes == null) return false;

    if (op == '+') return valA + valB == valRes;
    if (op == '-') return valA - valB == valRes;
    if (op == '*') return valA * valB == valRes;
    if (op == '/') return valB != 0 && valA / valB == valRes;
    return false;
  }

  /// Helper para obtener una celda en coordenadas específicas, devolviendo una vacía si no existe.
  GridCell _getCellAt(int x, int y) {
    return state.currentLevel!.cells.firstWhere(
      (c) => c.x == x && c.y == y,
      orElse: () => GridCell(x: x, y: y, type: CellType.empty),
    );
  }

  /// Comprueba si el jugador ha cumplido los requisitos para obtener alguna medalla.
  void _checkMedals() async {
    final repo = MedalRepository();
    if (state.levelNumber == 1) await repo.unlockMedal('first_step');
    if (state.levelNumber == 10) await repo.unlockMedal('math_genius');
    if (state.timeLeft > 40) await repo.unlockMedal('speed_runner');
    _loadMedals();
  }

  /// Salta al nivel especificado (útil para pruebas y debug).
  void skipLevel(int targetLevel) {
    _timer?.cancel();
    startNewLevel(targetLevel);
  }

  /// Utiliza una pista para revelar una celda al azar.
  void useHint() {
    if (state.hintsRemaining <= 0 || state.currentLevel == null || state.isGameOver || state.isLevelComplete) return;

    final unsolvedCells = state.currentLevel!.cells.where((c) =>
      !c.isFixed && (c.currentValue == null || c.currentValue != c.value)
    ).toList();

    if (unsolvedCells.isEmpty) return;
    
    final target = unsolvedCells[Random().nextInt(unsolvedCells.length)];

    if (target.value != null) {
      // Al usar una pista, si el número estaba en el footer o máquina, deberíamos quitarlo.
      // Por simplicidad lo quitamos del footer si existe.
      final updatedFooter = List<String>.from(state.currentLevel!.footerTiles);
      updatedFooter.remove(target.value);
      
      final updatedMachine = List<String>.from(state.machineTiles);
      updatedMachine.remove(target.value);

      state = state.copyWith(
        currentLevel: PuzzleLevel(
          id: state.currentLevel!.id,
          size: state.currentLevel!.size,
          cells: state.currentLevel!.cells,
          footerTiles: updatedFooter,
          machineTiles: updatedMachine,
        ),
        machineTiles: updatedMachine,
      );
      placeTile(target.x, target.y, target.value!);
    }
    state = state.copyWith(hintsRemaining: state.hintsRemaining - 1);
  }

  /// Pausa o reanuda el tiempo.
  void toggleTimer(bool pause) {
    state = state.copyWith(isTimerPaused: pause);
  }

  /// Añade pistas adicionales (recompensa por anuncio).
  void addHints(int amount) {
    state = state.copyWith(hintsRemaining: state.hintsRemaining + amount);
  }

  /// Cambia la preferencia de mostrar el tutorial y la guarda en disco.
  Future<void> setTutorialVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTutorial', visible);
    state = state.copyWith(showTutorial: visible);
  }

  /// Restablece todos los tutoriales para que se vuelvan a mostrar.
  Future<void> resetTutorials() async {
    await setTutorialVisible(true);
  }

  void addToMachine(int slot, String value, {bool isMachineTile = false}) {
    if (state.difficulty != 'hard') return;
    
    // Solo permitimos ingredientes (rosas) en la máquina como pidió el usuario.
    if (!isMachineTile) {
      state = state.copyWith(message: 'only_pink');
      return;
    }

    List<String> updatedFooter = List<String>.from(state.currentLevel?.footerTiles ?? []);
    List<String> updatedMachine = List<String>.from(state.machineTiles);

    // 1. Devolver el valor anterior del slot si existe
    final oldValue = slot == 1 ? state.machineInputA : state.machineInputB;
    final wasFromMachine = slot == 1 ? state.machineInputAFromMachine : state.machineInputBFromMachine;

    if (oldValue != null) {
      if (wasFromMachine) {
        updatedMachine.add(oldValue);
      } else {
        updatedFooter.add(oldValue);
      }
    }

    // 2. Quitar el nuevo valor de su lista de origen
    if (isMachineTile) {
      updatedMachine.remove(value);
    } else {
      updatedFooter.remove(value);
    }

    // 3. Actualizar estado de forma atómica
    state = state.copyWith(
      currentLevel: PuzzleLevel(
        id: state.currentLevel!.id,
        size: state.currentLevel!.size,
        cells: state.currentLevel!.cells,
        footerTiles: updatedFooter,
        machineTiles: updatedMachine,
      ),
      machineTiles: updatedMachine,
      machineInputA: slot == 1 ? value : state.machineInputA,
      machineInputB: slot == 2 ? value : state.machineInputB,
      machineInputAFromMachine: slot == 1 ? isMachineTile : state.machineInputAFromMachine,
      machineInputBFromMachine: slot == 2 ? isMachineTile : state.machineInputBFromMachine,
    );

    SoundService.playTileDrop();
  }

  void removeFromMachine(int slot) {
    final value = slot == 1 ? state.machineInputA : state.machineInputB;
    final isMachineTile = slot == 1 ? state.machineInputAFromMachine : state.machineInputBFromMachine;
    if (value == null) return;

    if (isMachineTile) {
      final updatedMachine = List<String>.from(state.machineTiles);
      updatedMachine.add(value);
      state = state.copyWith(
        machineTiles: updatedMachine,
        clearMachineA: slot == 1,
        clearMachineB: slot == 2,
      );
    } else {
      final updatedFooter = List<String>.from(state.currentLevel!.footerTiles);
      updatedFooter.add(value);
      state = state.copyWith(
        currentLevel: PuzzleLevel(
          id: state.currentLevel!.id,
          size: state.currentLevel!.size,
          cells: state.currentLevel!.cells,
          footerTiles: updatedFooter,
          machineTiles: state.machineTiles,
        ),
        clearMachineA: slot == 1,
        clearMachineB: slot == 2,
      );
    }
  }

  void toggleMachineOp() {
    state = state.copyWith(machineOp: state.machineOp == '+' ? '-' : '+');
  }

  void fuseNumbers() {
    if (state.machineInputA == null || state.machineInputB == null) return;

    final valA = int.tryParse(state.machineInputA!) ?? 0;
    final valB = int.tryParse(state.machineInputB!) ?? 0;
    int result = 0;

    if (state.machineOp == '+') {
      result = valA + valB;
    } else {
      result = valA - valB;
    }

    // No permitimos resultados negativos por ahora para no complicar el tablero
    if (result < 0) {
      state = state.copyWith(message: 'negative_error');
      return;
    }

    final resStr = result.toString();

    state = state.copyWith(
      machineResult: resStr,
      machineLastInputA: state.machineInputA,
      machineLastInputB: state.machineInputB,
      machineLastInputAFromMachine: state.machineInputAFromMachine,
      machineLastInputBFromMachine: state.machineInputBFromMachine,
      machineLastOp: state.machineOp,
      clearMachineA: true,
      clearMachineB: true,
      message: 'fusion_success|res:$result',
    );
    SoundService.playSuccess();
  }

  /// Deshace la fusión y devuelve los ingredientes.
  void breakResult() {
    if (state.machineResult == null) return;

    final valA = state.machineLastInputA;
    final valB = state.machineLastInputB;
    final fromMachineA = state.machineLastInputAFromMachine;
    final fromMachineB = state.machineLastInputBFromMachine;

    if (valA != null) addToMachine(1, valA, isMachineTile: fromMachineA);
    if (valB != null) addToMachine(2, valB, isMachineTile: fromMachineB);

    state = state.copyWith(
      clearMachineResult: true,
      message: 'fusion_undo',
    );
  }

  /// Limpia la máquina cuando el resultado se usa en el tablero.
  void useMachineResult() {
    state = state.copyWith(clearMachineResult: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Proveedor global para acceder al estado y lógica del juego desde la UI.
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});
