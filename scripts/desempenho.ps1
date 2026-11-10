# Resume o desempenho de cada membro da DEDZ (VS e doação) a partir do espelho da dash de acompanhamento,
# para a dash de migração marcar quem se empenha pouco (coluna Desempenho e sinal "não deveria ir").
#   .\desempenho.ps1 [-Dir C:\lz] [-Hoje 2026-11-10] [-Out C:\lz\desempenho.json]
# Depois grave o arquivo no banco da migração: ArtifactData set, collection "config", doc_id "desempenho",
# file_path C:\lz\desempenho.json (com o if_version do documento, se ele já existir).
#
# Só entram dias já fechados (antes de -Hoje) e, para quem entrou depois, só os dias desde a entrada.
# Por membro (chave = id, o mesmo nas duas dashes):
#   d  = dias de VS com leitura      m = dias em que bateu a meta    z = dias zerados
#   doa = doação somada               dm = doação esperada (20 mil por dia fechado)
#   ent = data de entrada (se houver)   sec = nome da conta principal, se for conta secundária
param([string]$Dir = 'C:\lz', [string]$Hoje = (Get-Date -Format 'yyyy-MM-dd'), [string]$Out = 'C:\lz\desempenho.json')
. (Join-Path $PSScriptRoot 'comum.ps1')

$metas = 4.5e6, 5e6, 3.3e6, 6e6, 7e6, 6e6     # mesmas metas diárias do VS do relatorio.ps1 (seg a sáb)
$doaDia = 20000
$hojeD = [datetime]::ParseExact($Hoje, 'yyyy-MM-dd', $null)
$est = Join-Path $Dir 'estado'
$cad = @{}; foreach ($m in (LerLista (Join-Path $est 'membros.json'))) { $cad[$m.id] = $m }
$sec = @{}
$arqSec = Join-Path $PSScriptRoot 'secundarias.json'
if (Test-Path $arqSec) { $js = LerJson $arqSec; foreach ($p in $js.PSObject.Properties) { if ($p.Name -ne '_sobre') { $sec[$p.Name] = $p.Value.principalNome } } }

$acc = @{}
$ultimo = $null
foreach ($r in (LerLista (Join-Path $est 'registros.json'))) {
  $mb = $cad[$r.membro]; if (-not $mb -or $mb.saiu) { continue }
  $sem = [datetime]::ParseExact($r.semana, 'yyyy-MM-dd', $null)
  $ent = if ($mb.entrou) { [datetime]::ParseExact([string]$mb.entrou, 'yyyy-MM-dd', $null) } else { [datetime]::MinValue }
  if (-not $acc.ContainsKey($r.membro)) { $acc[$r.membro] = [ordered]@{ d = 0; m = 0; z = 0; doa = 0; dm = 0 } }
  $a = $acc[$r.membro]
  # VS: segunda a sábado
  for ($i = 0; $i -lt 6; $i++) {
    $dia = $sem.AddDays($i)
    if ($dia -ge $hojeD -or $dia -lt $ent.Date) { continue }
    $v = if ($r.vs -and $r.vs.Count -gt $i) { $r.vs[$i] } else { $null }
    if ($null -eq $v) { continue }
    $a.d++; if ([double]$v -ge $metas[$i]) { $a.m++ }; if ([double]$v -le 0) { $a.z++ }
    if (-not $ultimo -or $dia -gt $ultimo) { $ultimo = $dia }
  }
  # doação: acumulado da semana até o último dia fechado com alguma leitura (VS ou doação). A doação semanal
  # nunca diminui, então um dia sem leitura de doação vale o último acumulado lido antes dele; sem nenhum
  # acumulado na semana, vale 0 (o ranking do jogo só lista quem doou).
  $ini = if ($ent -gt $sem) { [int]($ent.Date - $sem).TotalDays } else { 0 }
  $ult = -1; $acum = 0
  for ($i = $ini; $i -le 6; $i++) {
    if ($sem.AddDays($i) -ge $hojeD) { break }
    $v = if ($r.doacaoDias -and $r.doacaoDias.Count -gt $i) { $r.doacaoDias[$i] } else { $null }
    $temVS = $i -lt 6 -and $r.vs -and $r.vs.Count -gt $i -and $null -ne $r.vs[$i]
    if ($null -ne $v) { $acum = [math]::Max($acum, [double]$v) }
    if ($null -ne $v -or $temVS) { $ult = $i }
  }
  if ($ult -ge 0) { $a.doa += $acum; $a.dm += $doaDia * ($ult + 1 - $ini) }
}

$saida = [ordered]@{}
foreach ($id in ($acc.Keys | Sort-Object)) {
  $o = $acc[$id]
  if ($cad[$id].entrou) { $o.ent = [string]$cad[$id].entrou }
  if ($sec.ContainsKey($id)) { $o.sec = $sec[$id] }
  $saida[$id] = $o
}
$doc = [ordered]@{ at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); ate = if ($ultimo) { $ultimo.ToString('yyyy-MM-dd') } else { $null }; metaDoaDia = $doaDia; membros = $saida }
SalvarJson $Out $doc
"desempenho de $($saida.Count) membros até $($doc.ate) -> $Out"
