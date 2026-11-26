# ==============================================================================
# Execucao recomendada (copiar e colar comando unico no PowerShell como Administrador):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/limpeza_armaz_windows_server.ps1 | iex
#
# Execucao remota com /ResetBase (remove versoes antigas de componentes substituidos):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/limpeza_armaz_windows_server.ps1))) -ResetBase
# ==============================================================================

<#
.SYNOPSIS
    Analisa e executa a limpeza do repositorio de componentes (WinSxS) no Windows Server e Windows 11.
.DESCRIPTION
    Script PowerShell compativel do Windows Server 2012 (PowerShell 3.0) ate Windows Server 2025 e Windows 11 (PowerShell 5.1 / 7).
    Executa a analise (/AnalyzeComponentStore) em builds compativeis (Server 2012 R2 / 8.1 ou superior)
    e a limpeza (/StartComponentCleanup), tratando codigos de retorno do DISM (incluindo 3010) e medindo o espaco liberado.
.PARAMETER ResetBase
    Quando informado em sistemas compativeis (Server 2012 R2 / Windows 8.1 ou superior), adiciona '/ResetBase'
    ao comando '/StartComponentCleanup' para remover versoes antigas de componentes ja substituidos
    (impede a desinstalacao de atualizacoes ja instaladas).
.PARAMETER ConfirmarResetBaseIrreversivel
    Quando informado em conjunto com -ResetBase, dispensa a confirmacao textual interativa para
    automacoes nao-interativas conscientes do impacto irreversivel do /ResetBase.
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1 -ResetBase
.EXAMPLE
    .\limpeza_armaz_windows_server.ps1 -ResetBase -WhatIf
.NOTES
    Versao: 1.6
    Requisitos: PowerShell 3.0 ou superior (Windows Server 2012, 2012 R2, 2016, 2019, 2022, 2025 e Windows 10/11).
    Privilegios: Requer privilegios de Administrador para operacoes do DISM (validacao realizada em tempo
    de execucao para manter compatibilidade com PowerShell 3.0, -WhatIf e Invoke-Expression).
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento pelo operador.
#>

#Requires -Version 3.0

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ResetBase,

    [Parameter(Mandatory = $false)]
    [switch]$ConfirmarResetBaseIrreversivel
)

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'
$codigoDismErro = $null
$detalheEspaco = 'Nao calculado'
$reinicioNecessario = $false

function Get-DismCaminho {
    <#
    .SYNOPSIS
        Resolve o caminho correto do Dism.exe, incluindo execucao a partir de PowerShell 32-bit em SO 64-bit.
    #>
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $caminhoSysnative = Join-Path -Path $env:SystemRoot -ChildPath 'Sysnative\Dism.exe'
        if (Test-Path -LiteralPath $caminhoSysnative) {
            return $caminhoSysnative
        }
    }

    $caminhoSystem32 = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Dism.exe'
    if (Test-Path -LiteralPath $caminhoSystem32) {
        return $caminhoSystem32
    }

    return 'Dism.exe'
}

function Get-NumeroBuildSistema {
    <#
    .SYNOPSIS
        Obtem o numero de build do Windows via registro (compativel com Server 2012 a Windows 11).
    #>
    $caminhoVersao = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if (Test-Path -LiteralPath $caminhoVersao) {
        $dados = Get-ItemProperty -LiteralPath $caminhoVersao -ErrorAction SilentlyContinue
        if ($null -ne $dados -and -not [string]::IsNullOrEmpty($dados.CurrentBuildNumber)) {
            [int]$build = 0
            if ([int]::TryParse($dados.CurrentBuildNumber, [ref]$build)) {
                return $build
            }
        }
    }

    return [int][System.Environment]::OSVersion.Version.Build
}

function Test-ReinicioPendente {
    <#
    .SYNOPSIS
        Verifica chaves de registro padrao do Windows para identificar reinicializacao pendente.
    #>
    $chavesPendencia = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($chave in $chavesPendencia) {
        if (Test-Path -LiteralPath $chave) {
            return $true
        }
    }

    return $false
}

