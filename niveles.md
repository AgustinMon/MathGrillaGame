# Criterios de Armado de Niveles (Crucimath)

Este documento detalla la lógica interna utilizada por el motor de generación (`MathEngine` y `generate_levels.dart`) para crear los niveles del juego.

## 1. Tamaños de Tablero por Dificultad
Los tamaños del crucigrama crecen progresivamente según el nivel actual del jugador dentro de cada categoría:

*   **Fácil (Easy):**
    *   Rango de tamaño: `5x5` a `10x10`.
    *   Incremento: +1 celda de tamaño cada 20 niveles.
    *   Cantidad generada: 100 niveles.
*   **Medio (Medium):**
    *   Rango de tamaño: `11x11` a `15x15`.
    *   Incremento: +1 celda de tamaño cada 70 niveles.
    *   Cantidad generada: 350 niveles.
*   **Difícil (Hard):**
    *   Rango de tamaño: `16x16` a `20x20`.
    *   Incremento: +1 celda de tamaño cada 40 niveles.
    *   Cantidad generada: 200 niveles.

## 2. Operaciones Matemáticas Permitidas
*   **Niveles 1 a 5 (Tutorial y primer contacto):** Solo suma (`+`) y resta (`-`).
*   **Nivel 6 en adelante:** Se introduce la multiplicación (`*`).
*   **Nivel 11 en adelante:** Se introduce la división (`/`).
*   *Nota:* En los modos Medio y Difícil, todas las operaciones están disponibles desde el nivel 1.

## 3. Lógica de Pistas Fijas (Deducción vs Adivinanza)
Para evitar que el jugador tenga que adivinar ("fuerza bruta") y fomentar la **deducción lógica**, el motor fija (pre-completa) un porcentaje de las celdas en el tablero.

*   **Porcentajes Base de Fijos:**
    *   **Fácil:** ~40% de las celdas están fijas.
    *   **Medio:** ~35% de las celdas están fijas.
    *   **Difícil:** ~30% de las celdas están fijas.
*   **Sesgo hacia Resultados:** Al momento de decidir qué celda dejar fija, el motor le otorga un **+10% extra de probabilidad a las celdas de resultado** (lo que está a la derecha del símbolo `=`). Esto garantiza que muchas ecuaciones revelen su meta (ej. `_ + _ = 15`), permitiendo resolver el crucigrama cruzando filas y columnas de manera deductiva.
*   **Restricciones de Dificultad:**
    *   Nunca se fijan los 3 números de una misma ecuación.
    *   En niveles fáciles y medios, una ecuación nueva puede tener hasta 2 números fijos.
    *   En niveles difíciles, una ecuación nueva tiene como máximo 1 número fijo.

## 4. Validación Estricta
El juego evalúa no solo que una ecuación sea matemáticamente viable, sino que también corresponda al diseño original:
*   **Acierto (Verde):** La matemática es correcta y las piezas colocadas son las que se designaron originalmente para ese espacio.
*   **Coincidencia Parcial (Amarillo Oscuro):** La ecuación es matemáticamente correcta (ej. `2 + 3 = 5`), pero esas fichas estaban pensadas para otras intersecciones. La celda no da puntos, pero tampoco descuenta vidas, permitiendo al jugador darse cuenta de que "cuadra" la matemática pero no el crucigrama.
*   **Error (Rojo):** La ecuación es matemáticamente incorrecta. El juego vibra, emite un sonido de error y resta una vida.
