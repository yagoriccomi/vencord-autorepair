# Vencord Auto-Repair - desinstalacao.
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
