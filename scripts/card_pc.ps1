# Lê cartão + detalhamento do PC de um membro na lista Aliança > Membros.
#   .\card_pc.ps1 -X 133 -Y 530 -Out C:\lz\cards\001.png -Base C:\lz\cards\base.png
# -Base: print da tela da lista ANTES do toque (para achar o menu pela diferença).
# Toca no retrato, acha o botão "Detalhes" (o verde de cima à esquerda do menu; "Ajuste de classe" fica embaixo e nunca é tocado),
# abre o cartão, toca em PC e salva um recorte: nome + sede (cartão) em cima, detalhamento do PC embaixo.
# Fecha tudo e volta para a lista. Saída: "ok", "sem-menu" (nada tocado além do retrato) ou "sem-cartao".
param([int]$X, [int]$Y, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Base)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$lz = Join-Path $PSScriptRoot 'lz.ps1'
function L { powershell -NoProfile -ExecutionPolicy Bypass -File $lz @args | Out-Null }   # processo separado: no mesmo processo o clique não pegava
function Verde($c) { $c.G -gt 140 -and $c.R -lt 140 -and $c.B -lt 110 -and ($c.G - $c.R) -gt 35 }
$tmp = [IO.Path]::GetTempPath()

$s1 = Join-Path $tmp 'cpc_menu.png'
for ($tent = 1; $tent -le 2; $tent++) {   # o jogo às vezes ignora o toque logo depois de fechar um cartão
  L -Action click -X $X -Y $Y; Start-Sleep -Milliseconds 1200
  L -Action shot -Out $s1
  $a = [Drawing.Bitmap]::FromFile($Base); $b = [Drawing.Bitmap]::FromFile($s1)
  $pts = New-Object System.Collections.Generic.List[object]
  for ($yy = 60; $yy -lt 930; $yy += 4) { for ($xx = 90; $xx -lt 540; $xx += 4) {
    $cb = $b.GetPixel($xx, $yy); if (-not (Verde $cb)) { continue }
    if (Verde ($a.GetPixel($xx, $yy))) { continue }
    $pts.Add(@($xx, $yy)) } }
  $a.Dispose(); $b.Dispose()
  if ($pts.Count -ge 40) { break }
}
if ($pts.Count -lt 40) { 'sem-menu'; return }
$miny = ($pts | % { $_[1] } | Measure-Object -Minimum).Minimum
$top = $pts | ? { $_[1] -lt $miny + 45 }
$minx = ($top | % { $_[0] } | Measure-Object -Minimum).Minimum; $maxx = ($top | % { $_[0] } | Measure-Object -Maximum).Maximum
$left = $top | ? { $_[0] -lt ($minx + $maxx) / 2 }
$dx = [int](($left | % { $_[0] } | Measure-Object -Average).Average); $dy = [int](($left | % { $_[1] } | Measure-Object -Average).Average)
L -Action click -X $dx -Y $dy
# espera o cartão abrir (vermelho do botão X em 472,72), até ~6 s
$s2 = Join-Path $tmp 'cpc_card.png'; $aberto = $false
for ($i = 0; $i -lt 8 -and -not $aberto; $i++) {
  Start-Sleep -Milliseconds 800; L -Action shot -Out $s2
  $c = [Drawing.Bitmap]::FromFile($s2); $px = $c.GetPixel(472, 72); $c.Dispose()
  $aberto = $px.R -gt 150 -and $px.G -lt 120 }
if (-not $aberto) { 'sem-cartao'; return }
Start-Sleep -Milliseconds 600; L -Action shot -Out $s2   # nome e números já carregados
L -Action click -X 160 -Y 265; Start-Sleep -Milliseconds 2000
$s3 = Join-Path $tmp 'cpc_det.png'; L -Action shot -Out $s3
L -Action click -X 486 -Y 232; Start-Sleep -Milliseconds 1000
L -Action click -X 487 -Y 82; Start-Sleep -Milliseconds 1300
# confere se o cartão fechou (o vermelho do X some); senão, toca no X de novo
for ($i = 0; $i -lt 3; $i++) {
  $s4 = Join-Path $tmp 'cpc_fim.png'; L -Action shot -Out $s4
  $c = [Drawing.Bitmap]::FromFile($s4); $px = $c.GetPixel(472, 72); $c.Dispose()
  if (-not ($px.R -gt 150 -and $px.G -lt 120)) { break }
  L -Action click -X 487 -Y 82; Start-Sleep -Milliseconds 1300 }
# recorte: cartão (nome, Lv, PC) 120..500 x 175..280 ; detalhes 120..500 x 262..600
$card = [Drawing.Image]::FromFile($s2); $det = [Drawing.Image]::FromFile($s3)
$o = New-Object Drawing.Bitmap 380, 443; $g = [Drawing.Graphics]::FromImage($o); $g.Clear([Drawing.Color]::White)
$g.DrawImage($card, (New-Object Drawing.Rectangle 0, 0, 380, 105), (New-Object Drawing.Rectangle 120, 175, 380, 105), [Drawing.GraphicsUnit]::Pixel)
$g.DrawImage($det, (New-Object Drawing.Rectangle 0, 105, 380, 338), (New-Object Drawing.Rectangle 120, 262, 380, 338), [Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $card.Dispose(); $det.Dispose(); $o.Save($Out); $o.Dispose()
'ok'
