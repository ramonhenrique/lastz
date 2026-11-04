# Contexto do projeto lastz (DEDZ)

Para abrir outra instância do Claude Code em outro PC: clone este repositório, abra a pasta e peça para ler este arquivo primeiro. O conteúdo aqui junta a memória salva e tudo o que foi feito até 03/11/2026.

## Quem e o quê

- Jogo: **Last Z: Survival Shooter**, aliança **New Deadz [DEDZ]**, zona de guerra #614. Ramon joga com o personagem **C0r1nga** (R4).
- A liderança acompanha duas metas por membro:
  - **Doação:** 20 mil por dia (140 mil por semana).
  - **VS (Duelo de Aliança):** Seg 4,5Mi (Radar + Veículo) · Ter 5Mi (Construção) · Qua 3,3Mi (Pesquisa) · Qui 6Mi (Heróis) · Sex 7Mi (Exército) · Sáb 6Mi (Combate). Domingo não tem VS. Soma da semana: 31,8Mi.
- O dia do jogo vira às 23:00 de Brasília (o servidor fica em UTC-2).
- A aliança está se preparando para a **S4** e para uma migração de servidor.

## Artefatos (claude.ai)

| Artefato | Link | Para quê |
|---|---|---|
| Acompanhamento DEDZ | https://claude.ai/artifact/3aii6XvyJi7PcP8zSShU1n | Dash de doação, VS, resumo e análises |
| Mensagens automáticas DEDZ | https://claude.ai/artifact/ADzmCYKYAj8oeZtMAx4ddE | Documento com os textos do bot do n8n (check-in, doação, VS, Preparação Total) |
| Migração DEDZ | https://claude.ai/artifact/TdiYGf4RT4jYT7LrAYC6cW | Levantamento da migração (28/10) |
| Poder da Aliança DEDZ | https://claude.ai/artifact/5hXx1yzDRS1naUMoChPcY9 | Poder dos membros |

**A dash é administrativa.** Os membros não têm acesso a ela. Em textos para os membros, nunca ofereça o link nem diga que eles podem consultá-la. O compartilhamento ainda está como "qualquer pessoa com o link"; Ramon pode restringir pelo menu Compartilhar da página.

### Como a dash guarda os dados

- O código fica em `dash/index.html` neste repositório. A versão publicada é igual a ele (v18 em 03/11 14:01).
- Os dados ficam no **banco da página** (ferramenta `ArtifactData`, com o URL da dash):
  - `membros`: id → `{nome, cargo, poder, poderArena, poderEm, saiu?}`. Os ids são `m001`…`m095` e `n<nome>` para quem entrou depois.
  - `registros`: id `<segunda AAAA-MM-DD>__<idMembro>` → `{semana, membro, doacao, doacaoDias[7], vs[6], at}`. `doacao` é o acumulado semanal; `doacaoDias[i]` é o acumulado lido no dia i (seg = 0); `vs[0..5]` é seg..sáb.
  - `leituras`: id = data → `{data, poder: {idMembro: [poderTotal, poderArena]}}`.
- Toda escrita precisa de `if_version` (a versão que o `list`/`query` mostrou). Escreva em lote (`batch`, até 50 por vez).
- A dash também tem uma **foto embutida**: o bloco `<script type="application/json" id="foto">` no `index.html`, que é o que aparece para quem abre sem login. Ela precisa ser regerada a partir do banco depois de cada coleta (script `foto.js`, abaixo).
- Para casar nomes do jogo com membros: NFKD, sem acentos, minúsculas e sem espaços ("Vini ²²" = "Vini²²").

## Regra combinada: toda coleta atualiza tudo

Depois de **toda** leitura no jogo, sem esperar pedido:
1. Ler `registros` da semana (com versão) e gravar só o que mudou, em lote.
2. Baixar `membros`, `registros` e `leituras` e regerar a foto em `dash/index.html`.
3. Publicar no mesmo URL da dash e fazer commit. **O push é manual (do Ramon)**: nesta máquina o SSH e o HTTPS falharam por falta de credencial.

