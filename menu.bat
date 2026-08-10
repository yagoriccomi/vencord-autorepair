@echo off
REM Vencord Auto-Repair - menu
REM Copyright (C) 2026 yagoriccomi
REM
REM This program is free software: you can redistribute it and/or modify
REM it under the terms of the GNU General Public License as published by
REM the Free Software Foundation, either version 3 of the License, or
REM (at your option) any later version.
REM
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM GNU General Public License for more details.
REM
REM You should have received a copy of the GNU General Public License
REM along with this program.  If not, see <https://www.gnu.org/licenses/>.
title Vencord Auto-Repair
set "SCRIPTS=%~dp0scripts"
set "INSTALL=%USERPROFILE%\Vencord"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File"

:menu
cls
echo ==================================================
echo               VENCORD AUTO-REPAIR
echo ==================================================
echo.
echo   --- USAR ---
echo   [1]  Instalar Vencord + auto-reparo
echo   [2]  Ver status
echo   [3]  Aplicar / reparar o Vencord agora
echo   [4]  Abrir o Discord
echo.
echo   --- AJUSTES ---
echo   [5]  Ligar/desligar aviso quando DER CERTO
echo   [6]  Ligar/desligar pergunta antes de fechar o Discord
echo   [7]  Ligar/desligar reabrir o Discord sozinho
echo   [8]  Destravar auto-reparo (zerar quarentena)
echo.
echo   --- MANUTENCAO ---
echo   [9]  Ver log do vigia
echo   [10] Reinstalar a tarefa agendada
echo   [11] Desligar auto-reparo (remove a tarefa)
echo   [12] Desinstalar TUDO (tarefa + Vencord do Discord)
echo.
echo   [0]  Sair
echo.
set "op="
set /p "op=Escolha uma opcao: "

if "%op%"=="1"  goto install
if "%op%"=="2"  goto status
if "%op%"=="3"  goto repair
if "%op%"=="4"  goto opendiscord
if "%op%"=="5"  goto cfgsucesso
if "%op%"=="6"  goto cfgaviso
if "%op%"=="7"  goto cfgreabrir
if "%op%"=="8"  goto destravar
if "%op%"=="9"  goto log
if "%op%"=="10" goto regtask
if "%op%"=="11" goto uninstall
if "%op%"=="12" goto purge
if "%op%"=="0"  goto end
goto menu

:install
echo.
%PS% "%SCRIPTS%\install.ps1"
pause
goto menu

:status
echo.
%PS% "%SCRIPTS%\status.ps1"
pause
goto menu

:repair
echo.
if exist "%INSTALL%\vencord-watch.ps1" (
  echo Verificando e aplicando se precisar...
  echo O Discord sera fechado e reaberto se for necessario.
  %PS% "%INSTALL%\vencord-watch.ps1" -Once -Force
  echo.
  echo Concluido. Veja o log (opcao 9) para os detalhes.
) else (
  echo Projeto ainda nao instalado. Use a opcao [1] primeiro.
)
pause
goto menu

:opendiscord
echo.
if exist "%LOCALAPPDATA%\Discord\Update.exe" (
  start "" "%LOCALAPPDATA%\Discord\Update.exe" --processStart Discord.exe
  echo Discord aberto.
) else (
  echo Discord nao encontrado.
)
timeout /t 2 >nul
goto menu

:cfgsucesso
echo.
%PS% "%SCRIPTS%\config.ps1" -Action sucesso
pause
goto menu

:cfgaviso
echo.
%PS% "%SCRIPTS%\config.ps1" -Action aviso
pause
goto menu

:cfgreabrir
echo.
%PS% "%SCRIPTS%\config.ps1" -Action reabrir
pause
goto menu

:destravar
echo.
%PS% "%SCRIPTS%\config.ps1" -Action resetar
pause
goto menu

:log
echo.
if exist "%INSTALL%\watch.log" (
  powershell -NoProfile -Command "Get-Content '%INSTALL%\watch.log' -Tail 30"
) else (
  echo Nenhum log ainda.
)
pause
goto menu

:regtask
echo.
%PS% "%SCRIPTS%\register-task.ps1"
pause
goto menu

:uninstall
echo.
%PS% "%SCRIPTS%\uninstall.ps1"
pause
goto menu

:purge
echo.
echo Isso vai remover a tarefa E o Vencord do Discord.
set "c="
set /p "c=Tem certeza? (S/N): "
if /I "%c%"=="S" (
  %PS% "%SCRIPTS%\uninstall.ps1" -RemoveVencord -Purge
)
pause
goto menu

:end
