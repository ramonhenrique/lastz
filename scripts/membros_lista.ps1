# Lista de membros (rotina manual "atualizar lista de membros"): grava poder total, cargo e nível da sede
# no banco da dash de acompanhamento. O poder de arena NÃO é lido (só um R4 vê; a conta da rotina é R3).
#
# Entrada: $Dir\membros_lista.tsv, uma linha por membro lido no jogo: cargo<TAB>nome<TAB>sede<TAB>poder em milhões
#          (ex.: R3<TAB>Assofra<TAB>33<TAB>248.2). R5 inclusive.
# Antes de rodar: ArtifactData list no URL da dash de acompanhamento, collection "membros", query {"limit": 1000},
#   out_dir C:\lz\dl, e salve o TEXTO do resultado em C:\lz\membros_versoes.txt (pares id/versão).
# Uso: .\membros_lista.ps1            -> gera $Dir\mlista_batch0.json… (updates com if_version) e lista o que não casou
#      .\membros_lista.ps1 -Confirmar -> depois que o banco aceitar os lotes, aplica as mesmas mudanças no espelho
# Não cria, não renomeia e não marca saída: esses casos saem na lista "sem par" para o usuário decidir.
param([string]$Dir = 'C:\lz', [string]$Versoes = 'C:\lz\membros_versoes.txt', [switch]$Confirmar,
      [string]$Data = (Get-Date).ToString('yyyy-MM-dd'))
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir

$jogo = [ordered]@{}
foreach ($ln in [IO.File]::ReadAllLines((Join-Path $Dir 'membros_lista.tsv'), $script:utf8)) {
  $p = $ln -split "`t"; if ($p.Count -lt 4) { continue }
  $jogo[(Norm $p[1])] = [pscustomobject]@{ cargo = $p[0].Trim(); nome = $p[1].Trim(); sede = [int]$p[2]; poder = [long][math]::Round([double]($p[3].Replace(',', '.')) * 1e6) }
}
$membros = @(LerLista "$est\membros.json")
$ativos = @($membros | Where-Object { -not $_.saiu })
$porNome = @{}; foreach ($m in $ativos) { $porNome[(Norm $m.nome)] = $m }

$mud = [ordered]@{}
foreach ($k in $jogo.Keys) {
  $m = $porNome[$k]; if (-not $m) { continue }
  $j = $jogo[$k]; $d = [ordered]@{}
  if ([long]$m.poder -ne $j.poder) { $d.poder = $j.poder }
  if ([int]$m.sede -ne $j.sede) { $d.sede = $j.sede }
  if ([string]$m.cargo -ne $j.cargo) { $d.cargo = $j.cargo }
  if ($d.Count) { $d.poderEm = $Data; $mud[$m.id] = $d }
}

if ($Confirmar) {
  foreach ($m in $membros) {
    if (-not $mud.Contains($m.id)) { continue }
    foreach ($kv in $mud[$m.id].GetEnumerator()) { $m | Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value -Force }
  }
  SalvarJson "$est\membros.json" @($membros | ForEach-Object { Ordenar $_.id $_ })
  "espelho: $($mud.Count) membro(s) atualizados"
  return
}

$txt = [IO.File]::ReadAllText($Versoes, $script:utf8)
$vers = @{}
foreach ($x in [regex]::Matches($txt, '"([^"]+)"\s+\d+ bytes\s+version (\d+)')) { $vers[$x.Groups[1].Value] = [int]$x.Groups[2].Value }
foreach ($x in [regex]::Matches($txt, '"([^"]+)" (\d+)(?=[,\]])')) { $vers[$x.Groups[1].Value] = [int]$x.Groups[2].Value }
$writes = New-Object System.Collections.Generic.List[object]
foreach ($id in $mud.Keys) {
  if (-not $vers.ContainsKey($id)) { throw "Sem versão para $id em $Versoes" }
  $writes.Add([ordered]@{ op = 'update'; collection = 'membros'; doc_id = $id; data = $mud[$id]; if_version = $vers[$id] })
}
Get-ChildItem $Dir -Filter 'mlista_batch*.json' | Remove-Item -Force
$n = 0
for ($i = 0; $i -lt $writes.Count; $i += 50) {
  $lote = @($writes[$i..([math]::Min($i + 49, $writes.Count - 1))])
  [IO.File]::WriteAllText((Join-Path $Dir "mlista_batch$n.json"), (ConvertTo-Json -InputObject $lote -Depth 6 -Compress), $script:utf8); $n++
}
$cargos = @($mud.Values | Where-Object { $_.Contains('cargo') }).Count
"lidos no jogo: $($jogo.Count) · no banco: $($ativos.Count) · com mudança: $($mud.Count) (cargo: $cargos) -> $n lote(s) $Dir\mlista_batch0.json…"
$semBanco = @($jogo.Keys | Where-Object { -not $porNome[$_] } | ForEach-Object { $j = $jogo[$_]; "$($j.cargo) $($j.nome) (sede $($j.sede), $([math]::Round($j.poder / 1e6, 1))M)" })
$semJogo = @($ativos | Where-Object { -not $jogo.Contains((Norm $_.nome)) } | ForEach-Object { "$($_.id) $($_.nome) ($($_.cargo), $([math]::Round([double]$_.poder / 1e6, 1))M)" })
if ($semBanco.Count) { "nome do jogo sem membro no banco: $($semBanco -join '; ')" }
if ($semJogo.Count) { "membro do banco que não está no jogo: $($semJogo -join '; ')" }
