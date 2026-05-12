# Criterios de Armado y Lógica de Niveles (CruciMath)

Este documento detalla la lógica interna utilizada por el motor de generación procedural (`generator.py`) y el sistema de validación para garantizar una experiencia equilibrada, deductiva y de alta calidad.

## 1. Estructura y Densidad por Dificultad

Para garantizar que los niveles se sientan como verdaderos crucigramas y no como operaciones aisladas, se aplican restricciones estrictas de densidad y conectividad:

| Dificultad | Tamaño Grilla | Cant. Ecuaciones | Densidad Mínima | Intersecciones Reales |
| :--- | :--- | :--- | :--- | :--- |
| **Fácil** | 5x5 | ≥ 4 | 60% | ≥ 30% |
| **Medio** | 7x7 | ≥ 8 | 60% | ≥ 30% |
| **Difícil** | 9x9 | ≥ 12 | 60% | ≥ 30% |

*   **Densidad**: Al menos el 60% de las celdas de la grilla deben estar ocupadas.
*   **Intersecciones**: Al menos el 30% de las ecuaciones deben compartir un número con otra ecuación.

## 2. Motor Matemático y Reglas de Calidad

Para evitar niveles triviales o repetitivos, el generador aplica las siguientes restricciones:

### A. Restricciones de Operación
*   **Prohibición de Dobles**: No se permiten operaciones de tipo `a + a` ni `a * a` (esta última solo en Easy/Medium).
*   **Resultados Significativos**: En dificultades **Medio y Difícil**, todos los resultados deben ser **≥ 5**.
*   **Sin Operaciones Nulas**: Se prohíben operaciones que resulten en 0 (ej. `a - a`).

### B. Distribución de Operadores
Cada dificultad tiene un "peso" específico para fomentar el uso de operaciones más complejas:

| Dificultad | Suma (+) | Resta (-) | Multiplicación (×) | División (÷) |
| :--- | :--- | :--- | :--- | :--- |
| **Fácil** | 50% | 30% | 15% | 5% |
| **Medio** | 30% | 25% | 30% | 15% |
| **Difícil** | 20% | 20% | 35% | 25% |

### C. Variedad Numérica
*   **Mínimo de Números Distintos**: Easy (≥ 5), Medium/Hard (≥ 6).
*   **Límite de Repetición**: Ningún número puede representar más del **15%** del total de números del nivel (con un mínimo de 2 para permitir cruces).

## 3. Garantía de Resolubilidad (Solvers)

Cada nivel generado debe pasar por dos validadores automáticos antes de ser aceptado:

### A. Solver Lógico (Deducibilidad)
*   Simula el razonamiento humano paso a paso.
*   **Regla del 15%**: Al menos el **85%** de los números ocultos deben ser deducibles lógicamente a partir de las celdas fijas y las ecuaciones que se van resolviendo. Solo se permite un máximo de 15% de "adivinanza" inicial.

### B. Solver CSP (Unicidad)
*   Verifica mediante backtracking que el conjunto de piezas en el inventario (footer) permita **exactamente una única solución** válida en la grilla.
*   Si existe más de una forma de colocar los números que cumpla todas las ecuaciones, el nivel se descarta por ambiguo.

## 4. Lógica de Celdas Fijas (Anclajes)
*   Los operadores (+, -, *, /) y el signo igual (=) son **siempre fijos**.
*   Los números tienen una probabilidad base de ser fijos, pero el sistema añade números fijos estratégicamente hasta que el nivel cumple con la **Regla del 15%** de deducibilidad.

## 5. Estados de Validación en Juego
*   **Verde (Match):** Matemática correcta + Posición correcta.
*   **Amarillo (Math-Only):** Matemática correcta pero posición incorrecta en el puzzle.
*   **Rojo (Error):** Matemática incorrecta. Resta una vida.
