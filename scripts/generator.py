import json
import os
import random
from collections import Counter, defaultdict

# =========================
# CONFIG
# =========================
BLOCK_SIZE = 50

OPS = ["+", "-", "*", "/"]

CONFIG = {
    "easy": {
        "size": 5, "levels": 50, "eq": 4, "max_guess": 0.50,
        "weights": [0.50, 0.30, 0.15, 0.05]
    },
    "medium": {
        "size": 7, "levels": 50, "eq": 8, "max_guess": 0.45,
        "weights": [0.30, 0.25, 0.30, 0.15]
    },
    "hard": {
        "size": 9, "levels": 50, "eq": 12, "max_guess": 0.40,
        "weights": [0.20, 0.20, 0.35, 0.25]
    },
}

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# =========================
# SETUP
# =========================

def ensure_dirs():
    for d in ["easy", "medium", "hard"]:
        os.makedirs(os.path.join(BASE_DIR, "assets", "levels", d), exist_ok=True)

# =========================
# ECUACIONES
# =========================

def generate_equation(mode):
    while True:
        if mode == "easy":
            a, b = random.randint(1, 20), random.randint(1, 20)
        elif mode == "medium":
            a, b = random.randint(5, 50), random.randint(5, 50)
        else:
            a, b = random.randint(10, 99), random.randint(10, 99)

        op = random.choices(OPS, weights=CONFIG[mode]["weights"])[0]

        if op == "+":
            if a == b: continue
            r = a + b
        elif op == "-":
            if a <= b:
                continue
            r = a - b
        elif op == "*":
            if (mode == "easy" or mode == "medium") and a == b: continue
            r = a * b
        elif op == "/":
            # Para división: a / b = r  =>  a = r * b
            # Generamos r y b, calculamos a
            r_val = random.randint(1, a) # Reutilizamos a como rango para el resultado
            b_val = random.randint(2, 10) # Divisor entre 2 y 10
            a_val = r_val * b_val
            if a_val > 999: continue
            a, b, r = a_val, b_val, r_val
            
        if op != "/" and r > 999:
            continue
        
        # Prohibir resultados < 5 en medium y hard
        if mode != "easy" and r < 5:
            continue

        return (a, op, b, r)

# =========================
# GRID LOGIC
# =========================

def place_equation(grid, eq, size, force_intersection):
    a, op, b, r = eq
    values = [str(a), op, str(b), "=", str(r)]

    for _ in range(300):
        horizontal = random.choice([True, False])
        orient = "H" if horizontal else "V"

        if horizontal:
            x = random.randint(0, size - 5)
            y = random.randint(0, size - 1)
            coords = [(x+i, y) for i in range(5)]
        else:
            x = random.randint(0, size - 1)
            y = random.randint(0, size - 5)
            coords = [(x, y+i) for i in range(5)]

        valid = True
        intersects = False

        for (cx, cy), val in zip(coords, values):
            if (cx, cy) in grid:
                # REGLA 1: Solo intersecciones perpendiculares
                if orient in grid[(cx, cy)]["orient"]:
                    valid = False
                    break
                # REGLA 2: Valores deben coincidir
                if grid[(cx, cy)]["val"] != val:
                    valid = False
                    break
                intersects = True
            
            # REGLA 3: Evitar que ecuaciones paralelas estén pegadas.
            # Solo revisamos vecinos en la dirección PERPENDICULAR a la ecuación actual.
            # H: solo revisa arriba (dx=-1) y abajo (dx=+1), no izquierda/derecha.
            # V: solo revisa izquierda (dy=-1) y derecha (dy=+1), no arriba/abajo.
            perp_neighbors = [(-1, 0), (1, 0)] if orient == "H" else [(0, -1), (0, 1)]
            for dx, dy in perp_neighbors:
                nc = (cx + dx, cy + dy)
                if nc in grid and nc not in coords:
                    if orient in grid[nc]["orient"]:
                        valid = False
                        break
            if not valid: break

        if not valid:
            continue

        if force_intersection and not intersects:
            continue

        return coords, values, orient

    return None, None, None


def build_grid(size, eq_target, mode):
    grid = {}
    equations = []

    # 1) primera ecuación
    for _ in range(100):
        eq = generate_equation(mode)
        coords, values, orient = place_equation(grid, eq, size, False)
        if coords:
            for c, v in zip(coords, values):
                grid[c] = {"val": v, "orient": {orient}}
            equations.append((coords, values))
            break

    if not equations:
        return None

    # 2) siguientes (SIEMPRE conectadas)
    attempts = 0

    while len(equations) < eq_target and attempts < 5000:
        attempts += 1

        eq = generate_equation(mode)

        coords, values, orient = place_equation(
            grid,
            eq,
            size,
            force_intersection=True
        )

        if not coords:
            continue

        for c, v in zip(coords, values):
            if c in grid:
                grid[c]["orient"].add(orient)
            else:
                grid[c] = {"val": v, "orient": {orient}}

        equations.append((coords, values))

    # 🔴 clave: si no logra conectar todo → descartar
    if len(equations) < eq_target:
        return None, None, 0

    # Calcular intersecciones reales (celdas usadas por >1 ecuación)
    cell_usage = Counter()
    for coords, vals in equations:
        for c in coords:
            cell_usage[c] += 1
    
    intersections = sum(1 for c, count in cell_usage.items() if count > 1)

    return grid, equations, intersections

