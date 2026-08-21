# Discord Mod Auto-Repair - camada de acesso ao Discord
# Uso particular. Todos os direitos reservados.
#
# UNICA camada que conhece o disco e os processos do Discord. Quem chama
# decide O QUE fazer; este arquivo sabe COMO mexer no Discord.
#
# As funcoes nao escrevem em log nem no console: recebem um scriptblock -Log
# injetado por quem chama. Assim o vigia manda para o arquivo de log e os
# scripts de menu mandam para a tela, sem esta camada conhecer nenhum dos dois.

# --------------------------------------------------------------- constantes ----
# Tempos que antes estavam espalhados como literais pelo codigo.
$script:DiscordDir              = "$env:LOCALAPPDATA\Discord"
$script:DiscordUpdater          = "$env:LOCALAPPDATA\Discord\Update.exe"

# O Discord ignora o "fechar educado" (vai para a bandeja em vez de sair),
# entao esperamos pouco antes de encerrar o processo de fato.
$script:EsperaFecharSegundos    = 6
$script:EsperaPosKillSegundos   = 3
$script:FolgaArquivosSegundos   = 2   # o Windows ainda segura os arquivos um instante

# Reabertura: o Update.exe (Squirrel) as vezes diz que lancou e nao sobe nada.
$script:EsperaUpdaterSegundos   = 12
$script:EsperaDiretoSegundos    = 15

function Write-Passo($Log, $mensagem) {
    if ($Log) { & $Log $mensagem }
}

# ------------------------------------------------------------ versoes ----
# Uma pasta app-* so conta como versao de verdade se tiver o Discord.exe E um
# .asar em resources. O updater copia o Discord.exe ANTES do resources, e um
# download interrompido deixa a pasta so com os .dll/.exe: sem esta checagem o
# esqueleto seria eleito "versao atual" e o patch tentaria rodar no vazio.
function Test-DiscordAppCompleto($dir) {
    (Test-Path (Join-Path $dir 'Discord.exe')) -and
    ((Test-Path (Join-Path $dir 'resources\app.asar')) -or
     (Test-Path (Join-Path $dir 'resources\_app.asar')))
}

# Versao comparada como NUMERO (texto quebraria em 1.0.10000).
function Get-DiscordAppDir {
    Get-ChildItem $script:DiscordDir -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { Test-DiscordAppCompleto $_.FullName } |
        Sort-Object @{ Expression = {
            try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
        Select-Object -Last 1
}

function Get-DiscordAppIncompleto {
    Get-ChildItem $script:DiscordDir -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-DiscordAppCompleto $_.FullName) }
}

# O mod renomeia app.asar -> _app.asar e poe um shim no lugar.
#   patched = os dois existem | pure = so o app.asar original
#   broken  = falta o app.asar -> o Discord ABRE E FECHA SOZINHO
function Get-DiscordPatchState($appDir) {
    $res  = Join-Path $appDir.FullName 'resources'
    $shim = Test-Path (Join-Path $res 'app.asar')
    $orig = Test-Path (Join-Path $res '_app.asar')
    if     ($shim -and $orig)      { 'patched' }
    elseif ($shim -and -not $orig) { 'pure'    }
    else                           { 'broken'  }
}

# ------------------------------------------------------------ processos ----
function Test-DiscordRodando {
    [bool](Get-Process Discord -ErrorAction SilentlyContinue)
}

# Fecha o Discord e devolve $true se conseguiu. Obrigatorio antes de patchear:
# com ele aberto o instalador recusa ("files are used by a different process")
# e pode deixar o Discord quebrado.
function Stop-DiscordApp {
    param([scriptblock]$Log)

    if (-not (Test-DiscordRodando)) { return $true }

    Write-Passo $Log "Fechando o Discord para liberar os arquivos..."
    Get-Process Discord -ErrorAction SilentlyContinue | ForEach-Object { $null = $_.CloseMainWindow() }

    for ($i = 0; $i -lt $script:EsperaFecharSegundos; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Test-DiscordRodando)) { break }
    }

    if (Test-DiscordRodando) {
        Write-Passo $Log "Discord foi para a bandeja - encerrando o processo."
        Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds $script:EsperaPosKillSegundos
    }

    Start-Sleep -Seconds $script:FolgaArquivosSegundos
    return (-not (Test-DiscordRodando))
}

# Abre o Discord e CONFERE se subiu mesmo, com plano B.
function Start-DiscordApp {
    param([scriptblock]$Log)

    if (Test-DiscordRodando) { return $true }

    # 1) jeito oficial: Update.exe (preserva o auto-update do Discord)
    if (Test-Path $script:DiscordUpdater) {
        Start-Process $script:DiscordUpdater -ArgumentList '--processStart', 'Discord.exe'
        for ($i = 0; $i -lt $script:EsperaUpdaterSegundos; $i++) {
            Start-Sleep -Seconds 1
            if (Test-DiscordRodando) { Write-Passo $Log "Discord reaberto."; return $true }
        }
        Write-Passo $Log "Update.exe nao subiu o Discord - tentando abrir direto."
    }

    # 2) plano B: executavel da versao mais nova (ignorando updates pela metade)
    $app = Get-DiscordAppDir
    if ($app) {
        $bin = Join-Path $app.FullName 'Discord.exe'
        if (Test-Path $bin) {
            Start-Process $bin
            for ($i = 0; $i -lt $script:EsperaDiretoSegundos; $i++) {
                Start-Sleep -Seconds 1
                if (Test-DiscordRodando) { Write-Passo $Log "Discord reaberto (direto)."; return $true }
            }
        }
    }

    Write-Passo $Log "NAO consegui reabrir o Discord."
    return $false
}
