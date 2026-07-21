# Vencord Auto-Repair - instalacao completa (sem admin).
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
# 1) Baixa o VencordInstallerCli oficial (com verificacao SHA256)
# 2) Aplica o Vencord no Discord
# 3) Instala o vigia e registra a tarefa agendada
$ErrorActionPreference = 'Stop'

$InstallDir = "$env:USERPROFILE\Vencord"
$Exe        = "$InstallDir\VencordInstallerCli.exe"
$Url        = "https://github.com/Vencord/Installer/releases/download/v1.4.0/VencordInstallerCli.exe"
$Sha256     = "466d2a0be1f380ddffed052df3cc132125fa34dc1af29312e14f13f358c8d2a2"

Write-Host "== Vencord Auto-Repair :: instalacao ==" -ForegroundColor Cyan

if (-not (Test-Path "$env:LOCALAPPDATA\Discord")) {
    Write-Host "Discord (stable) nao encontrado em %LOCALAPPDATA%\Discord. Instale o Discord primeiro." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Copia os scripts do projeto para a pasta de instalacao
Copy-Item "$PSScriptRoot\vencord-watch.ps1"  $InstallDir -Force
Copy-Item "$PSScriptRoot\register-task.ps1"  $InstallDir -Force
Copy-Item "$PSScriptRoot\run-hidden.vbs"     $InstallDir -Force

# Baixa o instalador se necessario
if (-not (Test-Path $Exe)) {
    Write-Host "Baixando VencordInstallerCli.exe ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Url -OutFile $Exe -UseBasicParsing
}

# Verifica integridade
$hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $Sha256) {
    Write-Host "FALHA de checksum! Esperado $Sha256, obtido $hash. Abortando." -ForegroundColor Red
    Remove-Item $Exe -Force
    exit 1
}
Write-Host "Checksum OK." -ForegroundColor Green

# Aplica o Vencord agora
Write-Host "Aplicando Vencord no Discord ..." -ForegroundColor Yellow
& $Exe -install -branch stable
if ($LASTEXITCODE -ne 0) { Write-Host "Instalador retornou codigo $LASTEXITCODE." -ForegroundColor Red }

# Registra a tarefa de auto-reparo
& "$InstallDir\register-task.ps1"

Write-Host ""
Write-Host "Concluido. Reinicie o Discord para carregar o Vencord." -ForegroundColor Green
Write-Host "Arquivos em: $InstallDir" -ForegroundColor DarkGray
