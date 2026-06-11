# Para ver o script no terminal powershell
# Invoke-RestMethod -Uri "https://raw.githubusercontent.com/lucasolidev/linux/main/agendar_reinicio.ps1"

# Para executar o script pelo powerhell
# irm https://raw.githubusercontent.com/lucasolidev/linux/main/agendar_reinicio.ps1 | iex

# Permissão de Execução: Se for a primeira vez que você executa um script PowerShell, pode ser necessário liberar a execução. Abra o PowerShell como Administrador e digite:
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Solicita a hora no formato HH:MM (ex: 23:30)
$horaAlvo = Read-Host "Digite o horário que deseja reiniciar (formato HH:MM)"

try {
    # Converte a entrada para um objeto de data/hora
    $dataAlvo = [DateTime]::Parse($horaAlvo)
    
    # Se a hora informada já passou hoje, agenda para amanhã
    if ($dataAlvo -lt (Get-Date)) {
        $dataAlvo = $dataAlvo.AddDays(1)
    }

    # Calcula a diferença em segundos
    $diferenca = ($dataAlvo - (Get-Date)).TotalSeconds
    $segundos = [math]::Round($diferenca)

    Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "O computador será reiniciado em $segundos segundos." -ForegroundColor Cyan
    Write-Host "Horário agendado: $dataAlvo" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
    
    # Informação sobre como cancelar
    Write-Host "IMPORTANTE: Para CANCELAR este reinício, abra o Prompt de Comando" -ForegroundColor White
    Write-Host "ou PowerShell e digite o comando: shutdown /a" -ForegroundColor Green
    Write-Host "--------------------------------------------------------" -ForegroundColor Yellow

    # Executa o comando de shutdown do Windows
    shutdown.exe /r /t $segundos /f
}
catch {
    Write-Host "Erro: Formato de hora inválido. Use o formato HH:MM (ex: 14:30)." -ForegroundColor Red
}

Write-Host "`nPressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
