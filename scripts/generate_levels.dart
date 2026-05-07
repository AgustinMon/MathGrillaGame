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
  
  _generateCategory('easy', (i) {
    int size = 6;
    int numOps = 5 + (i ~/ 5); 
    if (i >= 20) size = 8;
    return {'size': size, 'numOps': min(numOps, 20), 'maxNum': 20 + i};
  }, random);

  _generateCategory('medium', (i) {
    int size = 8;
    int numOps = 15 + (i * 2); 
    if (i >= 5) { size = 14; numOps = max(numOps, 40); }
    if (i >= 10) { size = 20; numOps = max(numOps, 80); }
    if (i >= 15) { size = 25; numOps = max(numOps, 120); }
    return {'size': size, 'numOps': min(numOps, 180), 'maxNum': 100};
  }, random);

  _generateCategory('hard', (i) {
    int size = 12;
    int numOps = 30 + (i * 3); 
    if (i >= 5) { size = 18; numOps = max(numOps, 60); }
    if (i >= 10) { size = 24; numOps = max(numOps, 100); }
    if (i >= 15) { size = 30; numOps = max(numOps, 150); }
    return {'size': size, 'numOps': min(numOps, 250), 'maxNum': 150};
  }, random);
}

void _generateCategory(String name, Map<String, int> Function(int) config, Random random) {
  List<PuzzleLevel> levels = [];
  print('Generando categoría: $name...');
  for (int i = 1; i <= 200; i++) {
    var cfg = config(i);
    levels.add(_generateLevel(i, cfg['size']!, cfg['numOps']!, cfg['maxNum']!, random));
    stdout.write('.'); // Puntito por cada nivel para ver que vive
    if (i % 20 == 0) print(' [$name $i/200]');
  }
  final file = File('assets/levels_$name.json');
  file.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(levels.map((PuzzleLevel l) => l.toJson()).toList()));
}

PuzzleLevel _generateLevel(int id, int size, int numOps, int maxNum, Random random) {
  List<GridCell> cells = [];
  List<String> footer = [];
  List<String> ops = ['+', '-'];
  if (id > 5) ops.add('*');
  if (id > 10) ops.add('/');

  for (int attempt = 0; attempt < 100; attempt++) {
    bool horiz = random.nextBool();
    int x = random.nextInt(max(1, horiz ? size - 4 : size));
    int y = random.nextInt(max(1, horiz ? size : size - 4));
    if (_addOp(cells, x, y, horiz, footer, ops, maxNum, random, id, size)) break;
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
          _addIntersectingOpEnhanced(cells, target.x, target.y, vertical, footer, ops, target.value!, size, maxNum, random, id, pos);
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

bool _addOp(List<GridCell> cells, int startX, int startY, bool horiz, List<String> footer, List<String> ops, int maxNum, Random random, int id, int size) {
  if (startX < 0 || startY < 0 || (horiz && startX + 5 > size) || (!horiz && startY + 5 > size)) return false;
  var data = _genOp(ops, maxNum, random);
  List<String> parts = [data['a'], data['op'], data['b'], '=', data['res']];
  for (int i = 0; i < 5; i++) {
    int x = horiz ? startX + i : startX;
    int y = horiz ? startY : startY + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isNotEmpty && existing.first.value != parts[i]) return false;
  }
  for (int i = 0; i < 5; i++) {
    int x = horiz ? startX + i : startX;
    int y = horiz ? startY : startY + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isEmpty) _createCell(cells, x, y, parts[i], footer, id, random, horiz);
  }
  return true;
}

void _addIntersectingOpEnhanced(List<GridCell> cells, int ix, int iy, bool horiz, List<String> footer, List<String> ops, String target, int size, int maxNum, Random random, int id, int pos) {
  int tVal = int.tryParse(target) ?? 0;
  var data = _genOpWithTargetEnhanced(ops, tVal, pos, maxNum, random);
  if (data == null) return;
  List<String> parts = [data['a'], data['op'], data['b'], '=', data['res']];
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
  for (int i = 0; i < 5; i++) {
    int x = horiz ? sx + i : sx;
    int y = horiz ? sy : sy + i;
    var existing = cells.where((GridCell c) => c.x == x && c.y == y).toList();
    if (existing.isEmpty) _createCell(cells, x, y, parts[i], footer, id, random, horiz);
  }
}

void _createCell(List<GridCell> cells, int x, int y, String val, List<String> footer, int id, Random random, bool horiz) {
  bool isOp = ['+', '-', '*', '/', '='].contains(val);
  bool fixed = isOp;
  if (!isOp) {
    double prob = 0.3 / (1 + (id / 50));
    if (random.nextDouble() < prob) fixed = true;
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
