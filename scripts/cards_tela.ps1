# Roda card_pc.ps1 em várias posições da tela atual da lista de membros.
#   .\cards_tela.ps1 -Pos "133,445 350,445 ..." -Prefixo s01
param([Parameter(Mandatory)][string]$Pos, [Parameter(Mandatory)][string]$Prefixo, [string]$Pasta = 'C:\lz\cards')
$lz = Join-Path $PSScriptRoot 'lz.ps1'; $cp = Join-Path $PSScriptRoot 'card_pc.ps1'
$base = Join-Path $Pasta "$Prefixo`_base.png"
powershell -NoProfile -ExecutionPolicy Bypass -File $lz -Action shot -Out $base | Out-Null
$i = 0
foreach ($p in ($Pos -split '\s+' | ? { $_ })) {
  $i++; $xy = $p -split ','
  $out = Join-Path $Pasta ('{0}_{1:00}.png' -f $Prefixo, $i)
  $r = powershell -NoProfile -ExecutionPolicy Bypass -File $cp -X $xy[0] -Y $xy[1] -Out $out -Base $base
  "$Prefixo $i ($p): $r"
  if ($r -ne 'ok') { break }   # parou: algo inesperado na tela, conferir antes de seguir
}
