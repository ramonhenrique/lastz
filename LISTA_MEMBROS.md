# Rotina manual: atualizar a lista de membros

Só roda quando o Ramon pede ("atualiza a lista de membros", "coleta os membros" e afins). As coletas automáticas (11h, 19h, 23h, sábado 22:45) leem só VS e doação; esta lê, de cada membro ativo, o **poder total**, o **cargo** e o **nível da sede**, e atualiza as duas dashes.

O **poder de arena não é lido**: só um R4 vê o modo de arena da lista, e a conta da rotina (C0r1nga²) é R3. O valor de arena fica o da última leitura.

Regras de sempre: no jogo só leia. Nunca clique em "Ajuste de classe", "Expulsar da aliança", "Abandonar a aliança" (aba Gestão) nem envie mensagens. Não crie, não renomeie e não marque saída sozinho: liste os casos para o Ramon decidir.

## 1. Ler no jogo (janela 623x993)

1. `scripts\jogo.ps1 -Acao abrir`. Aliança (587,748) → **Membros** no rodapé (352,945).
2. No topo fica o R5 (nome, poder e sede abaixo do retrato). Depois vêm as faixas R4, R3, R2 e R1. Em cada membro aparecem o nome, a sede (ícone da casa) e o poder total (ex.: 248.2M).
3. A faixa abre e fecha pela seta ▼ da direita (x 508). Leia uma faixa por vez:
   - **R4:** com a lista no topo, a seta fica em y 435. Abra, tire o print e feche de novo (mesma seta).
   - **R3** (a maior, ~64): a lista abre já expandida. Print, depois `lz.ps1 -Action drag -X 300 -Y 820 -X2 300 -Y2 480`, 1 s, print, até aparecerem as faixas R2 e R1.
   - **R2** e **R1:** com a faixa na tela, clique na seta dela (R2 ~820, R1 ~873 quando estão no fim) e role até o fim, com print a cada rolagem.
4. Confira as contagens: cada faixa mostra o total (ex.: R3 64). A ordem muda quando alguém entra online, então não confie na posição. Junte pelos nomes, sem repetir, e confira se bate com o número da faixa.
5. `scripts\jogo.ps1 -Acao fechar`.
6. Escreva `C:\lz\membros_lista.tsv` (UTF-8), uma linha por membro, com o R5 incluído: `cargo<TAB>nome<TAB>sede<TAB>poder em milhões` (ex.: `R3	Assofra	33	248.2`). Copie os nomes exatamente como aparecem.

## 2. Dash de acompanhamento

1. `ArtifactData` `list` no URL https://claude.ai/artifact/3aii6XvyJi7PcP8zSShU1n, `collection` `membros`, `query` `{"limit": 1000}`, `out_dir` `C:\lz\dl`. Salve o texto do resultado (pares id/versão) em `C:\lz\membros_versoes.txt`. Logo em seguida rode `scripts\sincroniza.ps1 -Colecao membros -Pasta C:\lz\dl\membros -Esperado <quantidade>` para o espelho ficar igual ao banco.
2. `scripts\membros_lista.ps1`. Ele gera `C:\lz\mlista_batch0.json…` (poder, sede, cargo e `poderEm`, com `if_version`) e lista:
   - "nome do jogo sem membro no banco": entrada ou troca de nome;
   - "membro do banco que não está no jogo": saída ou troca de nome.
3. Mande cada lote como `writes` de um `ArtifactData` `batch` no URL da dash. Se um lote for recusado por versão, repita do 1.
4. `scripts\membros_lista.ps1 -Confirmar` (aplica no espelho).

## 3. Dash de migração

Siga o passo 5a do `ROTINA.md`: download, `sync_migracao.ps1`, lotes e lista pública. O sync agora também leva poder total e sede.

## 4. Publicar e avisar

1. `scripts\foto.ps1`, depois `Artifact` `read` e publish da dash de acompanhamento (passo 6 do `ROTINA.md`). A migração já foi publicada no passo 3.
2. Commit e push (`dash/index.html`, `dash/migracao.html`): "Lista de membros: poder, cargo e sede (<data>)".
3. Responda ao Ramon:
   - quantos foram lidos e quantos mudaram de cargo;
   - os nomes sem par dos dois lados, com sede e poder, e os pares prováveis (mesmo cargo, sede igual, poder parecido);
   - pergunte se pode renomear, cadastrar ou marcar saída.
