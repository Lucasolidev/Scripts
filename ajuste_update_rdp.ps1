<#
.SYNOPSIS
    Ajusta configuracoes de registro para suprimir avisos de redirecionamento no RDP.
.DESCRIPTION
    Script PowerShell compativel com versoes antigas do PowerShell.
    Cria a chave e o valor DWORD 'RedirectionWarningDialogVersion' em HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services\Client.
.EXAMPLE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/lucasolidev/scripts/main/ajuste_update_rdp.ps1 | iex
.VERSION
    1.0
.NOTES
    Requer privilegios de Administrador.
#>

Write-Host " Script de ajuste de registro do RDP v1.0" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Aplicando configuracao no registro do Windows..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

try {
    $registryPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services\Client"
    $name = "RedirectionWarningDialogVersion"
    $value = 1

    # Cria o caminho base no registro caso ele nao exista
    if (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    # Aplica/Atualiza o valor na chave de registro
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    
    Write-Host "`nConfiguracao aplicada com exito!" -ForegroundColor Green
} catch {
    Write-Host "`nOcorreu um erro ao tentar aplicar a configuracao no registro." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
