<#
.SYNOPSIS
    Aplica exclusoes recomendadas (KB1999) no Microsoft Defender para Veeam Backup & Replication.
.DESCRIPTION
    Script PowerShell compativel com Windows PowerShell 5.1 e PowerShell 7 no Windows.
    Configura de forma idempotente as exclusoes de pastas, processos e extensoes no Microsoft Defender
    conforme a documentacao oficial Veeam KB1999 (cobrindo Veeam 12.3 e novidades do 13.0/13.1),
    reduzindo o impacto de I/O e CPU durante execucao de backups, proxies, mounts, vPower NFS,
    Threat Hunter e repositorios locais.
    Inclui deteccao dinamica via Registro do Windows, descoberta automatica dos executaveis reais
    dos servicos Veeam instalados no servidor, consulta opcional aos repositorios locais via modulo
    Veeam.Backup.PowerShell, verificacao de Tamper Protection / politicas centralizadas e validacao
    pos-gravacao. Nao gera arquivo de log em disco.
.PARAMETER RepositoryPaths
    Lista opcional de pastas ou volumes de repositorios locais adicionais / LUNs iSCSI
    (ex: 'E:\Backups', 'F:\Veeam'). A raiz pura do sistema operacional (ex: C:\) e ignorada
    automaticamente por seguranca.
.PARAMETER IncluirBancoLocal
    Quando informado, adiciona exclusoes para pastas e processos de banco de dados local
    (PostgreSQL e SQL Server) caso o banco de configuracao do Veeam rode localmente.
.PARAMETER IncluirExtensoesSqlite
    Quando informado, adiciona exclusoes globais para extensoes .sqlite, .sqlite-wal e .sqlite-shm.
    Por padrao, arquivos SQLite do Veeam ja ficam cobertos pelas exclusoes de pasta.
.PARAMETER IgnorarAutoDeteccaoRepositorios
    Quando informado, pula a consulta automatica de repositorios locais via modulo PowerShell do Veeam.
.EXAMPLE
    .\exclusoes_defender_veeam.ps1
.EXAMPLE
    .\exclusoes_defender_veeam.ps1 -RepositoryPaths 'E:\Backups','F:\Veeam' -IncluirBancoLocal
.EXAMPLE
    .\exclusoes_defender_veeam.ps1 -WhatIf
.NOTES
    Versao: 1.0
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7 no Windows.
    Privilegios: Requer execucao como Administrador para alterar preferencias do Microsoft Defender
    (validacao realizada em tempo de execucao para compatibilidade com Invoke-Expression).
    Referencia: Veeam KB1999 - Antivirus Exclusions for Veeam Backup & Replication.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento pelo operador.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param(
    [Parameter(Mandatory = $false)]
    [Alias('CaminhosRepositorio')]
    [string[]]$RepositoryPaths = @(),

    [Parameter(Mandatory = $false)]
    [switch]$IncluirBancoLocal,

    [Parameter(Mandatory = $false)]
    [switch]$IncluirExtensoesSqlite,

    [Parameter(Mandatory = $false)]
    [switch]$IgnorarAutoDeteccaoRepositorios
)

# ==============================================================================
# Execucao recomendada (copiar e colar comando unico no PowerShell como Administrador):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/exclusoes_defender_veeam.ps1 | iex
#
# Execucao remota passando repositorios locais extras manualmente:
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/exclusoes_defender_veeam.ps1))) -RepositoryPaths 'E:\Backups','F:\Veeam'
# ==============================================================================

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'
$resumoPastasAntes = 0
$resumoProcessosAntes = 0
$resumoExtensoesAntes = 0
$resumoPastasDepois = 0
$resumoProcessosDepois = 0
$resumoExtensoesDepois = 0
$resumoNovasPastas = 0
$resumoNovosProcessos = 0
$resumoNovasExtensoes = 0
$resumoNaoPersistidos = 0
$avisoPoliticaCentral = $false

