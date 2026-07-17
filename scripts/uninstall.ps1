# Vencord Auto-Repair - desinstalacao.
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
#   -RemoveVencord : tambem remove o Vencord do Discord (desfaz o patch)
#   -Purge         : tambem apaga a pasta de instalacao (%USERPROFILE%\Vencord)
param([switch]$RemoveVencord, [switch]$Purge)

$ErrorActionPreference = 'SilentlyContinue'
$InstallDir = "$env:USERPROFILE\Vencord"
$Exe        = "$InstallDir\VencordInstallerCli.exe"
$taskName   = "Vencord Auto-Repair"

Write-Host "== Vencord Auto-Repair :: desinstalacao ==" -ForegroundColor Cyan

# Para e remove a tarefa
Stop-ScheduledTask   -TaskName $taskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Tarefa agendada removida (auto-reparo desligado)." -ForegroundColor Green

# Encerra o processo do vigia, se estiver rodando
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*vencord-watch.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

if ($RemoveVencord) {
    if (Test-Path $Exe) {
        Write-Host "Removendo o Vencord do Discord ..." -ForegroundColor Yellow
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
