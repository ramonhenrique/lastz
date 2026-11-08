# Monta os relatórios a partir do espelho local (C:\lz\estado):
#   relatorio_geral.txt      grupo dos membros (DEDZ): só números, sem nomes e sem link da dash
#   relatorio_lideranca.txt  grupo da liderança (DEDZ R4, R5 e Agregados): nomes, cobrança, alertas e insights
#
# Turnos:
#   meio        (11:01) meio do dia do jogo: ritmo do VS de hoje, lista de cobrança, quem parou de doar
#   alerta      (19:01) começa o combo de pontuação: alerta incisivo sobre o VS de hoje e a projeção da doação
#                       (sem os dias anteriores); no domingo, só a doação
#   fechamento  (23:01) o dia acabou de fechar: resultado final, reincidentes, destaques, projeção, amanhã
#                       (no sábado e no domingo inclui o fechamento da semana)
# Uso: .\relatorio.ps1 [-Turno meio|alerta|fechamento] [-Agora 'AAAA-MM-DD HH:mm'] [-Dir C:\lz]
# Duelo (opcional): $Dir\duelo.json  {"placar":"0:1","nos":48,"eles":52,"adversario":"[VVD]"} lido no jogo nesta execução.
param([ValidateSet('meio','alerta','fechamento')][string]$Turno, [datetime]$Agora = (Get-Date), [string]$Dir = 'C:\lz', [switch]$NaoSalvarHistorico)
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
if (-not $Turno) { $Turno = if ($Agora.Hour -ge 5 -and $Agora.Hour -lt 17) { 'meio' } elseif ($Agora.Hour -ge 17 -and $Agora.Hour -lt 23) { 'alerta' } else { 'fechamento' } }

# ---------- calendário (o dia do jogo vira às 23:00 de Brasília) ----------
$jogoData = $Agora.AddHours(1).Date
$refData = if ($Turno -eq 'fechamento') { $jogoData.AddDays(-1) } else { $jogoData }   # dia que o relatório analisa
$refDia = ([int]$refData.DayOfWeek + 6) % 7                                           # 0 = segunda ... 6 = domingo
$refSemana = $refData.AddDays(-$refDia).ToString('yyyy-MM-dd')
$nomesDia = 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'
$curtos = 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'
$temas = 'Radar + Veículo', 'Construção', 'Pesquisa', 'Heróis', 'Exército', 'Combate'
$metas = 4.5e6, 5e6, 3.3e6, 6e6, 7e6, 6e6
$diasDoa = $refDia + 1
$metaDoa = 20000 * $diasDoa
$metaSemanaDoa = 140000
$emAndamento = $Turno -ne 'fechamento'                                                   # meio (11:01) e alerta (19:01): o dia ainda está correndo
$diasFechados = @(0..5 | Where-Object { if ($Turno -eq 'fechamento') { $_ -le $refDia } else { $_ -lt $refDia } })
$vsHoje = if ($emAndamento -and $refDia -le 5) { $refDia } else { -1 }            # VS em andamento (só no meio)
$vsFechou = if ($Turno -eq 'fechamento' -and $refDia -le 5) { $refDia } else { -1 }    # VS que acabou de fechar
$fimDeSemana = $Turno -eq 'fechamento' -and $refDia -ge 5

# ---------- dados ----------
$cadastro = @{}; foreach ($mb in (LerLista "$est\membros.json")) { if (-not $mb.saiu) { $cadastro[$mb.id] = $mb } }
$todosRegs = @(LerLista "$est\registros.json")
$regsSemana = @($todosRegs | Where-Object { $_.semana -eq $refSemana -and $cadastro.ContainsKey($_.membro) })
$total = $regsSemana.Count
$semanaPassada = $refData.AddDays(-$refDia - 7).ToString('yyyy-MM-dd')
$regsPassada = @{}; foreach ($rp in $todosRegs) { if ($rp.semana -eq $semanaPassada) { $regsPassada[$rp.membro] = $rp } }
$semanasAnteriores = @($todosRegs | Where-Object { $_.semana -lt $refSemana } | ForEach-Object { $_.semana } | Sort-Object -Unique -Descending | Select-Object -First 4)

function EmMi($v) { if (-not $v) { return '0' }; ('{0:0.00}' -f ($v / 1e6)).Replace('.', ',') + 'Mi' }
function MetaMi($i) { ('{0:0.#}' -f ($metas[$i] / 1e6)).Replace('.', ',') + 'Mi' }
function EmMil($v) { if ($v -ge 1e6) { ('{0:0.00}' -f ($v / 1e6)).Replace('.', ',') + 'M' } else { [string][math]::Round($v / 1000) + ' mil' } }
function Pct($a, $b) { if (-not $b) { return '-' }; [string][math]::Round(100 * $a / $b) + '%' }
function Juntar($lista) { (@($lista) | Sort-Object { $_.ToLowerInvariant() }) -join ', ' }
function Num($v) { if ($null -eq $v) { 0 } else { [double]$v } }

# contas secundárias da liderança (scripts\secundarias.json): ficam fora só da cobrança no privado
$secundarias = @{}
$arqSec = Join-Path $PSScriptRoot 'secundarias.json'
if (Test-Path $arqSec) { foreach ($pr in (LerJson $arqSec).PSObject.Properties) { if ($pr.Name -notlike '_*') { $secundarias[$pr.Name] = $pr.Value } } }

# ---------- por membro ----------
$pessoas = foreach ($reg in $regsSemana) {
  $dd = @($reg.doacaoDias); while ($dd.Count -lt 7) { $dd += $null }
  # doação acumulada no dia analisado (permite refazer relatórios de dias anteriores); sem leitura no dia, usa a última
  $doaAtual = if ($null -ne $dd[$refDia]) { [double]$dd[$refDia] } else { Num $reg.doacao }
  # doação no dia de referência e no dia anterior (leituras acumuladas por dia)
  $antes = $null; for ($k = $refDia - 1; $k -ge 0; $k--) { if ($null -ne $dd[$k]) { $antes = [double]$dd[$k]; break } }
  if ($null -eq $antes -and $refDia -eq 0) { $antes = 0 }
  $doaNoDia = if ($null -ne $dd[$refDia] -and $null -ne $antes) { [double]$dd[$refDia] - $antes } else { $null }
  # quem entrou nesta semana só é cobrado a partir do dia da entrada (VS e doação)
  $ini = 0; $ent = [string]$cadastro[$reg.membro].entrou
  if ($ent -and $ent -gt $refSemana) { $ini = [math]::Min([int]([datetime]$ent - [datetime]$refSemana).TotalDays, 6) }
  $metaDoaP = 20000 * [math]::Max($diasDoa - $ini, 1)
  $falhas = @($diasFechados | Where-Object { $_ -ge $ini -and $null -ne $reg.vs[$_] -and $reg.vs[$_] -lt $metas[$_] })
  $zerou = @($diasFechados | Where-Object { $_ -ge $ini -and $reg.vs[$_] -eq 0 })
  [pscustomobject]@{
    id = $reg.membro; nome = [string]$cadastro[$reg.membro].nome; reg = $reg
    ini = $ini; metaDoa = $metaDoaP; metaSem = 20000 * (7 - $ini)
    doa = $doaAtual; pctDoa = $doaAtual / $metaDoaP; doaNoDia = $doaNoDia
    falhas = $falhas; zerou = $zerou
    vsHoje = $(if ($vsHoje -ge 0) { $reg.vs[$vsHoje] } else { $null })
    vsFechou = $(if ($vsFechou -ge 0) { $reg.vs[$vsFechou] } else { $null })
    projDoa = $doaAtual / $diasDoa * 7
  }
}

function Reincidencia($id) {
  $n = 0
  foreach ($sem in $semanasAnteriores) {
    $x = $todosRegs | Where-Object { $_.semana -eq $sem -and $_.membro -eq $id } | Select-Object -First 1
    if (-not $x) { continue }
    $mv = @(0..5 | Where-Object { $null -ne $x.vs[$_] -and $x.vs[$_] -lt $metas[$_] }).Count
    if ($mv -ge 3 -or ($null -ne $x.doacao -and $x.doacao -lt 70000)) { $n++ }
  }
  $n
}

