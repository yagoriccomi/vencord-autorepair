# Discord Mod Auto-Repair - roda a suite de testes
# Uso particular. Todos os direitos reservados.
#
# Os testes NAO tocam no Discord real: desviam %LOCALAPPDATA%/%USERPROFILE%
# para pastas temporarias e mockam processos, instaladores e janelas.
# Sai com codigo != 0 se algo falhar, para servir de gate no CI.

$ErrorActionPreference = 'Stop'
$raiz  = Split-Path $PSScriptRoot -Parent
$testes = Join-Path $raiz 'tests'

$pester = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' } |
    Sort-Object Version -Descending | Select-Object -First 1

if (-not $pester) {
    Write-Host "Pester 5+ nao encontrado. Instale com:" -ForegroundColor Red
    Write-Host "  Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck" -ForegroundColor Yellow
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0 -Force
Write-Host "Pester $((Get-Module Pester).Version) | testes em $testes" -ForegroundColor DarkGray

$cfg = New-PesterConfiguration
$cfg.Run.Path          = $testes
$cfg.Run.PassThru      = $true
$cfg.Output.Verbosity  = 'Detailed'

$r = Invoke-Pester -Configuration $cfg

Write-Host ""
if ($r.FailedCount -gt 0) {
    Write-Host "$($r.FailedCount) teste(s) FALHARAM de $($r.TotalCount)." -ForegroundColor Red
    exit 1
}
Write-Host "Todos os $($r.PassedCount) testes passaram." -ForegroundColor Green
exit 0