function Invoke-DismEtapa {
    <#
    .SYNOPSIS
        Executa o Dism.exe exibindo a saida em tempo real e valida o codigo de retorno.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Exibicao de alerta de codigo 3010 no console')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CaminhoDism,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NomeEtapa,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Argumentos,

        [Parameter(Mandatory = $true)]
        [ref]$ReinicioDetectado
    )

    # Chamada direta sem capturar saida garante exibicao ao vivo da barra de progresso do DISM
    & $CaminhoDism @Argumentos
    $codigoRetorno = $LASTEXITCODE

    if ($null -eq $codigoRetorno) {
        throw "Nao foi possivel obter o codigo de retorno do DISM na etapa: $NomeEtapa."
    }

    # 0 = sucesso; 3010 = sucesso com reinicializacao recomendada (ERROR_SUCCESS_REBOOT_REQUIRED)
    if ($codigoRetorno -notin @(0, 3010)) {
        $excecao = New-Object System.Exception("O DISM falhou na etapa: $NomeEtapa.")
        $excecao.Data['CodigoDism'] = $codigoRetorno
        throw $excecao
    }

    if ($codigoRetorno -eq 3010) {
        $ReinicioDetectado.Value = $true
        Write-Host "`n[AVISO] A etapa '$NomeEtapa' retornou codigo 3010 (reinicializacao recomendada)." -ForegroundColor Yellow
    }
}

$identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identidade
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$textoPrivilegio = if ($isAdmin) { 'Administrador' } else { 'Usuario padrao (insuficiente para DISM)' }
$dataExecucao = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Script de Limpeza do Component Store (WinSxS) v1.6" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Computador: $env:COMPUTERNAME | Data/Hora: $dataExecucao" -ForegroundColor DarkGray
Write-Host "  Privilegio: $textoPrivilegio" -ForegroundColor DarkGray

$acaoPlanejada = if ($ResetBase) {
    'Analisar e limpar Component Store (WinSxS) com /ResetBase'
}
else {
    'Analisar e limpar Component Store (WinSxS)'
}

