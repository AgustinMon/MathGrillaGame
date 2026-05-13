"""
Crossmath level generator (v2).

Diseño:
- Tamaño de grilla y nº de ecuaciones se eligen aleatoriamente dentro
  de un rango por modo, no son fijos.
- Las ecuaciones son palabras de 5 celdas: [A] [op] [B] [=] [R].
- Intersecciones sólo perpendiculares y sólo en celdas numéricas con
  valor coincidente; operadores y '=' no se intersectan jamás.
- Reglas de adyacencia tipo crucigrama (sin paralelas pegadas, sin
  concatenación accidental, sin extensión más allá de los 5 tokens).
- Colocación O(1) por anchor: índice value → coords para encontrar
  candidatos de intersección sin escanear el tablero.
- Validación de unicidad por CSP con forward checking sobre dominios
  reales (lista de tokens disponibles en el footer).
- Selección de pistas con dos invariantes:
    a) máx 1 pista por ecuación;
    b) ninguna ecuación arranca con sus 3 números visibles.
- Cada nivel pasa por un validador externo independiente antes de
  aceptarse (defensa en profundidad).
"""

import json
import os
import random
import sys
from collections import Counter, defaultdict

from validate import validate_level

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------

OPS = ["+", "-", "*", "/"]

CONFIG = {
    "easy": {
        "size_range": (7, 9),
        "eq_range": (4, 6),
        "levels": 50,
        "weights": [0.50, 0.30, 0.15, 0.05],
        "num_range": (1, 20),
        "min_r": 1,
        "min_clues_ratio": 0.25,
        "max_clues_ratio": 0.50,
        "min_density": 0.35,
        "min_distinct": 5,
    },
    "medium": {
        "size_range": (10, 13),
        "eq_range": (8, 12),
        "levels": 50,
        "weights": [0.30, 0.25, 0.30, 0.15],
        "num_range": (5, 50),
        "min_r": 5,
        "min_clues_ratio": 0.25,
        "max_clues_ratio": 0.45,
        "min_density": 0.30,
        "min_distinct": 6,
    },
    "hard": {
        "size_range": (14, 17),
        "eq_range": (12, 18),
        "levels": 50,
        "weights": [0.20, 0.20, 0.35, 0.25],
        "num_range": (10, 99),
        "min_r": 5,
        "min_clues_ratio": 0.20,
        "max_clues_ratio": 0.40,
        "min_density": 0.25,
        "min_distinct": 6,
    },
}

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------------------
# Ecuaciones
# ---------------------------------------------------------------------------

def _eq_is_valid(a, op, b, r, mode):
    """Verifica que una tupla (a,op,b,r) cumpla todas las reglas del modo."""
    conf = CONFIG[mode]
    lo, hi = conf["num_range"]
    min_r = conf["min_r"]

    if a < 1 or b < 1 or r < min_r:
        return False
    if a > 999 or b > 999 or r > 999:
        return False
    if op == "+":
        if a == b:
            return False
        if not (lo <= a <= hi and lo <= b <= hi):
            return False
        return a + b == r
    if op == "-":
        if a <= b:
            return False
        if not (lo <= a <= hi and lo <= b <= hi):
            return False
        return a - b == r
    if op == "*":
        if a == b and mode != "hard":
            return False
        if not (lo <= a <= hi and lo <= b <= hi):
            return False
        return a * b == r
    if op == "/":
        if b < 2 or b > 10:
            return False
        if r < 1 or r > hi:
            return False
        return a == b * r
    return False


