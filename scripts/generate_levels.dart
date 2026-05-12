import 'dart:convert';
import 'dart:io';
import 'dart:math';

enum CellType { empty, number, operator, equals }

class GridCell {
  final int x;
  final int y;
  final CellType type;
  final String? value;
  final bool isFixed;
  final bool isHorizontal; 

  GridCell(this.x, this.y, this.type, this.value, this.isFixed, this.isHorizontal);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'type': type.index,
    'value': value,
    'isFixed': isFixed,
    'isHorizontal': isHorizontal,
  };
}

class PuzzleLevel {
  final int id, size;
  final List<GridCell> cells;
  final List<String> footerTiles;
  PuzzleLevel(this.id, this.size, this.cells, this.footerTiles);
  Map<String, dynamic> toJson() => {
    'id': id,
    'size': size,
    'cells': cells.map((GridCell c) => c.toJson()).toList(),
    'footerTiles': footerTiles
  };
}

void main() {
  final Random random = Random();
  
  _generateCategory('easy', 100, (i) {
    int increment = i ~/ 20;
    int size = (5 + increment).clamp(5, 10);
    int numOps = 5 + (i ~/ 5); 
    return {'size': size, 'numOps': min(numOps, 20), 'maxNum': 20 + i};
  }, random);

  _generateCategory('medium', 350, (i) {
    int increment = i ~/ 70;
    int size = (11 + increment).clamp(11, 15);
    int numOps = 15 + (i ~/ 5); 
    return {'size': size, 'numOps': min(numOps, 180), 'maxNum': 100};
  }, random);

  _generateCategory('hard', 200, (i) {
    int increment = i ~/ 40;
    int size = (16 + increment).clamp(16, 20);
    int numOps = 30 + (i ~/ 3); 
    return {'size': size, 'numOps': min(numOps, 250), 'maxNum': 150};
  }, random);
}

void _generateCategory(String name, int count, Map<String, int> Function(int) config, Random random) {
  List<PuzzleLevel> levels = [];
  print('Generando categoría: $name...');
  for (int i = 1; i <= count; i++) {
    var cfg = config(i);
    levels.add(_generateLevel(name, i, cfg['size']!, cfg['numOps']!, cfg['maxNum']!, random));
    stdout.write('.'); // Puntito por cada nivel para ver que vive
    if (i % 20 == 0) print(' [$name $i/$count]');
  }
  final file = File('assets/levels_$name.json');
  file.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(levels.map((PuzzleLevel l) => l.toJson()).toList()));
}

PuzzleLevel _generateLevel(String difficulty, int id, int size, int numOps, int maxNum, Random random) {
  List<GridCell> cells = [];
  List<String> footer = [];
  List<String> ops = ['+', '-'];
  if (id > 5 || difficulty != 'easy') ops.add('*');
  if (id > 10 || difficulty != 'easy') ops.add('/');

  for (int attempt = 0; attempt < 100; attempt++) {
    bool horiz = random.nextBool();
    int x = random.nextInt(max(1, horiz ? size - 4 : size));
    int y = random.nextInt(max(1, horiz ? size : size - 4));
    if (_addOp(difficulty, cells, x, y, horiz, footer, ops, maxNum, random, id, size)) break;
  }

  for (int o = 1; o < numOps; o++) {
    bool added = false;
    // Seleccionamos candidatos a intersección de forma más eficiente
    var candidates = cells.where((GridCell c) => c.type == CellType.number).toList()..shuffle();
    
    for (int retry = 0; retry < 5 && !added; retry++) {
      for (var target in candidates) {
        bool vertical = !target.isHorizontal;
        // Solo probamos 2 posiciones al azar para ir más rápido
        var posList = [0, 1, 2]..shuffle();
        for (int pos in posList.take(2)) {
          int countBefore = cells.length;
          _addIntersectingOpEnhanced(difficulty, cells, target.x, target.y, vertical, footer, ops, target.value!, size, maxNum, random, id, pos);
          if (cells.length > countBefore) { 
            added = true; 
            break; 
          }
        }
        if (added) break;
      }
      if (added) break;
    }
    // Si después de varios intentos no pudimos añadir más, paramos para este nivel
    if (!added && o > numOps ~/ 2) break; 
  }

  footer.shuffle();
  return PuzzleLevel(id, size, cells, footer);
}

bool _addOp(String difficulty, List<GridCell> cells, int startX, int startY, bool horiz, List<String> footer, List<String> ops, int maxNum, Random random, int id, int size) {
  if (startX < 0 || startY < 0 || (horiz && startX + 5 > size) || (!horiz && startY + 5 > size)) return false;
  var data = _genOp(ops, maxNum, random);
  List<String> parts = [data['a']!, data['op']!, data['b']!, '=', data['res']!];
  for (int i = 0; i < 5; i++) {
    int x = horiz ? startX + i : startX;
    int y = horiz ? startY : startY + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isNotEmpty && existing.first.value != parts[i]) return false;
  }

  // Nueva lógica de fijos
  List<int> numberIndices = [0, 2, 4];
  List<int> fixedIndices = [];
  double fixedProb = (difficulty == 'easy') ? 0.4 : (difficulty == 'medium' ? 0.35 : 0.3);
  
  for (int idx in numberIndices) {
    double prob = fixedProb;
    if (idx == 4) prob += 0.1;
    if (random.nextDouble() < prob) fixedIndices.add(idx);
  }
  
  int maxFixed = (difficulty == 'hard') ? 1 : 2;
  if (fixedIndices.isEmpty && cells.isEmpty) fixedIndices.add([0, 2, 4][random.nextInt(3)]);
  while (fixedIndices.length > maxFixed) fixedIndices.removeAt(random.nextInt(fixedIndices.length));
  if (fixedIndices.length >= 3) fixedIndices.removeAt(0);

  for (int i = 0; i < 5; i++) {
    int x = horiz ? startX + i : startX;
    int y = horiz ? startY : startY + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isEmpty) {
      bool forceFixed = fixedIndices.contains(i);
      bool forceFooter = numberIndices.contains(i) && !fixedIndices.contains(i);
      _createCell(cells, x, y, parts[i], footer, random, horiz, forceFixed, forceFooter);
    }
  }
  return true;
}

