# Vencord Auto-Repair - vigia
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
# Reaplica o Vencord APENAS em dois momentos:
#   1) quando o Discord instala uma nova versao (surge um app-<versao> novo);
#   2) quando o Discord e ABERTO (transicao de fechado -> aberto).
# NAO aplica nada ao iniciar/logar e NAO roda em intervalo de tempo.
# Use -Once para uma verificacao unica (teste / "reparar agora").
param([switch]$Once)

$ErrorActionPreference = 'SilentlyContinue'
$discord = "$env:LOCALAPPDATA\Discord"
$exe     = "$env:USERPROFILE\Vencord\VencordInstallerCli.exe"
$log     = "$env:USERPROFILE\Vencord\watch.log"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8 }

function Latest-App {
    (Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1)
}

function Reconcile {
    if (-not (Test-Path $exe))     { Log "Instalador ausente - abortando."; return }
    if (-not (Test-Path $discord)) { Log "Discord nao instalado."; return }

    $appDir = Latest-App
    if (-not $appDir) { Log "Nenhuma pasta app-*."; return }

    # Garante que a versao terminou de instalar (Discord.exe presente e estavel)
    $mainExe = Join-Path $appDir.FullName 'Discord.exe'
    for ($i = 0; $i -lt 30; $i++) { if (Test-Path $mainExe) { break }; Start-Sleep -Seconds 3 }
    if (-not (Test-Path $mainExe)) { Log "$($appDir.Name) ainda incompleto - adiando."; return }
    Start-Sleep -Seconds 5

    # Patch do Vencord: renomeia o app.asar original para _app.asar e poe um shim no lugar.
    # Logo, "ja aplicado" = existe _app.asar na pasta resources.
    $orig    = Join-Path $appDir.FullName 'resources\_app.asar'
    $patched = Test-Path $orig
    if ($patched) { Log "$($appDir.Name) ja com Vencord - nada a fazer."; return }

    Log "$($appDir.Name): sem patch -> aplicando Vencord..."
    $out = & $exe -install -location $discord 2>&1 | Out-String
    Log $out.Trim()
    Log "Aplicado (exit $LASTEXITCODE)."
}

if ($Once) { Reconcile; return }

# Instancia unica via mutex nomeado (nao mata processo nenhum).
# Se outro vigia ja detem a "chave", este sai imediatamente.
$script:mtx = New-Object System.Threading.Mutex($false, 'VencordAutoRepairWatcher')
$owns = $false
try { $owns = $script:mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owns = $true }
if (-not $owns) { Log "Ja existe um vigia rodando - saindo."; return }

# Estado inicial: NAO aplica nada agora. So registra a linha de base.
$lastApp    = (Latest-App).Name
$wasRunning = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
Log "Vigia iniciado (sem patch no inicio). Observando updates e abertura do Discord. Base: $lastApp, aberto=$wasRunning"

while ($true) {
    Start-Sleep -Seconds 5
    $curApp  = (Latest-App).Name
    $running = [bool](Get-Process Discord -ErrorAction SilentlyContinue)

    if ($curApp -and $curApp -ne $lastApp) {
        Log "Update detectado: $lastApp -> $curApp"
        $lastApp = $curApp
        Reconcile
    }
    elseif ($running -and -not $wasRunning) {
        Log "Discord aberto - verificando patch."
        Start-Sleep -Seconds 4
        Reconcile
    }
    $wasRunning = $running
}
