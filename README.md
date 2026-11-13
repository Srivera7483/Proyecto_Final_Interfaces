# Proyecto #3 — Interfaces Gráficas (INFO1128)
## Visor de Material Particulado MP 2.5 µm
**Docente:** Profesor Asistente Alberto Caro (`LCARO@UCT.CL`)  
**Ayudante:** Daniela Romero  
**Universidad Católica de Temuco — Facultad de Ingeniería**  
**Desarrollador:** Kuro_Waza  

---

## 1. Resumen General del Proyecto

Este proyecto consiste en el desarrollo integral de una plataforma distribuida en 3 capas para la medición, adquisición serial, visualización gráfica en tiempo real y persistencia en base de datos de **Material Particulado fino MP 2.5 µm** (partículas respirables con diámetro aerodinámico $\le 2.5\ \mu\text{m}$).

### Arquitectura en 3 Capas:
1. **Emisor / Simulador Serial (Python 3):**
   - Transmite tramas por puerto serial virtual (**COM1**, 9600 Baudios, 8N1).
   - Intervalo de muestreo (sampling) de **1 segundo** (1 Hz).
   - Generación estocástica modelada estrictamente con una **Distribución Normal $\mathcal{N}(\mu=80, \sigma=5)$** (Requerimiento #5).

2. **Visor Gráfico Humano-Máquina (Lazarus Free Pascal GUI):**
   - Desarrollado con Lazarus LCL y compilado a código nativo de 64 bits (`VisorMP25.exe`).
   - Receptor serial integrado con el componente **`TLazSerial`** en **COM2** a 9600-8N1.
   - Gráfico de series temporales en tiempo real con **`TAChart`** y **`TLineSeries`**:
     - Ventana deslizante de **30 muestras continuas** (rango horizontal de 0 a 29).
     - Eje vertical $Y$: `[ug/m3]` con rango acotado de 0 a 200.
     - Trazado de línea roja (`LinePen`), punteros cuadrados azules con borde amarillo (`Pointer`), y marcas numéricas con recuadro blanco y borde negro sobre cada punto (`Marks`).
     - Título superior: **"Material Particulado 2.5 um"**.
     - Subtítulo inferior: **"Sampling MP 2.5um"**.
     - Título de ventana: **"By Alberto Caro"** con icono.
     - Propiedad `Hint` y `ShowHint := True` habilitada en cada botón y control interactivo.
     - Botón **"Save"** (icono `camara.png`): guarda una instantánea del visor en `captura.png`.
     - Botón **"On/off"** (iconos de toggle `f01.bmp`/`f02.bmp`): activa/desactiva la grilla punteada del visor.
     - Botón **"Click"** (icono `pale.png`): rota cíclicamente los paisajes de fondo (`img1.png` a `img6.png`).
     - Monograma/icono del disquete AC (`disk.png`) en la esquina superior izquierda del visor.
   - Cliente **TCP/IP** integrado: Cada muestra recibida es enviada inmediatamente mediante un socket TCP hacia `127.0.0.1:5000`.

3. **Servidor Backend en Modo Consola y Base de Datos (Lazarus Pascal + SQLite3):**
   - Aplicación de terminal compilada (`ServerConsola.exe`).
   - Servidor TCP/IP Winsock a la escucha en el puerto `5000`.
   - Muestra las lecturas recibidas por consola con timestamp:  
     `[00001] YYYY-MM-DD HH:NN:SS | Cliente: 127.0.0.1 | MP 2.5: 82.3 ug/m3 -> Guardado en SQLite`
   - Motor de persistencia SQLite (`sensores.db`) en la tabla `Aire`:
     `CREATE TABLE IF NOT EXISTS Aire (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, hora TEXT, mp25 REAL);`
   - Compatible con **HeidiSQL Portable** para auditoría y visualización de datos en vivo.

---

## 2. Estructura de Directorios

```text
Proyecto_Final_Interfaces/
├── simulador/                          # Capa de Simulación y Telemetría
│   └── simulador_mp25.py               # Emisor serial Python (9600-8N1, Normal(80,5), 1s)
├── servidor_consola/                   # Capa Backend / Persistencia
│   ├── ServerConsola.lpr               # Código fuente del Servidor TCP/IP + SQLite
│   ├── ServerConsola.exe               # Ejecutable compilado en modo consola
│   └── sqlite3.dll                     # Motor dinámico SQLite3 64-bit
├── visor_lazarus/                      # Capa Frontend GUI
│   ├── VisorMP25.lpr                   # Archivo principal del proyecto Lazarus
│   ├── VisorMP25.lpi                   # Archivo de configuración del proyecto Lazarus
│   ├── VisorMP25.exe                   # Ejecutable compilado del Visor
│   ├── main_unit.pas                   # Lógica completa (TAChart, TLazSerial, TCP client)
│   ├── main_unit.lfm                   # Diseño visual del formulario
│   ├── camara.png                      # Icono del botón Save (captura de pantalla)
│   ├── pale.png                        # Icono del botón Click (rotación de fondo)
│   ├── disk.png                        # Icono AC disquete (marca de agua en gráfico)
│   ├── f01.bmp / f02.bmp               # Glifos on/off de la grilla
│   ├── f_003.bmp                       # Icono institucional de la aplicación
│   └── img1.png .. img6.png            # Colección de imágenes de paisajes de fondo
├── TLazSerial/                         # Paquete y librería serial para Lazarus
├── Recursos Proyecto #3/               # Recursos originales de Blackboard
├── Documentacion_Proyecto3_INFO1128.pdf# DOCUMENTO TÉCNICO COMPLETO EN PDF (9 páginas)
├── generar_documentacion_pdf.py        # Generador automatizado del informe PDF
├── iniciar_servidor_tcp.bat            # Acceso directo para arrancar Servidor TCP
├── iniciar_simulador_serial.bat        # Acceso directo para arrancar Emisor Python
├── iniciar_visor_lazarus.bat           # Acceso directo para arrancar Visor GUI
└── iniciar_todo.bat                    # Script para arrancar todo el sistema a la vez
```

---

## 3. Guía de Ejecución Rápida

### Opción A — Ejecución Automática con un Clic:
1. Asegurarse de tener **VSPE** activo con el par **COM1 <--> COM2**.
2. Ejecutar con doble clic:
   ```cmd
   iniciar_todo.bat
   ```
   Se abrirán de forma secuencial y coordinada las tres ventanas correspondientes a cada componente.

### Opción B — Ejecución Manual Paso a Paso:
1. **Activar VSPE:** Crear o abrir el par `COM1 <--> COM2` y presionar Play.
2. **Servidor TCP Consola:** Ejecutar `iniciar_servidor_tcp.bat`. Mostrará el puerto 5000 a la escucha y creará la base de datos `sensores.db`.
3. **Visor Lazarus:** Ejecutar `iniciar_visor_lazarus.bat`. Se abrirá la ventana gráfica del visor.
4. **Simulador Serial:** Ejecutar `iniciar_simulador_serial.bat`. Comenzará la emisión periódica de muestras a 9600-8N1.
5. **HeidiSQL:** Abrir HeidiSQL, conectar a `servidor_consola/sensores.db`, abrir la tabla `Aire` y presionar F5 para ver las mediciones almacenadas en tiempo real.

---

## 4. Matriz de Cumplimiento de Requerimientos Oficiales

| Req. # | Requerimiento Oficial del PDF | Estado | Evidencia / Archivo |
| :---: | :--- | :---: | :--- |
| **1** | Visor MP 2.5 µm en Lazarus Free Pascal compilado | **CUMPLIDO** | `visor_lazarus/VisorMP25.exe` |
| **2** | Imágenes e iconos de plataforma Blackboard | **CUMPLIDO** | `camara.png`, `disk.png`, `pale.png`, `f01.bmp`, etc. |
| **3** | Componente serial `TLazSerial` instalado e integrado | **CUMPLIDO** | Carpeta `TLazSerial/` enlazada en el proyecto |
| **4** | Datos recibidos desde Python a 9600 Bps, 8N1, sampling 1s | **CUMPLIDO** | `simulador/simulador_mp25.py` |
| **5** | Rango de MP 2.5 modelado con Normal(80, 5) | **CUMPLIDO** | `random.gauss(80.0, 5.0)` en Python |
| **6** | Botón "Cámara Fotográfica" genera `captura.png` | **CUMPLIDO** | Evento `btnSaveClick` en `main_unit.pas` |
| **7** | Botón "On/Off" activa/desactiva la grilla del visor | **CUMPLIDO** | Evento `btnGridToggleClick` con cambio de glifo |
| **8** | Botón "Click" cambia la figura de fondo (background) | **CUMPLIDO** | Evento `btnChangeBgClick` cicla `img1` a `img6` |
| **9** | Título Top, SubTítulo Bottom y Hints activos en cada botón | **CUMPLIDO** | `lblMainTitle`, `BottomAxis.Title` y `ShowHint=True` |
| **10** | Componente `TChart` con serie `TLineSeries` | **CUMPLIDO** | `ChartVisor` y `SerieMP25` |
| **11** | Configuración Legend, LinePen, Marks, Frame, Pointer, etc. | **CUMPLIDO** | Línea roja, puntero azul/amarillo, marcas blancas/negras |
| **12** | Envío a Server TCP consola Lazarus y guardado en SQLite `Aire` | **CUMPLIDO** | `ServerConsola.exe` en puerto 5000 y tabla `Aire` |
| **13** | Uso de HeidiSQL para ver data en tiempo real | **CUMPLIDO** | `sensores.db` SQLite 3 nativo compatible |
| **14** | Aplicación idéntica al demo de plataforma | **CUMPLIDO** | Ventana deslizante 30 puntos (0-29) y estética oficial |
