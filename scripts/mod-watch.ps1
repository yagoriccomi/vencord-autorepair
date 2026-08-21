# Discord Mod Auto-Repair - vigia
# Uso particular. Todos os direitos reservados.
#
# Mantem aplicado o mod que VOCE escolheu (Vencord ou Equicord, com ou sem um
# build proprio) e reage APENAS em dois momentos:
#   1) quando o Discord instala uma nova versao;
#   2) quando o Discord e ABERTO (transicao de fechado -> aberto).
# NAO aplica nada ao iniciar/logar e NAO roda em intervalo de tempo.
#
# Regras de seguranca (aprendidas na marra, ver watch.log):
#   - NUNCA roda o instalador com o Discord aberto. O instalador recusa
#     ("files are used by a different process") e pode deixar o Discord
#     quebrado, abrindo e fechando sozinho.
#   - Espera o updater do Discord ESTABILIZAR antes de agir (o updater troca
#     as pastas app-* varias vezes durante um update).
#   - Confere o resultado de verdade (nao confia no exit code) e reconfere
#     depois de alguns segundos, para pegar o updater desfazendo o patch.
#   - Se falhar: limpa o mod, devolve o Discord PURO e avisa na tela.
#   - Depois de N falhas na mesma versao entra em QUARENTENA e para de mexer,
#     para nunca virar um ciclo de fechar/abrir o Discord infinitamente.
#
# Use -Once para uma verificacao unica; -Force ignora a quarentena.
param([switch]$Once, [switch]$Force)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'mods.ps1')
. (Join-Path $PSScriptRoot 'discord.ps1')
. (Join-Path $PSScriptRoot 'ui.ps1')

$base    = "$env:USERPROFILE\DiscordModAutoRepair"
$discord = "$env:LOCALAPPDATA\Discord"
$log     = "$base\watch.log"
$cfgFile = "$base\config.json"
$stFile  = "$base\state.json"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8 }

# A camada de acesso ao Discord nao conhece o nosso log: recebe este
# scriptblock injetado e reporta por ele [#20][#21].
$script:LogInfra = { param($m) Log $m }

# ---------------------------------------------------------------- config ----
function Get-Config {
    $d = [pscustomobject]@{
        Mod                 = 'equicord' # 'vencord' ou 'equicord'
        NotificarSucesso    = $true      # caixa verde de "deu certo" (ligavel no menu)
        AvisarAntesDeFechar = $true      # pergunta antes de fechar o Discord
        SegundosAviso       = 8          # tempo do aviso ate seguir sozinho
        ReabrirDiscord      = $true      # reabre o Discord depois de mexer
        MaxTentativas       = 3          # falhas na mesma versao ate a quarentena
        BuildPersonalizado  = ''         # .asar de um build proprio (com userplugins);
                                         # vazio = usa o build padrao do instalador
        AsarDoMod           = ''         # destino; vazio = o padrao do mod escolhido
    }
    if (Test-Path $cfgFile) {
        try {
            $j = Get-Content $cfgFile -Raw | ConvertFrom-Json
            foreach ($k in @($d.PSObject.Properties.Name)) {
                if ($null -ne $j.$k) { $d.$k = $j.$k }
            }
        } catch { }
    }
    $d
}

# ----------------------------------------------------------------- estado ----
function Get-State {
    $d = [pscustomobject]@{ Versao = ''; Falhas = 0; Quarentena = $false }
    if (Test-Path $stFile) {
        try {
            $j = Get-Content $stFile -Raw | ConvertFrom-Json
            if ($j.Versao)     { $d.Versao     = [string]$j.Versao }
            if ($j.Falhas)     { $d.Falhas     = [int]$j.Falhas }
            if ($j.Quarentena) { $d.Quarentena = [bool]$j.Quarentena }
        } catch { }
    }
    $d
}
function Set-State($s) { $s | ConvertTo-Json | Set-Content -Path $stFile -Encoding utf8 }

# ------------------------------------------------------ build personalizado ----
# O instalador oficial poe SEMPRE o build padrao do mod. Quem compila a propria
# versao (src/userplugins, ex.: GoLiveBypass) perde os plugins proprios a cada
# reparo, porque o patch passa a apontar para o .asar padrao. Estas funcoes
# conferem e devolvem o build proprio por cima do padrao.
function Get-AsarDestino($cfg, $info) {
    $d = [string]$cfg.AsarDoMod
    if ([string]::IsNullOrWhiteSpace($d)) { return $info.Asar }
    return $d
}

