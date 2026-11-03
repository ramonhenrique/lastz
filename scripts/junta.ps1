# Junta os JSONs de uma coleção baixada pelo ArtifactData (out_dir) num único arquivo:
# array de {id, ...campos em ordem alfabética}, o formato da foto da dash.
# Rode logo depois de cada download: o próximo download apaga os arquivos do anterior.
param([string]$Pasta, [string]$Saida, [int]$Esperado)
$utf8 = New-Object System.Text.UTF8Encoding $false
$arqs = Get-ChildItem $Pasta -Filter *.json | Sort-Object Name
if ($arqs.Count -ne $Esperado) { throw "Esperava $Esperado arquivos em $Pasta, achei $($arqs.Count)" }
$lista = foreach ($a in $arqs) {
  $doc = [IO.File]::ReadAllText($a.FullName, $utf8).TrimStart([char]0xFEFF) | ConvertFrom-Json
  $o = [ordered]@{ id = $a.BaseName }
  foreach ($k in ($doc.PSObject.Properties.Name | Sort-Object { $_ } -Culture 'en-US' -CaseSensitive)) { $o[$k] = $doc.$k }
  [pscustomobject]$o
}
[IO.File]::WriteAllText($Saida, (ConvertTo-Json @($lista) -Depth 10 -Compress), $utf8)
"$($arqs.Count) -> $Saida"
