# Testes das definicoes de mod (scripts/mods.ps1)
# Uso particular. Todos os direitos reservados.

BeforeAll {
    . (Join-Path $PSScriptRoot '..\scripts\mods.ps1')

    # Cria um app-* falso cujo shim aponta para o caminho informado.
    # NAO tipar como [string]: o PowerShell converteria $null em '' e o helper
    # criaria um shim vazio em vez de nenhum shim.
    function New-ShimFalso($conteudo) {
        $dir = Join-Path $TestDrive ("app-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path (Join-Path $dir 'resources') | Out-Null
        if ($null -ne $conteudo) { Set-Content (Join-Path $dir 'resources\app.asar') $conteudo }
        return (Get-Item $dir)
    }
}

Describe 'Get-ModInfo' {

    # --- BUG REAL: o caminho do .asar do Vencord foi preenchido de memoria e
    # apontava para um arquivo que nunca existiu. O Vencord carrega
    # dist/patcher.js, nao um .asar unico.
    It 'marca o Vencord como SEM suporte a build proprio' {
        (Get-ModInfo 'vencord').SuportaBuildProprio | Should -BeFalse
    }

    It 'nao promete um caminho de asar para o Vencord' {
        (Get-ModInfo 'vencord').Asar | Should -BeNullOrEmpty
    }

    It 'marca o Equicord como COM suporte a build proprio' {
        (Get-ModInfo 'equicord').SuportaBuildProprio | Should -BeTrue
    }

    It 'aponta o Equicord para um equicord.asar concreto' {
        (Get-ModInfo 'equicord').Asar | Should -Match 'equicord\.asar$'
    }

    It 'usa o instalador correto de cada mod' {
        (Get-ModInfo 'vencord').Exe  | Should -Be 'VencordInstallerCli.exe'
        (Get-ModInfo 'equicord').Exe | Should -Be 'EquilotlCli.exe'
    }

    It 'traz checksum e URL para todo mod suportado (integridade nao e opcional)' {
        foreach ($m in @('vencord', 'equicord')) {
            (Get-ModInfo $m).Sha256 | Should -Match '^[0-9a-f]{64}$'
            (Get-ModInfo $m).Url    | Should -Match '^https://github\.com/'
        }
    }

    # --- entradas invalidas nao podem derrubar o vigia ---------------------
    It 'cai no Equicord quando o mod pedido e desconhecido' {
        (Get-ModInfo 'mod-que-nao-existe').Id | Should -Be 'equicord'
    }

    It 'cai no Equicord quando o mod vem vazio ou nulo' {
        (Get-ModInfo '').Id    | Should -Be 'equicord'
        (Get-ModInfo $null).Id | Should -Be 'equicord'
    }

    It 'aceita o nome do mod em maiusculas' {
        (Get-ModInfo 'VENCORD').Id | Should -Be 'vencord'
    }
}

Describe 'Get-ModAplicado' {

    It 'reconhece o Equicord pelo caminho dentro do shim' {
        $app = New-ShimFalso 'require("C:\\Users\\x\\AppData\\Roaming\\Equicord\\equicord.asar")'
        Get-ModAplicado $app | Should -Be 'equicord'
    }

    It 'reconhece o Vencord pelo caminho dentro do shim' {
        $app = New-ShimFalso 'require("C:\\Users\\x\\AppData\\Roaming\\Vencord\\dist\\patcher.js")'
        Get-ModAplicado $app | Should -Be 'vencord'
    }

    # --- e isto que permite detectar "mod errado aplicado" e trocar --------
    It 'nao confunde os dois: shim do Vencord nunca devolve equicord' {
        $app = New-ShimFalso 'require("C:\\Users\\x\\AppData\\Roaming\\Vencord\\dist\\patcher.js")'
        Get-ModAplicado $app | Should -Not -Be 'equicord'
    }

    It 'devolve vazio quando nao ha shim nenhum (Discord puro)' {
        $app = New-ShimFalso $null
        Get-ModAplicado $app | Should -BeNullOrEmpty
    }

    It 'devolve outro quando o shim aponta para um mod desconhecido' {
        $app = New-ShimFalso 'require("C:\\Qualquer\\OutroMod\\coisa.asar")'
        Get-ModAplicado $app | Should -Be 'outro'
    }

    It 'trata shim vazio ou truncado como mod desconhecido, nao como Discord puro' {
        $app = New-ShimFalso ''
        Get-ModAplicado $app | Should -Be 'outro'
    }
}

Describe 'Get-ModRotulo' {

    It 'nao oferece build proprio para o Vencord, mesmo se configurado na mao' {
        $cfg = [pscustomobject]@{ Mod = 'vencord'; BuildPersonalizado = 'C:\qualquer\coisa.asar' }
        Get-ModRotulo $cfg | Should -Be 'Vencord'
    }

    It 'distingue Equicord padrao de Equicord com build proprio' {
        $padrao  = [pscustomobject]@{ Mod = 'equicord'; BuildPersonalizado = '' }
        $proprio = [pscustomobject]@{ Mod = 'equicord'; BuildPersonalizado = 'C:\x\dist\desktop.asar' }

        Get-ModRotulo $padrao  | Should -Be 'Equicord (build padrao)'
        Get-ModRotulo $proprio | Should -Match 'GoLiveBypass'
    }
}
