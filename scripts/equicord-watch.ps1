# Equicord Auto-Repair - vigia
# Uso particular. Todos os direitos reservados.
#
# Reaplica o Equicord APENAS em dois momentos:
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
#   - Se falhar: limpa o Equicord, devolve o Discord PURO e avisa na tela.
#   - Depois de N falhas na mesma versao entra em QUARENTENA e para de mexer,
#     para nunca virar um ciclo de fechar/abrir o Discord infinitamente.
#
# Use -Once para uma verificacao unica; -Force ignora a quarentena.
param([switch]$Once, [switch]$Force)

$ErrorActionPreference = 'SilentlyContinue'
$base    = "$env:USERPROFILE\EquicordAutoRepair"
$discord = "$env:LOCALAPPDATA\Discord"
$exe     = "$base\EquilotlCli.exe"
$log     = "$base\watch.log"
$cfgFile = "$base\config.json"
$stFile  = "$base\state.json"
$notify  = "$base\notify.vbs"
$updater = "$discord\Update.exe"

function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8 }

# ---------------------------------------------------------------- config ----
function Get-Config {
    $d = [pscustomobject]@{
        NotificarSucesso    = $true   # caixa verde de "deu certo" (ligavel no menu)
        AvisarAntesDeFechar = $true   # pergunta antes de fechar o Discord
        SegundosAviso       = 8       # tempo do aviso ate seguir sozinho
        ReabrirDiscord      = $true   # reabre o Discord depois de mexer
        MaxTentativas       = 3       # falhas na mesma versao ate a quarentena
        BuildPersonalizado  = ''      # .asar de um build proprio (com userplugins);
                                      # vazio = usa o build padrao do Equilotl
        AsarDoMod           = ''      # destino; vazio = %APPDATA%\Equicord\equicord.asar
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

# ------------------------------------------------------------- interface ----
# Caixa de aviso lancada como processo separado: nao trava o vigia.
function Show-Box($titulo, $mensagem, $erro, $segundos) {
    if (-not (Test-Path $notify)) { return }
    try {
        $f = Join-Path $base ("msg-" + [guid]::NewGuid().ToString('N') + ".txt")
        Set-Content -Path $f -Value $mensagem -Encoding Unicode
        $tipo = if ($erro) { '1' } else { '0' }
        Start-Process wscript.exe -ArgumentList "`"$notify`"", "`"$f`"", "`"$titulo`"", $tipo, "$segundos" -WindowStyle Hidden
    } catch { }
}

# Pergunta Sim/Nao com contagem regressiva. Sem resposta = segue em frente.
function Ask-Proceed($mensagem, $segundos) {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $r = $wsh.Popup($mensagem, $segundos, 'Equicord Auto-Repair', 4 + 32)
        return ($r -ne 7)   # 7 = Nao ; 6 = Sim ; -1 = tempo esgotado
    } catch { return $true }
}

# --------------------------------------------------------------- Discord ----
# Uma pasta app-* so conta como versao de verdade se tiver o Discord.exe E um
# .asar em resources. O updater do Discord copia o Discord.exe ANTES do
# resources, e um download interrompido deixa a pasta so com os .dll/.exe:
# sem esta checagem o vigia elegia esse esqueleto como "versao atual", achava
# que estava quebrada e tentava patchear o que nem existe.
# Versao comparada como NUMERO (texto quebraria em 1.0.10000).
function Test-AppCompleto($dir) {
    (Test-Path (Join-Path $dir 'Discord.exe')) -and
    ((Test-Path (Join-Path $dir 'resources\app.asar')) -or
     (Test-Path (Join-Path $dir 'resources\_app.asar')))
}

function Get-AppDir {
    Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { Test-AppCompleto $_.FullName } |
        Sort-Object @{ Expression = {
            try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
        Select-Object -Last 1
}

# Pastas app-* que existem mas ainda nao terminaram de baixar.
function Get-AppIncompletos {
    Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-AppCompleto $_.FullName) }
}

# O Equicord renomeia app.asar -> _app.asar e poe um shim no lugar.
#   patched = os dois existem | pure = so o app.asar original
#   broken  = falta o app.asar -> o Discord ABRE E FECHA SOZINHO
function Get-PatchState($appDir) {
    $res  = Join-Path $appDir.FullName 'resources'
    $shim = Test-Path (Join-Path $res 'app.asar')
    $orig = Test-Path (Join-Path $res '_app.asar')
    if     ($shim -and $orig)       { 'patched' }
    elseif ($shim -and -not $orig)  { 'pure'    }
    else                            { 'broken'  }
}

function Stop-Discord {
    $p = Get-Process Discord -ErrorAction SilentlyContinue
    if (-not $p) { return $true }
    Log "Fechando o Discord para liberar os arquivos..."
    # O Discord normalmente so minimiza para a bandeja em vez de sair, entao
    # esperamos pouco pelo fechamento educado e partimos para o encerramento.
    foreach ($x in $p) { $null = $x.CloseMainWindow() }
    for ($i = 0; $i -lt 6; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) { break }
    }
    if (Get-Process Discord -ErrorAction SilentlyContinue) {
        Log "Discord foi para a bandeja - encerrando o processo."
        Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    Start-Sleep -Seconds 2   # folga para o Windows soltar os arquivos
    return (-not (Get-Process Discord -ErrorAction SilentlyContinue))
}

# Reabre o Discord e CONFERE se ele realmente subiu. O Update.exe (Squirrel)
# as vezes diz "About to launch" e nao sobe nada, entao existe um plano B.
function Start-Discord {
    # 1) jeito oficial: pelo Update.exe (preserva o auto-update do Discord)
    if (Test-Path $updater) {
        Start-Process $updater -ArgumentList '--processStart', 'Discord.exe'
        for ($i = 0; $i -lt 12; $i++) {
            Start-Sleep -Seconds 1
            if (Get-Process Discord -ErrorAction SilentlyContinue) { Log "Discord reaberto."; return $true }
        }
        Log "Update.exe nao subiu o Discord - tentando abrir direto."
    }
    # 2) plano B: executavel da versao mais nova
    $app = Get-AppDir
    if ($app) {
        $bin = Join-Path $app.FullName 'Discord.exe'
        if (Test-Path $bin) {
            Start-Process $bin
            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Seconds 1
                if (Get-Process Discord -ErrorAction SilentlyContinue) { Log "Discord reaberto (direto)."; return $true }
            }
        }
    }
    Log "NAO consegui reabrir o Discord."
    return $false
}

