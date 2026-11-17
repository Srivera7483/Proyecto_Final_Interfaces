@echo off
title Proyecto #3 - Sistema Completo INFO1128
cd /d "c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces"

echo.
echo =======================================================================
echo   ARRANCANDO SISTEMA COMPLETO PROYECTO #3 INTERFACES GRAFICAS
echo =======================================================================
echo.

echo 1. Iniciando Servidor TCP/IP Consola (Puerto 5000)...
start /b "ServidorTCP" "c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces\\servidor_consola\\ServerConsola.exe"
timeout /t 2 /nobreak >nul

echo 2. Iniciando Simulador Serial Python...
start /b "SimuladorPython" "c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces\\simulador\\simulador_mp25.py" -p COM1 -s 1.0 --media 80.0 --sigma 5.0
timeout /t 2 /nobreak >nul

echo 3. Iniciando Visor Grafico Lazarus...
start /b "VisorLazarus" "c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces\\visor_lazarus\\VisorMP25.exe"
timeout /t 2 /nobreak >nul

echo.
echo =======================================================================
echo   SISTEMA COMPLETO INICIADO CORRECTAMENTE
echo =======================================================================
echo.
echo Por favor, ejecuta el visor grafico para interactuar con el sistema.
echo Presiona cualquier tecla para continuar...
pause > nul