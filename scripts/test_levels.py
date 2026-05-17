"""
Tester de todos los niveles en assets/levels/.

Recorre dinámicamente todas las subcarpetas de assets/levels, carga cada
archivo JSON y valida cada nivel. El comportamiento varía por carpeta:
  - easy/medium/hard: usa validate_level (solución única requerida)
  - optimize:         verifica estructura + enumera todas las soluciones
                      y reporta la suma máxima de resultados (max_sum_r)

Uso:
    python test_levels.py              # ruta automática relativa al script
    python test_levels.py ruta/custom  # ruta custom a la carpeta levels
    python test_levels.py -v           # verbose (muestra niveles OK también)
    python test_levels.py -f           # fail-fast (para al primer error)

Salida: resumen por archivo + resumen global. Exit code 1 si hay errores.
"""
import json
import os
import sys
import time
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(__file__))
from validate import validate_level, check_connected, find_runs, check_structure

MAX_OPTIMIZE_SOLUTIONS = 10_000


# ---------------------------------------------------------------------------
# Validación modo optimize
# ---------------------------------------------------------------------------

def _enum_optimize(level, cells_by_xy, h_runs, v_runs):
    """Enumera todas las soluciones válidas de un nivel optimize.

    Devuelve (num_solutions, max_sum_r, capped) donde capped indica que se
    llegó al límite MAX_OPTIMIZE_SOLUTIONS sin agotar el espacio de búsqueda.
    max_sum_r es la suma máxima de los valores en las celdas resultado (r)
    de todas las ecuaciones, para cualquier solución válida.
    """
    variables = [
        xy for xy, c in cells_by_xy.items()
        if c["type"] == 1 and not c["isFixed"]
    ]
    pool = Counter(level["footerTiles"])

    if sum(pool.values()) != len(variables):
        return 0, None, False

    eqs = []
    r_positions = []
    for run in h_runs + v_runs:
        if len(run) == 5:
            a_xy, op_xy, b_xy, _, r_xy = run
            eqs.append((a_xy, b_xy, r_xy, cells_by_xy[op_xy]["value"]))
            r_positions.append(r_xy)

    var_set = set(variables)
    var_to_eqs = defaultdict(list)
    for i, (a, b, r, _) in enumerate(eqs):
        for xy in (a, b, r):
            if xy in var_set:
                var_to_eqs[xy].append(i)

    fixed_vals = {
        xy: c["value"] for xy, c in cells_by_xy.items()
        if c["type"] == 1 and c["isFixed"]
    }

    def get_val(xy, assignment):
        if xy in assignment:
            return assignment[xy]
        return fixed_vals.get(xy)

    def get_missing_var(eq_idx, assignment):
        a_xy, b_xy, r_xy, op = eqs[eq_idx]
        known = {}
        missing = None
        miss_role = None
        for xy, role in ((a_xy, "a"), (b_xy, "b"), (r_xy, "r")):
            v = get_val(xy, assignment)
            if v is not None:
                known[role] = int(v)
            else:
                if missing is not None:
                    return None  # más de una variable libre
                missing = xy
                miss_role = role

        if missing is None:
            a_v, b_v, r_v = known["a"], known["b"], known["r"]
            if op == "+": return ("CHECK", a_v + b_v == r_v)
            if op == "-": return ("CHECK", a_v - b_v == r_v)
            if op == "*": return ("CHECK", a_v * b_v == r_v)
            if op == "/": return ("CHECK", b_v != 0 and a_v == b_v * r_v)
            return ("CHECK", False)

        if miss_role == "a":
            b_v, r_v = known["b"], known["r"]
            if op == "+":   result = r_v - b_v
            elif op == "-": result = r_v + b_v
            elif op == "*":
                if b_v == 0 or r_v % b_v != 0: return (missing, None)
                result = r_v // b_v
            elif op == "/": result = b_v * r_v
            else: return (missing, None)
        elif miss_role == "b":
            a_v, r_v = known["a"], known["r"]
            if op == "+":   result = r_v - a_v
            elif op == "-": result = a_v - r_v
            elif op == "*":
                if a_v == 0 or r_v % a_v != 0: return (missing, None)
                result = r_v // a_v
            elif op == "/":
                if r_v == 0 or a_v % r_v != 0: return (missing, None)
                result = a_v // r_v
            else: return (missing, None)
        else:  # "r"
            a_v, b_v = known["a"], known["b"]
            if op == "+":   result = a_v + b_v
            elif op == "-": result = a_v - b_v
            elif op == "*": result = a_v * b_v
            elif op == "/":
                if b_v == 0 or a_v % b_v != 0: return (missing, None)
                result = a_v // b_v
            else: return (missing, None)

        if result < 0:
            return (missing, None)
        return (missing, str(result))

    state = {"count": 0, "max_sum": None, "capped": False}

    def compute_sum_r(assignment):
        return sum(
            int(v) for r_xy in r_positions
            if (v := get_val(r_xy, assignment)) is not None
        )

    def backtrack(assignment, pool_state):
        if state["count"] >= MAX_OPTIMIZE_SOLUTIONS:
            state["capped"] = True
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
                state["count"] += 1
                s = compute_sum_r(assignment)
                if state["max_sum"] is None or s > state["max_sum"]:
                    state["max_sum"] = s
            for var, val in reversed(forced):
                del assignment[var]
                pool_state[val] += 1
            return

        var = max(remaining, key=lambda v: len(var_to_eqs[v]))
        tried = set()
        for value in list(pool_state.keys()):
            if state["count"] >= MAX_OPTIMIZE_SOLUTIONS:
                break
            if pool_state[value] <= 0 or value in tried:
                continue
            tried.add(value)
            assignment[var] = value
            pool_state[value] -= 1
            ok_constraints = True
            for ei in var_to_eqs[var]:
                res = get_missing_var(ei, assignment)
                if res and res[0] == "CHECK" and not res[1]:
                    ok_constraints = False
                    break
            if ok_constraints:
                backtrack(assignment, pool_state)
            del assignment[var]
            pool_state[value] += 1

        for var, val in reversed(forced):
            del assignment[var]
            pool_state[val] += 1

    backtrack({}, dict(pool))
    return state["count"], state["max_sum"], state["capped"]