# ------------------------------------------------------ build personalizado ----
# O Equilotl instala SEMPRE o build padrao do Equicord. Quem compila a propria
# versao (src/userplugins) perde os plugins proprios a cada reparo, porque o
# patch passa a apontar para o .asar padrao. Esta funcao devolve o build proprio
# por cima do padrao, logo depois do patch e antes de reabrir o Discord.
# O build proprio e o que o Discord esta carregando de fato?
function Test-CustomBuildAtivo($cfg) {
    $origem = [string]$cfg.BuildPersonalizado
    if ([string]::IsNullOrWhiteSpace($origem)) { return $true }   # nao usa build proprio
    if (-not (Test-Path $origem))              { return $true }   # sem origem: avisado em Restore

    $destino = [string]$cfg.AsarDoMod
    if ([string]::IsNullOrWhiteSpace($destino)) {
        $destino = Join-Path $env:APPDATA 'Equicord\equicord.asar'
    }
    if (-not (Test-Path $destino)) { return $false }
    return ((Get-FileHash $origem -Algorithm SHA256).Hash -eq (Get-FileHash $destino -Algorithm SHA256).Hash)
}

function Restore-CustomBuild($cfg) {
    $origem = [string]$cfg.BuildPersonalizado
    if ([string]::IsNullOrWhiteSpace($origem)) { return $true }   # desligado: nada a fazer

    $destino = [string]$cfg.AsarDoMod
    if ([string]::IsNullOrWhiteSpace($destino)) {
        $destino = Join-Path $env:APPDATA 'Equicord\equicord.asar'
    }

    if (-not (Test-Path $origem)) {
        Log "Build personalizado nao encontrado em $origem - ficando com o build padrao."
        return $false
    }

    try {
        $pasta = Split-Path $destino -Parent
        if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }
        Copy-Item $origem $destino -Force -ErrorAction Stop
    } catch {
        Log "Falha ao restaurar o build personalizado: $($_.Exception.Message)"
        return $false
    }

    # confere que chegou inteiro (copia truncada = Discord que nao abre)
    $tamOrigem  = (Get-Item $origem).Length
    $tamDestino = if (Test-Path $destino) { (Get-Item $destino).Length } else { -1 }
    if ($tamOrigem -ne $tamDestino) {
        Log "Build personalizado copiado pela metade ($tamDestino de $tamOrigem bytes)."
        return $false
    }

    Log "Build personalizado restaurado ($([math]::Round($tamOrigem / 1MB, 1)) MB)."
    return $true
}