## Coleta no jogo

O jogo roda como **app de PC**: processo `Survival`, janela "LastZ", área útil de **702x1120** (num monitor secundário). O BlueStacks está instalado mas não é usado. A coleta é feita tirando print da janela e clicando por PowerShell (script `lz.ps1`). As coordenadas abaixo são relativas à área útil.

### Doação semanal
Cidade → **Aliança** (canto inf. direito, 662,840) → **Ranking** (228,896) → aba **Contribuição** (522,102) → **Semanal** (470,164). Sempre use o semanal. Arrastar de 850 para 380 rola 5 linhas sem pular ninguém; uns 21 arrastos cobrem os 97.

### VS diário
Cidade → botão **VS** (direita, abaixo de Atividades Populares, 660,245) → **Ranking** (ícone no topo, 565,75) → **Ranking Diário** → marcar **"Minha Aliança"** (270,882; às vezes ele desmarca sozinho, confira) → clicar o dia (Seg 160,300 · Ter 237,300 · Qua ~313 · Qui ~388 · Sex ~463 · Sáb ~540). Fechar: X em 560,172.

O dia em andamento é **parcial** até as 23:00 de Brasília.

### Chat privado com um membro
Aliança → aba **Membros** (395,1080) → abrir o grupo do cargo (R3 864 · R2 924 · R1 984, quando a lista está no topo) → tocar no membro → **Chat privado**.
- **Cuidado:** o botão **"Expulsar da aliança"** fica no mesmo menu, logo abaixo.
- Dentro de cada cargo, a ordem é por último login: quem está sumido fica no fim.
- Para escrever: clicar na caixa (330,1065), colar com Ctrl+V e clicar no botão verde (565,1062).
- O jogo **descarta a maioria dos emojis** (só o ⚠️ aparece). Escreva sem emoji.
- A busca da lista de chats só acha conversas que já existem.
- Conversa nova às vezes não mostra o nome no topo: depois de enviar, confira na lista de chats.

## Mensagens individuais (formato combinado)

Curtas, sem o cabeçalho "⚔️ DEDZ ⚔️", sem emoji:

```text
Fala, {nome}! Como está sua semana até agora:

VS segunda: {seg} de 4,5Mi{ (meta batida!)}
VS terça: {ter} de 5Mi (o dia ainda não acabou)
Doação: {doacao} de {meta_ate_hoje} (meta de 20k por dia)

Ainda dá tempo de pontuar na terça! Qualquer dificuldade, me avisa.
```

Antes de enviar, releia o ranking do VS do dia para a mensagem sair com o número atual.

**Enviadas em 03/11:** LARI •, P4ND0R4, SMRSAM (formato antigo/curto) e Natalicio, Srichterr, GuigoVkG, THE BRUXO, 99GXB99, Dudamoss, Boiadeiro3r. THE BRUXO respondeu e o Ramon seguiu a conversa por conta própria.

Pontos de atenção:
- **99GXB99** aparece com a tag [PIBL] no chat e recebeu convite de outra aliança. Pode estar de saída.
- **SMRSAM** usa bandeira da Alemanha; talvez não leia português.
- **Napoleon bel** foi o 1º no VS de segunda (41,3Mi) mas doa pouco (6,5k). Se for cobrar doação, elogie o VS.

## Situação em 03/11 14:01 (semana de 02/11)

- VS segunda: **92 de 97** bateram 4,5Mi. Abaixo: LARI • (0), 99GXB99 (3,1Mi), Vini¹²³ (3,5Mi), P4ND0R4 (3,6Mi), SMRSAM (4,47Mi).
- VS terça (parcial): **53 de 97** acima de 5Mi. Em zero: SMRSAM, Srichterr, P4ND0R4.
- Doação: **37 de 97** com 40k ou mais (meta até terça). Total doado pela aliança: 3,52M.
- Quem saiu da aliança em 02/11: Gil 13, Døn Dante, Belladønna, Mateus cruz, dynami6ht.

