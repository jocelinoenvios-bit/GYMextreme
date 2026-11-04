@echo off
REM Abre o GYM XTREME (versao Web) no navegador deste computador.
REM Deixe a janela preta aberta enquanto usa o app; feche-a para encerrar.
title GYM XTREME
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor-local.ps1"
if errorlevel 1 pause
