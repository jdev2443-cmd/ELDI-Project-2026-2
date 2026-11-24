<h1 align="center">Bienvenido a ATRAPALUX 😎</h1>
<p align="center">
---Proyecto de implementación en Verilog HDL de un juego de velocidad de reacción sobre una FPGA Tang Nano 9K (Gowin GW1NR-9). El sistema utiliza una matriz de LEDs direccionables WS2812B de 4×4, una matriz de 16 pulsadores y retroalimentación sonora mediante un módulo DFPlayer Mini controlado por UART.
---
  
## Funcionamiento del juego

1. **Estado de Espera (`IDLE`):** La matriz se ilumina en **amarillo** mientras espera el inicio de la partida (`start_dip_n`).
2. **Selección de Dificultad:** Se configura mediante interruptores DIP antes de iniciar cada ronda:
   * **Fácil:** El bot reacciona en `1500 ms`.
   * **Medio:** El bot reacciona en `900 ms`.
   * **Difícil:** El bot reacciona en `550 ms`.
3. **Mecánica de Rondas (`PLAY`):**
   * Cada partida es de **3 rondas**.
   * Un generador pseudoaleatorio **LFSR de 16 bits** selecciona uno de los 16 LEDs y lo enciende en **verde**.
   * **Logro correcto:** Si el jugador presiona el botón correspondiente antes que el bot, gana la ronda y se muestra un **cuadrado verde** durante `1 s`.
   * **Error (`PENALTY`):** Si presiona un botón equivocado, toda la matriz parpadea en **rojo** durante `500 ms` como penalización mientras el tiempo del bot sigue corriendo.
   * **Derrota de ronda:** Si el tiempo del bot se agota primero, se muestra una **X roja** durante `1 s`.
4. **Resultado Final (`FINAL`):** Al completar las 3 rondas, la matriz parpadea durante `4 s` y reproduce una pista de audio por UART:
   * **Victoria del jugador:** Cuadrado **morado** parpadeante + pista `/MP3/0001.mp3`.
   * **Victoria del bot:** **X roja** parpadeante + pista `/MP3/0002.mp3`.
  
##  Hardware y Pinout

### Componentes Necesarios
* **FPGA:** Sipeed Tang Nano 9K (`27 MHz` reloj interno).
* **Display:** Matriz WS2812B 4×4 (16 LEDs en cascada, configuración serpentina).
* **Entrada:** 16 pulsadores (lógica activa en bajo con pull-up) + 4 interruptores DIP (Inicio + 3 niveles de dificultad).
* **Audio:** Módulo DFPlayer Mini + tarjeta microSD con carpeta `/MP3/` (`0001.mp3` y `0002.mp3`) + altavoz.

### Conexiones Principales
 Señal Verilog | Dirección | Descripción / Pin Tang Nano 9K 
 `clk` | `input` | Reloj principal de `27 MHz` (Pin `52`) 
 `ws_data` | `output` | Línea de datos hacia `DIN` de la matriz WS2812B 
 `df_tx` | `output` | UART TX hacia `RX` del DFPlayer Mini (Pin `71`) 
 `df_rx` | `input` | UART RX desde `TX` del DFPlayer Mini (Pin `72`) 
 `bt[15:0]` | `input` | Bus de 16 pulsadores (activos en bajo) 
 `start_dip_n` | `input` | Interruptor de inicio de partida (activo en bajo) 
 `dip_easy_n` | `input` | Selección dificultad Fácil (activo en bajo) 
 `dip_medium_n` | `input` | Selección dificultad Medio (activo en bajo) 
 `dip_hard_n` | `input` | Selección dificultad Difícil (activo en bajo) 


## Arquitectura del Diseño

El diseño está estructurado en dos módulos principales dentro de un esquema síncrono a `27 MHz`:
* **`reaction_game` (Top-Level):**
  * **Sincronizador de 2 etapas y Antirrebote:** Filtra rebotes mecánicos en los 16 botones con una ventana de `10 ms` (`DB_COUNT = CLK_FREQ / 100`).
  * **Generador LFSR (`16'hACE1`):** Polinomio $x^{16} + x^{14} + x^{13} + x^{11} + 1$ para selección aleatoria de objetivos.
  * **FSM de Control:** Gestiona los estados `IDLE`, `PLAY`, `PENALTY`, `RESULT` y `FINAL`.
  * **Controlador WS2812B:** Serializador de 384 bits (16 LEDs × 24 bits en formato GRB) con tiempos calibrados para `27 MHz` (`T0H ≈ 370 ns`, `T1H ≈ 815 ns`, `RESET > 80 µs`).
* **`dfplayer_uart`:**
  * Transmisor UART `9600 8N1` que construye y envía la trama de 10 bytes (`0x7E 0xFF 0x06 0x12 ... 0xEF`)

## Parámetros Ajustables 

Puedes ajustar el comportamiento del módulo principal modificando los siguientes parámetros en la instanciación:

```verilog
reaction_game #(
    .CLK_FREQ      (27000000), // Frecuencia de reloj en Hz
    .LEVEL         (8'd32),    // Brillo máximo de los LEDs (0 - 255)
    .COLOR_GRB     (1),        // 1: Orden GRB (WS2812B estándar) | 0: RGB
    .SERPENTINE    (1),        // 1: Cableado en zigzag | 0: Progresivo
    .USE_RESET_PIN (0),        // 1: Habilita pin físico reset_n | 0: Power-On Reset
    .TEST_MODE     (0)         // 1: Prueba colores RGB en LEDs 0, 1 y 2
) juego_inst ( ... );
```
## Módulos
El repositorio consta de diferentes segmentaciones del codigo principal, para fines de ubicación de partes se agruparon por carpetas, en las cuales se tiene el codigo de la parte a ubicar,
de igual manera se puede encontrar los modulos principales **Modjuego** y **Modmusica**, siendo estos los ejecutables del proyecto en la FPGA.

## Aclaraciones

Durante la elaboración del proyecto se recurrió a diferentes recursos de carácter informativo y de IA, estos recursos fueron utilizados para las siguientes especificaciones.
* **RECURSOS INFORMATIVOS**
    * **Código fuente de snake**: se tomó como referencia el codigo base de snake para encontrar la forma óptima de realizar la aleatoriedad del objetivo en la matriz de leds
    * **Especificación tang nano 9k**: se utilizó la ficha tecnica de la tang nano 9k para la identificación de diferentes especificaciones como frecuencia y pines
    * **Documentación de maquinas de estados**: se investigó acercca del funcionamiento y logica de las maquinas de estados oara enfcontrar el correcto funcionamiento del proyecto haciendo uso de las maquinas de estados FSM
* **RECURSOS IA**
   * **CHATGPT**: se utilizó la inteligencia artificial de Chatgpt como ayuda de segmentación y correccion de logica seccuencial
   * **GEMINI**: se utilizó la inteligencia artificial de Gemini como asesor de diseño del proyecto
   * **CLAUDE**: se utilizó la inteligencia artificial de Claude como ayudante y correcor de funcionamiento del codigo en aspectos como la conección de el DFPlayer con el resto del circuito, y el segundo modulo, incluyendo traduccion de musica e implementación de lectura.

## Creadores
* Juan Esteban Bolivar Muñoz
* Valentina Carrillo Cardenas
