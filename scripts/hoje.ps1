# Diz qual é a semana e o dia do jogo agora (horário de Brasília; o dia do jogo vira às 23:00).
# Saída em JSON: semana (segunda AAAA-MM-DD), dia (0 = segunda ... 6 = domingo), temVS, diaAnterior (VS a fechar, ou -1).
param([datetime]$Agora = (Get-Date))
$jogo = $Agora.AddHours(1)          # 23:00 de Brasília = 00:00 do dia seguinte no jogo
$dia = ([int]$jogo.DayOfWeek + 6) % 7
$segunda = $jogo.Date.AddDays(-$dia)
$ant = $dia - 1
[pscustomobject]@{
  agora       = $Agora.ToString('yyyy-MM-dd HH:mm')
  semana      = $segunda.ToString('yyyy-MM-dd')
  dia         = $dia
  nomeDia     = @('segunda','terça','quarta','quinta','sexta','sábado','domingo')[$dia]
  temVS       = $dia -le 5
  diaAnterior = $(if ($ant -ge 0 -and $ant -le 5) { $ant } else { -1 })
} | ConvertTo-Json
