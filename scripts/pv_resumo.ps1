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
$motivos = @{}; $reincs = @{}; $periodo = $null
if (Test-Path $Lista) {
  foreach ($ln in (Get-Content $Lista -Encoding UTF8)) {
    $cols = $ln -split "`t"
    if ($cols[0] -eq '#periodo') { $periodo = $cols[1] }
    elseif ($cols.Count -ge 2) { $motivos[(Norm $cols[0])] = $cols[1]; if ($cols.Count -ge 3) { $reincs[(Norm $cols[0])] = $cols[2].Trim() } }
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
  [pscustomobject]@{ nome = $nm; id = $id; assunto = $assunto; rein = [string]$reincs[(Norm $nm)]; ok = ($cols[1].Trim() -eq 'ok'); motivo = $(if ($cols.Count -gt 2) { $cols[2].Trim() } else { '' }); antes = $antes }
}
$itens = @($itens)
$okL = @($itens | Where-Object { $_.ok }); $falhou = @($itens | Where-Object { -not $_.ok })
# reincidente = errou a meta em 2 dias ou mais na semana (VS ou doação), calculado pelo relatorio.ps1
$rein = @($itens | Where-Object { $_.rein })

function Quando($regs) { ($regs | ForEach-Object { $d = [datetime]$_.data; "$(@('seg','ter','qua','qui','sex','sáb','dom')[([int]$d.DayOfWeek + 6) % 7]) $($d.ToString('dd/MM'))" }) -join ', ' }

$r = New-Object System.Collections.Generic.List[string]
$r.Add("📩 DEDZ - Notificações no PV - $tipo ($($Data.ToString('dd/MM')))")
$r.Add("Enviadas: $($okL.Count) de $($itens.Count) · Não deu certo: $($falhou.Count) · Reincidentes: $($rein.Count)")
if ($periodo) { $r.Add("Período analisado: $periodo (VS e doação somam a semana inteira até hoje, não só o dia)") }
$r.Add('')
if ($tipo -eq 'quarta') { $r.Add('Por que esses nomes: os piores da semana até hoje: abaixo de 50% da meta do VS de hoje (ou zerados), ou com a doação da semana abaixo de 50% da meta. Quem está entre 50% e 99% fica para a cobrança de vocês. Contas secundárias da liderança ficam de fora.') }
else { $r.Add('Por que esses nomes: os piores da semana: bateram a meta do VS em 3 de 6 dias ou menos, ou estão com a doação da semana abaixo de 50% da meta. Receberam o balanço da semana com os pontos de melhoria. Contas secundárias da liderança ficam de fora.') }
$r.Add('')
$r.Add("✅ RECEBERAM ($($okL.Count)): $(if ($okL.Count) { ($okL | ForEach-Object { "$($_.nome)$(if ($_.rein) { ' 🔁' })" }) -join ', ' } else { 'ninguém' })")
$r.Add('')
$r.Add("🔁 REINCIDENTES NA SEMANA ($($rein.Count))$(if ($rein.Count) { ': erraram a meta em 2 dias ou mais (VS abaixo da meta ou doação abaixo de 20 mil no dia)' })")
if ($rein.Count) {
  foreach ($i in $rein) {
    $doaSem = ($i.assunto -split ' · ' | Where-Object { $_ -like 'doação *' }) -join ''
    $r.Add("- $($i.nome): $($i.rein)$(if ($doaSem) { " · $doaSem" })$(if ($i.antes.Count) { ". Já notificado no PV: $(Quando $i.antes)" })")
  }
  $r.Add('Para os reincidentes vale uma conversa direta da liderança.')
} else { $r.Add('- ninguém errou a meta em 2 dias ou mais') }
$outros = @($itens | Where-Object { -not $_.rein })
if ($outros.Count) { $r.Add(''); $r.Add("📌 OUTROS NOTIFICADOS ($($outros.Count))"); foreach ($i in $outros) { $r.Add("- $($i.nome): $($i.assunto)") } }
$r.Add('')
if ($falhou.Count) {
  $r.Add("❌ NÃO DEU CERTO ($($falhou.Count))")
  foreach ($i in $falhou) { $r.Add("- $($i.nome)$(if ($i.rein) { ' 🔁' }) - $(if ($i.motivo) { $i.motivo } else { 'outro' }) (motivo da notificação: $($i.assunto))") }
} else { $r.Add('❌ NÃO DEU CERTO: ninguém') }

[IO.File]::WriteAllText((Join-Path $Dir 'pv_resumo.txt'), ($r -join "`n"), (New-Object Text.UTF8Encoding $false))
if (-not $NaoSalvarHistorico) {
  $hist = @($hist | Where-Object { $_.data -ne $dataTxt })   # refazer o mesmo dia substitui o registro
  foreach ($i in $itens) { $hist += [pscustomobject][ordered]@{ data = $dataTxt; tipo = $tipo; id = $i.id; nome = $i.nome; assunto = $i.assunto; recebeu = $i.ok; motivo = $i.motivo } }
  SalvarJson $histArq @($hist)
}
"resumo: $($itens.Count) pessoa(s), $($okL.Count) ok, $($falhou.Count) falhou, $($rein.Count) reincidente(s) -> $(Join-Path $Dir 'pv_resumo.txt')"