def _candidate_eqs_for_slot(slot, fixed_val, mode, rng, max_results=20):
    """Enumera ecuaciones válidas donde el slot dado (0=a, 2=b, 4=r) toma
    el valor `fixed_val`. Devuelve hasta `max_results` ecuaciones barajadas.

    Esta es la clave del backtracking nivel (1): en vez de generar al azar
    y rezar para que coincida con la celda de anchor, enumeramos
    directamente las ecuaciones compatibles.
    """
    conf = CONFIG[mode]
    lo, hi = conf["num_range"]
    min_r = conf["min_r"]
    v = fixed_val
    out = []

    def add(eq):
        a, op, b, r = eq
        if _eq_is_valid(a, op, b, r, mode):
            out.append(eq)

    ops = OPS[:]
    rng.shuffle(ops)

    for op in ops:
        if op == "+":
            # a + b = r, una incógnita es v
            if slot == 0:  # a = v
                # b en [lo,hi], r = v+b
                for b in range(lo, hi + 1):
                    add((v, "+", b, v + b))
            elif slot == 2:  # b = v
                for a in range(lo, hi + 1):
                    add((a, "+", v, a + v))
            else:  # r = v
                # a + b = v, ambos en [lo,hi]
                for a in range(lo, min(hi, v - lo) + 1):
                    b = v - a
                    if lo <= b <= hi:
                        add((a, "+", b, v))

        elif op == "-":
            # a - b = r, a > b
            if slot == 0:  # a = v
                for b in range(lo, min(hi, v - 1) + 1):
                    add((v, "-", b, v - b))
            elif slot == 2:  # b = v
                for a in range(v + 1, hi + 1):
                    add((a, "-", v, a - v))
            else:  # r = v
                for b in range(lo, hi + 1):
                    a = v + b
                    if lo <= a <= hi:
                        add((a, "-", b, v))

        elif op == "*":
            if slot == 0:
                for b in range(lo, hi + 1):
                    add((v, "*", b, v * b))
            elif slot == 2:
                for a in range(lo, hi + 1):
                    add((a, "*", v, a * v))
            else:  # r = v: divisores de v
                if v <= 0:
                    continue
                d = 1
                while d * d <= v:
                    if v % d == 0:
                        a, b = d, v // d
                        if lo <= a <= hi and lo <= b <= hi:
                            add((a, "*", b, v))
                        if a != b:
                            a2, b2 = b, d
                            if lo <= a2 <= hi and lo <= b2 <= hi:
                                add((a2, "*", b2, v))
                    d += 1

        else:  # "/"
            # a / b = r, con b en [2,10], r en [1,hi]
            if slot == 0:  # a = v: descomponer v = b*r
                for b in range(2, 11):
                    if v % b == 0:
                        r = v // b
                        if 1 <= r <= hi:
                            add((v, "/", b, r))
            elif slot == 2:  # b = v: necesita v en [2,10]
                if 2 <= v <= 10:
                    for r in range(1, hi + 1):
                        a = v * r
                        add((a, "/", v, r))
            else:  # r = v
                for b in range(2, 11):
                    a = v * b
                    add((a, "/", b, v))

    # Deduplicar manteniendo orden
    seen = set()
    uniq = []
    for eq in out:
        if eq not in seen:
            seen.add(eq)
            uniq.append(eq)
    rng.shuffle(uniq)
    return uniq[:max_results]


def generate_equation(mode, rng):
    """Genera una ecuación sin restricciones (para la primera del tablero)."""
    conf = CONFIG[mode]
    lo, hi = conf["num_range"]
    min_r = conf["min_r"]

    for _ in range(2000):
        op = rng.choices(OPS, weights=conf["weights"])[0]

        if op == "+":
            a = rng.randint(lo, hi)
            b = rng.randint(lo, hi)
            if a == b:
                continue
            r = a + b
        elif op == "-":
            a = rng.randint(lo, hi)
            b = rng.randint(lo, hi)
            if a <= b:
                continue
            r = a - b
        elif op == "*":
            a = rng.randint(lo, hi)
            b = rng.randint(lo, hi)
            if a == b and mode != "hard":
                continue
            r = a * b
        else:  # "/"
            b = rng.randint(2, 10)
            r = rng.randint(1, hi)
            a = b * r

        if r > 999 or r < min_r:
            continue
        if a > 999:
            continue
        return (a, op, b, r)

    return None


def equation_tokens(eq):
    a, op, b, r = eq
    return [str(a), op, str(b), "=", str(r)]


# ---------------------------------------------------------------------------
# Grid + índice de búsqueda
# ---------------------------------------------------------------------------

