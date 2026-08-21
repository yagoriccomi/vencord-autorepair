# Discord Mod Auto-Repair - regra de negocio do reparo
# Uso particular. Todos os direitos reservados.
#
# Este arquivo contem SOMENTE definicoes: carrega-lo nao executa nada e nao
# toca no Discord. E o que permite testar a regra de negocio sem disparar o
# vigia. O ponto de entrada (mutex + laco de observacao) mora em mod-watch.ps1.
# 'Stop' de proposito: este codigo fecha o Discord e troca binarios. Erro
# engolido aqui significa decidir sobre um estado que falhou em silencio - foi
# assim que o Discord acabou quebrado antes. Os pontos que PODEM falhar
# legitimamente (config/estado corrompidos, sondagem de processo) tem try/catch
# ou -ErrorAction proprios, e sao cobertos por teste.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mods.ps1')
. (Join-Path $PSScriptRoot 'discord.ps1')
. (Join-Path $PSScriptRoot 'ui.ps1')

$base    = "$env:USERPROFILE\DiscordModAutoRepair"
$discord = "$env:LOCALAPPDATA\Discord"
$log     = "$base\watch.log"
$cfgFile = "$base\config.json"
$stFile  = "$base\state.json"

$script:LogMaxBytes = 1MB

# Rotaciona antes de escrever: o vigia registra desde o logon, a cada abertura
# do Discord e a cada atualizacao - sem limite, o arquivo cresceria para sempre
# e ficaria inutil justamente para diagnosticar.
function Log($m) {
    try {
        if ((Test-Path $log) -and (Get-Item $log).Length -gt $script:LogMaxBytes) {
            Move-Item $log "$log.1" -Force -ErrorAction SilentlyContinue
        }
    } catch { }
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8
}

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
    # Escrita ATOMICA: copia para um temporario, confere o tamanho e so entao
    # promove por rename (atomico no mesmo volume).
    #
    # Copiar 16MB direto sobre o .asar vivo abre uma janela em que uma
    # interrupcao (queda de energia, disco cheio, antivirus travando o arquivo)
    # deixa o destino truncado e o Discord sem abrir - exatamente o sintoma que
    # este projeto existe para evitar. Conferir depois de copiar por cima so
    # detecta o estrago; nao evita.
    $temp = "$destino.novo"
    $tamOrigem = 0
    try {
        $pasta = Split-Path $destino -Parent
        if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }

        Copy-Item $origem $temp -Force -ErrorAction Stop

        $tamOrigem = (Get-Item $origem).Length
        $tamTemp   = (Get-Item $temp).Length
        if ($tamOrigem -ne $tamTemp) {
            Log "Build proprio copiado pela metade ($tamTemp de $tamOrigem bytes) - descartando o temporario e mantendo o build atual."
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            return $false
        }

        Move-Item $temp $destino -Force -ErrorAction Stop
    } catch {
        Log "Falha ao restaurar o build proprio: $($_.Exception.Message)"
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
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
    if ($cfg.AvisarAntesDeFechar -and -not (Confirm-Proceed $mensagemAviso $cfg.SegundosAviso)) { return 'adiado' }
    if (Stop-DiscordApp -Log $script:LogInfra) { return 'ok' }
    return 'falhou'
}

# O mod escolhido esta MESMO aplicado? Conferido pelos arquivos, porque o exit
# code do instalador ja mentiu antes.
function Test-ModAplicadoOk($info) {
    $app = Get-DiscordAppDir
    return ($app -and (Get-DiscordPatchState $app) -eq 'patched' -and (Get-ModAplicado $app) -eq $info.Id)
}

# Executa o instalador e captura saida + codigo de retorno.
#
# O 2>&1 PRECISA rodar com 'Continue': o PowerShell 5.1 embrulha CADA linha de
# stderr de um .exe num ErrorRecord, e sob 'Stop' isso vira erro terminante
# mesmo quando o instalador apenas escreveu "INFO Patching..." e teve sucesso.
# O resultado real e decidido pelo exit code e pela conferencia dos ARQUIVOS -
# nunca pelo stream de erro.
function Invoke-Instalador($exe, [string[]]$argumentos) {
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & $exe @argumentos 2>&1 | Out-String
        return [pscustomobject]@{
            Codigo = $LASTEXITCODE
            # Os icones unicode do instalador viram lixo ilegivel na captura
            # ("OOi Failed!") e esse texto vai para a caixa de erro do usuario.
            Saida  = ($saida -replace '[^\x20-\x7E\r\n]', '').Trim()
        }
    } finally { $ErrorActionPreference = $anterior }
}

