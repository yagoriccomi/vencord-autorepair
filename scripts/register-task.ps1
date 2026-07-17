# Registra a tarefa agendada que inicia o vigia junto com a sessao do usuario.
# Sem admin. O vigia NAO patcha no logon; so age quando o Discord atualiza ou e aberto.
$watch    = "$env:USERPROFILE\Vencord\vencord-watch.ps1"
$taskName = "Vencord Auto-Repair"

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watch`""

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
