# ==============================================================================
# Execucao recomendada (copiar e colar comando unico no PowerShell como Administrador):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/Implantacao_WSL.ps1 | iex
#
# Execucao remota para criar apenas instancias descartaveis de teste (-Modo CriarTestes):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/Implantacao_WSL.ps1))) -Modo CriarTestes
# ==============================================================================

<#
.SYNOPSIS
    Prepara imagens-base do Ubuntu no WSL ou cria instancias descartaveis de teste.

.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes (Windows PowerShell 5.1 e PowerShell 7).
    No modo PrepararBases, instala e atualiza Ubuntu-26.04 e Ubuntu-24.04,
    cria o usuario solicitado, instala ShellCheck, exporta VHDX em C:\WSL,
    desregistra as instalacoes originais e reimporta as distribuicoes.

    No modo CriarTestes, importa copias independentes das imagens-base com o
    sufixo -Teste.

.PARAMETER Modo
    Define o modo de operacao: 'PrepararBases' ou 'CriarTestes'.

.PARAMETER Usuario
    Nome do usuario Linux padrao a ser criado/validado nas distribuicoes Ubuntu.

.PARAMETER SenhaSegura
    Credencial do usuario Linux como SecureString (solicitada interativamente quando omitida).

.PARAMETER UsarDistribuicoesExistentes
    Permite preparar distribuicoes Ubuntu-26.04 / Ubuntu-24.04 ja registradas no WSL.

.PARAMETER SemConfirmacao
    Dispensa a confirmacao textual 'DESREGISTRAR' antes de recriar as distribuicoes base.

.EXAMPLE
    .\Implantacao_WSL.ps1

.EXAMPLE
    .\Implantacao_WSL.ps1 -UsarDistribuicoesExistentes

.EXAMPLE
    .\Implantacao_WSL.ps1 -Modo CriarTestes

.EXAMPLE
    .\Implantacao_WSL.ps1 -Modo CriarTestes -WhatIf

.NOTES
    Versao: 1.1
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7 no Windows.
    Requer privilegios de Administrador.
    A senha e solicitada como SecureString e nao fica fixa no codigo-fonte.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento pelo operador.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SemConfirmacao', Justification = 'Utilizado pelo operador para ignorar confirmacoes')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('PrepararBases', 'CriarTestes')]
    [string]$Modo = 'PrepararBases',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$Usuario = 'administrador',

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$SenhaSegura,

    [Parameter(Mandatory = $false)]
    [switch]$UsarDistribuicoesExistentes,

    [Parameter(Mandatory = $false)]
    [switch]$SemConfirmacao
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

$WslRoot = 'C:\WSL'
$PasswordFile = Join-Path -Path $WslRoot -ChildPath 'wsl-pass.txt'
$WslConfigFile = Join-Path -Path $env:USERPROFILE -ChildPath '.wslconfig'
$BaseDistros = @('Ubuntu-26.04', 'Ubuntu-24.04')
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$SenhaTexto = $null
$ConfirmacaoSegura = $null
$ConfirmacaoTexto = $null

function Show-TituloSecao {
    <#
    .SYNOPSIS
        Exibe um cabecalho de etapa padronizado no console.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Cabecalho visual de console para o operador')]
    param([Parameter(Mandatory)][string]$Message)

    Write-Host '' -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
}

