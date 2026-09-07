<#
.SYNOPSIS
    Agenda o reinicio do Windows para um horario especifico (HH:MM).
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Permite digitar a hora alvo e agenda um shutdown do Windows com a diferenca de segundos calculada.
.EXAMPLE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.ps1 | iex
.VERSION
    1.1
.NOTES
    Requer privilegios basicos para agendar o reinicio.
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Agendamento de Reinicio v1.1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Solicita a hora no formato HH:MM (ex: 23:30)
$horaAlvo = Read-Host "Digite o horario que deseja reiniciar (formato HH:MM)"

try {
    # Converte a entrada para um objeto de data/hora
    $dataAlvo = [DateTime]::Parse($horaAlvo)
    
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

    # Executa o comando de shutdown do Windows
    shutdown.exe /r /t $segundos /f | Out-Null
    
    Write-Host "`nAgendamento de reinicio criado com exito!" -ForegroundColor Green
}
catch {
    Write-Host "`nOcorreu um erro ao tentar agendar o reinicio." -ForegroundColor Red
    Write-Host "Erro: Formato de hora invalido. Use o formato HH:MM (ex: 14:30)." -ForegroundColor Red
}

Write-Host "`nPressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
