# Projeto: Discord Mod Auto-Repair

> ⚠️ **Este arquivo existe para impedir um erro de contexto.** O diretório pai
> (`E:\User Files\Downloads\`) tem um `CLAUDE.md` sobre um *servidor de Minecraft
> com Docker e Syncthing*. **Aquilo não tem relação nenhuma com este projeto.**
> Aqui não há Docker, contêiner, servidor, banco de dados nem `compose.yaml`.

## 📌 O que é

Utilitário de **desktop Windows** que mantém um mod do Discord (**Vencord** ou
**Equicord**) aplicado. O Discord se atualiza sozinho e, a cada atualização,
**apaga o patch do mod**. Este programa detecta e reaplica automaticamente.

**Valor entregue:** o usuário não perde os plugins toda vez que o Discord
atualiza, e não precisa reinstalar nada na mão.

Roda como **tarefa agendada do Windows**, no usuário comum, **sem admin**.

## 🧱 Stack

- **Windows PowerShell 5.1** (não PowerShell 7 — o código usa APIs Win32)
- **Batch** (`menu.bat`) e **VBScript** (janelas sem console)
- **Pester 6** para testes · **PSScriptAnalyzer** para lint
- Sem Node, sem Python, sem banco, sem rede exposta

## 📂 Arquitetura em camadas

Cada camada tem **uma** responsabilidade. Quem chama decide *o quê*; a camada
sabe *como*.

| Arquivo | Papel | Regra |
|---|---|---|
| `scripts/discord.ps1` | **Infra** | Única que toca disco e processos do Discord |
| `scripts/ui.ps1` | **Apresentação** | Única que fala com o usuário (caixas, perguntas) |
| `scripts/repair.ps1` | **Regra de negócio** | Decide o que fazer. **Só definições** — carregar não executa nada |
| `scripts/mod-watch.ps1` | **Entrada** (49 linhas) | Mutex de vida + laço de observação |
| `scripts/mods.ps1` | **Catálogo** | URL, SHA256 e caminhos de cada mod + verificação de integridade |

Auxiliares: `install.ps1`, `uninstall.ps1`, `status.ps1`, `config.ps1`,
`open-discord.ps1`, `rebuild.ps1`, `test.ps1`.

> `repair.ps1` conter **apenas definições** não é estética: é o que torna a
> regra de negócio testável sem disparar o vigia nem tocar no Discord.

## ⚠️ Regras que NÃO devem ser "simplificadas"

Cada uma abaixo nasceu de um Discord quebrado de verdade, na máquina do
usuário. Elas parecem cerimônia desnecessária até você desfazer uma.

1. **Nunca rodar o instalador com o Discord aberto.** Ele recusa (*"files are
   used by a different process"*) e pode deixar o Discord **abrindo e fechando
   sozinho**. Fechar de propósito → aplicar → reabrir.
2. **Esperar o updater estabilizar** (30 s sem mudança) antes de agir. Durante
   uma atualização o Discord troca as pastas `app-*` várias vezes; agir no meio
   gera patch desfeito segundos depois.
3. **Conferir o resultado pelos ARQUIVOS, nunca pelo exit code.** O instalador
   já reportou sucesso com o patch desfeito. Confere-se duas vezes, com
   intervalo, para pegar o updater desfazendo por baixo.
4. **Pasta `app-*` só conta com `Discord.exe` E um `.asar`.** O updater copia o
   `.exe` antes do `resources`; um download interrompido já foi eleito "versão
   atual" e gerou alarme falso de "Discord quebrado" + quarentena indevida.
5. **Versão comparada como NÚMERO, não texto.** Ordenação textual elegeria
   `1.0.9999` em vez de `1.0.10000`.
6. **Quarentena após 3 falhas na mesma versão.** Sem isso, uma falha
   persistente vira ciclo infinito de fechar/abrir o Discord — já aconteceu.
7. **Build próprio é restaurado por cima do padrão.** O instalador oficial
   sempre instala o build **padrão**; quem compila os próprios `userplugins`
   perderia os plugins a cada reparo, **em silêncio**. A escrita é **atômica**
   (temporário + rename): copiar 16 MB direto sobre o arquivo vivo deixa o
   Discord sem abrir se a cópia for interrompida.
8. **Integridade (SHA256) conferida em TODO caminho de execução**, não só na
   instalação manual. O vigia roda sozinho, sem supervisão, numa pasta que o
   README manda excluir do antivírus.
9. **Mutex de OPERAÇÃO (não de tempo de vida)** serializa reparo manual e
   automático. O mutex do vigia fica preso enquanto ele existir — reutilizá-lo
   faria o `-Once` do menu nunca funcionar.
10. **A captura da saída do instalador roda com `ErrorActionPreference =
    'Continue'`.** O PowerShell 5.1 embrulha **cada linha de stderr de um
    `.exe`** num `ErrorRecord`; sob `'Stop'`, um patch **bem-sucedido** virava
    erro terminante, porque o instalador escreve `INFO ...` em stderr.

## 🧪 Testes

```powershell
.\scripts\test.ps1     # ou opção [17] do menu
```

64 casos em `tests/`. **Não tocam no Discord real**: desviam
`%LOCALAPPDATA%` / `%USERPROFILE%` para pasta temporária *antes da carga* (os
caminhos são resolvidos no momento em que o script é carregado) e mockam
processos, instaladores e janelas.

> Ao escrever teste novo: **jamais** chamar `Stop-Process` em Discord real nem
> executar os `.exe` de instalação.

## 🚦 CI

`.github/workflows/ci.yml` — PSScriptAnalyzer + Pester como **gate**, em
`windows-latest` com shell `powershell` (5.1, não `pwsh`). Sem deploy: não há
o que implantar. **Zero secrets.**

Exclusões do linter estão em `PSScriptAnalyzerSettings.psd1`, **cada uma com
justificativa escrita** — a maior é `PSAvoidUsingWriteHost`, regra errada para
um utilitário de console onde a saída na tela *é* o produto.

## 🗂️ Duas pastas — não confundir

| Caminho | O que é |
|---|---|
| a pasta deste repositório | **Fonte.** Onde se edita |
| `%USERPROFILE%\DiscordModAutoRepair` | **Cópia instalada**, que roda sozinha |

A opção **[4]** do menu copia a fonte para a instalação. Editar aqui **não**
muda o que roda até reinstalar — o `status` (opção 5) avisa quando divergem.

## 🔁 Pendências não urgentes: agrupar, não empurrar

Correção que **não tem risco hoje** não ganha push dedicado. Anota-se em
[`REVIEW.md`](REVIEW.md) (seção *Pendência aberta*) com o motivo de ter ficado
para depois, e ela **pega carona na próxima alteração real** do projeto.

Por quê: cada push que toca código dispara o CI, que aqui roda em runner
Windows de repositório privado — **multiplicador 2x** de cota. Push de duas
linhas sem urgência gasta o mesmo que uma entrega de verdade.

> Commit que só toca `.md` **não** dispara o CI (`paths-ignore`), então
> documentação pode ser commitada à vontade.

**Pendência aberta hoje:** `actions/checkout@v4` e `actions/cache@v4` usam
Node 20 (depreciado). Não quebra agora — o runner força Node 24. Subir para
`@v5` junto da próxima mudança em `.github/` ou em `scripts/`.

## 📋 Convenções

- Comentário explica **o porquê**, não o o-quê. Regra de segurança ganha
  comentário dizendo qual estrago ela evita.
- Verbos aprovados do PowerShell (`Confirm-`, `Get-`, `Test-`, `Invoke-`).
- Mensagens ao usuário em **português sem acento** nos scripts (evita problema
  de codificação no console e nas caixas do Windows).
- Módulos carregados por **dot-source** (`. (Join-Path $PSScriptRoot 'x.ps1')`),
  não `.psm1`.

## 🔗 Documentos

- [`README.md`](README.md) — guia do usuário, linguagem simples
- [`REVIEW.md`](REVIEW.md) — auditoria de segurança e o status das correções
- [`docs/arquitetura.md`](docs/arquitetura.md) — o "porquê" das decisões
