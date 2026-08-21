# Arquitetura — o "porquê" por trás do código

Este documento explica **como o sistema pensa**. O [`README.md`](../README.md)
ensina a usar; o [`CLAUDE.md`](../CLAUDE.md) resume as regras; aqui está o
raciocínio, para quem precisa **mudar** o código sem quebrar o que já foi
aprendido a duras penas.

---

## 1. O problema, em uma frase

> O Discord se atualiza sozinho. Cada atualização substitui a pasta do
> aplicativo por uma nova e **limpa** — levando junto o mod que estava aplicado.

Não é bug do mod nem do Discord: é consequência de como o Discord instala
versões. Qualquer solução tem que conviver com isso, não lutar contra.

## 2. Como um mod é "aplicado"

O Discord carrega seu código de `resources/app.asar`. Instalar um mod significa:

```
resources/
  app.asar   ← renomeado para _app.asar (o Discord original, ~16 MB)
  app.asar   ← um atalho novo e minúsculo (~220 B) que carrega o mod
```

Daí sai o **vocabulário de estado** que o sistema inteiro usa:

| Arquivos presentes | Estado | Significado |
|---|---|---|
| `app.asar` + `_app.asar` | `patched` | Mod aplicado |
| só `app.asar` | `pure` | Discord original, sem mod |
| falta `app.asar` | `broken` | **O Discord não abre** |
| pasta só com `.dll`/`.exe` | *incompleto* | Update baixado pela metade — ignorar |

E como o atalho contém **o caminho do mod**, dá para saber *qual* mod está
aplicado — é isso que permite trocar de Vencord para Equicord e detectar
divergência entre o escolhido e o instalado.

## 3. As quatro camadas

```
                 menu.bat  (o usuário)
                     │
     ┌───────────────┼────────────────┐
     ▼               ▼                ▼
  mod-watch.ps1   install.ps1     status.ps1        ← pontos de entrada
     │               │                │
     └───────────────┴────────┬───────┘
                              ▼
                        repair.ps1                   ← REGRA DE NEGÓCIO
                    (decide o que fazer)                "o quê"
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        discord.ps1        ui.ps1         mods.ps1    ← "como"
        (disco e          (fala com       (catálogo
        processos)         o usuário)      dos mods)
```

**Por que separar assim?** Porque cada motivo de mudança fica isolado:

- Mudou o jeito do Discord guardar arquivos → mexe só em `discord.ps1`.
- Mudou o texto de um aviso → mexe só em `ui.ps1`.
- Saiu uma versão nova do instalador → mexe só em `mods.ps1`.

E a mais importante: **`repair.ps1` contém apenas definições**. Carregá-lo não
executa nada. Sem isso, um teste que importasse a regra de negócio dispararia
o laço infinito do vigia — a lógica seria, na prática, intestável.

### Inversão de dependência, na prática

A camada de disco **não conhece** o log nem o console. Ela recebe um
`scriptblock` de quem chama:

```powershell
Stop-DiscordApp -Log { param($m) Log $m }               # vigia → arquivo de log
Stop-DiscordApp -Log { param($m) Write-Host $m }        # menu  → tela
```

Mesma função, dois destinos, zero acoplamento.

## 4. Quando o sistema age

Apenas **dois gatilhos** — nunca em intervalo de tempo, nunca no logon:

| Gatilho | Por quê |
|---|---|
| O Discord **atualizou** | É o momento em que o mod some |
| O Discord foi **aberto** | Pega o caso de a atualização ter ocorrido com o vigia parado |

Rodar de tempo em tempo seria desperdício: o estado só muda nesses dois
momentos.

## 5. O fluxo de um reparo

