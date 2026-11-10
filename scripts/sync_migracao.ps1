# Sincroniza a dash de migração (https://claude.ai/artifact/TdiYGf4RT4jYT7LrAYC6cW) com o cadastro da DEDZ
# do acompanhamento (espelho $Dir\estado\membros.json). Os dois bancos usam os mesmos ids (m001…, n…).
#
# Antes de rodar, baixe a coleção da migração:
#   ArtifactData list, url da migração, collection "membros", query {"limit": 1000}, out_dir C:\lz\mig
#   e salve o TEXTO do resultado em C:\lz\mig_versoes.txt (os arquivos não trazem a versão).
# Uso: .\sync_migracao.ps1 [-Dir C:\lz]
# Saída: $Dir\mig_batch.json (lista de writes; vazio = nada a fazer). Mande como ArtifactData batch no url da
#        migração, em lotes de até 50 (mig_batch0.json, mig_batch1.json…).
#
# Regras:
# - Membro ativo da DEDZ que não está na migração: cria com situação "Sem resposta" (status pendente).
# - Membro ativo que já está: atualiza nome, cargo, poder de arena, poder total e nível da sede quando mudaram
#   (poder total e sede vêm da lista de membros, rotina manual; os componentes do poder não são tocados).
# - Quem saiu da DEDZ (campo saiu no acompanhamento): apaga da migração (decisão do Ramon em 09/11/2026).
# - Nunca mexe em situação, T10, observação, atividade, componentes, nem em membros cadastrados à mão
#   na página (origem "manual" ou id que não existe no acompanhamento).
param([string]$Dir = 'C:\lz', [string]$Pasta = 'C:\lz\mig\membros', [string]$Versoes = 'C:\lz\mig_versoes.txt')
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir

$txt = [IO.File]::ReadAllText($Versoes, $script:utf8)
$vers = @{}
foreach ($m in [regex]::Matches($txt, '"([^"]+)"\s+\d+ bytes\s+version (\d+)')) { $vers[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
foreach ($m in [regex]::Matches($txt, '"([^"]+)" (\d+)(?=\s*[,\]]|\s*$)')) { $vers[$m.Groups[1].Value] = [int]$m.Groups[2].Value }

# arquivo sem versão no resultado = sobra de um download anterior (documento já apagado): ignora
$mig = @{}
foreach ($a in (Get-ChildItem $Pasta -Filter *.json)) { if ($vers.ContainsKey($a.BaseName)) { $mig[$a.BaseName] = LerJson $a.FullName } }
$faltam = @($vers.Keys | Where-Object { -not $mig.ContainsKey($_) })
if ($faltam.Count) { throw "Versão sem arquivo baixado: $($faltam -join ', ')" }

$writes = New-Object System.Collections.Generic.List[object]
$log = New-Object System.Collections.Generic.List[string]
foreach ($mb in (LerLista "$est\membros.json")) {
  $id = $mb.id; $atual = $mig[$id]
  if ($mb.saiu) {
    if ($atual) { $writes.Add([ordered]@{ op = 'delete'; collection = 'membros'; doc_id = $id; if_version = $vers[$id] }); $log.Add("remove $($atual.nome) (saiu em $($mb.saiu))") }
    continue
  }
  $cargo = if ($mb.cargo) { [string]$mb.cargo } else { $null }
  $arena = if ($mb.poderArena) { [long]$mb.poderArena } else { $null }
  if (-not $atual) {
    $obs = if ($mb.entrou) { "entrou na DEDZ em $(([datetime]$mb.entrou).ToString('dd/MM'))" } else { '' }
    $doc = [ordered]@{ nome = [string]$mb.nome; cargo = $cargo; alianca = 'DEDZ'; origem = 'jogo'; status = 'pendente'; ativo = $true; obs = $obs; veiculoTipo = 'hercules' }
    if ($mb.poder) { $doc.poder = [long]$mb.poder }
    if ($arena) { $doc.arena = $arena }
    if ($mb.sede) { $doc.sede = [int]$mb.sede }
    $doc.zona = 614
    $writes.Add([ordered]@{ op = 'set'; collection = 'membros'; doc_id = $id; data = $doc }); $log.Add("cria $($mb.nome)")
    continue
  }
  $mud = [ordered]@{}
  if ([string]$atual.nome -cne [string]$mb.nome) { $mud.nome = [string]$mb.nome }
  if ($cargo -and [string]$atual.cargo -ne $cargo) { $mud.cargo = $cargo }
  if ($arena -and [long]$atual.arena -ne $arena) { $mud.arena = $arena }
  # poder total e sede vêm da lista de membros (membros_lista.ps1); os componentes (edifício, herói…) ficam
  if ($mb.poder -and [long]$atual.poder -ne [long]$mb.poder) { $mud.poder = [long]$mb.poder }
  if ($mb.sede -and [int]$atual.sede -ne [int]$mb.sede) { $mud.sede = [int]$mb.sede }
  if (-not $atual.zona) { $mud.zona = 614 }   # membros da DEDZ são da zona #614
  if ($mud.Count) {
    $writes.Add([ordered]@{ op = 'update'; collection = 'membros'; doc_id = $id; data = $mud; if_version = $vers[$id] })
    $log.Add("atualiza $($atual.nome): $(($mud.Keys | ForEach-Object { if ($_ -eq 'nome') { "nome -> $($mud.nome)" } elseif ($_ -eq 'cargo') { "cargo $($atual.cargo) -> $($mud.cargo)" } elseif ($_ -eq 'arena') { 'poder de arena' } elseif ($_ -eq 'sede') { "sede $($atual.sede) -> $($mud.sede)" } elseif ($_ -eq 'zona') { 'zona 614' } else { 'poder total' } }) -join ', ')")
  }
}

Get-ChildItem $Dir -Filter 'mig_batch*.json' | Remove-Item -Force
$n = 0
for ($i = 0; $i -lt $writes.Count; $i += 50) {
  $lote = @($writes[$i..([math]::Min($i + 49, $writes.Count - 1))])
  [IO.File]::WriteAllText((Join-Path $Dir "mig_batch$n.json"), (ConvertTo-Json -InputObject $lote -Depth 6 -Compress), $script:utf8); $n++
}
$log | ForEach-Object { $_ }
"$($writes.Count) escrita(s) em $n lote(s) para a migração$(if ($n) { ": $Dir\mig_batch0.json…" })"