def validate_optimize_level(level):
    """Valida un nivel optimize. Devuelve (ok, reason, num_solutions, max_sum_r)."""
    cells_by_xy = {(c["x"], c["y"]): c for c in level["cells"]}
    size = level["size"]

    ok, reason = check_connected(cells_by_xy)
    if not ok:
        return False, reason, None, None

    h_runs, v_runs = find_runs(cells_by_xy, size)
    if not h_runs and not v_runs:
        return False, "sin ecuaciones detectables", None, None

    ok, reason = check_structure(level, cells_by_xy, h_runs, v_runs)
    if not ok:
        return False, reason, None, None

    num_solutions, max_sum, capped = _enum_optimize(
        level, cells_by_xy, h_runs, v_runs
    )

    if num_solutions == 0:
        return False, "sin solución", 0, None

    return True, None, num_solutions, max_sum, capped


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def find_level_files(levels_root):
    files = []
    for entry in sorted(os.scandir(levels_root), key=lambda e: e.name):
        if not entry.is_dir():
            continue
        for f in sorted(os.scandir(entry.path), key=lambda e: e.name):
            if f.name.endswith(".json"):
                files.append((entry.name, f.path))
    return files


def validate_file(folder, path, verbose=False, fail_fast=False):
    """Valida todos los niveles de un JSON. Devuelve (ok_count, total, failures)."""
    with open(path, encoding="utf-8") as f:
        levels = json.load(f)

    is_optimize = folder == "optimize"
    ok_count = 0
    failures = []

    for lvl in levels:
        lvl_id = lvl.get("id", "?")

        if is_optimize:
            result = validate_optimize_level(lvl)
            ok = result[0]
            reason = result[1]
            if ok:
                num_sols, max_sum, capped = result[2], result[3], result[4]
                ok_count += 1
                cap_mark = "+" if capped else ""
                if verbose:
                    print(
                        f"    [{folder}] id={lvl_id} OK  "
                        f"soluciones={num_sols}{cap_mark}  max_sum_r={max_sum}"
                    )
            else:
                failures.append((lvl_id, reason))
                print(f"    [{folder}] id={lvl_id} FALLO: {reason}")
        else:
            ok, reason = validate_level(lvl)
            if ok:
                ok_count += 1
                if verbose:
                    print(f"    [{folder}] id={lvl_id} OK")
            else:
                failures.append((lvl_id, reason))
                print(f"    [{folder}] id={lvl_id} FALLO: {reason}")

        if not ok and fail_fast:
            return ok_count, len(levels), failures

    return ok_count, len(levels), failures


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    verbose = "-v" in args
    fail_fast = "-f" in args
    positional = [a for a in args if not a.startswith("-")]

    if positional:
        levels_root = positional[0]
    else:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        levels_root = os.path.join(script_dir, "..", "assets", "levels")

    levels_root = os.path.normpath(levels_root)

    if not os.path.isdir(levels_root):
        print(f"Error: no se encontró la carpeta '{levels_root}'")
        sys.exit(2)

    files = find_level_files(levels_root)
    if not files:
        print(f"No se encontraron archivos JSON en '{levels_root}'")
        sys.exit(2)

    print(f"Directorio de niveles: {levels_root}")
    print(f"Archivos encontrados:  {len(files)}")
    print("=" * 60)

    grand_ok = grand_total = 0
    any_failure = False
    t_start = time.time()

    for folder, path in files:
        filename = os.path.basename(path)
        is_optimize = folder == "optimize"
        mode_tag = " [optimize: max_sum_r]" if is_optimize else ""
        print(f"\n{folder}/{filename}{mode_tag}")
        t0 = time.time()

        ok_count, total, failures = validate_file(folder, path, verbose, fail_fast)

        elapsed = time.time() - t0
        grand_ok += ok_count
        grand_total += total

        status = "OK" if not failures else f"{len(failures)} FALLOS"
        print(f"  -> {ok_count}/{total} válidos  [{elapsed:.1f}s]  {status}")

        if failures:
            any_failure = True
            if fail_fast:
                break

    elapsed_total = time.time() - t_start
    print()
    print("=" * 60)
    print(f"RESUMEN: {grand_ok}/{grand_total} niveles válidos  ({elapsed_total:.1f}s total)")
    if any_failure:
        print("RESULTADO: HAY ERRORES")
        sys.exit(1)
    else:
        print("RESULTADO: TODOS OK")
        sys.exit(0)


if __name__ == "__main__":
    main()
