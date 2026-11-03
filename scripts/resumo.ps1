# Números da semana para mensagens do grupo, a partir do espelho local.
param([Parameter(Mandatory)][string]$Sem, [string]$Dir = 'C:\lz')
. (Join-Path $PSScriptRoot 'comum.ps1')
$R = @(LerLista "$(PastaEstado $Dir)\registros.json" | Where-Object { $_.semana -eq $Sem })
$metas = 4.5e6, 5e6, 3.3e6, 6e6, 7e6, 6e6
$dias = 'seg', 'ter', 'qua', 'qui', 'sex', 'sab'
$diasDoa = ([int](Get-Date).DayOfWeek + 6) % 7 + 1
"membros: $($R.Count)"
for ($i = 0; $i -lt 6; $i++) { $c = @($R | Where-Object { $null -ne $_.vs[$i] }); if ($c.Count) { "VS $($dias[$i]): " + @($c | Where-Object { $_.vs[$i] -ge $metas[$i] }).Count + " de $($R.Count) na meta" } }
"doação na meta (20k x $diasDoa dias): " + @($R | Where-Object { $_.doacao -ge 20000 * $diasDoa }).Count
"total doado: " + ($R | Measure-Object doacao -Sum).Sum
