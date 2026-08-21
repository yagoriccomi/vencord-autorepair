# Discord Mod Auto-Repair - definicoes dos mods
# Uso particular. Todos os direitos reservados.
#
# Um lugar so para tudo que muda entre os mods suportados. Carregado por
# ponto-fonte (. mods.ps1) pelos demais scripts.

function Get-ModInfo([string]$mod) {
    switch ("$mod".ToLower()) {
        'vencord' {
            [pscustomobject]@{
                Id     = 'vencord'
                Nome   = 'Vencord'
                Exe    = 'VencordInstallerCli.exe'
                Url    = 'https://github.com/Vencord/Installer/releases/download/v1.4.0/VencordInstallerCli.exe'
                Sha256 = '466d2a0be1f380ddffed052df3cc132125fa34dc1af29312e14f13f358c8d2a2'
                Asar   = (Join-Path $env:APPDATA 'Vencord\vencord.asar')
            }
        }
        default {
            [pscustomobject]@{
                Id     = 'equicord'
                Nome   = 'Equicord'
                Exe    = 'EquilotlCli.exe'
                Url    = 'https://github.com/Equicord/Equilotl/releases/download/v2.2.6/EquilotlCli.exe'
                Sha256 = '79932382d859747318f642c3e23297c7a0174398cc489e8fb4222cc2758c16e8'
                Asar   = (Join-Path $env:APPDATA 'Equicord\equicord.asar')
            }
        }
    }
}

# Nome curto do que esta escolhido, para mostrar no menu e no status.
function Get-ModRotulo($cfg) {
    $temBuild = -not [string]::IsNullOrWhiteSpace([string]$cfg.BuildPersonalizado)
    if ("$($cfg.Mod)".ToLower() -eq 'vencord') {
        if ($temBuild) { return 'Vencord + build proprio' }
        return 'Vencord'
    }
    if ($temBuild) { return 'Equicord + GoLiveBypass (build proprio)' }
    return 'Equicord (build padrao)'
}

# Qual mod esta REALMENTE aplicado no Discord agora. O shim que o instalador
# deixa no lugar do app.asar carrega o caminho do .asar do mod, entao da para
# saber quem aplicou - o que permite trocar de mod e detectar divergencia.
function Get-ModAplicado($appDir) {
    $shim = Join-Path $appDir.FullName 'resources\app.asar'
    if (-not (Test-Path $shim)) { return '' }
    try {
        $t = [IO.File]::ReadAllText($shim)
        if ($t -match 'Equicord') { return 'equicord' }
        if ($t -match 'Vencord')  { return 'vencord' }
        return 'outro'
    } catch { return '' }
}
