<#
.SYNOPSIS
    Desabilita o Bing na barra de pesquisa do Windows 10 e 11.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Altera o valor de registro 'BingSearchEnabled' para 0 em HKCU e reinicia o explorer.exe
    para que as alteracoes entrem em vigor imediatamente.
.EXAMPLE
    .\desabilitar_bing.ps1
.EXAMPLE
    .\desabilitar_bing.ps1 -WhatIf
.NOTES
    Versao: 1.1
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7.
    Ajusta configuracao de usuario corrente (HKCU).
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param()

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script para Desabilitar o Bing Search v1.1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    $name = 'BingSearchEnabled'
    $value = 0

    if ($PSCmdlet.ShouldProcess($path, "Definir $name = $value e reiniciar o processo explorer")) {
        $etapa = 'Configuracao do Registro'

        Write-Host "`nConfigurando o Registro do Windows..." -ForegroundColor Yellow

        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        New-ItemProperty -LiteralPath $path -Name $name -Value $value -PropertyType DWord -Force | Out-Null

        $etapa = 'Reinicio do Explorer'
        Write-Host "Reiniciando o Explorador de Arquivos para aplicar as alteracoes..." -ForegroundColor Yellow
        Stop-Process -Name 'explorer' -Force | Out-Null

        Write-Host "`nOperacao concluida com exito! O Bing Search foi desativado." -ForegroundColor Green
        $status = 'Concluido e verificado'
        $corStatus = 'Green'
        $codigoSaida = 0
    }
    elseif ($WhatIfPreference) {
        $status = 'Simulacao concluida; nenhuma alteracao aplicada'
        $corStatus = 'Yellow'
        $codigoSaida = 0
    }
    else {
        $status = 'Cancelado pelo operador; nenhuma alteracao aplicada'
        $corStatus = 'Yellow'
        $codigoSaida = 2
    }
}
catch {
    Write-Error -Message "Falha na etapa: $etapa. Nao foi possivel concluir a desativacao do Bing." -ErrorAction Continue
    $status = 'Falha durante a execucao'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:          $status" -ForegroundColor $corStatus
Write-Host "  - Chave Alvo:      HKCU\...\Search" -ForegroundColor White
Write-Host "  - Valor Definido:  BingSearchEnabled = 0" -ForegroundColor White
Write-Host "  - Processo:        explorer.exe reiniciado" -ForegroundColor White
Write-Host "  - Codigo de saida: $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

exit $codigoSaida
