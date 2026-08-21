# Discord Mod Auto-Repair - configuracao
# Uso particular. Todos os direitos reservados.
#
# Le e altera as opcoes do auto-reparo (usado pelo menu.bat).
param([ValidateSet('mostrar', 'rotulo', 'vencord', 'equicord', 'equicord-golive',
                   'sucesso', 'aviso', 'reabrir', 'resetar')]
      [string]$Action = 'mostrar')

. (Join-Path $PSScriptRoot 'mods.ps1')

$base    = "$env:USERPROFILE\DiscordModAutoRepair"
$cfgFile = "$base\config.json"
$stFile  = "$base\state.json"

function Get-Config {
    $d = [pscustomobject]@{
        Mod                 = 'equicord'
        NotificarSucesso    = $true
        AvisarAntesDeFechar = $true
        SegundosAviso       = 8
        ReabrirDiscord      = $true
        MaxTentativas       = 3
        BuildPersonalizado  = ''
        AsarDoMod           = ''
    }
    if (Test-Path $cfgFile) {
        try {
            $j = Get-Content $cfgFile -Raw | ConvertFrom-Json
            foreach ($k in @($d.PSObject.Properties.Name)) { if ($null -ne $j.$k) { $d.$k = $j.$k } }
        } catch { }
    }
    $d
}
function Set-Config($c) {
    New-Item -ItemType Directory -Force -Path $base | Out-Null
    $c | ConvertTo-Json | Set-Content -Path $cfgFile -Encoding utf8
}
function OnOff($b) { if ($b) { "LIGADO" } else { "desligado" } }

$cfg = Get-Config

switch ($Action) {

    # ------------------------------------------------ escolha do mod ----
    'vencord' {
        $cfg.Mod = 'vencord'
        $cfg.BuildPersonalizado = ''
        Set-Config $cfg
        Write-Host "Mod escolhido: Vencord" -ForegroundColor Green
        Write-Host "Use a opcao [4] do menu para aplicar no Discord." -ForegroundColor DarkGray
    }

    'equicord' {
        $cfg.Mod = 'equicord'
        $cfg.BuildPersonalizado = ''
        Set-Config $cfg
        Write-Host "Mod escolhido: Equicord (build padrao)" -ForegroundColor Green
        Write-Host "Sem o GoLiveBypass." -ForegroundColor DarkGray
        Write-Host "Use a opcao [4] do menu para aplicar no Discord." -ForegroundColor DarkGray
    }

    'equicord-golive' {
        $padrao = "$env:USERPROFILE\Equicord\dist\desktop.asar"
        $cfg.Mod = 'equicord'
        if ([string]::IsNullOrWhiteSpace([string]$cfg.BuildPersonalizado)) {
            $cfg.BuildPersonalizado = $padrao
        }
        Set-Config $cfg
        Write-Host "Mod escolhido: Equicord + GoLiveBypass (build proprio)" -ForegroundColor Green
        Write-Host "Build: $($cfg.BuildPersonalizado)" -ForegroundColor DarkGray

        if (-not (Test-Path $cfg.BuildPersonalizado)) {
            Write-Host ""
            Write-Host "ATENCAO: esse arquivo nao existe ainda." -ForegroundColor Yellow
            Write-Host "O GoLiveBypass precisa estar em src/userplugins do seu Equicord" -ForegroundColor DarkGray
            Write-Host "e o build precisa ser gerado. Use a opcao [13] do menu (pnpm build)." -ForegroundColor DarkGray
        } else {
            $mb = [math]::Round((Get-Item $cfg.BuildPersonalizado).Length / 1MB, 1)
            Write-Host "Build encontrado ($mb MB)." -ForegroundColor Green
            Write-Host "Use a opcao [4] do menu para aplicar no Discord." -ForegroundColor DarkGray
        }
    }

    # ------------------------------------------------------ ajustes ----
    'sucesso' {
        $cfg.NotificarSucesso = -not $cfg.NotificarSucesso
        Set-Config $cfg
        Write-Host "Aviso de SUCESSO agora esta: $(OnOff $cfg.NotificarSucesso)" -ForegroundColor Green
        Write-Host "(o aviso de FALHA aparece sempre, nao da para desligar)" -ForegroundColor DarkGray
    }
    'aviso' {
        $cfg.AvisarAntesDeFechar = -not $cfg.AvisarAntesDeFechar
        Set-Config $cfg
        Write-Host "Aviso ANTES de fechar o Discord agora esta: $(OnOff $cfg.AvisarAntesDeFechar)" -ForegroundColor Green
    }
    'reabrir' {
        $cfg.ReabrirDiscord = -not $cfg.ReabrirDiscord
        Set-Config $cfg
        Write-Host "Reabrir o Discord automaticamente agora esta: $(OnOff $cfg.ReabrirDiscord)" -ForegroundColor Green
    }
    'resetar' {
        if (Test-Path $stFile) { Remove-Item $stFile -Force -ErrorAction SilentlyContinue }
        Write-Host "Quarentena e contador de falhas zerados." -ForegroundColor Green
    }

    # Linha unica para o menu.bat mostrar no cabecalho.
    'rotulo' {
        if (Test-Path $cfgFile) { Get-ModRotulo $cfg }
        else { (Get-ModRotulo $cfg) + '   [padrao - voce ainda nao escolheu]' }
    }

    default {
        Write-Host "== Opcoes atuais ==" -ForegroundColor Cyan
        Write-Host "  Mod escolhido .................... $(Get-ModRotulo $cfg)" -ForegroundColor White
        if (-not [string]::IsNullOrWhiteSpace([string]$cfg.BuildPersonalizado)) {
            Write-Host "  Build proprio .................... $($cfg.BuildPersonalizado)"
        }
        Write-Host "  Avisar quando der certo .......... $(OnOff $cfg.NotificarSucesso)"
        Write-Host "  Avisar quando der errado ......... SEMPRE (fixo)"
        Write-Host "  Perguntar antes de fechar ........ $(OnOff $cfg.AvisarAntesDeFechar) ($($cfg.SegundosAviso)s)"
        Write-Host "  Reabrir o Discord sozinho ........ $(OnOff $cfg.ReabrirDiscord)"
        Write-Host "  Tentativas antes de pausar ....... $($cfg.MaxTentativas)"
    }
}