class Grid:
    """Tablero con índices auxiliares:
        cells: (x,y) -> {val, kind, orients}
        num_index: val(str) -> set de (x,y) numéricos con ese valor
        free_orient: (x,y) -> {orientaciones disponibles para nuevas ecuaciones}
    """

    def __init__(self, size):
        self.size = size
        self.cells = {}
        self.num_index = defaultdict(set)

    def in_bounds(self, x, y):
        return 0 <= x < self.size and 0 <= y < self.size

    def get(self, x, y):
        return self.cells.get((x, y))

    @staticmethod
    def kind_of(val):
        if val in OPS:
            return "op"
        if val == "=":
            return "eq"
        return "num"

    # -- adyacencia ----------------------------------------------------------

    def can_place(self, x, y, orient, tokens):
        """Verifica si la ecuación encaja desde (x,y) con orientación 'H'/'V'.
        Devuelve coords si encaja, o None.

        Reglas:
        1) dentro del tablero
        2) intersecciones SOLO en celdas numéricas, perpendicular,
           con valor idéntico
        3) ninguna celda numérica nueva colinda en perpendicular con
           otra celda (paralelas pegadas)
        4) en la dirección de la palabra, antes del primer token y
           después del último no debe haber otra celda (evita extensión
           y concatenación numérica)
        """
        dx, dy = (1, 0) if orient == "H" else (0, 1)
        coords = [(x + i * dx, y + i * dy) for i in range(5)]

        # 1) Bounds
        for cx, cy in coords:
            if not self.in_bounds(cx, cy):
                return None

        # 4a) Pre/post de la palabra
        before = (x - dx, y - dy)
        after = (coords[-1][0] + dx, coords[-1][1] + dy)
        for nb in (before, after):
            if self.in_bounds(*nb) and nb in self.cells:
                return None

        # 2 y 3) Celda por celda
        for (cx, cy), tok in zip(coords, tokens):
            tok_kind = self.kind_of(tok)
            existing = self.cells.get((cx, cy))

            if existing is not None:
                # Intersección
                if tok_kind != "num" or existing["kind"] != "num":
                    return None
                if orient in existing["orients"]:
                    return None
                if existing["val"] != str(tok):
                    return None
                # Las intersecciones son OK; el chequeo de perpendicular
                # adyacente se hace para celdas NUEVAS, no para existentes.
            else:
                # Celda nueva: ningún vecino perpendicular puede estar ocupado
                perp = [(-dy, dx), (dy, -dx)]
                for pdx, pdy in perp:
                    nx, ny = cx + pdx, cy + pdy
                    if self.in_bounds(nx, ny) and (nx, ny) in self.cells:
                        return None
                # Vecino en la dirección de la palabra que no sea coords:
                # imposible si las reglas 4a se respetan (ya cubierto).
        return coords

    def place(self, coords, tokens, orient):
        """Coloca la ecuación. Devuelve un 'undo record' para revertir."""
        undo = []  # lista de operaciones para revertir en orden inverso
        for (cx, cy), tok in zip(coords, tokens):
            kind = self.kind_of(tok)
            if (cx, cy) in self.cells:
                # Intersección: sólo añadimos la orientación
                self.cells[(cx, cy)]["orients"].add(orient)
                undo.append(("orient", (cx, cy), orient))
            else:
                self.cells[(cx, cy)] = {
                    "val": str(tok),
                    "kind": kind,
                    "orients": {orient},
                }
                if kind == "num":
                    self.num_index[str(tok)].add((cx, cy))
                undo.append(("new", (cx, cy), str(tok), kind))
        return undo

    def unplace(self, undo):
        """Revierte una colocación usando su undo record."""
        for action in reversed(undo):
            if action[0] == "new":
                _, xy, val, kind = action
                if kind == "num":
                    self.num_index[val].discard(xy)
                    if not self.num_index[val]:
                        del self.num_index[val]
                del self.cells[xy]
            elif action[0] == "orient":
                _, xy, orient = action
                self.cells[xy]["orients"].discard(orient)

    # -- conectividad --------------------------------------------------------

    def is_connected(self):
        if not self.cells:
            return False
        start = next(iter(self.cells))
        seen = {start}
        stack = [start]
        while stack:
            x, y = stack.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (x + dx, y + dy)
                if nb in self.cells and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
        return len(seen) == len(self.cells)


# ---------------------------------------------------------------------------
# Construcción del tablero
# ---------------------------------------------------------------------------

def _enumerate_anchor_options(grid, rng):
    """Devuelve celdas numéricas con orientaciones libres, barajadas y
    priorizadas por menor grado (las celdas con menos orientaciones libres
    primero, para no agotar las celdas claves al final)."""
    options = []
    for xy, c in grid.cells.items():
        if c["kind"] != "num":
            continue
        free = []
        if "H" not in c["orients"]:
            free.append("H")
        if "V" not in c["orients"]:
            free.append("V")
        if free:
            options.append((xy, c["val"], free))
    rng.shuffle(options)
    # Priorizar celdas con menos orientaciones libres (= más restringidas)
    options.sort(key=lambda o: len(o[2]))
    return options


