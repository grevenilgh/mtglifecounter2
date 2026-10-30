@echo off
rem Prepara el entorno de desarrollo (Git + Flutter + dependencias) para probar en Chrome.
rem Opciones: setup.bat -Android   (ademas SDK de Android para probar en el movil y generar el APK)
rem           setup.bat -Emulator  (ademas crea un emulador de Android)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" %*
pause
