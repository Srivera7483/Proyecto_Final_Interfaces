@echo off
title Visor Material Particulado MP 2.5 um - INFO1128
cd /d "%~dp0visor_lazarus"
echo ======================================================================
echo    INICIANDO VISOR LAZARUS FREE PASCAL (TAChart + TLazSerial)
echo ======================================================================
powershell -Command "Start-Process -FilePath 'VisorMP25.exe' -Verb RunAs"

