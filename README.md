# 🐒 Vencord Auto-Repair

**Bota o Vencord no seu Discord e nunca mais deixa ele sumir.**

O Discord adora se atualizar sozinho, e toda vez que ele faz isso, ele **apaga o Vencord**. Que saco, né? Este programa resolve isso: ele fica de olho e **coloca o Vencord de volta sozinho**, sem você fazer nada.

---

## 🎯 O que ele faz (em 1 frase)

> Se o Discord tirar o Vencord, ele bota de volta. Automático. Fim.

Ele só age em **2 momentos**:
- 🔄 Quando o Discord **se atualiza**.
- ▶️ Quando você **abre o Discord**.

Fora isso, ele fica quietinho no cantinho, gastando quase nada.

---

## 🚀 Como usar (3 passos)

```
1. Baixe esta pasta
2. Dê 2 cliques no arquivo  menu.bat
3. Aperte a tecla  1  e dê Enter
```

Pronto! Agora **feche e abra o Discord** uma vez. Acabou. 🎉

> ⚠️ Você precisa já ter o **Discord** instalado antes.

---

## 🎮 Os botões do menu

Quando você abre o `menu.bat`, aparece uma listinha. É só digitar o número e apertar Enter:

| Aperte | O que acontece |
|:------:|----------------|
| **1** | 📥 Instala o Vencord e liga o "guarda-costas" (é o que você usa da primeira vez) |
| **2** | 🔎 Mostra se tá tudo funcionando |
| **3** | 🔧 Bota o Vencord de volta agora, na marra |
| **4** | 📜 Mostra o "diário" do que o guarda-costas andou fazendo |
| **5** | 🔁 Religa o guarda-costas (se ele bugar) |
| **6** | 🛑 Desliga o guarda-costas (o Vencord continua, mas não volta mais sozinho) |
| **7** | 🗑️ Apaga tudo (tira o Vencord e desliga o guarda-costas) |
| **0** | 🚪 Fecha o menu |

---

## ✅ Como sei que tá funcionando?

Abra o `menu.bat` e aperte **2**. Se aparecer isso, tá tudo certo:

```
Discord: instalado
Vencord: APLICADO        ✅
Tarefa: Running          ✅
Vigia: rodando           ✅
```

Ou, dentro do Discord: **Configurações → role até achar "Vencord"**. Se estiver lá, tá funcionando. 😎

---

## 🛑 Como desligo?

- Só quero **parar o auto-reparo** (mas manter o Vencord): menu, aperte **6**.
- Quero **tirar tudo**: menu, aperte **7**.

---

## 🚨 Deu erro? Provavelmente é o antivírus

Antivírus (tipo o **Kaspersky**) às vezes acha que "um programa que se reinstala sozinho" é vírus — porque vírus fazem isso. Aqui é de boa (é o seu PC e um programa conhecido), mas talvez você precise **avisar o antivírus que pode confiar**:

1. Abra o antivírus.
2. Procure por **Exclusões** / **Aplicativos confiáveis**.
3. Adicione a pasta `C:\Users\SEU-NOME\Vencord` e os processos `wscript.exe` e `powershell.exe`.

Depois é só rodar o menu de novo. 👍

---

## 🧠 "Mas como isso funciona por dentro?"

*(Só leia se você for curioso — não precisa entender pra usar.)*

- Usa o instalador **oficial** do Vencord (baixado do site deles, conferido pra garantir que não foi adulterado).
- Um "vigia" (um script bem pequeno) roda escondido e fica checando o Discord.
- Ele guarda tudo em `C:\Users\SEU-NOME\Vencord`, incluindo um `watch.log` com o histórico.
- **Não** precisa de senha de administrador. **Não** fica rodando toda hora. **Não** mexe em nada no login.

---

## 📜 Licença

Este projeto usa a **GNU General Public License v3.0** (GPLv3). Resumindo em miúdos: você pode **usar, estudar, mudar e compartilhar** à vontade — só que qualquer versão modificada que você distribuir também precisa ficar aberta sob a mesma licença. O texto completo está no arquivo [`LICENSE`](LICENSE).

```
Copyright (C) 2026 yagoriccomi

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
sob os termos da GNU General Public License, versão 3, publicada pela
Free Software Foundation. Sem QUALQUER GARANTIA. Veja o arquivo LICENSE.
```

---

## 📄 Aviso

O Vencord é um mod (uma modificação) do Discord. Usar é decisão sua. Este projeto só automatiza colocar um programa **open-source** de volta no **seu próprio** computador. 🙂
