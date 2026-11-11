# Monta o resumo das notificações no PV para o grupo da liderança e grava o histórico de envios.
# Uso: .\pv_resumo.ps1 -Resultado C:\lz\pv_resultado.tsv [-Lista C:\lz\pv_lista.tsv] [-Data 2026-11-04] [-Dir C:\lz] [-NaoSalvarHistorico]
#   pv_resultado.tsv: uma linha por pessoa da lista, na ordem: nome<TAB>ok|falhou<TAB>motivo da falha (só se falhou)
#   pv_lista.tsv (gerado pelo relatorio.ps1 junto com a lista do PV): nome<TAB>motivo com os números da semana;
#     a primeira linha é "#periodo<TAB>seg a qua 04/11".
# Saída: $Dir\pv_resumo.txt (texto exato para enviar) e $Dir\estado\pv_historico.json (um registro por envio).
# Reincidente = já recebeu notificação no PV antes desta data (últimas 4 semanas), recebida ou não.
param([Parameter(Mandatory)][string]$Resultado, [string]$Lista, [datetime]$Data = (Get-Date).AddHours(1).Date, [string]$Dir = 'C:\lz', [switch]$NaoSalvarHistorico)
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
$dataTxt = $Data.ToString('yyyy-MM-dd')
$diaSem = ([int]$Data.DayOfWeek + 6) % 7
$tipo = if ($diaSem -eq 5) { 'sábado' } else { 'quarta' }

$porNome = @{}; foreach ($mb in (LerLista "$est\membros.json")) { $porNome[(Norm $mb.nome)] = $mb }
$histArq = "$est\pv_historico.json"
$hist = @(); if (Test-Path $histArq) { $hist = @(LerLista $histArq) }
$limite = $Data.AddDays(-28).ToString('yyyy-MM-dd')
$anteriores = @($hist | Where-Object { $_.data -lt $dataTxt -and $_.data -ge $limite })

# motivos com os números da semana
if (-not $Lista) { $Lista = Join-Path $Dir 'pv_lista.tsv' }
$motivos = @{}; $reincs = @{}; $curtos = @{}; $periodo = $null
if (Test-Path $Lista) {
  foreach ($ln in (Get-Content $Lista -Encoding UTF8)) {
    $cols = $ln -split "`t"
    if ($cols[0] -eq '#periodo') { $periodo = $cols[1] }
    elseif ($cols.Count -ge 2) {
      $motivos[(Norm $cols[0])] = $cols[1]
      if ($cols.Count -ge 3) { $reincs[(Norm $cols[0])] = $cols[2].Trim() }
      if ($cols.Count -ge 4) { $curtos[(Norm $cols[0])] = $cols[3].Trim() }
    }
  }
}

$entradas = @(Get-Content $Resultado -Encoding UTF8 | Where-Object { $_.Trim() })
$itens = foreach ($ln in $entradas) {
  $cols = $ln -split "`t"
  $nm = $cols[0].Trim()
  $mb = $porNome[(Norm $nm)]
  $id = if ($mb) { $mb.id } else { $null }
  $antes = @($anteriores | Where-Object { ($id -and $_.id -eq $id) -or (Norm $_.nome) -eq (Norm $nm) } | Sort-Object data)
  $assunto = $motivos[(Norm $nm)]; if (-not $assunto) { $assunto = '(motivo não encontrado na lista)' }
  $curto = $curtos[(Norm $nm)]; if (-not $curto) { $curto = $assunto }
  [pscustomobject]@{ nome = $nm; id = $id; assunto = $assunto; curto = $curto; rein = [string]$reincs[(Norm $nm)]; ok = ($cols[1].Trim() -eq 'ok'); motivo = $(if ($cols.Count -gt 2) { $cols[2].Trim() } else { '' }); antes = $antes }
}
$itens = @($itens)
$okL = @($itens | Where-Object { $_.ok }); $falhou = @($itens | Where-Object { -not $_.ok })
# reincidente = errou a meta em 2 dias ou mais na semana (VS ou doação), calculado pelo relatorio.ps1
$rein = @($itens | Where-Object { $_.rein })

