<#
.SYNOPSIS
    Agenda o reinicio do Windows para um horario especifico (HH:MM).
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Permite digitar a hora alvo ou passar via parametro, agendando o shutdown do Windows.
.PARAMETER Horario
    Horario no formato HH:MM (ex: 23:30) para efetuar o reinicio do sistema.
.EXAMPLE
    .\agendar_reinicio.ps1
.EXAMPLE
    .\agendar_reinicio.ps1 -Horario 23:30
.EXAMPLE
    .\agendar_reinicio.ps1 -Horario 23:30 -WhatIf
.NOTES
    Versao: 1.2
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7.
    Requer privilegios de Administrador para agendar o reinicio do sistema.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Horario
)

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Agendamento de Reinicio v1.2" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Limpa teclas pendentes no buffer do teclado antes da solicitacao interativa
if ($Host.UI.RawUI -and ($Host.UI.RawUI | Get-Member -Name 'FlushInputBuffer')) {
    $Host.UI.RawUI.FlushInputBuffer()
}

$dataAlvo = $null
$horaInformada = $Horario

try {
    while ($null -eq $dataAlvo) {
        if ([string]::IsNullOrWhiteSpace($horaInformada)) {
            $horaInformada = Read-Host 'Digite o horario que deseja reiniciar (formato HH:MM)'
        }

        if ([string]::IsNullOrWhiteSpace($horaInformada)) {
            Write-Host 'Horario nao informado. Por favor, digite um horario valido.' -ForegroundColor Yellow
            $horaInformada = $null
            continue
        }

        $horaInformada = $horaInformada.Trim()

        try {
            $dataAlvo = [DateTime]::Parse($horaInformada)
        }
        catch {
            Write-Host 'Erro: Formato de hora invalido. Use o formato HH:MM (ex: 14:30).' -ForegroundColor Red
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

    if ($PSCmdlet.ShouldProcess("Computador Local", "Agendar reinicio para $dataAlvo ($segundos segundos)")) {
        $etapa = 'Agendamento com shutdown.exe'

        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " O computador sera reiniciado em $segundos segundos." -ForegroundColor Green
        Write-Host " Horario agendado: $dataAlvo" -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Cyan

        Write-Host " IMPORTANTE: Para CANCELAR este reinicio, abra o Prompt de" -ForegroundColor Yellow
        Write-Host " Comando ou PowerShell e digite o comando: shutdown /a" -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Cyan

        # Cancela agendamento previo para evitar conflitos (silenciosamente)
        & shutdown.exe /a 2>$null | Out-Null

        # Executa o comando de shutdown do Windows
        & shutdown.exe /r /t $segundos /f 2>$null | Out-Null
        $shutdownExit = $LASTEXITCODE

        if ($shutdownExit -eq 0) {
            $status = 'Reinicio agendado com exito'
            $corStatus = 'Green'
            $codigoSaida = 0
        }
        else {
            throw "O comando shutdown.exe falhou com codigo de saida $shutdownExit."
        }
    }
    elseif ($WhatIfPreference) {
        $status = 'Simulacao concluida; nenhum agendamento aplicado'
        $corStatus = 'Yellow'
        $codigoSaida = 0
    }
    else {
        $status = 'Cancelado pelo operador; nenhum agendamento aplicado'
        $corStatus = 'Yellow'
        $codigoSaida = 2
    }
}
catch {
    Write-Error -Message "Falha na etapa: $etapa. Nao foi possivel agendar o reinicio." -ErrorAction Continue
    $status = 'Falha durante o agendamento'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:                $status" -ForegroundColor $corStatus
if ($null -ne $dataAlvo) {
    Write-Host "  - Horario Alvo:          $dataAlvo" -ForegroundColor White
    Write-Host "  - Tempo Restante:        $segundos segundos" -ForegroundColor White
}
Write-Host "  - Comando de Cancelar:   shutdown /a" -ForegroundColor White
Write-Host "  - Codigo de saida:       $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

exit $codigoSaida