# =========================
# SOLVERS
# =========================

class LogicalSolver:
    """Simula el pensamiento deductivo del jugador."""
    def __init__(self, grid, equations):
        self.grid = grid
        self.equations = equations # list of (a, op, b, r) with coords
        
    def solve(self, fixed_coords):
        known = set(fixed_coords)
        hidden_nums = {c for c, v in self.grid.items() if v["val"].isdigit() and c not in fixed_coords}
        
        if not hidden_nums:
            return 0.0

        total_hidden = len(hidden_nums)
        deduced = set()
        
        changed = True
        while changed:
            changed = False
            for eq_coords, eq_vals in self.equations:
                # eq_coords: [(x,y) for a, op, b, =, r]
                # eq_vals: [a, op, b, =, r]
                a_c, op_c, b_c, eq_sign_c, r_c = eq_coords
                
                # Check which parts are known
                a_k = a_c in known or a_c in deduced
                b_k = b_c in known or b_c in deduced
                r_k = r_c in known or r_c in deduced
                
                op = eq_vals[1]
                
                # Logic:
                # if a, b known -> r deduced
                if a_k and b_k and not r_k:
                    if r_c in hidden_nums:
                        deduced.add(r_c)
                        changed = True
                # if a, r known -> b deduced
                elif a_k and r_k and not b_k:
                    if b_c in hidden_nums:
                        # Para / y *, esto es siempre deducible si no es 0
                        deduced.add(b_c)
                        changed = True
                # if b, r known -> a deduced
                elif b_k and r_k and not a_k:
                    if a_c in hidden_nums:
                        deduced.add(a_c)
                        changed = True
                        
        guess_count = total_hidden - len(deduced)
        return guess_count / total_hidden

class CSPSolver:
    """Verifica la unicidad de la solución."""
    def __init__(self, grid, equations):
        self.grid = grid
        self.equations = equations # [(coords, vals), ...]
        self.variables = [c for c, v in grid.items() if v["val"].isdigit()]
        
    def check_unique(self, fixed_coords):
        var_to_solve = [c for c in self.variables if c not in fixed_coords]
        if not var_to_solve:
            return True
            
        pool = [self.grid[c]["val"] for c in var_to_solve]
        solutions = []
        
        # Pre-mapear ecuaciones a variables para poda
        var_to_eqs = defaultdict(list)
        for i, (eq_coords, eq_vals) in enumerate(self.equations):
            for c in eq_coords:
                if c in var_to_solve:
                    var_to_eqs[c].append(i)

        def is_valid_eq(eq_idx, current_grid):
            eq_coords, eq_vals = self.equations[eq_idx]
            vals = []
            for c in eq_coords:
                if c in current_grid:
                    vals.append(current_grid[c])
                elif c in self.grid: # fixed
                    vals.append(self.grid[c]["val"])
                else:
                    return True # No completa aún, no podemos invalidar
            
            a, op, b, _, r = vals
            try:
                ai, bi, ri = int(a), int(b), int(r)
                if op == "+": return ai + bi == ri
                if op == "-": return ai - bi == ri
                if op == "*": return ai * bi == ri
                if op == "/": return bi != 0 and ai // bi == ri and ai % bi == 0
            except: return False
            return False

        def backtrack(idx, current_pool, current_grid):
            if len(solutions) > 1: return
            
            if idx == len(var_to_solve):
                solutions.append(dict(current_grid))
                return

            var = var_to_solve[idx]
            seen_in_pool = set()
            for i in range(len(current_pool)):
                val = current_pool[i]
                if val in seen_in_pool: continue
                seen_in_pool.add(val)
                
                current_grid[var] = val
                
                # Poda: verificar si las ecuaciones completadas son válidas
                possible = True
                for eq_idx in var_to_eqs[var]:
                    if not is_valid_eq(eq_idx, current_grid):
                        possible = False
                        break
                
                if possible:
                    new_pool = current_pool[:i] + current_pool[i+1:]
                    backtrack(idx + 1, new_pool, current_grid)
                
                del current_grid[var]
                if len(solutions) > 1: return

        backtrack(0, pool, {})
        return len(solutions) == 1

# =========================
# VALIDACIÓN
# =========================

