# 🐒 Discord Mod Auto-Repair

**Você escolhe o mod. Ele mantém aplicado, mesmo quando o Discord atualiza.**

O Discord se atualiza sozinho e, toda vez, **apaga o mod**. Este programa fica de olho e **coloca de volta** — avisando na tela e sem sustos.

---

## 🎯 Escolha o que você quer

O menu te dá **três opções**, e ele mostra sempre qual está valendo no topo da tela:

| Opção | O que é |
|:---:|---|
| **1** | 🟣 **Vencord** — o mod original |
| **2** | 🔵 **Equicord** — fork do Vencord com mais plugins, **build padrão** (sem GoLiveBypass) |
| **3** | 🔵➕ **Equicord + GoLiveBypass** — usa o **seu build próprio**, compilado da fonte com os plugins que você adicionou |

Escolheu? Aperte **[4]** para aplicar no Discord. Pode trocar quando quiser: ele **remove o anterior e põe o novo** sozinho.

> A opção **3** exige que você tenha o Equicord clonado, com o plugin em `src/userplugins`, e o build gerado. A opção **[13]** do menu roda o `pnpm build` pra você.

---

## 🚀 Como usar (3 passos)

```
1. Baixe esta pasta
2. Dê 2 cliques no arquivo  menu.bat
3. Escolha o mod (1, 2 ou 3) e aperte 4
```

Pronto! 🎉  *(Você precisa já ter o **Discord** instalado.)*

---

## 🎮 O menu

```
   Mod escolhido:  Equicord + GoLiveBypass (build proprio)

   --- 1) ESCOLHA O MOD ---
   [1] Vencord
   [2] Equicord (build padrao, SEM GoLiveBypass)
   [3] Equicord + GoLiveBypass (seu build proprio)

   --- 2) APLICAR NO DISCORD ---
   [4] Instalar / trocar para o mod escolhido
   [5] Ver status
   [6] Reparar agora
   [7] Abrir o Discord
```

| Aperte | O que acontece |
|:------:|----------------|
| **8** | ✅ Liga/desliga o aviso de **sucesso** |
| **9** | 🔔 Liga/desliga a **pergunta** antes de fechar o Discord |
| **10** | 🔁 Liga/desliga **reabrir o Discord** sozinho |
| **11** | 🔓 Zera a **quarentena** |
| **12** | 📜 Mostra o log |
| **13** | 🔨 Reconstrói o build próprio (`pnpm build`) |
| **14** | ♻️ Reinstala a tarefa agendada |
| **15** | 🛑 Desliga o auto-reparo (o mod continua) |
| **16** | 🗑️ Apaga tudo |
| **17** | 🧪 Roda os testes (confere se tudo continua funcionando) |

---

## 💬 As caixinhas de aviso

| Quando | O que aparece |
|---|---|
| 🔔 **Antes de fechar o Discord** | Pergunta *"Aplicar agora?"*. Sem resposta em 8s, ele aplica. Clicou **Não**, fica pra depois. |
| ✅ **Deu certo** | Fecha sozinha em 8s. *(desligável — opção 8)* |
| ❌ **Deu errado** | Caixa vermelha com **código e mensagem do erro**. Fica até você clicar OK. **Não desliga.** |

> 🕒 Toda caixa mostra **data e hora** — assim um aviso esquecido na tela não se confunde com um problema de agora.

Se falhar, ele **limpa o mod e abre o Discord puro**: você nunca fica sem Discord.

---

## 🛡️ Por que ele não vira um loop infinito

1. **Nunca mexe com o Discord aberto.** O instalador *falha* com ele rodando e pode quebrar o Discord. Então o programa fecha de propósito, aplica e reabre.
2. **Espera o update terminar** (30s sem mudança) antes de encostar.
3. **Confere pelos arquivos**, não pelo "deu certo" do instalador — e reconfere 12s depois.
4. **Quarentena:** 3 falhas na mesma versão e ele desiste, deixa o Discord funcionando e avisa.

---

## ✅ Como sei que tá funcionando?

Menu → **[5]**:

```
Mod escolhido .... Equicord + GoLiveBypass (build proprio)
Discord .......... instalado (app-1.0.9253)
Mod aplicado ..... Equicord (APLICADO)
Vigia ............ rodando
Auto-reparo ...... ativo, sem falhas
Build proprio .... ATIVO no Discord
```

Se o que está aplicado for diferente do escolhido, ele avisa e manda usar a opção **[4]**.

