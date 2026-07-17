# Vencord Auto-Repair

Instala o [Vencord](https://vencord.dev) no Discord e mantém o mod **sempre aplicado**, reaplicando-o automaticamente sempre que o Discord se atualiza e o remove — sem intervenção manual.

> Feito para Windows. Roda no seu próprio usuário, **sem privilégios de administrador**.

---

## O que ele faz

O Discord se atualiza sozinho de tempos em tempos, e cada atualização **remove o patch do Vencord** (troca a pasta `app-<versão>` por uma nova, "limpa"). Este projeto instala um **vigia** leve que fica de olho no Discord e reaplica o Vencord automaticamente.

O vigia age **apenas em dois momentos**:

1. **Após uma atualização do Discord** — quando surge uma nova versão (`app-<versão>`), ele detecta e reaplica o Vencord assim que a instalação termina.
2. **Ao abrir o Discord** — quando você abre o app depois de tê-lo fechado, ele confere e reaplica se estiver sem o patch.

O que ele **não** faz:

- ❌ Não roda em intervalo de tempo (nada de "a cada 1 hora").
- ❌ Não aplica patch no logon — a tarefa apenas *inicia o vigia* junto com sua sessão; a ação de patch só ocorre nos dois eventos acima.
- ❌ Não precisa de administrador.

---

## Instalação

1. Baixe/clone este repositório.
2. Execute **`menu.bat`** (duplo clique).
3. Escolha a opção **`[1] Instalar Vencord + auto-reparo`**.
4. Reinicie o Discord.

Pronto. A partir daí o Vencord volta sozinho após qualquer atualização.

> **Pré-requisito:** o Discord (stable) precisa já estar instalado em `%LOCALAPPDATA%\Discord`.

---

## O menu (`menu.bat`)

| Opção | Ação |
|:---:|---|
| **1** | Instala o Vencord e configura o auto-reparo (baixa o instalador oficial com verificação de checksum) |
| **2** | Mostra o status (Discord, Vencord aplicado?, tarefa, vigia, log) |
| **3** | Reaplica/verifica o Vencord agora (roda o vigia uma vez) |
| **4** | Mostra as últimas linhas do log do vigia |
| **5** | Reinstala/recria a tarefa agendada |
| **6** | Desliga o auto-reparo (remove a tarefa; **não** remove o Vencord) |
| **7** | Desinstala tudo (remove a tarefa **e** o Vencord do Discord) |
| **0** | Sai |

---

## Como funciona por dentro

- **Instalador:** [`VencordInstallerCli.exe`](https://github.com/Vencord/Installer) oficial (v1.4.0), baixado do GitHub e validado por **SHA256** antes de rodar.
- **Detecção do patch:** o Vencord renomeia o `app.asar` original para `_app.asar` e coloca um shim no lugar. O vigia considera "aplicado" quando existe `resources\_app.asar` na versão mais recente do Discord.
- **Persistência:** uma tarefa do Agendador de Tarefas (**"Vencord Auto-Repair"**) com gatilho *no logon* inicia o vigia, que roda em segundo plano observando os dois eventos. A tarefa reinicia o vigia caso ele caia.
- **Local de instalação:** `%USERPROFILE%\Vencord\` (contém o instalador, os scripts e o `watch.log`).

### Arquivos

```
vencord-autorepair/
├── menu.bat                    Menu principal (instalar + manutenção)
├── README.md
└── scripts/
    ├── install.ps1             Baixa o instalador, aplica o Vencord, registra a tarefa
    ├── vencord-watch.ps1       O vigia (detecta update / abertura do Discord)
    ├── register-task.ps1       Cria a tarefa agendada
    ├── uninstall.ps1           Remove a tarefa (e opcionalmente o Vencord)
    └── status.ps1              Relatório de status
```

---

## Desinstalação

- **Só desligar o auto-reparo** (mantém o Vencord): menu opção **6**.
- **Remover tudo** (tarefa + Vencord + pasta): menu opção **7**.

Ou via PowerShell:

```powershell
# desliga o auto-reparo
Unregister-ScheduledTask -TaskName "Vencord Auto-Repair" -Confirm:$false

# remove tambem o Vencord do Discord
& "$env:USERPROFILE\Vencord\VencordInstallerCli.exe" -uninstall -location "$env:LOCALAPPDATA\Discord"
```

---

## Notas de segurança

- Um antivírus (ex.: **Kaspersky**) pode sinalizar a criação de uma tarefa agendada e um programa que "se reaplica sozinho", porque esse é o mesmo padrão usado por malware para ganhar persistência. Aqui o uso é legítimo (seu PC, seu mod), mas você pode precisar **liberar o `powershell.exe`/a pasta do projeto** nas exclusões do antivírus para o auto-reparo funcionar.
- Todo o código é aberto e legível: veja a pasta `scripts/`.
- O binário do instalador **não** é versionado neste repositório; ele é baixado da release oficial do Vencord e verificado por checksum na instalação.

## Aviso

O Vencord é um mod de cliente do Discord e seu uso é de responsabilidade do usuário. Este projeto apenas automatiza a (re)instalação de um software open-source no seu próprio computador.