$script:NomeMutexOperacao = 'DiscordModAutoRepairOperacao'

# Serializa QUALQUER reparo, venha do vigia ou do menu (-Once).
#
# Nao da para reaproveitar o mutex do vigia: aquele e de TEMPO DE VIDA (fica
# preso enquanto o vigia existir), entao o -Once nunca conseguiria adquiri-lo
# e a opcao do menu nunca funcionaria. Este e de OPERACAO: so dura o reparo.
#
# Sem isto, um reparo manual e um automatico rodavam o instalador nos MESMOS
# arquivos ao mesmo tempo - observado em producao com 2s de diferenca. Duas
# escritas simultaneas no mesmo .asar podem corromper a instalacao.
#
# WaitOne(0) em vez de esperar: se ja ha um reparo rodando, nao faz sentido
# enfileirar outro - o trabalho ja esta sendo feito.
function Invoke-ComTravaDeOperacao([scriptblock]$Acao) {
    $mtx   = New-Object System.Threading.Mutex($false, $script:NomeMutexOperacao)
    $tenho = $false
    try { $tenho = $mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $tenho = $true }

    if (-not $tenho) {
        Log "Outro reparo ja esta em andamento - saindo para nao mexer nos mesmos arquivos."
        $mtx.Dispose()
        return
    }
    try { & $Acao } finally { $mtx.ReleaseMutex(); $mtx.Dispose() }
}

function Repair([string]$motivo, [bool]$forcar) {
    Invoke-ComTravaDeOperacao {
        # Falha ALTA mas CONTIDA: um erro inesperado precisa aparecer (nao ser
        # engolido), sem derrubar o vigia - que precisa continuar vivo para a
        # proxima atualizacao do Discord.
        try {
            Invoke-Repair $motivo $forcar
        } catch {
            Log "ERRO INESPERADO no reparo: $($_.Exception.Message)"
            Log $_.ScriptStackTrace
            Show-Erro "$script:TituloApp - ERRO" `
                ("O auto-reparo encontrou um erro inesperado e parou por seguranca." + [char]10 + [char]10 +
                 "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
                 "Erro: $($_.Exception.Message)" + [char]10 + [char]10 +
                 "Confira o Discord e o log (menu, opcao 12).")
        }
    }
}

function Invoke-Repair([string]$motivo, [bool]$forcar) {
    $cfg  = Get-Config
    $info = Get-ModInfo $cfg.Mod
    $exe  = Join-Path $base $info.Exe
    $nome = $info.Nome

    if (-not (Test-Path $exe)) { Log "Instalador do $nome ausente ($exe) - abortando."; return }

    # Integridade conferida a CADA execucao, nao so na instalacao: este codigo
    # roda sozinho e sem supervisao. Checksum divergente e exatamente o que o
    # usuario precisa saber, entao avisa na tela em vez de so registrar.
    if (-not (Test-InstaladorConfiavel $exe $info)) {
        Log "ABORTADO: o instalador em $exe nao confere com o checksum oficial."
        Show-Erro "$script:TituloApp - INSTALADOR SUSPEITO" `
            ("O instalador do $nome nao confere com o checksum oficial." + [char]10 + [char]10 +
             "Quando: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" + [char]10 +
             "Arquivo: $exe" + [char]10 + [char]10 +
             "Nada foi executado e o Discord nao foi tocado." + [char]10 +
             "Apague esse arquivo e reinstale pelo menu (opcao 4).")
        return
    }

    if (-not (Test-Path $discord)) { Log "Discord nao instalado."; return }

    $incompletos = Get-DiscordAppIncompleto
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
    $execucao = Invoke-Instalador $exe @('-install', '-location', $discord)
    $saida = $execucao.Saida
    $code  = $execucao.Codigo
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
    Log (Invoke-Instalador $exe @('-uninstall', '-location', $discord)).Saida

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

