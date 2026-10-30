@echo off
rem Igual que setup.bat pero instala tambien el SDK de Android para probar en el movil por USB.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" -Android %*
pause
