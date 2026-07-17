# Vencord Auto-Repair - status geral
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