## Mensagem do grupo do WhatsApp

Foi montada uma mensagem para o grupo sobre o acompanhamento (rumo à S4, métricas acompanhadas, números da semana sem citar nomes, aviso das mensagens no privado). O print vai junto; se não quiser expor nomes, use os cartões do topo ou um gráfico da aba Análises, não as tabelas.

## Pendências e ideias

- Coletar o VS final de terça depois das 23:00 e atualizar banco + dash. (Última coleta: 03/11 ~17:15, dash v19: VS ter 54 de 97 acima de 5Mi, doação 48 de 97 com 40k+, total 3,85M.)
- **Participação no SVS** foi prometida na mensagem do grupo, mas a dash ainda não acompanha. Falta descobrir onde o jogo mostra isso.
- A evolução de poder depende de novas leituras da lista de membros (só existe a de 02/11). O poder de arena aparece trocando a lista para "Combate Pessoal".
- Commits locais ainda sem push: `125536f`, `082f917`, `f179401` (e este arquivo, se for commitado).

---

## Scripts em PowerShell (pasta `scripts/`)

Desde 03/11 os scripts ficam no repositório, em PowerShell, e não precisam de Node. Os dados de trabalho ficam em `C:\lz` (parâmetro `-Dir`), fora do repositório.

**Espelho local do banco.** `C:\lz\estado` guarda uma cópia do banco da dash (`membros.json`, `registros.json`, `leituras.json` e `versoes.json`, com a versão de cada registro). As escritas e a foto saem desse espelho, então uma coleta normal **não baixa nada do banco**. Isso vale enquanto só a coleta escreve no banco. Se alguém lançar dados pela aba "Lançar dados" da dash, o próximo lote é recusado por versão (nada é gravado) e aí basta sincronizar.

| Script | Para quê |
|---|---|
| `lz.ps1` | Print, clique, arrasto e tecla na janela do jogo. Traz a janela para frente e para se não conseguir (o Chrome costuma ficar por cima). |
| `scan.ps1` | Rola a lista aberta e junta os prints em grades `G_<tag>_N.png` |
| `atualiza.ps1` | Compara os TSVs com o espelho e monta `batch0.json`, `batch1.json`… já com `if_version` |
| `confirma.ps1` | Depois que o banco aceitou os lotes, aplica as escritas no espelho (`-Lotes 0,1`) |
| `foto.ps1` | Regera a foto embutida em `dash/index.html` a partir do espelho |
| `resumo.ps1` | Números da semana para as mensagens do grupo |
| `sincroniza.ps1` | Recarrega o espelho a partir de um download do `ArtifactData` |
| `comum.ps1` | Funções usadas pelos outros |

Fluxo de uma coleta:
1. Abrir a lista no jogo e rodar `scan.ps1`. Na janela de 607x1046: doação com `-Tag doa -Drags 24`; VS com `-Tag vster -Drags 34 -FromY 660 -ToY 400 -CX 95 -CY 308 -CW 420 -CH 392 -PerGrid 4`, e mais alguns arrastos para pegar o fim da lista.
2. Ler as grades e escrever `doacao_semanal.tsv` e `vs_<dia>.tsv` em `C:\lz`.
3. Rodar `atualiza.ps1 -Sem <segunda> -Dia <0-5> -VsTsv vs_<dia>.tsv -DiaDoa <0-6>`. Se ele avisar "nome do jogo sem membro no banco", provavelmente alguém trocou de nome: compare o VS do dia com o espelho, corrija o `nome` em `membros` no banco, sincronize `membros` e rode de novo.
4. Mandar cada `batchN.json` num `ArtifactData` `batch` e, para os que foram aceitos, rodar `confirma.ps1 -Lotes 0,1`.
5. Rodar `foto.ps1`, publicar `dash/index.html` no URL da dash e fazer commit.