function ConvertTo-TextoPlano {
    <#
    .SYNOPSIS
        Converte um SecureString em texto puro temporario liberando o buffer BSTR.
    #>
    param([Parameter(Mandatory)][System.Security.SecureString]$SecureValue)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-ComandoNativo {
    <#
    .SYNOPSIS
        Executa um comando nativo validando o codigo de saida imediatamente.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    & $FilePath @Arguments
    $exitCodeNativo = $LASTEXITCODE
    if ($exitCodeNativo -ne 0) {
        throw "$FailureMessage (codigo de saida: $exitCodeNativo)."
    }
}

function Get-DistribuicaoWsl {
    <#
    .SYNOPSIS
        Lista as distribuicoes atualmente registradas no WSL.
    #>
    $output = & wsl.exe --list --quiet 2>$null
    $wslExit = $LASTEXITCODE
    if ($wslExit -ne 0) {
        throw "Nao foi possivel consultar as distribuicoes registradas no WSL (codigo $wslExit)."
    }

    return @(
        $output |
            ForEach-Object { ($_ -replace "`0", '').Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Assert-DiretorioInstalacaoVazio {
    <#
    .SYNOPSIS
        Garante que o diretorio de destino da distribuicao exista e esteja vazio.
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
        return
    }

    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) {
        throw "O diretorio de instalacao nao esta vazio: $Path"
    }
}

function Save-ConfiguracaoWsl {
    <#
    .SYNOPSIS
        Grava .wslconfig preservando eventual configuracao anterior em backup.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Aviso visual de backup preservado no console')]
    param()

    Show-TituloSecao -Message "Criando $WslConfigFile"

    $content = @'
[wsl2]
memory=2GB
processors=2
swap=512MB
localhostForwarding=true
vmIdleTimeout=600000
'@
    $content += [Environment]::NewLine

    if (Test-Path -LiteralPath $WslConfigFile) {
        $currentContent = [System.IO.File]::ReadAllText($WslConfigFile)
        if ($currentContent -ne $content) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupPath = "$WslConfigFile.backup-$timestamp"
            Copy-Item -LiteralPath $WslConfigFile -Destination $backupPath
            Write-Host "Configuracao anterior preservada em: $backupPath" -ForegroundColor Yellow
        }
    }

    [System.IO.File]::WriteAllText($WslConfigFile, $content, $Utf8NoBom)
}

function Save-ArquivoCredencialWsl {
    <#
    .SYNOPSIS
        Prepara ACL restrita antes de gravar o arquivo de credenciais do WSL.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Aviso de seguranca em texto puro no console')]
    param()

    Show-TituloSecao -Message "Criando $PasswordFile"
    Write-Host 'AVISO: O arquivo solicitado armazenara a senha em texto puro.' -ForegroundColor Yellow

    # Prepara arquivo vazio com ACL restrita antes de gravar o segredo
    [System.IO.File]::WriteAllText($PasswordFile, '', $Utf8NoBom)

    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $PasswordFile '/inheritance:r' '/grant:r' "${currentIdentity}:(F)" '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Null
    $icaclsExit = $LASTEXITCODE
    if ($icaclsExit -ne 0) {
        Remove-Item -LiteralPath $PasswordFile -Force -ErrorAction SilentlyContinue
        throw "Falha ao restringir permissoes ACL de wsl-pass.txt antes da gravacao (codigo $icaclsExit)."
    }

    $content = @"
Distribuicoes: Ubuntu-26.04, Ubuntu-24.04
Usuario: $Usuario
Senha: $SenhaTexto
"@
    $content += [Environment]::NewLine
    [System.IO.File]::WriteAllText($PasswordFile, $content, $Utf8NoBom)
}

function Initialize-DistribuicaoUbuntu {
    <#
    .SYNOPSIS
        Atualiza pacotes, instala ShellCheck, cria o usuario padrao e grava wsl.conf.
    #>
    param([Parameter(Mandatory)][string]$Distro)

    Show-TituloSecao -Message "Atualizando $Distro e instalando ShellCheck"

    $setupCommand = @"
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::=--force-confold dist-upgrade
apt-get install -y sudo shellcheck
if ! id -u '$Usuario' >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash '$Usuario'
fi
usermod --append --groups sudo --shell /bin/bash '$Usuario'
if [ -f /etc/wsl.conf ] && [ ! -f /etc/wsl.conf.pre-implantacao ]; then
    cp -a /etc/wsl.conf /etc/wsl.conf.pre-implantacao
fi
echo '[boot]' > /etc/wsl.conf
echo 'systemd=true' >> /etc/wsl.conf
echo '' >> /etc/wsl.conf
echo '[user]' >> /etc/wsl.conf
echo 'default=$Usuario' >> /etc/wsl.conf
chown root:root /etc/wsl.conf
chmod 0644 /etc/wsl.conf
apt-get clean
shellcheck --version
"@

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('-d', $Distro, '-u', 'root', '--', 'bash', '-lc', $setupCommand) `
        -FailureMessage "Falha ao preparar $Distro"

    "$Usuario`:$SenhaTexto" | & wsl.exe -d $Distro -u root -- chpasswd
    $chpasswdExit = $LASTEXITCODE
    if ($chpasswdExit -ne 0) {
        throw "Falha ao definir a senha do usuario $Usuario em $Distro (codigo $chpasswdExit)."
    }

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--terminate', $Distro) `
        -FailureMessage "Falha ao encerrar $Distro"
}

function Export-ImagemBaseWsl {
    <#
    .SYNOPSIS
        Exporta as imagens-base VHDX preservando arquivos ja existentes.
    #>
    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path -Path $WslRoot -ChildPath "$distro.vhdx"
        if (Test-Path -LiteralPath $imagePath) {
            throw "A imagem-base ja existe e foi preservada: $imagePath. Renomeie ou remova o arquivo antes de repetir a preparacao."
        }
    }

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao desligar o WSL antes da exportacao'

    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path -Path $WslRoot -ChildPath "$distro.vhdx"
        Show-TituloSecao -Message "Exportando $distro para $imagePath"

        try {
            Invoke-ComandoNativo -FilePath 'wsl.exe' `
                -Arguments @('--export', $distro, $imagePath, '--vhd') `
                -FailureMessage "Falha ao exportar $distro"
        }
        catch {
            if (Test-Path -LiteralPath $imagePath) {
                Remove-Item -LiteralPath $imagePath -Force
            }
            throw
        }

        $image = Get-Item -LiteralPath $imagePath
        if ($image.Length -le 0) {
            throw "A imagem exportada esta vazia: $imagePath"
        }
    }
}

