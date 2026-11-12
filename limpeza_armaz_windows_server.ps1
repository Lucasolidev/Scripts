<#
.SYNOPSIS
    Analisa e executa a limpeza do repositorio de componentes (WinSxS) no Windows Server.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes do Windows Server.
    Executa sequencialmente a analise (/AnalyzeComponentStore) e a limpeza (/StartComponentCleanup).
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1
.NOTES
    Versao: 1.3
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7.
    Requer privilegios de Administrador para operacoes do DISM.
    Saida: 0 = sucesso; 1 = falha.
#>

# ==============================================================================
# Execucao recomendada (copiar e colar comando unico no PowerShell como Administrador):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/limpeza_armaz_windows_server.ps1 | iex
# ==============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param()

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Limpeza do Component Store (WinSxS) v1.3" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Validacao de privilegios de Administrador (garante funcionamento mesmo via Invoke-Expression / iex)
$identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identidade
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`nERRO: Este script requer privilegios de Administrador para executar o DISM." -ForegroundColor Red
    Write-Host "Por favor, abra o PowerShell como Administrador e execute novamente.`n" -ForegroundColor Yellow
    if ([string]::IsNullOrEmpty($MyInvocation.ScriptName)) {
        return
    }
    exit 1
}

try {
    # -------------------------------------------------------------------------
    # Etapa 1: Verifica (AnalyzeComponentStore)
    # -------------------------------------------------------------------------
    $etapa = 'Analise do Component Store'
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " Etapa 1/2: Analisando o Component Store..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "(Aguarde a conclusao da verificacao pelo DISM...)`n" -ForegroundColor Yellow

    $argumentosAnalise = @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore')
    & Dism.exe @argumentosAnalise
    $codigoDismAnalise = $LASTEXITCODE

    if ($codigoDismAnalise -ne 0) {
        throw "O DISM falhou durante a analise do repositorio (codigo de saida: $codigoDismAnalise)."
    }

    # -------------------------------------------------------------------------
    # Etapa 2: Limpeza (StartComponentCleanup)
    # -------------------------------------------------------------------------
    $etapa = 'Limpeza do Component Store'
    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " Etapa 2/2: Executando a Limpeza do Component Store..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "(Aguarde a conclusao da limpeza pelo DISM...)`n" -ForegroundColor Yellow

    $argumentosLimpeza = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    & Dism.exe @argumentosLimpeza
    $codigoDismLimpeza = $LASTEXITCODE

    if ($codigoDismLimpeza -ne 0) {
        throw "O DISM falhou durante a limpeza do repositorio (codigo de saida: $codigoDismLimpeza)."
    }

    $status = 'Processo concluido com exito'
    $corStatus = 'Green'
    $codigoSaida = 0
}
catch {
    Write-Host "`n==========================================================" -ForegroundColor Red
    Write-Host "  [ERRO] Falha na etapa: $etapa" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "A operacao foi interrompida antes de concluir todas as etapas." -ForegroundColor Yellow
    $status = 'Falha durante a execucao'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:          $status" -ForegroundColor $corStatus
Write-Host "  - Codigo de saida: $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

# Quando executado via Invoke-Expression (iex), usa return para nao fechar a janela do PowerShell do operador
if ([string]::IsNullOrEmpty($MyInvocation.ScriptName)) {
    return
}

exit $codigoSaida