Para sincronizar (lote recusado, primeira vez numa máquina, ou dados lançados por outra pessoa): baixe cada coleção com `ArtifactData` num `out_dir` próprio (`C:\lz\dl`) e rode `sincroniza.ps1` **logo depois de cada download**, porque o download seguinte apaga os arquivos do anterior. Para `registros`, salve o texto do resultado do download em `C:\lz\versoes.txt`: os arquivos não trazem a versão, e o script a tira desse texto.
Coordenadas na janela de 607x1046 (PC NOVO-0000): Aliança 570,785 · Ranking 190,837 · Contribuição 463,96 · Semanal 417,153 · voltar 103,995 · VS 568,228 · Ranking do VS 502,70 · Minha Aliança 228,824 · fechar ranking 497,160. Nesse PC o git é o do GitHub Desktop (`%LOCALAPPDATA%\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe`).

Renomeados em 03/11: Demon Tazz → Corrida Maluca, Gargamel ツ → Muttley ツ, Maikynhoo → Peter Perfect.

---

## Scripts antigos em JS (referência; precisam de Node)

Todos usam a mesma pasta. Em outra máquina, confira se a janela do jogo tem a mesma área útil (o `lz.ps1 -Action shot` imprime o tamanho); se mudar, as coordenadas mudam junto.

### lz.ps1: print, clique, arrasto e tecla na janela do jogo

```powershell
param(
  [Parameter(Mandatory)][ValidateSet('shot','click','drag','key')][string]$Action,
  [int]$X, [int]$Y, [int]$X2, [int]$Y2,
  [string]$Out = "$PSScriptRoot\shot.png",
  [string]$Key = 'ESC'
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process Survival -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $p.MainWindowHandle
if ([W]::IsIconic($h)) { [W]::ShowWindow($h, 9) | Out-Null }
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 300
$r = New-Object W+RECT; [W]::GetClientRect($h, [ref]$r) | Out-Null
$o = New-Object W+POINT; [W]::ClientToScreen($h, [ref]$o) | Out-Null
$w = $r.R - $r.L; $hh = $r.B - $r.T

function Down-Up($sx, $sy) {
  [W]::SetCursorPos($sx, $sy) | Out-Null; Start-Sleep -Milliseconds 60
  [W]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 80
  [W]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
}

switch ($Action) {
  'shot' {
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($o.X, $o.Y, 0, 0, $bmp.Size)
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    "client ${w}x${hh} at $($o.X),$($o.Y) -> $Out"
  }
  'click' { Down-Up ($o.X + $X) ($o.Y + $Y); "clicked $X,$Y" }
  'drag' {
    [W]::SetCursorPos($o.X + $X, $o.Y + $Y) | Out-Null; Start-Sleep -Milliseconds 60
    [W]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
    for ($i = 1; $i -le 20; $i++) {
      [W]::SetCursorPos([int]($o.X + $X + ($X2 - $X) * $i / 20), [int]($o.Y + $Y + ($Y2 - $Y) * $i / 20)) | Out-Null
      Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 200
    [W]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); "dragged $X,$Y -> $X2,$Y2"
  }
  'key' { $vk = @{ ESC = 0x1B }[$Key]; [W]::keybd_event($vk, 0, 0, [IntPtr]::Zero); [W]::keybd_event($vk, 0, 2, [IntPtr]::Zero); "key $Key" }
}
```

### vs_scan.ps1: rola o ranking do VS (já aberto no dia) e junta os prints em grades

