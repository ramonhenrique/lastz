# Regera o bloco <script id="foto"> de dash/index.html a partir do espelho local ($Dir\estado).
# Rode depois do confirma.ps1: não precisa baixar o banco de novo.
param([string]$Dir = 'C:\lz', [string]$Html = (Join-Path $PSScriptRoot '..\dash\index.html'))
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
$partes = foreach ($c in 'membros', 'registros', 'leituras') { [IO.File]::ReadAllText("$est\$c.json", $script:utf8).Trim() }
foreach ($i in 0..2) { if (-not $partes[$i].StartsWith('[')) { $partes[$i] = "[$($partes[$i])]" } }
$em = (Get-Date).ToString('dd/MM HH:mm')
$json = ('{"em":"' + $em + '","membros":' + $partes[0] + ',"registros":' + $partes[1] + ',"leituras":' + $partes[2] + '}').Replace('<', '\u003c')
$null = $json | ConvertFrom-Json  # valida
$arq = (Resolve-Path $Html).Path
$conteudo = [IO.File]::ReadAllText($arq, $script:utf8)
$re = [regex]'(<script type="application/json" id="foto">)[\s\S]*?(</script>)'
if (-not $re.IsMatch($conteudo)) { throw 'bloco foto nao encontrado' }
$conteudo = $re.Replace($conteudo, { param($mm) $mm.Groups[1].Value + $json + $mm.Groups[2].Value }, 1)
[IO.File]::WriteAllText($arq, $conteudo, $script:utf8)
"$em  foto com $($json.Length) caracteres -> $arq"
