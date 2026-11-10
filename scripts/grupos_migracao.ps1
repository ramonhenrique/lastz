# Auditoria dos grupos de migração (REGULAR 609 e intermediary609): compara a leitura nova com a anterior,
# muda a situação na dash de migração e monta a mensagem para o grupo de teste. Roteiro: GRUPOS_MIGRACAO.md.
#   .\grupos_migracao.ps1 [-Dir C:\lz] [-Pasta C:\lz\migN\membros] [-Versoes C:\lz\mig_versoes.txt] [-Hoje dd/MM]
#   .\grupos_migracao.ps1 -Confirmar     (depois que os lotes foram aceitos: a leitura nova vira a base)
#
# Entradas, uma linha por membro no formato ALIANCA|nome (como a lista do grupo mostra [TAG]Nome):
#   base (leitura anterior): $Dir\grp\regular.txt e $Dir\grp\inter.txt
#   nova:                    $Dir\grp\novo\regular.txt e $Dir\grp\novo\inter.txt
# Regras:
#   - entrou num grupo (ou está num grupo) e não está "vai"  -> "vai"
#   - saiu dos dois grupos e estava "vai"                    -> "nao"
#   - trocou de um grupo para o outro                         -> só aparece no relatório
#   - organizadores (Vini²², C0r1nga², Marcelo QAF, Mané 07)  -> nunca mudam
#   - nome do grupo sem cadastro na dash                      -> relatório (conta de fora: cadastrar pelo 3a/3b do LISTA_MEMBROS.md)
# Saída: $Dir\grp_batch0.json… (writes do ArtifactData batch; nenhum arquivo = nada a mudar),
#        $Dir\grp\mensagem.txt (texto para o grupo de teste) e o resumo na tela.
param([string]$Dir = 'C:\lz', [string]$Pasta = 'C:\lz\mig\membros', [string]$Versoes = 'C:\lz\mig_versoes.txt',
      [string]$Hoje = (Get-Date -Format 'dd/MM'), [switch]$Confirmar)
. (Join-Path $PSScriptRoot 'comum.ps1')

$grp = Join-Path $Dir 'grp'; $novo = Join-Path $grp 'novo'
$GRUPOS = [ordered]@{ regular = 'REGULAR 609'; inter = 'intermediary609' }

