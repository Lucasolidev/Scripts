<#
.SYNOPSIS
    Prepara imagens-base do Ubuntu no WSL ou cria instancias descartaveis de teste.

.DESCRIPTION
    Script PowerShell compativel com versoes antigas e recentes.
    No modo PrepararBases, instala e atualiza Ubuntu-26.04 e Ubuntu-24.04,
    cria o usuario solicitado, instala ShellCheck, exporta VHDX em C:\WSL,
    desregistra as instalacoes originais e reimporta as distribuicoes.

    No modo CriarTestes, importa copias independentes das imagens-base com o
    sufixo -Teste.

.EXAMPLE
    .\Implantacao_WSL.ps1

.EXAMPLE
    .\Implantacao_WSL.ps1 -UsarDistribuicoesExistentes

.EXAMPLE
    .\Implantacao_WSL.ps1 -Modo CriarTestes

.VERSION
    1.0

.NOTES
    Requer privilegios de Administrador.
    A senha e solicitada como SecureString e nao fica fixa no codigo-fonte.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [ValidateSet('PrepararBases', 'CriarTestes')]
    [string]$Modo = 'PrepararBases',

    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$Usuario = 'administrador',

    [System.Security.SecureString]$SenhaSegura,

    [switch]$UsarDistribuicoesExistentes,

    [switch]$SemConfirmacao
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WslRoot = 'C:\WSL'
$PasswordFile = Join-Path $WslRoot 'wsl-pass.txt'
$WslConfigFile = Join-Path $env:USERPROFILE '.wslconfig'
$BaseDistros = @('Ubuntu-26.04', 'Ubuntu-24.04')
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$SenhaTexto = $null
$ConfirmacaoSegura = $null
$ConfirmacaoTexto = $null

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host '' -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
}

function ConvertTo-PlainText {
    param([Parameter(Mandatory)][System.Security.SecureString]$SecureValue)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (codigo de saida: $LASTEXITCODE)."
    }
}

function Get-WslDistributions {
    $output = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel consultar as distribuicoes registradas no WSL.'
    }

    return @(
        $output |
            ForEach-Object { ($_ -replace "`0", '').Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Assert-EmptyInstallLocation {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        [System.IO.Directory]::CreateDirectory($Path) | Out-Null
        return
    }

    if (@(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) {
        throw "O diretorio de instalacao nao esta vazio: $Path"
    }
}

function Write-WslConfig {
    Write-Step "Criando $WslConfigFile"

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

function Write-PasswordFile {
    Write-Step "Criando $PasswordFile"
    Write-Host 'AVISO: O arquivo solicitado armazenara a senha em texto puro.' -ForegroundColor Yellow

    $content = @"
Distribuicoes: Ubuntu-26.04, Ubuntu-24.04
Usuario: $Usuario
Senha: $SenhaTexto
"@
    $content += [Environment]::NewLine
    [System.IO.File]::WriteAllText($PasswordFile, $content, $Utf8NoBom)

    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $PasswordFile '/inheritance:r' '/grant:r' "${currentIdentity}:(F)" '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'AVISO: Nao foi possivel restringir as permissoes de wsl-pass.txt.' -ForegroundColor Yellow
    }
}

function Initialize-UbuntuDistribution {
    param([Parameter(Mandatory)][string]$Distro)

    Write-Step "Atualizando $Distro e instalando ShellCheck"

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

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('-d', $Distro, '-u', 'root', '--', 'bash', '-lc', $setupCommand) `
        -FailureMessage "Falha ao preparar $Distro"

    "$Usuario`:$SenhaTexto" | & wsl.exe -d $Distro -u root -- chpasswd
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao definir a senha do usuario $Usuario em $Distro."
    }

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--terminate', $Distro) `
        -FailureMessage "Falha ao encerrar $Distro"
}

function Export-WslBases {
    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path $WslRoot "$distro.vhdx"
        if (Test-Path -LiteralPath $imagePath) {
            throw "A imagem-base ja existe e foi preservada: $imagePath. Renomeie ou remova o arquivo antes de repetir a preparacao."
        }
    }

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao desligar o WSL antes da exportacao'

    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path $WslRoot "$distro.vhdx"
        Write-Step "Exportando $distro para $imagePath"

        try {
            Invoke-NativeCommand -FilePath 'wsl.exe' `
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

function Confirm-Unregister {
    if ($SemConfirmacao) {
        return
    }

    Write-Host "`nAs duas imagens-base foram exportadas e validadas." -ForegroundColor Yellow
    Write-Host 'A proxima etapa executara wsl --unregister nas distribuicoes originais.' -ForegroundColor Yellow
    $confirmation = Read-Host 'Digite DESREGISTRAR para continuar'
    if ($confirmation -cne 'DESREGISTRAR') {
        throw 'Operacao cancelada. As imagens exportadas foram mantidas em C:\WSL.'
    }
}

function Import-BaseDistributions {
    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path $WslRoot "$distro.vhdx"
        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
            throw "Imagem-base nao encontrada: $imagePath"
        }
        Assert-EmptyInstallLocation -Path (Join-Path $WslRoot $distro)
    }

    Confirm-Unregister

    foreach ($distro in $BaseDistros) {
        Write-Step "Removendo o registro antigo de $distro"
        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('--unregister', $distro) `
            -FailureMessage "Falha ao desregistrar $distro"
    }

    foreach ($distro in $BaseDistros) {
        $imagePath = Join-Path $WslRoot "$distro.vhdx"
        $installPath = Join-Path $WslRoot $distro
        $validationCommand = "test `$(id -un) = '$Usuario' && command -v shellcheck >/dev/null"

        Write-Step "Importando $distro em $installPath"
        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('--import', $distro, $installPath, $imagePath, '--vhd') `
            -FailureMessage "Falha ao importar $distro"

        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('-d', $distro, '--', 'bash', '-lc', $validationCommand) `
            -FailureMessage "A validacao final de $distro falhou"
    }

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--set-default', 'Ubuntu-26.04') `
        -FailureMessage 'Falha ao definir Ubuntu-26.04 como distribuicao padrao'

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao aplicar o desligamento final do WSL'
}