def try_place_connected(grid, mode, rng, max_anchor_tries=15):
    """Intento de colocación nivel (1): enumera candidatos por anchor y
    deriva ecuaciones que satisfagan la restricción del anchor.

    Devuelve (equation_dict, undo_record) o (None, None).
    """
    anchor_options = _enumerate_anchor_options(grid, rng)
    if not anchor_options:
        return None, None

    for (ex, ey), anchor_val, free_orients in anchor_options[:max_anchor_tries]:
        try:
            v_int = int(anchor_val)
        except ValueError:
            continue

        # Probar las 3 posiciones numéricas (a=0, b=2, r=4)
        slots = [0, 2, 4]
        rng.shuffle(slots)

        for slot in slots:
            cand_eqs = _candidate_eqs_for_slot(slot, v_int, mode, rng,
                                               max_results=5)
            if not cand_eqs:
                continue

            orients = list(free_orients)
            rng.shuffle(orients)

            for eq in cand_eqs:
                tokens = equation_tokens(eq)
                for orient in orients:
                    dx, dy = (1, 0) if orient == "H" else (0, 1)
                    sx = ex - slot * dx
                    sy = ey - slot * dy
                    coords = grid.can_place(sx, sy, orient, tokens)
                    if coords:
                        undo = grid.place(coords, tokens, orient)
                        return ({
                            "coords": coords, "tokens": tokens,
                            "orient": orient,
                            "a": eq[0], "op": eq[1],
                            "b": eq[2], "r": eq[3],
                        }, undo)
    return None, None


def _pick_size_and_target(mode, rng):
    """Elige tamaño y cantidad objetivo de ecuaciones de forma acoplada,
    para garantizar que la densidad objetivo es alcanzable.

    Cada ecuación aporta hasta 5 celdas nuevas (menos las intersecciones).
    Asumimos ~1 intersección por ecuación adicional, luego cada eq aporta
    ~4 celdas nuevas. Para alcanzar density ≥ min_density en una grilla
    de size² celdas, necesitamos:
        eqs * 4 + 1 >= min_density * size²
    """
    conf = CONFIG[mode]
    smin, smax = conf["size_range"]
    emin, emax = conf["eq_range"]
    min_density = conf["min_density"]

    # Para cada tamaño posible, calcular el rango factible de ecuaciones
    candidates = []
    for s in range(smin, smax + 1):
        cells_needed = min_density * s * s
        # ecuaciones mínimas para alcanzar densidad (4 celdas nuevas por eq
        # contando intersecciones obligatorias)
        e_for_density = max(emin, int((cells_needed - 1) / 4 + 0.999))
        # ecuaciones máximas físicamente plausibles
        e_max_phys = (s * s) // 3
        e_lo = max(emin, e_for_density)
        e_hi = min(emax, e_max_phys)
        if e_lo <= e_hi:
            candidates.append((s, e_lo, e_hi))

    if not candidates:
        # Fallback: usar el tamaño más chico y el mínimo de eqs
        return smin, emin

    s, e_lo, e_hi = rng.choice(candidates)
    return s, rng.randint(e_lo, e_hi)


