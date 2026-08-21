# Discord Mod Auto-Repair - abrir o Discord
# Uso particular. Todos os direitos reservados.
. (Join-Path $PSScriptRoot 'discord.ps1')

if (Test-DiscordRodando) {
    Write-Host "O Discord ja esta aberto." -ForegroundColor Green
    return
}
if (-not (Test-Path $script:DiscordDir)) {
    Write-Host "Discord nao encontrado." -ForegroundColor Red
    return
}

Write-Host "Abrindo o Discord..." -ForegroundColor Yellow
if (Start-DiscordApp -Log { param($m) Write-Host "  $m" -ForegroundColor DarkGray }) {
    Write-Host "Discord aberto." -ForegroundColor Green
} else {
    Write-Host "Nao consegui abrir o Discord." -ForegroundColor Red
}
