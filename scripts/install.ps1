# Discord Mod Auto-Repair - instalacao / troca de mod (sem admin).
# Uso particular. Todos os direitos reservados.
#
# 1) Baixa o instalador oficial do mod escolhido (com verificacao SHA256)
# 2) Fecha o Discord (obrigatorio: com ele aberto o patch FALHA), aplica e reabre
# 3) Restaura o build proprio, se houver
# 4) Instala o vigia e registra a tarefa agendada
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mods.ps1')

$InstallDir = "$env:USERPROFILE\DiscordModAutoRepair"
$Discord    = "$env:LOCALAPPDATA\Discord"
$Updater    = "$Discord\Update.exe"
$CfgFile    = "$InstallDir\config.json"

if (-not (Test-Path $Discord)) {
    Write-Host "Discord (stable) nao encontrado em %LOCALAPPDATA%\Discord. Instale o Discord primeiro." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copia os scripts do projeto para a pasta de instalacao
foreach ($f in @('mod-watch.ps1', 'mods.ps1', 'register-task.ps1', 'run-hidden.vbs', 'notify.vbs', 'config.ps1')) {
    Copy-Item "$PSScriptRoot\$f" $InstallDir -Force
}

# Le a escolha do mod (o menu grava antes de chamar isto)
$cfg = $null
if (Test-Path $CfgFile) { try { $cfg = Get-Content $CfgFile -Raw | ConvertFrom-Json } catch { } }
$modId    = if ($cfg -and $cfg.Mod) { [string]$cfg.Mod } else { 'equicord' }
$build    = if ($cfg) { [string]$cfg.BuildPersonalizado } else { '' }
$info     = Get-ModInfo $modId
$Exe      = Join-Path $InstallDir $info.Exe

Write-Host "== Discord Mod Auto-Repair :: instalacao ==" -ForegroundColor Cyan
Write-Host "Mod: $(Get-ModRotulo $cfg)" -ForegroundColor White

# Baixa o instalador se necessario
if (-not (Test-Path $Exe)) {
    Write-Host "Baixando $($info.Exe) ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $info.Url -OutFile $Exe -UseBasicParsing
}

# Verifica integridade
$hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $info.Sha256) {
    Write-Host "FALHA de checksum! Esperado $($info.Sha256), obtido $hash. Abortando." -ForegroundColor Red
    Remove-Item $Exe -Force
    exit 1
}
Write-Host "Checksum OK." -ForegroundColor Green

# O Discord PRECISA estar fechado: com ele aberto o instalador recusa
# ("files are used by a different process") e pode deixar tudo quebrado.
$estavaAberto = [bool](Get-Process Discord -ErrorAction SilentlyContinue)
if ($estavaAberto) {
    Write-Host "Fechando o Discord (obrigatorio para aplicar o patch)..." -ForegroundColor Yellow
    Get-Process Discord -ErrorAction SilentlyContinue | ForEach-Object { $null = $_.CloseMainWindow() }
    for ($i = 0; $i -lt 8; $i++) {
        Start-Sleep -Seconds 1
        if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) { break }
    }
    Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# Aplica o mod (se houver outro aplicado, o instalador desfaz antes)
Write-Host "Aplicando $($info.Nome) no Discord ..." -ForegroundColor Yellow
& $Exe -install -location $Discord
$code = $LASTEXITCODE

# Confere de verdade (o exit code sozinho nao basta)
Start-Sleep -Seconds 2
$app = Get-ChildItem $Discord -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
    Where-Object {
        (Test-Path (Join-Path $_.FullName 'Discord.exe')) -and
        ((Test-Path (Join-Path $_.FullName 'resources\app.asar')) -or
         (Test-Path (Join-Path $_.FullName 'resources\_app.asar'))) } |
    Sort-Object @{ Expression = { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0.0.0' } } } |
    Select-Object -Last 1

$aplicado = $app -and (Test-Path (Join-Path $app.FullName 'resources\_app.asar')) -and
            ((Get-ModAplicado $app) -eq $info.Id)

if ($aplicado) {
    Write-Host "$($info.Nome) aplicado em $($app.Name)." -ForegroundColor Green

    # Build proprio (ex.: Equicord com o GoLiveBypass compilado)
    if (-not [string]::IsNullOrWhiteSpace($build) -and $info.SuportaBuildProprio) {
        $destino = if ($cfg.AsarDoMod) { [string]$cfg.AsarDoMod } else { $info.Asar }
        if (Test-Path $build) {
            $pasta = Split-Path $destino -Parent
            if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }
            Copy-Item $build $destino -Force
            if ((Get-Item $build).Length -eq (Get-Item $destino).Length) {
                Write-Host "Build proprio restaurado." -ForegroundColor Green
            } else {
                Write-Host "Build proprio copiado pela metade!" -ForegroundColor Red
            }
        } else {
            Write-Host "Build proprio nao encontrado em $build - ficando com o build padrao." -ForegroundColor Yellow
            Write-Host "Use a opcao [13] do menu para gerar o build." -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "NAO foi possivel aplicar (codigo $code). Restaurando o Discord original..." -ForegroundColor Red
    & $Exe -uninstall -location $Discord
}

# Registra a tarefa de auto-reparo
& "$InstallDir\register-task.ps1"

# Reabre o Discord se ele estava aberto antes (conferindo se subiu mesmo)
if ($estavaAberto) {
    $subiu = $false
    if (Test-Path $Updater) {
        Start-Process $Updater -ArgumentList '--processStart', 'Discord.exe'
        for ($i = 0; $i -lt 12; $i++) {
            Start-Sleep -Seconds 1
            if (Get-Process Discord -ErrorAction SilentlyContinue) { $subiu = $true; break }
        }
    }
    if (-not $subiu -and $app) {
        $bin = Join-Path $app.FullName 'Discord.exe'
        if (Test-Path $bin) { Start-Process $bin; $subiu = $true }
    }
    if ($subiu) { Write-Host "Discord reaberto." -ForegroundColor Green }
    else        { Write-Host "Nao consegui reabrir o Discord - abra manualmente." -ForegroundColor Yellow }
}

Write-Host ""
if ($aplicado) {
    Write-Host "Concluido! Abra o Discord e procure '$($info.Nome)' nas configuracoes." -ForegroundColor Green
} else {
    Write-Host "Concluido com FALHA na aplicacao - o Discord esta intacto." -ForegroundColor Yellow
}
Write-Host "Arquivos em: $InstallDir" -ForegroundColor DarkGray