if ($Confirmar) {
  $hist = Join-Path $grp ('historico\' + (Get-Date -Format 'yyyy-MM-dd_HHmm')); New-Item -ItemType Directory -Force $hist | Out-Null
  foreach ($g in $GRUPOS.Keys) {
    $b = Join-Path $grp "$g.txt"; if (Test-Path $b) { Copy-Item $b $hist }
    Copy-Item (Join-Path $novo "$g.txt") $b -Force
  }
  Get-ChildItem $Dir -Filter 'grp_batch*.json' | Remove-Item -Force
  "leitura nova virou a base (a anterior foi para $hist)"; return
}

function LerGrupo([string]$arq) {
  if (-not (Test-Path $arq)) { throw "falta $arq" }
  [IO.File]::ReadAllLines($arq, $script:utf8) | ForEach-Object { $_.Trim().TrimStart([char]0xFEFF) } | Where-Object { $_ } | ForEach-Object {
    $p = $_ -split '\|', 2; if ($p.Count -lt 2) { $p = @('', $p[0]) }
    [pscustomobject]@{ ali = $p[0].Trim(); nome = $p[1].Trim(); k = Norm $p[1] }
  }
}
$base = @{}; $nova = @{}
foreach ($g in $GRUPOS.Keys) { $base[$g] = @(LerGrupo (Join-Path $grp "$g.txt")); $nova[$g] = @(LerGrupo (Join-Path $novo "$g.txt")) }

# banco da migração (download) e versões
$vers = @{}
foreach ($m in [regex]::Matches([IO.File]::ReadAllText($Versoes, $script:utf8), '"([^"]+)" (\d+)(?=\s*[,\]]|\s*$)')) { $vers[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
$docs = @{}; $porNome = @{}
foreach ($f in (Get-ChildItem $Pasta -Filter *.json)) {
  $d = LerJson $f.FullName; $docs[$f.BaseName] = $d
  $porNome[(Norm $d.nome)] = $f.BaseName
}
$ORGANIZA = @('m001', 'm002', 'm003', 'm071')
# nome do grupo -> id do banco: nome igual (sem acento, espaço e maiúscula) ou, se não houver, só letras e números
$soAlnum = @{}; foreach ($k in $porNome.Keys) { $a = $k -replace '[^\p{L}\p{Nd}]', ''; if ($a -and -not $soAlnum.ContainsKey($a)) { $soAlnum[$a] = $porNome[$k] } }
function Achar($x) {
  if ($porNome.ContainsKey($x.k)) { return $porNome[$x.k] }
  $a = $x.k -replace '[^\p{L}\p{Nd}]', ''
  if ($a -and $soAlnum.ContainsKey($a)) { return $soAlnum[$a] }
  $null
}

# onde cada um está, antes e agora
$antes = @{}; $agora = @{}; $info = @{}
foreach ($g in $GRUPOS.Keys) {
  foreach ($x in $base[$g]) { $antes[$x.k] = @($antes[$x.k]) + $g | Where-Object { $_ }; $info[$x.k] = $x }
  foreach ($x in $nova[$g]) { $agora[$x.k] = @($agora[$x.k]) + $g | Where-Object { $_ }; $info[$x.k] = $x }
}
$nomeG = { param($lst) (@($lst) | ForEach-Object { $GRUPOS[$_] }) -join ' e ' }

$writes = New-Object System.Collections.ArrayList
$entrou = New-Object System.Collections.ArrayList; $saiu = New-Object System.Collections.ArrayList
$trocou = New-Object System.Collections.ArrayList; $semCad = New-Object System.Collections.ArrayList; $ajuste = New-Object System.Collections.ArrayList
function Mudar($id, $status, $nota) {
  $d = $docs[$id]
  $obs = if ($d.obs) { "$($d.obs); $nota" } else { $nota }
  [void]$writes.Add([ordered]@{ op = 'update'; collection = 'membros'; doc_id = $id; data = [ordered]@{ status = $status; obs = $obs }; if_version = $vers[$id] })
}

foreach ($k in @($info.Keys | Sort-Object)) {
  $x = $info[$k]; $a = @($antes[$k] | Where-Object { $_ }); $n = @($agora[$k] | Where-Object { $_ }); $id = Achar $x
  $rot = if ($x.ali) { "$($x.nome) [$($x.ali)]" } else { $x.nome }
  if ($n.Count -and -not $a.Count) {
    # entrou
    if (-not $id) { [void]$semCad.Add("$rot, no $(& $nomeG $n)"); continue }
    if ($ORGANIZA -contains $id) { continue }
    $st = $docs[$id].status
    if ($st -ne 'vai') { Mudar $id 'vai' "entrou no $(& $nomeG $n) em $Hoje"; [void]$entrou.Add("${rot}: entrou no $(& $nomeG $n), $(if ($st -eq 'nao') { 'não vai' } else { 'sem resposta' }) -> vai") }
    else { [void]$entrou.Add("${rot}: entrou no $(& $nomeG $n), já estava vai") }
  } elseif ($a.Count -and -not $n.Count) {
    # saiu dos dois grupos
    if (-not $id -or $ORGANIZA -contains $id) { if (-not $id) { [void]$saiu.Add("${rot}: saiu do $(& $nomeG $a), sem cadastro na dash") }; continue }
    $st = $docs[$id].status
    if ($st -eq 'vai') { Mudar $id 'nao' "saiu do $(& $nomeG $a) em $Hoje"; [void]$saiu.Add("${rot}: saiu do $(& $nomeG $a), vai -> não vai") }
    else { [void]$saiu.Add("${rot}: saiu do $(& $nomeG $a), já não estava vai") }
  } else {
    if ((($a | Sort-Object) -join ',') -ne (($n | Sort-Object) -join ',')) { [void]$trocou.Add("${rot}: $(& $nomeG $a) -> $(& $nomeG $n)") }
    # continua num grupo: tem que estar "vai"
    if ($n.Count -and $id -and $ORGANIZA -notcontains $id -and $docs[$id].status -ne 'vai') {
      $st = $docs[$id].status
      Mudar $id 'vai' "está no $(& $nomeG $n) ($Hoje)"; [void]$ajuste.Add("${rot}: está no $(& $nomeG $n), $(if ($st -eq 'nao') { 'não vai' } else { 'sem resposta' }) -> vai")
    } elseif ($n.Count -and -not $id) { [void]$semCad.Add("$rot, no $(& $nomeG $n)") }
  }
}

Get-ChildItem $Dir -Filter 'grp_batch*.json' | Remove-Item -Force
for ($i = 0; $i -lt $writes.Count; $i += 50) {
  $lote = @($writes[$i..([math]::Min($i + 49, $writes.Count - 1))])
  [IO.File]::WriteAllText((Join-Path $Dir ("grp_batch{0}.json" -f ($i / 50))), (ConvertTo-Json -InputObject $lote -Depth 6 -Compress), $script:utf8)
}

$cont = "REGULAR 609: $($nova.regular.Count) · intermediary609: $($nova.inter.Count)"
$tem = $entrou.Count + $saiu.Count + $trocou.Count + $semCad.Count + $ajuste.Count
$msg = New-Object System.Collections.ArrayList
if (-not $tem) {
  [void]$msg.Add("Rotina dos grupos de migração finalizada em $Hoje $(Get-Date -Format 'HH:mm'). Não foi constatada alteração nos membros.")
  [void]$msg.Add($cont)
} else {
  [void]$msg.Add("Rotina dos grupos de migração ($Hoje $(Get-Date -Format 'HH:mm')): $($writes.Count) situação(ões) alterada(s) na dash de migração.")
  [void]$msg.Add($cont)
  $bloco = { param($tit, $lst) if ($lst.Count) { [void]$msg.Add(''); [void]$msg.Add("$tit ($($lst.Count)):"); foreach ($l in $lst) { [void]$msg.Add("- $l") } } }
  & $bloco 'Entraram' $entrou
  & $bloco 'Saíram dos grupos' $saiu
  & $bloco 'Trocaram de grupo' $trocou
  & $bloco 'Estavam no grupo sem estar como vai' $ajuste
  & $bloco 'No grupo sem cadastro na dash' $semCad
}
[IO.File]::WriteAllText((Join-Path $grp 'mensagem.txt'), ($msg -join "`n"), $script:utf8)
$msg -join "`n"
''
"$($writes.Count) escrita(s)$(if ($writes.Count) { " em $Dir\grp_batch0.json…" })"
