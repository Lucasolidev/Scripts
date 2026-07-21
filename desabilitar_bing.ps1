<#
.SYNOPSIS
    Desabilita o Bing na barra de pesquisa do Windows 10/11.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    Altera o registro 'BingSearchEnabled' para 0 e reinicia o explorer.exe para aplicar imediatamente.
.EXAMPLE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/desabilitar_bing.ps1 | iex
.VERSION
    1.1
.NOTES
    Pode requerer privilegios de Administrador dependendo do ambiente.
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script para Desabilitar o Bing Search v1.1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    # Altera o registro para desativar o Bing na barra de pesquisa
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $Name = "BingSearchEnabled"

    Write-Host " Configurando o Registro do Windows..." -ForegroundColor Yellow

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -Value 0 -PropertyType DWORD -Force | Out-Null

    Write-Host " Reiniciando o Explorador de Arquivos para aplicar as alteracoes..." -ForegroundColor Yellow

    # Reinicia o explorer para aplicar a alteracao imediatamente
    Stop-Process -Name explorer -Force | Out-Null

    Write-Host "`nOperacao concluida com exito! O Bing Search foi desativado." -ForegroundColor Green
} catch {
    Write-Host "`nOcorreu um erro durante a alteracao do registro." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
