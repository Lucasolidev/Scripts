<#
.SYNOPSIS
    Analisa o repositorio de componentes (WinSxS) no Windows Server e executa a limpeza se recomendado.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas do PowerShell (2.0+).
    Executa 'Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore' e, caso a limpeza seja recomendada ('Sim' / 'Yes'),
    inicia automaticamente 'Dism.exe /Online /Cleanup-Image /StartComponentCleanup'.
.EXAMPLE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/limpeza_armaz_windows_server.ps1 | iex
.VERSION
    1.2
.NOTES
    Requer privilegios de Administrador.
#>

Write-Host " Script de limpeza da pasta updates (SXS) v1.2" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Iniciando analise do repositorio de componentes (WinSxS)..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Executa o comando de analise e armazena a saida
$analise = & Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 | Out-String

# Exibe o resultado da analise no console
Write-Host $analise

# Expressao regular para identificar se a limpeza foi recomendada (suporta Portugues e Ingles, ignorando caracteres corrompidos)
$padraoLimpezaRecomendada = '(Limpeza.*Componentes Recomendada\s*:\s*Sim)|(Component Store Cleanup Recommended\s*:\s*Yes)'

if ($analise -match $padraoLimpezaRecomendada) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " Limpeza RECOMENDADA! Executando StartComponentCleanup... " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    
    # Verifica espaco livre ANTES da limpeza (em bytes)
    $espacoLivreAntes = (Get-PSDrive -Name C).Free

    # Executa a limpeza do repositorio
    & Dism.exe /Online /Cleanup-Image /StartComponentCleanup
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nOperacao de limpeza concluida com exito!" -ForegroundColor Green
        
        # Verifica espaco livre DEPOIS da limpeza
        $espacoLivreDepois = (Get-PSDrive -Name C).Free
        $liberadoBytes = $espacoLivreDepois - $espacoLivreAntes
        
        if ($liberadoBytes -gt 0) {
            $liberadoMB = [math]::Round($liberadoBytes / 1MB, 2)
            $liberadoGB = [math]::Round($liberadoBytes / 1GB, 2)
            
            Write-Host "==========================================================" -ForegroundColor Cyan
            Write-Host " Espaco liberado na unidade C: $liberadoMB MB ($liberadoGB GB)" -ForegroundColor Cyan
            Write-Host "==========================================================" -ForegroundColor Cyan
        } else {
            Write-Host "==========================================================" -ForegroundColor Yellow
            Write-Host " Nenhum espaco adicional na unidade C: foi liberado." -ForegroundColor Yellow
            Write-Host "==========================================================" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nOcorreu um erro durante a limpeza. Codigo de saida: $LASTEXITCODE" -ForegroundColor Red
    }
} else {
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " Limpeza NAO e necessaria no momento.                     " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
}
