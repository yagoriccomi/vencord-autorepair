# Testes da regra de negocio do reparo (scripts/repair.ps1)
# Uso particular. Todos os direitos reservados.
#
# ISOLAMENTO: $env:USERPROFILE e $env:LOCALAPPDATA sao desviados para o
# TestDrive ANTES da carga (os caminhos sao calculados na carga). Processos,
# instaladores e janelas sao mockados - nenhum teste fecha o Discord de
# verdade nem executa .exe.

BeforeAll {
    $script:UserProfileOriginal   = $env:USERPROFILE
    $script:LocalAppDataOriginal  = $env:LOCALAPPDATA
    $env:USERPROFILE  = Join-Path $TestDrive 'perfil'
    $env:LOCALAPPDATA = Join-Path $TestDrive 'local'
    New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE 'DiscordModAutoRepair') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $env:LOCALAPPDATA 'Discord') | Out-Null

    . (Join-Path $PSScriptRoot '..\scripts\repair.ps1')

    $script:Base    = Join-Path $env:USERPROFILE 'DiscordModAutoRepair'
    $script:CfgFile = Join-Path $script:Base 'config.json'
    $script:StFile  = Join-Path $script:Base 'state.json'
}

AfterAll {
    $env:USERPROFILE  = $script:UserProfileOriginal
    $env:LOCALAPPDATA = $script:LocalAppDataOriginal
}

Describe 'Get-Config' {

    BeforeEach {
        Remove-Item $script:CfgFile -Force -ErrorAction SilentlyContinue
    }

    It 'usa Equicord como padrao quando nao ha arquivo de configuracao' {
        (Get-Config).Mod | Should -Be 'equicord'
    }

    It 'nao liga build proprio por conta propria' {
        (Get-Config).BuildPersonalizado | Should -BeNullOrEmpty
    }

    It 'respeita o mod gravado no arquivo' {
        '{"Mod":"vencord"}' | Set-Content $script:CfgFile -Encoding utf8
        (Get-Config).Mod | Should -Be 'vencord'
    }

    # --- tolerancia a arquivo corrompido: o vigia nao pode morrer por isso ---
    It 'cai nos padroes quando o JSON esta corrompido em vez de estourar' {
        '{isto nao e json valido' | Set-Content $script:CfgFile -Encoding utf8
        { Get-Config } | Should -Not -Throw
        (Get-Config).Mod | Should -Be 'equicord'
    }

    It 'cai nos padroes quando o arquivo esta vazio' {
        '' | Set-Content $script:CfgFile -Encoding utf8
        (Get-Config).MaxTentativas | Should -Be 3
    }

    It 'preserva os demais padroes quando o arquivo traz so uma chave' {
        '{"Mod":"vencord"}' | Set-Content $script:CfgFile -Encoding utf8
        $c = Get-Config
        $c.MaxTentativas    | Should -Be 3
        $c.ReabrirDiscord   | Should -BeTrue
    }
}

Describe 'Get-State' {

    BeforeEach {
        Remove-Item $script:StFile -Force -ErrorAction SilentlyContinue
    }

    It 'comeca sem falhas e sem quarentena quando nao ha estado salvo' {
        $s = Get-State
        $s.Falhas     | Should -Be 0
        $s.Quarentena | Should -BeFalse
    }

    It 'le o contador de falhas e a quarentena gravados' {
        '{"Versao":"app-1.0.9253","Falhas":3,"Quarentena":true}' | Set-Content $script:StFile -Encoding utf8
        $s = Get-State
        $s.Falhas     | Should -Be 3
        $s.Quarentena | Should -BeTrue
    }

    # --- estado corrompido nao pode virar quarentena eterna ----------------
    It 'cai no estado limpo quando o JSON esta corrompido' {
        '{{{' | Set-Content $script:StFile -Encoding utf8
        { Get-State } | Should -Not -Throw
        (Get-State).Quarentena | Should -BeFalse
    }
}

Describe 'Test-CustomBuildAtivo' {

    BeforeEach {
        $script:Origem  = Join-Path $TestDrive 'meu-build.asar'
        $script:Destino = Join-Path $TestDrive 'instalado.asar'
        $script:InfoEqui = [pscustomobject]@{ SuportaBuildProprio = $true;  Asar = $script:Destino }
        $script:InfoVen  = [pscustomobject]@{ SuportaBuildProprio = $false; Asar = '' }
    }

    It 'considera ativo quando o usuario nao usa build proprio' {
        $cfg = [pscustomobject]@{ BuildPersonalizado = ''; AsarDoMod = '' }
        Test-CustomBuildAtivo $cfg $script:InfoEqui | Should -BeTrue
    }

    It 'considera ativo para mod que nem suporta build proprio (Vencord)' {
        $cfg = [pscustomobject]@{ BuildPersonalizado = 'C:\x.asar'; AsarDoMod = '' }
        Test-CustomBuildAtivo $cfg $script:InfoVen | Should -BeTrue
    }

    # --- REGRESSAO REAL: foi assim que o GoLiveBypass sumiu em silencio -----
    It 'detecta que o build PADRAO substituiu o proprio (conteudo diferente)' {
        Set-Content $script:Origem  'build com meus plugins'
        Set-Content $script:Destino 'build padrao do instalador'
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = $script:Destino }

        Test-CustomBuildAtivo $cfg $script:InfoEqui | Should -BeFalse
    }

    It 'reconhece como ativo quando o conteudo bate byte a byte' {
        Set-Content $script:Origem  'build com meus plugins'
        Set-Content $script:Destino 'build com meus plugins'
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = $script:Destino }

        Test-CustomBuildAtivo $cfg $script:InfoEqui | Should -BeTrue
    }

    It 'considera inativo quando o destino nem existe (mod nao instalado)' {
        Set-Content $script:Origem 'build com meus plugins'
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = (Join-Path $TestDrive 'nao-existe.asar') }

        Test-CustomBuildAtivo $cfg $script:InfoEqui | Should -BeFalse
    }
}