function Confirm-DesregistroBase {
    <#
    .SYNOPSIS
        Solicita confirmacao textual explicita antes de desregistrar as distribuicoes originais.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Aviso visual de operacao irreversivel antes da confirmacao')]
    [OutputType([bool])]
    param()

    if ($SemConfirmacao) {
        return $true
    }

    Write-Host "`nAs duas imagens-base foram exportadas e validadas." -ForegroundColor Yellow
    Write-Host 'A proxima etapa executara wsl --unregister nas distribuicoes originais.' -ForegroundColor Yellow
    $confirmation = Read-Host 'Digite DESREGISTRAR para continuar'
    return ($confirmation -ceq 'DESREGISTRAR')
}

function Import-DistribuicaoBase {
    <#
    .SYNOPSIS
        Reimporta as distribuicoes-base a partir dos arquivos VHDX exportados.
    #>
    [OutputType([bool])]
    param()

    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path -Path $WslRoot -ChildPath "$distro.vhdx"
        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
            throw "Imagem-base nao encontrada: $imagePath"
        }
        Assert-DiretorioInstalacaoVazio -Path (Join-Path -Path $WslRoot -ChildPath $distro)
    }

    if (-not (Confirm-DesregistroBase)) {
        return $false
    }

    foreach ($distro in $BaseDistros) {
        Show-TituloSecao -Message "Removendo o registro antigo de $distro"
        Invoke-ComandoNativo -FilePath 'wsl.exe' `
            -Arguments @('--unregister', $distro) `
            -FailureMessage "Falha ao desregistrar $distro"
    }

    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path -Path $WslRoot -ChildPath "$distro.vhdx"
        $installPath = Join-Path -Path $WslRoot -ChildPath $distro
        $validationCommand = "test `$(id -un) = '$Usuario' && command -v shellcheck >/dev/null"

        Show-TituloSecao -Message "Importando $distro em $installPath"
        Invoke-ComandoNativo -FilePath 'wsl.exe' `
            -Arguments @('--import', $distro, $installPath, $imagePath, '--vhd') `
            -FailureMessage "Falha ao importar $distro"

        Invoke-ComandoNativo -FilePath 'wsl.exe' `
            -Arguments @('-d', $distro, '--', 'bash', '-lc', $validationCommand) `
            -FailureMessage "A validacao final de $distro falhou"
    }

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--set-default', 'Ubuntu-26.04') `
        -FailureMessage 'Falha ao definir Ubuntu-26.04 como distribuicao padrao'

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao aplicar o desligamento final do WSL'

    return $true
}

