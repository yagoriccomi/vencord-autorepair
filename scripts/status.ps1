# Equicord Auto-Repair - status geral
# Uso particular. Todos os direitos reservados.
#
$base     = "$env:USERPROFILE\EquicordAutoRepair"
$discord  = "$env:LOCALAPPDATA\Discord"
$taskName = "Equicord Auto-Repair"

Write-Host "== Equicord Auto-Repair :: status ==" -ForegroundColor Cyan

# ---- Discord + patch ----
if (Test-Path $discord) {
    # So conta como versao valida se tiver Discord.exe E um .asar: um update
    # interrompido deixa a pasta so com os .dll/.exe e nao deve ser considerado.
    $todas = Get-ChildItem $discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue
    $completa = { param($p)
        (Test-Path (Join-Path $p 'Discord.exe')) -and
        ((Test-Path (Join-Path $p 'resources\app.asar')) -or (Test-Path (Join-Path $p 'resources\_app.asar'))) }
    $app = $todas | Where-Object { & $completa $_.FullName } |
        Sort-Object @{ Expression = { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
        Select-Object -Last 1
    $incompletas = $todas | Where-Object { -not (& $completa $_.FullName) }

    if ($app) {
        Write-Host "Discord .......... instalado ($($app.Name))" -ForegroundColor Green
        $res  = Join-Path $app.FullName 'resources'
        $shim = Test-Path (Join-Path $res 'app.asar')
        $orig = Test-Path (Join-Path $res '_app.asar')
        if     ($shim -and $orig)      { Write-Host "Equicord .......... APLICADO" -ForegroundColor Green }
        elseif ($shim -and -not $orig) { Write-Host "Equicord .......... nao aplicado (Discord puro)" -ForegroundColor Yellow }
        else                           { Write-Host "Equicord .......... QUEBRADO - falta o app.asar, o Discord nao abre!" -ForegroundColor Red }
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
if (Get-Process Discord -ErrorAction SilentlyContinue) {
    Write-Host "Discord agora .... aberto"
} else {
    Write-Host "Discord agora .... fechado"
}

# ---- Tarefa ----
$t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Tarefa ........... registrada (ultima exec: $($info.LastRunTime))" -ForegroundColor Green
} else {
    Write-Host "Tarefa ........... NAO registrada" -ForegroundColor Yellow
}

# ---- Vigia ----
$proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'equicord-watch\.ps1' -and $_.CommandLine -notmatch 'Win32_Process' }
if ($proc) { Write-Host "Vigia ............ rodando (PID $(@($proc)[0].ProcessId))" -ForegroundColor Green }
else       { Write-Host "Vigia ............ parado" -ForegroundColor Yellow }

# ---- Quarentena ----
$stFile = "$base\state.json"
if (Test-Path $stFile) {
    try {
        $st = Get-Content $stFile -Raw | ConvertFrom-Json
        if ($st.Quarentena) {
            Write-Host "Auto-reparo ...... PAUSADO em $($st.Versao) apos $($st.Falhas) falha(s)" -ForegroundColor Red
            Write-Host "                   use a opcao [8] do menu para destravar" -ForegroundColor DarkGray
        } elseif ([int]$st.Falhas -gt 0) {
            Write-Host "Auto-reparo ...... ativo ($($st.Falhas) falha(s) em $($st.Versao))" -ForegroundColor Yellow
        } else {
            Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
        }
    } catch { }
} else {
    Write-Host "Auto-reparo ...... ativo, sem falhas" -ForegroundColor Green
}

# ---- Build personalizado (userplugins compilados por voce) ----
$cfgFile = "$base\config.json"
$cfgJson = $null
if (Test-Path $cfgFile) { try { $cfgJson = Get-Content $cfgFile -Raw | ConvertFrom-Json } catch { } }
$bp = if ($cfgJson) { [string]$cfgJson.BuildPersonalizado } else { '' }
if (-not [string]::IsNullOrWhiteSpace($bp)) {
    $dest = if ($cfgJson.AsarDoMod) { [string]$cfgJson.AsarDoMod } else { Join-Path $env:APPDATA 'Equicord\equicord.asar' }
    if (-not (Test-Path $bp)) {
        Write-Host "Build proprio .... configurado, mas o arquivo nao existe" -ForegroundColor Red
        Write-Host "                   $bp" -ForegroundColor DarkGray
    } elseif (-not (Test-Path $dest)) {
        Write-Host "Build proprio .... NAO aplicado (o Equicord nem esta instalado)" -ForegroundColor Yellow
    } elseif ((Get-FileHash $bp -Algorithm SHA256).Hash -eq (Get-FileHash $dest -Algorithm SHA256).Hash) {
        Write-Host "Build proprio .... ATIVO no Discord" -ForegroundColor Green
    } else {
        Write-Host "Build proprio .... NAO esta ativo - o Discord carrega o build padrao" -ForegroundColor Yellow
        Write-Host "                   use a opcao [3] do menu para aplicar" -ForegroundColor DarkGray
    }
}

# ---- Os scripts instalados estao iguais aos desta pasta? ----
# O vigia roda a COPIA instalada. Se voce atualizou o projeto e nao reinstalou,
# o que roda automaticamente ainda e a versao antiga (ja nos mordeu uma vez).
$desatualizados = @()
foreach ($f in @('equicord-watch.ps1', 'register-task.ps1', 'run-hidden.vbs', 'notify.vbs', 'config.ps1')) {
    $orig = Join-Path $PSScriptRoot $f
    $dest = Join-Path $base $f
    if (-not (Test-Path $orig)) { continue }
    if (-not (Test-Path $dest)) { $desatualizados += $f; continue }
    if ((Get-FileHash $orig -Algorithm SHA256).Hash -ne (Get-FileHash $dest -Algorithm SHA256).Hash) {
        $desatualizados += $f
    }
}
if ($desatualizados.Count -gt 0) {
    Write-Host "Versao ........... DESATUALIZADA - o que roda sozinho e mais antigo que esta pasta" -ForegroundColor Red
    Write-Host "                   ($($desatualizados -join ', '))" -ForegroundColor DarkGray
    Write-Host "                   rode a opcao [1] do menu para atualizar" -ForegroundColor DarkGray
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
