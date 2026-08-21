# 🐒 Equicord Auto-Repair

**Bota o Equicord no seu Discord e nunca mais deixa ele sumir.**

O Discord adora se atualizar sozinho, e toda vez que ele faz isso, ele **apaga o Equicord**. Que saco, né? Este programa resolve isso: ele fica de olho e **coloca o Equicord de volta sozinho** — agora avisando na tela e sem sustos.

---

## 🎯 O que ele faz (em 1 frase)

> Se o Discord tirar o Equicord, ele bota de volta, te avisa e reabre o Discord. Fim.

Ele só age em **2 momentos**:
- 🔄 Quando o Discord **se atualiza**.
- ▶️ Quando você **abre o Discord**.

Fora isso, fica quietinho no cantinho.

---

## 🚀 Como usar (3 passos)

```
1. Baixe esta pasta
2. Dê 2 cliques no arquivo  menu.bat
3. Aperte a tecla  1  e dê Enter
```

Pronto! 🎉

> ⚠️ Você precisa já ter o **Discord** instalado antes.

---

## 💬 As caixinhas de aviso

Antes o Discord fechava do nada e dava um susto. Agora **ele te conta o que está fazendo**:

| Quando | O que aparece |
|---|---|
| 🔔 **Antes de fechar o Discord** | Pergunta *"Aplicar agora?"*. Se você não responder em 8s, ele aplica sozinho. Se clicar em **Não**, ele deixa pra depois. |
| ✅ **Deu certo** | Caixa avisando que o Equicord foi aplicado. Fecha sozinha em 8s. *(dá pra desligar no menu — opção 5)* |
| ❌ **Deu errado** | Caixa vermelha com **o código e a mensagem exata do erro**. Fica na tela até você clicar OK. **Não dá pra desligar** — falha você sempre precisa saber. |

> 🕒 Toda caixa mostra **data e hora**. Como a de erro fica esperando o clique, isso evita você confundir um aviso esquecido na tela com um problema de agora.

**E o Discord reabre sozinho** depois de aplicar. Se falhar, ele **limpa o Equicord e abre o Discord puro**, para você nunca ficar sem Discord.

---

## 🎮 Os botões do menu

Abra o `menu.bat`, digite o número e dê Enter:

| Aperte | O que acontece |
|:------:|----------------|
| **1** | 📥 Instala o Equicord e liga o guarda-costas *(use na primeira vez)* |
| **2** | 🔎 Mostra se tá tudo funcionando |
| **3** | 🔧 Aplica/repara o Equicord agora *(destrava até a quarentena)* |
| **4** | ▶️ Abre o Discord |
| **5** | ✅ Liga/desliga o aviso de **sucesso** |
| **6** | 🔔 Liga/desliga a **pergunta** antes de fechar o Discord |
| **7** | 🔁 Liga/desliga **reabrir o Discord** sozinho |
| **8** | 🔓 **Zera a quarentena** (faz ele voltar a tentar sozinho) |
| **9** | 📜 Mostra o diário (log) |
| **10** | ♻️ Reinstala a tarefa agendada |
| **11** | 🛑 Desliga o auto-reparo (o Equicord continua) |
| **12** | 🗑️ Apaga tudo |
| **0** | 🚪 Sai |

---

## 🛡️ Por que ele não vira um loop infinito

Já aconteceu de o Discord abrir e fechar sozinho várias vezes seguidas. **Isso não acontece mais**, por 4 motivos:

1. **Nunca mexe com o Discord aberto.** O instalador do Equicord *falha* se o Discord estiver rodando (e pode deixar o Discord quebrado). Agora o programa fecha o Discord de propósito, aplica, e reabre.
2. **Espera a atualização terminar.** O Discord troca as pastas várias vezes enquanto atualiza. Agora ele espera tudo estabilizar (30s parado) antes de encostar.
3. **Confere o resultado de verdade.** Não confia no "deu certo" do instalador: ele olha os arquivos, espera 12s e olha de novo — porque o Discord já desfez o trabalho pelas costas antes.
4. **Quarentena.** Se falhar **3 vezes** na mesma versão do Discord, ele **desiste**, deixa o Discord puro e funcionando, e avisa. Nunca fica tentando pra sempre.

> Para destravar depois de uma quarentena: menu → opção **8** (ou **3** para tentar na hora).

---

## ✅ Como sei que tá funcionando?

Abra o `menu.bat` e aperte **2**:

```
Discord .......... instalado (app-1.0.9251)
Equicord .......... APLICADO          ✅
Tarefa ........... registrada        ✅
Vigia ............ rodando           ✅
Auto-reparo ...... ativo, sem falhas ✅
```

Ou, dentro do Discord: **Configurações → procure "Equicord"**. 😎

