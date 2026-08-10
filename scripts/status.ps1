# Vencord Auto-Repair - status geral
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
$base     = "$env:USERPROFILE\Vencord"
$discord  = "$env:LOCALAPPDATA\Discord"
$taskName = "Vencord Auto-Repair"

Write-Host "== Vencord Auto-Repair :: status ==" -ForegroundColor Cyan

# ---- Discord + patch ----
if (Test-Path $discord) {
    $app = Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'Discord.exe') } |
        Sort-Object @{ Expression = { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
        Select-Object -Last 1

    if ($app) {
        Write-Host "Discord .......... instalado ($($app.Name))" -ForegroundColor Green
        $res  = Join-Path $app.FullName 'resources'
        $shim = Test-Path (Join-Path $res 'app.asar')
        $orig = Test-Path (Join-Path $res '_app.asar')
        if     ($shim -and $orig)      { Write-Host "Vencord .......... APLICADO" -ForegroundColor Green }
        elseif ($shim -and -not $orig) { Write-Host "Vencord .......... nao aplicado (Discord puro)" -ForegroundColor Yellow }
        else                           { Write-Host "Vencord .......... QUEBRADO - falta o app.asar, o Discord nao abre!" -ForegroundColor Red }
    } else {
        Write-Host "Discord .......... pasta existe, mas sem versao completa" -ForegroundColor Yellow
    }
} else {
    Write-Host "Discord .......... nao encontrado" -ForegroundColor Red
}

# ---- Discord rodando ----
if (Get-Process Discord -ErrorAction SilentlyContinue) {
    Write-Host "Discord agora .... aberto"
} else {
    Write-Host "Discord agora .... fechado"
}

# ---- Tarefa ----
$t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Tarefa ........... registrada (ultima exec: $($info.LastRunTime))" -ForegroundColor Green
} else {
    Write-Host "Tarefa ........... NAO registrada" -ForegroundColor Yellow
}

# ---- Vigia ----
$proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'vencord-watch\.ps1' -and $_.CommandLine -notmatch 'Win32_Process' }
if ($proc) { Write-Host "Vigia ............ rodando (PID $(@($proc)[0].ProcessId))" -ForegroundColor Green }
else       { Write-Host "Vigia ............ parado" -ForegroundColor Yellow }

# ---- Quarentena ----
$stFile = "$base\state.json"
if (Test-Path $stFile) {
    try {
        $st = Get-Content $stFile -Raw | ConvertFrom-Json
        if ($st.Quarentena) {
            Write-Host "Auto-reparo ...... PAUSADO em $($st.Versao) apos $($st.Falhas) falha(s)" -ForegroundColor Red
            Write-Host "                   use a opcao [8] do menu para destravar" -ForegroundColor DarkGray
        } elseif ([int]$st.Falhas -gt 0) {
            Write-Host "Auto-reparo ...... ativo ($($st.Falhas) falha(s) em $($st.Versao))" -ForegroundColor Yellow
        } else {
            Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
        }
    } catch { }
} else {
    Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
}

# ---- Config ----
Write-Host ""
if (Test-Path "$base\config.ps1") { & "$base\config.ps1" -Action mostrar }

# ---- Log ----
$log = "$base\watch.log"
if (Test-Path $log) {
    Write-Host ""
    Write-Host "-- ultimas linhas do log --" -ForegroundColor DarkGray
    Get-Content $log -Tail 8
}