```powershell
param([string]$Tag, [int]$Drags = 30)
$s = $PSScriptRoot
Add-Type -AssemblyName System.Drawing
& "$s\lz.ps1" -Action shot -Out ("$s\{0}_00.png" -f $Tag) | Out-Null
for ($i = 1; $i -le $Drags; $i++) {
  & "$s\lz.ps1" -Action drag -X 350 -Y 700 -X2 350 -Y2 380 | Out-Null
  Start-Sleep 1.2
  & "$s\lz.ps1" -Action shot -Out ("$s\{0}_{1:D2}.png" -f $Tag, $i) | Out-Null
}
$files = Get-ChildItem "$s\${Tag}_*.png" | Sort-Object Name
$cw = 450; $ch = 420
$crop = New-Object System.Drawing.Rectangle 125, 330, $cw, $ch
$n = 0
for ($k = 0; $k -lt $files.Count; $k += 4) {
  $grp = $files[$k..([Math]::Min($k + 3, $files.Count - 1))]
  $out = New-Object System.Drawing.Bitmap ($cw * $grp.Count), $ch
  $g = [System.Drawing.Graphics]::FromImage($out)
  $j = 0
  foreach ($f in $grp) {
    $b = [System.Drawing.Bitmap]::FromFile($f.FullName)
    $g.DrawImage($b, (New-Object System.Drawing.Rectangle ($j * $cw), 0, $cw, $ch), $crop, 'Pixel')
    $b.Dispose(); $j++
  }
  $out.Save(("$s\G_{0}_{1}.png" -f $Tag, $n), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $out.Dispose(); $n++
}
"$Tag -> $n grids"
```

Para a doação semanal, o mesmo esquema com arrasto de 850 para 380 (21 vezes), recorte `110,240,490,665` e 3 prints por grade.

### Chat privado (mapeado em 04/11/2026, janela 623x1046)

Usado só pelo passo 7c do `ROTINA.md`, depois do "pode enviar" do usuário. Testado com uma mensagem para C0r1nga³ (conta do próprio usuário).

1. Na cidade: **Aliança** (585,790); se o menu não abrir, o jogo ainda estava carregando, clique de novo.
2. Aba **Membros** no rodapé (352,1000). No topo ficam o R5 e os cargos especiais; abaixo, uma grade de 2 colunas com foto, nome, nível e poder.
3. **A ordem da grade muda** (quem está online sobe), então ache o nome pelo print a cada vez. Role com `lz.ps1 -Action drag` dentro da grade se o nome não estiver visível.
4. Toque na **foto** do membro: aparece um balão com só dois botões, **Detalhes** e **Chat privado** (logo abaixo da foto). Não há "Expulsar" nesse balão; mesmo assim confira pelo print antes de cada clique.
5. **Chat privado** abre a conversa: o topo mostra `(DEDZ)<nome>`. Confira que é a pessoa certa.
6. Clique no campo "Clique para inserir texto" (280,995), cole com `lz.ps1 -Action text -Text '<mensagem>'` (aceita acentos, ², ³, •, quebras de linha) e confira pelo print. Para desfazer: `lz.ps1 -Action limpar`.
7. Com texto no campo o botão verde vira **enviar** (510,1000; sem texto ele mostra um "+"). Clique e tire um print.
8. **Enviou:** aparece um balão verde à direita, com o horário acima e o nome da nossa conta, e o campo volta a "Clique para inserir texto". **Não enviou** (o membro só aceita mensagem de amigos, ou outro bloqueio): o balão não aparece. Registre como "não recebeu" e siga para o próximo.
9. Volte (111,995) até a grade de membros para o próximo nome. Se o chat fechar sozinho (acontece se ficar parado), refaça a partir do passo 2.

Uma faixa "Esta é uma sessão não comercial." (do programa de acesso remoto) cobre parte do canto inferior direito da janela; o botão enviar continua clicável logo abaixo dela.

### membros.ps1: da cidade, abre Aliança → Membros → grupo do cargo

(Desatualizado: coordenadas de uma janela antiga e o script não está no repositório. Use a seção "Chat privado" acima.)

```powershell
param([ValidateSet('R3','R2','R1')][string]$Grupo, [int]$Rolar = 0, [string]$Out)
$s = $PSScriptRoot
$y = @{ R3 = 864; R2 = 924; R1 = 984 }[$Grupo]
& "$s\lz.ps1" -Action click -X 662 -Y 840 | Out-Null; Start-Sleep 2
& "$s\lz.ps1" -Action click -X 395 -Y 1080 | Out-Null; Start-Sleep 2
& "$s\lz.ps1" -Action click -X 350 -Y $y | Out-Null; Start-Sleep 2
for ($i = 0; $i -lt $Rolar; $i++) { & "$s\lz.ps1" -Action drag -X 350 -Y 950 -X2 350 -Y2 520 | Out-Null; Start-Sleep 1 }
& "$s\lz.ps1" -Action shot -Out $Out
```