void _addIntersectingOpEnhanced(String difficulty, List<GridCell> cells, int ix, int iy, bool horiz, List<String> footer, List<String> ops, String target, int size, int maxNum, Random random, int id, int pos) {
  int tVal = int.tryParse(target) ?? 0;
  var data = _genOpWithTargetEnhanced(ops, tVal, pos, maxNum, random);
  if (data == null) return;
  List<String> parts = [data['a']!, data['op']!, data['b']!, '=', data['res']!];
  int idx = (pos == 0) ? 0 : (pos == 1 ? 2 : 4);
  int sx = horiz ? ix - idx : ix;
  int sy = horiz ? iy : iy - idx;
  if (sx < 0 || sy < 0 || (horiz && sx + 5 > size) || (!horiz && sy + 5 > size)) return;
  for (int i = 0; i < 5; i++) {
    int x = horiz ? sx + i : sx;
    int y = horiz ? sy : sy + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isNotEmpty && existing.first.value != parts[i]) return;
  }

  // Nueva lógica fijos intersección
  List<int> numberIndices = [0, 2, 4];
  int intersectIdx = idx;
  List<int> otherIndices = numberIndices.where((i) => i != intersectIdx).toList();
  List<int> fixedIndices = [];
  double fixedProb = (difficulty == 'easy') ? 0.35 : (difficulty == 'medium' ? 0.3 : 0.25);
  
  for (int i in otherIndices) {
    double prob = fixedProb;
    if (i == 4) prob += 0.1;
    if (random.nextDouble() < prob) fixedIndices.add(i);
  }

  var existingIntersect = cells.firstWhere((c) => c.x == ix && c.y == iy);
  int totalFixedInEq = fixedIndices.length + (existingIntersect.isFixed ? 1 : 0);
  int maxFixed = (difficulty == 'hard') ? 1 : 2;
  while (totalFixedInEq > maxFixed && fixedIndices.isNotEmpty) {
    fixedIndices.removeAt(0);
    totalFixedInEq--;
  }

  for (int i = 0; i < 5; i++) {
    int x = horiz ? sx + i : sx;
    int y = horiz ? sy : sy + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isEmpty) {
      bool forceFixed = fixedIndices.contains(i);
      bool forceFooter = numberIndices.contains(i) && !fixedIndices.contains(i);
      _createCell(cells, x, y, parts[i], footer, random, horiz, forceFixed, forceFooter);
    }
  }
}

void _createCell(List<GridCell> cells, int x, int y, String val, List<String> footer, Random random, bool horiz, bool forceFixed, bool forceFooter) {
  bool isOp = ['+', '-', '*', '/', '='].contains(val);
  bool fixed = isOp;
  if (!isOp) {
    fixed = forceFixed;
    if (!fixed) footer.add(val);
  }
  cells.add(GridCell(x, y, isOp ? (val == '=' ? CellType.equals : CellType.operator) : CellType.number, val, fixed, horiz));
}

Map<String, dynamic> _genOp(List<String> ops, int max, Random r) {
  String op = ops[r.nextInt(ops.length)];
  int a = r.nextInt(max) + 2, b = r.nextInt(max) + 2;
  if (op == '-' && a < b) { int t = a; a = b; b = t; }
  if (op == '/') { int res = r.nextInt(max ~/ 5 + 5) + 1; b = r.nextInt(12) + 2; a = res * b; }
  int res = 0;
  if (op == '+') res = a + b; if (op == '-') res = a - b; if (op == '*') res = a * b; if (op == '/') res = a ~/ b;
  return {'a': a.toString(), 'op': op, 'b': b.toString(), 'res': res.toString()};
}

Map<String, dynamic>? _genOpWithTargetEnhanced(List<String> ops, int t, int pos, int max, Random r) {
  String op = ops[r.nextInt(ops.length)];
  int a = 0, b = 0, res = 0;
  if (pos == 0) {
    a = t; b = r.nextInt(max) + 1;
    if (op == '/') { b = r.nextInt(9) + 2; a = (a ~/ b) * b; if (a == 0) return null; }
  } else if (pos == 1) {
    b = t; a = r.nextInt(max) + 1;
    if (op == '/') { a = b * (r.nextInt(10) + 1); }
    if (op == '-' && a < b) a = b + r.nextInt(max);
  } else {
    res = t;
    if (op == '+') { a = r.nextInt(res.clamp(1, 1000)); b = res - a; }
    else if (op == '-') { b = r.nextInt(max); a = res + b; }
    else if (op == '*') { 
      var factors = []; 
      for(int i=1; i*i<=res; i++) {
        if(res % i == 0) {
          factors.add(i);
          if (i*i != res) factors.add(res ~/ i);
        }
      }
      if (factors.isEmpty) return null; a = factors[r.nextInt(factors.length)]; b = res ~/ a;
    } else { b = r.nextInt(10) + 1; a = res * b; }
    return {'a': a.toString(), 'op': op, 'b': b.toString(), 'res': res.toString()};
  }
  if (op == '+') res = a + b; 
  if (op == '-') res = a - b; 
  if (op == '*') res = a * b; 
  if (op == '/') {
    if (b == 0) b = 1;
    res = a ~/ b;
  }
  return {'a': a.toString(), 'op': op, 'b': b.toString(), 'res': res.toString()};
}
