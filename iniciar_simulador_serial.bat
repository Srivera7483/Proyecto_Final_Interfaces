@echo off
title Simulador Serial MP 2.5 um - INFO1128
cd /d "%~dp0simulador"
echo ======================================================================
echo    INICIANDO SIMULADOR SERIAL PYTHON (9600-8N1, SAMPLING 1s, N(80,5))
echo ======================================================================
python simulador_mp25.py -p COM1 -s 1.0 --media 80.0 --sigma 5.0
pause