function Quando($regs) { ($regs | ForEach-Object { $d = [datetime]$_.data; "$(@('seg','ter','qua','qui','sex','sáb','dom')[([int]$d.DayOfWeek + 6) % 7]) $($d.ToString('dd/MM'))" }) -join ', ' }

$r = New-Object System.Collections.Generic.List[string]
$r.Add("📩 DEDZ - Notificações no PV - $tipo ($($Data.ToString('dd/MM')))")
$r.Add("Enviadas: $($okL.Count) de $($itens.Count) · Não deu certo: $($falhou.Count) · Reincidentes: $($rein.Count)")
if ($periodo) { $r.Add("Período: $periodo (semana até hoje)") }
$cobrarVS = $true; $arqCob = Join-Path $PSScriptRoot 'cobranca.json'
if (Test-Path $arqCob) { $cfgCob = LerJson $arqCob; if ($null -ne $cfgCob.vsNoPrivado) { $cobrarVS = [bool]$cfgCob.vsNoPrivado } }
if (-not $cobrarVS) { $r.Add('Critério: só doação abaixo de 50% da meta (VS fora do privado durante a migração). Secundárias fora.') }
elseif ($tipo -eq 'quarta') { $r.Add('Critério: piores da semana no VS (zerado ou abaixo de 50% hoje) ou na doação (abaixo de 50%). Entre 50% e 99% fica com vocês. Secundárias fora.') }
else { $r.Add('Critério: bateram o VS em 3 de 6 dias ou menos, ou doação abaixo de 50%. Receberam o balanço da semana. Secundárias fora.') }
$r.Add('')
# formato curto: uma linha por pessoa; VS dia a dia (✅/❌ e o % dos dias que falhou), doação da semana
$r.Add("✅ RECEBERAM ($($okL.Count)) · 🔁 = errou a meta em 2 dias ou mais")
if ($okL.Count) {
  foreach ($i in $okL) { $r.Add("- $($i.nome)$(if ($i.rein) { ' 🔁' }): $($i.curto)$(if ($i.antes.Count) { " · já notificado: $(Quando $i.antes)" })") }
} else { $r.Add('- ninguém') }
$r.Add('')
if ($falhou.Count) {
  $r.Add("❌ NÃO DEU CERTO ($($falhou.Count))")
  foreach ($i in $falhou) { $r.Add("- $($i.nome)$(if ($i.rein) { ' 🔁' }): $(if ($i.motivo) { $i.motivo } else { 'outro' }) · $($i.curto)") }
} else { $r.Add('❌ NÃO DEU CERTO: ninguém') }
if ($rein.Count) { $r.Add(''); $r.Add('Para os 🔁 vale uma conversa direta da liderança.') }

[IO.File]::WriteAllText((Join-Path $Dir 'pv_resumo.txt'), ($r -join "`n"), (New-Object Text.UTF8Encoding $false))
if (-not $NaoSalvarHistorico) {
  $hist = @($hist | Where-Object { $_.data -ne $dataTxt })   # refazer o mesmo dia substitui o registro
  foreach ($i in $itens) { $hist += [pscustomobject][ordered]@{ data = $dataTxt; tipo = $tipo; id = $i.id; nome = $i.nome; assunto = $i.assunto; recebeu = $i.ok; motivo = $i.motivo } }
  SalvarJson $histArq @($hist)
  # mesmas linhas para a coleção "pv" do banco da dash (aba Desempenho): mande como writes de um ArtifactData batch
  $writes = @(foreach ($i in $itens) { if ($i.id) { [ordered]@{ op = 'set'; collection = 'pv'; doc_id = "${dataTxt}__$($i.id)"; data = [ordered]@{ data = $dataTxt; tipo = $tipo; membro = $i.id; nome = $i.nome; assunto = $i.assunto; recebeu = $i.ok; motivo = $i.motivo } } } })
  [IO.File]::WriteAllText((Join-Path $Dir 'pv_batch.json'), (ConvertTo-Json -InputObject $writes -Depth 5 -Compress), (New-Object Text.UTF8Encoding $false))
}
"resumo: $($itens.Count) pessoa(s), $($okL.Count) ok, $($falhou.Count) falhou, $($rein.Count) reincidente(s) -> $(Join-Path $Dir 'pv_resumo.txt')"