function Test-PrivilegioAdministrador {
    <#
    .SYNOPSIS
        Verifica se a sessao atual do PowerShell esta elevada como Administrador.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identidade
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-CaminhoNormalizado {
    <#
    .SYNOPSIS
        Normaliza caminhos de pastas para comparacao consistente e sem duplicidades.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Caminho
    )

    if ([string]::IsNullOrWhiteSpace($Caminho)) {
        return $null
    }

    $limpo = $Caminho.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($limpo)) {
        return $null
    }

    # Preserva barra final apenas em raiz de unidade (ex: E:\)
    if ($limpo -match '^[A-Za-z]:\\?$') {
        return ($limpo.Substring(0, 2) + '\')
    }

    return $limpo.TrimEnd('\')
}

function Test-CaminhoSeguroParaExclusao {
    <#
    .SYNOPSIS
        Impede a inclusao acidental da raiz inteira do disco do sistema operacional.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Caminho
    )

    if ([string]::IsNullOrWhiteSpace($Caminho)) {
        return $false
    }

    $raizSistema = ($env:SystemDrive.TrimEnd('\') + '\')
    if ($Caminho.Equals($raizSistema, [System.StringComparison]::OrdinalIgnoreCase) -or
        $Caminho.Equals($env:SystemDrive.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase) -or
        $Caminho.Equals('\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    return $true
}

function Get-ValorRegistroSeguro {
    <#
    .SYNOPSIS
        Le um valor de string do Registro do Windows quando a chave e a propriedade existem.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaminhoChave,

        [Parameter(Mandatory = $true)]
        [string]$NomePropriedade
    )

    try {
        if (-not (Test-Path -LiteralPath $CaminhoChave)) {
            return $null
        }

        $propriedade = Get-ItemProperty -LiteralPath $CaminhoChave -Name $NomePropriedade -ErrorAction SilentlyContinue
        if ($null -ne $propriedade) {
            $valor = $propriedade.$NomePropriedade
            if (-not [string]::IsNullOrWhiteSpace([string]$valor)) {
                return [string]$valor
            }
        }
    }
    catch {
        Write-Verbose "Nao foi possivel ler '$NomePropriedade' em '$CaminhoChave'."
    }

    return $null
}

function Get-ProcessoServicoVeeamLocal {
    <#
    .SYNOPSIS
        Descobre dinamicamente os executaveis reais dos servicos Veeam instalados no Windows.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $executaveis = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $binariosIgnorados = @('svchost.exe', 'cmd.exe', 'powershell.exe', 'pwsh.exe')
    $caminhosServico = New-Object 'System.Collections.Generic.List[string]'

    try {
        $servicos = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object {
            $_.Name -like 'Veeam*' -or $_.DisplayName -like 'Veeam*'
        })
        foreach ($svc in $servicos) {
            if (-not [string]::IsNullOrWhiteSpace([string]$svc.PathName)) {
                [void]$caminhosServico.Add([string]$svc.PathName)
            }
        }
    }
    catch {
        try {
            $chavesSvc = @(Get-ChildItem -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Veeam*' -ErrorAction SilentlyContinue)
            foreach ($chaveSvc in $chavesSvc) {
                $img = Get-ValorRegistroSeguro -CaminhoChave $chaveSvc.PSPath -NomePropriedade 'ImagePath'
                if (-not [string]::IsNullOrWhiteSpace($img)) {
                    [void]$caminhosServico.Add([Environment]::ExpandEnvironmentVariables($img))
                }
            }
        }
        catch {
            Write-Verbose 'Nao foi possivel consultar servicos locais via CIM ou Registro.'
        }
    }

    foreach ($pathName in $caminhosServico) {
        if ($pathName -match '^\s*"([^"]+\.exe)"|^\s*([^\s"]+\.exe)') {
            $caminhoExe = if (-not [string]::IsNullOrWhiteSpace($Matches[1])) { $Matches[1] } else { $Matches[2] }
            $nomeBinario = [System.IO.Path]::GetFileName($caminhoExe)
            if (-not [string]::IsNullOrWhiteSpace($nomeBinario) -and
                $nomeBinario.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase) -and
                ($binariosIgnorados -notcontains $nomeBinario.ToLowerInvariant())) {
                [void]$executaveis.Add($nomeBinario)
            }
        }
    }

    [string[]]$resultado = @($executaveis)
    return $resultado
}

function Get-CaminhoRepositorioLocalVeeam {
    <#
    .SYNOPSIS
        Detecta caminhos de repositorios locais configurados no Veeam Backup & Replication local.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    [string[]]$listaVazia = @()
    $caminhosDetectados = New-Object 'System.Collections.Generic.List[string]'

    $servicoVbr = Get-Service -Name 'VeeamBackupSvc' -ErrorAction SilentlyContinue
    if ($null -eq $servicoVbr -or $servicoVbr.Status -ne 'Running') {
        return $listaVazia
    }

    $moduloVeeam = Get-Module -ListAvailable -Name 'Veeam.Backup.PowerShell' -ErrorAction SilentlyContinue
    if ($null -eq $moduloVeeam) {
        return $listaVazia
    }

    $conectadoPeloScript = $false

    try {
        Import-Module -Name 'Veeam.Backup.PowerShell' -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null

        $sessaoAtual = Get-VBRServerSession -ErrorAction SilentlyContinue
        if ($null -eq $sessaoAtual) {
            Connect-VBRServer -Server 'localhost' -ErrorAction Stop | Out-Null
            $conectadoPeloScript = $true
        }

        $nomesLocais = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        [void]$nomesLocais.Add('localhost')
        [void]$nomesLocais.Add('127.0.0.1')
        [void]$nomesLocais.Add('::1')
        [void]$nomesLocais.Add('This server')
        if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
            [void]$nomesLocais.Add($env:COMPUTERNAME)
        }
        try {
            $fqdnLocal = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
            if (-not [string]::IsNullOrWhiteSpace($fqdnLocal)) {
                [void]$nomesLocais.Add($fqdnLocal)
            }
        }
        catch {
            Write-Verbose 'Nao foi possivel resolver o FQDN local para filtro de repositorios.'
        }

        $listaRepos = New-Object 'System.Collections.Generic.List[object]'
        $reposSimples = @(Get-VBRBackupRepository -ErrorAction SilentlyContinue)
        foreach ($repo in $reposSimples) {
            if ($null -ne $repo -and $repo.Type -ne 'SanSnapshotOnly') {
                [void]$listaRepos.Add($repo)
            }
        }

        $reposSobr = @(Get-VBRBackupRepository -ScaleOut -ErrorAction SilentlyContinue)
        foreach ($sobr in $reposSobr) {
            if ($null -ne $sobr) {
                $extents = @(Get-VBRRepositoryExtent -Repository $sobr -ErrorAction SilentlyContinue)
                foreach ($extent in $extents) {
                    if ($null -ne $extent -and $null -ne $extent.Repository) {
                        [void]$listaRepos.Add($extent.Repository)
                    }
                }
            }
        }

        foreach ($repo in $listaRepos) {
            $caminhoRepo = $null
            if ($repo.PSObject.Properties.Match('FriendlyPath').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$repo.FriendlyPath)) {
                $caminhoRepo = [string]$repo.FriendlyPath
            }
            elseif ($repo.PSObject.Properties.Match('Path').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$repo.Path)) {
                $caminhoRepo = [string]$repo.Path
            }

            if ([string]::IsNullOrWhiteSpace($caminhoRepo)) {
                continue
            }

            # Considera apenas caminhos locais de disco (ex: D:\Backups) pertencentes a este servidor
            if ($caminhoRepo -notmatch '^[A-Za-z]:\\') {
                continue
            }

            $hostNome = $null
            if ($null -ne $repo.Host -and $repo.Host.PSObject.Properties.Match('Name').Count -gt 0) {
                $hostNome = [string]$repo.Host.Name
            }

            if ([string]::IsNullOrWhiteSpace($hostNome) -or $nomesLocais.Contains($hostNome)) {
                $normalizado = ConvertTo-CaminhoNormalizado -Caminho $caminhoRepo
                if (Test-CaminhoSeguroParaExclusao -Caminho $normalizado) {
                    [void]$caminhosDetectados.Add($normalizado)
                }
            }
        }
    }
    catch {
        Write-Host "  [AVISO] Nao foi possivel consultar repositorios via Veeam.Backup.PowerShell; prosseguindo com pastas padrao." -ForegroundColor Yellow
    }
    finally {
        if ($conectadoPeloScript) {
            try {
                Disconnect-VBRServer -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Verbose 'Falha nao critica ao encerrar sessao local do VBR.'
            }
        }
    }

    [string[]]$resultadoRepos = @($caminhosDetectados | Select-Object -Unique)
    return $resultadoRepos
}

