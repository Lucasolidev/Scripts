<#
.SYNOPSIS
    Agenda o reinicio do Windows para um horario especifico (HH:MM).
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Permite digitar a hora alvo ou passar via parametro, agendando o shutdown do Windows.
.EXAMPLE
    .\agendar_reinicio.ps1
    .\agendar_reinicio.ps1 -Horario 23:30
.VERSION
    1.2
.NOTES
    Requer privilegios de Administrador para agendar o reinicio.
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Horario
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Agendamento de Reinicio v1.2" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Limpa teclas pendentes no buffer do teclado antes da solicitacao interativa
if ($Host.UI.RawUI -and ($Host.UI.RawUI | Get-Member -Name FlushInputBuffer)) {
    $Host.UI.RawUI.FlushInputBuffer()
}

$dataAlvo = $null
$horaInformada = $Horario

while ($null -eq $dataAlvo) {
    if ([string]::IsNullOrWhiteSpace($horaInformada)) {
        $horaInformada = Read-Host "Digite o horario que deseja reiniciar (formato HH:MM)"
    }

    if ([string]::IsNullOrWhiteSpace($horaInformada)) {
        Write-Host "Horario nao informado. Por favor, digite um horario valido." -ForegroundColor Yellow
        $horaInformada = $null
        continue
    }

    $horaInformada = $horaInformada.Trim()

    try {
        $dataAlvo = [DateTime]::Parse($horaInformada)
    }
    catch {
        Write-Host "Erro: Formato de hora invalido. Use o formato HH:MM (ex: 14:30)." -ForegroundColor Red
        $horaInformada = $null
        $dataAlvo = $null
    }
}

# Se a hora informada ja passou hoje, agenda para amanha
if ($dataAlvo -lt (Get-Date)) {
    $dataAlvo = $dataAlvo.AddDays(1)
}

# Calcula a diferenca em segundos
$diferenca = ($dataAlvo - (Get-Date)).TotalSeconds
$segundos = [math]::Round($diferenca)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " O computador sera reiniciado em $segundos segundos." -ForegroundColor Green
Write-Host " Horario agendado: $dataAlvo" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# Informacao sobre como cancelar
Write-Host " IMPORTANTE: Para CANCELAR este reinicio, abra o Prompt de" -ForegroundColor Yellow
Write-Host " Comando ou PowerShell e digite o comando: shutdown /a" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# Cancela agendamento previo para evitar conflitos (silenciosamente)
shutdown.exe /a 2>$null | Out-Null

# Executa o comando de shutdown do Windows
shutdown.exe /r /t $segundos /f 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host "  [OK] RESUMO DA EXECUCAO - REINICIO AGENDADO COM EXITO" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  - Horario Alvo:          $dataAlvo" -ForegroundColor White
    Write-Host "  - Tempo Restante:        $segundos segundos" -ForegroundColor White
    Write-Host "  - Comando de Cancelar:   shutdown /a" -ForegroundColor White
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
}
else {
    Write-Host "`nOcorreu um erro ao executar shutdown.exe (Codigo de saida: $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Certifique-se de executar o PowerShell como Administrador." -ForegroundColor Red
}

Write-Host "`nPressione qualquer tecla para sair..."
if ($Host.UI.RawUI -and ($Host.UI.RawUI | Get-Member -Name FlushInputBuffer)) {
    $Host.UI.RawUI.FlushInputBuffer()
}
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