function Alertas {
  $saida = foreach ($p in $pessoas) {
    $mot = @(); $pts = 0
    if ($p.zerou.Count) { $mot += "zerou o VS em $($p.zerou.Count) dia(s) ($(($p.zerou | ForEach-Object { $curtos[$_] }) -join ', '))"; $pts += 2 * $p.zerou.Count }
    if ($p.falhas.Count -ge 2) { $mot += "abaixo da meta do VS em $($p.falhas.Count) de $($diasFechados.Count) dias"; $pts += $p.falhas.Count }
    elseif ($p.falhas.Count -eq 1 -and -not $p.zerou.Count -and $p.pctDoa -lt 0.5) { $mot += "abaixo da meta do VS na $($nomesDia[$p.falhas[0]])"; $pts += 1 }
    if ($p.pctDoa -lt 0.25) { $mot += "doação muito baixa ($(EmMil $p.doa) de $(EmMil $p.metaDoa))"; $pts += 2 }
    elseif ($p.pctDoa -lt 0.5 -and $p.falhas.Count) { $mot += "doação baixa ($(EmMil $p.doa) de $(EmMil $p.metaDoa))"; $pts += 1 }
    $rein = Reincidencia $p.id
    if ($rein -and $mot.Count) { $mot += "também abaixo em $rein semana(s) anterior(es)"; $pts += $rein }
    if ($pts -ge 2) { [pscustomobject]@{ nome = $p.nome; pts = $pts; mot = $mot -join '; ' } }
  }
  @($saida | Sort-Object @{e = 'pts'; Descending = $true }, nome)
}

# ---------- duelo e histórico de ritmo ----------
$duelo = $null
if (Test-Path "$Dir\duelo.json") { try { $duelo = LerJson "$Dir\duelo.json" } catch { $duelo = $null } }
$histArq = "$est\historico.json"
$hist = @(); if (Test-Path $histArq) { $hist = @(LerLista $histArq) }
function OkVS($i) { @($regsSemana | Where-Object { $_.vs[$i] -ge $metas[$i] }).Count }

$titulo = "$($nomesDia[$refDia].Substring(0,1).ToUpper())$($nomesDia[$refDia].Substring(1)) ($($refData.ToString('dd/MM')))"
$okDoa = @($pessoas | Where-Object { $_.doa -ge $_.metaDoa }).Count
$somaDoa = ($pessoas | Measure-Object doa -Sum).Sum
$alertas = Alertas

$geral = New-Object System.Collections.Generic.List[string]
$lid = New-Object System.Collections.Generic.List[string]

# ---------- análise e previsão para o grupo geral (sem nomes) ----------
# Dias de doação já corridos: no meio do dia conta a fração de hoje (o dia do jogo começa às 23:00 de Brasília).
$diasCorridos = if ($emAndamento) { $refDia + [math]::Min([math]::Max(($Agora.AddHours(1) - $refData).TotalHours / 24, 0.1), 1) } else { $refDia + 1 }
$metaTimeSemana = $metaSemanaDoa * [math]::Max($total, 1)
$projTime = if ($diasCorridos -gt 0) { $somaDoa / $diasCorridos * 7 } else { 0 }
$projPessoa = @($pessoas | ForEach-Object { $_.doa / $diasCorridos * 7 })
$vaoBater = @($projPessoa | Where-Object { $_ -ge $metaSemanaDoa }).Count
$abaixo100 = @($projPessoa | Where-Object { $_ -lt 100000 }).Count
$abaixoMetadeDoa = @($pessoas | Where-Object { $_.pctDoa -lt 0.5 }).Count
$pctNaMeta = $okDoa / [math]::Max($total, 1)

# ---------- cobrança incisiva: zerados e abaixo de 50% no VS do dia ----------
$diaCob = if ($vsHoje -ge 0) { $vsHoje } else { $vsFechou }        # dia do VS cobrado (-1 = nenhum)
function ValorCob($p) { if ($vsHoje -ge 0) { $p.vsHoje } else { $p.vsFechou } }
$cobZerados = @(); $cobMetade = @()
if ($diaCob -ge 0) {
  $cobZerados = @($pessoas | Where-Object { -not (ValorCob $_) })
  $cobMetade = @($pessoas | Where-Object { (ValorCob $_) -gt 0 -and (ValorCob $_) -lt $metas[$diaCob] / 2 } | Sort-Object { ValorCob $_ })
}
function TempoFalta { $min = [math]::Max([math]::Round(($refData.AddHours(23) - $Agora).TotalMinutes), 0); $h = [math]::Floor($min / 60); $m = $min % 60; if ($h -ge 1 -and $m -lt 10) { "$h hora$(if ($h -gt 1) { 's' })" } elseif ($h -ge 1) { "$h h e $m min" } else { "$m minutos" } }
function Qtd($n, $um, $varios) { if ($n -eq 1) { "1 $um" } else { "$n $varios" } }
function ArtigoDia($i) { if ($i -eq 5) { "o $($nomesDia[$i])" } else { "a $($nomesDia[$i])" } }

function CobrancaGeral {
  $l = New-Object System.Collections.Generic.List[string]
  if ($diaCob -lt 0 -or ($cobZerados.Count + $cobMetade.Count) -eq 0) { return $l }
  $baixa = if ($metas[$diaCob] -le 4.5e6) { ', e é um dia de meta baixa' } else { '' }
  $l.Add('COBRANÇA DO DIA')
  if ($vsHoje -ge 0) {
    $l.Add("Hoje $(Qtd $cobZerados.Count 'membro ainda está' 'membros ainda estão') ZERADOS no VS e $(Qtd $cobMetade.Count 'não chegou' 'não chegaram') nem à metade da meta de $(MetaMi $diaCob) ($(EmMi ($metas[$diaCob] / 2)))$baixa.")
  } else {
    $l.Add("$(Qtd $cobZerados.Count 'membro fechou' 'membros fecharam') $(ArtigoDia $diaCob) ZERADO$(if ($cobZerados.Count -ne 1) { 'S' }) no VS e $(Qtd $cobMetade.Count 'ficou' 'ficaram') abaixo da metade da meta de $(MetaMi $diaCob) ($(EmMi ($metas[$diaCob] / 2)))$baixa.")
  }
  $l.Add('Zerar o VS não é falta de recurso, é falta de participação. Cada zero tira pontos do duelo e coloca a aliança inteira em desvantagem.')
  if ($vsHoje -ge 0) { $l.Add('A meta é para todos. Quem estiver zerado ou abaixo da metade até o fechamento vai ser chamado no privado pela liderança.') }
  else { $l.Add('A meta é para todos. Quem ficou zerado ou abaixo da metade vai ser chamado no privado pela liderança.') }
  $repet = @($pessoas | Where-Object { $_.falhas.Count -ge 2 }).Count
  if ($repet) { $l.Add("Quem fica abaixo da meta vários dias seguidos está sendo acompanhado ($repet nesta semana). Aliança forte é aliança em que todo mundo joga junto.") }
  $l
}

function MensagensPrivado {
  $l = New-Object System.Collections.Generic.List[string]
  if ($diaCob -lt 0) { return $l }
  $alvo = @(@($cobZerados) + @($cobMetade) | Where-Object { -not $secundarias.ContainsKey($_.id) })   # contas secundárias da liderança não recebem cobrança no privado
  foreach ($p in $alvo) { $l.Add("> $(TextoPrivado $p)") }
  $l
}

