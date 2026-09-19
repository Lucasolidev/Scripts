<#
.SYNOPSIS
    Ajusta configuracoes de registro para suprimir avisos de redirecionamento no RDP.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Cria a chave e o valor DWORD 'RedirectionWarningDialogVersion' em
    HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services\Client.
.EXAMPLE
    .\ajuste_update_rdp.ps1
.EXAMPLE
    .\ajuste_update_rdp.ps1 -WhatIf
.NOTES
    Versao: 1.0
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7.
    Requer privilegios de Administrador para alterar chaves em HKLM.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param()

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Ajuste de Registro do RDP v1.0" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    $registryPath = 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client'
    $name = 'RedirectionWarningDialogVersion'
    $value = 1

    if ($PSCmdlet.ShouldProcess($registryPath, "Definir $name = $value")) {
        $etapa = 'Configuracao do Registro'

        Write-Host "`nAplicando configuracao no Registro do Windows..." -ForegroundColor Cyan

        if (-not (Test-Path -LiteralPath $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        New-ItemProperty -LiteralPath $registryPath -Name $name -Value $value -PropertyType DWord -Force | Out-Null

        $propriedade = Get-ItemProperty -LiteralPath $registryPath -Name $name -ErrorAction Stop
        if ($propriedade.$name -ne $value) {
            throw "A verificacao pos-gravacao falhou para $name."
        }

        Write-Host "Configuracao aplicada com exito!" -ForegroundColor Green
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
    Write-Error -Message "Falha na etapa: $etapa. A operacao de registro nao foi concluida com exito." -ErrorAction Continue
    $status = 'Falha durante a aplicacao da configuracao'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:          $status" -ForegroundColor $corStatus
Write-Host "  - Chave Alvo:      HKLM\...\Terminal Services\Client" -ForegroundColor White
Write-Host "  - Valor Definido:  RedirectionWarningDialogVersion = 1" -ForegroundColor White
Write-Host "  - Codigo de saida: $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

exit $codigoSaida
