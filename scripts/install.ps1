# Vencord Auto-Repair - instalacao completa (sem admin).
# Copyright (C) 2026 yagoriccomi
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# 1) Baixa o VencordInstallerCli oficial (com verificacao SHA256)
# 2) Fecha o Discord (obrigatorio: com ele aberto o patch FALHA), aplica e reabre
# 3) Instala o vigia e registra a tarefa agendada
$ErrorActionPreference = 'Stop'

$InstallDir = "$env:USERPROFILE\Vencord"
$Discord    = "$env:LOCALAPPDATA\Discord"
$Updater    = "$Discord\Update.exe"
$Exe        = "$InstallDir\VencordInstallerCli.exe"
$Url        = "https://github.com/Vencord/Installer/releases/download/v1.4.0/VencordInstallerCli.exe"
$Sha256     = "466d2a0be1f380ddffed052df3cc132125fa34dc1af29312e14f13f358c8d2a2"

Write-Host "== Vencord Auto-Repair :: instalacao ==" -ForegroundColor Cyan

if (-not (Test-Path $Discord)) {
    Write-Host "Discord (stable) nao encontrado em %LOCALAPPDATA%\Discord. Instale o Discord primeiro." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copia os scripts do projeto para a pasta de instalacao
foreach ($f in @('vencord-watch.ps1', 'register-task.ps1', 'run-hidden.vbs', 'notify.vbs', 'config.ps1')) {
    Copy-Item "$PSScriptRoot\$f" $InstallDir -Force
}

# Baixa o instalador se necessario
if (-not (Test-Path $Exe)) {
    Write-Host "Baixando VencordInstallerCli.exe ..." -ForegroundColor Yellow
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

# Aplica o Vencord
Write-Host "Aplicando Vencord no Discord ..." -ForegroundColor Yellow
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
    Write-Host "Vencord aplicado em $($app.Name)." -ForegroundColor Green
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
    Write-Host "Concluido! Abra o Discord e procure 'Vencord' nas configuracoes." -ForegroundColor Green
} else {
    Write-Host "Concluido com FALHA na aplicacao do Vencord - o Discord esta intacto." -ForegroundColor Yellow
}
Write-Host "Arquivos em: $InstallDir" -ForegroundColor DarkGray
