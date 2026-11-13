import sqlite3
from datetime import datetime
from flask import Flask, request, jsonify, redirect, abort
import requests

app = Flask(__name__)
DB_NAME = "sensores.db"

# 1. Inicialización de la base de datos SQLite local
def init_db():
    with sqlite3.connect(DB_NAME) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS lecturas (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                temperatura REAL,
                humedad REAL,
                presion REAL
            )
        """)
        conn.commit()

init_db()

# Endpoint POST: Recibe el payload JSON y lo almacena en SQLite
@app.route("/datos", methods=["POST"])
def registrar_datos():
    datos = request.get_json(silent=True)
    
    # Validación básica de estructura para los estudiantes
    if not datos or not all(k in datos for k in ("temperatura", "humedad", "presion")):
        return jsonify({"status": "error", "mensaje": "JSON malformado o campos faltantes"}), 400

    fecha_actual = datetime.now().strftime("%H:%M:%S")

    with sqlite3.connect(DB_NAME) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO lecturas (timestamp, temperatura, humedad, presion)
            VALUES (?, ?, ?, ?)
        """, (
            fecha_actual, 
            float(datos["temperatura"]), 
            float(datos["humedad"]), 
            float(datos["presion"])
        ))
        conn.commit()

    return jsonify({"status": "ok", "mensaje": "Datos guardados correctamente"}), 201

# Endpoint GET: Consulta las últimas 10 lecturas y redirige a QuickChart
@app.route("/grafica", methods=["GET"])
def obtener_grafica():
    with sqlite3.connect(DB_NAME) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT timestamp, temperatura, humedad, presion 
            FROM lecturas 
            ORDER BY id DESC LIMIT 10
        """)
        filas = cursor.fetchall()

    if not filas:
        return jsonify({"error": "No hay datos registrados aún"}), 404

    # Invertir para orden cronológico en el eje temporal
    filas.reverse()
    tiempos = [f[0] for f in filas]
    temps = [f[1] for f in filas]
    humedades = [f[2] for f in filas]
    presiones = [f[3] for f in filas]

    # Configuración de Chart.js enviada a QuickChart
    chart_config = {
        "type": "line",
        "data": {
            "labels": tiempos,
            "datasets": [
                {"label": "Temp (°C)", "data": temps, "borderColor": "red", "fill": False},
                {"label": "Humedad (%)", "data": humedades, "borderColor": "blue", "fill": False},
                {"label": "Presión (hPa)", "data": presiones, "borderColor": "green", "fill": False, "yAxisID": "y2"}
            ]
        },
        "options": {
            "title": {"display": True, "text": "Últimas Mediciones Ambientales (Flask)"},
            "scales": {
                "yAxes": [
                    {"id": "y", "position": "left"},
                    {"id": "y2", "position": "right", "gridLines": {"drawOnChartArea": False}}
                ]
            }
        }
    }

    qc_response = requests.post(
        "https://quickchart.io/chart/create",
        json={"chart": chart_config}
    )
    
    if qc_response.status_code != 200:
        return jsonify({"error": "Error al conectar con la API de QuickChart"}), 502

    url_grafica = qc_response.json().get("url")
    return redirect(url_grafica, code=302)

if __name__ == "__main__":
    # Flask corre por defecto en el puerto 5000
    app.run(host="127.0.0.1", port=5000, debug=True)