try {
    if (($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess($env:COMPUTERNAME, $acaoPlanejada)) {
        if (-not $isAdmin) {
            Write-Host "`nERRO: Este script requer privilegios de Administrador para executar o DISM." -ForegroundColor Red
            Write-Host "Por favor, abra o PowerShell como Administrador e execute novamente." -ForegroundColor Yellow
            $status = 'Falha de privilegios (requer Administrador)'
            $corStatus = 'Red'
            $codigoSaida = 1
        }
        else {
            $caminhoDism = Get-DismCaminho
            $buildSistema = Get-NumeroBuildSistema
            # /AnalyzeComponentStore e /ResetBase foram introduzidos no Windows 8.1 / Server 2012 R2 (build 9600)
            $suportaRecursosAvancadosDism = ($buildSistema -ge 9600)

            $confirmadoResetBase = $true
            if ($ResetBase -and $suportaRecursosAvancadosDism -and (-not $ConfirmarResetBaseIrreversivel)) {
                Write-Host "`n[ATENCAO] A opcao -ResetBase remove versoes antigas de componentes substituidos." -ForegroundColor Yellow
                Write-Host "Apos a execucao, nao sera possivel desinstalar atualizacoes do Windows ja instaladas." -ForegroundColor Yellow
                $respostaResetBase = Read-Host 'Digite RESETBASE para confirmar e prosseguir'
                if ($respostaResetBase -cne 'RESETBASE') {
                    $confirmadoResetBase = $false
                    $status = 'Cancelado pelo operador na confirmacao de ResetBase'
                    $corStatus = 'Yellow'
                    $codigoSaida = 2
                }
            }

            if ($confirmadoResetBase) {
                $letraDiscoSistema = ($env:SystemDrive -replace ':', '').Trim()
                $espacoAntesBytes = (Get-PSDrive -Name $letraDiscoSistema).Free
                $reinicioPendenteAntes = Test-ReinicioPendente

                if ($reinicioPendenteAntes) {
                    $reinicioNecessario = $true
                    Write-Host "`n[AVISO] Reinicializacao pendente detectada antes da execucao; a limpeza pode reter arquivos ate o proximo boot." -ForegroundColor Yellow
                }

                # -----------------------------------------------------------------
                # Etapa 1: Verifica (AnalyzeComponentStore)
                # -----------------------------------------------------------------
                $etapa = 'Analise do Component Store'
                Write-Host "`n==========================================================" -ForegroundColor Cyan
                Write-Host " Etapa 1/2: Analisando o Component Store..." -ForegroundColor Cyan
                Write-Host "==========================================================" -ForegroundColor Cyan

                if ($suportaRecursosAvancadosDism) {
                    Write-Host "(Aguarde a conclusao da verificacao pelo DISM...)`n" -ForegroundColor Yellow
                    Invoke-DismEtapa -CaminhoDism $caminhoDism -NomeEtapa $etapa -Argumentos @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore') -ReinicioDetectado ([ref]$reinicioNecessario)
                }
                else {
                    Write-Host "[AVISO] Build $buildSistema detectada (Windows Server 2012 / 8). A flag /AnalyzeComponentStore requer build 9600+ (Server 2012 R2+)." -ForegroundColor Yellow
                    Write-Host "Prosseguindo diretamente para a Etapa 2 (Limpeza)..." -ForegroundColor Yellow
                }

                # -----------------------------------------------------------------
                # Etapa 2: Limpeza (StartComponentCleanup)
                # -----------------------------------------------------------------
                $etapa = 'Limpeza do Component Store'
                $argumentosLimpeza = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
                $usandoResetBase = $false

                if ($ResetBase) {
                    if ($suportaRecursosAvancadosDism) {
                        $argumentosLimpeza += '/ResetBase'
                        $usandoResetBase = $true
                    }
                    else {
                        Write-Host "`n[AVISO] A flag /ResetBase nao e suportada na build $buildSistema (requer Server 2012 R2+). Executando apenas /StartComponentCleanup." -ForegroundColor Yellow
                    }
                }

                Write-Host "`n==========================================================" -ForegroundColor Cyan
                Write-Host " Etapa 2/2: Executando a Limpeza do Component Store..." -ForegroundColor Cyan
                if ($usandoResetBase) {
                    Write-Host " Modo: /StartComponentCleanup /ResetBase" -ForegroundColor Yellow
                }
                Write-Host "==========================================================" -ForegroundColor Cyan
                Write-Host "(Aguarde a conclusao da limpeza pelo DISM...)`n" -ForegroundColor Yellow

                Invoke-DismEtapa -CaminhoDism $caminhoDism -NomeEtapa $etapa -Argumentos $argumentosLimpeza -ReinicioDetectado ([ref]$reinicioNecessario)

                $espacoDepoisBytes = (Get-PSDrive -Name $letraDiscoSistema).Free
                $diferencaBytes = $espacoDepoisBytes - $espacoAntesBytes
                if ($diferencaBytes -gt 0) {
                    $liberadoMB = [math]::Round($diferencaBytes / 1MB, 2)
                    $liberadoGB = [math]::Round($diferencaBytes / 1GB, 2)
                    $detalheEspaco = "$liberadoMB MB ($liberadoGB GB) liberados em $env:SystemDrive"
                }
                else {
                    $detalheEspaco = "Sem liberacao imediata mensuravel em $env:SystemDrive"
                }

                $status = 'Processo concluido com exito'
                $corStatus = 'Green'
                $codigoSaida = 0
            }
        }
    }
    elseif ($WhatIfPreference) {
        $status = 'Simulacao concluida; nenhuma limpeza executada'
        $corStatus = 'Yellow'
        $codigoSaida = 0
    }
    else {
        $status = 'Cancelado pelo operador; nenhuma limpeza executada'
        $corStatus = 'Yellow'
        $codigoSaida = 2
    }
}
catch {
    if ($null -ne $_.Exception -and $null -ne $_.Exception.Data -and $null -ne $_.Exception.Data['CodigoDism']) {
        $codigoDismErro = $_.Exception.Data['CodigoDism']
    }

    Write-Host "`n==========================================================" -ForegroundColor Red
    Write-Host "  [ERRO] Falha na etapa: $etapa" -ForegroundColor Red
    if ($null -ne $codigoDismErro) {
        Write-Host "  Codigo de retorno do DISM: $codigoDismErro" -ForegroundColor Red
    }
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "A operacao foi interrompida antes de concluir todas as etapas." -ForegroundColor Yellow
    $status = 'Falha durante a execucao'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:            $status" -ForegroundColor $corStatus
Write-Host "  - Espaco WinSxS:     $detalheEspaco" -ForegroundColor White
if ($reinicioNecessario) {
    Write-Host "  - Reinicializacao:   Recomendada (pendencia ou codigo 3010)" -ForegroundColor Yellow
}
else {
    Write-Host "  - Reinicializacao:   Nao necessaria" -ForegroundColor White
}
if ($null -ne $codigoDismErro) {
    Write-Host "  - Codigo erro DISM:  $codigoDismErro" -ForegroundColor Red
}
if ($codigoSaida -eq 0) {
    $descricaoCodigoSaida = if ($WhatIfPreference) { '0 (Simulacao concluida sem alteracoes)' } else { '0 (Sucesso - concluido sem erros)' }
}
elseif ($codigoSaida -eq 2) {
    $descricaoCodigoSaida = '2 (Cancelado pelo operador)'
}
else {
    $descricaoCodigoSaida = "$codigoSaida (Falha - operacao interrompida por erro)"
}
Write-Host "  - Codigo de saida:   $descricaoCodigoSaida" -ForegroundColor $corStatus
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

# Quando executado via Invoke-Expression (iex), usa return para nao fechar a janela do PowerShell do operador
if ([string]::IsNullOrEmpty($PSCommandPath)) {
    return
}

exit $codigoSaida