Describe 'Restore-CustomBuild' {

    BeforeEach {
        $script:Origem  = Join-Path $TestDrive 'meu-build2.asar'
        $script:Destino = Join-Path $TestDrive 'instalado2.asar'
        Remove-Item $script:Origem, $script:Destino -Force -ErrorAction SilentlyContinue
        $script:InfoEqui = [pscustomobject]@{ SuportaBuildProprio = $true; Asar = $script:Destino; Nome = 'Equicord' }
    }

    It 'copia o build proprio por cima do padrao' {
        Set-Content $script:Origem 'plugins proprios'
        Set-Content $script:Destino 'padrao'
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = $script:Destino }

        Restore-CustomBuild $cfg $script:InfoEqui | Should -BeTrue
        (Get-Content $script:Destino -Raw).Trim() | Should -Be 'plugins proprios'
    }

    # --- falha em vez de mentir: build ausente nao pode reportar sucesso ----
    It 'devolve falso quando o build proprio nao existe no disco' {
        $cfg = [pscustomobject]@{ BuildPersonalizado = (Join-Path $TestDrive 'sumiu.asar'); AsarDoMod = $script:Destino }

        Restore-CustomBuild $cfg $script:InfoEqui | Should -BeFalse
    }

    It 'nao tenta restaurar em mod sem suporte e reporta sucesso silencioso' {
        Set-Content $script:Origem 'plugins proprios'
        $infoVen = [pscustomobject]@{ SuportaBuildProprio = $false; Asar = ''; Nome = 'Vencord' }
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = '' }

        Restore-CustomBuild $cfg $infoVen | Should -BeTrue
    }

    It 'cria a pasta de destino quando ela ainda nao existe' {
        Set-Content $script:Origem 'plugins proprios'
        $destinoNovo = Join-Path $TestDrive 'pasta\que\nao\existe\mod.asar'
        $cfg = [pscustomobject]@{ BuildPersonalizado = $script:Origem; AsarDoMod = $destinoNovo }

        Restore-CustomBuild $cfg $script:InfoEqui | Should -BeTrue
        Test-Path $destinoNovo | Should -BeTrue
    }
}

Describe 'Request-FecharDiscord' {

    BeforeEach {
        $script:CfgAvisa = [pscustomobject]@{ AvisarAntesDeFechar = $true; SegundosAviso = 8 }
    }

    It 'devolve ok sem incomodar ninguem quando o Discord ja esta fechado' {
        Mock Test-DiscordRodando { $false }
        Mock Ask-Proceed { throw 'nao deveria perguntar nada' }
        Mock Stop-DiscordApp { throw 'nao deveria fechar nada' }

        Request-FecharDiscord $script:CfgAvisa 'mensagem' | Should -Be 'ok'
    }

    # --- respeitar o "nao" do usuario e o que evita fechar o Discord na cara dele
    It 'devolve adiado e NAO fecha o Discord quando o usuario recusa' {
        Mock Test-DiscordRodando { $true }
        Mock Ask-Proceed { $false }
        Mock Stop-DiscordApp { throw 'nao pode fechar apos o usuario recusar' }

        Request-FecharDiscord $script:CfgAvisa 'mensagem' | Should -Be 'adiado'
    }

    It 'devolve ok quando o usuario aceita e o fechamento funciona' {
        Mock Test-DiscordRodando { $true }
        Mock Ask-Proceed { $true }
        Mock Stop-DiscordApp { $true }

        Request-FecharDiscord $script:CfgAvisa 'mensagem' | Should -Be 'ok'
    }

    # --- nao conseguiu fechar = NAO patchear (foi o que corrompia o Discord)
    It 'devolve falhou quando o Discord se recusa a fechar' {
        Mock Test-DiscordRodando { $true }
        Mock Ask-Proceed { $true }
        Mock Stop-DiscordApp { $false }

        Request-FecharDiscord $script:CfgAvisa 'mensagem' | Should -Be 'falhou'
    }

    It 'nao pergunta nada quando o aviso esta desligado, mas ainda fecha' {
        Mock Test-DiscordRodando { $true }
        Mock Ask-Proceed { throw 'aviso desligado: nao deveria perguntar' }
        Mock Stop-DiscordApp { $true }
        $cfgSemAviso = [pscustomobject]@{ AvisarAntesDeFechar = $false; SegundosAviso = 8 }

        Request-FecharDiscord $cfgSemAviso 'mensagem' | Should -Be 'ok'
    }
}
