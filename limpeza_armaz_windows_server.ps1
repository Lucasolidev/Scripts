<#
.SYNOPSIS
    Analisa o repositorio de componentes (WinSxS) no Windows Server e executa a limpeza se recomendado.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Executa 'Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore' e, caso a limpeza seja recomendada,
    inicia a operacao 'Dism.exe /Online /Cleanup-Image /StartComponentCleanup'.
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1 -WhatIf
.NOTES
    Versao: 1.2
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7.
    Requer privilegios de Administrador para operacoes do DISM.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param()

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'
$detalheLimpeza = 'Nao executada'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Limpeza da Pasta Updates (WinSxS) v1.2" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    $etapa = 'Analise do Component Store'
    Write-Host "`nIniciando analise do repositorio de componentes (WinSxS)..." -ForegroundColor Cyan
    Write-Host "(Essa operacao pode demorar alguns minutos. Aguarde...)" -ForegroundColor Yellow

    $argumentosAnalise = @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore', '/NoRestart')
    $analise = & Dism.exe @argumentosAnalise 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "O DISM falhou durante a analise do repositorio (codigo de saida: $LASTEXITCODE)."
    }

    Write-Host "`n$analise" -ForegroundColor White

    $padraoLimpezaRecomendada = '(Limpeza.*Componentes Recomendada\s*:\s*Sim)|(Component Store Cleanup Recommended\s*:\s*Yes)'

    if ($analise -match $padraoLimpezaRecomendada) {
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host " Limpeza RECOMENDADA pelo sistema operacional!            " -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green

        if ($PSCmdlet.ShouldProcess('WinSxS Component Store', 'Executar StartComponentCleanup')) {
            $etapa = 'Execucao da Limpeza (StartComponentCleanup)'

            $espacoLivreAntes = (Get-PSDrive -Name C).Free

            $argumentosLimpeza = @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/NoRestart')
            & Dism.exe @argumentosLimpeza

            $codigoDism = $LASTEXITCODE
            if ($codigoDism -ne 0) {
                throw "O DISM falhou durante a limpeza (codigo de saida: $codigoDism)."
            }

            $espacoLivreDepois = (Get-PSDrive -Name C).Free
            $liberadoBytes = $espacoLivreDepois - $espacoLivreAntes

            if ($liberadoBytes -gt 0) {
                $liberadoMB = [math]::Round($liberadoBytes / 1MB, 2)
                $liberadoGB = [math]::Round($liberadoBytes / 1GB, 2)
                $detalheLimpeza = "Espaco liberado: $liberadoMB MB ($liberadoGB GB)"
                Write-Host "`n$detalheLimpeza" -ForegroundColor Green
            }
            else {
                $detalheLimpeza = 'Limpeza concluida sem liberacao imediata de espaco adicional'
                Write-Host "`n$detalheLimpeza" -ForegroundColor Yellow
            }

            $status = 'Limpeza concluida com exito'
            $corStatus = 'Green'
            $codigoSaida = 0
        }
        elseif ($WhatIfPreference) {
            $status = 'Simulacao concluida; nenhuma alteracao aplicada'
            $corStatus = 'Yellow'
            $detalheLimpeza = 'Simulacao de limpeza'
            $codigoSaida = 0
        }
        else {
            $status = 'Cancelado pelo operador; nenhuma alteracao aplicada'
            $corStatus = 'Yellow'
            $codigoSaida = 2
        }
    }
    else {
        Write-Host "==========================================================" -ForegroundColor Yellow
        Write-Host " Limpeza NAO e necessaria no momento.                     " -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Yellow
        $status = 'Analise concluida (Limpeza desnecessaria)'
        $corStatus = 'Green'
        $detalheLimpeza = 'Repositorio saudavel'
        $codigoSaida = 0
    }
}
catch {
    Write-Error -Message "Falha na etapa: $etapa. A operacao foi interrompida." -ErrorAction Continue
    $status = 'Falha durante a execucao'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:          $status" -ForegroundColor $corStatus
Write-Host "  - Resultado WinSxS: $detalheLimpeza" -ForegroundColor White
Write-Host "  - Codigo de saida: $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

exit $codigoSaida
