' Equicord Auto-Repair - launcher invisivel
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
' Inicia o vigia (equicord-watch.ps1) SEM nenhuma janela: nem o console do
' PowerShell, nem flash no logon. O wscript.exe nao tem console proprio e o
' terceiro parametro 0 do .Run faz o PowerShell nascer ja com a janela oculta.
' (O -WindowStyle Hidden sozinho ainda cria a janela e so depois a esconde,
'  o que aparece como um flash de "CMD" toda vez que o Windows inicia.)
Dim sh, cmd
Set sh = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & _
      sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\EquicordAutoRepair\equicord-watch.ps1"""
sh.Run cmd, 0, False
