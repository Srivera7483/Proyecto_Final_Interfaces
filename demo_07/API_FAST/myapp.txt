import sqlite3
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
import requests

app = FastAPI(title="Monitor Ambiental")
DB_NAME = "sensores.db"

# 1. Inicialización de la base de datos SQLite
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

# 2. Modelo de datos esperado en el JSON de entrada
class DatosAmbientales(BaseModel):
    temperatura: float
    humedad: float
    presion: float

# Endpoint POST: Recibe el JSON y lo guarda en SQLite
@app.post("/datos")
def registrar_datos(datos: DatosAmbientales):
    fecha_actual = datetime.now().strftime("%H:%M:%S")
    with sqlite3.connect(DB_NAME) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO lecturas (timestamp, temperatura, humedad, presion)
            VALUES (?, ?, ?, ?)
        """, (fecha_actual, datos.temperatura, datos.humedad, datos.presion))
        conn.commit()
    return {"status": "ok", "mensaje": "Datos guardados correctamente"}

# Endpoint GET: Lee las últimas 10 mediciones y redirige a la gráfica de QuickChart
@app.get("/grafica")
def obtener_grafica():
    with sqlite3.connect(DB_NAME) as conn:
        cursor = conn.cursor()
        # Tomamos los últimos 10 registros ordenados cronológicamente
        cursor.execute("""
            SELECT timestamp, temperatura, humedad, presion 
            FROM lecturas 
            ORDER BY id DESC LIMIT 10
        """)
        filas = cursor.fetchall()

    if not filas:
        raise HTTPException(status_code=404, detail="No hay datos registrados aún")

    # Invertimos para que el eje X vaya de pasado a presente
    filas.reverse()
    tiempos = [f[0] for f in filas]
    temps = [f[1] for f in filas]
    humedades = [f[2] for f in filas]
    presiones = [f[3] for f in filas]

    # Estructura de configuración Chart.js compatible con QuickChart
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
            "title": {"display": True, "text": "Últimas Mediciones Ambientales"},
            "scales": {
                "yAxes": [
                    {"id": "y", "position": "left"},
                    {"id": "y2", "position": "right", "gridLines": {"drawOnChartArea": False}}
                ]
            }
        }
    }

    # Solicitamos la URL corta o renderizada a la API de QuickChart
    qc_response = requests.post(
        "https://quickchart.io/chart/create",
        json={"chart": chart_config}
    )
    
    if qc_response.status_code != 200:
        raise HTTPException(status_code=500, detail="Error al generar gráfico en QuickChart")
        
    url_grafica = qc_response.json().get("url")
    
    # Redirige al navegador directamente a la imagen renderizada
    return RedirectResponse(url=url_grafica)