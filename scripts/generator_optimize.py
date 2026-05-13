"""
Generador modo 'optimize' (solo medium).

Mismo motor estructural que generator.py, pero el objetivo del juego cambia:
- Se aceptan tableros con MÚLTIPLES soluciones válidas (5–20 configuraciones).
- El jugador debe encontrar la configuración que MAXIMIZA la suma de los
  resultados R de todas las ecuaciones.
- Se computa el óptimo, el peor caso y los umbrales para 1/2/3 estrellas.

JSON resultante (formato distinto al deductivo, para que el front lo detecte):
{
  "id": int,
  "mode": "optimize",
  "objective": "max_sum_r",
  "size": int,
  "footerTiles": [str, ...],
  "cells": [...],
  "scoring": {
    "min_score": int,    # peor configuración válida
    "max_score": int,    # óptimo: meta del jugador
    "thresholds": {
      "three_stars": int,  # >= 90% del rango (min..max)
      "two_stars": int,    # >= 70%
      "one_star":  int     # >= 50%
    },
    "solutions_count": int  # nº de configs válidas (5..20)
  }
}
"""

import json
import os
import random
from collections import Counter, defaultdict

from generator_claude import (
    Grid, CONFIG as DEDUCTIVE_CONFIG, OPS,
    _place_first, try_place_connected,
    validate_structure as _validate_structure_deductive,
    equation_tokens,
)
from validate import (
    find_runs, check_structure as _vcheck_structure,
    check_connected as _vcheck_connected,
)

# ---------------------------------------------------------------------------
# Config (solo medium, derivada de la del deductivo)
# ---------------------------------------------------------------------------

CONFIG = {
    "medium": {
        # Estructura: igual al deductivo medium
        "size_range":  DEDUCTIVE_CONFIG["medium"]["size_range"],
        "eq_range":    DEDUCTIVE_CONFIG["medium"]["eq_range"],
        "weights":     DEDUCTIVE_CONFIG["medium"]["weights"],
        "num_range":   DEDUCTIVE_CONFIG["medium"]["num_range"],
        "min_r":       DEDUCTIVE_CONFIG["medium"]["min_r"],
        "min_density": DEDUCTIVE_CONFIG["medium"]["min_density"],
        "min_distinct":DEDUCTIVE_CONFIG["medium"]["min_distinct"],

        # Específicas de optimize
        "levels": 50,
        "solutions_range": (5, 20),
        # Pistas: queremos POCAS, para que haya varias configs válidas
        "min_clues_ratio": 0.10,
        "max_clues_ratio": 0.30,
        # Cap para no explorar más allá: si hay >21 soluciones, abortamos
        "solutions_cap": 21,
    }
}

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------------------
# Enumerador de soluciones (versión "todas" hasta un cap)
# ---------------------------------------------------------------------------

