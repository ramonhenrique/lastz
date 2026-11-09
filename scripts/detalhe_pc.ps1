# Lê o detalhamento do PC (edifício, tecnologia, tropas, herói, veículo) de uma conta pela busca do grupo REGULAR 609.
# Começa e termina na tela "Lista de membros do chat em grupo".
#   .\detalhe_pc.ps1 -Busca "Lytta" -Out C:\lz\pc\lytta.png
# Gera <Out>_lista.png (resultado da busca), <Out>_cartao.png (cartão: sede, aliança, zona) e <Out> (detalhes do PC).
# Confira o nome no print: a busca pode trazer mais de um resultado e o primeiro é o que abre.
param([Parameter(Mandatory)][string]$Busca, [Parameter(Mandatory)][string]$Out, [int]$Linha = 1)
$ErrorActionPreference = 'Stop'
$lz = Join-Path $PSScriptRoot 'lz.ps1'
function L { & $lz @args | Out-Null }
$base = [IO.Path]::ChangeExtension($Out, $null).TrimEnd('.')
L -Action click -X 290 -Y 80; Start-Sleep -Milliseconds 400
L -Action limpar
L -Action text -Text $Busca; Start-Sleep -Milliseconds 300
L -Action click -X 498 -Y 80; Start-Sleep 2
L -Action shot -Out "$base`_lista.png"
L -Action click -X 133 -Y (152 + 93 * ($Linha - 1)); Start-Sleep 2
L -Action shot -Out "$base`_cartao.png"
L -Action click -X 160 -Y 265; Start-Sleep 2
L -Action shot -Out $Out
L -Action click -X 486 -Y 232; Start-Sleep 1   # fecha Detalhes
L -Action click -X 487 -Y 82; Start-Sleep 1    # fecha o cartão
"ok $Busca -> $Out"
