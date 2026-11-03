# Abre ou fecha o jogo.
#   .\jogo.ps1 -Acao abrir   abre pelo Last Z.exe (se não estiver aberto) e espera a janela "LastZ"
#   .\jogo.ps1 -Acao fechar  fecha a janela como no X; força o fim do processo só se não fechar em 20 s
param([Parameter(Mandatory)][ValidateSet('abrir','fechar')][string]$Acao)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $env:LOCALAPPDATA 'Last Z\Last Z.exe'
function Janela { Get-Process Survival -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }

if ($Acao -eq 'abrir') {
  if (Janela) { 'jogo já estava aberto'; return }
  Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
  for ($i = 0; $i -lt 60; $i++) { Start-Sleep 2; if (Janela) { break } }
  if (-not (Janela)) { throw 'a janela do jogo não apareceu em 2 minutos' }
  Start-Sleep 25   # carregamento até a cidade
  "jogo aberto após $(2 * ($i + 1) + 25) s"
} else {
  $p = @(Get-Process Survival -ErrorAction SilentlyContinue)
  if (-not $p.Count) { 'jogo já estava fechado'; return }
  foreach ($x in $p) { [void]$x.CloseMainWindow() }
  for ($i = 0; $i -lt 10; $i++) { Start-Sleep 2; if (-not (Get-Process Survival -ErrorAction SilentlyContinue)) { 'jogo fechado'; return } }
  Get-Process Survival -ErrorAction SilentlyContinue | Stop-Process -Force
  'jogo fechado à força (não respondeu ao fechar)'
}