def enumerate_solutions(grid, equations, clue_coords, cap=21):
    """Enumera hasta `cap` configuraciones válidas. Cada configuración es
    un dict {var_xy: value_str}.

    Misma propagación que solve_unique pero **recolectando** asignaciones
    completas en vez de contarlas.
    """
    num_cells = [xy for xy, c in grid.cells.items() if c["kind"] == "num"]
    variables = [xy for xy in num_cells if xy not in clue_coords]
    pool_init = Counter(grid.cells[xy]["val"] for xy in variables)

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
    solutions = []

    def get_missing_var(eq_idx, assignment):
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
                    return None
                missing = xy
                miss_role = role

        if missing is None:
            d = {role: int(v) for role, v in vals}
            a_v, b_v, r_v = d['a'], d['b'], d['r']
            if op == "+": return ("CHECK", a_v + b_v == r_v)
            if op == "-": return ("CHECK", a_v - b_v == r_v)
            if op == "*": return ("CHECK", a_v * b_v == r_v)
            if op == "/": return ("CHECK", b_v != 0 and a_v == b_v * r_v)
            return ("CHECK", False)

        d = {role: int(v) for role, v in vals}
        if miss_role == 'a':
            b_v, r_v = d['b'], d['r']
            if op == "+": result = r_v - b_v
            elif op == "-": result = r_v + b_v
            elif op == "*":
                if b_v == 0 or r_v % b_v != 0: return (missing, None)
                result = r_v // b_v
            elif op == "/": result = b_v * r_v
            else: return (missing, None)
        elif miss_role == 'b':
            a_v, r_v = d['a'], d['r']
            if op == "+": result = r_v - a_v
            elif op == "-": result = a_v - r_v
            elif op == "*":
                if a_v == 0 or r_v % a_v != 0: return (missing, None)
                result = r_v // a_v
            elif op == "/":
                if r_v == 0 or a_v % r_v != 0: return (missing, None)
                result = a_v // r_v
            else: return (missing, None)
        else:  # 'r'
            a_v, b_v = d['a'], d['b']
            if op == "+": result = a_v + b_v
            elif op == "-": result = a_v - b_v
            elif op == "*": result = a_v * b_v
            elif op == "/":
                if b_v == 0 or a_v % b_v != 0: return (missing, None)
                result = a_v // b_v
            else: return (missing, None)

        if result < 0:
            return (missing, None)
        return (missing, str(result))

    def backtrack(assignment, pool_state):
        if len(solutions) >= cap:
            return

        forced = []
        while True:
            progress = False
            for ei in range(len(eqs)):
                res = get_missing_var(ei, assignment)
                if res is None:
                    continue
                target, value = res
                if target == "CHECK":
                    if not value:
                        for var, val in reversed(forced):
                            del assignment[var]
                            pool_state[val] += 1
                        return
                    continue
                if value is None or pool_state.get(value, 0) <= 0:
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

        remaining = [v for v in variables if v not in assignment]
        if not remaining:
            all_ok = True
            for ei in range(len(eqs)):
                res = get_missing_var(ei, assignment)
                if res and res[0] == "CHECK" and not res[1]:
                    all_ok = False
                    break
            if all_ok:
                solutions.append(dict(assignment))
            for var, val in reversed(forced):
                del assignment[var]
                pool_state[val] += 1
            return

        # MRV-like
        var = remaining[0]
        best = -1
        for v in remaining:
            s = len(var_to_eqs[v])
            if s > best:
                best = s
                var = v

        tried = set()
        for value in list(pool_state.keys()):
            if pool_state[value] <= 0 or value in tried:
                continue
            tried.add(value)
            assignment[var] = value
            pool_state[value] -= 1
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
            if len(solutions) >= cap:
                break

        for var, val in reversed(forced):
            del assignment[var]
            pool_state[val] += 1

    backtrack({}, dict(pool_init))
    return solutions


# ---------------------------------------------------------------------------
# Construcción de tableros: reutilizamos build_board del deductivo
# ---------------------------------------------------------------------------

def build_board(mode, rng, max_total_steps=100):
    """Misma lógica que generator.build_board pero usando la CONFIG de optimize."""
    conf = CONFIG[mode]
    smin, smax = conf["size_range"]
    emin, emax = conf["eq_range"]
    min_density = conf["min_density"]

    # Pick size & target (idéntico a generator._pick_size_and_target)
    candidates = []
    for s in range(smin, smax + 1):
        cells_needed = min_density * s * s
        e_for_density = max(emin, int((cells_needed - 1) / 4 + 0.999))
        e_max_phys = (s * s) // 3
        e_lo = max(emin, e_for_density)
        e_hi = min(emax, e_max_phys)
        if e_lo <= e_hi:
            candidates.append((s, e_lo, e_hi))
    if not candidates:
        size, eq_target = smin, emin
    else:
        s, e_lo, e_hi = rng.choice(candidates)
        size, eq_target = s, rng.randint(e_lo, e_hi)

    eq_min = conf["eq_range"][0]
    target_cells = int(min_density * size * size)

    grid = Grid(size)
    equations = []
    undos = []

    # Para la primera ecuación usamos el modo "medium" del deductivo
    first = _place_first(grid, "medium", rng)
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
        eqs_remaining = eq_target - len(equations)
        max_cells_possible = len(grid.cells) + eqs_remaining * 4
        if max_cells_possible < target_cells:
            return None

        eq_dict, eq_undo = try_place_connected(grid, "medium", rng)

        if eq_dict is not None:
            equations.append(eq_dict)
            undos.append(eq_undo)
            fail_streak = 0
        else:
            fail_streak += 1
            if fail_streak >= max_fail_streak and len(equations) > 1:
                grid.unplace(undos.pop())
                equations.pop()
                fail_streak = 0

    if len(grid.cells) < target_cells:
        return None
    if len(equations) < eq_min:
        return None
    return grid, equations


# ---------------------------------------------------------------------------
# Validación estructural local (para no depender del nombre)
# ---------------------------------------------------------------------------

