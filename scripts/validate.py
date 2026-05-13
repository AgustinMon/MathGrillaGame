"""
Validador independiente de niveles de crossmath.

Uso como módulo:
    from validate import validate_level
    ok, reason = validate_level(level_dict)

Uso como CLI:
    python3 validate.py /ruta/a/assets/levels
"""
import json
import os
import sys
from collections import Counter, defaultdict


# ---------------------------------------------------------------------------
# Carga y render (sólo para CLI)
# ---------------------------------------------------------------------------

def load(path):
    with open(path) as f:
        return json.load(f)


def render(level):
    size = level["size"]
    grid = [[" . " for _ in range(size)] for _ in range(size)]
    for c in level["cells"]:
        v = c["value"]
        if c["type"] == 1 and not c["isFixed"]:
            v = "_" + v + "_"
        s = v.center(3)
        grid[c["y"]][c["x"]] = s
    print(f"\nLevel {level['id']} (size {size}, footer={level['footerTiles']}):")
    for row in grid:
        print("".join(row))


# ---------------------------------------------------------------------------
# Reconstrucción de palabras
# ---------------------------------------------------------------------------

def find_runs(cells_by_xy, size):
    """Devuelve (h_runs, v_runs) — secuencias contiguas de >=5 celdas en
    cada fila / columna. Una run de longitud != 5 indica concatenación
    accidental de ecuaciones."""
    h_runs, v_runs = [], []
    for y in range(size):
        run = []
        for x in range(size):
            if (x, y) in cells_by_xy:
                run.append((x, y))
            else:
                if len(run) >= 5:
                    h_runs.append(run)
                run = []
        if len(run) >= 5:
            h_runs.append(run)
    for x in range(size):
        run = []
        for y in range(size):
            if (x, y) in cells_by_xy:
                run.append((x, y))
            else:
                if len(run) >= 5:
                    v_runs.append(run)
                run = []
        if len(run) >= 5:
            v_runs.append(run)
    return h_runs, v_runs


# ---------------------------------------------------------------------------
# Reglas estructurales
# ---------------------------------------------------------------------------

def check_structure(level, cells_by_xy, h_runs, v_runs):
    """Verifica que cada run sea una ecuación válida de 5 celdas y que no
    haya palabras paralelas pegadas."""
    for run in h_runs + v_runs:
        if len(run) != 5:
            return False, f"run de {len(run)} celdas en {run[0]} (debe ser 5)"

    for run in h_runs + v_runs:
        vals = [cells_by_xy[xy]["value"] for xy in run]
        try:
            a = int(vals[0])
            op = vals[1]
            b = int(vals[2])
            eq_sign = vals[3]
            r = int(vals[4])
        except (ValueError, IndexError):
            return False, f"run mal formada en {run[0]}: {vals}"

        if eq_sign != "=":
            return False, f"run sin '=' en pos 3: {vals}"

        if op == "+":
            ok = (a + b == r)
        elif op == "-":
            ok = (a - b == r)
        elif op == "*":
            ok = (a * b == r)
        elif op == "/":
            ok = (b != 0 and a == b * r)
        else:
            return False, f"operador inválido '{op}' en {run[0]}"
        if not ok:
            return False, f"ecuación inválida: {a}{op}{b}={r}"

    cell_to_hruns = defaultdict(set)
    for i, run in enumerate(h_runs):
        for xy in run:
            cell_to_hruns[xy].add(i)
    cell_to_vruns = defaultdict(set)
    for i, run in enumerate(v_runs):
        for xy in run:
            cell_to_vruns[xy].add(i)

    for (x, y) in cells_by_xy:
        for dy in (-1, 1):
            nb = (x, y + dy)
            if nb in cells_by_xy:
                hr_a = cell_to_hruns[(x, y)]
                hr_b = cell_to_hruns[nb]
                if hr_a and hr_b and hr_a != hr_b:
                    if not (cell_to_vruns[(x, y)] & cell_to_vruns[nb]):
                        return False, f"paralelas H pegadas en {(x,y)} y {nb}"
        for dx in (-1, 1):
            nb = (x + dx, y)
            if nb in cells_by_xy:
                vr_a = cell_to_vruns[(x, y)]
                vr_b = cell_to_vruns[nb]
                if vr_a and vr_b and vr_a != vr_b:
                    if not (cell_to_hruns[(x, y)] & cell_to_hruns[nb]):
                        return False, f"paralelas V pegadas en {(x,y)} y {nb}"

    return True, None


