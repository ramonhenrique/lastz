# Compara as leituras do jogo com o espelho local do banco e monta os lotes de escrita.
# Entrada em $Dir: doacao_semanal.tsv e o TSV do VS do dia (posição<TAB>nome<TAB>valor, UTF-8), e o espelho em $Dir\estado.
# Saída: $Dir\batch0.json, batch1.json... (até 50 escritas cada, já com if_version) e os arquivos em $Dir\up.
# Não altera o espelho: depois que o banco aceitar os lotes, rode o confirma.ps1.
# Exemplo (terça): .\atualiza.ps1 -Sem 2026-11-02 -Dia 1 -VsTsv vs_ter.tsv -DiaDoa 1
# Sem leitura de VS, use -VsTsv ''. Sem leitura de doação, -DoaTsv ''.
param([Parameter(Mandatory)][string]$Sem, [int]$Dia = -1, [string]$VsTsv = '', [int]$DiaDoa = -1,
      [string]$DoaTsv = 'doacao_semanal.tsv', [string]$Dir = 'C:\lz')
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir

function LerTsv([string]$nome) {
  $m = @{}
  if (-not $nome) { return $m }
  foreach ($linha in [IO.File]::ReadAllLines((Join-Path $Dir $nome), $script:utf8)) { $pp = $linha -split "`t"; if ($pp.Count -eq 3) { $m[(Norm $pp[1])] = [long]$pp[2] } }
  $m
}

if ($VsTsv -and $Dia -lt 0) { throw 'Informe -Dia (0 = segunda ... 5 = sábado)' }
if ($DoaTsv -and $DiaDoa -lt 0) { $DiaDoa = ([int](Get-Date).DayOfWeek + 6) % 7 }

$ver = @{}; foreach ($p in (LerJson "$est\versoes.json").PSObject.Properties) { $ver[$p.Name] = [int]$p.Value }
$ids = @{}
foreach ($m in (LerLista "$est\membros.json")) { if (-not $m.saiu) { $ids[(Norm ([string]$m.nome))] = $m.id } }
$regs = @{}
foreach ($r in (LerLista "$est\registros.json")) { if ($r.semana -eq $Sem) { $regs[$r.membro] = $r } }
$doa = LerTsv $DoaTsv; $vsd = LerTsv $VsTsv

$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$up = Join-Path $Dir 'up'
if (Test-Path $up) { Get-ChildItem $up -Filter *.json | Remove-Item } else { New-Item -ItemType Directory $up | Out-Null }
$writes = New-Object System.Collections.ArrayList; $avisos = @()
foreach ($k in (@($doa.Keys) + @($vsd.Keys) | Sort-Object -Unique)) { if (-not $ids.ContainsKey($k)) { $avisos += "nome do jogo sem membro no banco: $k" } }
foreach ($nm in @($ids.Keys | Sort-Object)) {
  $id = $ids[$nm]; $key = "${Sem}__$id"
  $novo = -not $regs.ContainsKey($id)
  if ($novo) { $r = [pscustomobject]@{ doacao = $null; doacaoDias = @($null,$null,$null,$null,$null,$null,$null); vs = @($null,$null,$null,$null,$null,$null) } } else { $r = $regs[$id] }
  $patch = [ordered]@{}
  if ($doa.ContainsKey($nm) -and $r.doacao -ne $doa[$nm]) {
    $dd = @($r.doacaoDias); while ($dd.Count -lt 7) { $dd += $null }; $dd[$DiaDoa] = $doa[$nm]
    $patch.doacao = $doa[$nm]; $patch.doacaoDias = $dd
  }
  if ($vsd.ContainsKey($nm) -and $r.vs[$Dia] -ne $vsd[$nm]) { $v = @($r.vs); $v[$Dia] = $vsd[$nm]; $patch.vs = $v }
  if ($patch.Count -eq 0) { continue }
  $patch.at = $now
  if ($novo) { $obj = [ordered]@{ semana = $Sem; membro = $id; doacao = $null; doacaoDias = $r.doacaoDias; vs = $r.vs }; foreach ($pk in @($patch.Keys)) { $obj[$pk] = $patch[$pk] } } else { $obj = $patch }
  $fp = Join-Path $up "$id.json"; SalvarJson $fp $obj
  $w = [ordered]@{ op = $(if ($novo) { 'set' } else { 'update' }); collection = 'registros'; doc_id = $key; file_path = $fp }
  if (-not $novo) { if (-not $ver.ContainsKey($key)) { throw "sem versão de $key no espelho: rode o sincroniza.ps1" }; $w.if_version = $ver[$key] }
  [void]$writes.Add([pscustomobject]$w)
}
Get-ChildItem $Dir -Filter 'batch*.json' | Remove-Item
$n = 0
for ($i = 0; $i -lt $writes.Count; $i += 50) { $fim = [Math]::Min($i + 49, $writes.Count - 1); SalvarJson (Join-Path $Dir "batch$n.json") @($writes[$i..$fim]); $n++ }
"$($writes.Count) escritas em $n lote(s), $($ids.Count) membros ativos"
$avisos
$sd = @($ids.Keys | Where-Object { $DoaTsv -and -not $doa.ContainsKey($_) }); if ($sd.Count) { "membros sem leitura de doação: " + ($sd -join ', ') }
$sv = @($ids.Keys | Where-Object { $VsTsv -and -not $vsd.ContainsKey($_) }); if ($sv.Count) { "membros sem leitura de VS: " + ($sv -join ', ') }
