# Monta os dois relatórios a partir do espelho local (C:\lz\estado):
#   relatorio_geral.txt      para o grupo dos membros: só números, sem nomes e sem link da dash
#   relatorio_lideranca.txt  para o grupo da liderança: nomes abaixo das metas e alertas de baixa performance
# Uso: .\relatorio.ps1 [-Turno 12h|noite] [-Agora 'AAAA-MM-DD HH:mm'] [-Dir C:\lz]
param([ValidateSet('12h','noite')][string]$Turno, [datetime]$Agora = (Get-Date), [string]$Dir = 'C:\lz')
. (Join-Path $PSScriptRoot 'comum.ps1')
$est = PastaEstado $Dir
if (-not $Turno) { $Turno = if ($Agora.Hour -lt 18) { '12h' } else { 'noite' } }

# ---------- calendário do jogo (o dia vira às 23:00 de Brasília) ----------
$jogo = $Agora.AddHours(1)
$dia = ([int]$jogo.DayOfWeek + 6) % 7                 # 0 = segunda ... 6 = domingo
$semana = $jogo.Date.AddDays(-$dia).ToString('yyyy-MM-dd')
$diasNome = 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'
$diasCurto = 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'
$temas = 'Radar + Veículo', 'Construção', 'Pesquisa', 'Heróis', 'Exército', 'Combate'
$metas = 4.5e6, 5e6, 3.3e6, 6e6, 7e6, 6e6
$diasDoa = $dia + 1                                    # dias da semana já começados
$metaDoa = 20000 * $diasDoa
$fechados = @(0..5 | Where-Object { $_ -lt $dia })     # VS de dias já encerrados
$hojeVS = if ($dia -le 5) { $dia } else { -1 }         # VS em andamento (parcial)

# ---------- dados ----------
$membros = @{}; foreach ($m in (LerLista "$est\membros.json")) { if (-not $m.saiu) { $membros[$m.id] = $m } }
$todos = @(LerLista "$est\registros.json")
$R = @($todos | Where-Object { $_.semana -eq $semana -and $membros.ContainsKey($_.membro) })
$total = $R.Count
function Nome($x) { [string]$membros[$x.membro].nome }
function EmMi($v) { if (-not $v) { return '0' }; ('{0:0.00}' -f ($v / 1e6)).Replace('.', ',') + 'Mi' }
function EmMil($v) { if ($v -ge 1e6) { ('{0:0.00}' -f ($v / 1e6)).Replace('.', ',') + 'M' } else { [string][math]::Round($v / 1000) + ' mil' } }
function MetaTxt($i) { (('{0:0.#}' -f ($metas[$i] / 1e6)).Replace('.', ',')) + 'Mi' }
function Lista($nomes) { (@($nomes) | Sort-Object { $_.ToLowerInvariant() }) -join ', ' }

# ---------- contas por membro ----------
$info = foreach ($reg in $R) {
  $miss = @($fechados | Where-Object { $null -ne $reg.vs[$_] -and $reg.vs[$_] -lt $metas[$_] })
  $zeros = @($fechados | Where-Object { $reg.vs[$_] -eq 0 })
  $doa = [double]($reg.doacao | ForEach-Object { $_ }); if (-not $doa) { $doa = 0 }
  [pscustomobject]@{
    nome = Nome $reg; r = $reg; miss = $miss; zeros = $zeros
    doa = $doa; pctDoa = $doa / $metaDoa
    hojeVS = $(if ($hojeVS -ge 0) { $reg.vs[$hojeVS] } else { $null })
  }
}

# Histórico: semanas anteriores fechadas (para reincidência)
$anteriores = @($todos | Where-Object { $_.semana -lt $semana } | ForEach-Object { $_.semana } | Sort-Object -Unique -Descending | Select-Object -First 3)
function FalhasAnteriores($id) {
  $n = 0
  foreach ($s in $anteriores) {
    $x = $todos | Where-Object { $_.semana -eq $s -and $_.membro -eq $id } | Select-Object -First 1
    if (-not $x) { continue }
    $mv = @(0..5 | Where-Object { $null -ne $x.vs[$_] -and $x.vs[$_] -lt $metas[$_] }).Count
    if ($mv -ge 3 -or ($null -ne $x.doacao -and $x.doacao -lt 70000)) { $n++ }
  }
  $n
}

