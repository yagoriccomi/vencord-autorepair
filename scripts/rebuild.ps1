# Discord Mod Auto-Repair - reconstruir o build personalizado
# Uso particular. Todos os direitos reservados.
#
# Roda "pnpm build" no projeto do Equicord (aquele com src/userplugins) para
# regerar o .asar que o auto-reparo restaura depois de cada patch.
$base    = "$env:USERPROFILE\DiscordModAutoRepair"
$cfgFile = "$base\config.json"

$cfg = $null
if (Test-Path $cfgFile) { try { $cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json } catch { } }

$asar = if ($cfg) { [string]$cfg.BuildPersonalizado } else { '' }
if ([string]::IsNullOrWhiteSpace($asar)) {
    Write-Host "Nenhum build personalizado configurado." -ForegroundColor Yellow
    Write-Host "Defina BuildPersonalizado em $cfgFile" -ForegroundColor DarkGray
    exit 0
}

# dist\desktop.asar  ->  raiz do projeto
$fonte = Split-Path (Split-Path $asar -Parent) -Parent
if (-not (Test-Path (Join-Path $fonte 'package.json'))) {
    Write-Host "Nao encontrei o projeto em $fonte (sem package.json)." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "pnpm nao esta no PATH - nao da para reconstruir." -ForegroundColor Red
    exit 1
}

Write-Host "Reconstruindo o Equicord em $fonte ..." -ForegroundColor Yellow
Write-Host "(pode demorar um pouco)" -ForegroundColor DarkGray

$code = 1
Push-Location $fonte
try { & pnpm build; $code = $LASTEXITCODE } finally { Pop-Location }

if ($code -ne 0) {
    Write-Host "pnpm build falhou (codigo $code)." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $asar)) {
    Write-Host "O build terminou, mas $asar nao existe. Confira o caminho em config.json." -ForegroundColor Red
    exit 1
}

$mb = [math]::Round((Get-Item $asar).Length / 1MB, 1)
Write-Host "Build refeito: $asar ($mb MB)" -ForegroundColor Green
Write-Host "Use a opcao [3] do menu para aplicar no Discord." -ForegroundColor DarkGray
