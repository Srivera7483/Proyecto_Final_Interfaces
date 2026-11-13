import random
import time
import requests

SERVER_URL = "http://127.0.0.1:5000/datos"

print("Iniciando envío de telemetría a Flask (Ctrl + C para detener)...")

while True:
    payload = {
        "temperatura": round(random.uniform(18.0, 26.5), 2),
        "humedad": round(random.uniform(40.0, 75.0), 2),
        "presion": round(random.uniform(1010.0, 1016.0), 2)
    }

    try:
        response = requests.post(SERVER_URL, json=payload)
        if response.status_code in (200, 201):
            print(f"[OK] Enviado: {payload}")
        else:
            print(f"[Error {response.status_code}]: {response.text}")
    except requests.exceptions.ConnectionError:
        print("[Alerta] No se puede conectar con el servidor Flask.")

    time.sleep(1)