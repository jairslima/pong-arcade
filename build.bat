@echo off
REM ============================================================
REM build.bat - Compila Pong Arcade by Jair Lima (Harbour 3.0.0)
REM ============================================================
SET HB_PATH=C:\hb30\bin

echo Compilando Pong Arcade...
"%HB_PATH%\hbmk2.exe" pong.hbp

IF ERRORLEVEL 1 (
    echo.
    echo ERRO: Compilacao falhou!
    pause
) ELSE (
    echo.
    echo Compilacao concluida com sucesso: pong.exe
)