def build_board(mode, rng, max_total_steps=100):
    """Backtracking nivel (2): si en algún paso no se logra extender,
    se retrocede y se reemplaza la última ecuación por otra.

    Aborta temprano si la densidad proyectada no alcanza el mínimo.
    """
    conf = CONFIG[mode]
    size, eq_target = _pick_size_and_target(mode, rng)
    eq_min = conf["eq_range"][0]
    min_density = conf["min_density"]
    target_cells = int(min_density * size * size)

    grid = Grid(size)
    equations = []
    undos = []

    # 1) Primera ecuación (sin restricciones de anchor)
    first = _place_first(grid, mode, rng)
    if first is None:
        return None
    eq_dict, eq_undo = first
    equations.append(eq_dict)
    undos.append(eq_undo)

    steps = 0
    fail_streak = 0
    max_fail_streak = 15

    while len(equations) < eq_target and steps < max_total_steps:
        steps += 1

        # Early-exit progresivo: tras la primera ecuación, cada ecuación
        # adicional aporta ~4 celdas nuevas (porque debe intersectar). Si
        # con eso no llegamos al objetivo, abortar.
        eqs_remaining = eq_target - len(equations)
        max_cells_possible = len(grid.cells) + eqs_remaining * 4
        if max_cells_possible < target_cells:
            return None

        eq_dict, eq_undo = try_place_connected(grid, mode, rng)

        if eq_dict is not None:
            equations.append(eq_dict)
            undos.append(eq_undo)
            fail_streak = 0
        else:
            fail_streak += 1
            if fail_streak >= max_fail_streak and len(equations) > 1:
                # Backtrack: revertir la última ecuación
                grid.unplace(undos.pop())
                equations.pop()
                fail_streak = 0

    # Validación final de densidad y mínimo de ecuaciones
    if len(grid.cells) < target_cells:
        return None
    if len(equations) < eq_min:
        return None

    return grid, equations


def _place_first(grid, mode, rng):
    """Coloca la primera ecuación cerca del centro. Devuelve (eq_dict, undo)."""
    size = grid.size
    for _ in range(200):
        eq = generate_equation(mode, rng)
        if eq is None:
            continue
        tokens = equation_tokens(eq)
        orient = rng.choice(["H", "V"])
        cx, cy = size // 2, size // 2
        if orient == "H":
            x = max(0, min(size - 5, cx - 2 + rng.randint(-1, 1)))
            y = max(0, min(size - 1, cy + rng.randint(-1, 1)))
        else:
            x = max(0, min(size - 1, cx + rng.randint(-1, 1)))
            y = max(0, min(size - 5, cy - 2 + rng.randint(-1, 1)))
        coords = grid.can_place(x, y, orient, tokens)
        if coords:
            undo = grid.place(coords, tokens, orient)
            return ({"coords": coords, "tokens": tokens, "orient": orient,
                     "a": eq[0], "op": eq[1], "b": eq[2], "r": eq[3]},
                    undo)
    return None


# ---------------------------------------------------------------------------
# CSP: unicidad por forward checking
# ---------------------------------------------------------------------------