$titulo = "$($diasNome[$dia].Substring(0,1).ToUpper())$($diasNome[$dia].Substring(1)) ($($Agora.ToString('dd/MM')), $(if ($Turno -eq '12h') { '12h' } else { 'noite' }))"

# ================= RELATÓRIO GERAL (membros) =================
$g = New-Object System.Collections.Generic.List[string]
$g.Add("DEDZ - Atualização de $titulo")
$g.Add('')
foreach ($i in $fechados) {
  $ok = @($R | Where-Object { $_.vs[$i] -ge $metas[$i] }).Count
  $g.Add("VS de $($diasNome[$i]) ($($temas[$i]), meta $(MetaTxt $i)): $ok de $total bateram.")
}
if ($hojeVS -ge 0) {
  $ok = @($R | Where-Object { $_.vs[$hojeVS] -ge $metas[$hojeVS] }).Count
  $g.Add("VS de hoje ($($temas[$hojeVS]), meta $(MetaTxt $hojeVS)): $ok de $total já bateram. O dia fecha às 23h.")
} else { $g.Add('Hoje não tem VS.') }
$okDoa = @($info | Where-Object { $_.doa -ge $metaDoa }).Count
$somaDoa = ($info | Measure-Object doa -Sum).Sum
$g.Add("Doação da semana (meta de $(EmMil $metaDoa) até hoje): $okDoa de $total na meta. Total doado pela aliança: $(EmMil $somaDoa).")
$g.Add('')
$frase = if ($hojeVS -ge 0 -and $Turno -eq 'noite') { 'Última chance de pontuar hoje: o VS fecha às 23h!' }
         elseif ($hojeVS -ge 0) { "Bora pra cima no VS de $($diasNome[$hojeVS]). Cada ponto conta!" }
         else { 'Domingo é dia de colocar as doações em dia. Bora!' }
$g.Add($frase)
$g.Add('Rumo à S4!')

# ================= RELATÓRIO DA LIDERANÇA =================
$l = New-Object System.Collections.Generic.List[string]
$l.Add("DEDZ - Liderança - $titulo")
$l.Add('')
$l.Add('RESUMO')
foreach ($i in $fechados) {
  $ok = @($R | Where-Object { $_.vs[$i] -ge $metas[$i] }).Count
  $l.Add("- VS $($diasCurto[$i]): $ok/$total na meta")
}
if ($hojeVS -ge 0) {
  $ok = @($R | Where-Object { $_.vs[$hojeVS] -ge $metas[$hojeVS] }).Count
  $l.Add("- VS $($diasCurto[$hojeVS]) (parcial): $ok/$total na meta")
}
$l.Add("- Doação: $okDoa/$total com $(EmMil $metaDoa) ou mais · total $(EmMil $somaDoa)")

foreach ($i in $fechados) {
  $abaixo = @($info | Where-Object { $_.r.vs[$i] -lt $metas[$i] })
  $l.Add('')
  $l.Add("VS DE $($diasNome[$i].ToUpper()) - abaixo da meta ($($abaixo.Count))")
  if ($abaixo.Count) { foreach ($x in ($abaixo | Sort-Object { $_.r.vs[$i] })) { $l.Add("- $($x.nome): $(EmMi $x.r.vs[$i])") } } else { $l.Add('- ninguém') }
}
if ($hojeVS -ge 0) {
  $zerados = @($info | Where-Object { $_.hojeVS -eq 0 -or $null -eq $_.hojeVS })
  $metade = $metas[$hojeVS] / 2
  $abaixoMetade = @($info | Where-Object { $_.hojeVS -gt 0 -and $_.hojeVS -lt $metade } | Sort-Object hojeVS)
  $entre = @($info | Where-Object { $_.hojeVS -ge $metade -and $_.hojeVS -lt $metas[$hojeVS] }).Count
  $l.Add('')
  $l.Add("VS DE HOJE ($($diasNome[$hojeVS]), parcial)")
  $l.Add("- Ainda não pontuaram ($($zerados.Count)): $(if ($zerados.Count) { Lista $zerados.nome } else { 'ninguém' })")
  $l.Add("- Abaixo de 50% da meta, menos de $(EmMi $metade) ($($abaixoMetade.Count)):")
  if ($abaixoMetade.Count) { foreach ($x in $abaixoMetade) { $l.Add("  - $($x.nome): $(EmMi $x.hojeVS)") } } else { $l.Add('  - ninguém') }
  $l.Add("- Entre 50% e 99% da meta: $entre membros")
}

