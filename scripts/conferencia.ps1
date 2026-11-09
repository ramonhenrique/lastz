# Gera a página de conferência para os membros (poder, componentes do PC e Migration Score, sem situação, observação e atividade).
# Usa o download da coleção membros da dash de migração (o mesmo do mig_snapshot.ps1).
#   .\conferencia.ps1 -Pasta C:\lz\mig10\membros -Versoes C:\lz\mig_versoes.txt [-LidoEm 2026-11-09] [-Temporada s3]
# Depois publique dash\conferencia.html no URL da página de conferência (ver ROTINA.md, passo 5a).
param([string]$Fonte = (Join-Path $PSScriptRoot '..\dash\conferencia_fonte.html'),
      [string]$Out = (Join-Path $PSScriptRoot '..\dash\conferencia.html'),
      [string]$Pasta = 'C:\lz\mig\membros', [string]$Versoes = 'C:\lz\mig_versoes.txt',
      [string]$LidoEm = (Get-Date -Format 'yyyy-MM-dd'),
      [ValidateSet('s12', 's3')][string]$Temporada = 's3')
. (Join-Path $PSScriptRoot 'comum.ps1')

$tpl = [IO.File]::ReadAllText($Fonte, $script:utf8)
if (-not $tpl.Contains('__DADOS__')) { throw 'conferencia_fonte.html sem o marcador __DADOS__' }
$txt = [IO.File]::ReadAllText($Versoes, $script:utf8)
$ids = @{}
foreach ($m in [regex]::Matches($txt, '"([^"]+)"\s+\d+ bytes\s+version \d+')) { $ids[$m.Groups[1].Value] = 1 }
foreach ($m in [regex]::Matches($txt, '"([^"]+)" \d+(?=\s*[,\]]|\s*$)')) { $ids[$m.Groups[1].Value] = 1 }

# só os campos que os membros podem ver: nada de situação, observação, atividade, arena ou T10 (%)
$campos = 'nome', 'alianca', 'cargo', 'sede', 'poder', 'edificio', 'tecnologia', 'tropas', 'heroi', 'veiculo', 'veiculoTipo', 't10ok'
$rows = foreach ($a in (Get-ChildItem $Pasta -Filter *.json | Sort-Object Name)) {
  if (-not $ids.ContainsKey($a.BaseName)) { continue }
  $d = LerJson $a.FullName
  if ($d.ativo -eq $false) { continue }
  $o = [ordered]@{ id = $a.BaseName }
  foreach ($c in $campos) { $o[$c] = $d.$c }
  if (-not $o.alianca) { $o.alianca = 'DEDZ' }
  $o.alianca = "$($o.alianca)".ToUpper()
  $o.t10ok = ($d.t10ok -eq $true)
  [pscustomobject]$o
}
$rows = @($rows)
$dados = [ordered]@{ at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); lidoEm = $LidoEm; temporada = $Temporada; rows = $rows }
$json = (ConvertTo-Json $dados -Depth 5 -Compress).Replace('<', '\u003c')
$null = $json | ConvertFrom-Json
[IO.File]::WriteAllText($Out, $tpl.Replace('__DADOS__', $json), $script:utf8)
"conferência com $($rows.Count) jogadores -> $Out"
