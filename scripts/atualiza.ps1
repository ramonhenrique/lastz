# Compara as leituras do jogo com o banco da dash e monta os lotes de escrita (batch0.json, batch1.json...).
# Entrada, tudo em $Dir:
#   all_membros.json, all_registros.json  (saída do junta.ps1)
#   versoes.txt   uma linha "<idMembro> <versão>" por registro da semana, copiada do resultado do ArtifactData
#   doacao_semanal.tsv e o TSV do VS do dia   (posição<TAB>nome<TAB>valor, UTF-8)
# Exemplo (terça): .\atualiza.ps1 -Sem 2026-11-02 -Dia 1 -VsTsv vs_ter.tsv -DiaDoa 1
param([string]$Sem, [int]$Dia, [string]$VsTsv, [int]$DiaDoa, [string]$Dir = "$env:TEMP\lastz-coleta")
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
# Atenção: o PowerShell não diferencia maiúsculas nos nomes de variável.
function Norm([string]$txt) {
  $nf = $txt.Normalize([Text.NormalizationForm]::FormKD)
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $nf.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne 'NonSpacingMark') { [void]$sb.Append($ch) } }
  ($sb.ToString().ToLowerInvariant() -replace '\s+', '')
}
function LerTsv([string]$nome) {
  $m = @{}
  foreach ($linha in [IO.File]::ReadAllLines((Join-Path $Dir $nome), $utf8)) { $pp = $linha -split "`t"; if ($pp.Count -eq 3) { $m[(Norm $pp[1])] = [long]$pp[2] } }
  $m
}
function LerLista([string]$nome) { [IO.File]::ReadAllText((Join-Path $Dir $nome), $utf8) | ConvertFrom-Json }

$ver = @{}
foreach ($linha in [IO.File]::ReadAllLines((Join-Path $Dir 'versoes.txt'))) { $pp = $linha.Trim() -split '\s+'; if ($pp.Count -eq 2) { $ver[$pp[0]] = [int]$pp[1] } }
$ids = @{}
foreach ($m in (LerLista 'all_membros.json')) { if (-not $m.saiu) { $ids[(Norm ([string]$m.nome))] = $m.id } }
$regs = @{}
foreach ($r in (LerLista 'all_registros.json')) { if ($r.semana -eq $Sem) { $regs[$r.membro] = $r } }
$doa = LerTsv 'doacao_semanal.tsv'; $vsd = LerTsv $VsTsv
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$up = Join-Path $Dir 'up'
if (Test-Path $up) { Get-ChildItem $up -Filter *.json | Remove-Item } else { New-Item -ItemType Directory $up | Out-Null }
$writes = New-Object System.Collections.ArrayList; $avisos = @()
foreach ($k in (@($doa.Keys) + @($vsd.Keys) | Sort-Object -Unique)) { if (-not $ids.ContainsKey($k)) { $avisos += "nome do jogo sem membro no banco: $k" } }
foreach ($nm in @($ids.Keys)) {
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
  $fp = Join-Path $up "$key.json"; [IO.File]::WriteAllText($fp, (ConvertTo-Json $obj -Compress -Depth 5), $utf8)
  $w = [ordered]@{ op = $(if ($novo) { 'set' } else { 'update' }); collection = 'registros'; doc_id = $key; file_path = $fp }
  if (-not $novo) { if (-not $ver.ContainsKey($id)) { throw "sem versão para $id em versoes.txt" }; $w.if_version = $ver[$id] }
  [void]$writes.Add([pscustomobject]$w)
}
Get-ChildItem $Dir -Filter 'batch*.json' | Remove-Item
for ($i = 0; $i -lt $writes.Count; $i += 50) { $fim = [Math]::Min($i + 49, $writes.Count - 1); [IO.File]::WriteAllText((Join-Path $Dir "batch$($i/50).json"), (ConvertTo-Json @($writes[$i..$fim]) -Depth 5), $utf8) }
"$($writes.Count) escritas, $($ids.Count) membros ativos"
$avisos
"membros sem leitura de doação: " + (($ids.Keys | Where-Object { -not $doa.ContainsKey($_) }) -join ', ')
"membros sem leitura de VS: " + (($ids.Keys | Where-Object { -not $vsd.ContainsKey($_) }) -join ', ')
