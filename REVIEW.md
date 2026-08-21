# 🔍 Relatório de Auditoria e Revisão de Código

**Projeto:** Discord Mod Auto-Repair · **Data:** 21/08/2026 · **Base:** 16 arquivos, ~1.400 linhas
**Stack:** PowerShell 5.1 + Batch + VBScript · **Escopo:** 100% da base lida

---

## 📊 Resumo Executivo

Projeto **maduro em engenharia** e com **um furo de segurança relevante**. Depois da refatoração em camadas e da suíte de 58 testes, a base está coesa, com responsabilidades separadas e as regressões históricas travadas por teste.

O risco real deste software **não é web** — não há query, render, cookie, sessão ou origem. É **execução de binário externo, integridade de arquivos e destruição de dados na máquina do usuário**. A auditoria foi conduzida sobre essa superfície.

**O achado que importa:** a verificação SHA256 existe, mas **só no caminho de instalação manual**. O vigia — que roda sozinho, sem supervisão, a cada atualização do Discord — executa o mesmo binário **sem verificar nada**. Isso transforma a pasta de instalação num alvo de persistência: quem conseguir escrever ali ganha execução automática e recorrente.

**Nível de risco no momento da auditoria: MÉDIO-ALTO**, concentrado em 1 item crítico e 2 altos.

### ✅ Situação após as correções (21/08/2026, mesmo dia)

Todos os achados de Crítico a Baixo foram corrigidos e **verificados na prática**, não só por teste unitário:

| # | Achado | Status | Verificação |
|:-:|---|:-:|---|
| 1 | Binário executado sem checksum no caminho automático | **Corrigido** | Adulterei 1 byte do instalador: o vigia **recusou executá-lo** e não tocou no Discord |
| 2 | Cópia de 16 MB não atômica | **Corrigido** | Temporário + `Move-Item`; teste garante que a falha **preserva** o build anterior |
| 3 | `SilentlyContinue` global | **Corrigido** | Trocado por `Stop` + falha contida que avisa em vez de engolir |
| 4 | Sem CI | **Corrigido** | GitHub Actions verde na 1ª execução (52 s): lint + 64 testes como gate |
| 5 | Log sem rotação / cabeçalhos defasados | **Corrigido** | Rotação em 1 MB; três cabeçalhos padronizados |

**O que a correção nº 3 revelou de imediato:** ao ligar o `Stop`, o ciclo real quebrou na hora. O PowerShell 5.1 embrulha **cada linha de stderr de um `.exe`** num `ErrorRecord` — e o instalador escreve `INFO Patching...` no stderr. Ou seja, sob `Stop`, um patch **bem-sucedido** virava erro terminante. Resolvido com um executor dedicado (`Invoke-Instalador`) que isola essa captura, deixando o sucesso ser decidido pelo exit code e pela conferência dos arquivos — nunca pelo stream de erro. Suíte: **64 testes**, todos passando.

### Sobre LGPD — e por que não há achado crítico aqui

A skill trata a ausência de fluxo de exclusão como Risco Crítico. **Não se aplica a este software, e afirmar o contrário seria inventar achado.** Justificativa concreta:

- Não há **titular de dados** além do próprio operador da máquina;
- Não há **coleta**, **transmissão** ou **compartilhamento**: nada sai do computador;
- Não há banco, servidor, telemetria ou endpoint.

O único dado pessoal presente é o **nome de usuário do Windows**, embutido nos caminhos gravados em `watch.log` — arquivo local, do próprio titular, na própria máquina. Está registrado abaixo como Risco Baixo, que é a classificação honesta.

---

## 🚨 Risco Crítico (Segurança)

