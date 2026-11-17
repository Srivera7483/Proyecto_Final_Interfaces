@echo off
cd /d "c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces\\servidor_consola"
"c:\\Users\\Kuro_Waza\\Documents\\GitHub\\Proyecto_Final_Interfaces\\servidor_consola\\ServerConsola.exe" > servidor.log 2>&1
echo Server started, checking log...
timeout /t 5 /nobreak >nul