import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../domain/use_cases/math_engine.dart';
import '../providers/game_provider.dart';
import '../widgets/math_tile.dart';
import '../widgets/ad_banner.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/translations.dart';
import 'game_screen.dart';

class LevelEditorScreen extends ConsumerStatefulWidget {
  const LevelEditorScreen({super.key});

  @override
  ConsumerState<LevelEditorScreen> createState() => _LevelEditorScreenState();
}

class _LevelEditorScreenState extends ConsumerState<LevelEditorScreen> {
  int gridWidth = 9;
  int gridHeight = 9;
  List<GridCell> cells = [];
  CellType selectedType = CellType.number;
  String selectedValue = "1";
  bool isDarkMode = true;
  List<dynamic> savedGrids = [];
  bool _showInstructions = true;

  @override
  void initState() {
    super.initState();
    _resetGrid();
    _loadSavedGrids();
  }

  void _resetGrid() {
    setState(() {
      cells = [];
      for (int y = 0; y < gridHeight; y++) {
        for (int x = 0; x < gridWidth; x++) {
          cells.add(GridCell(x: x, y: y, type: CellType.empty));
        }
      }
    });
  }

  Future<void> _loadSavedGrids() async {
    final prefs = await SharedPreferences.getInstance();
    final String? gridsJson = prefs.getString('my_custom_grids');
    if (gridsJson != null) {
      setState(() {
        savedGrids = json.decode(gridsJson);
      });
    }
  }

  void _loadGridForEditing(Map<String, dynamic> gridData) {
    setState(() {
      gridWidth = gridData['width'];
      gridHeight = gridData['height'];
      cells = (gridData['cells'] as List)
          .map(
            (c) => GridCell(
              x: c['x'],
              y: c['y'],
              type: CellType.values[c['type']],
              value: c['value'],
              isFixed: c['isFixed'] ?? true,
            ),
          )
          .toList();

      // Aseguramos que la lista de celdas esté completa según el nuevo tamaño
      List<GridCell> fullCells = [];
      for (int y = 0; y < gridHeight; y++) {
        for (int x = 0; x < gridWidth; x++) {
          var existing = cells.where((c) => c.x == x && c.y == y).toList();
          if (existing.isNotEmpty) {
            fullCells.add(existing.first);
          } else {
            fullCells.add(GridCell(x: x, y: y, type: CellType.empty));
          }
        }
      }
      cells = fullCells;
    });
    Navigator.pop(context);
  }