# Texto da cobrança no privado de uma pessoa zerada ou abaixo de 50% no VS do dia.
function TextoPrivado($p) {
  $prazo = if ($Turno -eq 'alerta') { 'O combo de pontuação está ativo até as 23h: é a hora de recuperar.' } else { 'Ainda dá tempo até as 23h.' }
  $amanhaVS = $diaCob + 1
  & {
    $v = ValorCob $p
    $diasRuins = $p.falhas.Count + $(if ($vsHoje -ge 0) { 1 } else { 0 })
    if ($diasRuins -ge 2) {
      $txt = if ($vsHoje -ge 0) { "$($p.nome), já são $diasRuins dias abaixo da meta nesta semana, contando hoje até agora ($(EmMi $v) de $(MetaMi $diaCob))." }
             else { "$($p.nome), é o $($diasRuins)º dia abaixo da meta nesta semana ($(ArtigoDia $diaCob) fechou com $(EmMi $v) de $(MetaMi $diaCob))." }
      $txt += ' A aliança precisa de quem participa. Se não der para acompanhar, conversa com a gente. Contamos com você nos próximos dias para virar esse jogo.'
    } elseif (-not $v) {
      $txt = if ($vsHoje -ge 0) { "Fala, $($p.nome). Você está zerado no VS de hoje (meta $(MetaMi $diaCob)). Não dá para seguir assim: cada zero pesa no duelo da aliança. Consegue pontuar até as 23h? $(if ($Turno -eq 'alerta') { 'O combo de pontuação já está ativo. ' })Se tiver algum problema, me fala que a gente ajuda." }
             else { "Fala, $($p.nome). Você fechou $(ArtigoDia $diaCob) zerado no VS (meta $(MetaMi $diaCob)). Cada zero pesa no duelo da aliança.$(if ($amanhaVS -le 5) { " Amanhã o tema é $($temas[$amanhaVS]), meta $(MetaMi $amanhaVS): conto com você." }) Se tiver algum problema, me fala que a gente ajuda." }
    } else {
      $txt = if ($vsHoje -ge 0) { "$($p.nome), você está com $(EmMi $v) no VS de hoje, menos da metade da meta de $(MetaMi $diaCob). $prazo Precisamos que você chegue na meta hoje." }
             else { "$($p.nome), você fechou $(ArtigoDia $diaCob) com $(EmMi $v) no VS, menos da metade da meta de $(MetaMi $diaCob).$(if ($amanhaVS -le 5) { " Amanhã o tema é $($temas[$amanhaVS]) (meta $(MetaMi $amanhaVS)): precisamos que você chegue na meta." })" }
    }
    if ($p.pctDoa -lt 0.5) { $txt += " Sua doação também está baixa: $(EmMil $p.doa) de $(EmMil $p.metaDoa) até agora. Dá para doar com diamantes: 30 por dia já fazem diferença." }
    $txt
  }
}

# ---------- lista do PV (envio no chat privado do jogo, só com o "pode enviar" do usuário) ----------
# Quarta no alerta das 19:01: puxão de orelha do dia. Sábado no fechamento das 23:01: balanço da semana.
# Só os piores (até 10): fora quem está entre 50% e 99% da meta e as contas secundárias da liderança.
$diaPV = if ($Turno -eq 'alerta' -and $refDia -eq 2) { 'quarta' } elseif ($Turno -eq 'fechamento' -and $refDia -eq 5) { 'sabado' } else { $null }

function JuntarDias($ds) { $n = @($ds | ForEach-Object { $curtos[$_] }); if ($n.Count -le 1) { $n -join '' } else { ($n[0..($n.Count - 2)] -join ', ') + ' e ' + $n[-1] } }

function TextoDoacaoPV($p) {
  "$($p.nome), sua doação da semana está em $(EmMil $p.doa) de $(EmMil $p.metaDoa) até hoje. Sem doação a loja da aliança não é reabastecida. Dá para doar com diamantes: 30 por dia já fazem diferença. Contamos com você para colocar em dia até domingo."
}

function TextoSemanaPV($p, $diasVS) {
  $bat = @($diasVS | Where-Object { $p.reg.vs[$_] -ge $metas[$_] })
  $abx = @($diasVS | Where-Object { $p.reg.vs[$_] -lt $metas[$_] })
  $zer = @($diasVS | Where-Object { -not $p.reg.vs[$_] })
  $t = New-Object System.Collections.Generic.List[string]
  $t.Add("$($p.nome), o VS da semana fechou e quero te mostrar seu resultado:")
  $linhaVS = "- VS: bateu a meta em $($bat.Count) de $($diasVS.Count) dias$(if ($p.ini -gt 0) { ' desde que entrou' })."
  if ($abx.Count) { $linhaVS += " Ficou abaixo na $(JuntarDias $abx)" + $(if ($zer.Count) { ", e zerou na $(JuntarDias $zer)." } else { '.' }) }
  $t.Add($linhaVS)
  $pior = $null
  if ($abx.Count) {
    $pior = $abx | Sort-Object { (Num $p.reg.vs[$_]) / $metas[$_] } | Select-Object -First 1
    $t.Add("- Pior dia: $($nomesDia[$pior]) ($($temas[$pior])), com $(EmMi (Num $p.reg.vs[$pior])) de $(MetaMi $pior).")
  }
  # a doação fecha no domingo às 23h; escrito assim porque a lista é montada no sábado e enviada no sábado ou no domingo
  $faltaSem = [math]::Max($p.metaSem - $p.doa, 0)
  $desde = if ($p.ini -gt 0) { "desde a sua entrada na $($curtos[$p.ini])" } else { "até $($nomesDia[$refDia])" }
  $t.Add("- Doação: $(EmMil $p.doa) de $(EmMil $p.metaDoa) $desde ($(Pct $p.doa $p.metaDoa)).$(if ($faltaSem -gt 0) { " Para fechar os $(EmMil $p.metaSem) da semana, faltam $(EmMil $faltaSem) até domingo às 23h." } else { ' Meta da semana batida, obrigado!' })")
  $t.Add('')
  $vsBom = $abx.Count -le 1; $doaBoa = $p.doa -ge $p.metaDoa
  if ($vsBom -and -not $doaBoa) { $t.Add("Seu VS foi bom ($($bat.Count) de $($diasVS.Count) dias na meta). O ponto agora é a doação.") }
  elseif ($doaBoa -and -not $vsBom) { $t.Add('Sua doação está em dia, obrigado. O foco é o VS.') }
  $t.Add('Pontos de melhoria:')
  if ($zer.Count) { $t.Add('- Entre no VS todo dia, mesmo que seja para fazer o básico. Dia zerado não ajuda a aliança.') }
  $altos = @($abx | Where-Object { $metas[$_] -ge 6e6 })
  if ($altos.Count) { $t.Add('- Guarde aceleradores e recursos para os dias de meta alta (Heróis, Exército e Combate) e use no combo, das 19h às 23h.') }
  if ($null -ne $pior -and $metas[$pior] -lt 6e6) { $t.Add("- No tema de $($temas[$pior]) você ficou mais longe da meta: planeje os recursos desse dia com antecedência.") }
  if ($abx.Count -and -not $zer.Count -and -not $altos.Count -and ($null -eq $pior -or $metas[$pior] -ge 6e6)) { $t.Add('- Use o combo, das 19h às 23h, para fechar a meta nos dias em que estiver perto.') }
  if (-not $doaBoa) { $t.Add('- Doe todo dia. Não dependa só da recarga: 30 diamantes por dia já fazem diferença.') }
  $t.Add('')
  $t.Add('Contamos com você na próxima semana para virar esse jogo.')
  $t -join "`n"
}