---

## 🧩 O build próprio (opção 3)

Aqui está a pegadinha que essa opção resolve:

> O instalador oficial põe **sempre o build padrão**. Sem isso, todo reparo apagaria seus plugins compilados — e **em silêncio**, porque o mod continuaria funcionando normalmente, só que sem eles.

Por isso, depois de aplicar o patch e **antes de reabrir o Discord**, ele copia o seu `.asar` por cima do padrão. E confere: se a cópia falhar, **abre caixa de aviso na tela** mesmo com as notificações de sucesso desligadas.

Ele também detecta o caso em que o patch está intacto mas o build foi trocado pelo padrão — compara o **hash** do que o Discord carrega com o do seu build.

Configurado em `C:\Users\SEU-NOME\DiscordModAutoRepair\config.json`:

```json
{
  "Mod": "equicord",
  "BuildPersonalizado": "C:\\Users\\SEU-NOME\\Equicord\\dist\\desktop.asar"
}
```

**Mexeu no código dos plugins?** Opção **[13]** (roda `pnpm build`), depois **[6]** para aplicar.

---

## 🚨 Deu erro? Provavelmente é o antivírus

Antivírus (tipo o **Kaspersky**) acha que "programa que se reinstala sozinho" é vírus — porque vírus fazem isso. Libere:

1. Antivírus → **Exclusões** / **Aplicativos confiáveis**
2. Adicione `C:\Users\SEU-NOME\DiscordModAutoRepair` e o `powershell.exe`

---

## 🧠 Como funciona por dentro

*(Só se você for curioso.)*

- Usa os instaladores **oficiais** (Vencord Installer / Equilotl), conferidos por **SHA256** antes de rodar.
- Um "vigia" roda escondido e observa o Discord — **só** reage a update e a abertura do app.
- Guarda tudo em `C:\Users\SEU-NOME\DiscordModAutoRepair`: `watch.log`, `config.json`, `state.json`.
- **Não** precisa de administrador. **Não** roda de hora em hora. **Não** aplica nada no login.

### Como ele sabe o que está aplicado

O mod renomeia o `app.asar` do Discord para `_app.asar` e põe um atalho no lugar — e esse atalho **carrega o caminho do mod**, que é como o programa sabe se quem está lá é o Vencord ou o Equicord.

| Arquivos | Significa |
|---|---|
| `app.asar` + `_app.asar` | ✅ Mod aplicado |
| só `app.asar` | ⚪ Discord puro |
| falta o `app.asar` | ❌ **Quebrado** — o Discord abre e fecha sozinho |
| pasta só com `.dll` e `.exe` | ⏳ **Update baixado pela metade** — ignorado |

### ⚠️ Duas pastas

Esta pasta (com o `menu.bat`) é a **fonte**. A opção **[4]** copia os scripts para `C:\Users\SEU-NOME\DiscordModAutoRepair`, e é a **cópia** que roda sozinha. Baixou versão nova do projeto? Rode a **[4]** de novo. O status avisa se estiver desatualizado.

---

## 🧪 Tem rede de segurança

O programa mexe em coisa séria: fecha o seu Discord e troca arquivos de 16 MB
dentro dele. Por isso existe uma **suíte de 64 testes** que confere se tudo
continua funcionando — inclusive os problemas que já deram errado de verdade
(update baixado pela metade, plugins sumindo em silêncio, instalador
adulterado).

Rode quando quiser, pela opção **[17]** do menu:

```
Todos os 64 testes passaram.
```

Eles são seguros: rodam contra um **Discord de mentira** numa pasta temporária.
Nenhum teste fecha o seu Discord nem executa instalador de verdade.

---

## 🛠️ Vai mexer no código?

Leia antes:

- **[`CLAUDE.md`](CLAUDE.md)** — as regras que **não** devem ser "simplificadas".
  Cada uma nasceu de um Discord quebrado de verdade.
- **[`docs/arquitetura.md`](docs/arquitetura.md)** — como o sistema pensa, o
  fluxo de um reparo e o porquê de cada trava.
- **[`REVIEW.md`](REVIEW.md)** — auditoria de segurança e o que foi corrigido.

Toda alteração passa por lint e testes automaticamente no GitHub Actions.

---

## 📜 Uso

**Projeto particular.** © 2026 yagoriccomi — todos os direitos reservados.

Repositório privado, **sem licença de uso**: não é software livre e não está aberto para redistribuição ou modificação por terceiros.
