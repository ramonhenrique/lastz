# Aplica no espelho local os lotes que o banco aceitou: mescla cada escrita em registros.json e soma 1 na versão
# (cada update aceito sobe a versão do documento em 1; um set novo começa na 1).
# Rode só com os lotes que o ArtifactData confirmou: .\confirma.ps1 -Lotes 0,1
# Se um lote foi recusado por versão, alguém mexeu no banco: rode o sincroniza.ps1 antes de tentar de novo.
param([Parameter(Mandatory)][int[]]$Lotes, [string]$Dir = 'C:\lz')
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir

$regs = [ordered]@{}; foreach ($r in (LerLista "$est\registros.json")) { $regs[$r.id] = $r }
$ver = [ordered]@{}; foreach ($p in (LerJson "$est\versoes.json").PSObject.Properties) { $ver[$p.Name] = [int]$p.Value }
$total = 0
foreach ($n in $Lotes) {
  $arq = Join-Path $Dir "batch$n.json"
  foreach ($w in (LerLista $arq)) {
    $patch = LerJson $w.file_path
    if ($w.op -eq 'set') {
      $regs[$w.doc_id] = Ordenar $w.doc_id $patch; $ver[$w.doc_id] = 1
    } else {
      if (-not $regs.Contains($w.doc_id)) { throw "$($w.doc_id) não está no espelho" }
      if ($ver[$w.doc_id] -ne $w.if_version) { throw "$($w.doc_id): espelho na versão $($ver[$w.doc_id]), lote feito para a $($w.if_version). Lote já confirmado?" }
      $doc = [ordered]@{}; foreach ($p in $regs[$w.doc_id].PSObject.Properties) { $doc[$p.Name] = $p.Value }
      foreach ($p in $patch.PSObject.Properties) { $doc[$p.Name] = $p.Value }
      $regs[$w.doc_id] = Ordenar $w.doc_id $doc; $ver[$w.doc_id] = $ver[$w.doc_id] + 1
    }
    $total++
  }
  Rename-Item $arq "batch$n.confirmado.json" -Force
}
$lista = @($regs.Keys | Sort-Object | ForEach-Object { $regs[$_] })
SalvarJson "$est\registros.json" $lista
SalvarJson "$est\versoes.json" ([pscustomobject]$ver) -Bonito
"$total escritas aplicadas no espelho ($($lista.Count) registros)"