* **[Execução de binário não verificado no caminho automático]**: O checksum SHA256 é conferido **apenas** em `install.ps1`. O vigia e o desinstalador executam o `.exe` diretamente, sem qualquer verificação de integridade. Como o vigia roda **sem supervisão** a cada atualização do Discord, um binário substituído em `%USERPROFILE%\DiscordModAutoRepair\` seria executado automaticamente, de forma recorrente e silenciosa. A pasta é gravável pelo usuário (e por qualquer processo rodando como ele) e está, por orientação do próprio README, **excluída da varredura do antivírus** — o que remove a última rede de proteção. Quebra o princípio do menor privilégio e a cadeia de confiança [#55][#51].
* **Onde está:** `scripts/repair.ps1:272` e `:328` (vigia), `scripts/uninstall.ps1:46`. Verificação existente só em `scripts/install.ps1:46-52`.
* **Como corrigir:** extrair a verificação para `mods.ps1` como função reutilizável e chamá-la **imediatamente antes de cada execução**, não só na instalação:
  ```powershell
  function Test-InstaladorConfiavel($exe, $info) {
      if (-not (Test-Path $exe)) { return $false }
      return ((Get-FileHash $exe -Algorithm SHA256).Hash.ToLower() -eq $info.Sha256)
  }
  ```
  No `repair.ps1`, trocar o `Test-Path $exe` atual por essa checagem e **abortar com aviso na tela** se falhar — checksum divergente é exatamente o cenário que o usuário precisa saber.

---

## 🐛 Risco Alto (Bugs e Arquitetura)

* **[Escrita não atômica de 16 MB sobre arquivo vivo]**: `Restore-CustomBuild` faz `Copy-Item` do build próprio **direto por cima** do `.asar` que o Discord carrega. Se a cópia for interrompida no meio (queda de energia, falta de espaço, antivírus travando o arquivo), o destino fica **truncado** e o Discord não abre — o mesmo sintoma que este projeto existe para evitar. A verificação de tamanho posterior *detecta* o estrago, mas depois de já ter destruído o arquivo bom. Quebra o tratamento de falha previsível [#93][#9].
* **Onde está:** `scripts/repair.ps1` (função `Restore-CustomBuild`, `Copy-Item $origem $destino -Force`).
* **Como refatorar:** escrever em temporário e promover por rename, que é atômico no mesmo volume:
  ```powershell
  $tmp = "$destino.novo"
  Copy-Item $origem $tmp -Force -ErrorAction Stop
  if ((Get-Item $tmp).Length -ne (Get-Item $origem).Length) { Remove-Item $tmp -Force; return $false }
  Move-Item $tmp $destino -Force        # troca atomica
  ```

* **[`SilentlyContinue` global mascara falhas no componente que mais precisa falhar alto]**: `repair.ps1:7` define `$ErrorActionPreference = 'SilentlyContinue'` para o arquivo inteiro. Isso significa que erros inesperados em qualquer ponto do reparo — permissão negada, disco cheio, arquivo travado — são **engolidos**, e o fluxo segue como se nada tivesse acontecido, podendo tomar decisões erradas sobre um estado que falhou em silêncio. Contradiz o tratamento explícito de erros [#93] e a visibilidade de falhas [#92].
* **Onde está:** `scripts/repair.ps1:7`.
* **Como refatorar:** trocar o padrão global por `'Stop'` e envolver as operações que **legitimamente** podem falhar (leitura de config, sondagem de processo) em `try/catch` explícitos — que já existem nos pontos certos e são cobertos por teste. O padrão silencioso deveria ser a exceção documentada, não a regra do arquivo.

---

## ⚠️ Risco Médio (Robustez e Infraestrutura)

* **[Log sem rotação: cresce para sempre]**: `Log` faz `Out-File -Append` sem qualquer limite. O vigia registra a cada abertura do Discord e a cada atualização, indefinidamente. Não é urgente (hoje são ~2 KB após semanas), mas é dívida garantida num processo que roda desde o logon [#91][#92].
* **Impacto:** crescimento ilimitado em disco; log grande fica inútil para diagnóstico.
* **Solução:** rotacionar por tamanho na própria função `Log` — se passar de ~1 MB, renomear para `watch.log.1` e recomeçar. Cinco linhas, resolve de vez.

* **[Caminhos vindos de `config.json` usados sem validação]**: `BuildPersonalizado` e `AsarDoMod` são lidos do JSON e usados como origem/destino de cópia; `rebuild.ps1` deriva desse caminho o diretório onde executa `pnpm build` — ou seja, um `package.json` malicioso naquele diretório executaria seus scripts. **Ressalva honesta de modelo de ameaça:** o arquivo fica em `%USERPROFILE%`, então quem consegue editá-lo já tem o mesmo privilégio do usuário e poderia agir diretamente. Isso rebaixa de Crítico para Médio — mas continua valendo como defesa em profundidade [#51].
* **Impacto:** sobrescrita de arquivo arbitrário / execução de script arbitrário a partir de um arquivo de configuração adulterado.
* **Solução:** validar que `AsarDoMod` termina em `.asar` e reside sob `%APPDATA%`, e que `BuildPersonalizado` existe e é arquivo — rejeitando com aviso em vez de obedecer cegamente.

* **[Sem CI: os testes não eram gate de nada]** — ✅ **RESOLVIDO**: a suíte existia e passava, mas nada a executava automaticamente. Um commit que quebrasse a base só apareceria na próxima falha real, na máquina do usuário [#49][#76].
* **Impacto:** a rede de proteção dependia de alguém lembrar de rodá-la.
* **Solução aplicada:** `.github/workflows/ci.yml` — PSScriptAnalyzer + Pester como gate em `windows-latest`. Verificado: **verde na primeira execução**, 52 s, 64 testes. Sem deploy e sem secrets (não há o que implantar).

---

## 💡 Risco Baixo (Clean Code e Dívida Técnica)

* **[Nome de usuário do Windows nos logs locais]**: `watch.log` grava caminhos completos (`C:\Users\<usuario>\...`) e a saída bruta do instalador. É dado pessoal em sentido amplo, porém **local, do próprio titular e nunca transmitido**. Não há CPF, credencial, token ou dado de terceiro [#63].
* **Recomendação:** nenhuma ação necessária para uso pessoal. **Se um dia** o log for anexado a um relatório de bug público, mascarar o segmento do usuário antes de compartilhar.

* **[Cabeçalhos defasados após a renomeação do projeto]**: três arquivos ainda se identificam como "Equicord Auto-Repair", nome anterior do projeto, que hoje suporta os dois mods. Confunde quem for ler o código depois [#1][#14].
* **Onde está:** `scripts/notify.vbs:1`, `scripts/register-task.ps1:1`, `scripts/uninstall.ps1:1`.
* **Recomendação:** padronizar para "Discord Mod Auto-Repair".

* **[`catch { }` vazios]**: oito ocorrências. A maioria é **deliberada e testada** (config/estado corrompidos devem cair no padrão, e há teste para isso). Uma merece atenção: `ui.ps1:27` engole falhas ao exibir a caixa de aviso — se a notificação falhar, o usuário fica sem **nenhum** sinal, justamente no caminho de erro que o projeto promete sempre reportar [#93].
* **Recomendação:** em `ui.ps1`, registrar no log quando a caixa não puder ser exibida. Os demais podem permanecer, com comentário explicando o porquê.

---

## ✅ Plano de Ação Imediato

1. **Verificar o checksum antes de TODA execução do instalador**, não só na instalação manual (`repair.ps1`, `uninstall.ps1`). É o único achado crítico e o de correção mais barata. *(Risco Crítico)*
2. **Tornar atômica a troca do `.asar`** (temporário + `Move-Item`), eliminando a janela em que uma cópia interrompida quebra o Discord. *(Risco Alto)*
3. **Substituir o `SilentlyContinue` global** por `Stop` + `try/catch` nos pontos que legitimamente falham, para o reparo parar de decidir sobre estado que falhou em silêncio. *(Risco Alto)*
4. ~~**Concluir a etapa de CI**~~ — ✅ feito: 64 testes viraram gate real de cada push.
5. ~~**Rotacionar o log** e padronizar os cabeçalhos defasados~~ — ✅ feito.

### 📌 Pendência aberta (não urgente)

* **[Ações do CI usando Node 20, que está sendo descontinuado]**: o GitHub anotou na execução que `actions/checkout@v4` e `actions/cache@v4` têm como alvo o Node 20, já depreciado. **Não quebra hoje** — o runner as força a rodar em Node 24 —, mas vai parar de funcionar quando o suporte sair de vez [#62].
* **Onde está:** `.github/workflows/ci.yml`, passos `actions/checkout@v4` e `actions/cache@v4`.
* **Como corrigir:** subir as duas para `@v5`. São duas linhas. Deixado para a próxima alteração do projeto em vez de um push só para isso, porque cada execução consome cota de CI e o risco atual é zero.

---

## 🔎 Verificado e SEM achado

Registrado para que "não auditado" não se confunda com "aprovado":

| Item | Resultado |
|---|---|
| Segredos versionados (tokens, senhas, chaves) | **Nenhum** — varredura em toda a base |
| `.gitignore` | Correto: exclui `.exe` e logs [#40] |
| SQLi / XSS / CSRF / CORS / JWT | **Não se aplica** — sem query, render, cookie, origem ou sessão |
| Dependências de terceiros no código | **Nenhuma** — binários são baixados em runtime, não redistribuídos |
| Escalonamento de privilégio | Tarefa roda como usuário comum, `RunLevel Limited` — sem admin [#55] |
| HTTPS nos downloads | Sim, releases oficiais do GitHub via TLS [#60] |
| Corrida entre reparo manual e automático | **Corrigido** nesta sessão (mutex de operação) e coberto por teste |
