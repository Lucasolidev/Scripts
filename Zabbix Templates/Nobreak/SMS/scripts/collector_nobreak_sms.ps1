param(
  [Alias('host')][string]$hostParam = '127.0.0.1',
  [Alias('port')][int]$portParam = 8080,
  [switch]$debug
)

try {
  $url = "http://$($hostParam):$portParam/s2/Monitores.action"
  if ($debug) { Write-Output "DEBUG: fetching URL $url" }
  try {
    $wc = New-Object System.Net.WebClient
    $bytes = $wc.DownloadData($url)
    $enc = [System.Text.Encoding]::GetEncoding('iso-8859-1')
    $html = $enc.GetString($bytes)
    if ($debug) { Write-Output "DEBUG: downloaded $($bytes.Length) bytes, decoded as iso-8859-1" }
  } catch {
    if ($debug) { Write-Output "DEBUG: WebClient download failed, falling back to Invoke-WebRequest: $($_.Exception.Message)" }
    $html = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10).Content
  }

  # Map of possible icon base names (without prefix/suffix) to metric keys
  $iconMap = @{
    'tensaoEntrada' = 'tensao_entrada'
    'tensaoSaida' = 'tensao_saida'
    'potenciaSaida' = 'potencia_saida'
    'porcentagemTensaoBateria' = 'carga_bateria'
    'frequenciaSaida' = 'frequencia_saida'
    'temperatura' = 'temperatura'
  }

  # initialize results as nulls
  $result = @{
    tensao_entrada = $null
    potencia_saida  = $null
    carga_bateria   = $null
    tensao_saida    = $null
    frequencia_saida= $null
    temperatura     = $null
  }
  # only capture the normalized numeric results required by the template

  # Find img/icon followed by the DigitalValor div and capture both icon name and raw value
  $pattern = '<img[^>]*src=["'']?[^"'']*?(ico_[^"'']+)["'']?[^>]*>[\s\S]*?<div[^>]*class=["'']DigitalValor["''][^>]*>([\s\S]*?)</div>'
  $matches = [regex]::Matches($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($debug) { Write-Output "DEBUG: found $($matches.Count) icon/DigitalValor pairs" }
  foreach ($m in $matches) {
    $icon = $m.Groups[1].Value
    $raw  = $m.Groups[2].Value
    if ($debug) { Write-Output "DEBUG: raw pair -> icon='$icon' value='$raw'" }
    # normalize icon name: remove prefix 'ico_' and any file extension
    $iconKey = ($icon -replace '^ico_', '') -replace '\..*$', ''
    # prepare numeric parse placeholder and normalize value
    $numeric = $null
    $clean = ($raw -replace '[^0-9,\.-]', '') -replace ',','.'
    if ($clean -ne '') {
      try { $numeric = [double]$clean } catch { $numeric = $null }
    }

    if ($iconMap.ContainsKey($iconKey)) {
      $metric = $iconMap[$iconKey]
      if ($numeric -ne $null) {
        if ($numeric -eq [math]::truncate($numeric)) { $result[$metric] = [int]$numeric } else { $result[$metric] = $numeric }
      } else {
        $result[$metric] = $null
      }
    }
  }

  # --- Fetch status/info page to extract flags and last event ---
  $infoHtml = ''
  try {
    if ($debug) { Write-Output "DEBUG: fetching status URL $url - replacing path with /s2/atualizaInfo.action" }
    $infoUrl = "http://$($hostParam):$portParam/s2/atualizaInfo.action"
    try {
      $bytes2 = $wc.DownloadData($infoUrl)
      $infoHtml = $enc.GetString($bytes2)
      if ($debug) { Write-Output "DEBUG: downloaded $($bytes2.Length) bytes from status endpoint" }
    } catch {
      if ($debug) { Write-Output "DEBUG: WebClient download failed for status endpoint, falling back to Invoke-WebRequest: $($_.Exception.Message)" }
      $infoHtml = (Invoke-WebRequest -UseBasicParsing -Uri $infoUrl -Method POST -TimeoutSec 10).Content
    }
  } catch {
    if ($debug) { Write-Output "DEBUG: failed to fetch status endpoint: $($_.Exception.Message)" }
    $infoHtml = ''
  }

  # default status flags
  $status_rede_eletrica = 0
  $status_bateria = 0
  $status_ups = 0
  $status_teste = 0
  $status_alerta = 0
  $status_gateway_mobile = 0
  $status_potencia_elevada = 0
  $ultimo_evento = ''
  $ultimo_evento_data = ''

  if ($infoHtml -ne '') {
    # parse muda("statusid",'On'/'Off') calls
    $rxStatus = 'muda\("(?<id>status[^"]+)"\s*,\s*''(?<state>On|Off)''\);'
    $statusMatches = [regex]::Matches($infoHtml, $rxStatus, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($sm in $statusMatches) {
      $id = $sm.Groups['id'].Value
      $state = $sm.Groups['state'].Value
      $val = if ($state -ieq 'On') { 1 } else { 0 }
      switch ($id) {
        'statusredeEletrica' { $status_rede_eletrica = $val }
        'statusbateria'      { $status_bateria = $val }
        'statusups'          { $status_ups = $val }
        'statusteste'        { $status_teste = $val }
        'statusalerta'       { $status_alerta = $val }
        'statusgatewaymobile'{ $status_gateway_mobile = $val }
        'statusPotenciaElevada'{ $status_potencia_elevada = $val }
        default { }
      }
    }

    # extract last event description and dataStr if present
    try {
      $mEvt = [regex]::Match($infoHtml, '\$\("#descricaoEvento"\)\.html\("(?<evt>[^"]*)"\);')
      if ($mEvt.Success) { $ultimo_evento = $mEvt.Groups['evt'].Value }
    } catch { }
    try {
      $mDate = [regex]::Match($infoHtml, 'var dataStr = "(?<ds>[^"]+)";')
      if ($mDate.Success) { $ultimo_evento_data = $mDate.Groups['ds'].Value }
    } catch { }
  }

  # fallback: if nothing matched as icon pairs, list all DigitalValor entries for debugging
  if ($matches.Count -eq 0) {
    $dvMatches = [regex]::Matches($html, '<div[^>]*class=["'']DigitalValor["''][^>]*>([\s\S]*?)</div>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($debug) { Write-Output "DEBUG: found $($dvMatches.Count) DigitalValor entries (fallback)" }
    $i = 0
    foreach ($dm in $dvMatches) {
      $raw = $dm.Groups[1].Value
      if ($debug) { Write-Output "DEBUG: DigitalValor[$i] = '$raw'" }
      $i++
    }
  }

  # agent primary IPv4 address (non-loopback)
  try {
    $agent_ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notmatch '^(127|169\.254)\.' -and $_.IPAddress -notmatch ':' } |
           Select-Object -ExpandProperty IPAddress -First 1)
  } catch {
    $agent_ip = $env:COMPUTERNAME
  }
  if (-not $agent_ip) {
    try { $agent_ip = ([System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString } catch { $agent_ip = $env:COMPUTERNAME }
  }

  $output = [ordered]@{
    collector_host = $hostParam
    collector_port = $portParam
    agent_ip       = $agent_ip
    timestamp      = [int64](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds)
  }

  foreach ($k in $result.Keys) { $output[$k] = $result[$k] }

  # attach parsed status flags and last event (from atualizaInfo.action)
  $output['status_rede_eletrica'] = $status_rede_eletrica
  $output['status_bateria'] = $status_bateria
  $output['status_ups'] = $status_ups
  $output['status_teste'] = $status_teste
  $output['status_alerta'] = $status_alerta
  $output['status_gateway_mobile'] = $status_gateway_mobile
  $output['status_potencia_elevada'] = $status_potencia_elevada
  $output['ultimo_evento'] = $ultimo_evento
  $output['ultimo_evento_data'] = $ultimo_evento_data


  $output | ConvertTo-Json -Compress -Depth 4

} catch {
  # On error, return a JSON object with an 'error' field so Zabbix can detect and alert on it.
  try {
    if (-not [string]::IsNullOrEmpty($agent_ip)) {
      $agent_ip = $agent_ip
    } else {
      $agent_ip = $env:COMPUTERNAME
    }
  } catch {
    $agent_ip = $env:COMPUTERNAME
  }

  $errorOutput = [ordered]@{
    collector_host = $hostParam
    collector_port = $portParam
    agent_ip       = $agent_ip
    timestamp      = [int64](([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds)
    error          = $_.Exception.Message
  }

  # Emit JSON so dependent items' JSONPATH preprocessing can be used to detect errors.
  $errorOutput | ConvertTo-Json -Compress -Depth 4

  # Exit with success code so Zabbix receives the JSON payload reliably.
  exit 0
}