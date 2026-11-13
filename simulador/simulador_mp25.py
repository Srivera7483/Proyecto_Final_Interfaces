"""
================================================================================
PROYECTO #3 - INTERFACES GRÁFICAS (INFO1128)
MÓDULO: SIMULADOR DE SENSOR DE MATERIAL PARTICULADO (MP 2.5 µm)
Autor: Kuro_Waza / INFO1128
Docente: Alberto Caro | Ayudante: Daniela Romero
================================================================================
Descripción:
  Este script simula un sensor de calidad de aire que mide la concentración de
  Material Particulado fino (MP 2.5 µm) y transmite las lecturas a través de
  un puerto serial configurado a 9600 Bps, 8 bits de datos, sin paridad y 1 bit
  de parada (8N1), con un intervalo de muestreo (sampling) de 1 segundo.
  
  Los valores generados siguen una Distribución Normal N(μ=80, σ=5), tal como
  lo exige el requerimiento #5 del proyecto.
================================================================================
"""

import sys
import time
import random
import argparse

try:
    import serial
except ImportError:
    print("[ERROR] El módulo 'pyserial' no está instalado.")
    print("Instálalo ejecutando: pip install pyserial")
    sys.exit(1)


def generar_muestra_mp25(media: float = 80.0, desviacion: float = 5.0, modo_demo: bool = False) -> float:
    """
    Genera un valor de concentración de MP 2.5 en ug/m3.
    Por defecto utiliza una Distribución Normal N(media, desviacion) según el punto 5
    del enunciado: Distribución Normal(80, 5).
    
    Si modo_demo es True, introduce fluctuaciones y picos similares a los vistos
    en la demostración de video para observar el comportamiento dinámico completo
    de la gráfica del TAChart (0 a 200 ug/m3).
    """
    if modo_demo:
        # En modo demo amplio para recorrer todo el rango [0 - 200]
        # manteniendo como referencia la media 80
        prob = random.random()
        if prob < 0.70:
            valor = random.gauss(80.0, 25.0)
        elif prob < 0.85:
            valor = random.uniform(130.0, 198.0) # Picos altos
        else:
            valor = random.uniform(5.0, 50.0)    # Valles bajos
    else:
        # Modo estricto según requerimiento 5: Normal(80, 5)
        valor = random.gauss(media, desviacion)
    
    # Asegurar que el valor no sea negativo ni exceda el límite del visor (200 ug/m3)
    valor = max(0.0, min(200.0, valor))
    return round(valor, 1)


def parsear_argumentos():
    """Configura los argumentos de línea de comandos para el simulador."""
    parser = argparse.ArgumentParser(
        description="Simulador de Sensor Serial MP 2.5 µm (INFO1128 - Proyecto #3)"
    )
    parser.add_argument(
        "-p", "--puerto",
        type=str,
        default="COM1",
        help="Puerto serial COM a utilizar (por defecto: COM1)"
    )
    parser.add_argument(
        "-b", "--baudios",
        type=int,
        default=9600,
        help="Velocidad en baudios (por defecto: 9600 Bps, 8N1)"
    )
    parser.add_argument(
        "-s", "--sampling",
        type=float,
        default=1.0,
        help="Intervalo de muestreo en segundos (por defecto: 1.0 s)"
    )
    parser.add_argument(
        "--media",
        type=float,
        default=80.0,
        help="Media de la distribución normal (por defecto: 80.0)"
    )
    parser.add_argument(
        "--sigma",
        type=float,
        default=5.0,
        help="Desviación estándar de la distribución normal (por defecto: 5.0)"
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Activar fluctuaciones amplias como en el video demo (0 - 200 ug/m3)"
    )
    return parser.parse_args()


def main():
    args = parsear_argumentos()

    print("=" * 70)
    print("  SIMULADOR DE MATERIAL PARTICULADO MP 2.5 µm - INFO1128")
    print("=" * 70)
    print(f" Puerto Serial       : {args.puerto}")
    print(f" Configuración      : {args.baudios} Bps, 8N1 (8 datos, Sin paridad, 1 parada)")
    print(f" Intervalo Muestreo : {args.sampling} segundo(s)")
    print(f" Modelo Estadístico : Distribución Normal({args.media}, {args.sigma})")
    print(f" Modo Demostración  : {'Activado (Rango amplio 0-200)' if args.demo else 'Normal Estricta N(80,5)'}")
    print("=" * 70)
    print("Intentando abrir el puerto serial...")

    try:
        ser = serial.Serial(
            port=args.puerto,
            baudrate=args.baudios,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        print(f"[OK] Conexión serial abierta exitosamente en {args.puerto}.")
    except serial.SerialException as err:
        print(f"\n[ERROR CRÍTICO] No se pudo abrir el puerto {args.puerto}:")
        print(f"  Detalle: {err}")
        print("\nRecomendación:")
        print("  1. Verifica que tengas configurado un par de puertos virtuales (ej: VSPE o com0com).")
        print("     Por ejemplo: COM1 <--> COM2 (Python escribe en COM1, Lazarus lee de COM2).")
        print(f"  2. Si tu par de puertos usa otro nombre, especifícalo con: python simulador_mp25.py -p COM3")
        sys.exit(1)

    muestra_id = 0
    print("\nIniciando transmisión de telemetría (Presiona Ctrl+C para finalizar)...\n")

    try:
        while True:
            # Generar muestra según distribución Normal(80, 5)
            mp25_val = generar_muestra_mp25(media=args.media, desviacion=args.sigma, modo_demo=args.demo)
            
            # Formato de transmisión serial: "82.5\r\n"
            trama = f"{mp25_val:.1f}\r\n"
            ser.write(trama.encode("ascii"))
            ser.flush()

            muestra_id += 1
            timestamp_str = time.strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{muestra_id:05d}] {timestamp_str} | MP 2.5 transmitido: {mp25_val:5.1f} ug/m3  --> [{args.puerto}]")

            time.sleep(args.sampling)

    except KeyboardInterrupt:
        print("\n\n[INFO] Simulación interrumpida por el usuario.")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print(f"[OK] Puerto serial {args.puerto} cerrado correctamente.")
        print(f"Total de muestras transmitidas: {muestra_id}")


if __name__ == "__main__":
    main()