  Future<void> _saveGrid() async {
    final l10n = ref.read(translationsProvider);

    // 1. Saneamiento: Eliminar operadores o iguales sueltos
    _sanitizeGrid();

    // 2. Validación: Chequear que haya al menos una ecuación válida
    String? validationError = _validateGridIntegrity();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Recortar filas y columnas vacías en los extremos
    final nonEmptyCells = cells.where((c) => c.type != CellType.empty).toList();
    if (nonEmptyCells.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.text('empty_grid_error'))));
      return;
    }

    int minX = nonEmptyCells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    int maxX = nonEmptyCells.map((c) => c.x).reduce((a, b) => a > b ? a : b);
    int minY = nonEmptyCells.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    int maxY = nonEmptyCells.map((c) => c.y).reduce((a, b) => a > b ? a : b);

    int finalWidth = maxX - minX + 1;
    int finalHeight = maxY - minY + 1;

    final trimmedCells = nonEmptyCells
        .map(
          (c) => {
            'x': c.x - minX,
            'y': c.y - minY,
            'type': c.type.index,
            'value': c.value,
            'isFixed': c.isFixed,
          },
        )
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final newGrid = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'width': finalWidth,
      'height': finalHeight,
      'cells': trimmedCells,
      'date': DateTime.now().toIso8601String(),
    };

    savedGrids.add(newGrid);
    await prefs.setString('my_custom_grids', json.encode(savedGrids));
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.text('grid_saved_success'))));
  }

  void _sanitizeGrid() {
    setState(() {
      for (int i = 0; i < cells.length; i++) {
        final cell = cells[i];
        if (cell.type == CellType.operator || cell.type == CellType.equals) {
          // Si es un operador o igual, debe tener vecinos
          bool hasHorizontal = _isPartOfEquation(cell.x, cell.y, true);
          bool hasVertical = _isPartOfEquation(cell.x, cell.y, false);
          if (!hasHorizontal && !hasVertical) {
            cells[i] = GridCell(x: cell.x, y: cell.y, type: CellType.empty);
          }
        }
      }
    });
  }

  bool _isPartOfEquation(int x, int y, bool horizontal) {
    int count = 0;
    if (horizontal) {
      for (int i = -4; i <= 4; i++) {
        final c = _getCellAt(x + i, y);
        if (c != null && c.type != CellType.empty) {
          count++;
          if (count >= 3) return true;
        } else {
          count = 0;
        }
      }
    } else {
      for (int i = -4; i <= 4; i++) {
        final c = _getCellAt(x, y + i);
        if (c != null && c.type != CellType.empty) {
          count++;
          if (count >= 3) return true;
        } else {
          count = 0;
        }
      }
    }
    return false;
  }

  String? _validateGridIntegrity() {
    final l10n = ref.read(translationsProvider);
    bool hasEquation = false;

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        if (_checkEquationAt(x, y, true) || _checkEquationAt(x, y, false)) {
          hasEquation = true;
          break;
        }
      }
      if (hasEquation) break;
    }

    if (!hasEquation) return l10n.text('error_no_valid_equations');
    return null;
  }

  bool _checkEquationAt(int x, int y, bool horizontal) {
    if (horizontal) {
      if (x > gridWidth - 5) return false;
      final c1 = _getCellAt(x, y);
      final c2 = _getCellAt(x + 1, y);
      final c3 = _getCellAt(x + 2, y);
      final c4 = _getCellAt(x + 3, y);
      final c5 = _getCellAt(x + 4, y);
      return _isValidSequence(c1, c2, c3, c4, c5);
    } else {
      if (y > gridHeight - 5) return false;
      final c1 = _getCellAt(x, y);
      final c2 = _getCellAt(x, y + 1);
      final c3 = _getCellAt(x, y + 2);
      final c4 = _getCellAt(x, y + 3);
      final c5 = _getCellAt(x, y + 4);
      return _isValidSequence(c1, c2, c3, c4, c5);
    }
  }

  bool _isValidSequence(
    GridCell? c1,
    GridCell? c2,
    GridCell? c3,
    GridCell? c4,
    GridCell? c5,
  ) {
    if (c1 == null || c2 == null || c3 == null || c4 == null || c5 == null)
      return false;
    return c1.type == CellType.number &&
        c2.type == CellType.operator &&
        c3.type == CellType.number &&
        c4.type == CellType.equals &&
        c5.type == CellType.number;
  }

  GridCell? _getCellAt(int x, int y) {
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) return null;
    return cells[y * gridWidth + x];
  }

  void _onCellTap(int index) {
    setState(() {
      final old = cells[index];
      if (old.type == selectedType && old.value == selectedValue) {
        cells[index] = GridCell(x: old.x, y: old.y, type: CellType.empty);
      } else {
        cells[index] = GridCell(
          x: old.x,
          y: old.y,
          type: selectedType,
          value: selectedValue,
          isFixed: true,
        );

        if (selectedValue == "=") {
          _tryAutoCalculate(old.x, old.y);
        }
      }
    });
  }

  void _tryAutoCalculate(int x, int y) {
    final h1 = _getCellAt(x - 3, y);
    final h2 = _getCellAt(x - 2, y);
    final h3 = _getCellAt(x - 1, y);
    if (h1?.type == CellType.number &&
        h2?.type == CellType.operator &&
        h3?.type == CellType.number) {
      final res = _compute(h1!.value!, h2!.value!, h3!.value!);
      if (res != null) _setCellAt(x + 1, y, CellType.number, res);
    }

    final v1 = _getCellAt(x, y - 3);
    final v2 = _getCellAt(x, y - 2);
    final v3 = _getCellAt(x, y - 1);
    if (v1?.type == CellType.number &&
        v2?.type == CellType.operator &&
        v3?.type == CellType.number) {
      final res = _compute(v1!.value!, v2!.value!, v3!.value!);
      if (res != null) _setCellAt(x, y + 1, CellType.number, res);
    }
  }

  String? _compute(String a, String op, String b) {
    final n1 = int.tryParse(a);
    final n2 = int.tryParse(b);
    if (n1 == null || n2 == null) return null;
    int res = 0;
    if (op == "+") {
      res = n1 + n2;
    } else if (op == "-")
      res = n1 - n2;
    else if (op == "*")
      res = n1 * n2;
    else if (op == "/") {
      if (n2 == 0) return null;
      if (n1 % n2 != 0) return null;
      res = n1 ~/ n2;
    }
    return res.toString();
  }

  void _setCellAt(int x, int y, CellType type, String val) {
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) return;
    setState(() {
      cells[y * gridWidth + x] = GridCell(
        x: x,
        y: y,
        type: type,
        value: val,
        isFixed: true,
      );
    });
  }

  void _addColumn() {
    setState(() {
      gridWidth++;
      List<GridCell> newCells = [];
      for (int y = 0; y < gridHeight; y++) {
        for (int x = 0; x < gridWidth; x++) {
          var existing = cells.where((c) => c.x == x && c.y == y).toList();
          if (existing.isNotEmpty) {
            newCells.add(existing.first);
          } else {
            newCells.add(GridCell(x: x, y: y, type: CellType.empty));
          }
        }
      }
      cells = newCells;
    });
  }

  void _addRow() {
    setState(() {
      gridHeight++;
      for (int x = 0; x < gridWidth; x++) {
        cells.add(GridCell(x: x, y: gridHeight - 1, type: CellType.empty));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final gridLineColor = isDarkMode ? Colors.white24 : Colors.black12;
    final cellColor = isDarkMode
        ? Colors.white24
        : Colors.blue.withOpacity(0.05);

    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(l10n.text('editor')),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.folder_special),
              onPressed: () => _showMyGrids(l10n),
            ),
            IconButton(icon: const Icon(Icons.save), onPressed: _saveGrid),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: gridLineColor),
                          ),
                          child: SizedBox(
                            width: gridWidth * 50.0,
                            height: gridHeight * 50.0,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridWidth,
                                  ),
                              itemCount: cells.length,
                              itemBuilder: (context, index) {
                                final cell = cells[index];
                                return DragTarget<int>(
                                  onAcceptWithDetails: (details) {
                                    setState(() {
                                      final fromIndex = details.data;
                                      final fromCell = cells[fromIndex];
                                      cells[index] = GridCell(
                                        x: cell.x,
                                        y: cell.y,
                                        type: fromCell.type,
                                        value: fromCell.value,
                                        isFixed: true,
                                      );
                                      cells[fromIndex] = GridCell(
                                        x: fromCell.x,
                                        y: fromCell.y,
                                        type: CellType.empty,
                                      );
                                    });
                                  },
                                  builder: (context, candidate, rejected) {
                                    return GestureDetector(
                                      onTap: () => _onCellTap(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: gridLineColor,
                                          ),
                                          color: cell.type == CellType.empty
                                              ? null
                                              : cellColor,
                                        ),
                                        child: cell.type == CellType.empty
                                            ? null
                                            : LongPressDraggable<int>(
                                                data: index,
                                                feedback: Material(
                                                  color: Colors.transparent,
                                                  child: MathTile(
                                                    value: cell.value ?? '',
                                                    size: 50,
                                                    animateOnEntry: false,
                                                  ),
                                                ),
                                                childWhenDragging:
                                                    const SizedBox.shrink(),
                                                child: Center(
                                                  child: Text(
                                                    cell.value ?? '',
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildFloatingControls(l10n),
                ],
              ),
            ),
            _buildToolbar(l10n),
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls(Translations l10n) {
    return Positioned(
      right: 10,
      top: 10,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'add_col',
            onPressed: _addColumn,
            child: const Icon(Icons.view_column),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'add_row',
            onPressed: _addRow,
            child: const Icon(Icons.table_rows),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'calc',
            onPressed: () => _showCalculator(l10n),
            backgroundColor: Colors.amber,
            child: const Icon(Icons.calculate, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _showCalculator(Translations l10n) {
    String calcText = "0";
    String operator = "";
    double firstOperand = 0;
    bool newNumber = true;

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void press(String btn) {
            setState(() {
              if (['+', '-', '×', '÷'].contains(btn)) {
                firstOperand = double.tryParse(calcText) ?? 0;
                operator = btn;
                newNumber = true;
              } else if (btn == '=') {
                double secondOperand = double.tryParse(calcText) ?? 0;
                if (operator == '+')
                  calcText = (firstOperand + secondOperand).toString();
                if (operator == '-')
                  calcText = (firstOperand - secondOperand).toString();
                if (operator == '×')
                  calcText = (firstOperand * secondOperand).toString();
                if (operator == '÷')
                  calcText = secondOperand != 0
                      ? (firstOperand / secondOperand).toString()
                      : 'Err';
                if (calcText.endsWith('.0'))
                  calcText = calcText.substring(0, calcText.length - 2);
                newNumber = true;
              } else if (btn == 'C') {
                calcText = "0";
                operator = "";
                firstOperand = 0;
                newNumber = true;
              } else {
                if (newNumber) {
                  calcText = btn;
                  newNumber = false;
                } else {
                  calcText = calcText == "0" ? btn : calcText + btn;
                }
              }
            });
          }

          Widget calcBtn(String text, {Color? color}) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        color ?? (isDarkMode ? Colors.grey[800] : Colors.white),
                    foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => press(text),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: isDarkMode
                ? const Color(0xFF1E1E1E)
                : Colors.grey[200],
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              l10n.text('calculator_title'),
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      calcText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      calcBtn('7'),
                      calcBtn('8'),
                      calcBtn('9'),
                      calcBtn('÷', color: Colors.orange),
                    ],
                  ),
                  Row(
                    children: [
                      calcBtn('4'),
                      calcBtn('5'),
                      calcBtn('6'),
                      calcBtn('×', color: Colors.orange),
                    ],
                  ),
                  Row(
                    children: [
                      calcBtn('1'),
                      calcBtn('2'),
                      calcBtn('3'),
                      calcBtn('-', color: Colors.orange),
                    ],
                  ),
                  Row(
                    children: [
                      calcBtn('C', color: Colors.redAccent),
                      calcBtn('0'),
                      calcBtn('=', color: Colors.green),
                      calcBtn('+', color: Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMyGrids(Translations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text('my_grids'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: savedGrids.isEmpty
                  ? Center(child: Text(l10n.text('no_grids_yet')))
                  : ListView.builder(
                      itemCount: savedGrids.length,
                      itemBuilder: (context, i) {
                        final g = savedGrids[i];
                        return ListTile(
                          leading: const Icon(Icons.grid_on),
                          title: Text(
                            '${l10n.text('grid_label')} ${g['width']}x${g['height']}',
                          ),
                          subtitle: Text(
                            '${l10n.text('date_label')}: ${g['date'].toString().split('T')[0]}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.orange,
                                ),
                                onPressed: () {
                                  _shareGridPdf(g, l10n);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _loadGridForEditing(g),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.green,
                                ),
                                onPressed: () => _playCustomGrid(g),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _playCustomGrid(Map<String, dynamic> gridData) {
    final List<GridCell> levelCells = (gridData['cells'] as List)
        .map(
          (c) => GridCell(
            x: c['x'],
            y: c['y'],
            type: CellType.values[c['type']],
            value: c['value'],
            isFixed: c['isFixed'] ?? true,
          ),
        )
        .toList();

    final customLevel = PuzzleLevel(
      id: gridData['id'],
      size: max(gridData['width'], gridData['height']),
      cells: levelCells,
      footerTiles:
          [], // Editor levels start solved or for testing? User said "to play"
    );

    ref.read(gameProvider.notifier).loadCustomLevel(customLevel);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  void _shareGridPdf(Map<String, dynamic> gridData, Translations l10n) async {
    final pdf = pw.Document();

    final int width = gridData['width'];
    final int height = gridData['height'];
    final List<dynamic> cellsData = gridData['cells'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'MathGrillaGame - ${l10n.text('custom_level_title')}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.black,
                      width: 1,
                    ),
                    children: List.generate(height, (y) {
                      return pw.TableRow(
                        children: List.generate(width, (x) {
                          final cell = cellsData.firstWhere(
                            (c) => c['x'] == x && c['y'] == y,
                            orElse: () => null,
                          );

                          final bool isEmpty =
                              cell == null ||
                              cell['type'] == CellType.empty.index;
                          final String val = isEmpty
                              ? ''
                              : (cell['value'] ?? '');

                          return pw.Container(
                            width: 30,
                            height: 30,
                            color: isEmpty
                                ? PdfColors.grey300
                                : PdfColors.white,
                            child: pw.Center(
                              child: pw.Text(
                                val,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  l10n.text('solve_this_puzzle'),
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'mathgrillagame_nivel.pdf',
    );
  }

  Widget _buildToolbar(Translations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDarkMode ? Colors.black26 : Colors.grey[200],
      child: Column(
        children: [
          if (_showInstructions)
            GestureDetector(
              onTap: () => setState(() => _showInstructions = false),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.text('select_tool_instruction'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Icon(Icons.close, color: Colors.blueAccent, size: 16),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _typeButton(CellType.number, Icons.numbers),
              _typeButton(CellType.operator, Icons.add),
              _typeButton(CellType.equals, Icons.drag_handle),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedType == CellType.number)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 20,
                itemBuilder: (context, i) => _valueButton(i.toString()),
              ),
            )
          else if (selectedType == CellType.operator)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                '+',
                '-',
                '*',
                '/',
              ].map((op) => _valueButton(op)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _typeButton(CellType type, IconData icon) {
    final isSelected = selectedType == type;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : null),
      onPressed: () => setState(() {
        selectedType = type;
        if (type == CellType.equals) {
          selectedValue = "=";
        } else if (type == CellType.operator)
          selectedValue = "+";
        else
          selectedValue = "1";
      }),
    );
  }

  Widget _valueButton(String val) {
    final isSelected = selectedValue == val;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(val),
        selected: isSelected,
        onSelected: (s) => setState(() => selectedValue = val),
      ),
    );
  }
}