```
 detecta gatilho
       │
       ▼
 ignora updates incompletos ─────────────► (nada a fazer)
       │
       ▼
 mod certo já aplicado? ──sim──► build próprio ativo? ──sim──► FIM
       │ não                          │ não
       │                              ▼
       │                     repõe só o build próprio
       ▼
 em quarentena? ──sim──► não mexe (evita ciclo infinito)
       │ não
       ▼
 instalador íntegro? (SHA256) ──não──► ABORTA e avisa
       │ sim
       ▼
 Discord aberto? ──sim──► avisa e fecha ──recusado──► adia
       │
       ▼
 aplica ──► confere pelos ARQUIVOS ──► espera 12 s ──► confere DE NOVO
       │                                                    │
    sucesso                                              falhou
       │                                                    │
       ▼                                                    ▼
 restaura build próprio (atômico)              limpa e devolve Discord PURO
       │                                                    │
       ▼                                                    ▼
 reabre e avisa                              conta falha → 3ª = quarentena
                                                            avisa SEMPRE
```

### Por que conferir duas vezes

Porque o updater do Discord **já desfez o patch alguns segundos depois de
aplicado**. Uma única verificação registraria sucesso num estado que não
sobreviveu. A segunda leitura, após intervalo, é o que torna o "sucesso"
confiável.

### Por que a falha devolve o Discord *puro*

Entre "Discord com mod quebrado" e "Discord sem mod", a segunda opção é
sempre melhor: o usuário continua conseguindo conversar. O programa **nunca**
deixa um Discord inutilizável como resultado de uma tentativa falha.

## 6. As travas contra o pior cenário

O pior cenário não é "o mod não instalou". É **"o Discord não abre mais"** ou
**"o Discord fecha sozinho toda vez que abro"**. Ambos já aconteceram nesta
base, e cada trava existe por causa disso:

| Trava | Impede |
|---|---|
| Fechar o Discord antes de aplicar | Patch parcial → Discord que morre ao abrir |
| Esperar estabilizar (30 s) | Agir no meio do update e ser desfeito |
| Conferir arquivos 2× | Declarar sucesso que não sobreviveu |
| Exigir `.asar` na pasta | Eleger download pela metade como "versão atual" |
| Quarentena (3 falhas) | Ciclo infinito de fechar/abrir |
| Checksum antes de executar | Rodar binário adulterado, sem supervisão |
| Escrita atômica | Cópia interrompida truncar o arquivo bom |
| Mutex de operação | Dois reparos escrevendo no mesmo arquivo |

## 7. Build próprio (o caso do GoLiveBypass)

Quem compila o Equicord da fonte com `userplugins` próprios enfrenta uma
armadilha silenciosa:

> O instalador oficial instala **sempre o build padrão**. Depois de cada reparo,
> o mod volta funcionando — **sem os seus plugins**, e sem nada avisando.

Por isso o sistema, após aplicar o patch e **antes de reabrir**, copia o build
próprio por cima do padrão. Ele detecta a divergência comparando **hash**, não
data nem tamanho.

A cópia é **atômica** — temporário e depois rename — porque escrever 16 MB
direto sobre o arquivo que o Discord carrega abre uma janela em que qualquer
interrupção deixa o Discord sem abrir.

## 8. Testes: por que eles são seguros

Testar este código é delicado: ele **encerra processos** e **substitui
binários**. Um teste descuidado fecharia o Discord de verdade.

A solução é **injeção por ambiente**: os caminhos (`%LOCALAPPDATA%`,
`%USERPROFILE%`) são resolvidos **no momento em que o script é carregado**.
Então o teste os aponta para uma pasta temporária *antes* de carregar — e todo
o código passa a operar num Discord de mentira.

O que exige processo de verdade (o teste de concorrência) usa `Start-Job`,
porque **mutex nomeado do Windows é reentrante na mesma thread**: um teste que
segurasse a trava na própria thread passaria sem testar nada.

---

## Para onde olhar quando algo der errado

| Sintoma | Onde investigar |
|---|---|
| Mod some depois de atualizar | `watch.log` — procure `aplicando` e `SUCESSO` |
| Discord abre e fecha sozinho | Estado `broken`: falta o `app.asar` |
| Plugins próprios sumiram | `status` → linha `Build proprio` |
| Auto-reparo parou | Provável quarentena → menu opção **[11]** |
| Caixa de erro com checksum | Instalador adulterado ou corrompido — apague e reinstale |
