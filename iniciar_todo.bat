@echo off
title Sistema Completo - Proyecto #3 INFO1128
echo ======================================================================
echo    ARRANCANDO SISTEMA COMPLETO PROYECTO #3 INTERFACES GRAFICAS
echo ======================================================================
echo 1. Iniciando Servidor TCP/IP Lazarus Modo Consola (Puerto 5000)...
start "Servidor TCP Consola" cmd /k "%~dp0iniciar_servidor_tcp.bat"

ping 127.0.0.1 -n 3 >nul

echo 2. Iniciando Visor Grafico Lazarus Free Pascal...
start "Visor Lazarus" cmd /k "%~dp0iniciar_visor_lazarus.bat"

ping 127.0.0.1 -n 3 >nul

echo 3. Iniciando Simulador Serial Python en COM1 (Normal(80,5), 9600-8N1)...
start "Simulador Python" cmd /k "%~dp0iniciar_simulador_serial.bat"

echo ======================================================================
echo    TODO EL SISTEMA HA SIDO INICIADO SATISFACTORIAMENTE
echo ======================================================================

