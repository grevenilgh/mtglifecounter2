@echo off
rem Arranca la app en modo desarrollo.
rem   run.bat            en Chrome, con ventana de tamano movil
rem   run.bat android    en el movil conectado por USB (o en el emulador)
rem   run.bat android -Release
rem Con la app abierta: r = recarga en caliente, R = reinicio completo, q = salir.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run.ps1" %*