---

## 🚨 Deu erro? Provavelmente é o antivírus

Antivírus (tipo o **Kaspersky**) às vezes acha que "um programa que se reinstala sozinho" é vírus — porque vírus fazem isso. Aqui é de boa, mas talvez você precise **avisar o antivírus que pode confiar**:

1. Abra o antivírus → **Exclusões** / **Aplicativos confiáveis**.
2. Adicione a pasta `C:\Users\SEU-NOME\EquicordAutoRepair` e o `powershell.exe`.

---

## 🧠 "Mas como isso funciona por dentro?"

*(Só leia se for curioso.)*

- Usa o instalador **oficial** do Equicord, conferido por SHA256 antes de rodar.
- Um "vigia" roda escondido e observa o Discord (sem gastar CPU à toa).
- Guarda tudo em `C:\Users\SEU-NOME\EquicordAutoRepair`:
  - `watch.log` — histórico de tudo que ele fez
  - `config.json` — suas opções (as do menu)
  - `state.json` — contador de falhas / quarentena
- **Não** precisa de administrador. **Não** roda de hora em hora. **Não** aplica nada no login.

### ⚠️ Duas pastas: a do projeto e a instalada

Esta pasta (com o `menu.bat`) é a **fonte**. Ao apertar **1**, os scripts são **copiados** para `C:\Users\SEU-NOME\EquicordAutoRepair`, e é a **cópia** que roda sozinha.

Ou seja: se você **baixar uma versão nova** deste projeto, precisa apertar **1** de novo para valer. Se esquecer, o que roda continua sendo o antigo.

Para não cair nessa, o **status (opção 2)** avisa:

```
Versao ........... DESATUALIZADA - o que roda sozinho e mais antigo que esta pasta
                   rode a opcao [1] do menu para atualizar
```

### Como ele sabe se o Equicord está aplicado

O Equicord renomeia o `app.asar` do Discord para `_app.asar` e põe o dele no lugar. Então:

| Arquivos | Significa |
|---|---|
| `app.asar` + `_app.asar` | ✅ Equicord aplicado |
| só `app.asar` | ⚪ Discord puro |
| falta o `app.asar` | ❌ **Quebrado** — o Discord abre e fecha sozinho |
| pasta só com `.dll` e `.exe` | ⏳ **Update baixado pela metade** — ignorado |

O programa detecta o caso ❌ e conserta.

### ⏳ Updates do Discord baixados pela metade

Às vezes o Discord começa a baixar uma versão nova e **não termina** (você desliga o PC, cai a internet...). Sobra uma pasta com o `Discord.exe` e os `.dll`, mas **sem o `app.asar`**.

Isso **não é problema**: o Discord continua rodando na versão antiga normalmente. O programa reconhece essas pastas e **passa reto** — não tenta aplicar o Equicord nelas. O status mostra assim:

```
Equicord .......... APLICADO
Update pendente .. app-1.0.9252 - baixado pela metade, ignorado
```

Quando o Discord terminar de baixar aquela versão, aí sim o Equicord é aplicado nela automaticamente.

---

## 🧩 Build personalizado (plugins compilados por você)

Se você compila o Equicord da fonte para incluir **userplugins** (plugins que não vêm no Equicord oficial), existe uma pegadinha:

> O Equilotl instala **sempre o build padrão**. Toda vez que o auto-reparo repõe o Equicord depois de uma atualização do Discord, você volta para o build oficial — **sem os seus plugins**, e sem nada avisando.

Por isso o auto-reparo restaura o seu build logo depois de aplicar o patch, antes de reabrir o Discord.

**Como configurar** — em `C:\Users\SEU-NOME\EquicordAutoRepair\config.json`:

```json
{
  "BuildPersonalizado": "C:\\Users\\SEU-NOME\\Equicord\\dist\\desktop.asar"
}
```

Deixe `""` para usar sempre o build padrão.

**Mexeu no código dos plugins?** Menu → opção **13** (roda `pnpm build`) e depois **3** para aplicar.

O status (opção **2**) mostra se está valendo de verdade:

```
Equicord ......... APLICADO
Build proprio .... ATIVO no Discord
```

Se a restauração falhar, aparece uma **caixa de aviso na tela** — porque o Equicord voltaria funcionando e você não notaria que os seus plugins sumiram.

---

## 📜 Uso

**Projeto particular.** © 2026 yagoriccomi — todos os direitos reservados.

Repositório privado, **sem licença de uso**: não é software livre, não está aberto para redistribuição ou modificação por terceiros.

---

## 📄 Aviso

O Equicord é um mod do Discord. Usar é decisão sua. Este projeto só automatiza colocar um programa **open-source** de volta no **seu próprio** computador. 🙂
