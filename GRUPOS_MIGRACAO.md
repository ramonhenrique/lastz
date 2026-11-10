# Rotina manual: auditar os grupos de migração

Só roda quando o Ramon pede ("ver os grupos de migração", "auditar os grupos" e afins). Lê no jogo quem está nos grupos **REGULAR 609** e **intermediary609**, compara com a leitura anterior, **muda a situação** na dash de migração (https://claude.ai/artifact/TdiYGf4RT4jYT7LrAYC6cW) e manda o resultado no **grupo de teste** do WhatsApp.

Regras de sempre: no jogo só leia. Nunca envie mensagem no jogo (nunca na aba Mundo). Nunca clique em "Ajuste de classe", "Expulsar", "Abandonar" nem no "−" do grupo. Tire um print antes de cada clique em tela nova.

O que muda na dash (o `scripts\grupos_migracao.ps1` decide):
- entrou num grupo, ou está num grupo sem estar "vai": passa para **vai**;
- saiu dos dois grupos e estava "vai": passa para **não vai**;
- trocou de um grupo para o outro: só entra no relatório;
- organizadores (Vini²², C0r1nga², Marcelo QAF, Mané 07) nunca mudam;
- a obs ganha uma nota ("entrou no REGULAR 609 em 10/11", "saiu do intermediary609 em 10/11").

## 1. Ler os grupos no jogo (janela 623x993)

1. `scripts\jogo.ps1 -Acao abrir` e um print (`scripts\lz.ps1 -Action shot`, depois leia `C:\lz\shot.png`).
2. Chat → Chat privado → Bate-papo em grupo. Toque no grupo **REGULAR 609** (a posição na lista muda; ache pelo print), na engrenagem (497,145) e em **"Ver mais membros"** (440,643).
3. Print do topo e, até o fim da lista: `lz.ps1 -Action drag -X 300 -Y 820 -X2 300 -Y2 260`, 1,2 s, print. A lista mostra `[TAG]Nome`. Anote todos, sem repetir.
4. Volte (121,945) três vezes até a lista de grupos e faça o mesmo no **intermediary609**.
5. `scripts\jogo.ps1 -Acao fechar` (também se parar por erro).
6. Grave `C:\lz\grp\novo\regular.txt` e `C:\lz\grp\novo\inter.txt` (UTF-8), uma linha por membro: `ALIANCA|nome`, com o nome exatamente como aparece (ex.: `DEDZ|Vini²²`, `KIN|Hercules°`). Confira a contagem com o total que o grupo mostra.

## 2. Comparar e mudar a situação

1. `ArtifactData` `list` no URL da migração, `collection` `membros`, `query` `{"limit": 1000}`, `out_dir` numa pasta **nova** (`C:\lz\migN`, N seguinte ao último). Grave os pares id/versão do resultado em `C:\lz\mig_versoes.txt` (formato `"id" N, "id" N, …`).
2. `scripts\grupos_migracao.ps1 -Pasta C:\lz\migN\membros`. Ele mostra o resumo, grava `C:\lz\grp\mensagem.txt` e, se houver mudança, `C:\lz\grp_batch0.json…`.
3. **Contas de fora sem cadastro** ("No grupo sem cadastro na dash", tag diferente de DEDZ): leia o cartão e o PC (LISTA_MEMBROS.md 3a e 3b, `scripts\detalhe_pc.ps1`) e crie o documento `g_<nome sem símbolos>` com status "vai", origem "grupo" e obs "grupo <nome do grupo>". Isso exige reabrir o jogo; se não der, deixe no relatório. Nome DEDZ sem cadastro: só relatório (o `sync_migracao.ps1` cuida).
4. Mande cada `grp_batchN.json` como `writes` de um `ArtifactData` `batch` no URL da migração. Se for recusado por versão, repita do 2.1.
5. `scripts\grupos_migracao.ps1 -Confirmar`: a leitura nova vira a base (a anterior vai para `C:\lz\grp\historico`). Rode também quando não houver mudança.
6. Se mudou alguma coisa: baixe de novo (pasta nova), `scripts\mig_snapshot.ps1 -Fonte dash\migracao_fonte.html -Pasta C:\lz\migN\membros -Out dash\migracao.html` e publique com `Artifact` publish (url da migração, `files` `{"fonte.html": "dash/migracao_fonte.html"}`). Commit e push de `dash/migracao.html`: "Grupos de migração: situação atualizada (<data>)".

## 3. Avisar

Envie o texto de `C:\lz\grp\mensagem.txt` (mais a linha "Cadastradas na dash: …" se o 2.3 criou contas) no WhatsApp, destino **teste**, sem pedir aprovação. Sem mudança, o texto já diz que a rotina terminou sem alteração nos membros. Nunca mande essa mensagem nos grupos geral ou liderança.
