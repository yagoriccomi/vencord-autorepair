# Vencord Auto-Repair - configuracao
# Copyright (C) 2026 yagoriccomi
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Le e altera as opcoes do auto-reparo (usado pelo menu.bat).
param([ValidateSet('mostrar', 'sucesso', 'aviso', 'reabrir', 'resetar')][string]$Action = 'mostrar')

$base    = "$env:USERPROFILE\Vencord"
$cfgFile = "$base\config.json"
$stFile  = "$base\state.json"

function Get-Config {
    $d = [pscustomobject]@{
        NotificarSucesso    = $true
        AvisarAntesDeFechar = $true
        SegundosAviso       = 8
        ReabrirDiscord      = $true
        MaxTentativas       = 3
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
        Write-Host "O auto-reparo vai voltar a tentar normalmente." -ForegroundColor DarkGray
    }
    default {
        Write-Host "== Opcoes atuais ==" -ForegroundColor Cyan
        Write-Host "  Avisar quando der certo .......... $(OnOff $cfg.NotificarSucesso)"
        Write-Host "  Avisar quando der errado ......... SEMPRE (fixo)"
        Write-Host "  Perguntar antes de fechar ........ $(OnOff $cfg.AvisarAntesDeFechar) ($($cfg.SegundosAviso)s)"
        Write-Host "  Reabrir o Discord sozinho ........ $(OnOff $cfg.ReabrirDiscord)"
        Write-Host "  Tentativas antes de pausar ....... $($cfg.MaxTentativas)"
    }
}