def solve_unique(grid, equations, clue_coords, limit=2):
    """Cuenta soluciones (hasta `limit`) compatibles con las pistas dadas.

    Variables: celdas numéricas no-pista.
    Dominio: multiset (pool) de valores del footer.

    Optimización clave: en cada paso, buscar primero ecuaciones con 2
    valores conocidos donde el 3º queda determinado por aritmética.
    Esto reduce drásticamente el branching factor.
    """
    num_cells = [xy for xy, c in grid.cells.items() if c["kind"] == "num"]
    variables = [xy for xy in num_cells if xy not in clue_coords]
    if not variables:
        return 1

    pool_init = Counter(grid.cells[xy]["val"] for xy in variables)

    # Ecuaciones como tuplas (a_xy, b_xy, r_xy, op)
    eqs = []
    for eq in equations:
        a_xy, _, b_xy, _, r_xy = eq["coords"]
        eqs.append((a_xy, b_xy, r_xy, eq["op"]))

    var_set = set(variables)
    var_to_eqs = defaultdict(list)
    for i, (a, b, r, _) in enumerate(eqs):
        for xy in (a, b, r):
            if xy in var_set:
                var_to_eqs[xy].append(i)

    fixed_vals = {xy: grid.cells[xy]["val"] for xy in clue_coords}
    solutions = [0]

    def get_missing_var(eq_idx, assignment):
        """Devuelve (var_xy, deduced_value_str) o None.
        Si la ecuación tiene exactamente 1 variable sin asignar y los otros
        2 valores son conocidos, devuelve el valor determinado para esa var.
        Si está completa, devuelve "CHECK" para verificar consistencia.
        Si tiene 2+ variables, devuelve None.
        """
        a_xy, b_xy, r_xy, op = eqs[eq_idx]
        vals = []
        missing = None
        miss_role = None
        for xy, role in ((a_xy, 'a'), (b_xy, 'b'), (r_xy, 'r')):
            if xy in assignment:
                vals.append((role, assignment[xy]))
            elif xy in fixed_vals:
                vals.append((role, fixed_vals[xy]))
            else:
                if missing is not None:
                    return None  # más de una variable libre
                missing = xy
                miss_role = role

        # 0 variables libres: verificar consistencia
        if missing is None:
            d = {role: int(v) for role, v in vals}
            a_v, b_v, r_v = d['a'], d['b'], d['r']
            if op == "+":
                return ("CHECK", a_v + b_v == r_v)
            if op == "-":
                return ("CHECK", a_v - b_v == r_v)
            if op == "*":
                return ("CHECK", a_v * b_v == r_v)
            if op == "/":
                return ("CHECK", b_v != 0 and a_v == b_v * r_v)
            return ("CHECK", False)

        # 1 variable libre: despejar
        d = {role: int(v) for role, v in vals}
        if miss_role == 'a':
            b_v, r_v = d.get('b'), d.get('r')
            if op == "+":
                result = r_v - b_v
            elif op == "-":
                result = r_v + b_v
            elif op == "*":
                if b_v == 0 or r_v % b_v != 0:
                    return (missing, None)
                result = r_v // b_v
            elif op == "/":
                result = b_v * r_v
            else:
                return (missing, None)
        elif miss_role == 'b':
            a_v, r_v = d.get('a'), d.get('r')
            if op == "+":
                result = r_v - a_v
            elif op == "-":
                result = a_v - r_v
            elif op == "*":
                if r_v == 0:
                    if a_v == 0:
                        return (missing, None)  # 0*? = 0, indeterminado
                    return (missing, None)
                if a_v == 0 or r_v % a_v != 0:
                    return (missing, None)
                result = r_v // a_v
            elif op == "/":
                if r_v == 0:
                    return (missing, None)
                if a_v % r_v != 0:
                    return (missing, None)
                result = a_v // r_v
            else:
                return (missing, None)
        else:  # 'r'
            a_v, b_v = d.get('a'), d.get('b')
            if op == "+":
                result = a_v + b_v
            elif op == "-":
                result = a_v - b_v
            elif op == "*":
                result = a_v * b_v
            elif op == "/":
                if b_v == 0 or a_v % b_v != 0:
                    return (missing, None)
                result = a_v // b_v
            else:
                return (missing, None)

        if result < 0:
            return (missing, None)
        return (missing, str(result))

    def backtrack(assignment, pool_state):
        if solutions[0] >= limit:
            return

        # 1) Buscar deducciones forzadas (ecuaciones con 1 sola variable libre).
        #    Aplicar todas las que se puedan en cadena.
        forced = []  # lista de (var, value) aplicadas, para revertir
        while True:
            progress = False
            for ei in range(len(eqs)):
                res = get_missing_var(ei, assignment)
                if res is None:
                    continue
                target, value = res
                if target == "CHECK":
                    if not value:
                        # ecuación inconsistente
                        for var, val in reversed(forced):
                            del assignment[var]
                            pool_state[val] += 1
                        return
                    continue
                # target es un var_xy
                if value is None:
                    # imposible asignar (división no entera, etc.)
                    for var, val in reversed(forced):
                        del assignment[var]
                        pool_state[val] += 1
                    return
                # Verificar que el valor esté disponible en el pool
                if pool_state.get(value, 0) <= 0:
                    for var, val in reversed(forced):
                        del assignment[var]
                        pool_state[val] += 1
                    return
                assignment[target] = value
                pool_state[value] -= 1
                forced.append((target, value))
                progress = True
            if not progress:
                break

        # 2) ¿Quedan variables libres?
        remaining = [v for v in variables if v not in assignment]
        if not remaining:
            # Verificar todas las ecuaciones
            all_ok = True
            for ei in range(len(eqs)):
                res = get_missing_var(ei, assignment)
                if res and res[0] == "CHECK" and not res[1]:
                    all_ok = False
                    break
            if all_ok:
                solutions[0] += 1
            for var, val in reversed(forced):
                del assignment[var]
                pool_state[val] += 1
            return

        # 3) Elegir variable con menos opciones disponibles (MRV).
        #    Para cada variable, el dominio efectivo es las claves del pool
        #    con stock > 0. Pero algunas variables están en ecuaciones con
        #    valores ya asignados — el dominio se reduce a valores
        #    consistentes con esas ecuaciones.
        var = remaining[0]
        best_score = -1
        for v in remaining:
            score = len(var_to_eqs[v])
            if score > best_score:
                best_score = score
                var = v

        # 4) Probar cada valor del pool
        tried = set()
        for value in list(pool_state.keys()):
            if pool_state[value] <= 0 or value in tried:
                continue
            tried.add(value)
            assignment[var] = value
            pool_state[value] -= 1
            # Verificación rápida: ecuaciones que ahora se completan deben
            # ser consistentes
            ok = True
            for ei in var_to_eqs[var]:
                res = get_missing_var(ei, assignment)
                if res and res[0] == "CHECK" and not res[1]:
                    ok = False
                    break
            if ok:
                backtrack(assignment, pool_state)
            del assignment[var]
            pool_state[value] += 1
            if solutions[0] >= limit:
                break

        # Revertir las deducciones forzadas
        for var, val in reversed(forced):
            del assignment[var]
            pool_state[val] += 1

    backtrack({}, dict(pool_init))
    return solutions[0]