# Motivo da notificação com os números da semana (segunda até o dia analisado), para o resumo da liderança.
function MotivoPV($p) {
  $partes = @()
  $dias = @(0..[math]::Min($refDia, 5) | Where-Object { $_ -ge $p.ini -and $null -ne $p.reg.vs[$_] })
  $abx = @($dias | Where-Object { (Num $p.reg.vs[$_]) -lt $metas[$_] })
  $zer = @($dias | Where-Object { -not (Num $p.reg.vs[$_]) })
  if ($abx.Count) {
    $txt = "VS abaixo da meta em $($abx.Count) de $($dias.Count) dias ($(JuntarDias $abx))"
    if ($zer.Count) { $txt += ", zerou na $(JuntarDias $zer)" }
    if ($vsHoje -ge 0 -and $abx -contains $vsHoje) { $txt += "; hoje $(EmMi (Num $p.vsHoje)) de $(MetaMi $vsHoje)" }
    $partes += $txt
  }
  if ($p.pctDoa -lt 0.5) { $partes += "doação $(EmMil $p.doa) de $(EmMil $p.metaDoa) $(if ($p.ini -gt 0) { "desde a entrada ($($curtos[$p.ini]))" } else { 'na semana' }) ($(Pct $p.doa $p.metaDoa))" }
  if (-not $partes.Count) { $partes += "VS e doação abaixo do esperado na semana" }
  $partes -join ' · '
}

# Reincidência na semana (segunda até o dia analisado, contando hoje): metas não cumpridas em 2 dias ou mais.
# VS: dias abaixo da meta. Doação: dias em que doou menos de 20 mil (a doação fica acumulada por dia em doacaoDias).
function ReincPV($p) {
  $dd = @($p.reg.doacaoDias); while ($dd.Count -lt 7) { $dd += $null }
  $prev = 0; $doaBaixa = @()
  for ($k = $p.ini; $k -le $refDia; $k++) {
    $cur = if ($null -ne $dd[$k]) { [double]$dd[$k] } elseif ($k -eq $refDia) { [double]$p.doa } else { $prev }
    if (($cur - $prev) -lt 20000) { $doaBaixa += $k }
    $prev = $cur
  }
  $vsAbx = @(0..[math]::Min($refDia, 5) | Where-Object { $_ -ge $p.ini -and $null -ne $p.reg.vs[$_] -and (Num $p.reg.vs[$_]) -lt $metas[$_] })
  $partes = @()
  if ($vsAbx.Count -ge 2) { $partes += "VS abaixo da meta em $($vsAbx.Count) dias ($(JuntarDias $vsAbx))" }
  if ($doaBaixa.Count -ge 2) { $partes += "doou menos de 20 mil em $($doaBaixa.Count) dias ($(JuntarDias $doaBaixa))" }
  $partes -join ' · '
}

# Linha curta para o resumo da liderança: VS dia a dia (✅/❌ e o % dos dias que falhou) e a doação da semana.
function CompactoPV($p) {
  $partes = @()
  $dias = @(0..[math]::Min($refDia, 5) | Where-Object { $_ -ge $p.ini -and $null -ne $p.reg.vs[$_] })
  $falhos = @($dias | Where-Object { (Num $p.reg.vs[$_]) -lt $metas[$_] })
  if ($falhos.Count) {
    $icones = ($dias | ForEach-Object { if ((Num $p.reg.vs[$_]) -ge $metas[$_]) { '✅' } else { '❌' } }) -join ''
    $pcts = ($falhos | ForEach-Object { "$($curtos[$_]) $([math]::Round(100 * (Num $p.reg.vs[$_]) / $metas[$_]))%" }) -join ' · '
    $partes += "VS $icones ($pcts)"
  }
  $rein = ReincPV $p
  if ($p.pctDoa -lt 0.5 -or $rein -like '*doou menos*') { $partes += "Doação $([math]::Round($p.doa / 1000))/$([math]::Round($p.metaDoa / 1000)) mil ($(Pct $p.doa $p.metaDoa))" }
  if (-not $partes.Count) { $partes += 'abaixo do esperado na semana' }
  $partes -join ' · '
}

function ListaPV {
  $itens = @()
  if ($diaPV -eq 'quarta') {
    foreach ($p in $pessoas) {
      if ($secundarias.ContainsKey($p.id) -or $p.ini -ge $refDia) { continue }   # quem entrou hoje não é cobrado
      $v = Num $p.vsHoje; $mt = $metas[$vsHoje]
      $vsRuim = $v -lt $mt / 2; $doaRuim = $p.pctDoa -lt 0.5
      if (-not $vsRuim -and -not $doaRuim) { continue }
      $s = 0
      if (-not $v) { $s += 4 } elseif ($v -lt $mt / 4) { $s += 3 } elseif ($vsRuim) { $s += 2 }
      if ($p.pctDoa -lt 0.25) { $s += 2 } elseif ($doaRuim) { $s += 1 }
      $s += $p.falhas.Count
      $txt = if ($vsRuim) { TextoPrivado $p } else { TextoDoacaoPV $p }
      $itens += [pscustomobject]@{ nome = $p.nome; s = $s; txt = $txt; mot = (MotivoPV $p); rein = (ReincPV $p); curto = (CompactoPV $p) }
    }
  } elseif ($diaPV -eq 'sabado') {
    $diasVS = @(0..5 | Where-Object { $d = $_; @($regsSemana | Where-Object { $null -ne $_.vs[$d] }).Count })
    foreach ($p in $pessoas) {
      if ($secundarias.ContainsKey($p.id) -or $p.ini -ge $refDia) { continue }   # quem entrou hoje não é cobrado
      $dvs = @($diasVS | Where-Object { $_ -ge $p.ini })                          # só os dias desde a entrada
      $bat = @($dvs | Where-Object { $p.reg.vs[$_] -ge $metas[$_] }).Count
      $zer = @($dvs | Where-Object { -not $p.reg.vs[$_] }).Count
      if ($bat -gt [math]::Floor($dvs.Count / 2) -and $p.pctDoa -ge 0.5) { continue }   # metade dos dias ou menos, ou doação abaixo de 50%
      $s = ($dvs.Count - $bat) + 2 * $zer + $(if ($p.pctDoa -lt 0.25) { 3 } elseif ($p.pctDoa -lt 0.5) { 2 } else { 0 })
      $itens += [pscustomobject]@{ nome = $p.nome; s = $s; txt = (TextoSemanaPV $p $dvs); mot = (MotivoPV $p); rein = (ReincPV $p); curto = (CompactoPV $p) }
    }
  }
  @($itens | Sort-Object @{e = 's'; Descending = $true }, nome | Select-Object -First 10)
}

