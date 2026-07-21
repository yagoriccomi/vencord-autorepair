# Vencord Auto-Repair - registro da tarefa agendada
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
# Registra a tarefa agendada que inicia o vigia junto com a sessao do usuario.
# Sem admin. O vigia NAO patcha no logon; so age quando o Discord atualiza ou e aberto.
$vbs      = "$env:USERPROFILE\Vencord\run-hidden.vbs"
$taskName = "Vencord Auto-Repair"

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Lanca via wscript + VBS para que o PowerShell rode SEM janela (sem flash de
# console no logon). O -WindowStyle Hidden sozinho ainda mostra a janela por um
# instante antes de esconder; o launcher .vbs evita que ela chegue a existir.
$action = New-ScheduledTaskAction -Execute "wscript.exe" `
    -Argument "`"$vbs`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings `
    -Description "Reaplica o Vencord apos o Discord atualizar ou ao abrir o Discord. Nao roda em intervalo nem patcha no logon." -Force | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Host "Tarefa '$taskName' registrada e iniciada." -ForegroundColor Green