def validate_structure(grid, equations, mode):
    conf = CONFIG[mode]
    size = grid.size

    if len(equations) < conf["eq_range"][0]:
        return False, "pocas ecuaciones"

    intersections = sum(1 for c in grid.cells.values() if len(c["orients"]) > 1)
    if intersections < max(1, int(len(equations) * 0.20)):
        return False, "pocas intersecciones"

    if not grid.is_connected():
        return False, "desconectado"

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
# Selección de pistas para optimize
# ---------------------------------------------------------------------------

def choose_clues_for_optimize(grid, equations, mode, rng):
    """Estrategia distinta al deductivo:
    - Empezamos sin pistas y contamos soluciones.
    - Si hay demasiadas (>20), añadimos pistas hasta caer en [5..20].
    - Si hay pocas (<5), descartamos: el tablero es demasiado restrictivo.
    - Respetamos máx 1 pista por ecuación.
    - No permitimos ecuaciones completamente reveladas.
    """
    conf = CONFIG[mode]
    cap = conf["solutions_cap"]
    target_lo, target_hi = conf["solutions_range"]

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

    by_degree = sorted(
        num_cells,
        key=lambda xy: (-len(grid.cells[xy]["orients"]), rng.random())
    )

    clues = set()

    # Sembrado inicial (min_clues)
    for xy in by_degree:
        if len(clues) >= min_clues:
            break
        if not can_fix(xy):
            continue
        fix(xy, clues)

    sols = enumerate_solutions(grid, equations, clues, cap=cap)

    # Si tenemos < target_lo, ya estamos demasiado restringidos
    if len(sols) < target_lo:
        return None, None

    # Si tenemos > target_hi, seguir añadiendo pistas
    for xy in by_degree:
        if len(sols) <= target_hi:
            break
        if len(clues) >= max_clues:
            break
        if xy in clues or not can_fix(xy):
            continue
        fix(xy, clues)
        sols = enumerate_solutions(grid, equations, clues, cap=cap)
        if len(sols) < target_lo:
            return None, None  # nos pasamos restringiendo

    if not (target_lo <= len(sols) <= target_hi):
        return None, None

    # Verificación: ninguna ecuación arranca completa
    for eq in equations:
        num_coords = [eq["coords"][i] for i in (0, 2, 4)]
        if all(xy in clues for xy in num_coords):
            return None, None

    return clues, sols


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score_solution(grid, equations, solution, clue_coords):
    """Calcula el puntaje (suma de R) de una configuración.

    Para cada ecuación, el R se obtiene del valor en la celda R:
    - si está asignado en `solution`, ese valor;
    - si es una pista (clue_coord), el valor original de la grilla.
    """
    fixed_vals = {xy: grid.cells[xy]["val"] for xy in clue_coords}

    total = 0
    for eq in equations:
        r_xy = eq["coords"][4]
        if r_xy in solution:
            v = solution[r_xy]
        elif r_xy in fixed_vals:
            v = fixed_vals[r_xy]
        else:
            v = grid.cells[r_xy]["val"]
        total += int(v)
    return total


def compute_scoring(grid, equations, solutions, clue_coords):
    """Devuelve dict con min, max y umbrales 1/2/3 estrellas."""
    scores = [score_solution(grid, equations, s, clue_coords) for s in solutions]
    s_min = min(scores)
    s_max = max(scores)
    rng_size = s_max - s_min

    three = s_min + int(rng_size * 0.90)
    two   = s_min + int(rng_size * 0.70)
    one   = s_min + int(rng_size * 0.50)
    # Evitar que three < max cuando rng=0
    if rng_size == 0:
        three = two = one = s_max

    return {
        "min_score": s_min,
        "max_score": s_max,
        "thresholds": {
            "three_stars": three,
            "two_stars": two,
            "one_star": one,
        },
        "solutions_count": len(solutions),
    }


# ---------------------------------------------------------------------------
# Serialización JSON (formato 'optimize')
# ---------------------------------------------------------------------------

def level_to_dict(level_id, grid, equations, clues, scoring, rng):
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
        "mode": "optimize",
        "objective": "max_sum_r",
        "size": grid.size,
        "footerTiles": footer,
        "cells": cells,
        "scoring": scoring,
    }


# ---------------------------------------------------------------------------
# Validación post-generación específica del modo optimize
# ---------------------------------------------------------------------------

