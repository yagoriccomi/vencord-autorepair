# Equicord Auto-Repair - abrir o Discord
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
# Abre o Discord e CONFERE se ele subiu. O Update.exe (Squirrel) as vezes
# diz que lancou e nao sobe nada, por isso existe o plano B.
$discord = "$env:LOCALAPPDATA\Discord"
$updater = "$discord\Update.exe"

if (Get-Process Discord -ErrorAction SilentlyContinue) {
    Write-Host "O Discord ja esta aberto." -ForegroundColor Green
    return
}

if (-not (Test-Path $discord)) {
    Write-Host "Discord nao encontrado." -ForegroundColor Red
    return
}

# 1) jeito oficial
if (Test-Path $updater) {
    Write-Host "Abrindo o Discord..." -ForegroundColor Yellow
    Start-Process $updater -ArgumentList '--processStart', 'Discord.exe'
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 1
        if (Get-Process Discord -ErrorAction SilentlyContinue) {
            Write-Host "Discord aberto." -ForegroundColor Green
            return
        }
    }
    Write-Host "O Update.exe nao subiu o Discord - abrindo direto..." -ForegroundColor DarkYellow
}

# 2) plano B: executavel da versao mais nova
# Ignora updates incompletos (so .dll/.exe, sem resources): abrir essa pasta
# iniciaria um Discord que morre na hora.
$app = Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
    Where-Object {
        (Test-Path (Join-Path $_.FullName 'Discord.exe')) -and
        ((Test-Path (Join-Path $_.FullName 'resources\app.asar')) -or
         (Test-Path (Join-Path $_.FullName 'resources\_app.asar'))) } |
    Sort-Object @{ Expression = { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
    Select-Object -Last 1

if ($app) {
    Start-Process (Join-Path $app.FullName 'Discord.exe')
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 1
        if (Get-Process Discord -ErrorAction SilentlyContinue) {
            Write-Host "Discord aberto." -ForegroundColor Green
            return
        }
    }
}

Write-Host "Nao consegui abrir o Discord." -ForegroundColor Red