function AnaliseGeral {
  $l = New-Object System.Collections.Generic.List[string]
  $pctProj = $projTime / $metaTimeSemana
  $nivel = if ($pctNaMeta -lt 0.6 -or $pctProj -lt 0.8) { 'CRÍTICO' } elseif ($pctNaMeta -lt 0.8 -or $pctProj -lt 0.95) { 'ATENÇÃO' } else { 'NO CAMINHO' }
  $l.Add("ANÁLISE DA DOAÇÃO: $nivel")
  $l.Add("- $okDoa de $total ($(Pct $okDoa $total)) estão em dia com a meta. $($total - $okDoa) estão atrasados$(if ($abaixoMetadeDoa) { ", e $abaixoMetadeDoa não chegaram nem à metade" }).")
  $l.Add("- Previsão no ritmo atual: a aliança fecha a semana com ~$(EmMil $projTime) de $(EmMil $metaTimeSemana) ($(Pct $projTime $metaTimeSemana)).")
  $l.Add("- Só $vaoBater de $total chegam aos 140 mil nesse ritmo; $abaixo100 ficam abaixo de 100 mil.")
  if ($nivel -ne 'NO CAMINHO') {
    if ($pctProj -lt 1) {
      $falta = [math]::Max($metaTimeSemana - $somaDoa, 0); $diasRest = [math]::Max(7 - $diasCorridos, 0.5)
      $l.Add("- Para fechar a meta, a aliança precisa doar ~$(EmMil ($falta / $diasRest)) $(if ($refDia -eq 6) { 'até o fim de hoje' } else { 'por dia até domingo' }), contra ~$(EmMil ($somaDoa / $diasCorridos)) por dia até agora.")
    } else {
      $l.Add("- O total só está acima porque uma parte doa bem mais que a meta. Isso não cobre os $($total - $okDoa) atrasados: a meta de 20 mil por dia vale para cada um.")
    }
    $l.Add('- Sem doação a loja da aliança não é reabastecida, e todo mundo perde. Quem está atrasado, coloque em dia hoje.')
    $l.Add('- Dica: não dependa só da recarga. Dá para doar também com diamantes: só 30 diamantes por dia já fazem muita diferença.')
  }

  $dias = @($diasFechados | Where-Object { $d = $_; @($regsSemana | Where-Object { $null -ne $_.vs[$d] }).Count })
  if ($dias.Count -or $vsHoje -ge 0) {
    $l.Add('')
    $pcts = @($dias | ForEach-Object { (OkVS $_) / [math]::Max($total, 1) })
    $media = if ($pcts.Count) { ($pcts | Measure-Object -Average).Average } else { $null }
    $nivelVS = if ($null -eq $media) { $null } elseif ($media -lt 0.7) { 'CRÍTICO' } elseif ($media -lt 0.85) { 'ATENÇÃO' } else { 'BOM' }
    $l.Add("ANÁLISE DO VS$(if ($nivelVS) { ": $nivelVS" })")
    if ($pcts.Count) {
      $l.Add("- Média da semana: $([math]::Round(100 * $media))% batem a meta do dia ($(($dias | ForEach-Object { "$($curtos[$_]) $(Pct (OkVS $_) $total)" }) -join ' · ')).")
      $repet = @($pessoas | Where-Object { $_.falhas.Count -ge 2 }).Count
      if ($repet) { $l.Add("- $repet membros já ficaram abaixo da meta em 2 dias ou mais. Isso pesa no duelo.") }
      if ($pcts.Count -ge 2 -and $pcts[-1] -lt $pcts[0] - 0.05) { $l.Add("- A adesão caiu de $([math]::Round(100 * $pcts[0]))% na $($nomesDia[$dias[0]]) para $([math]::Round(100 * $pcts[-1]))% na $($nomesDia[$dias[-1]]).") }
    }
    if ($vsHoje -ge 0) {
      $ok = OkVS $vsHoje; $meio = @($pessoas | Where-Object { $_.vsHoje -ge $metas[$vsHoje] / 2 -and $_.vsHoje -lt $metas[$vsHoje] }).Count
      $l.Add("- Previsão para hoje: de $ok a $($ok + $meio) de $total devem bater ($ok já bateram e $meio passaram da metade). $(@($pessoas | Where-Object { -not $_.vsHoje }).Count) ainda não pontuaram.")
    }
    $prox = @((($refDia + 1)..5) | Where-Object { $_ -le 5 -and $metas[$_] -gt $metas[[math]::Min($refDia, 5)] })
    if ($prox.Count) { $l.Add("- Atenção: as próximas metas são maiores ($(($prox | ForEach-Object { "$($curtos[$_]) $(MetaMi $_)" }) -join ', ')). Guarde aceleradores e recursos para os temas.") }
  }
  $l
}

