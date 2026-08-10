# 🐒 Vencord Auto-Repair

**Bota o Vencord no seu Discord e nunca mais deixa ele sumir.**

O Discord adora se atualizar sozinho, e toda vez que ele faz isso, ele **apaga o Vencord**. Que saco, né? Este programa resolve isso: ele fica de olho e **coloca o Vencord de volta sozinho** — agora avisando na tela e sem sustos.

---

## 🎯 O que ele faz (em 1 frase)

> Se o Discord tirar o Vencord, ele bota de volta, te avisa e reabre o Discord. Fim.

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
| ✅ **Deu certo** | Caixa avisando que o Vencord foi aplicado. Fecha sozinha em 8s. *(dá pra desligar no menu — opção 5)* |
| ❌ **Deu errado** | Caixa vermelha com **o código e a mensagem exata do erro**. Fica na tela até você clicar OK. **Não dá pra desligar** — falha você sempre precisa saber. |

**E o Discord reabre sozinho** depois de aplicar. Se falhar, ele **limpa o Vencord e abre o Discord puro**, para você nunca ficar sem Discord.

---

## 🎮 Os botões do menu

Abra o `menu.bat`, digite o número e dê Enter:

| Aperte | O que acontece |
|:------:|----------------|
| **1** | 📥 Instala o Vencord e liga o guarda-costas *(use na primeira vez)* |
| **2** | 🔎 Mostra se tá tudo funcionando |
| **3** | 🔧 Aplica/repara o Vencord agora *(destrava até a quarentena)* |
| **4** | ▶️ Abre o Discord |
| **5** | ✅ Liga/desliga o aviso de **sucesso** |
| **6** | 🔔 Liga/desliga a **pergunta** antes de fechar o Discord |
| **7** | 🔁 Liga/desliga **reabrir o Discord** sozinho |
| **8** | 🔓 **Destrava** o auto-reparo (zera a quarentena) |
| **9** | 📜 Mostra o diário (log) |
| **10** | ♻️ Reinstala a tarefa agendada |
| **11** | 🛑 Desliga o auto-reparo (o Vencord continua) |
| **12** | 🗑️ Apaga tudo |
| **0** | 🚪 Sai |

---

## 🛡️ Por que ele não vira um loop infinito

Já aconteceu de o Discord abrir e fechar sozinho várias vezes seguidas. **Isso não acontece mais**, por 4 motivos:

1. **Nunca mexe com o Discord aberto.** O instalador do Vencord *falha* se o Discord estiver rodando (e pode deixar o Discord quebrado). Agora o programa fecha o Discord de propósito, aplica, e reabre.
2. **Espera a atualização terminar.** O Discord troca as pastas várias vezes enquanto atualiza. Agora ele espera tudo estabilizar (30s parado) antes de encostar.
3. **Confere o resultado de verdade.** Não confia no "deu certo" do instalador: ele olha os arquivos, espera 12s e olha de novo — porque o Discord já desfez o trabalho pelas costas antes.
4. **Quarentena.** Se falhar **3 vezes** na mesma versão do Discord, ele **desiste**, deixa o Discord puro e funcionando, e avisa. Nunca fica tentando pra sempre.

> Para destravar depois de uma quarentena: menu → opção **8** (ou **3** para tentar na hora).

---

## ✅ Como sei que tá funcionando?

Abra o `menu.bat` e aperte **2**:

```
Discord .......... instalado (app-1.0.9251)
Vencord .......... APLICADO          ✅
Tarefa ........... registrada        ✅
Vigia ............ rodando           ✅
Auto-reparo ...... ativo, sem falhas ✅
```

Ou, dentro do Discord: **Configurações → procure "Vencord"**. 😎

---

## 🚨 Deu erro? Provavelmente é o antivírus

Antivírus (tipo o **Kaspersky**) às vezes acha que "um programa que se reinstala sozinho" é vírus — porque vírus fazem isso. Aqui é de boa, mas talvez você precise **avisar o antivírus que pode confiar**:

1. Abra o antivírus → **Exclusões** / **Aplicativos confiáveis**.
2. Adicione a pasta `C:\Users\SEU-NOME\Vencord` e o `powershell.exe`.

---

## 🧠 "Mas como isso funciona por dentro?"

*(Só leia se for curioso.)*

- Usa o instalador **oficial** do Vencord, conferido por SHA256 antes de rodar.
- Um "vigia" roda escondido e observa o Discord (sem gastar CPU à toa).
- Guarda tudo em `C:\Users\SEU-NOME\Vencord`:
  - `watch.log` — histórico de tudo que ele fez
  - `config.json` — suas opções (as do menu)
  - `state.json` — contador de falhas / quarentena
- **Não** precisa de administrador. **Não** roda de hora em hora. **Não** aplica nada no login.

### Como ele sabe se o Vencord está aplicado

O Vencord renomeia o `app.asar` do Discord para `_app.asar` e põe o dele no lugar. Então:

| Arquivos | Significa |
|---|---|
| `app.asar` + `_app.asar` | ✅ Vencord aplicado |
| só `app.asar` | ⚪ Discord puro |
| falta o `app.asar` | ❌ **Quebrado** — o Discord abre e fecha sozinho |

O programa detecta o caso ❌ e conserta.

---

## 📜 Licença

**GNU General Public License v3.0** (GPLv3). Você pode **usar, estudar, mudar e compartilhar** — versões modificadas também precisam ficar abertas sob a mesma licença. Texto completo em [`LICENSE`](LICENSE).

```
Copyright (C) 2026 yagoriccomi

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
sob os termos da GNU General Public License, versão 3, publicada pela
Free Software Foundation. Sem QUALQUER GARANTIA. Veja o arquivo LICENSE.
```

---

## 📄 Aviso

O Vencord é um mod do Discord. Usar é decisão sua. Este projeto só automatiza colocar um programa **open-source** de volta no **seu próprio** computador. 🙂
