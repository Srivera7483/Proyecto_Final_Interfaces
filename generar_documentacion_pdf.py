"""
================================================================================
SCRIPT GENERADOR DE DOCUMENTACIÓN TÉCNICA EN PDF - PROYECTO #3
Asignatura : INFO1128 - Interfaces Gráficas
Docente    : Alberto Caro | Ayudante: Daniela Romero
================================================================================
"""

import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable, Preformatted
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """Canvas de dos pasadas para numerar páginas dinámicamente 'Página X de Y'"""
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super(NumberedCanvas, self).showPage()
        super(NumberedCanvas, self).save()

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            return # Omitir encabezado y pie en portada
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#555555"))
        
        # Encabezado
        self.drawString(54, 750, "INFO1128 Interfaces Gráficas - Proyecto #3: Visor Material Particulado MP 2.5 µm")
        self.setStrokeColor(colors.HexColor("#003366"))
        self.setLineWidth(0.8)
        self.line(54, 744, 558, 744)
        
        # Pie de página
        self.setStrokeColor(colors.HexColor("#CCCCCC"))
        self.setLineWidth(0.5)
        self.line(54, 45, 558, 45)
        self.drawString(54, 32, "Universidad Católica de Temuco - Facultad de Ingeniería")
        page_str = f"Página {self._pageNumber} de {page_count}"
        self.drawRightString(558, 32, page_str)
        self.restoreState()


