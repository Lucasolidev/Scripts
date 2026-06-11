# Altera o registro para desativar o Bing na barra de pesquisa
$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
$Name = "BingSearchEnabled"

Write-Host "Configurando o Registro do Windows..." -ForegroundColor Cyan

New-ItemProperty -Path $Path -Name $Name -Value 0 -PropertyType DWORD -Force | Out-Null

Write-Host "Reiniciando o Explorador de Arquivos para aplicar as alterações..." -ForegroundColor Yellow

# Reinicia o explorer para aplicar a alteração imediatamente
Stop-Process -Name explorer -Force

Write-Host "Pronto! O Bing Search foi desativado com sucesso." -ForegroundColor Green
