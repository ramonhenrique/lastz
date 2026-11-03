# Funções comuns aos scripts da coleta. Use com: . (Join-Path $PSScriptRoot 'comum.ps1')
#
# Estado local (espelho do banco da dash), em $Dir\estado:
#   membros.json, registros.json, leituras.json  arrays no formato da foto: {id, ...campos em ordem alfabética}
#   versoes.json   {docId: versão} dos registros, para o if_version das escritas
# O espelho só é alterado pelo confirma.ps1 (depois que um lote foi aceito pelo banco) ou pelo sincroniza.ps1.
# Atenção: o PowerShell não diferencia maiúsculas nos nomes de variável ($Html e $html são a mesma).

$ErrorActionPreference = 'Stop'
$script:utf8 = New-Object System.Text.UTF8Encoding $false

function Norm([string]$txt) {
  $nf = $txt.Normalize([Text.NormalizationForm]::FormKD)
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $nf.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne 'NonSpacingMark') { [void]$sb.Append($ch) } }
  ($sb.ToString().ToLowerInvariant() -replace '\s+', '')
}

function LerJson([string]$arq) {
  $obj = [IO.File]::ReadAllText($arq, $script:utf8).TrimStart([char]0xFEFF) | ConvertFrom-Json
  , $obj
}

# Lê um array JSON e devolve os itens um a um (no PowerShell 5.1 o ConvertFrom-Json entrega o array inteiro como um item só).
function LerLista([string]$arq) { foreach ($x in (LerJson $arq)) { $x } }

function SalvarJson([string]$arq, $obj, [switch]$Bonito) {
  $dir = Split-Path $arq; if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $txt = if ($Bonito) { ConvertTo-Json $obj -Depth 10 } else { ConvertTo-Json $obj -Depth 10 -Compress }
  [IO.File]::WriteAllText($arq, $txt, $script:utf8)
}

# Documento no formato da foto: id primeiro, depois os campos em ordem alfabética (mesma ordem do foto.js).
function Ordenar([string]$id, $doc) {
  $o = [ordered]@{ id = $id }
  $campos = if ($doc -is [System.Collections.IDictionary]) { @($doc.Keys) } else { @($doc.PSObject.Properties.Name) }
  foreach ($k in ($campos | Where-Object { $_ -ne 'id' } | Sort-Object { $_ } -Culture 'en-US' -CaseSensitive)) { $o[$k] = $doc.$k }
  [pscustomobject]$o
}

function PastaEstado([string]$Dir) { Join-Path $Dir 'estado' }
