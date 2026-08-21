' Equicord Auto-Repair - caixa de mensagem
' Copyright (C) 2026 yagoriccomi
'
' This program is free software: you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation, either version 3 of the License, or
' (at your option) any later version.
'
' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
' GNU General Public License for more details.
'
' You should have received a copy of the GNU General Public License
' along with this program.  If not, see <https://www.gnu.org/licenses/>.
'
' Mostra uma caixa de aviso na tela SEM travar o vigia (e lancado como
' processo separado). A mensagem vem de um arquivo (em Unicode) para nao
' ter problema com acentos e quebras de linha na linha de comando.
'
' Argumentos:
'   0 = caminho do arquivo .txt com a mensagem (e apagado depois de lido)
'   1 = titulo da janela
'   2 = tipo: "1" = erro (icone vermelho), qualquer outro = informacao
'   3 = segundos ate fechar sozinho (0 = espera o usuario clicar em OK)
Option Explicit

Dim fso, sh, arq, msg, tipo, tempo

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

If WScript.Arguments.Count < 4 Then WScript.Quit 1
If Not fso.FileExists(WScript.Arguments(0)) Then WScript.Quit 1

' -1 = abre como Unicode (preserva acentos)
Set arq = fso.OpenTextFile(WScript.Arguments(0), 1, False, -1)
msg = arq.ReadAll
arq.Close
On Error Resume Next
fso.DeleteFile WScript.Arguments(0)
On Error GoTo 0

If WScript.Arguments(2) = "1" Then
    tipo = 16   ' vbCritical  - icone de erro
Else
    tipo = 64   ' vbInformation - icone de informacao
End If

tempo = CLng(WScript.Arguments(3))

sh.Popup msg, tempo, WScript.Arguments(1), tipo
