# Equicord Auto-Repair - registro da tarefa agendada
# Uso particular. Todos os direitos reservados.
#
# Registra a tarefa agendada que inicia o vigia junto com a sessao do usuario.
# Sem admin. O vigia NAO patcha no logon; so age quando o Discord atualiza ou e aberto.
$vbs      = "$env:USERPROFILE\EquicordAutoRepair\run-hidden.vbs"
$taskName = "Equicord Auto-Repair"

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
    -Description "Reaplica o Equicord apos o Discord atualizar ou ao abrir o Discord. Nao roda em intervalo nem patcha no logon." -Force | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Host "Tarefa '$taskName' registrada e iniciada." -ForegroundColor Green
