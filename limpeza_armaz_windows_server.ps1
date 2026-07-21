<#
.SYNOPSIS
    Analisa o repositório de componentes (WinSxS) no Windows Server e executa a limpeza se recomendado.
.DESCRIPTION
    Script PowerShell compatível com versões antigas do PowerShell (2.0+).
    Executa 'Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore' e, caso a limpeza seja recomendada ('Sim' / 'Yes'),
    inicia automaticamente 'Dism.exe /Online /Cleanup-Image /StartComponentCleanup'.
.EXAMPLE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/limpeza_armaz_windows_server.ps1 | iex
.NOTES
    Requer privilégios de Administrador.
#>

# Configura codificação de saída do console para tratar acentuação corretamente
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Iniciando análise do repositório de componentes (WinSxS)..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Executa o comando de análise e armazena a saída
$analise = & Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 | Out-String

# Exibe o resultado da análise no console
Write-Host $analise

# Expressão regular para identificar se a limpeza foi recomendada (suporta Português e Inglês)
$padraoLimpezaRecomendada = '(Limpeza do Repositório de Componentes Recomendada\s*:\s*Sim)|(Component Store Cleanup Recommended\s*:\s*Yes)'

if ($analise -match $padraoLimpezaRecomendada) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Limpeza RECOMENDADA! Executando StartComponentCleanup... " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    
    # Executa a limpeza do repositório
    & Dism.exe /Online /Cleanup-Image /StartComponentCleanup
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nOperação de limpeza concluída com êxito!" -ForegroundColor Green
    } else {
        Write-Host "`nOcorreu um erro durante a limpeza. Código de saída: $LASTEXITCODE" -ForegroundColor Red
    }
} else {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " Limpeza NÃO é necessária no momento.                     " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
}
