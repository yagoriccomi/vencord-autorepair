# Discord Mod Auto-Repair - desinstalacao.
# Uso particular. Todos os direitos reservados.
#
#   -RemoveMod : tambem remove o mod do Discord (desfaz o patch)
#   -Purge     : tambem apaga a pasta de instalacao
param([switch]$RemoveMod, [switch]$Purge)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'mods.ps1')

$InstallDir = "$env:USERPROFILE\DiscordModAutoRepair"
$Discord    = "$env:LOCALAPPDATA\Discord"
$Updater    = "$Discord\Update.exe"

Write-Host "== Discord Mod Auto-Repair :: desinstalacao ==" -ForegroundColor Cyan

# Remove a tarefa atual e as de versoes antigas do projeto
foreach ($tn in @('Discord Mod Auto-Repair', 'Equicord Auto-Repair', 'Vencord Auto-Repair')) {
    if (Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Tarefa '$tn' removida." -ForegroundColor Green
    }
}

# Encerra o vigia, se estiver rodando. O -ne $PID evita o script se matar
# caso rode a partir de um shell cuja linha de comando mencione o vigia.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { ($_.CommandLine -like '*mod-watch.ps1*' -or $_.CommandLine -like '*equicord-watch.ps1*' -or
                    $_.CommandLine -like '*vencord-watch.ps1*') -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

if ($RemoveMod) {
    # O instalador FALHA com o Discord aberto - fechar antes e obrigatorio.
    $estavaAberto = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
    if ($estavaAberto) {
        Write-Host "Fechando o Discord para remover o patch..." -ForegroundColor Yellow
        Get-Process Discord -ErrorAction SilentlyContinue | ForEach-Object { $null = $_.CloseMainWindow() }
        for ($i = 0; $i -lt 8; $i++) {
            Start-Sleep -Seconds 1
            if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) { break }
        }
        Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    # Usa qualquer instalador presente - serve tanto para Vencord quanto Equicord
    $removeu = $false
    foreach ($nome in @('EquilotlCli.exe', 'VencordInstallerCli.exe')) {
        $exe = Join-Path $InstallDir $nome
        if (Test-Path $exe) {
            Write-Host "Removendo o mod do Discord ($nome) ..." -ForegroundColor Yellow
            & $exe -uninstall -location $Discord
            $removeu = $true
        }
    }
    if (-not $removeu) {
        Write-Host "Nenhum instalador encontrado; pulando a remocao do patch." -ForegroundColor DarkYellow
    }

    if ($estavaAberto -and (Test-Path $Updater)) {
        Start-Process $Updater -ArgumentList '--processStart', 'Discord.exe'
        Write-Host "Discord reaberto." -ForegroundColor Green
    }
}

if ($Purge) {
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    # pasta da versao antiga do projeto, se tiver sobrado
    Remove-Item "$env:USERPROFILE\EquicordAutoRepair" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Pasta de instalacao removida." -ForegroundColor Green
}

Write-Host "Pronto." -ForegroundColor Green