if ($Turno -eq 'alerta') {
  # ================= ALERTA DAS 19H (combo de pontuação) =================
  # Foco: VS de hoje e projeção da doação, tom incisivo. Sem os dias anteriores do VS.
  $faltaVS = @(); $okHoje = 0; $meiaMeta = 0
  if ($vsHoje -ge 0) {
    $okHoje = OkVS $vsHoje; $meiaMeta = $metas[$vsHoje] / 2
    $faltaVS = @($pessoas | Where-Object { (Num $_.vsHoje) -lt $metas[$vsHoje] })
    $quaseVS = @($faltaVS | Where-Object { (Num $_.vsHoje) -ge $meiaMeta })
  }
  $pctProjA = $projTime / $metaTimeSemana
  $atrasados = $total - $okDoa

  $geral.Add("⚠️ DEDZ - ALERTA DAS 19H - $titulo"); $geral.Add('')
  if ($vsHoje -ge 0) {
    $geral.Add("O COMBO DE PONTUAÇÃO ESTÁ ATIVO. Faltam $(TempoFalta) para o VS de $($temas[$vsHoje]) fechar (meta $(MetaMi $vsHoje)).")
    $geral.Add('')
    $geral.Add('VS DE HOJE')
    $geral.Add("- $okHoje de $total bateram ($(Pct $okHoje $total)). $($faltaVS.Count) ainda NÃO bateram.")
    $geral.Add("- $(Qtd $cobZerados.Count 'membro está' 'membros estão') ZERADO$(if ($cobZerados.Count -ne 1) { 'S' }) e $(Qtd $cobMetade.Count 'não chegou' 'não chegaram') nem à metade da meta ($(EmMi $meiaMeta)).")
    $geral.Add("- Previsão: no ritmo atual, de $okHoje a $($okHoje + $quaseVS.Count) fecham na meta. Os outros $($total - $okHoje - $quaseVS.Count) vão deixar pontos na mesa se não jogarem agora.")
    if ($cobZerados.Count + $cobMetade.Count) {
      $geral.Add("- Zerado na hora do combo não é falta de recurso, é falta de participação. O combo é a melhor hora do dia para pontuar: use agora o que você guardou para $($temas[$vsHoje]).")
    }
  } else {
    $geral.Add('Domingo não tem VS. Hoje é o ÚLTIMO dia para fechar a doação da semana (140 mil).')
  }
  $geral.Add('')
  $geral.Add("DOAÇÃO: $(if ($pctNaMeta -lt 0.6 -or $pctProjA -lt 0.8) { 'CRÍTICO' } elseif ($pctNaMeta -lt 0.8 -or $pctProjA -lt 0.95) { 'ATENÇÃO' } else { 'NO CAMINHO' })")
  $geral.Add("- $atrasados de $total estão ATRASADOS na doação (meta de $(EmMil $metaDoa) até hoje)$(if ($abaixoMetadeDoa) { ", e $abaixoMetadeDoa não chegaram nem à metade" }).")
  $geral.Add("- Previsão: a aliança fecha a semana com ~$(EmMil $projTime) de $(EmMil $metaTimeSemana) ($(Pct $projTime $metaTimeSemana)). Só $vaoBater de $total chegam aos 140 mil nesse ritmo.")
  if ($pctProjA -lt 1) {
    $faltaD = [math]::Max($metaTimeSemana - $somaDoa, 0); $diasRestD = [math]::Max(7 - $diasCorridos, 0.5)
    $geral.Add("- Para fechar a meta, a aliança precisa doar ~$(EmMil ($faltaD / $diasRestD)) $(if ($refDia -eq 6) { 'até o fim de hoje' } else { 'por dia até domingo' }), contra ~$(EmMil ($somaDoa / $diasCorridos)) por dia até agora.")
  } elseif ($atrasados) {
    $geral.Add("- O total só está acima porque poucos doam muito. Isso não cobre os $atrasados atrasados: a meta de 20 mil por dia vale para cada um.")
  }
  $geral.Add('- Sem doação a loja da aliança não é reabastecida, e todo mundo perde.')
  $geral.Add('- Não dependa só da recarga: 30 diamantes por dia já fazem muita diferença.')
  $geral.Add('')
  $geral.Add('A liderança está acompanhando quem está zerado, abaixo da metade ou atrasado na doação, e vai chamar no privado.')
  $geral.Add($(if ($vsHoje -ge 0) { 'Combo ativo até as 23h. É agora!' } else { 'Fechem a doação até as 23h!' }))

  $lid.Add("⚠️ DEDZ - Liderança - ALERTA DAS 19H - $titulo"); $lid.Add('')
  if ($vsHoje -ge 0) {
    $lid.Add("VS DE HOJE ($($temas[$vsHoje]), meta $(MetaMi $vsHoje)) - combo ativo até as 23h")
    $lid.Add("- Bateram: $okHoje/$total ($(Pct $okHoje $total)) · faltam $($faltaVS.Count)")
    $antigosA = @($hist | Where-Object { $_.turno -eq 'alerta' -and $_.data -ne $refData.ToString('yyyy-MM-dd') -and $_.pctMeta -ne $null })
    if ($antigosA.Count) {
      $mediaA = ($antigosA | Measure-Object pctMeta -Average).Average
      $difA = [math]::Round(100 * $okHoje / [math]::Max($total, 1) - $mediaA)
      $lid.Add("- Comparado com as 19h dos outros dias ($($antigosA.Count) leituras): $(if ($difA -ge 0) { "$difA pontos acima" } else { "$(-$difA) pontos abaixo" }) da média de $([math]::Round($mediaA))%")
    }
    if ($duelo) { $lid.Add("- Duelo com $($duelo.adversario): placar $($duelo.placar) · nós $($duelo.nos)% x $($duelo.eles)% $(if ($duelo.nos -lt $duelo.eles) { '(estamos atrás no dia)' } else { '(estamos na frente no dia)' })") }
    $lid.Add('')
    $lid.Add("AINDA NÃO BATERAM ($($faltaVS.Count))")
    if ($cobZerados.Count) { $lid.Add("- ZERADOS ($($cobZerados.Count)): $(Juntar $cobZerados.nome)") }
    if ($cobMetade.Count) { $lid.Add("- Abaixo da metade, menos de $(EmMi $meiaMeta) ($($cobMetade.Count)):"); foreach ($p in $cobMetade) { $lid.Add("  - $($p.nome): $(EmMi $p.vsHoje)") } }
    if ($quaseVS.Count) { $lid.Add("- Passaram da metade, falta pouco ($($quaseVS.Count)): $(Juntar $quaseVS.nome)") }
  } else {
    $lid.Add('Domingo não tem VS: foco total em fechar a doação da semana.')
  }
  $msgA = @(MensagensPrivado)
  if ($msgA.Count) { $lid.Add(''); $lid.Add("MENSAGENS PARA O PRIVADO ($($msgA.Count), copiar e colar agora)"); foreach ($x in $msgA) { $lid.Add($x) } }
  $lid.Add('')
  $lid.Add("DOAÇÃO - PROJEÇÃO (meta 140 mil por membro)")
  $lid.Add("- Em dia até hoje: $okDoa/$total · total $(EmMil $somaDoa) · previsão da aliança ~$(EmMil $projTime) ($(Pct $projTime $metaTimeSemana))")
  $critA = @($pessoas | Where-Object { $_.pctDoa -lt 0.5 } | Sort-Object doa)
  if ($critA.Count) { $lid.Add("- Abaixo de 50% da meta ($($critA.Count)): $(($critA | ForEach-Object { "$($_.nome) ($(EmMil $_.doa))" }) -join ', ')") }
  $riscoA = @($pessoas | Where-Object { $_.pctDoa -ge 0.5 -and ($_.doa / $diasCorridos * 7) -lt 100000 } | Sort-Object doa)
  if ($riscoA.Count) { $lid.Add("- Não chegam a 100 mil no ritmo atual ($($riscoA.Count)): $(($riscoA | ForEach-Object { "$($_.nome) (~$(EmMil ($_.doa / $diasCorridos * 7)))" }) -join ', ')") }
  $lid.Add('- Na cobrança, lembre que dá para doar com diamantes: 30 por dia já fazem muita diferença.')
}
elseif ($Turno -eq 'meio') {
  # ================= MEIO DO DIA =================
  $geral.Add("DEDZ - Meio do dia - $titulo"); $geral.Add('')
  if ($vsHoje -ge 0) {
    $geral.Add("VS de hoje ($($temas[$vsHoje]), meta $(MetaMi $vsHoje)): $(OkVS $vsHoje) de $total já bateram.")
  } else { $geral.Add('Hoje não tem VS: dia de colocar as doações em dia.') }
  foreach ($i in $diasFechados) { $geral.Add("VS de $($nomesDia[$i]): $(OkVS $i) de $total bateram.") }
  $geral.Add("Doação da semana (meta de $(EmMil $metaDoa) até hoje): $okDoa de $total na meta. Total doado: $(EmMil $somaDoa).")
  $geral.Add(''); foreach ($x in (AnaliseGeral)) { $geral.Add($x) }
  $cobG = @(CobrancaGeral); if ($cobG.Count) { $geral.Add(''); foreach ($x in $cobG) { $geral.Add($x) } }
  $geral.Add('')
  $geral.Add($(if ($vsHoje -ge 0) { 'Ainda dá tempo: o VS fecha às 23h. Cada ponto conta!' } else { 'Bora deixar a doação da semana em dia!' }))

  $lid.Add("DEDZ - Liderança - Meio do dia - $titulo"); $lid.Add('')
  if ($vsHoje -ge 0) {
    $metade = $metas[$vsHoje] / 2
    $ok = OkVS $vsHoje
    $passouMetade = @($pessoas | Where-Object { $_.vsHoje -ge $metade -and $_.vsHoje -lt $metas[$vsHoje] }).Count
    $zerados = @($pessoas | Where-Object { -not $_.vsHoje })
    $abaixoMetade = @($pessoas | Where-Object { $_.vsHoje -gt 0 -and $_.vsHoje -lt $metade } | Sort-Object vsHoje)
    $lid.Add("RITMO DO VS DE HOJE ($($temas[$vsHoje]), meta $(MetaMi $vsHoje))")
    $lid.Add("- Já bateram: $ok/$total ($(Pct $ok $total))")
    $lid.Add("- Passaram da metade: $passouMetade · abaixo da metade: $($abaixoMetade.Count) · zerados: $($zerados.Count)")
    $antigos = @($hist | Where-Object { $_.turno -eq 'meio' -and $_.data -ne $refData.ToString('yyyy-MM-dd') -and $_.pctMeta -ne $null })
    if ($antigos.Count) {
      $media = ($antigos | Measure-Object pctMeta -Average).Average
      $hoje = 100 * $ok / [math]::Max($total, 1)
      $dif = [math]::Round($hoje - $media)
      $lid.Add("- Comparado com o meio dos outros dias ($($antigos.Count) leituras): $(if ($dif -ge 0) { "$dif pontos acima" } else { "$(-$dif) pontos abaixo" }) da média de $([math]::Round($media))%")
    } else { $lid.Add('- (ainda sem leituras de meio de dia anteriores para comparar o ritmo)') }
    if ($duelo) { $lid.Add("- Duelo com $($duelo.adversario): placar $($duelo.placar) · nós $($duelo.nos)% x $($duelo.eles)% $(if ($duelo.nos -lt $duelo.eles) { '(estamos atrás no dia)' } else { '(estamos na frente no dia)' })") }

    # lista de cobrança priorizada
    $fila = foreach ($p in $pessoas) {
      if ($secundarias.ContainsKey($p.id)) { continue }   # conta secundária da liderança: fora da cobrança no privado
      $s = 0
      if (-not $p.vsHoje) { $s += 3 } elseif ($p.vsHoje -lt $metas[$vsHoje] / 4) { $s += 2 } elseif ($p.vsHoje -lt $metade) { $s += 1 }
      if ($p.pctDoa -lt 0.5) { $s += 2 } elseif ($p.pctDoa -lt 1) { $s += 1 }
      $s += $p.falhas.Count
      if ($s -lt 3) { continue }
      $probVS = @(); $probDoa = $null
      if (-not $p.vsHoje) { $probVS += 'não pontuou hoje' } elseif ($p.vsHoje -lt $metade) { $probVS += 'VS de hoje fraco' }
      if ($p.zerou.Count) { $probVS += "zerou na $(($p.zerou | ForEach-Object { $curtos[$_] }) -join '/')" }
      elseif ($p.falhas.Count) { $probVS += "abaixo na $(($p.falhas | ForEach-Object { $curtos[$_] }) -join '/')" }
      if ($p.pctDoa -lt 0.5) { $probDoa = 'doação baixa' } elseif ($p.pctDoa -lt 0.9) { $probDoa = 'doação um pouco abaixo' }
      $acao = if ($probVS.Count -and -not $probDoa) { 'doa bem: focar o VS' }
              elseif ($probDoa -and -not $probVS.Count) { 'vai bem no VS: elogiar e cobrar a doação' }
              elseif (-not $p.vsHoje) { 'lembrar do tema de hoje e da doação' }
              else { 'conversa direta' }
      $dica = (@($probVS) + @($probDoa | Where-Object { $_ }) -join ', ') + ": $acao"
      [pscustomobject]@{ nome = $p.nome; s = $s; txt = "$($p.nome): VS hoje $(EmMi $p.vsHoje) · doação $(EmMil $p.doa) ($(Pct $p.doa $p.metaDoa)) → $dica" }
    }
    $fila = @($fila | Sort-Object @{e = 's'; Descending = $true }, nome | Select-Object -First 10)
    $lid.Add(''); $lid.Add("COBRAR NO PRIVADO AGORA (prioridade, até 10)")
    if ($fila.Count) { $n = 1; foreach ($f in $fila) { $lid.Add("$n. $($f.txt)"); $n++ } } else { $lid.Add('- ninguém em situação crítica') }
    if ($abaixoMetade.Count) { $lid.Add(''); $lid.Add("ABAIXO DE 50% DA META DE HOJE, menos de $(EmMi $metade) ($($abaixoMetade.Count))"); foreach ($p in $abaixoMetade) { $lid.Add("- $($p.nome): $(EmMi $p.vsHoje)") } }
    if ($zerados.Count) { $lid.Add("ZERADOS HOJE ($($zerados.Count)): $(Juntar $zerados.nome)") }
    $msgP = @(MensagensPrivado); if ($msgP.Count) { $lid.Add(''); $lid.Add("MENSAGENS PARA O PRIVADO ($($msgP.Count), copiar e colar)"); foreach ($x in $msgP) { $lid.Add($x) } }
  }
  # quem parou de doar
  $semDoar = @($pessoas | Where-Object { $null -ne $_.doaNoDia -and $_.doaNoDia -le 0 })
  $lid.Add(''); $lid.Add("DOAÇÃO")
  $lid.Add("- Na meta até hoje ($(EmMil $metaDoa)): $okDoa/$total · total $(EmMil $somaDoa)")
  if ($refDia -gt 0) {
    if (@($pessoas | Where-Object { $null -ne $_.doaNoDia }).Count) { $lid.Add("- Não doaram nada hoje até agora ($($semDoar.Count)): $(if ($semDoar.Count) { Juntar $semDoar.nome } else { 'ninguém' })") }
    else { $lid.Add('- (sem leitura de ontem para medir quem doou hoje)') }
  }
  $critDoa = @($pessoas | Where-Object { $_.pctDoa -lt 0.5 } | Sort-Object doa)
  if ($critDoa.Count) { $lid.Add("- Abaixo de 50% da meta: $(($critDoa | ForEach-Object { "$($_.nome) ($(EmMil $_.doa))" }) -join ', ')") }
  if ($okDoa -lt $total) { $lid.Add('- Na cobrança, lembre que dá para doar com diamantes, não só com a recarga: 30 diamantes por dia já fazem muita diferença.') }
  $lid.Add(''); $lid.Add("ALERTA DE BAIXA PERFORMANCE NA SEMANA ($($alertas.Count))")
  if ($alertas.Count) { foreach ($a in $alertas) { $lid.Add("- $($a.nome): $($a.mot)") } } else { $lid.Add('- ninguém por enquanto') }
}
else {
  # ================= FECHAMENTO =================
  $amanha = ($refDia + 1) % 7
  $geral.Add("DEDZ - Fechamento de $titulo"); $geral.Add('')
  if ($vsFechou -ge 0) {
    $ok = OkVS $vsFechou
    $geral.Add("VS de $($nomesDia[$vsFechou]) ($($temas[$vsFechou]), meta $(MetaMi $vsFechou)) fechou: $ok de $total bateram ($(Pct $ok $total)).")
    if ($duelo) { $geral.Add("Duelo com $($duelo.adversario): placar $($duelo.placar).") }
  }
  $geral.Add("Doação da semana (meta de $(EmMil $metaDoa) até $($nomesDia[$refDia])): $okDoa de $total na meta. Total doado: $(EmMil $somaDoa).")
  $geral.Add(''); foreach ($x in (AnaliseGeral)) { $geral.Add($x) }
  $cobG = @(CobrancaGeral); if ($cobG.Count) { $geral.Add(''); foreach ($x in $cobG) { $geral.Add($x) } }
  if ($amanha -le 5 -and $refDia -ne 6) { $geral.Add(''); $geral.Add("Amanhã: VS de $($temas[$amanha]), meta $(MetaMi $amanha). Bora!") }
  elseif ($refDia -eq 5) { $geral.Add(''); $geral.Add('Domingo não tem VS: aproveite para fechar a doação da semana (140 mil).') }
  $geral.Add('Rumo à S4!')

  $lid.Add("DEDZ - Liderança - Fechamento de $titulo"); $lid.Add('')
  if ($vsFechou -ge 0) {
    $ok = OkVS $vsFechou
    $lid.Add("RESULTADO DO VS DE $($nomesDia[$vsFechou].ToUpper()) ($($temas[$vsFechou]), meta $(MetaMi $vsFechou))")
    $lid.Add("- Bateram: $ok/$total ($(Pct $ok $total))")
    $outros = @($diasFechados | Where-Object { $_ -ne $vsFechou } | ForEach-Object { "$($curtos[$_]) $(Pct (OkVS $_) $total)" })
    if ($outros.Count) { $lid.Add("- Outros dias da semana: $($outros -join ' · ')") }
    $passadaOk = @($regsPassada.Values | Where-Object { $_.vs[$vsFechou] -ge $metas[$vsFechou] }).Count
    if ($regsPassada.Count) { $lid.Add("- Mesmo dia da semana passada: $(Pct $passadaOk $regsPassada.Count)") } else { $lid.Add('- (sem a semana passada no banco para comparar)') }
    if ($duelo) { $lid.Add("- Duelo com $($duelo.adversario): placar $($duelo.placar) · $($duelo.nos)% x $($duelo.eles)%") }
    $abaixo = @($pessoas | Where-Object { $_.vsFechou -lt $metas[$vsFechou] } | Sort-Object vsFechou)
    $lid.Add(''); $lid.Add("NÃO BATERAM A META ($($abaixo.Count))")
    if ($abaixo.Count) {
      $mt = $metas[$vsFechou]
      $faixa1 = @($abaixo | Where-Object { $_.vsFechou -lt 0.5 * $mt })
      $faixa2 = @($abaixo | Where-Object { $_.vsFechou -ge 0.5 * $mt -and $_.vsFechou -lt 0.9 * $mt })
      $faixa3 = @($abaixo | Where-Object { $_.vsFechou -ge 0.9 * $mt })
      if ($faixa1.Count) { $lid.Add("- Menos de 50% ($($faixa1.Count)):"); foreach ($p in $faixa1) { $lid.Add("  - $($p.nome): $(EmMi $p.vsFechou)") } }
      if ($faixa2.Count) { $lid.Add("- Entre 50% e 89% ($($faixa2.Count)): $(Juntar $faixa2.nome)") }
      if ($faixa3.Count) { $lid.Add("- Quase bateram, 90% ou mais ($($faixa3.Count)): $(Juntar $faixa3.nome)") }
    } else { $lid.Add('- ninguém!') }
    $top = @($pessoas | Sort-Object vsFechou -Descending | Select-Object -First 5)
    $lid.Add(''); $lid.Add('DESTAQUES DO DIA (para reconhecer no grupo)')
    $n = 1; foreach ($p in $top) { $lid.Add("$n. $($p.nome): $(EmMi $p.vsFechou)"); $n++ }
    $msgP = @(MensagensPrivado); if ($msgP.Count) { $lid.Add(''); $lid.Add("MENSAGENS PARA O PRIVADO ($($msgP.Count), copiar e colar)"); foreach ($x in $msgP) { $lid.Add($x) } }
  }
  $lid.Add(''); $lid.Add("ALERTA DE BAIXA PERFORMANCE NA SEMANA ($($alertas.Count))")
  if ($alertas.Count) { foreach ($a in $alertas) { $lid.Add("- $($a.nome): $($a.mot)") } } else { $lid.Add('- ninguém') }
  if (-not $semanasAnteriores.Count) { $lid.Add('(ainda sem semanas anteriores para medir reincidência)') }

  $risco = @($pessoas | Where-Object { $_.projDoa -lt 0.7 * $metaSemanaDoa } | Sort-Object projDoa)
  $quase = @($pessoas | Where-Object { $_.projDoa -ge 0.7 * $metaSemanaDoa -and $_.projDoa -lt $metaSemanaDoa }).Count
  $lid.Add(''); $lid.Add("DOAÇÃO - PROJEÇÃO PARA A SEMANA (meta 140 mil, no ritmo atual)")
  $lid.Add("- Na meta até hoje: $okDoa/$total · total $(EmMil $somaDoa)")
  if ($risco.Count) { $lid.Add("- Não chegam a 100 mil no ritmo atual ($($risco.Count)): $(($risco | ForEach-Object { "$($_.nome) (~$(EmMil $_.projDoa))" }) -join ', ')") }
  $lid.Add("- Chegam entre 100 e 140 mil: $quase")
  $semDoar = @($pessoas | Where-Object { $null -ne $_.doaNoDia -and $_.doaNoDia -le 0 })
  if ($refDia -gt 0 -and @($pessoas | Where-Object { $null -ne $_.doaNoDia }).Count) { $lid.Add("- Não doaram nada na $($nomesDia[$refDia]) ($($semDoar.Count)): $(if ($semDoar.Count) { Juntar $semDoar.nome } else { 'ninguém' })") }

  if ($amanha -le 5 -and $refDia -ne 6) {
    $lid.Add(''); $lid.Add("AMANHÃ: VS DE $($nomesDia[$amanha].ToUpper()) ($($temas[$amanha]), meta $(MetaMi $amanha))")
    $fracos = @(foreach ($p in $pessoas) {
      $nf = 0; foreach ($sem in $semanasAnteriores) { $x = $todosRegs | Where-Object { $_.semana -eq $sem -and $_.membro -eq $p.id } | Select-Object -First 1; if ($x -and $null -ne $x.vs[$amanha] -and $x.vs[$amanha] -lt $metas[$amanha]) { $nf++ } }
      if ($nf -ge 2) { $p.nome }
    })
    if ($semanasAnteriores.Count -ge 2) { $lid.Add("- Costumam ficar abaixo nesse tema: $(if ($fracos.Count) { Juntar $fracos } else { 'ninguém' })") }
    else { $lid.Add('- (histórico por tema começa a valer com 2 semanas de dados)') }
  }

  if ($fimDeSemana) {
    $lid.Add(''); $lid.Add("FECHAMENTO DA SEMANA ($($refData.AddDays(-$refDia).ToString('dd/MM')) a $($refData.AddDays(6 - $refDia).ToString('dd/MM')))")
    $diasVS = @(0..5 | Where-Object { $d = $_; $_ -le [math]::Min($refDia, 5) -and @($regsSemana | Where-Object { $null -ne $_.vs[$d] }).Count })
    $cons = foreach ($p in $pessoas) {
      $bat = @($diasVS | Where-Object { $p.reg.vs[$_] -ge $metas[$_] }).Count
      [pscustomobject]@{ nome = $p.nome; bat = $bat; doa = $p.doa; nota = $bat + [math]::Min($p.doa / $metaSemanaDoa, 1) * 2 }
    }
    $cons = @($cons | Sort-Object nota -Descending)
    $lid.Add("- Melhores (VS em todos os dias e doação mais alta): $(($cons | Where-Object { $_.bat -eq $diasVS.Count } | Sort-Object doa -Descending | Select-Object -First 5 | ForEach-Object { $_.nome }) -join ', ')")
    if ($diasVS.Count -lt 6) { $lid.Add("- (VS com leitura em $($diasVS.Count) de 6 dias: $(($diasVS | ForEach-Object { $curtos[$_] }) -join ', '))") }
    $conversa = @($cons | Where-Object { ($diasVS.Count - $_.bat) -ge 3 -or $_.doa -lt 0.5 * $metaSemanaDoa } | Sort-Object nota)
    $lid.Add("- Candidatos a conversa ou advertência (3+ dias abaixo no VS ou menos de 70 mil de doação) ($($conversa.Count)):")
    if ($conversa.Count) {
      foreach ($c in ($conversa | Select-Object -First 15)) { $lid.Add("  - $($c.nome): VS $($c.bat)/$($diasVS.Count) dias · doação $(EmMil $c.doa)") }
      if ($conversa.Count -gt 15) { $lid.Add("  - e mais $($conversa.Count - 15) (lista completa na dash)") }
    } else { $lid.Add('  - ninguém') }
  }
}

