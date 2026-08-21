# Equicord Auto-Repair - desinstalacao.
# Uso particular. Todos os direitos reservados.
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
