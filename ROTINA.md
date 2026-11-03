# Rotina automática da dash DEDZ

Este roteiro é seguido pelas tarefas agendadas das **12:00** e da noite (**~22:30**, antes do dia virar às 23:00) (horário de Brasília), sem ninguém acompanhando. Leia o `CONTEXTO.md` só se precisar de mais detalhes; tudo o que a rotina precisa está aqui.

Regras gerais:
- **Ninguém está olhando.** Não faça perguntas; quando algo impedir a coleta, pare e avise (passo 8).
- **Nunca digite senha nem PIN.** Se o jogo pedir login ou PIN, feche o jogo, pare e avise.
- **O jogo só fica aberto durante a leitura:** abra no passo 2 e feche no passo 4b.
- **No jogo, só leia rankings.** Não clique em nada que gaste recursos, aceite convites, envie mensagens ou mexa em membros (o botão "Expulsar da aliança" fica perto do chat privado).
- Antes de cada clique, confira pelo print onde está. Volte para a cidade com o botão de voltar ou `ESC` (`scripts\lz.ps1 -Action key`) quando aparecer algo inesperado.
- Pasta de trabalho: `C:\lz`. Scripts: `scripts\` deste repositório. Git: `%LOCALAPPDATA%\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`.
- Dash: https://claude.ai/artifact/3aii6XvyJi7PcP8zSShU1n (o banco é o `ArtifactData` desse URL).

## 1. Ver o que coletar

Rode `scripts\hoje.ps1`. Ele devolve `semana`, `dia` (0 = segunda … 6 = domingo), `temVS` e `diaAnterior`.

| Execução | VS | Doação |
|---|---|---|
| 12:00 | VS final de `diaAnterior` (se não for -1) **e** VS parcial do `dia` (se `temVS`) | sim |
| noite (~22:30) | VS do `dia` (se `temVS`), quase fechado | sim |

No domingo não há VS do dia. Na segunda às 12:00 não há dia anterior (a semana é nova).

## 2. Deixar o jogo pronto

1. `scripts\jogo.ps1 -Acao abrir`. O jogo entra sozinho, sem PIN (o PIN foi tirado em 03/11), e chega na cidade em uns 30 segundos.
2. Tire um print (`scripts\lz.ps1 -Action shot -Out C:\lz\s.png`) e olhe:
   - Ainda carregando → espere 15 segundos e tire outro.
   - Tela de **Código PIN** ou login → pare (passo 8, sem esquecer de fechar o jogo) e avise "o jogo pediu o PIN".
   - Vídeo de entrada → botão **Pular** (canto superior direito).
   - Janelas abertas (cartão de perfil, ofertas, eventos) → feche no X ou com `ESC` até ver a cidade.
3. O `lz.ps1` imprime o tamanho da janela (a posição na tela pode mudar; as coordenadas são relativas à janela). As coordenadas abaixo são para **623x1046**. Se o tamanho for outro, ache os botões pelo print.
4. Se o `lz.ps1` falhar com "Janela do jogo nao ficou em primeiro plano", ou o print sair preto, o PC deve estar bloqueado → pare e avise.

## 3. Coletar o VS

Na cidade: botão **VS** (583,228; à direita, abaixo de "Atividades Populares") → **Ranking** (510,70) → **Ranking Diário** (já vem selecionado) → marque **Minha Aliança** (236,824) e confira pelo print que o visto apareceu. As abas dos dias ficam em y=280: Seg 133 · Ter 205 · Qua 275 · Qui 347 · Sex 417 · Sáb 488.

Para cada dia a coletar:
1. Clique na aba do dia e confira pelo print que ela ficou selecionada e que "Minha Aliança" continua marcado.
2. Role a lista para o topo: `scripts\lz.ps1 -Action drag -X 300 -Y 400 -X2 300 -Y2 900` (duas vezes).
3. `scripts\scan.ps1 -Tag vs<dia> -Drags 37 -FromY 660 -ToY 400 -CX 103 -CY 308 -CW 420 -CH 392 -PerGrid 4`
4. Leia as grades `C:\lz\G_vs<dia>_N.png` e escreva `C:\lz\vs<dia>.tsv` (UTF-8, uma linha por membro: `posição<TAB>nome<TAB>valor`, sem separador de milhar). Os 97 membros precisam aparecer; a última grade deve terminar na última posição. Se faltar gente no fim, role mais e tire outro print.
   - Copie os nomes exatamente como aparecem (com ², ³, ¹, •, ツ, 亥, €, Ø). O `atualiza.ps1` ignora espaços e acentos.
   - Dica: `C:\lz\estado\registros.json` tem os valores já gravados. Na leitura do mesmo dia, a maioria não muda; compare para pegar erros de leitura.

Feche o ranking no X (505,160) e volte para a cidade (botão de voltar, 111,995).

## 4. Coletar a doação semanal

Na cidade: **Aliança** (585,790) → **Ranking** (198,837) → aba **Contribuição** (471,96) → **Semanal** (425,153). Use sempre o Semanal.

1. Role para o topo (drag de 400 para 900, duas vezes).
2. `scripts\scan.ps1 -Tag doa -Drags 26 -CX 88`
3. Leia `C:\lz\G_doa_N.png` e escreva `C:\lz\doacao_semanal.tsv` no mesmo formato. Os 97 precisam aparecer.

Volte para a cidade (111,995, duas vezes).

## 4b. Fechar o jogo

Assim que os TSVs estiverem escritos e conferidos (todos os 97 em cada um), feche o jogo: `scripts\jogo.ps1 -Acao fechar`. Feche também quando a rotina parar por erro em qualquer passo depois de abrir o jogo.

## 5. Gravar no banco

Para cada leitura, **uma de cada vez** (o espelho precisa ser confirmado antes da próxima):

1. VS final do dia anterior (só às 12:00):
   `scripts\atualiza.ps1 -Sem <semana> -Dia <diaAnterior> -VsTsv vs<diaAnterior>.tsv -DoaTsv ''`
2. VS do dia e doação:
   `scripts\atualiza.ps1 -Sem <semana> -Dia <dia> -VsTsv vs<dia>.tsv -DiaDoa <dia>`
   No domingo (sem VS): `scripts\atualiza.ps1 -Sem <semana> -DiaDoa 6`

Depois de cada `atualiza.ps1`:
- Ele avisa "nome do jogo sem membro no banco" quando alguém entrou, saiu ou trocou de nome. **Não renomeie nem crie membros sozinho**: siga com os outros e liste esses nomes no aviso final.
- Mande cada `C:\lz\batchN.json` como `writes` de um `ArtifactData` `batch` no URL da dash.
- Para os lotes aceitos: `scripts\confirma.ps1 -Lotes 0` (ou `0,1`…).
- **Lote recusado por versão** (alguém lançou dados pela dash): nada foi gravado. Baixe os registros da semana com `ArtifactData` `query` (`where semana == <semana>`, `limit` 1000, `out_dir` `C:\lz\dl`), salve o texto do resultado em `C:\lz\versoes.txt`, rode `scripts\sincroniza.ps1 -Colecao registros -Pasta C:\lz\dl\registros -Esperado <quantidade> -Versoes C:\lz\versoes.txt` e repita o `atualiza.ps1`.

## 6. Atualizar a dash

1. `scripts\foto.ps1` (regera a foto em `dash\index.html` a partir do espelho).
2. Leia a dash com `Artifact` `action: "read"` no URL (obrigatório antes de publicar numa sessão nova) e publique `dash\index.html` com `url` igual ao da dash. Não passe `capabilities`.
3. Commit: `git add dash/index.html` e `git commit -m "Rotina <12h|22h50>: VS de <dia> e doação (<data>)"`.
4. Push: tente `git push origin main` no shell. Se falhar pedindo usuário, rode o mesmo comando com `run_in_terminal` (o login está guardado no Git Credential Manager). Se ainda falhar, deixe o commit local e cite no aviso.

## 7. Resumo

`scripts\resumo.ps1 -Sem <semana>` dá os números da semana.

## 7b. Relatórios no WhatsApp

Só se a coleta deu certo (dados gravados e dash publicada).

1. `scripts\relatorio.ps1 -Turno <12h|noite>` gera `C:\lz\relatorio_geral.txt` (membros: só números, sem nomes e sem link da dash) e `C:\lz\relatorio_lideranca.txt` (liderança: nomes abaixo das metas, abaixo de 50% do VS do dia, doação abaixo de 50% e alerta de baixa performance da semana). Envie o conteúdo exato desses arquivos, sem reescrever.
2. Envie cada um com a ferramenta **Enviar no grupo cuja descrição fala em "relatório da dash DEDZ"** (conector do n8n `/mcp/dedz-relatorio-dash`); não use a da reflexão semanal. Só texto: passe `msg` e `destino` (se a ferramenta ainda listar campos de imagem, mande-os vazios).
3. Destinos: leia `C:\lz\destinos.txt`. Se ele tiver a linha `real`, mande o geral com `destino: "geral"` (grupo DEDZ) e o da liderança com `destino: "lideranca"` (grupo DEDZ R4, R5 e Agregados). Se o arquivo não existir ou não tiver `real`, mande **os dois com `destino: "teste"`** (grupo de teste).
4. Primeiro o geral, depois o da liderança. Se um envio falhar, siga e cite no aviso.
## 8. Avisar

Termine sempre com um `PushNotification` curto:
- Deu certo: "Dash atualizada (12h): VS seg 92/97, ter 54/97 · doação 48/97 na meta · relatórios enviados (teste|grupos reais) · 5 em alerta". Acrescente nomes sem membro no banco, se houver.
- Deu errado: o motivo em uma linha ("jogo pediu o PIN", "PC bloqueado", "ranking não abriu") e o que ficou feito.
