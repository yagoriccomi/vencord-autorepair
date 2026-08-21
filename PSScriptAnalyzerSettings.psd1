@{
    # Falha o CI em Error e Warning. Information fica de fora: e ruido para
    # este porte de projeto e nao indica defeito.
    Severity = @('Error', 'Warning')

    # Cada exclusao abaixo tem motivo. A lista NAO existe para calar o linter -
    # existe para que os avisos que sobrarem signifiquem alguma coisa. Regra
    # sem justificativa aqui deveria ser corrigida no codigo, nao excluida.
    ExcludeRules = @(

        # Este e um utilitario de CONSOLE: o menu, o status e os avisos sao o
        # produto, e vao para a tela de proposito. Write-Output devolveria os
        # textos como valor de retorno das funcoes e quebraria o desenho.
        'PSAvoidUsingWriteHost',

        # Os catch vazios sao deliberados e cobertos por teste: config/estado
        # corrompidos DEVEM cair no padrao em vez de derrubar o vigia. O unico
        # catch que escondia falha de verdade (exibicao da caixa de aviso) foi
        # corrigido na auditoria e agora registra no log.
        'PSAvoidUsingEmptyCatchBlock',

        # -WhatIf/-Confirm em Stop-DiscordApp e Restore-CustomBuild seria
        # cerimonia sem uso: o vigia roda sem supervisao, disparado por
        # atualizacao do Discord. Nao ha operador para confirmar nada.
        'PSUseShouldProcessForStateChangingFunctions',

        # Falso positivo unico, em tests/repair.Tests.ps1: o Start-Job recebe a
        # variavel por -ArgumentList com param() correspondente, que e a forma
        # suportada. O analisador nao rastreia esse caminho.
        'PSUseUsingScopeModifierInNewRunspaces',

        # Severidade Information; sao chamadas internas dos proprios atalhos
        # Show-Aviso/Show-Erro para Show-Box.
        'PSAvoidUsingPositionalParameters'
    )
}