### enviar.ps1: cola o texto de um arquivo no chat aberto e envia

(Desatualizado: coordenadas de uma janela antiga e o script não está no repositório. Hoje o envio usa `lz.ps1 -Action text` e o clique em 510,1000; veja "Chat privado".)

```powershell
param([Parameter(Mandatory)][string]$Arquivo, [string]$Out)
$s = $PSScriptRoot
Get-Content $Arquivo -Raw -Encoding utf8 | Set-Clipboard
& "$s\lz.ps1" -Action click -X 330 -Y 1065 | Out-Null
Start-Sleep 1.2
Add-Type -Name K -Namespace U -MemberDefinition '[DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, System.IntPtr e);'
[U.K]::keybd_event(0x11, 0, 0, [IntPtr]::Zero); [U.K]::keybd_event(0x56, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 80
[U.K]::keybd_event(0x56, 0, 2, [IntPtr]::Zero); [U.K]::keybd_event(0x11, 0, 2, [IntPtr]::Zero)
Start-Sleep 1.5
& "$s\lz.ps1" -Action click -X 565 -Y 1062 | Out-Null
Start-Sleep 2.5
& "$s\lz.ps1" -Action shot -Out $Out
```

Sempre confira por print que o chat certo está aberto antes de chamar este script.

### Arquivos de leitura

Os valores lidos nos prints vão para arquivos TSV com `posição<TAB>nome<TAB>valor`, um por ranking: `doacao_semanal.tsv`, `vs_seg.tsv`, `vs_ter.tsv`… (UTF-8 sem BOM).

### atualiza.js: compara a leitura com o banco e monta as escritas

Antes, baixe o banco com `ArtifactData` (`list` de `membros` e `registros`, com `out_dir` = `<pasta>\db2`) e salve as versões que o `list` mostrou em `versoes.json` (`{"2026-11-02__m001": 5, ...}`).

```js
// node atualiza.js <semana AAAA-MM-DD> <dia do VS 0-5> <arquivo vs.tsv>
const fs = require("fs"), path = require("path");
const S = __dirname, DB = path.join(S, "db2");
const [SEM, DIA_TXT, VS_TSV] = process.argv.slice(2), DIA = Number(DIA_TXT);
const norm = (s) => s.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, "");
const rd = (f) => JSON.parse(fs.readFileSync(f, "utf8").replace(/^\uFEFF/, ""));
const tsv = (n) => { const m = new Map(); for (const l of fs.readFileSync(path.join(S, n), "utf8").split(/\r?\n/)) { const p = l.split("\t"); if (p.length === 3) m.set(norm(p[1]), Number(p[2])); } return m; };
const versoes = rd(path.join(S, "versoes.json"));
const ids = new Map();
for (const f of fs.readdirSync(path.join(DB, "membros"))) { const d = rd(path.join(DB, "membros", f)); if (!d.saiu) ids.set(norm(d.nome), f.slice(0, -5)); }
const doa = tsv("doacao_semanal.tsv"), vsDia = tsv(VS_TSV);
// doação: dia da semana da leitura (seg = 0)
const diaDoa = (new Date().getDay() + 6) % 7;
const now = new Date().toISOString().replace(/\.\d+Z$/, "Z");
const dir = path.join(S, "up"); fs.mkdirSync(dir, { recursive: true });
const writes = [], log = [];
for (const [n, id] of ids) {
  const key = `${SEM}__${id}`, fr = path.join(DB, "registros", key + ".json");
  const r = fs.existsSync(fr) ? rd(fr) : { semana: SEM, membro: id, doacao: null, doacaoDias: Array(7).fill(null), vs: Array(6).fill(null) };
  const patch = {};
  if (doa.has(n) && r.doacao !== doa.get(n)) { const dd = (r.doacaoDias || Array(7).fill(null)).slice(); dd[diaDoa] = doa.get(n); patch.doacao = doa.get(n); patch.doacaoDias = dd; log.push(`${n} doação ${r.doacao} -> ${doa.get(n)}`); }
  if (vsDia.has(n) && r.vs[DIA] !== vsDia.get(n)) { const vs = r.vs.slice(); vs[DIA] = vsDia.get(n); patch.vs = vs; log.push(`${n} VS[${DIA}] ${r.vs[DIA]} -> ${vsDia.get(n)}`); }
  if (!Object.keys(patch).length) continue;
  patch.at = now;
  const novo = !fs.existsSync(fr);
  const fp = path.join(dir, key + ".json"); fs.writeFileSync(fp, JSON.stringify(novo ? { ...r, ...patch } : patch));
  const w = { op: novo ? "set" : "update", collection: "registros", doc_id: key, file_path: fp };
  if (!novo) w.if_version = versoes[key];
  writes.push(w);
}
for (let i = 0; i < writes.length; i += 50) fs.writeFileSync(path.join(S, `batch${i / 50}.json`), JSON.stringify(writes.slice(i, i + 50)));
console.log(writes.length, "escritas\n" + log.join("\n"));
```