function New-TestDistributions {
    [System.IO.Directory]::CreateDirectory($WslRoot) | Out-Null
    $registered = @(Get-WslDistributions)

    foreach ($distro in $BaseDistros) {
        $testName = "$distro-Teste"
        $imagePath = Join-Path $WslRoot "$distro.vhdx"
        $installPath = Join-Path $WslRoot $testName
        $validationCommand = "test `$(id -un) = '$Usuario' && command -v shellcheck >/dev/null"

        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
            throw "Imagem-base nao encontrada: $imagePath"
        }
        if ($registered -contains $testName) {
            throw "A distribuicao de teste ja esta registrada: $testName"
        }

        Assert-EmptyInstallLocation -Path $installPath
        Write-Step "Criando $testName a partir de $imagePath"
        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('--import', $testName, $installPath, $imagePath, '--vhd') `
            -FailureMessage "Falha ao importar $testName"

        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('-d', $testName, '--', 'bash', '-lc', $validationCommand) `
            -FailureMessage "A validacao final de $testName falhou"
    }

    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--shutdown') `
        -FailureMessage 'Falha ao encerrar as distribuicoes de teste'

    Write-Host '' -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host ' [OK] RESUMO - INSTANCIAS DE TESTE CRIADAS' -ForegroundColor Green
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host '  - Ubuntu-26.04-Teste: Criada e validada' -ForegroundColor White
    Write-Host '  - Ubuntu-24.04-Teste: Criada e validada' -ForegroundColor White
    Write-Host '  - ShellCheck:         Disponivel' -ForegroundColor White
    Write-Host '----------------------------------------------------------' -ForegroundColor DarkGray
    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--list', '--verbose') `
        -FailureMessage 'Falha ao listar as distribuicoes de teste'
}