function New-DistribuicaoTeste {
    <#
    .SYNOPSIS
        Cria instancias descartaveis -Teste a partir das imagens VHDX base.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Confirmacao ShouldProcess controlada pelo ponto de entrada')]
    param()

    [System.IO.Directory]::CreateDirectory($WslRoot) | Out-Null
    $registered = @(Get-DistribuicaoWsl)

    foreach ($distro in $BaseDistros) {
        $testName = "$distro-Teste"
        $imagePath = Join-Path -Path $WslRoot -ChildPath "$distro.vhdx"
        $installPath = Join-Path -Path $WslRoot -ChildPath $testName
        $validationCommand = "test `$(id -un) = '$Usuario' && command -v shellcheck >/dev/null"

        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
            throw "Imagem-base nao encontrada: $imagePath"
        }
        if ($registered -contains $testName) {
            throw "A distribuicao de teste ja esta registrada: $testName"
        }

        Assert-DiretorioInstalacaoVazio -Path $installPath
        Show-TituloSecao -Message "Criando $testName a partir de $imagePath"
        Invoke-ComandoNativo -FilePath 'wsl.exe' `
            -Arguments @('--import', $testName, $installPath, $imagePath, '--vhd') `
            -FailureMessage "Falha ao importar $testName"

        Invoke-ComandoNativo -FilePath 'wsl.exe' `
            -Arguments @('-d', $testName, '--', 'bash', '-lc', $validationCommand) `
            -FailureMessage "A validacao final de $testName falhou"
    }

    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao encerrar as distribuicoes de teste'
}

