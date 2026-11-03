# Regera o bloco <script id="foto"> de dash/index.html a partir de all_membros.json, all_registros.json e
# all_leituras.json (saídas do junta.ps1, com o banco baixado DEPOIS das escritas).
param([string]$Dir = "$env:TEMP\lastz-coleta", [string]$Html = (Join-Path $PSScriptRoot '..\dash\index.html'))
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$m = [IO.File]::ReadAllText("$Dir\all_membros.json", $utf8)
$r = [IO.File]::ReadAllText("$Dir\all_registros.json", $utf8)
$l = [IO.File]::ReadAllText("$Dir\all_leituras.json", $utf8)
$em = (Get-Date).ToString('dd/MM HH:mm')
$json = ('{"em":"' + $em + '","membros":' + $m + ',"registros":' + $r + ',"leituras":' + $l + '}').Replace('<', '<')
$null = $json | ConvertFrom-Json  # valida
$arq = (Resolve-Path $Html).Path
$conteudo = [IO.File]::ReadAllText($arq, $utf8)
$re = [regex]'(<script type="application/json" id="foto">)[\s\S]*?(</script>)'
if (-not $re.IsMatch($conteudo)) { throw 'bloco foto nao encontrado' }
$conteudo = $re.Replace($conteudo, { param($mm) $mm.Groups[1].Value + $json + $mm.Groups[2].Value }, 1)
[IO.File]::WriteAllText($arq, $conteudo, $utf8)
"$em  foto com $($json.Length) caracteres -> $arq"