try {
    if ($Modo -eq 'CriarTestes') {
        New-TestDistributions
        return
    }

    Write-Step 'Coletando a credencial das distribuicoes'
    if ($null -eq $SenhaSegura) {
        $SenhaSegura = Read-Host 'Informe a senha do usuario WSL' -AsSecureString
        $ConfirmacaoSegura = Read-Host 'Confirme a senha do usuario WSL' -AsSecureString
        $ConfirmacaoTexto = ConvertTo-PlainText -SecureValue $ConfirmacaoSegura
    }

    $SenhaTexto = ConvertTo-PlainText -SecureValue $SenhaSegura
    if ([string]::IsNullOrEmpty($SenhaTexto)) {
        throw 'A senha do usuario WSL nao pode ficar vazia.'
    }
    if (($null -ne $ConfirmacaoTexto) -and ($SenhaTexto -cne $ConfirmacaoTexto)) {
        throw 'As senhas informadas nao conferem.'
    }

    Write-Step 'Executando verificacoes iniciais'
    [System.IO.Directory]::CreateDirectory($WslRoot) | Out-Null
    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--update') `
        -FailureMessage 'Falha ao atualizar o componente WSL'
    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--set-default-version', '2') `
        -FailureMessage 'Falha ao definir WSL 2 como versao padrao'

    $registeredBeforeInstall = @(Get-WslDistributions)
    foreach ($distro in $BaseDistros) {
        if ($registeredBeforeInstall -contains $distro) {
            if (-not $UsarDistribuicoesExistentes) {
                throw "A distribuicao $distro ja existe. Para preparar essa instalacao conscientemente, repita com -UsarDistribuicoesExistentes."
            }
            Write-Host "Usando a distribuicao existente: $distro" -ForegroundColor Yellow
            continue
        }

        Write-Step "Instalando $distro sem iniciar a configuracao interativa"
        Invoke-NativeCommand -FilePath 'wsl.exe' `
            -Arguments @('--install', '-d', $distro, '--no-launch') `
            -FailureMessage "Falha ao instalar $distro"
    }

    $registeredAfterInstall = @(Get-WslDistributions)
    foreach ($distro in $BaseDistros) {
        if ($registeredAfterInstall -notcontains $distro) {
            throw "$distro ainda nao esta registrada. Reinicie o Windows e execute o script novamente com -UsarDistribuicoesExistentes."
        }
    }

    Write-WslConfig
    Write-PasswordFile

    foreach ($distro in $BaseDistros) {
        Initialize-UbuntuDistribution -Distro $distro
    }

    Export-WslBases
    Import-BaseDistributions

    Write-Host '' -ForegroundColor Cyan
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host ' [OK] RESUMO DA EXECUCAO - PROCESSO CONCLUIDO' -ForegroundColor Green
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Host '  - Ubuntu-26.04:       Preparada, exportada e importada' -ForegroundColor White
    Write-Host '  - Ubuntu-24.04:       Preparada, exportada e importada' -ForegroundColor White
    Write-Host '  - ShellCheck:         Instalado nas duas distribuicoes' -ForegroundColor White
    Write-Host '  - Imagens-base:       C:\WSL\Ubuntu-*.vhdx' -ForegroundColor White
    Write-Host "  - Usuario WSL:        $Usuario" -ForegroundColor White
    Write-Host "  - Credenciais:        $PasswordFile" -ForegroundColor White
    Write-Host "  - Configuracao WSL:   $WslConfigFile" -ForegroundColor White
    Write-Host '  - Distribuicao padrao: Ubuntu-26.04' -ForegroundColor White
    Write-Host '  - Criar testes:       .\Implantacao_WSL.ps1 -Modo CriarTestes' -ForegroundColor White
    Write-Host '----------------------------------------------------------' -ForegroundColor DarkGray
    Invoke-NativeCommand -FilePath 'wsl.exe' `
        -Arguments @('--list', '--verbose') `
        -FailureMessage 'Falha ao listar as distribuicoes no resumo final'
}
catch {
    Write-Host '' -ForegroundColor Red
    Write-Host '==========================================================' -ForegroundColor Red
    Write-Host ' ERRO NA EXECUCAO' -ForegroundColor Red
    Write-Host '==========================================================' -ForegroundColor Red
    Write-Host " $($_.Exception.Message)" -ForegroundColor Red
    exit 1
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
