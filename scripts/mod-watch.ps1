# Discord Mod Auto-Repair - vigia (ponto de entrada)
# Uso particular. Todos os direitos reservados.
#
# Mantem aplicado o mod que VOCE escolheu (Vencord ou Equicord, com ou sem um
# build proprio) e reage APENAS em dois momentos:
#   1) quando o Discord instala uma nova versao;
#   2) quando o Discord e ABERTO (transicao de fechado -> aberto).
# NAO aplica nada ao iniciar/logar e NAO roda em intervalo de tempo.
#
# A regra de negocio mora em repair.ps1; aqui fica so o disparo.
# Use -Once para uma verificacao unica; -Force ignora a quarentena.
param([switch]$Once, [switch]$Force)

. (Join-Path $PSScriptRoot 'repair.ps1')

# ------------------------------------------------------------------ main ----
if ($Once) { Repair 'manual' ([bool]$Force); return }

# Instancia unica via mutex nomeado (nao mata processo nenhum).
$script:mtx = New-Object System.Threading.Mutex($false, 'DiscordModAutoRepairWatcher')
$owns = $false
try { $owns = $script:mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owns = $true }
if (-not $owns) { Log "Ja existe um vigia rodando - saindo."; return }

# Estado inicial: NAO aplica nada agora. So registra a linha de base.
$cfgIni     = Get-Config
$lastVer    = (Get-DiscordAppDir).Name
$wasRunning = Test-DiscordRodando
Log "Vigia iniciado (sem aplicar nada agora). Mod: $(Get-ModRotulo $cfgIni). Base: $lastVer, Discord aberto=$wasRunning"

while ($true) {
    Start-Sleep -Seconds $script:IntervaloVigiaSegundos
    $cur     = (Get-DiscordAppDir).Name
    $running = Test-DiscordRodando

    if ($cur -and $cur -ne $lastVer) {
        Log "Mudanca de versao: $lastVer -> $cur. Esperando o Discord terminar de atualizar..."
        $lastVer = Wait-Settle
        Log "Versao estabilizada em $lastVer."
        Repair 'update do Discord' $false
    }
    elseif ($running -and -not $wasRunning) {
        Start-Sleep -Seconds $script:FolgaAposAbrirSegundos
        Repair 'abertura do Discord' $false
    }

    # Relido DEPOIS do reparo: o proprio reparo fecha/reabre o Discord.
    $wasRunning = Test-DiscordRodando
}
