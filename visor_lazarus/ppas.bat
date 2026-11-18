@echo off
SET THEFILE=C:\Users\Kuro_Waza\Documents\GitHub\Proyecto_Final_Interfaces\visor_lazarus\VisorMP25.exe
echo Linking %THEFILE%
C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ld.exe -b pei-x86-64  --gc-sections   --subsystem windows --entry=_WinMainCRTStartup    -o C:\Users\Kuro_Waza\Documents\GitHub\Proyecto_Final_Interfaces\visor_lazarus\VisorMP25.exe C:\Users\Kuro_Waza\Documents\GitHub\Proyecto_Final_Interfaces\visor_lazarus\link7540.res
if errorlevel 1 goto linkend
goto end
:asmend
echo An error occurred while assembling %THEFILE%
goto end
:linkend
echo An error occurred while linking %THEFILE%
:end