# ---------------------------------------------------------------------------
# Selección de pistas
# ---------------------------------------------------------------------------

def choose_clues(grid, equations, mode, rng):
    """Elige el conjunto mínimo de pistas tal que:
        - la solución es única (CSP),
        - máx 1 pista por ecuación,
        - ninguna ecuación arranca con sus 3 números visibles (garantizado
          por la regla anterior, pero verificado igual),
        - respeta los ratios min/max por modo.
    """
    conf = CONFIG[mode]
    num_cells = [xy for xy, c in grid.cells.items() if c["kind"] == "num"]
    total = len(num_cells)
    if total == 0:
        return None

    min_clues = max(2, int(total * conf["min_clues_ratio"]))
    max_clues = max(min_clues + 1, int(total * conf["max_clues_ratio"]))

    cell_to_eqs = defaultdict(list)
    for ei, eq in enumerate(equations):
        for xy in eq["coords"]:
            if grid.cells[xy]["kind"] == "num":
                cell_to_eqs[xy].append(ei)

    eq_clue_count = Counter()

    def can_fix(xy):
        return all(eq_clue_count[ei] < 1 for ei in cell_to_eqs[xy])

    def fix(xy, clues):
        clues.add(xy)
        for ei in cell_to_eqs[xy]:
            eq_clue_count[ei] += 1

    def unfix(xy, clues):
        clues.discard(xy)
        for ei in cell_to_eqs[xy]:
            eq_clue_count[ei] -= 1

    # Orden: por grado (más intersecciones primero) con desempate aleatorio
    by_degree = sorted(
        num_cells,
        key=lambda xy: (-len(grid.cells[xy]["orients"]), rng.random())
    )

    clues = set()

    # Sembrar con min_clues pistas antes de verificar unicidad.
    # No tiene sentido pedir unicidad con muy pocas pistas; añadirlas todas
    # de golpe ahorra muchas llamadas al CSP.
    for xy in by_degree:
        if len(clues) >= min_clues:
            break
        if not can_fix(xy):
            continue
        fix(xy, clues)

    n_sols = solve_unique(grid, equations, clues, limit=2)
    if n_sols == 0:
        return None

    # Fase 1: si aún no es único, añadir más pistas (de a una, verificando)
    for xy in by_degree:
        if n_sols == 1:
            break
        if len(clues) >= max_clues:
            break
        if xy in clues or not can_fix(xy):
            continue
        fix(xy, clues)
        n_sols = solve_unique(grid, equations, clues, limit=2)

    if n_sols != 1 or len(clues) > max_clues:
        return None

    # Fase 2: minimalidad — quitar pistas innecesarias preservando unicidad.
    # Sólo intentamos quitar las añadidas en fase 1 (las del sembrado son
    # estructurales y rara vez sobran).
    removable = list(clues)
    rng.shuffle(removable)
    removed_count = 0
    max_removals = len(clues) - min_clues
    for xy in removable:
        if removed_count >= max_removals:
            break
        unfix(xy, clues)
        if solve_unique(grid, equations, clues, limit=2) == 1:
            removed_count += 1
        else:
            fix(xy, clues)

    # Verificación extra: ninguna ecuación arranca completa
    for ei, eq in enumerate(equations):
        num_coords = [eq["coords"][i] for i in (0, 2, 4)]
        if all(xy in clues for xy in num_coords):
            return None

    return clues


# ---------------------------------------------------------------------------
# Validación estructural
# ---------------------------------------------------------------------------