Depois, passe o conteúdo de cada `batchN.json` como `writes` de um `ArtifactData` `batch`. Se algum nome não casar, ele simplesmente não entra: confira se o `log` cobriu quem você esperava.

### foto.js: regera a foto embutida da dash a partir do banco baixado

Baixe também `leituras` para `db2`. Ajuste `HTML` para o caminho do repositório na máquina.

```js
const fs = require("fs"), path = require("path");
const S = path.join(__dirname, "db2"), HTML = "D:\\dev\\lastz\\dash\\index.html";
const col = (c) => fs.readdirSync(path.join(S, c)).sort().map((f) => {
  const d = JSON.parse(fs.readFileSync(path.join(S, c, f), "utf8").replace(/^\uFEFF/, ""));
  const o = { id: f.replace(/\.json$/, "") };
  for (const k of Object.keys(d).sort()) o[k] = d[k];
  return o;
});
const now = new Date(), p = (n) => String(n).padStart(2, "0");
const foto = { em: `${p(now.getDate())}/${p(now.getMonth() + 1)} ${p(now.getHours())}:${p(now.getMinutes())}`, membros: col("membros"), registros: col("registros"), leituras: col("leituras") };
const json = JSON.stringify(foto).replace(/</g, "\\u003c");
const html = fs.readFileSync(HTML, "utf8");
const re = /(<script type="application\/json" id="foto">)[\s\S]*?(<\/script>)/;
if (!re.test(html)) throw new Error("bloco foto não encontrado");
fs.writeFileSync(HTML, html.replace(re, (_, a, b) => a + json + b));
console.log(foto.em, foto.membros.length, "membros,", foto.registros.length, "registros,", foto.leituras.length, "leituras");
```

Depois: publicar `dash/index.html` no URL da dash (Artifact publish com `url`; leia a página publicada antes se for a primeira vez na sessão) e fazer commit.

### resumo.js: números da semana para mensagens do grupo

```js
const fs = require("fs"), path = require("path");
const D = path.join(__dirname, "db2", "registros");
const rd = (f) => JSON.parse(fs.readFileSync(f, "utf8").replace(/^\uFEFF/, ""));
const R = fs.readdirSync(D).map((f) => rd(path.join(D, f)));
const diasDoa = (new Date().getDay() + 6) % 7 + 1;
console.log({
  membros: R.length,
  vsSeg: R.filter((r) => r.vs[0] >= 4.5e6).length,
  vsTer: R.filter((r) => r.vs[1] >= 5e6).length,
  doacaoNaMeta: R.filter((r) => r.doacao >= 20000 * diasDoa).length,
  totalDoado: R.reduce((a, r) => a + (r.doacao || 0), 0),
});
```

Na outra máquina, o Node precisa estar instalado (aqui era a v22). O Python não está disponível nesta máquina.
