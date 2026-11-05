# Rotina automática da dash DEDZ

Este roteiro é seguido pelas tarefas agendadas das **11:01** (meio do dia do jogo), das **19:01** (começa o combo de pontuação do VS) e das **23:01** (logo depois do dia virar às 23:00), horário de Brasília (o app atrasa alguns minutos: ~11:12, ~19:07 e ~23:07), sem ninguém acompanhando. Leia o `CONTEXTO.md` só se precisar de mais detalhes; tudo o que a rotina precisa está aqui.

Regras gerais:
- **Ninguém está olhando.** Não faça perguntas; quando algo impedir a coleta, pare e avise (passo 8).
- **Nunca digite senha nem PIN.** Se o jogo pedir login ou PIN, feche o jogo, pare e avise.
- **O jogo só fica aberto durante a leitura:** abra no passo 2 e feche no passo 4b.
- **NUNCA envie nada na aba "Mundo" (chat global), em nenhuma hipótese.** Nem nas abas "Aliança", "Duelo" ou "Atividades". O único envio permitido no jogo é no "Chat privado", pelo passo 7c, depois do "pode enviar" do usuário.
- **No jogo, só leia rankings.** Não clique em nada que gaste recursos, aceite convites, envie mensagens ou mexa em membros (o botão "Expulsar da aliança" fica perto do chat privado).
- Antes de cada clique, confira pelo print onde está. Volte para a cidade com o botão de voltar ou `ESC` (`scripts\lz.ps1 -Action key`) quando aparecer algo inesperado.
- Pasta de trabalho: `C:\lz`. Scripts: `scripts\` deste repositório. Git: `%LOCALAPPDATA%\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`.
- Dash: https://claude.ai/artifact/3aii6XvyJi7PcP8zSShU1n (o banco é o `ArtifactData` desse URL).

## 1. Ver o que coletar

Rode `scripts\hoje.ps1`. Ele devolve `semana`, `dia` (0 = segunda … 6 = domingo), `temVS` e `diaAnterior`.

| Execução | VS | Doação |
|---|---|---|
| 11:01 | VS parcial do `dia` (se `temVS`) e o VS final de `diaAnterior` (se não for -1; confere/corrige o da noite) | sim |
| 19:01 | VS parcial do `dia` (se `temVS`). Não precisa reler o dia anterior | sim |
| 23:01 | VS **final** de `diaAnterior` (o dia que acabou de fechar). O VS do novo `dia` está começando: não colete | sim, exceto no caso abaixo |

Às 23:01 o `hoje.ps1` já aponta para o novo dia, então o dia que fechou é o `diaAnterior`. **Virada da semana (domingo 23:01):** `hoje.ps1` devolve a semana nova com `dia` 0 e `diaAnterior` -1; o ranking semanal de doação zerou e o VS de sábado já foi gravado no sábado às 23:01. Nesse horário não colete nada no jogo: só gere e envie os relatórios (`relatorio.ps1 -Turno fechamento` já analisa o domingo e fecha a semana que acabou).
## 2. Deixar o jogo pronto

1. `scripts\jogo.ps1 -Acao abrir`. O jogo entra sozinho, sem PIN (o PIN foi tirado em 03/11), e chega na cidade em uns 30 segundos.
2. Tire um print (`scripts\lz.ps1 -Action shot -Out C:\lz\s.png`) e olhe:
   - Ainda carregando → espere 15 segundos e tire outro.
   - Tela de **Código PIN** ou login → pare (passo 8, sem esquecer de fechar o jogo) e avise "o jogo pediu o PIN".
   - Vídeo de entrada → botão **Pular** (canto superior direito).
   - Janelas abertas (cartão de perfil, ofertas, eventos) → feche no X ou com `ESC` até ver a cidade.
3. O `lz.ps1` imprime o tamanho da janela (a posição na tela pode mudar; as coordenadas são relativas à janela). As coordenadas abaixo são para **623x993** (desde 04/11, com a barra de tarefas do Windows fixa). Se o tamanho for outro, ache os botões pelo print.
4. Se o `lz.ps1` falhar com "Janela do jogo nao ficou em primeiro plano", ou o print sair preto, o PC deve estar bloqueado → pare e avise.

## 3. Coletar o VS

**Placar do duelo (antes do ranking):** ao abrir o jogo costuma aparecer a janela "Confronto de Alianças em andamento" com a Pontuação total (ex.: 0 : 1) e as porcentagens (ex.: 48% x 52%). Se ela não aparecer, a tela principal do botão VS mostra o mesmo. Grave em `C:\lz\duelo.json`, por exemplo `{"placar":"0:1","nos":48,"eles":52,"adversario":"[VVD]"}` (nós = DEDZ, à esquerda). Às 23:01 o placar já inclui o dia que fechou. Se não conseguir ler, apague `C:\lz\duelo.json` para não usar um placar velho.

Na cidade: botão **VS** (587,213; à direita, abaixo de "Atividades Populares") → **Ranking** (505,62) → **Ranking Diário** (já vem selecionado) → marque **Minha Aliança** (240,782) e confira pelo print que o visto apareceu. As abas dos dias ficam em y=262: Seg 145 · Ter 210 · Qua 277 · Qui 345 · Sex 411 · Sáb 478.

Para cada dia a coletar:
1. Clique na aba do dia e confira pelo print que ela ficou selecionada e que "Minha Aliança" continua marcado.
2. Role a lista para o topo: `scripts\lz.ps1 -Action drag -X 300 -Y 400 -X2 300 -Y2 900` (duas vezes).
3. Confira pelo print que a aba de cima é **Ranking Diário** (laranja). Em 03/11 ela pulou para "Ranking Semanal" durante a rolagem: os valores ficam bem maiores (somam os dias) e o 1º lugar muda. Se isso acontecer, volte ao Diário (176,204), clique no dia e refaça o scan.
4. `scripts\scan.ps1 -Tag vs<dia> -Drags 40 -FromY 627 -ToY 380 -CX 113 -CY 292 -CW 400 -CH 372 -PerGrid 4`
5. Leia as grades `C:\lz\G_vs<dia>_N.png` e escreva `C:\lz\vs<dia>.tsv` (UTF-8, uma linha por membro: `posição<TAB>nome<TAB>valor`, sem separador de milhar). Todos os membros ativos precisam aparecer (96 desde a saída de GAMZ€ em 03/11); a última grade deve terminar na última posição. Se faltar gente no fim, role mais e tire outro print.
   - Copie os nomes exatamente como aparecem (com ², ³, ¹, •, ツ, 亥, €, Ø). O `atualiza.ps1` ignora espaços e acentos.
   - Dica: `C:\lz\estado\registros.json` tem os valores já gravados. Na leitura do mesmo dia, a maioria não muda; compare para pegar erros de leitura.

Feche o ranking no X (495,152) e volte para a cidade (botão de voltar, 120,945; se não responder, `ESC`).

## 4. Coletar a doação semanal

Na cidade: **Aliança** (587,748) → **Ranking** (205,795) → aba **Contribuição** (463,90) → **Semanal** (418,145). Use sempre o Semanal. **Nunca clique no botão verde "Doar"** (rodapé, 311,950): ele gasta recursos.

1. Role para o topo (drag de 400 para 760, duas vezes; nunca arraste a partir do rodapé, onde fica o "Doar").
2. `scripts\scan.ps1 -Tag doa -Drags 28 -FromY 760 -ToY 400 -CX 98 -CY 218 -CW 430 -CH 580 -PerGrid 3`
3. Leia `C:\lz\G_doa_N.png` e escreva `C:\lz\doacao_semanal.tsv` no mesmo formato. Todos os membros ativos precisam aparecer.

Volte para a cidade (120,945, duas vezes; ou `ESC`).

## 4b. Fechar o jogo

Assim que os TSVs estiverem escritos e conferidos (todos os 97 em cada um), feche o jogo: `scripts\jogo.ps1 -Acao fechar`. Feche também quando a rotina parar por erro em qualquer passo depois de abrir o jogo.

## 5. Gravar no banco

Para cada leitura, **uma de cada vez** (o espelho precisa ser confirmado antes da próxima):

**11:01** (`dia` = hoje):
1. VS final do dia anterior (se `diaAnterior` não for -1 e você coletou):
   `scripts\atualiza.ps1 -Sem <semana> -Dia <diaAnterior> -VsTsv vs<diaAnterior>.tsv -DoaTsv ''`
2. VS parcial de hoje e doação:
   `scripts\atualiza.ps1 -Sem <semana> -Dia <dia> -VsTsv vs<dia>.tsv -DiaDoa <dia>`
   No domingo (sem VS): `scripts\atualiza.ps1 -Sem <semana> -DiaDoa 6`

**19:01** (`dia` = hoje): só o passo 2 do 11:01 (VS parcial de hoje e doação no slot de hoje). No domingo, só a doação.

**23:01** (o dia que fechou é o `diaAnterior`; a doação lida agora é o acumulado do fim desse dia, então vai no slot dele):
1. `scripts\atualiza.ps1 -Sem <semana> -Dia <diaAnterior> -VsTsv vs<diaAnterior>.tsv -DiaDoa <diaAnterior>`
2. Domingo 23:01 (`diaAnterior` -1): nada a gravar.
Depois de cada `atualiza.ps1`:
- **Saída (faça sozinho, sem perguntar):** se o `atualiza.ps1` disser que um membro está "sem leitura de VS" **e** "sem leitura de doação" e você conferiu que a lista do jogo terminou (o último colocado apareceu), a pessoa saiu da aliança. Marque no banco: `ArtifactData` `update` em `membros/<id>` com `{"saiu": "<AAAA-MM-DD de hoje>"}` e o `if_version` dele (pegue com `get`), e faça o mesmo no espelho `C:\lz\estado\membros.json` (adicione `"saiu"` ao membro). Depois rode o `atualiza.ps1` de novo e siga. No relatório da liderança, acrescente no fim a linha `SAÍDA: <nome> deixou a aliança em <dd/mm> (sumiu dos rankings de VS e doação).`. Se a pessoa sumiu de só um dos rankings, não marque: cite no aviso.
- **Entrada ou troca de nome:** "nome do jogo sem membro no banco". Não crie nem renomeie membros sozinho: siga com os outros e cite esses nomes no aviso de erro (passo 8). Os relatórios saem normalmente.
- Mande cada `C:\lz\batchN.json` como `writes` de um `ArtifactData` `batch` no URL da dash.
- Para os lotes aceitos: `scripts\confirma.ps1 -Lotes 0` (ou `0,1`…).
- **Lote recusado por versão** (alguém lançou dados pela dash): nada foi gravado. Baixe os registros da semana com `ArtifactData` `query` (`where semana == <semana>`, `limit` 1000, `out_dir` `C:\lz\dl`), salve o texto do resultado em `C:\lz\versoes.txt`, rode `scripts\sincroniza.ps1 -Colecao registros -Pasta C:\lz\dl\registros -Esperado <quantidade> -Versoes C:\lz\versoes.txt` e repita o `atualiza.ps1`.

## 6. Atualizar a dash

1. `scripts\foto.ps1` (regera a foto em `dash\index.html` a partir do espelho).
2. Leia a dash com `Artifact` `action: "read"` no URL (obrigatório antes de publicar numa sessão nova) e publique `dash\index.html` com `url` igual ao da dash. Não passe `capabilities`.
3. Commit: `git add dash/index.html` e `git commit -m "Rotina <11h|19h|23h>: VS de <dia> e doação (<data>)"`.
4. Push: tente `git push origin main` no shell. Se falhar pedindo usuário, rode o mesmo comando com `run_in_terminal` (o login está guardado no Git Credential Manager). Se ainda falhar, deixe o commit local e cite no aviso.

## 7. Resumo

`scripts\resumo.ps1 -Sem <semana>` dá os números da semana.

## 7b. Relatórios no WhatsApp

Só se a coleta deu certo (dados gravados e dash publicada).

1. `scripts\relatorio.ps1 -Turno <meio|alerta|fechamento>` (11:01 = `meio`, 19:01 = `alerta`, 23:01 = `fechamento`). O `alerta` é o puxão de orelha da hora do combo: só o VS de hoje (zerados, abaixo da metade, previsão) e a projeção da doação, em tom incisivo, sem os dias anteriores; na liderança vai com nomes e as mensagens prontas para o privado. No domingo fala só da doação. gera `C:\lz\relatorio_geral.txt` (membros: só números, sem nomes e sem link da dash) e `C:\lz\relatorio_lideranca.txt` (liderança: no `meio`, ritmo do VS, lista de cobrança priorizada e quem não doou; no `fechamento`, resultado final, quem não bateu, destaques, projeção de doação, o tema de amanhã e, no sábado e domingo, o fechamento da semana; nos dois, o alerta de baixa performance). Ele usa `C:\lz\duelo.json` se existir. Envie o conteúdo exato desses arquivos, sem reescrever.
   **Contas secundárias da liderança** (`scripts\secundarias.json`, por id) ficam fora só das listas e mensagens de cobrança no privado; no resto contam normalmente. Para incluir ou tirar uma conta, edite esse arquivo.
   **Antes de enviar, analise.** O relatório geral traz "ANÁLISE DA DOAÇÃO" e "ANÁLISE DO VS" (nível, previsão da semana e de hoje, tendência), sempre sem nomes. Leia esses números e confira se fazem sentido com o que você leu no jogo (total de membros, quantos na meta, previsão). Se algo estiver estranho (leitura faltando, previsão absurda), corrija os dados e gere de novo antes de enviar. O tom com a doação baixa é crítico de propósito: sem doação a loja da aliança não é reabastecida.
2. Envie cada um com a ferramenta **Enviar no grupo cuja descrição fala em "relatório da dash DEDZ"** (conector do n8n `/mcp/dedz-relatorio-dash`); não use a da reflexão semanal. Só texto: passe `msg` e `destino` (se a ferramenta ainda listar campos de imagem, mande-os vazios).
3. Destinos: leia `C:\lz\destinos.txt`. Se ele tiver a linha `real`, mande o geral com `destino: "geral"` (grupo DEDZ) e o da liderança com `destino: "lideranca"` (grupo DEDZ R4, R5 e Agregados). Se o arquivo não existir ou não tiver `real`, mande **os dois com `destino: "teste"`** (grupo de teste).
4. Primeiro o geral, depois o da liderança. Se um envio falhar, siga e cite no aviso.
## 7c. Lista do PV (só quarta 19:01 e sábado 23:01)

O `relatorio.ps1` gera `C:\lz\pv.txt` só nesses dois horários (nos outros ele apaga o arquivo):
- **Quarta 19:01:** puxão de orelha do dia (mesmos textos do alerta das 19h) para zerados e abaixo de 50% no VS de hoje, mais quem está com a doação abaixo de 50%.
- **Sábado 23:01:** balanço da semana para quem bateu a meta em 3 de 6 dias ou menos, ou está com a doação abaixo de 50%: dias na meta, dias abaixo e zerados, pior dia, doação e quanto falta para os 140 mil, pontos de melhoria.

Até 10 pessoas, as piores primeiro. Ficam fora quem está entre 50% e 99% (a liderança cobra) e as contas secundárias.

1. Mande o conteúdo de `pv.txt` no grupo de **teste** (destino `teste`), começando com a linha `[LISTA DO PV - aguardando "pode enviar"]`. Se ficar longo demais para uma mensagem, divida em partes.
2. No `PushNotification` final, acrescente: "Lista do PV pronta (N pessoas): responda 'pode enviar' nesta sessão".
3. **Não envie nada no jogo nesta execução.** O envio no chat privado só acontece depois que o usuário responder "pode enviar" na sessão (ele pode tirar nomes antes). Sem essa resposta, a lista fica só no grupo de teste.
4. Quando o usuário aprovar: abra o jogo e siga a seção "Chat privado" do `CONTEXTO.md` (se ela não existir, não tente enviar: avise que o caminho precisa ser mapeado com o usuário). Mande cada mensagem exatamente como está na lista, confira cada clique e cada envio pelo print, feche o jogo e responda com quem recebeu e quem não deu certo. Nunca clique em "Ajuste de classe" nem em "Expulsar da aliança".
5. **Resumo na liderança (sempre, ao terminar os envios):**
   1. Escreva `C:\lz\pv_resultado.tsv`, uma linha por pessoa da lista, na ordem: `nome<TAB>assunto<TAB>ok|falhou<TAB>motivo`. Assunto: `doação`, `VS, X dias abaixo da meta`, `VS, X dias abaixo da meta, e doação` ou `balanço da semana`. Motivo, só quando falhou: `só aceita mensagem de amigos`, `não encontrado na lista de membros` ou `outro`.
   2. `scripts\pv_resumo.ps1 -Resultado C:\lz\pv_resultado.tsv`. Ele grava o envio em `C:\lz\estado\pv_historico.json` e gera `C:\lz\pv_resumo.txt` com: números, "Por que esses nomes" (regra de quarta ou de sábado), **🔁 REINCIDENTES** (quem já tinha sido notificado no PV nas últimas 4 semanas, com as datas), quem recebeu e quem não deu certo.
   3. Mande o conteúdo exato de `pv_resumo.txt` no grupo da liderança (`destino: "lideranca"` se `C:\lz\destinos.txt` tiver `real`; senão `teste`), só texto.
## 8. Avisar

Termine sempre com um `PushNotification` curto:
- Deu certo: "Dash atualizada (12h): VS seg 92/97, ter 54/97 · doação 48/97 na meta · relatórios enviados (teste|grupos reais) · 5 em alerta". Acrescente nomes sem membro no banco, se houver.
- Deu errado: o motivo em uma linha ("jogo pediu o PIN", "PC bloqueado", "ranking não abriu") e o que ficou feito.

**Se deu errado, avise também no grupo de teste** (sempre, mesmo com `destinos.txt` em `real`): use a ferramenta "Enviar no grupo" do relatório da dash DEDZ com `destino: "teste"` e só texto, no formato:

```text
[ROTINA DEDZ - ERRO] <11:01|19:01|23:01> de <dd/mm>
Motivo: <uma linha>
Feito: <o que chegou a ser feito: coleta, banco, dash, relatórios>
Faltou: <o que não foi feito>
```

Considera "deu errado" qualquer parada antes do fim, e também quando um relatório não foi enviado aos grupos reais, quando sobrou nome sem membro no banco (entrada ou troca de nome) ou quando o push falhou. Saídas marcadas automaticamente não são erro (nesse caso, a rotina continua e o aviso vai no final). Nunca mande esse aviso nos grupos reais.