def validate_structure(grid, equations, mode):
    conf = CONFIG[mode]
    size = grid.size

    if len(equations) < conf["eq_range"][0]:
        return False, "pocas ecuaciones"

    # Intersecciones ≥ 20% de las ecuaciones
    intersections = sum(1 for c in grid.cells.values() if len(c["orients"]) > 1)
    if intersections < max(1, int(len(equations) * 0.20)):
        return False, "pocas intersecciones"

    if not grid.is_connected():
        return False, "desconectado"

    # Densidad mínima por modo
    density = len(grid.cells) / (size * size)
    if density < conf["min_density"]:
        return False, f"densidad baja {density:.2f}"

    nums = [c["val"] for c in grid.cells.values() if c["kind"] == "num"]
    cnt = Counter(nums)
    total = len(nums)
    if total == 0:
        return False, "sin números"
    if len(cnt) < conf["min_distinct"]:
        return False, "poca diversidad"
    limit = max(2, int(total * 0.15))
    if max(cnt.values()) > limit:
        return False, "repetición excesiva"

    return True, None


# ---------------------------------------------------------------------------
# Serialización
# ---------------------------------------------------------------------------

def level_to_dict(level_id, grid, equations, clues, rng):
    cells = []
    for (x, y), data in grid.cells.items():
        if data["kind"] == "num":
            t = 1
            is_fixed = (x, y) in clues
        elif data["kind"] == "op":
            t, is_fixed = 2, True
        else:
            t, is_fixed = 3, True
        cells.append({
            "x": x, "y": y, "type": t, "value": data["val"],
            "isFixed": is_fixed,
            "isHorizontal": "H" in data["orients"],
        })

    footer = [
        data["val"]
        for (x, y), data in grid.cells.items()
        if data["kind"] == "num" and (x, y) not in clues
    ]
    rng.shuffle(footer)

    return {
        "id": level_id,
        "size": grid.size,
        "footerTiles": footer,
        "cells": cells,
    }


# ---------------------------------------------------------------------------
# Loop principal
# ---------------------------------------------------------------------------

def generate_levels(mode, out_dir, rng, verbose=True):
    conf = CONFIG[mode]
    total = conf["levels"]
    levels = []
    attempts = 0
    fails = Counter()

    while len(levels) < total:
        attempts += 1
        if verbose and attempts % 200 == 0:
            print(f"  [{mode}] intentos={attempts} ok={len(levels)} "
                  f"fails={dict(fails)}", flush=True)

        res = build_board(mode, rng)
        if res is None:
            fails["build"] += 1
            continue
        grid, equations = res

        ok, reason = validate_structure(grid, equations, mode)
        if not ok:
            fails[f"struct:{reason}"] += 1
            continue

        clues = choose_clues(grid, equations, mode, rng)
        if clues is None:
            fails["clues"] += 1
            continue

        level = level_to_dict(len(levels) + 1, grid, equations, clues, rng)

        # Validación externa independiente (defensa en profundidad)
        ok, reason = validate_level(level)
        if not ok:
            fails[f"validate:{reason}"] += 1
            continue

        levels.append(level)
        if verbose:
            num_clues = sum(1 for c in level["cells"]
                            if c["type"] == 1 and c["isFixed"])
            num_total = sum(1 for c in level["cells"] if c["type"] == 1)
            print(f"  [{mode}] nivel {len(levels)}/{total} listo "
                  f"(size={grid.size}, eqs={len(equations)}, "
                  f"clues={num_clues}/{num_total})", flush=True)

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"levels_{mode}.json")
    with open(path, "w") as f:
        json.dump(levels, f, ensure_ascii=False, indent=2)
    return path, len(levels), fails


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.path.join(BASE_DIR, "assets", "levels"))
    parser.add_argument("--mode", default="all",
                        choices=["all", "easy", "medium", "hard"])
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--levels", type=int, default=None,
                        help="override del nº de niveles por modo")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    modes = ["easy", "medium", "hard"] if args.mode == "all" else [args.mode]

    for m in modes:
        if args.levels is not None:
            CONFIG[m]["levels"] = args.levels
        out_dir = os.path.join(args.out, m)
        print(f"Generando {m}...")
        path, n, fails = generate_levels(m, out_dir, rng)
        print(f"  -> {path} ({n} niveles, fails={dict(fails)})")
    print("DONE")