function Test-CustomBuildAtivo($cfg, $info) {
    if (-not $info.SuportaBuildProprio)        { return $true }   # mod sem .asar unico
    $origem = [string]$cfg.BuildPersonalizado
    if ([string]::IsNullOrWhiteSpace($origem)) { return $true }   # nao usa build proprio
    if (-not (Test-Path $origem))              { return $true }   # sem origem: avisado em Restore
    $destino = Get-AsarDestino $cfg $info
    if (-not (Test-Path $destino)) { return $false }
    return ((Get-FileHash $origem -Algorithm SHA256).Hash -eq (Get-FileHash $destino -Algorithm SHA256).Hash)
}

function Restore-CustomBuild($cfg, $info) {
    $origem = [string]$cfg.BuildPersonalizado
    if ([string]::IsNullOrWhiteSpace($origem)) { return $true }   # desligado: nada a fazer
    if (-not $info.SuportaBuildProprio) {
        Log "O $($info.Nome) nao carrega um .asar unico - build proprio nao se aplica."
        return $true
    }
    $destino = Get-AsarDestino $cfg $info

    if (-not (Test-Path $origem)) {
        Log "Build proprio nao encontrado em $origem - ficando com o build padrao."
        return $false
    }
    try {
        $pasta = Split-Path $destino -Parent
        if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }
        Copy-Item $origem $destino -Force -ErrorAction Stop
    } catch {
        Log "Falha ao restaurar o build proprio: $($_.Exception.Message)"
        return $false
    }
    # confere que chegou inteiro (copia truncada = Discord que nao abre)
    $tamOrigem  = (Get-Item $origem).Length
    $tamDestino = if (Test-Path $destino) { (Get-Item $destino).Length } else { -1 }
    if ($tamOrigem -ne $tamDestino) {
        Log "Build proprio copiado pela metade ($tamDestino de $tamOrigem bytes)."
        return $false
    }
    Log "Build proprio restaurado ($([math]::Round($tamOrigem / 1MB, 1)) MB)."
    return $true
}

# ---------------------------------------------------------------- reparo ----
# Tempos do ciclo de reparo, antes soltos como literais no meio do codigo.
$script:EsperaAssentarSegundos   = 3    # deixa o instalador terminar de escrever
$script:EsperaReconferirSegundos = 12   # janela em que o updater do Discord ja desfez o patch
$script:IntervaloVigiaSegundos   = 5    # ritmo do laco de observacao
$script:FolgaAposAbrirSegundos   = 5    # deixa o Discord subir antes de conferir
$script:CiclosParaEstabilizar    = 6    # 6 x 5s = 30s sem a versao mudar
$script:MaxCiclosEstabilizar     = 120  # teto de ~10 min esperando o updater

# Fecha o Discord para poder mexer nos arquivos, avisando antes se configurado.
# Devolve 'ok' | 'adiado' (o usuario recusou) | 'falhou' (nao fechou).
# Extraido porque o mesmo trio avisar/fechar/tratar aparecia em dois pontos.
function Request-FecharDiscord($cfg, $mensagemAviso) {
    if (-not (Test-DiscordRodando)) { return 'ok' }
    if ($cfg.AvisarAntesDeFechar -and -not (Ask-Proceed $mensagemAviso $cfg.SegundosAviso)) { return 'adiado' }
    if (Stop-DiscordApp -Log $script:LogInfra) { return 'ok' }
    return 'falhou'
}

# O mod escolhido esta MESMO aplicado? Conferido pelos arquivos, porque o exit
# code do instalador ja mentiu antes.
function Test-ModAplicadoOk($info) {
    $app = Get-DiscordAppDir
    return ($app -and (Get-DiscordPatchState $app) -eq 'patched' -and (Get-ModAplicado $app) -eq $info.Id)
}

