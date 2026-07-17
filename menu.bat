@echo off
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
echo   [1]  Instalar Vencord + auto-reparo
echo   [2]  Ver status
echo   [3]  Reparar / reaplicar Vencord agora
echo   [4]  Ver log do vigia
echo   [5]  Reinstalar a tarefa agendada
echo   [6]  Desligar auto-reparo (remove a tarefa)
echo   [7]  Desinstalar TUDO (tarefa + Vencord do Discord)
echo   [0]  Sair
echo.
set /p "op=Escolha uma opcao: "

if "%op%"=="1" goto install
if "%op%"=="2" goto status
if "%op%"=="3" goto repair
if "%op%"=="4" goto log
if "%op%"=="5" goto regtask
if "%op%"=="6" goto uninstall
if "%op%"=="7" goto purge
if "%op%"=="0" goto end
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
  %PS% "%INSTALL%\vencord-watch.ps1" -Once
  echo Verificacao concluida. Veja o log para detalhes.
) else (
  echo Projeto ainda nao instalado. Use a opcao [1] primeiro.
)
pause
goto menu

:log
echo.
if exist "%INSTALL%\watch.log" (
  powershell -NoProfile -Command "Get-Content '%INSTALL%\watch.log' -Tail 25"
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
set /p "c=Tem certeza? (S/N): "
if /I "%c%"=="S" (
  %PS% "%SCRIPTS%\uninstall.ps1" -RemoveVencord -Purge
)
pause
goto menu

:end