def is_valid(grid, equations, intersections, mode, size):
    if not grid or not equations:
        return False, None

    # 1. Densidad >= 50% (balance entre tablero lleno y reglas estructurales)
    density = len(grid) / (size * size)
    if density < 0.50:
        return False, None
        
    # 2. Intersecciones reales >= 20%
    if intersections < len(equations) * 0.20:
        return False, None
        
    # 3. Mínimo 5-6 números distintos
    all_num_coords = [c for c, v in grid.items() if v["val"].isdigit()]
    all_nums = [grid[c]["val"] for c in all_num_coords]
    counts = Counter(all_nums)
    total_nums = len(all_nums)

    min_distinct = 5 if mode == "easy" else 6
    if len(counts) < min_distinct:
        return False, None
        
    # 4. Ningún número > 15% del total (mínimo 2 para permitir intersecciones)
    limit = max(2, int(total_nums * 0.15))
    if any(count > limit for count in counts.values()):
        return False, None
        
    # 5. Estrategia: Fijamos números hasta que el 85% sea deducible
    fixed_coords = {c for c, v in grid.items() if not v["val"].isdigit()}
    
    random.shuffle(all_num_coords)
    
    # REGLA: Límite de fijos por ecuación para evitar niveles "ya resueltos"
    # Forzamos máximo 1 número fijo por ecuación en todas las dificultades.
    max_fixed_per_eq = 1
    eq_fixed_counts = Counter()
    
    # Probamos fijando inicialmente un número mínimo aleatorio
    initial_count = 1 if mode == "easy" else max(1, len(all_num_coords) // 8)
    for i in range(min(initial_count, len(all_num_coords))):
        c = all_num_coords[i]
        
        # Verificar si podemos fijarlo respetando el límite
        can_fix_initial = True
        for eq_idx, (eq_coords, _) in enumerate(equations):
            if c in eq_coords and eq_fixed_counts[eq_idx] >= max_fixed_per_eq:
                can_fix_initial = False
                break
        
        if can_fix_initial:
            fixed_coords.add(c)
            for eq_idx, (eq_coords, _) in enumerate(equations):
                if c in eq_coords:
                    eq_fixed_counts[eq_idx] += 1
        
    ls = LogicalSolver(grid, equations)
    
    # Vamos añadiendo fijos uno a uno si es necesario hasta cumplir el ratio
    for i in range(initial_count, len(all_num_coords)):
        ratio = ls.solve(fixed_coords)
        if ratio <= CONFIG[mode]["max_guess"]:
            # Cumple deducibilidad. Ahora verificamos unicidad.
            csp = CSPSolver(grid, equations)
            if csp.check_unique(fixed_coords):
                return True, fixed_coords
        
        c = all_num_coords[i]
        
        # Solo fijamos si la(s) ecuación(es) involucrada(s) no tiene(n) ya el máximo permitido
        can_fix = True
        for eq_idx, (eq_coords, _) in enumerate(equations):
            if c in eq_coords and eq_fixed_counts[eq_idx] >= max_fixed_per_eq:
                can_fix = False
                break
        
        if can_fix:
            fixed_coords.add(c)
            for eq_idx, (eq_coords, _) in enumerate(equations):
                if c in eq_coords:
                    eq_fixed_counts[eq_idx] += 1
        
    # Si llegamos aquí y es único (que lo será si fijamos casi todo), devolvemos
    csp = CSPSolver(grid, equations)
    if csp.check_unique(fixed_coords):
        return True, fixed_coords

    return False, None


# =========================
# SERIALIZACIÓN
# =========================

def build_footer(grid, fixed_coords):
    return [v["val"] for c, v in grid.items() if v["val"].isdigit() and c not in fixed_coords]


def to_cells(grid, fixed_coords):
    cells = []

    for (x, y), data in grid.items():
        v = data["val"]
        if v.isdigit():
            t = 1
        elif v in OPS:
            t = 2
        else:
            t = 3

        cells.append({
            "x": x,
            "y": y,
            "type": t,
            "value": v,
            "isFixed": (c := (x, y)) in fixed_coords or t != 1,
            "isHorizontal": "H" in data["orient"]
        })

    return cells


def save_block(levels, path):
    with open(path, "w") as f:
        json.dump(levels, f)

# =========================
# GENERADOR
# =========================

def generate_levels(mode):
    conf = CONFIG[mode]
    size = conf["size"]
    total = conf["levels"]
    eq_target = conf["eq"]

    levels = []
    level_id = 1
    attempts = 0

    while len(levels) < total:
        attempts += 1

        if attempts % 100 == 0:
            print(f"{mode} attempts: {attempts}, generated: {len(levels)}", flush=True)

        res = build_grid(size, eq_target, mode)
        if not res: continue
        
        grid, equations, intersections = res
        
        ok, fixed_coords = is_valid(grid, equations, intersections, mode, size)
        if not ok:
            if attempts % 10 == 0: print(".", end="", flush=True)
            continue
            
        print(f"\nLevel found after {attempts} attempts!", flush=True)

        level = {
            "id": level_id,
            "size": size,
            "footerTiles": build_footer(grid, fixed_coords),
            "cells": to_cells(grid, fixed_coords)
        }

        levels.append(level)

        if level_id % 10 == 0:
            print(f"{mode} -> nivel {level_id} generado")

        level_id += 1

    # Guardar todos los niveles en un solo archivo por categoría
    path = os.path.join(BASE_DIR, "assets", "levels", mode, f"levels_{mode}.json")
    save_block(levels, path)
    print(f"Saved {path} with {len(levels)} levels")

# =========================
# RUN
# =========================

if __name__ == "__main__":
    ensure_dirs()

    for mode in ["easy", "medium", "hard"]:
        print(f"Generating {mode}...")
        generate_levels(mode)

    print("DONE")