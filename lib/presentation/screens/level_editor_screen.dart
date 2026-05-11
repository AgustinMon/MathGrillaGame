import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/puzzle_level.dart';
import '../../domain/use_cases/math_engine.dart';
import '../providers/game_provider.dart';
import '../widgets/math_tile.dart';
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
      cells = (gridData['cells'] as List).map((c) => GridCell(
        x: c['x'],
        y: c['y'],
        type: CellType.values[c['type']],
        value: c['value'],
        isFixed: c['isFixed'] ?? true,
      )).toList();
      
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
    // Recortar filas y columnas vacías en los extremos
    final nonEmptyCells = cells.where((c) => c.type != CellType.empty).toList();
    if (nonEmptyCells.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La grilla está vacía.')));
      return;
    }

    int minX = nonEmptyCells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    int maxX = nonEmptyCells.map((c) => c.x).reduce((a, b) => a > b ? a : b);
    int minY = nonEmptyCells.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    int maxY = nonEmptyCells.map((c) => c.y).reduce((a, b) => a > b ? a : b);

    int finalWidth = maxX - minX + 1;
    int finalHeight = maxY - minY + 1;

    final trimmedCells = nonEmptyCells.map((c) => {
      'x': c.x - minX,
      'y': c.y - minY,
      'type': c.type.index,
      'value': c.value,
      'isFixed': c.isFixed,
    }).toList();

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Grilla guardada!')));
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
      }
    });
  }

  void _addColumn() {
    setState(() {
      gridWidth++;
      List<GridCell> newCells = [];
      for (int y = 0; y < gridHeight; y++) {
        for (int x = 0; x < gridWidth; x++) {
          var existing = cells.where((c) => c.x == x && c.y == y).toList();
          if (existing.isNotEmpty) newCells.add(existing.first);
          else newCells.add(GridCell(x: x, y: y, type: CellType.empty));
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
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final gridLineColor = isDarkMode ? Colors.white24 : Colors.black12;
    final cellColor = isDarkMode ? Colors.white24 : Colors.blue.withOpacity(0.05);

    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('Editor'),
          actions: [
            IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: () => setState(() => isDarkMode = !isDarkMode)),
            IconButton(icon: const Icon(Icons.folder_special), onPressed: _showMyGrids),
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
                          decoration: BoxDecoration(border: Border.all(color: gridLineColor)),
                          child: SizedBox(
                            width: gridWidth * 50.0,
                            height: gridHeight * 50.0,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridWidth),
                              itemCount: cells.length,
                              itemBuilder: (context, index) {
                                final cell = cells[index];
                                return DragTarget<int>(
                                  onAcceptWithDetails: (details) {
                                    setState(() {
                                      final fromIndex = details.data;
                                      final fromCell = cells[fromIndex];
                                      cells[index] = GridCell(x: cell.x, y: cell.y, type: fromCell.type, value: fromCell.value, isFixed: true);
                                      cells[fromIndex] = GridCell(x: fromCell.x, y: fromCell.y, type: CellType.empty);
                                    });
                                  },
                                  builder: (context, candidate, rejected) {
                                    return GestureDetector(
                                      onTap: () => _onCellTap(index),
                                      child: Container(
                                        decoration: BoxDecoration(border: Border.all(color: gridLineColor), color: cell.type == CellType.empty ? null : cellColor),
                                        child: cell.type == CellType.empty 
                                          ? null 
                                          : Draggable<int>(
                                              data: index,
                                              feedback: Material(color: Colors.transparent, child: MathTile(value: cell.value ?? '', size: 50, animateOnEntry: false)),
                                              childWhenDragging: const SizedBox.shrink(),
                                              child: Center(child: Text(cell.value ?? '', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
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
                  _buildFloatingControls(),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black54 : Colors.white70,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '👆 Selecciona abajo y toca la grilla para dibujar',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 1.seconds).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
                    ),
                  ),
                ],
              ),
            ),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(right: 10, top: 10, child: Column(children: [
      FloatingActionButton.small(heroTag: 'add_col', onPressed: _addColumn, child: const Icon(Icons.view_column)),
      const SizedBox(height: 10),
      FloatingActionButton.small(heroTag: 'add_row', onPressed: _addRow, child: const Icon(Icons.table_rows)),
      const SizedBox(height: 10),
      FloatingActionButton.small(heroTag: 'calc', onPressed: _showCalculator, backgroundColor: Colors.amber, child: const Icon(Icons.calculate, color: Colors.black)),
    ]));
  }

  void _showCalculator() {
    String calcText = "0";
    String operator = "";
    double firstOperand = 0;
    bool newNumber = true;

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        void press(String btn) {
          setState(() {
            if (['+', '-', '×', '÷'].contains(btn)) {
              firstOperand = double.tryParse(calcText) ?? 0;
              operator = btn;
              newNumber = true;
            } else if (btn == '=') {
              double secondOperand = double.tryParse(calcText) ?? 0;
              if (operator == '+') calcText = (firstOperand + secondOperand).toString();
              if (operator == '-') calcText = (firstOperand - secondOperand).toString();
              if (operator == '×') calcText = (firstOperand * secondOperand).toString();
              if (operator == '÷') calcText = secondOperand != 0 ? (firstOperand / secondOperand).toString() : 'Err';
              if (calcText.endsWith('.0')) calcText = calcText.substring(0, calcText.length - 2);
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
                  backgroundColor: color ?? (isDarkMode ? Colors.grey[800] : Colors.white),
                  foregroundColor: isDarkMode ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => press(text),
                child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[200],
          contentPadding: const EdgeInsets.all(16),
          title: Text('Calculadora', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black)),
          content: SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                  child: Text(calcText, textAlign: TextAlign.right, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                ),
                const SizedBox(height: 10),
                Row(children: [calcBtn('7'), calcBtn('8'), calcBtn('9'), calcBtn('÷', color: Colors.orange)]),
                Row(children: [calcBtn('4'), calcBtn('5'), calcBtn('6'), calcBtn('×', color: Colors.orange)]),
                Row(children: [calcBtn('1'), calcBtn('2'), calcBtn('3'), calcBtn('-', color: Colors.orange)]),
                Row(children: [calcBtn('C', color: Colors.redAccent), calcBtn('0'), calcBtn('=', color: Colors.green), calcBtn('+', color: Colors.orange)]),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showMyGrids() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Grillas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: savedGrids.isEmpty 
                ? const Center(child: Text('No has guardado grillas aún.'))
                : ListView.builder(
                    itemCount: savedGrids.length,
                    itemBuilder: (context, i) {
                      final g = savedGrids[i];
                      return ListTile(
                        leading: const Icon(Icons.grid_on),
                        title: Text('Grilla ${g['width']}x${g['height']}'),
                        subtitle: Text('Fecha: ${g['date'].toString().split('T')[0]}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.share, color: Colors.orange), onPressed: () {
                            Clipboard.setData(ClipboardData(text: json.encode(g)));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nivel copiado al portapapeles para compartir')));
                          }),
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _loadGridForEditing(g)),
                          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green), onPressed: () => _playCustomGrid(g)),
                        ]),
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
    final List<GridCell> levelCells = (gridData['cells'] as List).map((c) => GridCell(
      x: c['x'],
      y: c['y'],
      type: CellType.values[c['type']],
      value: c['value'],
      isFixed: c['isFixed'] ?? true,
    )).toList();

    final customLevel = PuzzleLevel(
      id: gridData['id'],
      size: max(gridData['width'], gridData['height']),
      cells: levelCells,
      footerTiles: [], // Editor levels start solved or for testing? User said "to play"
    );

    ref.read(gameProvider.notifier).loadCustomLevel(customLevel);
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const GameScreen()));
  }

  Widget _buildToolbar() {
    return Container(padding: const EdgeInsets.all(16), color: isDarkMode ? Colors.black26 : Colors.grey[200], child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _typeButton(CellType.number, Icons.numbers),
        _typeButton(CellType.operator, Icons.add),
        _typeButton(CellType.equals, Icons.drag_handle),
      ]),
      const SizedBox(height: 16),
      if (selectedType == CellType.number)
        SizedBox(height: 50, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 20, itemBuilder: (context, i) => _valueButton(i.toString())))
      else if (selectedType == CellType.operator)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ['+', '-', '*', '/'].map((op) => _valueButton(op)).toList()),
    ]));
  }

  Widget _typeButton(CellType type, IconData icon) {
    final isSelected = selectedType == type;
    return IconButton(icon: Icon(icon, color: isSelected ? Colors.blue : null), onPressed: () => setState(() {
      selectedType = type;
      if (type == CellType.equals) selectedValue = "=";
      else if (type == CellType.operator) selectedValue = "+";
      else selectedValue = "1";
    }));
  }

  Widget _valueButton(String val) {
    final isSelected = selectedValue == val;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(val), selected: isSelected, onSelected: (s) => setState(() => selectedValue = val)));
  }
}
