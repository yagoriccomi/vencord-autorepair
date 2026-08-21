@echo off
REM Discord Mod Auto-Repair - menu
REM Uso particular. Todos os direitos reservados.
title Discord Mod Auto-Repair
set "SCRIPTS=%~dp0scripts"
set "INSTALL=%USERPROFILE%\DiscordModAutoRepair"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -File"

:menu
cls
set "MODATUAL=(nao consegui ler)"
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\config.ps1" -Action rotulo 2^>nul') do set "MODATUAL=%%i"
echo ==================================================
echo            DISCORD MOD AUTO-REPAIR
echo ==================================================
echo.
echo    Mod escolhido:  %MODATUAL%
echo.
echo   --- 1) ESCOLHA O MOD ---
echo   [1]  Vencord
echo   [2]  Equicord  (build padrao, SEM GoLiveBypass)
echo   [3]  Equicord + GoLiveBypass  (seu build proprio)
echo.
echo   --- 2) APLICAR NO DISCORD ---
echo   [4]  Instalar / trocar para o mod escolhido
echo   [5]  Ver status
echo   [6]  Reparar agora
echo   [7]  Abrir o Discord
echo.
echo   --- AJUSTES ---
echo   [8]  Aviso quando DER CERTO (liga/desliga)
echo   [9]  Perguntar antes de fechar o Discord (liga/desliga)
echo   [10] Reabrir o Discord sozinho (liga/desliga)
echo   [11] Zerar quarentena
echo.
echo   --- MANUTENCAO ---
echo   [12] Ver log do vigia
echo   [13] Reconstruir o build proprio (pnpm build)
echo   [14] Reinstalar a tarefa agendada
echo   [15] Desligar o auto-reparo (remove a tarefa)
echo   [16] Desinstalar TUDO (tarefa + mod do Discord)
echo   [17] Rodar os testes
echo.
echo   [0]  Sair
echo.
set "op="
set /p "op=Escolha uma opcao: "

if "%op%"=="1"  goto modvencord
if "%op%"=="2"  goto modequicord
if "%op%"=="3"  goto modgolive
if "%op%"=="4"  goto install
if "%op%"=="5"  goto status
if "%op%"=="6"  goto repair
if "%op%"=="7"  goto opendiscord
if "%op%"=="8"  goto cfgsucesso
if "%op%"=="9"  goto cfgaviso
if "%op%"=="10" goto cfgreabrir
if "%op%"=="11" goto destravar
if "%op%"=="12" goto log
if "%op%"=="13" goto rebuild
if "%op%"=="14" goto regtask
if "%op%"=="15" goto uninstall
if "%op%"=="16" goto purge
if "%op%"=="17" goto testes
if "%op%"=="0"  goto end
goto menu

:modvencord
echo.
%PS% "%SCRIPTS%\config.ps1" -Action vencord
pause
goto menu

:modequicord
echo.
%PS% "%SCRIPTS%\config.ps1" -Action equicord
pause
goto menu

:modgolive
echo.
%PS% "%SCRIPTS%\config.ps1" -Action equicord-golive
pause
goto menu

:install
echo.
echo Aplicando o mod escolhido: %MODATUAL%
echo O Discord sera fechado e reaberto se estiver aberto.
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
if exist "%INSTALL%\mod-watch.ps1" (
  echo Verificando e aplicando se precisar...
  %PS% "%INSTALL%\mod-watch.ps1" -Once -Force
  echo.
  echo Concluido. Veja o log (opcao 12) para os detalhes.
) else (
  echo Ainda nao instalado. Escolha o mod (1 a 3) e use a opcao [4].
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

:rebuild
echo.
%PS% "%SCRIPTS%\rebuild.ps1"
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
echo Isso vai remover a tarefa E o mod do Discord.
set "c="
set /p "c=Tem certeza? (S/N): "
if /I "%c%"=="S" (
  %PS% "%SCRIPTS%\uninstall.ps1" -RemoveMod -Purge
)
pause
goto menu

:testes
echo.
%PS% "%SCRIPTS%\test.ps1"
pause
goto menu

:end
