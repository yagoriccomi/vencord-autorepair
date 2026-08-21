# Discord Mod Auto-Repair - camada de apresentacao
# Uso particular. Todos os direitos reservados.
#
# UNICA camada que fala com o usuario. Quem chama decide O QUE dizer; este
# arquivo sabe COMO mostrar. Nenhuma regra de negocio mora aqui.

$script:TituloApp        = 'Discord Mod Auto-Repair'
$script:NotifyVbs        = Join-Path $PSScriptRoot 'notify.vbs'
$script:SegundosCaixaOk  = 8    # aviso de sucesso some sozinho
$script:CaixaEsperaClique = 0   # 0 = fica na tela ate o usuario clicar (usado em falhas)

# Codigos do WScript.Shell.Popup
$script:BotoesSimNao     = 4 + 32   # Sim/Nao + icone de pergunta
$script:RespostaNao      = 7

# Caixa lancada como PROCESSO SEPARADO: nao trava quem chamou. A mensagem vai
# por arquivo (Unicode) para nao sofrer com acentos e quebras de linha na
# linha de comando.
function Show-Box($titulo, $mensagem, $erro, $segundos) {
    if (-not (Test-Path $script:NotifyVbs)) { return }
    try {
        $arquivo = Join-Path $PSScriptRoot ("msg-" + [guid]::NewGuid().ToString('N') + ".txt")
        Set-Content -Path $arquivo -Value $mensagem -Encoding Unicode
        $tipo = if ($erro) { '1' } else { '0' }
        Start-Process wscript.exe -WindowStyle Hidden -ArgumentList `
            "`"$script:NotifyVbs`"", "`"$arquivo`"", "`"$titulo`"", $tipo, "$segundos"
    } catch { }
}

# Pergunta Sim/Nao com contagem regressiva. Sem resposta = segue em frente,
# para o auto-reparo nao ficar travado esperando alguem que saiu da frente do PC.
function Ask-Proceed($mensagem, $segundos) {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $r = $wsh.Popup($mensagem, $segundos, $script:TituloApp, $script:BotoesSimNao)
        return ($r -ne $script:RespostaNao)   # 6 = Sim ; -1 = tempo esgotado
    } catch { return $true }
}

# Atalhos que dao nome as duas intencoes, em vez de repetir os literais.
function Show-Aviso($mensagem)  { Show-Box $script:TituloApp $mensagem $false $script:SegundosCaixaOk }
function Show-Erro($titulo, $mensagem) { Show-Box $titulo $mensagem $true $script:CaixaEsperaClique }