$critDoa = @($info | Where-Object { $_.pctDoa -lt 0.5 } | Sort-Object doa)
$quase = @($info | Where-Object { $_.pctDoa -ge 0.5 -and $_.pctDoa -lt 1 }).Count
$l.Add('')
$l.Add("DOAÇÃO - abaixo de 50% da meta até hoje ($($critDoa.Count))")
if ($critDoa.Count) { foreach ($x in $critDoa) { $l.Add("- $($x.nome): $(EmMil $x.doa)") } } else { $l.Add('- ninguém') }
$l.Add("- Entre 50% e 99% da meta: $quase membros")

# ---------- alertas de baixa performance ----------
$alertas = foreach ($x in $info) {
  $motivos = @()
  $pontos = 0
  if ($x.zeros.Count) { $motivos += "zerou o VS em $($x.zeros.Count) dia(s) ($(($x.zeros | ForEach-Object { $diasCurto[$_] }) -join ', '))"; $pontos += 2 * $x.zeros.Count }
  $missSemZero = @($x.miss | Where-Object { $_ -notin $x.zeros })
  if ($x.miss.Count -ge 2) { $motivos += "abaixo da meta do VS em $($x.miss.Count) de $($fechados.Count) dias fechados"; $pontos += $x.miss.Count }
  elseif ($missSemZero.Count -eq 1 -and $x.pctDoa -lt 0.5) { $motivos += "abaixo da meta do VS na $($diasNome[$missSemZero[0]])"; $pontos += 1 }
  if ($x.pctDoa -lt 0.25) { $motivos += "doação muito baixa ($(EmMil $x.doa) de $(EmMil $metaDoa))"; $pontos += 2 }
  elseif ($x.pctDoa -lt 0.5 -and $x.miss.Count) { $motivos += "doação baixa ($(EmMil $x.doa) de $(EmMil $metaDoa))"; $pontos += 1 }
  $rein = FalhasAnteriores $x.r.membro
  if ($rein -and $motivos.Count) { $motivos += "também ficou abaixo em $rein semana(s) anterior(es)"; $pontos += $rein }
  if ($pontos -ge 2) { [pscustomobject]@{ nome = $x.nome; pontos = $pontos; motivos = $motivos -join '; ' } }
}
$alertas = @($alertas | Sort-Object @{e = 'pontos'; Descending = $true }, nome)
$l.Add('')
$l.Add("ALERTA DE BAIXA PERFORMANCE NA SEMANA ($($alertas.Count))")
if ($fechados.Count -lt 2) { $l.Add("(com $($fechados.Count) dia de VS fechado, o alerta pesa mais a doação e os VS zerados)") }
if ($alertas.Count) { foreach ($a in $alertas) { $l.Add("- $($a.nome): $($a.motivos)") } } else { $l.Add('- ninguém por enquanto') }
if (-not $anteriores.Count) { $l.Add('(ainda não há semanas anteriores no banco para medir reincidência)') }

$destaques = @($info | Where-Object { $_.miss.Count -eq 0 -and $_.pctDoa -ge 1 -and $fechados.Count })
$l.Add('')
$l.Add("EM DIA COM TUDO (todas as metas de VS fechadas e a doação): $($destaques.Count) de $total")

[IO.File]::WriteAllText((Join-Path $Dir 'relatorio_geral.txt'), ($g -join "`n"), $script:utf8)
[IO.File]::WriteAllText((Join-Path $Dir 'relatorio_lideranca.txt'), ($l -join "`n"), $script:utf8)
"geral: $($g.Count) linhas · liderança: $($l.Count) linhas · semana $semana · dia $dia · turno $Turno"
