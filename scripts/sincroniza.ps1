# Atualiza o espelho local com uma coleção baixada pelo ArtifactData (action list/query com out_dir).
# Rode logo depois de cada download: o download seguinte apaga os arquivos do anterior.
#   membros:   .\sincroniza.ps1 -Colecao membros   -Pasta C:\lz\dl\membros   -Esperado 102
#   leituras:  .\sincroniza.ps1 -Colecao leituras  -Pasta C:\lz\dl\leituras  -Esperado 1
#   registros: .\sincroniza.ps1 -Colecao registros -Pasta C:\lz\dl\registros -Esperado 97 -Versoes C:\lz\versoes.txt
# Os arquivos baixados não trazem a versão. Para registros, salve em versoes.txt o texto do resultado do download:
# o script acha os pares id/versão nas duas formas que ele mostra ("id"  275 bytes  version 5  ... e "id" 5).
# Registros de uma semana só (query por semana) substituem só essa semana no espelho; as outras ficam.
param([Parameter(Mandatory)][ValidateSet('membros','registros','leituras')][string]$Colecao,
      [Parameter(Mandatory)][string]$Pasta, [Parameter(Mandatory)][int]$Esperado,
      [string]$Versoes, [string]$Dir = 'C:\lz')
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
New-Item -ItemType Directory -Force $est | Out-Null
$arqs = @(Get-ChildItem $Pasta -Filter *.json | Sort-Object Name)
if ($arqs.Count -ne $Esperado) { throw "Esperava $Esperado arquivos em $Pasta, achei $($arqs.Count)" }
$novos = [ordered]@{}
foreach ($a in $arqs) { $novos[$a.BaseName] = Ordenar $a.BaseName (LerJson $a.FullName) }

if ($Colecao -eq 'registros') {
  if (-not $Versoes) { throw 'Para registros, passe -Versoes com o texto do resultado do download' }
  $txt = [IO.File]::ReadAllText($Versoes, $script:utf8)
  $vers = @{}
  foreach ($m in [regex]::Matches($txt, '"([^"]+)"\s+\d+ bytes\s+version (\d+)')) { $vers[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
  foreach ($m in [regex]::Matches($txt, '"([^"]+)" (\d+)(?=[,\]])')) { $vers[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
  $faltam = @($novos.Keys | Where-Object { -not $vers.ContainsKey($_) })
  if ($faltam.Count) { throw "Sem versão para: $($faltam -join ', ')" }
  $semanas = @($novos.Values | ForEach-Object { $_.semana } | Sort-Object -Unique)
  $regs = [ordered]@{}; $ver = [ordered]@{}
  if (Test-Path "$est\registros.json") {
    foreach ($r in (LerLista "$est\registros.json")) { if ($r.semana -notin $semanas) { $regs[$r.id] = $r } }
    foreach ($p in (LerJson "$est\versoes.json").PSObject.Properties) { if ($regs.Contains($p.Name)) { $ver[$p.Name] = [int]$p.Value } }
  }
  foreach ($k in $novos.Keys) { $regs[$k] = $novos[$k]; $ver[$k] = $vers[$k] }
  SalvarJson "$est\registros.json" @($regs.Keys | Sort-Object | ForEach-Object { $regs[$_] })
  SalvarJson "$est\versoes.json" ([pscustomobject]$ver) -Bonito
  "registros: $($novos.Count) da(s) semana(s) $($semanas -join ', '); $($regs.Count) no espelho"
} else {
  SalvarJson "$est\$Colecao.json" @($novos.Values)
  "${Colecao}: $($novos.Count) no espelho"
}
