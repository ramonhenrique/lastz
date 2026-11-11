# Lista as mensagens que as rotinas enviaram no WhatsApp, lendo as execuções do fluxo
# "WhatsApp - Relatório da dash DEDZ" no n8n pela API (chave só de leitura na variável de usuário N8N_API_KEY).
# Uso: .\n8n_mensagens.ps1 [-Quantas 20] [-Destino teste|geral|lideranca] [-Desde '2026-11-11'] [-Completa]
#   -Completa mostra o texto inteiro; sem ele, só as 3 primeiras linhas de cada mensagem.
param([int]$Quantas = 20, [string]$Destino, [datetime]$Desde, [switch]$Completa)
$base = 'https://n8nmarketing.sittax.com.br/api/v1'
$fluxo = 'sLz3OdNvGJexbVkd'
$chave = [Environment]::GetEnvironmentVariable('N8N_API_KEY', 'User')
if (-not $chave) { throw 'Sem a variável N8N_API_KEY (chave de leitura do n8n).' }
$h = @{ 'X-N8N-API-KEY' = $chave; accept = 'application/json' }
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
$brt = [TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time')

$itens = @(); $cursor = $null
while ($itens.Count -lt $Quantas) {
  $url = "$base/executions?workflowId=$fluxo&includeData=true&limit=50" + $(if ($cursor) { "&cursor=$cursor" } else { '' })
  $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $h
  $o = $js.DeserializeObject([Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()))
  foreach ($e in $o['data']) {
    $rd = $e['data']['resultData']['runData']
    if (-not $rd -or -not $rd.ContainsKey('Chamado pela tool')) { continue }   # execuções do gatilho MCP repetem a mesma mensagem
    $ent = $rd['Chamado pela tool'][0]['data']['main'][0][0]['json']
    $quando = [TimeZoneInfo]::ConvertTimeFromUtc(([datetime]$e['startedAt']).ToUniversalTime(), $brt)
    if ($Desde -and $quando -lt $Desde) { $cursor = $null; break }
    $dest = if ($ent['destino']) { [string]$ent['destino'] } else { 'teste' }
    if ($Destino -and $dest -ne $Destino) { continue }
    $itens += [pscustomobject]@{ quando = $quando; destino = $dest; status = $e['status']; msg = [string]$ent['msg'] }
    if ($itens.Count -ge $Quantas) { break }
  }
  $cursor = $o['nextCursor']; if (-not $cursor) { break }
}
foreach ($i in $itens) {
  "== $($i.quando.ToString('dd/MM HH:mm')) · $($i.destino) · $($i.status)"
  $linhas = $i.msg -split "`n"
  if ($Completa -or $linhas.Count -le 3) { $linhas } else { $linhas[0..2]; "   (... mais $($linhas.Count - 3) linhas)" }
  ''
}
"$($itens.Count) mensagem(ns)"
