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
$InstallDir = "$env:USERPROFILE\Vencord"
$discord    = "$env:LOCALAPPDATA\Discord"
$taskName   = "Vencord Auto-Repair"

Write-Host "== Vencord Auto-Repair :: status ==" -ForegroundColor Cyan

# Discord
if (Test-Path $discord) {
    $app = Get-ChildItem $discord -Directory -Filter 'app-*' | Sort-Object Name -Descending | Select-Object -First 1
    Write-Host "Discord: instalado ($($app.Name))" -ForegroundColor Green
    $patched = Test-Path (Join-Path $app.FullName 'resources\_app.asar')
    if ($patched) { Write-Host "Vencord: APLICADO" -ForegroundColor Green }
    else          { Write-Host "Vencord: NAO aplicado" -ForegroundColor Yellow }
} else {
    Write-Host "Discord: nao encontrado" -ForegroundColor Red
}

# Tarefa
$t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Tarefa '$taskName': $($t.State) (ultima exec: $($info.LastRunTime))" -ForegroundColor Green
} else {
    Write-Host "Tarefa '$taskName': NAO registrada" -ForegroundColor Yellow
}

# Vigia rodando?
$proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*vencord-watch.ps1*' }
if ($proc) { Write-Host "Vigia: rodando (PID $($proc.ProcessId))" -ForegroundColor Green }
else       { Write-Host "Vigia: parado" -ForegroundColor Yellow }

# Log
$log = "$InstallDir\watch.log"
if (Test-Path $log) {
    Write-Host "`n-- ultimas linhas do log --" -ForegroundColor DarkGray
    Get-Content $log -Tail 8
}
