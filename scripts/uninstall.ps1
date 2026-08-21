# Equicord Auto-Repair - desinstalacao.
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
#   -RemoveEquicord : tambem remove o Equicord do Discord (desfaz o patch)
#   -Purge         : tambem apaga a pasta de instalacao (%USERPROFILE%\EquicordAutoRepair)
param([switch]$RemoveEquicord, [switch]$Purge)

$ErrorActionPreference = 'SilentlyContinue'
$InstallDir = "$env:USERPROFILE\EquicordAutoRepair"
$Exe        = "$InstallDir\EquilotlCli.exe"
$taskName   = "Equicord Auto-Repair"

Write-Host "== Equicord Auto-Repair :: desinstalacao ==" -ForegroundColor Cyan

# Para e remove a tarefa
Stop-ScheduledTask   -TaskName $taskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Tarefa agendada removida (auto-reparo desligado)." -ForegroundColor Green

# Encerra o processo do vigia, se estiver rodando.
# O -ne $PID evita o script se matar caso rode a partir de um shell cuja
# propria linha de comando mencione o vigia.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*equicord-watch.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

if ($RemoveEquicord) {
    if (Test-Path $Exe) {
        Write-Host "Removendo o Equicord do Discord ..." -ForegroundColor Yellow
        & $Exe -uninstall -location "$env:LOCALAPPDATA\Discord"
    } else {
        Write-Host "Instalador nao encontrado; pulando remocao do patch." -ForegroundColor DarkYellow
    }
}

if ($Purge) {
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Pasta de instalacao removida." -ForegroundColor Green
}

Write-Host "Pronto." -ForegroundColor Green