def validate_optimize_level(level):
    """Validador independiente para el formato 'optimize'.

    Verifica:
    - reglas estructurales (sin paralelas, runs de 5, ecuaciones válidas)
    - conectividad
    - el conteo de soluciones declarado coincide con el real
    - el óptimo declarado es realmente el máximo entre todas las soluciones
    - todas las soluciones son válidas para el footer
    """
    cells_by_xy = {(c["x"], c["y"]): c for c in level["cells"]}
    size = level["size"]

    ok, reason = _vcheck_connected(cells_by_xy)
    if not ok:
        return False, reason

    h_runs, v_runs = find_runs(cells_by_xy, size)
    if not h_runs and not v_runs:
        return False, "sin ecuaciones detectables"
    ok, reason = _vcheck_structure(level, cells_by_xy, h_runs, v_runs)
    if not ok:
        return False, reason

    # Reconstruir ecuaciones desde los runs y verificar el conteo de soluciones
    variables = [
        xy for xy, c in cells_by_xy.items()
        if c["type"] == 1 and not c["isFixed"]
    ]
    footer = list(level["footerTiles"])
    if sorted(footer) != sorted(cells_by_xy[xy]["value"] for xy in variables):
        return False, "footer no coincide con variables"

    # Construir grilla mínima y reusar enumerate_solutions
    class _MiniGrid:
        def __init__(self, size, cells_by_xy):
            self.size = size
            self.cells = {}
            for xy, c in cells_by_xy.items():
                kind = ("num" if c["type"] == 1 else
                        "op" if c["type"] == 2 else "eq")
                self.cells[xy] = {
                    "val": c["value"], "kind": kind,
                    "orients": set(),  # no se usa para enumerate
                }

    mini = _MiniGrid(size, cells_by_xy)
    fake_equations = []
    for run in h_runs + v_runs:
        if len(run) == 5:
            a_xy, op_xy, b_xy, _, r_xy = run
            fake_equations.append({
                "coords": run,
                "op": cells_by_xy[op_xy]["value"],
            })

    clues = {xy for xy, c in cells_by_xy.items()
             if c["type"] == 1 and c["isFixed"]}
    declared_count = level["scoring"]["solutions_count"]
    declared_max = level["scoring"]["max_score"]
    declared_min = level["scoring"]["min_score"]

    sols = enumerate_solutions(mini, fake_equations, clues,
                                cap=declared_count + 2)
    if len(sols) != declared_count:
        return False, f"solutions_count={declared_count} pero hay {len(sols)}"

    scores = [score_solution(mini, fake_equations, s, clues) for s in sols]
    if max(scores) != declared_max:
        return False, (f"max_score={declared_max} pero el real es "
                       f"{max(scores)}")
    if min(scores) != declared_min:
        return False, f"min_score={declared_min} pero el real es {min(scores)}"

    return True, None


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
            print(f"  [{mode}-optimize] intentos={attempts} "
                  f"ok={len(levels)} fails={dict(fails)}", flush=True)

        res = build_board(mode, rng)
        if res is None:
            fails["build"] += 1
            continue
        grid, equations = res

        ok, reason = validate_structure(grid, equations, mode)
        if not ok:
            fails[f"struct:{reason}"] += 1
            continue

        clues, sols = choose_clues_for_optimize(grid, equations, mode, rng)
        if clues is None:
            fails["clues"] += 1
            continue

        scoring = compute_scoring(grid, equations, sols, clues)

        # Descartar si min == max (tablero trivial: todas las configs dan
        # el mismo puntaje, así que no hay optimización real)
        if scoring["min_score"] == scoring["max_score"]:
            fails["no_optimization"] += 1
            continue

        level = level_to_dict(len(levels) + 1, grid, equations,
                              clues, scoring, rng)

        # Validador independiente
        ok, reason = validate_optimize_level(level)
        if not ok:
            fails[f"validate:{reason}"] += 1
            continue

        levels.append(level)
        if verbose:
            num_clues = sum(1 for c in level["cells"]
                            if c["type"] == 1 and c["isFixed"])
            num_total = sum(1 for c in level["cells"] if c["type"] == 1)
            print(f"  [{mode}-optimize] nivel {len(levels)}/{total} "
                  f"(size={grid.size}, eqs={len(equations)}, "
                  f"clues={num_clues}/{num_total}, "
                  f"sols={scoring['solutions_count']}, "
                  f"score={scoring['min_score']}..{scoring['max_score']})",
                  flush=True)

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"levels_{mode}_optimize.json")
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
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--levels", type=int, default=None)
    args = parser.parse_args()

    rng = random.Random(args.seed)

    if args.levels is not None:
        CONFIG["medium"]["levels"] = args.levels

    out_dir = os.path.join(args.out, "optimize")
    print("Generando medium-optimize...")
    path, n, fails = generate_levels("medium", out_dir, rng)
    print(f"  -> {path} ({n} niveles, fails={dict(fails)})")
    print("DONE")
