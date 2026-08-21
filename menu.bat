@echo off
REM Equicord Auto-Repair - menu
REM Uso particular. Todos os direitos reservados.
title Equicord Auto-Repair
set "SCRIPTS=%~dp0scripts"
set "INSTALL=%USERPROFILE%\EquicordAutoRepair"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File"

:menu
cls
echo ==================================================
echo               EQUICORD AUTO-REPAIR
echo ==================================================
echo.
echo   --- USAR ---
echo   [1]  Instalar Equicord + auto-reparo
echo   [2]  Ver status
echo   [3]  Aplicar / reparar o Equicord agora
echo   [4]  Abrir o Discord
echo.
echo   --- AJUSTES ---
echo   [5]  Ligar/desligar aviso quando DER CERTO
echo   [6]  Ligar/desligar pergunta antes de fechar o Discord
echo   [7]  Ligar/desligar reabrir o Discord sozinho
echo   [8]  Zerar quarentena (voltar a tentar sozinho)
echo.
echo   --- MANUTENCAO ---
echo   [9]  Ver log do vigia
echo   [10] Reinstalar a tarefa agendada
echo   [11] Desligar auto-reparo (remove a tarefa)
echo   [12] Desinstalar TUDO (tarefa + Equicord do Discord)
echo   [13] Reconstruir o build personalizado (pnpm build)
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
if "%op%"=="13" goto rebuild
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
if exist "%INSTALL%\equicord-watch.ps1" (
  echo Verificando e aplicando se precisar...
  echo O Discord sera fechado e reaberto se for necessario.
  %PS% "%INSTALL%\equicord-watch.ps1" -Once -Force
  echo.
  echo Concluido. Veja o log (opcao 9) para os detalhes.
) else (
  echo Projeto ainda nao instalado. Use a opcao [1] primeiro.
)
pause
goto menu

:opendiscord
echo.
%PS% "%SCRIPTS%\open-discord.ps1"
pause
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
echo Isso vai remover a tarefa E o Equicord do Discord.
set "c="
set /p "c=Tem certeza? (S/N): "
if /I "%c%"=="S" (
  %PS% "%SCRIPTS%\uninstall.ps1" -RemoveEquicord -Purge
)
pause
goto menu

:rebuild
echo.
%PS% "%SCRIPTS%\rebuild.ps1"
pause
goto menu

:end
