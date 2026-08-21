# Discord Mod Auto-Repair - status geral
# Uso particular. Todos os direitos reservados.
. (Join-Path $PSScriptRoot 'mods.ps1')
. (Join-Path $PSScriptRoot 'discord.ps1')

$base     = "$env:USERPROFILE\DiscordModAutoRepair"
$discord  = "$env:LOCALAPPDATA\Discord"
$taskName = "Discord Mod Auto-Repair"
$cfgFile  = "$base\config.json"

$cfg = $null
if (Test-Path $cfgFile) { try { $cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json } catch { } }
$modId = if ($cfg -and $cfg.Mod) { [string]$cfg.Mod } else { 'equicord' }
$info  = Get-ModInfo $modId

Write-Host "== Discord Mod Auto-Repair :: status ==" -ForegroundColor Cyan
Write-Host "Mod escolhido .... $(if ($cfg) { Get-ModRotulo $cfg } else { 'nada configurado ainda' })" -ForegroundColor White

# ---- Discord + patch ----
if (Test-Path $discord) {
    $app         = Get-DiscordAppDir
    $incompletas = Get-DiscordAppsIncompletos

    if ($app) {
        Write-Host "Discord .......... instalado ($($app.Name))" -ForegroundColor Green
        $patch = Get-DiscordPatchState $app
        if ($patch -eq 'patched') {
            $aplicado = Get-ModAplicado $app
            $nomeAp = switch ($aplicado) {
                'equicord' { 'Equicord' }
                'vencord'  { 'Vencord' }
                default    { 'um mod desconhecido' }
            }
            if ($aplicado -eq $info.Id) {
                Write-Host "Mod aplicado ..... $nomeAp (APLICADO)" -ForegroundColor Green
            } else {
                Write-Host "Mod aplicado ..... $nomeAp - DIFERENTE do escolhido!" -ForegroundColor Yellow
                Write-Host "                   use a opcao [4] do menu para trocar" -ForegroundColor DarkGray
            }
        }
        elseif ($patch -eq 'pure') { Write-Host "Mod aplicado ..... nenhum (Discord puro)" -ForegroundColor Yellow }
        else                       { Write-Host "Mod aplicado ..... QUEBRADO - falta o app.asar, o Discord nao abre!" -ForegroundColor Red }
    } else {
        Write-Host "Discord .......... pasta existe, mas sem versao completa" -ForegroundColor Yellow
    }
    if ($incompletas) {
        Write-Host "Update pendente .. $(($incompletas | ForEach-Object { $_.Name }) -join ', ') - baixado pela metade, ignorado" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "Discord .......... nao encontrado" -ForegroundColor Red
}

# ---- Discord rodando ----
if (Test-DiscordRodando) {
    Write-Host "Discord agora .... aberto"
} else {
    Write-Host "Discord agora .... fechado"
}

# ---- Tarefa ----
$t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($t) {
    $tinfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Tarefa ........... registrada (ultima exec: $($tinfo.LastRunTime))" -ForegroundColor Green
} else {
    Write-Host "Tarefa ........... NAO registrada" -ForegroundColor Yellow
}

# ---- Vigia ----
$proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'mod-watch\.ps1' -and $_.CommandLine -notmatch 'Win32_Process' }
if ($proc) { Write-Host "Vigia ............ rodando (PID $(@($proc)[0].ProcessId))" -ForegroundColor Green }
else       { Write-Host "Vigia ............ parado" -ForegroundColor Yellow }

# ---- Quarentena ----
$stFile = "$base\state.json"
if (Test-Path $stFile) {
    try {
        $st = Get-Content $stFile -Raw | ConvertFrom-Json
        if ($st.Quarentena) {
            Write-Host "Auto-reparo ...... PAUSADO em $($st.Versao) apos $($st.Falhas) falha(s)" -ForegroundColor Red
            Write-Host "                   use a opcao [11] do menu para destravar" -ForegroundColor DarkGray
        } elseif ([int]$st.Falhas -gt 0) {
            Write-Host "Auto-reparo ...... ativo ($($st.Falhas) falha(s) em $($st.Versao))" -ForegroundColor Yellow
        } else {
            Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
        }
    } catch { }
} else {
    Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
}

# ---- Build proprio (userplugins compilados por voce, ex.: GoLiveBypass) ----
$bp = if ($cfg) { [string]$cfg.BuildPersonalizado } else { '' }
if (-not [string]::IsNullOrWhiteSpace($bp) -and $info.SuportaBuildProprio) {
    $dest = if ($cfg.AsarDoMod) { [string]$cfg.AsarDoMod } else { $info.Asar }
    if (-not (Test-Path $bp)) {
        Write-Host "Build proprio .... configurado, mas o arquivo nao existe" -ForegroundColor Red
        Write-Host "                   $bp" -ForegroundColor DarkGray
        Write-Host "                   gere com a opcao [13] do menu" -ForegroundColor DarkGray
    } elseif (-not (Test-Path $dest)) {
        Write-Host "Build proprio .... NAO aplicado (o mod nem esta instalado)" -ForegroundColor Yellow
    } elseif ((Get-FileHash $bp -Algorithm SHA256).Hash -eq (Get-FileHash $dest -Algorithm SHA256).Hash) {
        Write-Host "Build proprio .... ATIVO no Discord" -ForegroundColor Green
    } else {
        Write-Host "Build proprio .... NAO esta ativo - o Discord carrega o build padrao" -ForegroundColor Yellow
        Write-Host "                   use a opcao [6] do menu para aplicar" -ForegroundColor DarkGray
    }
}

# ---- Os scripts instalados estao iguais aos desta pasta? ----
# O vigia roda a COPIA instalada. Se voce atualizou o projeto e nao reinstalou,
# o que roda automaticamente ainda e a versao antiga (ja nos mordeu uma vez).
$desatualizados = @()
foreach ($f in @('mod-watch.ps1', 'mods.ps1', 'discord.ps1', 'register-task.ps1', 'run-hidden.vbs', 'notify.vbs', 'config.ps1')) {
    $origem  = Join-Path $PSScriptRoot $f
    $destino = Join-Path $base $f
    if (-not (Test-Path $origem)) { continue }
    if (-not (Test-Path $destino)) { $desatualizados += $f; continue }
    if ((Get-FileHash $origem -Algorithm SHA256).Hash -ne (Get-FileHash $destino -Algorithm SHA256).Hash) {
        $desatualizados += $f
    }
}
if ($desatualizados.Count -gt 0) {
    Write-Host "Versao ........... DESATUALIZADA - o que roda sozinho e mais antigo que esta pasta" -ForegroundColor Red
    Write-Host "                   ($($desatualizados -join ', '))" -ForegroundColor DarkGray
    Write-Host "                   rode a opcao [4] do menu para atualizar" -ForegroundColor DarkGray
} else {
    Write-Host "Versao ........... instalada igual a desta pasta" -ForegroundColor Green
}

# ---- Config ----
Write-Host ""
if (Test-Path "$base\config.ps1") { & "$base\config.ps1" -Action mostrar }

# ---- Log ----
$log = "$base\watch.log"
if (Test-Path $log) {
    Write-Host ""
    Write-Host "-- ultimas linhas do log --" -ForegroundColor DarkGray
    Get-Content $log -Tail 8
}
