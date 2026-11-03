# Rola uma lista do jogo (já aberta) e junta os prints em grades para leitura.
# Doação semanal (janela 607x1046): .\scan.ps1 -Tag doa -Drags 24
# VS diário (janela 607x1046):     .\scan.ps1 -Tag vster -Drags 34 -FromY 660 -ToY 400 -CX 95 -CY 308 -CW 420 -CH 392 -PerGrid 4
param([string]$Tag, [int]$Drags = 24, [int]$FromY = 780, [int]$ToY = 400,
      [int]$CX = 80, [int]$CY = 225, [int]$CW = 450, [int]$CH = 615, [int]$PerGrid = 3,
      [string]$Dir = "$env:TEMP\lastz-coleta")
$lz = Join-Path $PSScriptRoot 'lz.ps1'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Dir | Out-Null
Remove-Item "$Dir\${Tag}_*.png", "$Dir\G_${Tag}_*.png" -ErrorAction SilentlyContinue
& $lz -Action shot -Out ("$Dir\{0}_00.png" -f $Tag) | Out-Null
for ($i = 1; $i -le $Drags; $i++) {
  & $lz -Action drag -X 300 -Y $FromY -X2 300 -Y2 $ToY | Out-Null
  Start-Sleep 1.2
  & $lz -Action shot -Out ("$Dir\{0}_{1:D2}.png" -f $Tag, $i) | Out-Null
}
$files = Get-ChildItem "$Dir\${Tag}_*.png" | Sort-Object Name
$crop = New-Object System.Drawing.Rectangle $CX, $CY, $CW, $CH
$n = 0
for ($k = 0; $k -lt $files.Count; $k += $PerGrid) {
  $grp = $files[$k..([Math]::Min($k + $PerGrid - 1, $files.Count - 1))]
  $out = New-Object System.Drawing.Bitmap ($CW * $grp.Count), $CH
  $g = [System.Drawing.Graphics]::FromImage($out)
  $j = 0
  foreach ($f in $grp) {
    $b = [System.Drawing.Bitmap]::FromFile($f.FullName)
    $g.DrawImage($b, (New-Object System.Drawing.Rectangle ($j * $CW), 0, $CW, $CH), $crop, 'Pixel')
    $b.Dispose(); $j++
  }
  $out.Save(("$Dir\G_{0}_{1}.png" -f $Tag, $n), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $out.Dispose(); $n++
}
"$Tag -> $n grades em $Dir"