# ---------------------------------------------------------------- reparo ----
function Repair([string]$motivo, [bool]$forcar) {
    $cfg = Get-Config
    if (-not (Test-Path $exe))     { Log "Instalador ausente - abortando."; return }
    if (-not (Test-Path $discord)) { Log "Discord nao instalado."; return }

    $incompletos = Get-AppIncompletos
    if ($incompletos) {
        Log "Ignorando update incompleto do Discord: $(($incompletos | ForEach-Object { $_.Name }) -join ', ')"
    }

    $app = Get-AppDir
    if (-not $app) { Log "Nenhuma versao completa do Discord - esperando o download terminar."; return }
    $ver = $app.Name

    # Versao nova zera o historico de falhas (quarentena e por versao).
    $st = Get-State
    if ($st.Versao -ne $ver) {
        $st.Versao = $ver; $st.Falhas = 0; $st.Quarentena = $false; Set-State $st
    }

    $estado = Get-PatchState $app
    if ($estado -eq 'patched') {
        # O patch do Discord esta bom. Mas o Equilotl instala SEMPRE o build
        # padrao, entao os plugins proprios podem ter sido substituidos sem que
        # o patch mude nada - some em silencio se ninguem conferir.
        if (Test-CustomBuildAtivo $cfg) {
            Log "$ver ja com Equicord - nada a fazer. [$motivo]"
            return
        }

        Log "$ver com Equicord, mas o build personalizado NAO esta ativo - repondo. [$motivo]"
        if (Get-Process Discord -ErrorAction SilentlyContinue) {
            if ($cfg.AvisarAntesDeFechar) {
                $aviso = "Seus plugins proprios do Equicord nao estao ativos." + [char]10 + [char]10 +
                         "O Discord vai fechar por alguns segundos e reabrir sozinho." + [char]10 + [char]10 +
                         "Repor agora?" + [char]10 +
                         "(Sem resposta, reponho em $($cfg.SegundosAviso)s.)"
                if (-not (Ask-Proceed $aviso $cfg.SegundosAviso)) {
                    Log "Usuario adiou a reposicao do build personalizado. [$motivo]"
                    return
                }
            }
            if (-not (Stop-Discord)) { Log "Nao consegui fechar o Discord - adiando a reposicao."; return }
        }

        $reposto = Restore-CustomBuild $cfg
        if ($cfg.ReabrirDiscord) { $null = Start-Discord }
        if ($reposto) {
            if ($cfg.NotificarSucesso) {
                Show-Box "Equicord Auto-Repair" `
                    ("Build personalizado restaurado." + [char]10 + [char]10 +
                     "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 + [char]10 +
                     "O Discord esta sendo reaberto com os seus plugins.") $false 8
            }
        } else {
            Show-Box "Equicord Auto-Repair - ATENCAO" `
                ("Nao consegui restaurar o seu build personalizado." + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Origem: $($cfg.BuildPersonalizado)" + [char]10 + [char]10 +
                 "O Discord esta com o Equicord padrao, sem os seus plugins.") $true 0
        }
        return
    }
    if ($estado -eq 'broken')  { Log "$ver QUEBRADO (app.asar ausente) - o Discord nao abre assim. Vou restaurar." }

    if ($st.Quarentena -and -not $forcar) {
        Log "$ver em quarentena apos $($st.Falhas) falha(s) - nao vou mexer no Discord. [$motivo]"
        return
    }

    # ---- o Discord PRECISA estar fechado (senao o instalador falha) ----
    if (Get-Process Discord -ErrorAction SilentlyContinue) {
        if ($cfg.AvisarAntesDeFechar) {
            $aviso = "O Equicord precisa ser aplicado no Discord." + [char]10 + [char]10 +
                     "O Discord vai fechar por alguns segundos e reabrir sozinho." + [char]10 + [char]10 +
                     "Aplicar agora?" + [char]10 +
                     "(Sem resposta, aplico automaticamente em $($cfg.SegundosAviso)s.)"
            if (-not (Ask-Proceed $aviso $cfg.SegundosAviso)) {
                Log "Usuario escolheu adiar. [$motivo]"
                return
            }
        }
        if (-not (Stop-Discord)) {
            Log "Nao consegui fechar o Discord - adiando (nao vou arriscar corromper)."
            Show-Box "Equicord Auto-Repair - FALHA" `
                ("Nao consegui fechar o Discord para aplicar o Equicord." + [char]10 + [char]10 +
                 "Feche o Discord manualmente e use o menu.bat (opcao 3).") $true 0
            return
        }
    }

    # Conta a tentativa ANTES de executar: se travar no meio, ainda conta.
    $st.Falhas = [int]$st.Falhas + 1
    Set-State $st

    Log "$ver ($estado): aplicando Equicord... tentativa $($st.Falhas)/$($cfg.MaxTentativas) [$motivo]"
    $saida = & $exe -install -location $discord 2>&1 | Out-String
    $code  = $LASTEXITCODE
    # O instalador imprime icones unicode que viram lixo ilegivel ao serem
    # capturados ("OØi Failed!"). Como esse texto vai para a caixa de erro,
    # limpamos para sobrar a mensagem util.
    $saida = ($saida -replace '[^\x20-\x7E\r\n]', '').Trim()
    Log $saida
    Log "Instalador retornou $code."

    # Confere o resultado de verdade - o exit code sozinho ja mentiu antes.
    Start-Sleep -Seconds 3
    $app = Get-AppDir
    $ok  = ($app -and (Get-PatchState $app) -eq 'patched')
    if ($ok) {
        Start-Sleep -Seconds 12   # o updater do Discord ja desfez o patch aqui
        $app = Get-AppDir
        $ok  = ($app -and (Get-PatchState $app) -eq 'patched')
        if (-not $ok) { Log "O patch foi desfeito logo depois (updater do Discord ainda ativo)." }
    }

    if ($ok) {
        $st.Falhas = 0; $st.Quarentena = $false; Set-State $st
        Log "SUCESSO: Equicord aplicado em $($app.Name)."

        # Devolve o build proprio ANTES de reabrir: com o Discord fechado o
        # .asar nao esta em uso e a copia nao falha.
        $buildOk     = Restore-CustomBuild $cfg
        $temBuild    = -not [string]::IsNullOrWhiteSpace([string]$cfg.BuildPersonalizado)
        $buildFalhou = ($temBuild -and -not $buildOk)
        $extraBuild  = ''
        if ($temBuild -and $buildOk) { $extraBuild = [char]10 + "Build personalizado: restaurado." }

        # Perder o build proprio e silencioso demais para passar batido: o
        # Equicord volta, mas sem os plugins compilados por voce.
        if ($buildFalhou) {
            Show-Box "Equicord Auto-Repair - ATENCAO" `
                ("O Equicord foi aplicado, mas NAO consegui restaurar o seu build personalizado." + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Origem: $($cfg.BuildPersonalizado)" + [char]10 + [char]10 +
                 "O Discord vai abrir com o Equicord padrao - seus plugins proprios nao estarao ativos." + [char]10 +
                 "Reconstrua o build (menu, opcao 13) e use a opcao 3.") $true 0
        }

        if ($cfg.ReabrirDiscord) { $null = Start-Discord }
        if ($cfg.NotificarSucesso -and -not $buildFalhou) {
            Show-Box "Equicord Auto-Repair" `
                ("Equicord aplicado com sucesso!" + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Versao do Discord: $($app.Name)" + $extraBuild + [char]10 + [char]10 +
                 "O Discord esta sendo reaberto.") $false 8
        }
        return
    }

    # ---------------- falhou: devolver o Discord PURO e avisar ----------------
    Log "FALHA ao aplicar. Limpando o Equicord para devolver o Discord original..."
    $limpeza = & $exe -uninstall -location $discord 2>&1 | Out-String
    Log (($limpeza -replace '[^\x20-\x7E\r\n]', '').Trim())

    $app     = Get-AppDir
    $estado2 = if ($app) { Get-PatchState $app } else { 'desconhecido' }
    Log "Estado depois da limpeza: $estado2"

    if ($cfg.ReabrirDiscord) { $null = Start-Discord }

    $extra = ''
    if ([int]$st.Falhas -ge [int]$cfg.MaxTentativas) {
        $st.Quarentena = $true; Set-State $st
        Log "QUARENTENA ativada para $ver - o vigia nao vai mais mexer nesta versao."
        $extra = [char]10 + [char]10 +
                 "O auto-reparo foi PAUSADO nesta versao do Discord depois de $($st.Falhas) tentativas," + [char]10 +
                 "para nao ficar fechando o Discord repetidamente." + [char]10 +
                 "Quando quiser tentar de novo: menu.bat -> opcao 3."
    }
    if ($estado2 -eq 'broken') {
        $extra += [char]10 + [char]10 +
                  "ATENCAO: o Discord ficou com arquivos faltando. Reinstale o Discord se ele nao abrir."
    }

    $txt = "Nao foi possivel aplicar o Equicord." + [char]10 + [char]10 +
           "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
           "Versao do Discord: $ver" + [char]10 +
           "Codigo de saida: $code" + [char]10 + [char]10 +
           "Mensagem do instalador:" + [char]10 + $saida.Trim() + [char]10 + [char]10 +
           "O Discord foi restaurado para o original (sem Equicord)" +
           $(if ($cfg.ReabrirDiscord) { " e reaberto." } else { "." }) + $extra

    Show-Box "Equicord Auto-Repair - FALHA" $txt $true 0
}

# Espera o updater do Discord parar de trocar as pastas app-*.
function Wait-Settle {
    $ultima  = (Get-AppDir).Name
    $estavel = 0
    for ($i = 0; $i -lt 120; $i++) {
        Start-Sleep -Seconds 5
        $agora = (Get-AppDir).Name
        if ($agora -eq $ultima) { $estavel++ } else { $estavel = 0; $ultima = $agora }
        if ($estavel -ge 6) { break }   # 30s sem nenhuma mudanca
    }
    return $ultima
}

# ------------------------------------------------------------------ main ----
if ($Once) { Repair 'manual' ([bool]$Force); return }

# Instancia unica via mutex nomeado (nao mata processo nenhum).
$script:mtx = New-Object System.Threading.Mutex($false, 'EquicordAutoRepairWatcher')
$owns = $false
try { $owns = $script:mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owns = $true }
if (-not $owns) { Log "Ja existe um vigia rodando - saindo."; return }

# Estado inicial: NAO aplica nada agora. So registra a linha de base.
$lastVer    = (Get-AppDir).Name
$wasRunning = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
Log "Vigia iniciado (sem aplicar nada agora). Base: $lastVer, Discord aberto=$wasRunning"

while ($true) {
    Start-Sleep -Seconds 5
    $cur     = (Get-AppDir).Name
    $running = [bool](Get-Process Discord -ErrorAction SilentlyContinue)

    if ($cur -and $cur -ne $lastVer) {
        Log "Mudanca de versao: $lastVer -> $cur. Esperando o Discord terminar de atualizar..."
        $lastVer = Wait-Settle
        Log "Versao estabilizada em $lastVer."
        Repair 'update do Discord' $false
    }
    elseif ($running -and -not $wasRunning) {
        Start-Sleep -Seconds 5
        Repair 'abertura do Discord' $false
    }

    # Relido DEPOIS do reparo: o proprio reparo fecha/reabre o Discord.
    $wasRunning = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
}
