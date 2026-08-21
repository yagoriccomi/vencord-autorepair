# Testes da camada de acesso ao Discord (scripts/discord.ps1)
# Uso particular. Todos os direitos reservados.
#
# ISOLAMENTO: nenhum teste toca no Discord real. O $env:LOCALAPPDATA e
# desviado para o TestDrive ANTES de carregar discord.ps1, porque o caminho
# do Discord e calculado no momento da carga.

BeforeAll {
    $script:LocalAppDataOriginal = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = Join-Path $TestDrive 'local'
    $script:FakeDiscord = Join-Path $env:LOCALAPPDATA 'Discord'
    New-Item -ItemType Directory -Force -Path $script:FakeDiscord | Out-Null

    . (Join-Path $PSScriptRoot '..\scripts\discord.ps1')

    # Monta uma pasta app-<versao> falsa com o conteudo pedido.
    function New-AppFalso {
        param(
            [string]$Versao,
            [switch]$SemExe,        # updater ainda nao copiou o Discord.exe
            [switch]$SemAsar,       # update pela metade: so .dll/.exe
            [switch]$ComPatch,      # app.asar + _app.asar (mod aplicado)
            [switch]$Quebrado       # falta o app.asar (Discord nao abre)
        )
        $dir = Join-Path $script:FakeDiscord "app-$Versao"
        $res = Join-Path $dir 'resources'
        New-Item -ItemType Directory -Force -Path $res | Out-Null
        if (-not $SemExe) { Set-Content (Join-Path $dir 'Discord.exe') 'binario' }
        Set-Content (Join-Path $dir 'd3dcompiler_47.dll') 'dll'
        if ($SemAsar)      { return $dir }
        if ($Quebrado)     { Set-Content (Join-Path $res '_app.asar') 'original'; return $dir }
        Set-Content (Join-Path $res 'app.asar') 'shim'
        if ($ComPatch)     { Set-Content (Join-Path $res '_app.asar') 'original' }
        return $dir
    }
}

AfterAll {
    $env:LOCALAPPDATA = $script:LocalAppDataOriginal
}

Describe 'Get-DiscordAppDir' {

    BeforeEach {
        Get-ChildItem $script:FakeDiscord -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }

    # --- REGRESSAO REAL: o bug do app-1.0.9252 (13/08) -----------------------
    It 'ignora update baixado pela metade e devolve a versao completa anterior' {
        New-AppFalso -Versao '1.0.9251' -ComPatch | Out-Null
        New-AppFalso -Versao '1.0.9252' -SemAsar  | Out-Null

        (Get-DiscordAppDir).Name | Should -Be 'app-1.0.9251'
    }

    It 'devolve nulo quando a UNICA pasta existente e um update pela metade' {
        New-AppFalso -Versao '1.0.9252' -SemAsar | Out-Null

        Get-DiscordAppDir | Should -BeNullOrEmpty
    }

    It 'ignora pasta sem Discord.exe mesmo que tenha o asar' {
        New-AppFalso -Versao '1.0.9300' -SemExe | Out-Null

        Get-DiscordAppDir | Should -BeNullOrEmpty
    }

    # --- BUG LATENTE: ordenacao por texto quebraria na virada ---------------
    It 'compara versao como NUMERO: 1.0.10000 ganha de 1.0.9999' {
        New-AppFalso -Versao '1.0.9999'  | Out-Null
        New-AppFalso -Versao '1.0.10000' | Out-Null

        (Get-DiscordAppDir).Name | Should -Be 'app-1.0.10000'
    }

    It 'devolve nulo quando nao ha nenhuma pasta app-*' {
        Get-DiscordAppDir | Should -BeNullOrEmpty
    }

    It 'nao quebra quando a pasta do Discord nem existe' {
        Remove-Item $script:FakeDiscord -Recurse -Force
        { Get-DiscordAppDir } | Should -Not -Throw
        New-Item -ItemType Directory -Force -Path $script:FakeDiscord | Out-Null
    }
}

Describe 'Get-DiscordAppsIncompletos' {

    BeforeEach {
        Get-ChildItem $script:FakeDiscord -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }

    It 'lista a pasta pela metade para que o vigia possa ignora-la conscientemente' {
        New-AppFalso -Versao '1.0.9251' -ComPatch | Out-Null
        New-AppFalso -Versao '1.0.9252' -SemAsar  | Out-Null

        $inc = @(Get-DiscordAppsIncompletos)
        $inc.Count      | Should -Be 1
        $inc[0].Name    | Should -Be 'app-1.0.9252'
    }

    It 'devolve vazio quando todas as pastas estao completas' {
        New-AppFalso -Versao '1.0.9251' -ComPatch | Out-Null

        @(Get-DiscordAppsIncompletos).Count | Should -Be 0
    }
}

Describe 'Get-DiscordPatchState' {

    BeforeEach {
        Get-ChildItem $script:FakeDiscord -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }

    It 'classifica como patched quando app.asar e _app.asar coexistem' {
        $dir = New-AppFalso -Versao '1.0.9251' -ComPatch
        Get-DiscordPatchState (Get-Item $dir) | Should -Be 'patched'
    }

    It 'classifica como pure quando so existe o app.asar original' {
        $dir = New-AppFalso -Versao '1.0.9251'
        Get-DiscordPatchState (Get-Item $dir) | Should -Be 'pure'
    }

    # --- O estado que fazia o Discord abrir e fechar sozinho -----------------
    It 'classifica como broken quando falta o app.asar (Discord nao abre assim)' {
        $dir = New-AppFalso -Versao '1.0.9251' -Quebrado
        Get-DiscordPatchState (Get-Item $dir) | Should -Be 'broken'
    }

    It 'classifica como broken quando a pasta resources esta vazia' {
        $dir = New-AppFalso -Versao '1.0.9251' -SemAsar
        Get-DiscordPatchState (Get-Item $dir) | Should -Be 'broken'
    }
}

Describe 'Test-DiscordAppCompleto' {

    BeforeEach {
        Get-ChildItem $script:FakeDiscord -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }

    It 'recusa pasta com .dll e .exe mas sem nenhum asar' {
        $dir = New-AppFalso -Versao '1.0.9252' -SemAsar
        Test-DiscordAppCompleto $dir | Should -BeFalse
    }

    It 'aceita pasta ja patcheada (tem _app.asar mesmo sem app.asar)' {
        $dir = New-AppFalso -Versao '1.0.9251' -Quebrado
        Test-DiscordAppCompleto $dir | Should -BeTrue
    }
}
