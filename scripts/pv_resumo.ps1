# Monta o resumo das notificações no PV para o grupo da liderança e grava o histórico de envios.
# Uso: .\pv_resumo.ps1 -Resultado C:\lz\pv_resultado.tsv [-Data 2026-11-04] [-Dir C:\lz] [-NaoSalvarHistorico]
#   pv_resultado.tsv: uma linha por pessoa da lista, na ordem: nome<TAB>assunto<TAB>ok|falhou<TAB>motivo (motivo só se falhou)
#   assunto: doação | VS, 2 dias abaixo da meta | VS, 3 dias abaixo da meta, e doação | balanço da semana ...
# Saída: $Dir\pv_resumo.txt (texto exato para enviar) e $Dir\estado\pv_historico.json (um registro por envio).
# Reincidente = já recebeu notificação no PV antes desta data (últimas 4 semanas), recebida ou não.
param([Parameter(Mandatory)][string]$Resultado, [datetime]$Data = (Get-Date).AddHours(1).Date, [string]$Dir = 'C:\lz', [switch]$NaoSalvarHistorico)
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
$dataTxt = $Data.ToString('yyyy-MM-dd')
$diaSem = ([int]$Data.DayOfWeek + 6) % 7
$tipo = if ($diaSem -eq 5) { 'sábado' } else { 'quarta' }

$porNome = @{}; foreach ($m in (LerLista "$est\membros.json")) { $porNome[(Norm $m.nome)] = $m }
$histArq = "$est\pv_historico.json"
$hist = @(); if (Test-Path $histArq) { $hist = @(LerLista $histArq) }
$limite = $Data.AddDays(-28).ToString('yyyy-MM-dd')
$anteriores = @($hist | Where-Object { $_.data -lt $dataTxt -and $_.data -ge $limite })

$linhas = @(Get-Content $Resultado -Encoding UTF8 | Where-Object { $_.Trim() })
$itens = foreach ($l in $linhas) {
  $c = $l -split "`t"
  $m = $porNome[(Norm $c[0])]
  $id = if ($m) { $m.id } else { $null }
  $antes = @($anteriores | Where-Object { ($id -and $_.id -eq $id) -or (Norm $_.nome) -eq (Norm $c[0]) } | Sort-Object data)
  [pscustomobject]@{ nome = $c[0].Trim(); id = $id; assunto = $c[1].Trim(); ok = ($c[2].Trim() -eq 'ok'); motivo = $(if ($c.Count -gt 3) { $c[3].Trim() } else { '' }); antes = $antes }
}
$itens = @($itens)
$okL = @($itens | Where-Object { $_.ok }); $falhou = @($itens | Where-Object { -not $_.ok })
$rein = @($itens | Where-Object { $_.antes.Count })

function Quando($regs) { ($regs | ForEach-Object { $d = [datetime]$_.data; "$(@('seg','ter','qua','qui','sex','sáb','dom')[([int]$d.DayOfWeek + 6) % 7]) $($d.ToString('dd/MM'))" }) -join ', ' }

$r = New-Object System.Collections.Generic.List[string]
$r.Add("📩 DEDZ - Notificações no PV - $tipo ($($Data.ToString('dd/MM')))")
$r.Add("Enviadas: $($okL.Count) de $($itens.Count) · Não deu certo: $($falhou.Count) · Reincidentes: $($rein.Count)")
$r.Add('')
if ($tipo -eq 'quarta') { $r.Add('Por que esses nomes: os piores do dia: zerados ou abaixo de 50% da meta do VS de hoje, ou com a doação da semana abaixo de 50% da meta. Quem está entre 50% e 99% fica para a cobrança de vocês. Contas secundárias da liderança ficam de fora.') }
else { $r.Add('Por que esses nomes: os piores da semana: bateram a meta do VS em 3 de 6 dias ou menos, ou estão com a doação da semana abaixo de 50% da meta. Receberam o balanço da semana com os pontos de melhoria. Contas secundárias da liderança ficam de fora.') }
$r.Add('')
$r.Add("🔁 REINCIDENTES ($($rein.Count))$(if ($rein.Count) { ': já tinham sido notificados no PV nas últimas 4 semanas' })")
if ($rein.Count) {
  foreach ($i in ($rein | Sort-Object @{e = { $_.antes.Count }; Descending = $true }, nome)) { $r.Add("- $($i.nome): $($i.antes.Count + 1)ª notificação (antes: $(Quando $i.antes)). Vale uma conversa direta da liderança.") }
} else { $r.Add('- ninguém (primeira notificação de todos)') }
$r.Add('')
$r.Add("✅ RECEBERAM ($($okL.Count))")
$n = 1; foreach ($i in $okL) { $r.Add("$n. $($i.nome) - $($i.assunto)$(if ($i.antes.Count) { ' 🔁' })"); $n++ }
$r.Add('')
if ($falhou.Count) { $r.Add("❌ NÃO DEU CERTO ($($falhou.Count))"); foreach ($i in $falhou) { $r.Add("- $($i.nome) - $(if ($i.motivo) { $i.motivo } else { 'outro' })$(if ($i.antes.Count) { ' 🔁' })") } }
else { $r.Add('❌ NÃO DEU CERTO: ninguém') }

[IO.File]::WriteAllText((Join-Path $Dir 'pv_resumo.txt'), ($r -join "`n"), (New-Object Text.UTF8Encoding $false))
if (-not $NaoSalvarHistorico) {
  $hist = @($hist | Where-Object { $_.data -ne $dataTxt })   # refazer o mesmo dia substitui o registro
  foreach ($i in $itens) { $hist += [pscustomobject][ordered]@{ data = $dataTxt; tipo = $tipo; id = $i.id; nome = $i.nome; assunto = $i.assunto; recebeu = $i.ok; motivo = $i.motivo } }
  SalvarJson $histArq @($hist)
}
"resumo: $($itens.Count) pessoa(s), $($okL.Count) ok, $($falhou.Count) falhou, $($rein.Count) reincidente(s) -> $(Join-Path $Dir 'pv_resumo.txt')"