function Repair([string]$motivo, [bool]$forcar) {
    $cfg  = Get-Config
    $info = Get-ModInfo $cfg.Mod
    $exe  = Join-Path $base $info.Exe
    $nome = $info.Nome

    if (-not (Test-Path $exe))     { Log "Instalador do $nome ausente ($exe) - abortando."; return }
    if (-not (Test-Path $discord)) { Log "Discord nao instalado."; return }

    $incompletos = Get-DiscordAppsIncompletos
    if ($incompletos) {
        Log "Ignorando update incompleto do Discord: $(($incompletos | ForEach-Object { $_.Name }) -join ', ')"
    }

    $app = Get-DiscordAppDir
    if (-not $app) { Log "Nenhuma versao completa do Discord - esperando o download terminar."; return }
    $ver = $app.Name

    # Versao nova zera o historico de falhas (quarentena e por versao).
    $st = Get-State
    if ($st.Versao -ne $ver) {
        $st.Versao = $ver; $st.Falhas = 0; $st.Quarentena = $false; Set-State $st
    }

    $estado     = Get-DiscordPatchState $app
    $modNoDisco = Get-ModAplicado $app

    if ($estado -eq 'patched' -and $modNoDisco -eq $info.Id) {
        # Mod certo aplicado. Mas o instalador poe SEMPRE o build padrao, entao
        # os plugins proprios podem ter sido substituidos sem que o patch mude
        # nada - some em silencio se ninguem conferir.
        if (Test-CustomBuildAtivo $cfg $info) {
            Log "$ver ja com $nome - nada a fazer. [$motivo]"
            return
        }

        Log "$ver com $nome, mas o build proprio NAO esta ativo - repondo. [$motivo]"
        $aviso = "Seus plugins proprios do $nome nao estao ativos." + [char]10 + [char]10 +
                 "O Discord vai fechar por alguns segundos e reabrir sozinho." + [char]10 + [char]10 +
                 "Repor agora?" + [char]10 +
                 "(Sem resposta, reponho em $($cfg.SegundosAviso)s.)"
        switch (Request-FecharDiscord $cfg $aviso) {
            'adiado' { Log "Usuario adiou a reposicao do build proprio. [$motivo]"; return }
            'falhou' { Log "Nao consegui fechar o Discord - adiando a reposicao."; return }
        }

        $reposto = Restore-CustomBuild $cfg $info
        if ($cfg.ReabrirDiscord) { $null = Start-DiscordApp -Log $script:LogInfra }
        if ($reposto) {
            if ($cfg.NotificarSucesso) {
                Show-Box "Discord Mod Auto-Repair" `
                    ("Build proprio restaurado." + [char]10 + [char]10 +
                     "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                     "Mod: $nome" + [char]10 + [char]10 +
                     "O Discord esta sendo reaberto com os seus plugins.") $false 8
            }
        } else {
            Show-Box "Discord Mod Auto-Repair - ATENCAO" `
                ("Nao consegui restaurar o seu build proprio." + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Origem: $($cfg.BuildPersonalizado)" + [char]10 + [char]10 +
                 "O Discord esta com o $nome padrao, sem os seus plugins.") $true 0
        }
        return
    }

    # Daqui pra baixo: precisa (re)aplicar o mod escolhido.
    if ($estado -eq 'patched' -and $modNoDisco -ne $info.Id) {
        $outro = if ($modNoDisco) { $modNoDisco } else { 'outro mod' }
        Log "$ver esta com '$outro', mas voce escolheu $nome - vou trocar. [$motivo]"
    }
    if ($estado -eq 'broken') { Log "$ver QUEBRADO (app.asar ausente) - o Discord nao abre assim. Vou restaurar." }

    if ($st.Quarentena -and -not $forcar) {
        Log "$ver em quarentena apos $($st.Falhas) falha(s) - nao vou mexer no Discord. [$motivo]"
        return
    }

    # ---- o Discord PRECISA estar fechado (senao o instalador falha) ----
    $aviso = "O $nome precisa ser aplicado no Discord." + [char]10 + [char]10 +
             "O Discord vai fechar por alguns segundos e reabrir sozinho." + [char]10 + [char]10 +
             "Aplicar agora?" + [char]10 +
             "(Sem resposta, aplico automaticamente em $($cfg.SegundosAviso)s.)"
    switch (Request-FecharDiscord $cfg $aviso) {
        'adiado' { Log "Usuario escolheu adiar. [$motivo]"; return }
        'falhou' {
            Log "Nao consegui fechar o Discord - adiando (nao vou arriscar corromper)."
            Show-Erro "$script:TituloApp - FALHA" `
                ("Nao consegui fechar o Discord para aplicar o $nome." + [char]10 + [char]10 +
                 "Feche o Discord manualmente e use o menu.bat (opcao 6).")
            return
        }
    }

    # Conta a tentativa ANTES de executar: se travar no meio, ainda conta.
    $st.Falhas = [int]$st.Falhas + 1
    Set-State $st

    Log "$ver ($estado): aplicando $nome... tentativa $($st.Falhas)/$($cfg.MaxTentativas) [$motivo]"
    $saida = & $exe -install -location $discord 2>&1 | Out-String
    $code  = $LASTEXITCODE
    # O instalador imprime icones unicode que viram lixo ilegivel ao serem
    # capturados ("OØi Failed!"). Como esse texto vai para a caixa de erro,
    # limpamos para sobrar a mensagem util.
    $saida = ($saida -replace '[^\x20-\x7E\r\n]', '').Trim()
    Log $saida
    Log "Instalador retornou $code."

    # Confere pelos arquivos, DUAS vezes: a segunda pega o updater do Discord
    # desfazendo o patch logo depois de ele ter sido aplicado.
    Start-Sleep -Seconds $script:EsperaAssentarSegundos
    $ok = Test-ModAplicadoOk $info
    if ($ok) {
        Start-Sleep -Seconds $script:EsperaReconferirSegundos
        $ok = Test-ModAplicadoOk $info
        if (-not $ok) { Log "O patch foi desfeito logo depois (updater do Discord ainda ativo)." }
    }
    $app = Get-DiscordAppDir

    if ($ok) {
        $st.Falhas = 0; $st.Quarentena = $false; Set-State $st
        Log "SUCESSO: $nome aplicado em $($app.Name)."

        # Devolve o build proprio ANTES de reabrir: com o Discord fechado o
        # .asar nao esta em uso e a copia nao falha.
        $buildOk     = Restore-CustomBuild $cfg $info
        $temBuild    = -not [string]::IsNullOrWhiteSpace([string]$cfg.BuildPersonalizado)
        $buildFalhou = ($temBuild -and -not $buildOk)
        $extraBuild  = ''
        if ($temBuild -and $buildOk) { $extraBuild = [char]10 + "Build proprio: restaurado." }

        # Perder o build proprio e silencioso demais para passar batido: o mod
        # volta, mas sem os plugins compilados por voce.
        if ($buildFalhou) {
            Show-Box "Discord Mod Auto-Repair - ATENCAO" `
                ("O $nome foi aplicado, mas NAO consegui restaurar o seu build proprio." + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Origem: $($cfg.BuildPersonalizado)" + [char]10 + [char]10 +
                 "O Discord vai abrir com o $nome padrao - seus plugins proprios nao estarao ativos." + [char]10 +
                 "Reconstrua o build (menu, opcao 13) e use a opcao 6.") $true 0
        }

        if ($cfg.ReabrirDiscord) { $null = Start-DiscordApp -Log $script:LogInfra }
        if ($cfg.NotificarSucesso -and -not $buildFalhou) {
            Show-Box "Discord Mod Auto-Repair" `
                ("$nome aplicado com sucesso!" + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Versao do Discord: $($app.Name)" + $extraBuild + [char]10 + [char]10 +
                 "O Discord esta sendo reaberto.") $false 8
        }
        return
    }

    # ---------------- falhou: devolver o Discord PURO e avisar ----------------
    Log "FALHA ao aplicar. Limpando o $nome para devolver o Discord original..."
    $limpeza = & $exe -uninstall -location $discord 2>&1 | Out-String
    Log (($limpeza -replace '[^\x20-\x7E\r\n]', '').Trim())

    $app     = Get-DiscordAppDir
    $estado2 = if ($app) { Get-DiscordPatchState $app } else { 'desconhecido' }
    Log "Estado depois da limpeza: $estado2"

    if ($cfg.ReabrirDiscord) { $null = Start-DiscordApp -Log $script:LogInfra }

    $extra = ''
    if ([int]$st.Falhas -ge [int]$cfg.MaxTentativas) {
        $st.Quarentena = $true; Set-State $st
        Log "QUARENTENA ativada para $ver - o vigia nao vai mais mexer nesta versao."
        $extra = [char]10 + [char]10 +
                 "O auto-reparo foi PAUSADO nesta versao do Discord depois de $($st.Falhas) tentativas," + [char]10 +
                 "para nao ficar fechando o Discord repetidamente." + [char]10 +
                 "Quando quiser tentar de novo: menu.bat -> opcao 6."
    }
    if ($estado2 -eq 'broken') {
        $extra += [char]10 + [char]10 +
                  "ATENCAO: o Discord ficou com arquivos faltando. Reinstale o Discord se ele nao abrir."
    }

    $txt = "Nao foi possivel aplicar o $nome." + [char]10 + [char]10 +
           "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
           "Versao do Discord: $ver" + [char]10 +
           "Codigo de saida: $code" + [char]10 + [char]10 +
           "Mensagem do instalador:" + [char]10 + $saida.Trim() + [char]10 + [char]10 +
           "O Discord foi restaurado para o original (sem mod)" +
           $(if ($cfg.ReabrirDiscord) { " e reaberto." } else { "." }) + $extra

    Show-Box "Discord Mod Auto-Repair - FALHA" $txt $true 0
}

# Espera o updater do Discord parar de trocar as pastas app-*.
function Wait-Settle {
    $ultima  = (Get-DiscordAppDir).Name
    $estavel = 0
    for ($i = 0; $i -lt $script:MaxCiclosEstabilizar; $i++) {
        Start-Sleep -Seconds $script:IntervaloVigiaSegundos
        $agora = (Get-DiscordAppDir).Name
        if ($agora -eq $ultima) { $estavel++ } else { $estavel = 0; $ultima = $agora }
        if ($estavel -ge $script:CiclosParaEstabilizar) { break }
    }
    return $ultima
}

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