# ---------------------------------------------------------------------------
# Conectividad
# ---------------------------------------------------------------------------

def check_connected(cells_by_xy):
    if not cells_by_xy:
        return False, "tablero vacío"
    start = next(iter(cells_by_xy))
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (x + dx, y + dy)
            if nb in cells_by_xy and nb not in seen:
                seen.add(nb)
                stack.append(nb)
    if len(seen) != len(cells_by_xy):
        return False, f"tablero desconectado ({len(seen)}/{len(cells_by_xy)})"
    return True, None


# ---------------------------------------------------------------------------
# Unicidad de solución
# ---------------------------------------------------------------------------

def check_unique(level, cells_by_xy, h_runs, v_runs):
    """Simula el juego: pool del footer + clues → ¿una sola asignación?

    Implementa el CSP con propagación: cuando una ecuación tiene 2 valores
    conocidos y 1 libre, el libre queda determinado por aritmética. Esto
    reduce drásticamente el espacio de búsqueda."""
    variables = [
        xy for xy, c in cells_by_xy.items()
        if c["type"] == 1 and not c["isFixed"]
    ]
    pool = Counter(level["footerTiles"])

    if sum(pool.values()) != len(variables):
        return False, (f"footer size {sum(pool.values())} != "
                       f"variables {len(variables)}")

    # Ecuaciones como (a_xy, b_xy, r_xy, op)
    eqs = []
    for run in h_runs + v_runs:
        if len(run) == 5:
            a_xy, op_xy, b_xy, _, r_xy = run
            eqs.append((a_xy, b_xy, r_xy, cells_by_xy[op_xy]["value"]))

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

    sols = [0]

    def backtrack(assignment, pool_state):
        if sols[0] >= 2:
            return

        # Propagación: deducir valores forzados
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
                sols[0] += 1
            for var, val in reversed(forced):
                del assignment[var]
                pool_state[val] += 1
            return

        # Elegir variable con más ecuaciones (MRV-like)
        var = remaining[0]
        best_score = -1
        for v in remaining:
            score = len(var_to_eqs[v])
            if score > best_score:
                best_score = score
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
            if sols[0] >= 2:
                break

        for var, val in reversed(forced):
            del assignment[var]
            pool_state[val] += 1

    backtrack({}, dict(pool))

    if sols[0] == 0:
        return False, "sin solución"
    if sols[0] > 1:
        return False, "múltiples soluciones"
    return True, None


# ---------------------------------------------------------------------------
# API principal
# ---------------------------------------------------------------------------

def validate_level(level):
    """Valida un nivel completo. Devuelve (ok: bool, motivo: str|None)."""
    cells_by_xy = {(c["x"], c["y"]): c for c in level["cells"]}
    size = level["size"]

    ok, reason = check_connected(cells_by_xy)
    if not ok:
        return False, reason

    h_runs, v_runs = find_runs(cells_by_xy, size)

    if not h_runs and not v_runs:
        return False, "sin ecuaciones detectables"

    ok, reason = check_structure(level, cells_by_xy, h_runs, v_runs)
    if not ok:
        return False, reason

    ok, reason = check_unique(level, cells_by_xy, h_runs, v_runs)
    if not ok:
        return False, reason

    return True, None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "."
    total_ok = total = 0
    for mode in ["easy", "medium", "hard"]:
        path = os.path.join(base, mode, f"levels_{mode}.json")
        if not os.path.exists(path):
            print(f"  (saltado) {path}")
            continue
        levels = load(path)
        for lvl in levels:
            total += 1
            print("=" * 60)
            print(f"MODE: {mode}")
            render(lvl)
            ok, reason = validate_level(lvl)
            if ok:
                total_ok += 1
                print("  ✅ válido")
            else:
                print(f"  ❌ inválido: {reason}")
    print()
    print(f"Resumen: {total_ok}/{total} válidos")
    sys.exit(0 if total_ok == total else 1)


if __name__ == "__main__":
    main()