def generar_pdf(nombre_salida="Documentacion_Proyecto3_INFO1128.pdf"):
    doc = SimpleDocTemplate(
        nombre_salida,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    
    # Paleta de colores institucionales
    c_primario = colors.HexColor("#003366")   # Azul marino
    c_secundario = colors.HexColor("#006699") # Azul medio
    c_acento = colors.HexColor("#D9534F")     # Rojo acento
    c_fondo_bloque = colors.HexColor("#F8F9FA")
    c_borde = colors.HexColor("#DCDCDC")
    c_codigo_bg = colors.HexColor("#F4F6F8")

    # Estilos tipográficos
    estilo_portada_univ = ParagraphStyle(
        'PortUniv', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=13, leading=17,
        alignment=1, textColor=c_primario
    )
    estilo_portada_subuniv = ParagraphStyle(
        'PortSubUniv', parent=styles['Normal'],
        fontName='Helvetica', fontSize=10, leading=14,
        alignment=1, textColor=colors.HexColor("#555555")
    )
    estilo_portada_titulo = ParagraphStyle(
        'PortTitulo', parent=styles['Title'],
        fontName='Helvetica-Bold', fontSize=22, leading=26,
        alignment=1, textColor=c_primario, spaceAfter=15
    )
    estilo_portada_subtitulo = ParagraphStyle(
        'PortSubTitulo', parent=styles['Normal'],
        fontName='Helvetica', fontSize=12, leading=16,
        alignment=1, textColor=c_secundario, spaceAfter=30
    )
    estilo_h1 = ParagraphStyle(
        'H1', parent=styles['Heading1'],
        fontName='Helvetica-Bold', fontSize=15, leading=19,
        textColor=c_primario, spaceBefore=18, spaceAfter=8,
        keepWithNext=True
    )
    estilo_h2 = ParagraphStyle(
        'H2', parent=styles['Heading2'],
        fontName='Helvetica-Bold', fontSize=12, leading=16,
        textColor=c_secundario, spaceBefore=12, spaceAfter=6,
        keepWithNext=True
    )
    estilo_h3 = ParagraphStyle(
        'H3', parent=styles['Heading3'],
        fontName='Helvetica-Bold', fontSize=10, leading=14,
        textColor=colors.HexColor("#333333"), spaceBefore=8, spaceAfter=4,
        keepWithNext=True
    )
    estilo_parrafo = ParagraphStyle(
        'Parrafo', parent=styles['Normal'],
        fontName='Helvetica', fontSize=9.5, leading=13.5,
        textColor=colors.HexColor("#222222"), spaceAfter=6,
        alignment=4 # Justificado
    )
    estilo_bullet = ParagraphStyle(
        'Bullet', parent=styles['Normal'],
        fontName='Helvetica', fontSize=9, leading=13,
        textColor=colors.HexColor("#222222"), spaceAfter=3,
        leftIndent=15
    )
    estilo_codigo = ParagraphStyle(
        'Codigo', parent=styles['Normal'],
        fontName='Courier', fontSize=7.5, leading=9.5,
        textColor=colors.HexColor("#1A1A1A")
    )
    estilo_destacado = ParagraphStyle(
        'Destacado', parent=styles['Normal'],
        fontName='Helvetica-Oblique', fontSize=9, leading=13,
        textColor=c_primario
    )

    story = []

    # =========================================================================
    # PORTADA
    # =========================================================================
    story.append(Spacer(1, 40))
    story.append(Paragraph("UNIVERSIDAD CATÓLICA DE TEMUCO", estilo_portada_univ))
    story.append(Paragraph("FACULTAD DE INGENIERÍA — DEPARTAMENTO DE INGENIERÍA CIVIL INFORMÁTICA", estilo_portada_subuniv))
    story.append(Spacer(1, 40))
    story.append(HRFlowable(width="100%", thickness=3, color=c_primario, spaceBefore=0, spaceAfter=20))
    story.append(Paragraph("DOCUMENTACIÓN TÉCNICA Y MANUAL DE PROYECTO", estilo_portada_subtitulo))
    story.append(Paragraph("PROYECTO #3: VISOR DE MATERIAL PARTICULADO MP 2.5 µm", estilo_portada_titulo))
    story.append(Paragraph("Adquisición Serial 9600-8N1, Gráfica TAChart Lazarus, Cliente/Servidor TCP/IP y Persistencia SQLite", estilo_portada_subtitulo))
    story.append(HRFlowable(width="100%", thickness=1, color=c_secundario, spaceBefore=10, spaceAfter=40))

    datos_portada = [
        [Paragraph("<b>Asignatura:</b>", estilo_parrafo), Paragraph("INFO1128 — Interfaces Gráficas", estilo_parrafo)],
        [Paragraph("<b>Docente:</b>", estilo_parrafo), Paragraph("Profesor Asistente Alberto Caro (LCARO@UCT.CL)", estilo_parrafo)],
        [Paragraph("<b>Ayudante:</b>", estilo_parrafo), Paragraph("Daniela Romero", estilo_parrafo)],
        [Paragraph("<b>Alumno / Desarrollador:</b>", estilo_parrafo), Paragraph("Kuro_Waza", estilo_parrafo)],
        [Paragraph("<b>Entorno de Desarrollo:</b>", estilo_parrafo), Paragraph("Lazarus Free Pascal 3.2.2 / FPC x86_64 / Python 3.14", estilo_parrafo)],
        [Paragraph("<b>Componentes Principales:</b>", estilo_parrafo), Paragraph("TAChart, TLazSerial, Sockets TCP/IP Winsock, SQLite3", estilo_parrafo)],
        [Paragraph("<b>Fecha:</b>", estilo_parrafo), Paragraph("Noviembre 2026", estilo_parrafo)],
    ]
    t_portada = Table(datos_portada, colWidths=[150, 350])
    t_portada.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_fondo_bloque),
        ('BOX', (0,0), (-1,-1), 1, c_borde),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_portada)
    story.append(PageBreak())

    # =========================================================================
    # 1. RESUMEN GENERAL DEL PROYECTO
    # =========================================================================
    story.append(Paragraph("1. Resumen General del Proyecto", estilo_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primario, spaceBefore=2, spaceAfter=10))

    story.append(Paragraph(
        "El presente proyecto corresponde al <b>Proyecto #3 de la asignatura Interfaces Gráficas (INFO1128)</b>, "
        "dictada por el docente Alberto Caro junto a la ayudante Daniela Romero en la Universidad Católica de Temuco. "
        "El objetivo principal es el diseño, construcción y validación de una plataforma completa e integrada para el "
        "monitoreo de Material Particulado fino <b>MP 2.5 µm</b> (partículas respirables con diámetro aerodinámico "
        "inferior a 2.5 micrómetros), clave en el análisis de contaminación atmosférica.",
        estilo_parrafo
    ))
    story.append(Paragraph(
        "La arquitectura de la solución se estructura en un <b>modelo distribuido en tres capas independientes</b> pero "
        "altamente coordinadas:",
        estilo_parrafo
    ))

    story.append(Paragraph("• <b>Capa de Generación / Telemetría (Python):</b> Simula el comportamiento físico de un sensor ambiental emitiendo mediciones con un intervalo de 1 segundo (1 Hz) a través de un canal serial a 9600 Bps, 8 bits de datos, sin paridad y 1 bit de parada (8N1). Las concentraciones generadas se modelan estrictamente mediante una Distribución Normal N(μ=80, σ=5) de acuerdo al requerimiento #5 del enunciado.", estilo_bullet))
    story.append(Paragraph("• <b>Capa de Visualización e Interfaz Humano-Máquina (Visor Lazarus GUI):</b> Aplicación nativa compilada en Lazarus Free Pascal que incorpora el componente serial <code>TLazSerial</code> para la captura de las tramas del sensor, y el componente gráfico <code>TAChart</code> con serie temporal <code>TLineSeries</code> para representar una ventana deslizante de 30 muestras continuas (rango 0 a 29). Permite conmutar la grilla dinámica, rotar imágenes de fondo paisajísticas y capturar instantáneas en formato PNG.", estilo_bullet))
    story.append(Paragraph("• <b>Capa de Persistencia y Servidor de Consola (Server TCP/IP + SQLite):</b> Servicio backend en modo consola compilado en Lazarus Pascal que mantiene un socket TCP a la escucha en el puerto 5000. Recibe en tiempo real cada muestra reenviada por la interfaz gráfica, imprime la telemetría por consola con fecha y hora, y la registra de forma transaccional en la base de datos <code>sensores.db</code> dentro de la tabla <code>Aire</code>, habilitando su auditoría en tiempo real con HeidiSQL Portable.", estilo_bullet))

    story.append(Spacer(1, 8))
    story.append(Paragraph("Diagrama de Flujo y Arquitectura del Sistema:", estilo_h2))

    tabla_arquitectura = [
        [Paragraph("<b>Componente</b>", estilo_parrafo), Paragraph("<b>Tecnología</b>", estilo_parrafo), Paragraph("<b>Canal / Protocolo</b>", estilo_parrafo), Paragraph("<b>Rol en la Solución</b>", estilo_parrafo)],
        [
            Paragraph("<b>Simulador Serial</b><br/>(simulador_mp25.py)", estilo_parrafo),
            Paragraph("Python 3.14<br/>PySerial", estilo_parrafo),
            Paragraph("Virtual COM1<br/>9600-8N1 (1 Hz)", estilo_parrafo),
            Paragraph("Genera valores estocásticos Normal(80,5) y los transmite como tramas de texto ASCII.", estilo_parrafo)
        ],
        [
            Paragraph("<b>Visor Gráfico GUI</b><br/>(VisorMP25.exe)", estilo_parrafo),
            Paragraph("Lazarus 4.8 / FPC 3.2.2<br/>TAChart + TLazSerial", estilo_parrafo),
            Paragraph("Virtual COM2 (Rx)<br/>TCP Socket Client (Tx)", estilo_parrafo),
            Paragraph("Visualiza ventana deslizante de 30 datos, controla fondos, grilla, capturas y reenvía por TCP.", estilo_parrafo)
        ],
        [
            Paragraph("<b>Servidor Backend</b><br/>(ServerConsola.exe)", estilo_parrafo),
            Paragraph("Free Pascal (Modo Consola)<br/>Winsock2 + SQLite3", estilo_parrafo),
            Paragraph("TCP Server 127.0.0.1:5000<br/>SQLite Engine", estilo_parrafo),
            Paragraph("Recibe telemetría, muestra logs con timestamp e inserta registros en tabla <code>Aire</code>.", estilo_parrafo)
        ],
        [
            Paragraph("<b>Base de Datos</b><br/>(sensores.db)", estilo_parrafo),
            Paragraph("SQLite 3.51<br/>HeidiSQL 12.3", estilo_parrafo),
            Paragraph("Almacenamiento Local<br/>Transaccional ACID", estilo_parrafo),
            Paragraph("Tabla <code>Aire</code> (id, fecha, hora, mp25). Consulta concurrente en vivo.", estilo_parrafo)
        ],
    ]
    t_arq = Table(tabla_arquitectura, colWidths=[110, 110, 110, 174])
    t_arq.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EAECEE")),
        ('GRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t_arq)
    story.append(PageBreak())

    # =========================================================================
    # 2. EXPLICACIÓN BLOQUE POR BLOQUE
    # =========================================================================
    story.append(Paragraph("2. Explicación Bloque por Bloque", estilo_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primario, spaceBefore=2, spaceAfter=10))

    story.append(Paragraph("2.1 Bloque 1: Simulador Serial de Material Particulado en Python", estilo_h2))
    story.append(Paragraph(
        "El módulo <code>simulador_mp25.py</code> actúa como el emulador del hardware sensor. "
        "Abre el puerto serial <b>COM1</b> mediante la librería <code>pyserial</code> configurado a <b>9600 Baudios, "
        "8 bits de datos, sin paridad y 1 bit de parada (8N1)</b>. En un ciclo infinito sincronizado con <code>time.sleep(1.0)</code>, "
        "calcula una nueva muestra empleando la función <code>random.gauss(80.0, 5.0)</code>, modelando exactamente la "
        "distribución normal N(80,5) exigida. El valor se formatea como cadena de caracteres terminada en retorno de carro "
        "y salto de línea (<code>\\r\\n</code>), siendo transmitido al par virtual.",
        estilo_parrafo
    ))

    story.append(Paragraph("2.2 Bloque 2: Servidor TCP/IP en Modo Consola con SQLite", estilo_h2))
    story.append(Paragraph(
        "El servidor <code>ServerConsola.lpr</code> es una aplicación de terminal compilada con Free Pascal. "
        "Su responsabilidad es doble: actúa como receptor de telemetría TCP/IP y como motor de persistencia de datos. "
        "Al iniciar, carga dinámicamente la biblioteca <code>sqlite3.dll</code>, se conecta al archivo <code>sensores.db</code> "
        "y ejecuta la instrucción DDL <code>CREATE TABLE IF NOT EXISTS Aire (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, hora TEXT, mp25 REAL);</code>. "
        "Posteriormente, crea un socket TCP con la API nativa de Winsock2 y se coloca a la escucha (<code>listen</code>) en el puerto 5000. "
        "Cada vez que un cliente se conecta, lee el valor de MP 2.5, obtiene la fecha (<code>YYYY-MM-DD</code>) y la hora actual (<code>HH:NN:SS</code>), "
        "imprime la línea de telemetría por consola y realiza un <code>INSERT</code> transaccional con <code>Commit</code>.",
        estilo_parrafo
    ))

    story.append(Paragraph("2.3 Bloque 3: Visor Gráfico en Lazarus Free Pascal (LCL)", estilo_h2))
    story.append(Paragraph(
        "La interfaz gráfica <code>VisorMP25.exe</code> (definida en <code>main_unit.pas</code> y <code>main_unit.lfm</code>) "
        "reproduce fielmente el aspecto y funcionamiento demostrado en la pauta y video del proyecto:",
        estilo_parrafo
    ))
    story.append(Paragraph("• <b>Encabezado y Título Principal:</b> En la parte superior luce el título principal centrado <i>'Material Particulado 2.5 um'</i> en negrita, acompañado por los botones de acción.", estilo_bullet))
    story.append(Paragraph("• <b>Subtítulo Inferior:</b> El eje inferior horizontal rotula el subtítulo <i>'Sampling MP 2.5um'</i>.", estilo_bullet))
    story.append(Paragraph("• <b>Componente TAChart y TLineSeries:</b> Muestra una ventana rodante continua de 30 puntos (índices 0 al 29). El eje Y representa <code>[ug/m3]</code> en el intervalo de 0 a 200. La serie presenta línea roja (<code>clRed</code>), puntero cuadrado azul con borde amarillo (<code>Pointer</code>) y etiquetas rectangulares blancas con contorno negro (<code>Marks</code>) que indican el valor exacto sobre cada punto.", estilo_bullet))
    story.append(Paragraph("• <b>Renderizado Dinámico de Fondos e Icono AC:</b> En el evento <code>OnBeforeDrawBackWall</code>, el visor dibuja la imagen de fondo estirada (<code>StretchDraw</code>) seleccionada de entre los recursos (<code>img1.png</code> a <code>img6.png</code>), además de estampar el icono del disquete (<code>disk.png</code>) con el monograma 'AC' en la esquina superior izquierda del lienzo.", estilo_bullet))
    story.append(Paragraph("• <b>Botón 'Save' (Cámara Fotográfica):</b> Provisto del icono <code>camara.png</code> y propiedad <code>Hint</code> activada. Al pulsarlo, vuelca el mapa de bits del formulario en un archivo <code>captura.png</code>.", estilo_bullet))
    story.append(Paragraph("• <b>Botón 'On/off' (Conmutador de Grilla):</b> Provisto de los glifos <code>f01.bmp</code> y <code>f02.bmp</code> y <code>Hint</code> descriptivo. Alterna la visibilidad de la cuadrícula punteada en ambos ejes.", estilo_bullet))
    story.append(Paragraph("• <b>Botón 'Click' (Paleta de Fondos):</b> Provisto del icono <code>pale.png</code> y <code>Hint</code>. Rota secuencialmente las imágenes de fondo del gráfico.", estilo_bullet))
    story.append(Paragraph("• <b>Componente TLazSerial:</b> Enlaza con <code>COM2</code> a 9600-8N1 para captar las lecturas en el evento <code>OnRxData</code>.", estilo_bullet))
    story.append(Paragraph("• <b>Cliente TCP Winsock:</b> Cada muestra válida recibida es transmitida en milisegundos mediante un socket TCP hacia <code>127.0.0.1:5000</code>.", estilo_bullet))

    story.append(Paragraph("2.4 Bloque 4: Canal Serial Virtual (VSPE)", estilo_h2))
    story.append(Paragraph(
        "Para comunicar el script de Python y la interfaz gráfica sin depender de hardware físico, se emplea el software "
        "<b>Virtual Serial Port Emulator (VSPE)</b>, creando un dispositivo de tipo <b>Pair</b> que interconecta <b>COM1</b> "
        "con <b>COM2</b>. Lo emitido por Python en COM1 es recibido de inmediato por TLazSerial en COM2.",
        estilo_parrafo
    ))

    story.append(Paragraph("2.5 Bloque 5: Auditoría y Visualización con HeidiSQL", estilo_h2))
    story.append(Paragraph(
        "Al utilizar SQLite como motor embebido, el archivo <code>sensores.db</code> puede ser abierto concurrentemente por "
        "<b>HeidiSQL Portable</b>. Al seleccionar la base de datos y la tabla <code>Aire</code>, el usuario puede ejecutar consultas "
        "o presionar F5 para comprobar en vivo la inserción de tuplas <code>(id, fecha, hora, mp25)</code> segundo a segundo.",
        estilo_parrafo
    ))
    story.append(PageBreak())

    # =========================================================================
    # 3. DOCUMENTACIÓN EXPLICADA LÍNEA POR LÍNEA DE CÓDIGOS IMPORTANTES
    # =========================================================================
    story.append(Paragraph("3. Documentación Explicada Línea por Línea", estilo_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primario, spaceBefore=2, spaceAfter=10))

    story.append(Paragraph("3.1 Código: simulador_mp25.py (Emisor Serial Python)", estilo_h2))
    story.append(Paragraph(
        "A continuación se documenta la lógica y el propósito técnico de cada sección clave del script de simulación:",
        estilo_parrafo
    ))

    lineas_python = [
        ("import sys, time, random, argparse", "Importa módulos estándar para control de sistema, temporización, generación estocástica y procesamiento de argumentos CLI."),
        ("try: import serial except ImportError:", "Intenta importar PySerial; si no está instalado, notifica al usuario con el comando pip correspondiente y aborta."),
        ("def generar_muestra_mp25(media=80.0, desviacion=5.0):", "Función generadora del valor de Material Particulado MP 2.5 µm."),
        ("    valor = random.gauss(media, desviacion)", "Aplica la función Gaussiana para obtener una variable aleatoria con Distribución Normal N(μ=80, σ=5) estricta (Punto 5)."),
        ("    valor = max(0.0, min(200.0, valor))", "Acota el valor al rango operacional válido de la interfaz gráfica [0.0 - 200.0 ug/m3]."),
        ("    return round(valor, 1)", "Redondea la lectura a un decimal de precisión para su transmisión."),
        ("ser = serial.Serial(port='COM1', baudrate=9600, ...)", "Instancia y abre la conexión serial en COM1 a 9600 Baudios, 8 bits de datos, sin paridad y 1 bit de parada (8N1)."),
        ("while True:", "Bucle infinito de adquisición y emisión continua de telemetría."),
        ("    mp25_val = generar_muestra_mp25()", "Calcula la muestra estocástica correspondiente al segundo actual."),
        ("    trama = f'{mp25_val:.1f}\\r\\n'", "Estructura la trama de texto delimitada por retorno de carro y salto de línea."),
        ("    ser.write(trama.encode('ascii'))", "Codifica la trama a bytes ASCII y la escribe en el buffer de transmisión serial."),
        ("    ser.flush()", "Fuerza la descarga inmediata de los bytes por el canal de hardware virtual."),
        ("    time.sleep(args.sampling)", "Pausa la ejecución durante exactamente 1.0 segundo (frecuencia de muestreo de 1 Hz)."),
    ]

    t_py = Table(
        [[Paragraph(f"<b>Línea / Bloque</b>", estilo_destacado), Paragraph("<b>Explicación Lógica Detallada</b>", estilo_destacado)]] +
        [[Paragraph(f"<code>{cod}</code>", estilo_codigo), Paragraph(exp, estilo_parrafo)] for cod, exp in lineas_python],
        colWidths=[200, 304]
    )
    t_py.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EAECEE")),
        ('GRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t_py)
    story.append(Spacer(1, 14))

    story.append(Paragraph("3.2 Código: ServerConsola.lpr (Servidor TCP/IP + SQLite)", estilo_h2))
    story.append(Paragraph(
        "A continuación se detalla la lógica de inicialización del motor SQLite, la creación de sockets Winsock y el bucle de persistencia:",
        estilo_parrafo
    ))

    lineas_server = [
        ("uses SysUtils, Classes, sqlite3conn, sqldb, WinSock2;", "Carga las unidades del sistema, componentes FCL de bases de datos SQLite y la API de red Winsock2."),
        ("Conn := TSQLite3Connection.Create(nil);", "Instancia la conexión nativa a SQLite de Free Pascal."),
        ("Conn.DatabaseName := 'sensores.db';", "Asigna el nombre del archivo de base de datos relacional persistente."),
        ("Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS Aire (...);'", "Define el esquema relacional con id autonumérico, fecha TEXT, hora TEXT y mp25 REAL (Punto 12)."),
        ("Query.ExecSQL; Trans.Commit;", "Ejecuta la instrucción DDL y consolida la transacción atómica en disco."),
        ("WSAStartup(MAKEWORD(2, 2), wsaData);", "Inicializa la pila de red de Windows Sockets en su versión 2.2."),
        ("serverSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);", "Crea el socket del servidor orientado a conexión mediante protocolo TCP sobre IPv4."),
        ("bind(serverSocket, @serverAddr, SizeOf(serverAddr));", "Asocia el socket a todas las interfaces locales (INADDR_ANY) en el puerto TCP 5000."),
        ("listen(serverSocket, SOMAXCONN);", "Coloca el socket en modo de escucha pasiva esperando peticiones de clientes."),
        ("clientSocket := accept(serverSocket, @clientAddr, ...);", "Acepta la conexión entrante de la interfaz gráfica Visor Lazarus y genera un socket dedicado."),
        ("bytesReceived := recv(clientSocket, buffer, BUFFER_SIZE - 1, 0);", "Lee los datos de telemetría enviados por la interfaz gráfica."),
        ("TryStrToFloat(cleanValStr, mp25Val);", "Convierte la cadena numérica recibida a coma flotante de doble precisión."),
        ("WriteLn(Format('[%05d] %s %s | MP 2.5: %6.1f', ...));", "Imprime la lectura por la consola de texto en tiempo real con timestamp (Punto 12)."),
        ("GuardarLectura(fechaStr, horaStr, mp25Val);", "Inserta la tupla en la tabla Aire con fecha, hora y concentración de MP 2.5."),
        ("send(clientSocket, PAnsiChar('ACK_OK\\n'), ...);", "Transmite un acuse de recibo ACK confirmando el almacenamiento exitoso al cliente."),
        ("closesocket(clientSocket);", "Cierra la conexión transaccional liberando los recursos del cliente."),
    ]

    t_srv = Table(
        [[Paragraph(f"<b>Línea / Bloque</b>", estilo_destacado), Paragraph("<b>Explicación Lógica Detallada</b>", estilo_destacado)]] +
        [[Paragraph(f"<code>{cod}</code>", estilo_codigo), Paragraph(exp, estilo_parrafo)] for cod, exp in lineas_server],
        colWidths=[200, 304]
    )
    t_srv.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EAECEE")),
        ('GRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t_srv)
    story.append(PageBreak())

    story.append(Paragraph("3.3 Código: main_unit.pas (Visor Gráfico Lazarus LCL)", estilo_h2))
    story.append(Paragraph(
        "A continuación se desglosan las rutinas de visualización, gestión de eventos gráficos, manejo serial y envío TCP:",
        estilo_parrafo
    ))

    lineas_visor = [
        ("ChartVisor.LeftAxis.Range.Max := 200;", "Fija la escala máxima del eje vertical de concentración en 200 ug/m3."),
        ("ChartVisor.BottomAxis.Range.Max := 29;", "Establece el límite horizontal para exactamente 30 puntos de muestreo (0 a 29)."),
        ("SerieMP25.LinePen.Color := clRed; Width := 1;", "Configura la propiedad LinePen con trazo de color rojo sólido de 1 pixel (Puntos 10 y 11)."),
        ("SerieMP25.Pointer.Style := psRectangle; Color := clHighlight;", "Configura los punteros como rectángulos azules con borde amarillo (Pointer)."),
        ("SerieMP25.Marks.Style := smsValue; Format := '%0:.0f';", "Activa las marcas numéricas (Marks) para exhibir el valor entero sobre cada punto."),
        ("SerieMP25.Marks.LabelBrush.Color := clWhite; Frame := clBlack;", "Asigna fondo blanco y marco negro a la etiqueta de cada marca."),
        ("ChartVisorBeforeDrawBackWall(ASender, ARect);", "Evento disparado antes de dibujar el gráfico; dibuja el fondo paisajístico y el logo disquete AC."),
        ("ASender.Canvas.StretchDraw(ARect, FBackgrounds[FCurrentBgIndex]);", "Estira la imagen PNG de fondo activa sobre el área del backwall del gráfico."),
        ("ASender.Canvas.Draw(ARect.Left + 12, ARect.Top + 8, FDiskBmp);", "Dibuja el logotipo del disquete (disk.png) en la esquina superior izquierda del visor."),
        ("btnGridToggleClick: isGridOn := not ChartVisor.LeftAxis.Grid.Visible;", "Conmuta la visibilidad de la cuadrícula en ambos ejes al presionar 'On/off' (Punto 7)."),
        ("btnChangeBgClick: FCurrentBgIndex := (FCurrentBgIndex + 1) mod 6;", "Alterna de forma cíclica entre las 6 imágenes de fondo disponibles al presionar 'Click' (Punto 8)."),
        ("btnSaveClick: Self.PaintTo(Bmp.Canvas, 0, 0); Png.SaveToFile('captura.png');", "Captura el formulario en mapa de bits y lo guarda en captura.png (Punto 6)."),
        ("LazSerial1RxData: rawStr := LazSerial1.ReadData;", "Lee los caracteres recibidos por el puerto serial COM2 desde el simulador Python (Punto 4)."),
        ("AgregarMuestra: for i:=0 to TOTAL_MUESTRAS-2 do FMuestras[i]:=FMuestras[i+1];", "Implementa la ventana deslizante desplazando los valores a la izquierda e insertando el nuevo en 29."),
        ("SerieMP25.AddXY(i, FMuestras[i]);", "Carga las coordenadas X, Y en la serie del TChart y actualiza la visualización."),
        ("EnviarATcpServer(AValor);", "Abre un socket cliente hacia 127.0.0.1:5000 y envía el dato de MP 2.5 al servidor de consola (Punto 12)."),
    ]

    t_vis = Table(
        [[Paragraph(f"<b>Línea / Bloque</b>", estilo_destacado), Paragraph("<b>Explicación Lógica Detallada</b>", estilo_destacado)]] +
        [[Paragraph(f"<code>{cod}</code>", estilo_codigo), Paragraph(exp, estilo_parrafo)] for cod, exp in lineas_visor],
        colWidths=[210, 294]
    )
    t_vis.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EAECEE")),
        ('GRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t_vis)
    story.append(PageBreak())

    # =========================================================================
    # 4. GUÍA DE COMPILACIÓN, EJECUCIÓN Y PRUEBAS PASO A PASO
    # =========================================================================
    story.append(Paragraph("4. Guía de Ejecución y Pruebas Paso a Paso", estilo_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primario, spaceBefore=2, spaceAfter=10))

    story.append(Paragraph(
        "Para ejecutar el sistema completo de forma coordinada, siga el procedimiento ordenado que se detalla a continuación:",
        estilo_parrafo
    ))

    pasos = [
        ("PASO 1: Iniciar Virtual Serial Port Emulator (VSPE)", 
         "Abrir VSPE, cargar la configuración o crear un dispositivo de tipo 'Pair' con COM1 y COM2. Presionar el botón de inicio (Play). Esto habilitará el puente de comunicación serial virtual entre Python y Lazarus."),
        ("PASO 2: Iniciar el Servidor TCP/IP en Modo Consola", 
         "Doble clic sobre el archivo <code>iniciar_servidor_tcp.bat</code> (o ejecutar <code>servidor_consola\\ServerConsola.exe</code>). "
         "La consola mostrará: <i>'[SQLITE] Tabla \"Aire\" verificada/creada exitosamente'</i> y <i>'[TCP] Servidor a la escucha en el puerto 5000...'</i>."),
        ("PASO 3: Iniciar el Visor Gráfico en Lazarus", 
         "Doble clic sobre <code>iniciar_visor_lazarus.bat</code> (o abrir <code>visor_lazarus\\VisorMP25.exe</code>). "
         "Se desplegará la interfaz con el fondo de paisaje, el disquete AC en la esquina superior izquierda, los títulos superior e inferior, la leyenda a la derecha y los botones Save, On/off y Click."),
        ("PASO 4: Iniciar el Simulador Serial en Python", 
         "Doble clic sobre <code>iniciar_simulador_serial.bat</code> (o ejecutar <code>python simulador\\simulador_mp25.py -p COM1</code>). "
         "Comenzará el envío de valores de MP 2.5 a 9600 Bps a un intervalo de 1 segundo con Distribución Normal N(80,5)."),
        ("PASO 5: Verificación de la Gráfica y Reenvío en Tiempo Real", 
         "En el Visor Lazarus, observe cómo la línea roja avanza punto por punto mostrando las marcas sobre cada puntero cuadrado azul. "
         "Simultáneamente, la consola del servidor TCP mostrará las lecturas entrantes y las insertará en SQLite."),
        ("PASO 6: Prueba de Funcionalidades Interactivas", 
         "• Presione <b>'On/off'</b>: La grilla del gráfico aparecerá y desaparecerá alternadamente.<br/>"
         "• Presione <b>'Click'</b>: La imagen de fondo del visor rotará secuencialmente entre los paisajes.<br/>"
         "• Presione <b>'Save'</b>: Se generará la captura de la pantalla en el archivo <code>captura.png</code>.<br/>"
         "• Pase el cursor sobre cada botón para confirmar la activación de los <b>Hints</b>."),
        ("PASO 7: Comprobación con HeidiSQL Portable", 
         "Abra HeidiSQL Portable, abra la base de datos <code>servidor_consola\\sensores.db</code>, seleccione la tabla <code>Aire</code> y pulse F5 para comprobar en vivo los registros de <code>id, fecha, hora, mp25</code>."),
        ("MÉTODO RÁPIDO AUTOMÁTICO", 
         "Puede iniciar los tres componentes en ventanas independientes con un solo clic ejecutando: <code>iniciar_todo.bat</code>."),
    ]

    for titulo, desc in pasos:
        story.append(Paragraph(f"<b>{titulo}</b>", estilo_h3))
        story.append(Paragraph(desc, estilo_parrafo))

    story.append(Spacer(1, 10))
    story.append(Paragraph("5. Matriz de Cumplimiento de Requerimientos Oficiales", estilo_h1))
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primario, spaceBefore=2, spaceAfter=10))

    checklist = [
        ("Req. #", "Requerimiento Oficial (PDF)", "Estado", "Módulo / Implementación"),
        ("1", "Visor de Material Particulado MP 2.5 um en Lazarus Free Pascal con código compilado.", "CUMPLIDO", "VisorMP25.exe compilado con lazbuild en FPC 3.2.2 x86_64."),
        ("2", "Utilizar imágenes e iconos de Blackboard.", "CUMPLIDO", "Incorporados: camara.png, disk.png, pale.png, f01.bmp, f02.bmp, img1..6."),
        ("3", "Componente serial LazSerial instalado desde IDE / OPM.", "CUMPLIDO", "Paquete TLazSerial integrado en el árbol del proyecto."),
        ("4", "Datos recibidos desde script Python a 9600 Bps, 8N1 a sampling de 1 segundo.", "CUMPLIDO", "simulador_mp25.py emite a 9600-8N1 cada 1.0s hacia COM1."),
        ("5", "Valores de MP 2.5 modelados con Distribución Normal(80,5).", "CUMPLIDO", "Implementado con random.gauss(80.0, 5.0) en simulador_mp25.py."),
        ("6", "Botón 'Cámara Fotográfica' realiza captura a captura.png.", "CUMPLIDO", "btnSave con icono camara.png exporta captura a captura.png."),
        ("7", "Botón 'On/Off' activa y desactiva la grilla del visor.", "CUMPLIDO", "btnGridToggle conmuta Grid.Visible de ambos ejes y glifos f01/f02."),
        ("8", "Botón 'Click' cambia la figura de fondo del visor.", "CUMPLIDO", "btnChangeBg con icono pale.png rota fondos img1.png .. img6.png."),
        ("9", "Título principal (Top), SubTítulo (Bottom) y activación de Hint en cada botón.", "CUMPLIDO", "Top: 'Material Particulado 2.5 um', Bottom: 'Sampling MP 2.5um', Hints activos."),
        ("10", "Componente TChart con serie TLineSeries.", "CUMPLIDO", "ChartVisor (TChart) con SerieMP25 (TLineSeries)."),
        ("11", "Configurar Legend, LinePen, Marks, Frame, LabelBrush, Style, Pointer, SeriesColor.", "CUMPLIDO", "Todas las propiedades estilísticas configuradas según diseño oficial."),
        ("12", "Enviar MP25 a Server TCP/IP Lazarus modo consola que guarde en SQLite Tabla Aire.", "CUMPLIDO", "ServerConsola.exe escucha en TCP 5000 y almacena en tabla Aire (fecha, hora, mp25)."),
        ("13", "Utilizar HeidiSQL Portable para verificar la data en tiempo real.", "CUMPLIDO", "Base de datos sensores.db con bloqueo concurrente apta para HeidiSQL."),
        ("14", "Aplicación similar al demo de plataforma.", "CUMPLIDO", "Ventana deslizante de 30 puntos, proporciones, paleta y disposición idénticas al demo."),
    ]

    t_check = Table(
        [[Paragraph(f"<b>{c[0]}</b>", estilo_destacado), Paragraph(f"<b>{c[1]}</b>", estilo_destacado), Paragraph(f"<b>{c[2]}</b>", estilo_destacado), Paragraph(f"<b>{c[3]}</b>", estilo_destacado)] for c in [checklist[0]]] +
        [[Paragraph(c[0], estilo_parrafo), Paragraph(c[1], estilo_parrafo), Paragraph(f"<font color='green'><b>{c[2]}</b></font>", estilo_parrafo), Paragraph(c[3], estilo_parrafo)] for c in checklist[1:]],
        colWidths=[45, 175, 74, 210]
    )
    t_check.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EAECEE")),
        ('GRID', (0,0), (-1,-1), 0.5, c_borde),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]))
    story.append(t_check)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[OK] Documento PDF generado exitosamente: {nombre_salida}")

if __name__ == "__main__":
    generar_pdf()

