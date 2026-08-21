# Equicord Auto-Repair - instalacao completa (sem admin).
# Uso particular. Todos os direitos reservados.
#
# 1) Baixa o Equilotl oficial (com verificacao SHA256)
# 2) Fecha o Discord (obrigatorio: com ele aberto o patch FALHA), aplica e reabre
# 3) Instala o vigia e registra a tarefa agendada
$ErrorActionPreference = 'Stop'

$InstallDir = "$env:USERPROFILE\EquicordAutoRepair"
$Discord    = "$env:LOCALAPPDATA\Discord"
$Updater    = "$Discord\Update.exe"
$Exe        = "$InstallDir\EquilotlCli.exe"
$Url        = "https://github.com/Equicord/Equilotl/releases/download/v2.2.6/EquilotlCli.exe"
$Sha256     = "79932382d859747318f642c3e23297c7a0174398cc489e8fb4222cc2758c16e8"

Write-Host "== Equicord Auto-Repair :: instalacao ==" -ForegroundColor Cyan

if (-not (Test-Path $Discord)) {
    Write-Host "Discord (stable) nao encontrado em %LOCALAPPDATA%\Discord. Instale o Discord primeiro." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copia os scripts do projeto para a pasta de instalacao
foreach ($f in @('equicord-watch.ps1', 'register-task.ps1', 'run-hidden.vbs', 'notify.vbs', 'config.ps1')) {
    Copy-Item "$PSScriptRoot\$f" $InstallDir -Force
}

# Baixa o instalador se necessario
if (-not (Test-Path $Exe)) {
    Write-Host "Baixando EquilotlCli.exe ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Url -OutFile $Exe -UseBasicParsing
}

# Verifica integridade
$hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $Sha256) {
    Write-Host "FALHA de checksum! Esperado $Sha256, obtido $hash. Abortando." -ForegroundColor Red
    Remove-Item $Exe -Force
    exit 1
}
Write-Host "Checksum OK." -ForegroundColor Green

# O Discord PRECISA estar fechado: com ele aberto o instalador recusa
# ("files are used by a different process") e pode deixar tudo quebrado.
$estavaAberto = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
if ($estavaAberto) {
    Write-Host "Fechando o Discord (obrigatorio para aplicar o patch)..." -ForegroundColor Yellow
    Get-Process Discord -ErrorAction SilentlyContinue | ForEach-Object { $null = $_.CloseMainWindow() }
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) { break }
    }
    Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# Aplica o Equicord
Write-Host "Aplicando Equicord no Discord ..." -ForegroundColor Yellow
& $Exe -install -location $Discord
$code = $LASTEXITCODE

# Confere de verdade (o exit code sozinho nao basta)
Start-Sleep -Seconds 2
$app = Get-ChildItem $Discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
    Where-Object {
        (Test-Path (Join-Path $_.FullName 'Discord.exe')) -and
        ((Test-Path (Join-Path $_.FullName 'resources\app.asar')) -or
         (Test-Path (Join-Path $_.FullName 'resources\_app.asar'))) } |
    Sort-Object @{ Expression = { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
    Select-Object -Last 1
$aplicado = $app -and (Test-Path (Join-Path $app.FullName 'resources\_app.asar'))

if ($aplicado) {
    Write-Host "Equicord aplicado em $($app.Name)." -ForegroundColor Green
} else {
    Write-Host "NAO foi possivel aplicar (codigo $code). Restaurando o Discord original..." -ForegroundColor Red
    & $Exe -uninstall -location $Discord
}

# Registra a tarefa de auto-reparo
& "$InstallDir\register-task.ps1"

# Reabre o Discord se ele estava aberto antes (conferindo se subiu mesmo)
if ($estavaAberto) {
    $subiu = $false
    if (Test-Path $Updater) {
        Start-Process $Updater -ArgumentList '--processStart', 'Discord.exe'
        for ($i = 0; $i -lt 12; $i++) {
            Start-Sleep -Seconds 1
            if (Get-Process Discord -ErrorAction SilentlyContinue) { $subiu = $true; break }
        }
    }
    if (-not $subiu -and $app) {
        $bin = Join-Path $app.FullName 'Discord.exe'
        if (Test-Path $bin) { Start-Process $bin; $subiu = $true }
    }
    if ($subiu) { Write-Host "Discord reaberto." -ForegroundColor Green }
    else        { Write-Host "Nao consegui reabrir o Discord - abra manualmente." -ForegroundColor Yellow }
}

Write-Host ""
if ($aplicado) {
    Write-Host "Concluido! Abra o Discord e procure 'Equicord' nas configuracoes." -ForegroundColor Green
} else {
    Write-Host "Concluido com FALHA na aplicacao do Equicord - o Discord esta intacto." -ForegroundColor Yellow
}
Write-Host "Arquivos em: $InstallDir" -ForegroundColor DarkGray
