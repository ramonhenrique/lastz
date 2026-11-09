# Gera a página pública da dash de migração com a lista atual: o mesmo que o botão "Atualizar versão pública".
# Quem abre a dash sem acesso ao banco vê a lista gravada dentro da página (bloco <script id="snapshot">).
# Antes de rodar:
#   - Artifact read, url https://claude.ai/artifact/TdiYGf4RT4jYT7LrAYC6cW, path "fonte.html" (o modelo com __SNAPSHOT__);
#   - o download da coleção membros em C:\lz\mig e o texto do resultado em C:\lz\mig_versoes.txt (passo 5a).
# Uso: .\mig_snapshot.ps1 -Fonte <caminho do fonte.html> [-Out C:\lz\migracao.html]
# Depois publique o -Out com Artifact publish, url da migração (o fonte.html publicado continua lá).
param([Parameter(Mandatory)][string]$Fonte, [string]$Out = 'C:\lz\migracao.html',
      [string]$Pasta = 'C:\lz\mig\membros', [string]$Versoes = 'C:\lz\mig_versoes.txt',
      [ValidateSet('s12', 's3')][string]$Temporada = 's3',
      [string[]]$Colunas = @('ativo', 'alianca', 'zona', 'cargo', 'sede', 'poder', 'score', 'tier', 'arena', 't10', 'vtipo', 't10ok', 'obs'))
# -Temporada: a temporada salva na página (ArtifactData get, collection config, doc_id temporada, campo s); sem o documento, s3.
. (Join-Path $PSScriptRoot 'comum.ps1')

$tpl = [IO.File]::ReadAllText($Fonte, $script:utf8)
$tag = 'id="snapshot">__SNAPSHOT__</script>'
if (-not $tpl.Contains($tag)) { throw 'fonte.html sem o marcador __SNAPSHOT__' }

$txt = [IO.File]::ReadAllText($Versoes, $script:utf8)
$ids = @{}
foreach ($m in [regex]::Matches($txt, '"([^"]+)"\s+\d+ bytes\s+version \d+')) { $ids[$m.Groups[1].Value] = 1 }
foreach ($m in [regex]::Matches($txt, '"([^"]+)" \d+(?=\s*[,\]]|\s*$)')) { $ids[$m.Groups[1].Value] = 1 }

# só os arquivos do último download (os de documentos apagados ficam na pasta, sem versão no resultado)
$rows = foreach ($a in (Get-ChildItem $Pasta -Filter *.json | Sort-Object Name)) {
  if (-not $ids.ContainsKey($a.BaseName)) { continue }
  $d = LerJson $a.FullName
  $o = [ordered]@{ id = $a.BaseName }
  foreach ($p in $d.PSObject.Properties) { if ($p.Name -ne 'id') { $o[$p.Name] = $p.Value } }
  [pscustomobject]$o
}
$rows = @($rows)
if ($rows.Count -ne $ids.Count) { throw "Esperava $($ids.Count) membros, achei $($rows.Count)" }

$snap = [ordered]@{ at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ'); temporada = $Temporada; colunas = $Colunas; rows = $rows }
$json = (ConvertTo-Json $snap -Depth 6 -Compress).Replace('<', '\u003c')
$null = $json | ConvertFrom-Json   # valida
[IO.File]::WriteAllText($Out, $tpl.Replace($tag, 'id="snapshot">' + $json + '</script>'), $script:utf8)
"lista pública com $($rows.Count) membros -> $Out"