$dataExecucao = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$usuarioWindows = [Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ' Implantacao de Imagens-Base WSL v1.1' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host "  Computador: $env:COMPUTERNAME | Operador: $usuarioWindows" -ForegroundColor DarkGray
Write-Host "  Data/Hora:  $dataExecucao | Modo: $Modo" -ForegroundColor DarkGray

$listagemWslFinal = $false

try {
    if (($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess("WSL ($WslRoot)", "Executar modo $Modo")) {
        if ($Modo -eq 'CriarTestes') {
            $etapa = 'Criacao das distribuicoes de teste'
            New-DistribuicaoTeste
            $listagemWslFinal = $true
            $status = 'Instancias de teste criadas e validadas'
            $corStatus = 'Green'
            $codigoSaida = 0
        }
        else {
            $etapa = 'Coleta de credencial'
            Show-TituloSecao -Message 'Coletando a credencial das distribuicoes'
            if ($null -eq $SenhaSegura) {
                $SenhaSegura = Read-Host 'Informe a senha do usuario WSL' -AsSecureString
                $ConfirmacaoSegura = Read-Host 'Confirme a senha do usuario WSL' -AsSecureString
                $ConfirmacaoTexto = ConvertTo-TextoPlano -SecureValue $ConfirmacaoSegura
            }

            $SenhaTexto = ConvertTo-TextoPlano -SecureValue $SenhaSegura
            if ([string]::IsNullOrEmpty($SenhaTexto)) {
                throw 'A senha do usuario WSL nao pode ficar vazia.'
            }
            if (($null -ne $ConfirmacaoTexto) -and ($SenhaTexto -cne $ConfirmacaoTexto)) {
                throw 'As senhas informadas nao conferem.'
            }

            $etapa = 'Verificacoes iniciais do WSL'
            Show-TituloSecao -Message 'Executando verificacoes iniciais'
            [System.IO.Directory]::CreateDirectory($WslRoot) | Out-Null
            Invoke-ComandoNativo -FilePath 'wsl.exe' `
                -Arguments @('--update') `
                -FailureMessage 'Falha ao atualizar o componente WSL'
            Invoke-ComandoNativo -FilePath 'wsl.exe' `
                -Arguments @('--set-default-version', '2') `
                -FailureMessage 'Falha ao definir WSL 2 como versao padrao'

            $registeredBeforeInstall = @(Get-DistribuicaoWsl)
            foreach ($distro in $BaseDistros) {
                if ($registeredBeforeInstall -contains $distro) {
                    if (-not $UsarDistribuicoesExistentes) {
                        throw "A distribuicao $distro ja existe. Para preparar essa instalacao conscientemente, repita com -UsarDistribuicoesExistentes."
                    }
                    Write-Host "Usando a distribuicao existente: $distro" -ForegroundColor Yellow
                    continue
                }

                Show-TituloSecao -Message "Instalando $distro sem iniciar a configuracao interativa"
                Invoke-ComandoNativo -FilePath 'wsl.exe' `
                    -Arguments @('--install', '-d', $distro, '--no-launch') `
                    -FailureMessage "Falha ao instalar $distro"
            }

            $registeredAfterInstall = @(Get-DistribuicaoWsl)
            foreach ($distro in $BaseDistros) {
                if ($registeredAfterInstall -notcontains $distro) {
                    throw "$distro ainda nao esta registrada. Reinicie o Windows e execute o script novamente com -UsarDistribuicoesExistentes."
                }
            }

            $etapa = 'Gravacao de .wslconfig'
            Save-ConfiguracaoWsl

            $etapa = 'Gravacao do arquivo de credenciais'
            Save-ArquivoCredencialWsl

            $etapa = 'Configuracao das distribuicoes Ubuntu'
            foreach ($distro in $BaseDistros) {
                Initialize-DistribuicaoUbuntu -Distro $distro
            }

            $etapa = 'Exportacao das imagens-base VHDX'
            Export-ImagemBaseWsl

            $etapa = 'Reimportacao das distribuicoes-base'
            if (Import-DistribuicaoBase) {
                $listagemWslFinal = $true
                $status = 'Imagens-base preparadas, exportadas e validadas'
                $corStatus = 'Green'
                $codigoSaida = 0
            }
            else {
                $status = 'Cancelado pelo operador; imagens exportadas preservadas em C:\WSL'
                $corStatus = 'Yellow'
                $codigoSaida = 2
            }
        }
    }
    elseif ($WhatIfPreference) {
        $status = "Simulacao concluida ($Modo); nenhuma alteracao aplicada"
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
    Write-Error -Message "Falha na etapa: $etapa. Operacao interrompida; verifique o estado em $WslRoot antes de repetir." -ErrorAction Continue
    $status = 'Falha durante a execucao'
    $corStatus = 'Red'
    $codigoSaida = 1
}
finally {
    $SenhaTexto = $null
    $ConfirmacaoTexto = $null
    if ($null -ne $ConfirmacaoSegura) {
        $ConfirmacaoSegura.Dispose()
    }
    if ($null -ne $SenhaSegura) {
        $SenhaSegura.Dispose()
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host '  RESUMO DA EXECUCAO' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host "  - Status:              $status" -ForegroundColor $corStatus
Write-Host "  - Modo executado:      $Modo" -ForegroundColor White
if ($Modo -eq 'PrepararBases') {
    Write-Host "  - Usuario WSL:         $Usuario" -ForegroundColor White
    Write-Host "  - Imagens-base:        $WslRoot\Ubuntu-*.vhdx" -ForegroundColor White
    Write-Host "  - Configuracao WSL:    $WslConfigFile" -ForegroundColor White
}
else {
    Write-Host '  - Instancias alvo:     Ubuntu-26.04-Teste, Ubuntu-24.04-Teste' -ForegroundColor White
}
Write-Host "  - Codigo de saida:     $codigoSaida" -ForegroundColor $corStatus
Write-Host '----------------------------------------------------------' -ForegroundColor DarkGray

if ($listagemWslFinal) {
    Invoke-ComandoNativo -FilePath 'wsl.exe' `
        -Arguments @('--list', '--verbose') `
        -FailureMessage 'Falha ao listar as distribuicoes no resumo final'
}

# Quando executado via Invoke-Expression (iex), usa return para nao fechar a janela do PowerShell do operador
if ([string]::IsNullOrEmpty($PSCommandPath)) {
    return
}

exit $codigoSaida
