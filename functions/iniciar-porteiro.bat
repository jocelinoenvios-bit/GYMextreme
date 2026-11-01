@echo off
REM Inicia o porteiro da catraca do GYM XTREME.
REM Coloque um atalho deste arquivo na pasta de Inicializar do Windows (ver PORTEIRO-LOCAL.md, passo 8).
title Porteiro GYM XTREME - NAO FECHE ESTA JANELA
cd /d "%~dp0"
:inicio
node porteiro-local.js
echo O porteiro parou. Reiniciando em 5 segundos...
timeout /t 5 /nobreak >nul
goto inicio