function Invoke-AplicacaoExclusaoCategoria {
    <#
    .SYNOPSIS
        Aplica exclusoes de uma categoria (Path, Process ou Extension) em lote com fallback individual.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Path', 'Process', 'Extension')]
        [string]$Tipo,

        [Parameter(Mandatory = $true)]
        [string]$TituloSecao,

        [Parameter(Mandatory = $true)]
        [string[]]$ItensDesejados,

        [Parameter(Mandatory = $false)]
        [string[]]$ItensAtuais = @(),

        [Parameter(Mandatory = $false)]
        [switch]$SimularApenas
    )

    Write-Host "`n--- $TituloSecao ---" -ForegroundColor Yellow

    $comparador = [System.StringComparer]::OrdinalIgnoreCase
    $conjuntoAtual = New-Object 'System.Collections.Generic.HashSet[string]' ($comparador)
    foreach ($itemAtual in $ItensAtuais) {
        if (-not [string]::IsNullOrWhiteSpace($itemAtual)) {
            $chave = if ($Tipo -eq 'Path') { ConvertTo-CaminhoNormalizado -Caminho $itemAtual } else { $itemAtual.Trim() }
            if (-not [string]::IsNullOrWhiteSpace($chave)) {
                [void]$conjuntoAtual.Add($chave)
            }
        }
    }

    $pendentes = New-Object 'System.Collections.Generic.List[string]'
    $conjuntoVisto = New-Object 'System.Collections.Generic.HashSet[string]' ($comparador)

    foreach ($item in $ItensDesejados) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $valorFinal = if ($Tipo -eq 'Path') { ConvertTo-CaminhoNormalizado -Caminho $item } else { $item.Trim() }
        if ([string]::IsNullOrWhiteSpace($valorFinal)) {
            continue
        }

        if (-not $conjuntoVisto.Add($valorFinal)) {
            continue
        }

        if ($conjuntoAtual.Contains($valorFinal)) {
            Write-Host "  [JA EXISTE]  $Tipo`: $valorFinal" -ForegroundColor DarkGray
        }
        else {
            [void]$pendentes.Add($valorFinal)
        }
    }

    if ($pendentes.Count -eq 0) {
        Write-Host "  Nenhuma nova exclusao pendente nesta categoria." -ForegroundColor DarkGray
        return [pscustomobject]@{
            Pendentes      = @()
            AplicadosCount = 0
            FalhasCount    = 0
        }
    }

    if ($SimularApenas) {
        foreach ($itemSimulado in $pendentes) {
            Write-Host "  [SIMULADO]   $Tipo`: $itemSimulado" -ForegroundColor Yellow
        }
        return [pscustomobject]@{
            Pendentes      = @($pendentes)
            AplicadosCount = 0
            FalhasCount    = 0
        }
    }

    $aplicados = 0
    $falhas = 0
    $arrayPendentes = @($pendentes)

    $shouldOk = ($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess("$($arrayPendentes.Count) item(ns) de $Tipo", 'Adicionar exclusoes no Microsoft Defender')
    if (-not $shouldOk) {
        return [pscustomobject]@{
            Pendentes      = $arrayPendentes
            AplicadosCount = 0
            FalhasCount    = 0
        }
    }

    try {
        switch ($Tipo) {
            'Path'      { Add-MpPreference -ExclusionPath $arrayPendentes -ErrorAction Stop }
            'Process'   { Add-MpPreference -ExclusionProcess $arrayPendentes -ErrorAction Stop }
            'Extension' { Add-MpPreference -ExclusionExtension $arrayPendentes -ErrorAction Stop }
        }

        foreach ($itemOk in $arrayPendentes) {
            Write-Host "  [ADICIONADO] $Tipo`: $itemOk" -ForegroundColor Green
            $aplicados++
        }
    }
    catch {
        Write-Host "  [AVISO] Aplicacao em lote de $Tipo falhou; tentando item a item..." -ForegroundColor Yellow

        foreach ($itemIndividual in $arrayPendentes) {
            try {
                switch ($Tipo) {
                    'Path'      { Add-MpPreference -ExclusionPath $itemIndividual -ErrorAction Stop }
                    'Process'   { Add-MpPreference -ExclusionProcess $itemIndividual -ErrorAction Stop }
                    'Extension' { Add-MpPreference -ExclusionExtension $itemIndividual -ErrorAction Stop }
                }
                Write-Host "  [ADICIONADO] $Tipo`: $itemIndividual" -ForegroundColor Green
                $aplicados++
            }
            catch {
                Write-Host "  [FALHA]      $Tipo`: $itemIndividual" -ForegroundColor Red
                $falhas++
            }
        }
    }

    return [pscustomobject]@{
        Pendentes      = $arrayPendentes
        AplicadosCount = $aplicados
        FalhasCount    = $falhas
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Exclusoes Microsoft Defender para Veeam (KB1999) v1.0" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-PrivilegioAdministrador)) {
    Write-Host "`nERRO: Este script requer privilegios de Administrador para configurar o Microsoft Defender." -ForegroundColor Red
    Write-Host "Abra o PowerShell como Administrador e execute novamente." -ForegroundColor Yellow
    $status = 'Falha de privilegios (requer Administrador)'
    $corStatus = 'Red'
    $codigoSaida = 1
}
else {
    try {
        # -------------------------------------------------------------------------
        # Etapa 1: Verificacao do Microsoft Defender e politicas ativas
        # -------------------------------------------------------------------------
        $etapa = 'Verificacao do Microsoft Defender'
        Write-Host "`nVerificando servico e politicas do Microsoft Defender..." -ForegroundColor Cyan

        $servicoDefender = Get-Service -Name 'WinDefend' -ErrorAction SilentlyContinue
        if ($null -eq $servicoDefender) {
            throw 'Servico WinDefend nao encontrado neste servidor.'
        }

        if ($servicoDefender.Status -ne 'Running') {
            Write-Host "  [AVISO] O servico WinDefend esta no estado '$($servicoDefender.Status)'." -ForegroundColor Yellow
        }

        if (-not (Get-Command -Name 'Get-MpPreference' -ErrorAction SilentlyContinue) -or
            -not (Get-Command -Name 'Add-MpPreference' -ErrorAction SilentlyContinue)) {
            throw 'Cmdlets do modulo Defender (Get-MpPreference / Add-MpPreference) nao estao disponiveis.'
        }

        $mpStatus = Get-MpComputerStatus -ErrorAction Stop
        $preferenciasAtuais = Get-MpPreference -ErrorAction Stop

        $resumoPastasAntes = @($preferenciasAtuais.ExclusionPath).Count
        $resumoProcessosAntes = @($preferenciasAtuais.ExclusionProcess).Count
        $resumoExtensoesAntes = @($preferenciasAtuais.ExclusionExtension).Count

        $tpExclusions = Get-ValorRegistroSeguro -CaminhoChave 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -NomePropriedade 'TPExclusions'
        $disableLocalMerge = Get-ValorRegistroSeguro -CaminhoChave 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -NomePropriedade 'DisableLocalAdminMerge'

        if ($mpStatus.IsTamperProtected) {
            Write-Host "  [AVISO] Tamper Protection esta ATIVO. Algumas exclusoes locais podem ser bloqueadas." -ForegroundColor Yellow
        }
        if ($tpExclusions -eq '1') {
            $avisoPoliticaCentral = $true
            Write-Host "  [AVISO] TPExclusions=1 detectado. Exclusoes podem estar protegidas pelo Microsoft Defender Portal/Intune." -ForegroundColor Yellow
        }
        if ($disableLocalMerge -eq '1') {
            $avisoPoliticaCentral = $true
            Write-Host "  [AVISO] DisableLocalAdminMerge=1 detectado via GPO/MDM. Exclusoes locais podem ser ignoradas pela politica." -ForegroundColor Yellow
        }

        # -------------------------------------------------------------------------
        # Etapa 2: Montagem dinamica de pastas, processos e extensoes (KB1999)
        # -------------------------------------------------------------------------
        $etapa = 'Coleta de caminhos, processos e extensoes KB1999'

        $raizSistema = $env:SystemDrive.TrimEnd('\')
        $programFilesX86 = ${env:ProgramFiles(x86)}
        $commonProgramFilesX86 = ${env:CommonProgramFiles(x86)}

        $pastasBase = New-Object 'System.Collections.Generic.List[string]'
        [void]$pastasBase.Add((Join-Path -Path $env:ProgramFiles -ChildPath 'Veeam'))
        [void]$pastasBase.Add((Join-Path -Path $env:ProgramFiles -ChildPath 'Veeam\Backup and Replication\Threat Hunter'))
        if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
            [void]$pastasBase.Add((Join-Path -Path $programFilesX86 -ChildPath 'Veeam'))
        }
        [void]$pastasBase.Add((Join-Path -Path $env:CommonProgramFiles -ChildPath 'Veeam'))
        if (-not [string]::IsNullOrWhiteSpace($commonProgramFilesX86)) {
            [void]$pastasBase.Add((Join-Path -Path $commonProgramFilesX86 -ChildPath 'Veeam'))
        }
        [void]$pastasBase.Add((Join-Path -Path $env:ProgramData -ChildPath 'Veeam'))
        [void]$pastasBase.Add("$raizSistema\VeeamFLR")
        [void]$pastasBase.Add("$raizSistema\VeeamCDP")
        [void]$pastasBase.Add("$raizSistema\VeeamBackupCatalog")
        [void]$pastasBase.Add((Join-Path -Path $env:SystemRoot -ChildPath 'Veeam'))
        [void]$pastasBase.Add((Join-Path -Path $env:SystemRoot -ChildPath 'VeeamVssSupport'))
        [void]$pastasBase.Add((Join-Path -Path $env:SystemRoot -ChildPath 'Temp\VeeamBackup'))
        [void]$pastasBase.Add((Join-Path -Path $env:SystemRoot -ChildPath 'Temp\VeeamBackupTemp'))
        [void]$pastasBase.Add((Join-Path -Path $env:SystemRoot -ChildPath 'Temp\veeamdumprecorder'))
        [void]$pastasBase.Add("$raizSistema\inetpub\wwwroot\Veeam")

        # Deteccao dinamica via Registro do Windows (Catalog, vPower NFS RootFolder e CorePath)
        $caminhosRegistro = @(
            @{ Chave = 'HKLM:\SOFTWARE\Veeam\Veeam Backup Catalog'; Valor = 'CatalogPath' },
            @{ Chave = 'HKLM:\SOFTWARE\Wow6432Node\Veeam\Veeam NFS'; Valor = 'RootFolder' },
            @{ Chave = 'HKLM:\SOFTWARE\Veeam\Veeam NFS'; Valor = 'RootFolder' },
            @{ Chave = 'HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication'; Valor = 'CorePath' }
        )

        foreach ($entradaReg in $caminhosRegistro) {
            $valorReg = Get-ValorRegistroSeguro -CaminhoChave $entradaReg.Chave -NomePropriedade $entradaReg.Valor
            if (-not [string]::IsNullOrWhiteSpace($valorReg)) {
                $regNormalizado = ConvertTo-CaminhoNormalizado -Caminho $valorReg
                if (Test-CaminhoSeguroParaExclusao -Caminho $regNormalizado) {
                    [void]$pastasBase.Add($regNormalizado)
                }
            }
        }

        # Auto-deteccao opcional de repositorios locais configurados no Veeam Backup & Replication
        if (-not $IgnorarAutoDeteccaoRepositorios) {
            $reposDetectados = @(Get-CaminhoRepositorioLocalVeeam)
            if ($reposDetectados.Count -gt 0) {
                Write-Host "  [INFO] Repositorios locais detectados automaticamente no Veeam: $($reposDetectados.Count)" -ForegroundColor Cyan
                foreach ($repoDetectado in $reposDetectados) {
                    [void]$pastasBase.Add($repoDetectado)
                }
            }
        }

        # Repositorios extras informados manualmente via -RepositoryPaths
        foreach ($repoInformado in $RepositoryPaths) {
            $repoNormalizado = ConvertTo-CaminhoNormalizado -Caminho $repoInformado
            if ([string]::IsNullOrWhiteSpace($repoNormalizado)) {
                continue
            }

            if (Test-CaminhoSeguroParaExclusao -Caminho $repoNormalizado) {
                [void]$pastasBase.Add($repoNormalizado)
            }
            else {
                Write-Host "  [AVISO] Caminho '$repoNormalizado' ignorado para evitar exclusao total do disco do sistema." -ForegroundColor Yellow
            }
        }

        $processosBase = New-Object 'System.Collections.Generic.List[string]'
        foreach ($proc in @(
            # Core, Gerenciamento, REST API, UI, Identidade e Updater (Veeam 12.3 + 13.0/13.1)
            'Veeam.Backup.Service.exe',
            'Veeam.Backup.Manager.exe',
            'Veeam.Backup.Shell.exe',
            'Veeam.Backup.UIServer.exe',
            'Veeam.Backup.BrokerService.exe',
            'VeeamBrokerService.exe',
            'Veeam.Backup.CatalogDataService.exe',
            'VeeamCatalogService.exe',
            'Veeam.Backup.MountService.exe',
            'VeeamMountService.exe',
            'Veeam.Backup.RestSvc.exe',
            'Veeam.Backup.RESTAPIService.exe',
            'Veeam.Backup.IdentityService.exe',
            'VeeamIdentitySvc.exe',
            'Veeam.Backup.WebService.exe',
            'Veeam.Web.Service.exe',
            'Veeam.Backup.Updater.exe',
            'Veeam.Backup.UpdateService.exe',
            'Veeam.Updater.Service.exe',
            'Veeam.Updater.exe',
            'VeeamUpdaterSvc.exe',

            # Seguranca, Threat Hunter e Analise de Dados (Veeam 12.3 + 13.0/13.1)
            'Veeam.ThreatHunterService.exe',
            'VeeamThreatHunterService.exe',
            'Veeam.DataAnalyzer.Service.exe',
            'VeeamDataAnalyzerService.exe',

            # Cloud, Hypervisors, Kasten e Entra ID (Veeam 12.3 + 13.0/13.1)
            'Veeam.Backup.CloudService.exe',
            'Veeam.CloudConnect.Service.exe',
            'Veeam.AHV.Service.exe',
            'VeeamAHVService.exe',
            'VeeamAHVSvc.exe',
            'Veeam.AWS.Service.exe',
            'VeeamAWSService.exe',
            'VeeamAWSSvc.exe',
            'Veeam.Azure.Service.exe',
            'VeeamAzureService.exe',
            'VeeamAzureSvc.exe',
            'Veeam.GCP.Service.exe',
            'VeeamGCPService.exe',
            'VeeamGCPSvc.exe',
            'Veeam.Kasten.Service.exe',
            'VeeamKastenService.exe',
            'VeeamKastenSvc.exe',
            'Veeam.KVM.Service.exe',
            'Veeam.RHV.Service.exe',
            'VeeamKVMService.exe',
            'VeeamRHVService.exe',
            'VeeamRHVSvc.exe',
            'Veeam.PVE.Service.exe',
            'Veeam.Backup.PveService.exe',
            'VeeamPVEservice.exe',
            'VeeamPVESvc.exe',
            'VeeamHvIntegrationSvc.exe',
            'Veeam.Backup.HvIntegrationService.exe',
            'Veeam.EntraId.Service.exe',
            'Veeam.EntraId.Worker.exe',
            'Veeam.Backup.EntraId.exe',

            # Transporte, Data Movers, CDP, VSS, NFS, Tape, WAN e Deploy
            'VeeamTransportSvc.exe',
            'VeeamTransportService.exe',
            'VeeamAgent.exe',
            'VeeamAgent64.exe',
            'veeam.agent.windows.exe',
            'Veeam.EndPoint.Service.exe',
            'Veeam.EndPoint.Manager.exe',
            'VeeamDeploymentSvc.exe',
            'VeeamDeploymentDll.exe',
            'VeeamInstallerService.exe',
            'VeeamDistributionSvc.exe',
            'VeeamDistributionService.exe',
            'Veeam.Backup.DistributionService.exe',
            'Veeam.Explorers.RecoveryService.exe',
            'VeeamExplorersRecoveryService.exe',
            'VeeamExplorersRecoverySvc.exe',
            'VeeamFilesysVssSvc.exe',
            'Veeam.VSSIntegration.Service.exe',
            'VeeamVssProviderSvc.exe',
            'VeeamVSSProviderService.exe',
            'VeeamNFSSvc.exe',
            'Veeam.Backup.CdpService.exe',
            'VeeamCdpCoordinatorService.exe',
            'VeeamBackupCdpSvc.exe',
            'VeeamWanAcceleratorSvc.exe',
            'Veeam.Backup.WanAcceleratorService.exe',
            'VeeamTapeSvc.exe',
            'Veeam.Backup.TapeService.exe',
            'VeeamTapeAccessSvc.exe',
            'VeeamLogShipperService.exe',
            'Veeam.Archiver.Service.exe',

            # Processos de Runtime / Workers sob demanda (maior impacto de I/O e CPU)
            'Veeam.Backup.Proxy.exe',
            'Veeam.Backup.ProxyService.exe',
            'Veeam.Backup.Agent.Configuration.exe',
            'Veeam.Backup.Agent.Recovery.exe',
            'Veeam.Backup.External.exe',
            'Veeam.Backup.Satellite.exe',
            'Veeam.Backup.WmiServer.exe',
            'Veeam.Backup.VssBridge.exe',
            'Veeam.Backup.Validator.exe',
            'Veeam.Backup.Extractor.exe',
            'Veeam.Backup.DBConfig.exe',
            'Veeam.Backup.ServiceHost.exe',
            'Veeam.Archiver.Proxy.exe',
            'Veeam.Guest.Interaction.Proxy.exe',
            'VeeamGuestHelperCtrl.exe'
        )) {
            [void]$processosBase.Add($proc)
        }

        # Descoberta dinamica dos executaveis reais dos servicos Veeam instalados no servidor
        $processosServicosLocais = @(Get-ProcessoServicoVeeamLocal)
        if ($processosServicosLocais.Count -gt 0) {
            Write-Host "  [INFO] Executaveis de servicos Veeam detectados no Windows: $($processosServicosLocais.Count)" -ForegroundColor Cyan
            foreach ($procLocal in $processosServicosLocais) {
                [void]$processosBase.Add($procLocal)
            }
        }

        if ($IncluirBancoLocal) {
            [void]$pastasBase.Add((Join-Path -Path $env:ProgramFiles -ChildPath 'PostgreSQL'))
            [void]$pastasBase.Add((Join-Path -Path $env:ProgramData -ChildPath 'PostgreSQL'))
            [void]$processosBase.Add('postgres.exe')
            [void]$processosBase.Add('pg_ctl.exe')
            [void]$processosBase.Add('sqlservr.exe')
        }
        else {
            $pastaPg = Join-Path -Path $env:ProgramFiles -ChildPath 'PostgreSQL'
            if (Test-Path -LiteralPath $pastaPg) {
                Write-Host "  [DICA] PostgreSQL detectado localmente. Se o banco do Veeam rodar neste servidor, avalie usar -IncluirBancoLocal." -ForegroundColor Cyan
            }
        }

        $extensoesBase = New-Object 'System.Collections.Generic.List[string]'
        foreach ($ext in @(
            '.vbk', '.vib', '.vrb', '.vbm', '.vlb', '.vab', '.vsb',
            '.vblobs', '.vslice', '.metadb', '.bco', '.vacm', '.vsm',
            '.vstore', '.vmcb', '.ridx',
            '.ctb', '.cbd', '.dvs', '.vpower'
        )) {
            [void]$extensoesBase.Add($ext)
        }

        if ($IncluirExtensoesSqlite) {
            [void]$extensoesBase.Add('.sqlite')
            [void]$extensoesBase.Add('.sqlite-wal')
            [void]$extensoesBase.Add('.sqlite-shm')
        }

        $todasPastas = @($pastasBase)
        $todosProcessos = @($processosBase)
        $todasExtensoes = @($extensoesBase)

        # -------------------------------------------------------------------------
        # Etapa 3: Aplicacao das exclusoes (com suporte a -WhatIf / Confirm)
        # -------------------------------------------------------------------------
        $etapa = 'Aplicacao de exclusoes no Microsoft Defender'

        if ($WhatIfPreference) {
            [void](Invoke-AplicacaoExclusaoCategoria -Tipo 'Path' -TituloSecao 'Simulando Exclusoes de Pastas' -ItensDesejados $todasPastas -ItensAtuais $preferenciasAtuais.ExclusionPath -SimularApenas -WhatIf:$false)
            [void](Invoke-AplicacaoExclusaoCategoria -Tipo 'Process' -TituloSecao 'Simulando Exclusoes de Processos' -ItensDesejados $todosProcessos -ItensAtuais $preferenciasAtuais.ExclusionProcess -SimularApenas -WhatIf:$false)
            [void](Invoke-AplicacaoExclusaoCategoria -Tipo 'Extension' -TituloSecao 'Simulando Exclusoes de Extensoes' -ItensDesejados $todasExtensoes -ItensAtuais $preferenciasAtuais.ExclusionExtension -SimularApenas -WhatIf:$false)

            $resumoPastasDepois = $resumoPastasAntes
            $resumoProcessosDepois = $resumoProcessosAntes
            $resumoExtensoesDepois = $resumoExtensoesAntes
            $status = 'Simulacao concluida; nenhuma alteracao aplicada'
            $corStatus = 'Yellow'
            $codigoSaida = 0
        }
        else {
            $confirmado = ($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess('Microsoft Defender (Preferencias Locais)', 'Aplicar exclusoes recomendadas KB1999 para Veeam')
            if ($confirmado) {
                $resPastas = Invoke-AplicacaoExclusaoCategoria -Tipo 'Path' -TituloSecao 'Aplicando Exclusoes de Pastas' -ItensDesejados $todasPastas -ItensAtuais $preferenciasAtuais.ExclusionPath -Confirm:$false
                $resProcessos = Invoke-AplicacaoExclusaoCategoria -Tipo 'Process' -TituloSecao 'Aplicando Exclusoes de Processos' -ItensDesejados $todosProcessos -ItensAtuais $preferenciasAtuais.ExclusionProcess -Confirm:$false
                $resExtensoes = Invoke-AplicacaoExclusaoCategoria -Tipo 'Extension' -TituloSecao 'Aplicando Exclusoes de Extensoes' -ItensDesejados $todasExtensoes -ItensAtuais $preferenciasAtuais.ExclusionExtension -Confirm:$false

                $resumoNovasPastas = $resPastas.AplicadosCount
                $resumoNovosProcessos = $resProcessos.AplicadosCount
                $resumoNovasExtensoes = $resExtensoes.AplicadosCount

                # -----------------------------------------------------------------
                # Etapa 4: Verificacao pos-gravacao (detecta bloqueio silencioso)
                # -----------------------------------------------------------------
                $etapa = 'Verificacao pos-gravacao das exclusoes'
                $preferenciasDepois = Get-MpPreference -ErrorAction Stop
                $resumoPastasDepois = @($preferenciasDepois.ExclusionPath).Count
                $resumoProcessosDepois = @($preferenciasDepois.ExclusionProcess).Count
                $resumoExtensoesDepois = @($preferenciasDepois.ExclusionExtension).Count

                $setPastasDepois = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($p in @($preferenciasDepois.ExclusionPath)) {
                    $pNorm = ConvertTo-CaminhoNormalizado -Caminho $p
                    if (-not [string]::IsNullOrWhiteSpace($pNorm)) { [void]$setPastasDepois.Add($pNorm) }
                }
                $setProcDepois = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($pr in @($preferenciasDepois.ExclusionProcess)) {
                    if (-not [string]::IsNullOrWhiteSpace($pr)) { [void]$setProcDepois.Add($pr.Trim()) }
                }
                $setExtDepois = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($ex in @($preferenciasDepois.ExclusionExtension)) {
                    if (-not [string]::IsNullOrWhiteSpace($ex)) { [void]$setExtDepois.Add($ex.Trim()) }
                }

                foreach ($itemEsperado in $resPastas.Pendentes) {
                    if (-not $setPastasDepois.Contains($itemEsperado)) { $resumoNaoPersistidos++ }
                }
                foreach ($itemEsperado in $resProcessos.Pendentes) {
                    if (-not $setProcDepois.Contains($itemEsperado)) { $resumoNaoPersistidos++ }
                }
                foreach ($itemEsperado in $resExtensoes.Pendentes) {
                    if (-not $setExtDepois.Contains($itemEsperado)) { $resumoNaoPersistidos++ }
                }

                $totalFalhasExecucao = $resPastas.FalhasCount + $resProcessos.FalhasCount + $resExtensoes.FalhasCount
                if ($totalFalhasExecucao -gt 0 -or $resumoNaoPersistidos -gt 0) {
                    $status = 'Concluido parcialmente (itens bloqueados ou descartados por politica)'
                    $corStatus = 'Yellow'
                    $codigoSaida = 1
                }
                else {
                    $status = 'Concluido e verificado'
                    $corStatus = 'Green'
                    $codigoSaida = 0
                }
            }
            else {
                $resumoPastasDepois = $resumoPastasAntes
                $resumoProcessosDepois = $resumoProcessosAntes
                $resumoExtensoesDepois = $resumoExtensoesAntes
                $status = 'Cancelado pelo operador; nenhuma alteracao aplicada'
                $corStatus = 'Yellow'
                $codigoSaida = 2
            }
        }
    }
    catch {
        Write-Error -Message "Falha na etapa: $etapa. Verifique o estado do Microsoft Defender antes de repetir." -ErrorAction Continue
        $status = 'Falha durante a execucao'
        $corStatus = 'Red'
        $codigoSaida = 1
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:            $status" -ForegroundColor $corStatus
Write-Host "  - Pastas ativas:     $resumoPastasDepois (antes: $resumoPastasAntes | adicionadas: $resumoNovasPastas)" -ForegroundColor White
Write-Host "  - Processos ativos:  $resumoProcessosDepois (antes: $resumoProcessosAntes | adicionados: $resumoNovosProcessos)" -ForegroundColor White
Write-Host "  - Extensoes ativas:  $resumoExtensoesDepois (antes: $resumoExtensoesAntes | adicionadas: $resumoNovasExtensoes)" -ForegroundColor White
if ($resumoNaoPersistidos -gt 0 -or $avisoPoliticaCentral) {
    Write-Host "  - Alerta politica:   $resumoNaoPersistidos item(ns) nao persistido(s); verifique GPO/Intune/TPExclusions" -ForegroundColor Yellow
}
Write-Host "  - Codigo de saida:   $codigoSaida" -ForegroundColor $corStatus
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

# Quando executado via Invoke-Expression (iex), usa return para nao fechar a janela do PowerShell do operador
if ([string]::IsNullOrEmpty($PSCommandPath)) {
    return
}

exit $codigoSaida