# ---------- salvar ----------
[IO.File]::WriteAllText((Join-Path $Dir 'relatorio_geral.txt'), ($geral -join "`n"), $script:utf8)
[IO.File]::WriteAllText((Join-Path $Dir 'relatorio_lideranca.txt'), ($lid -join "`n"), $script:utf8)
# lista do PV: só na quarta (alerta) e no sábado (fechamento); nos outros turnos o arquivo é apagado para não reaproveitar lista velha
$arqPV = Join-Path $Dir 'pv.txt'
if ($diaPV) {
  $pv = @(ListaPV)
  $cab = if ($diaPV -eq 'quarta') { "LISTA DO PV - puxão de orelha de quarta ($($refData.ToString('dd/MM'))), combo ativo" } else { "LISTA DO PV - balanço da semana ($($refData.AddDays(-$refDia).ToString('dd/MM')) a $($refData.ToString('dd/MM')))" }
  $linhasPV = New-Object System.Collections.Generic.List[string]
  $linhasPV.Add("$cab · $($pv.Count) pessoa(s), as piores primeiro · fora quem está entre 50% e 99% e as contas secundárias"); $linhasPV.Add('')
  $n = 1; foreach ($i in $pv) { $linhasPV.Add("$n. $($i.nome)"); $linhasPV.Add($i.txt); $linhasPV.Add(''); $n++ }
  if (-not $pv.Count) { $linhasPV.Add('Ninguém na lista.') }
  # pv_lista.tsv: nome<TAB>motivo com os números da semana, usado pelo pv_resumo.ps1
  $periodo = "seg a $($curtos[$refDia]) $($refData.ToString('dd/MM'))"
  [IO.File]::WriteAllText((Join-Path $Dir 'pv_lista.tsv'), ((@("#periodo`t$periodo") + @($pv | ForEach-Object { "$($_.nome)`t$($_.mot)`t$($_.rein)`t$($_.curto)" })) -join "`n"), $script:utf8)
  [IO.File]::WriteAllText($arqPV, ($linhasPV -join "`n").TrimEnd(), $script:utf8)
} else { foreach ($a in @($arqPV, (Join-Path $Dir 'pv_lista.tsv'))) { if (Test-Path $a) { Remove-Item $a -Force } } }
if (-not $NaoSalvarHistorico) {
  $chave = "$($refData.ToString('yyyy-MM-dd'))_$Turno"
  $novo = [ordered]@{ chave = $chave; data = $refData.ToString('yyyy-MM-dd'); turno = $Turno; dia = $refDia; total = $total
    pctMeta = $(if ($vsHoje -ge 0) { [math]::Round(100 * (OkVS $vsHoje) / [math]::Max($total, 1), 1) } elseif ($vsFechou -ge 0) { [math]::Round(100 * (OkVS $vsFechou) / [math]::Max($total, 1), 1) } else { $null })
    okDoa = $okDoa; duelo = $duelo }
  $hist = @($hist | Where-Object { $_.chave -ne $chave }) + [pscustomobject]$novo
  SalvarJson $histArq @($hist)
}
"turno $Turno · ref $($refData.ToString('yyyy-MM-dd')) ($($nomesDia[$refDia])) · semana $refSemana · geral $($geral.Count) linhas · liderança $($lid.Count) linhas"
