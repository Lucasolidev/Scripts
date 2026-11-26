# ==============================================================================
# Execucao recomendada (copiar e colar comando unico no PowerShell como Administrador):
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/verificar_seguranca_windows.ps1 | iex
#
# Execucao remota incluindo loopback, tarefas Microsoft e exportacao de relatorio:
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Lucasolidev/Scripts/main/verificar_seguranca_windows.ps1))) -IncluirLoopback -IncluirTarefasMicrosoft -CaminhoRelatorio 'C:\Temp\auditoria_seguranca.txt'
# ==============================================================================

<#
.SYNOPSIS
    Executa auditoria local de seguranca no Windows para identificar sinais de invasao ou malware.
.DESCRIPTION
    Script PowerShell compativel com Windows PowerShell 5.1 e PowerShell 7.
    Automatiza no console as verificacoes locais recomendadas para triagem de comprometimento:
      1. Conexoes TCP ativas agrupadas por processo e portas em escuta unificadas (IPv4/IPv6).
      2. Contas de usuario locais em tabela alinhada (detecta contas ocultas ou convidado ativa).
      3. Membros do grupo local de Administradores (via SID S-1-5-32-544 com fallback seguro).
      4. Tarefas agendadas ativas para identificacao de persistencia e comandos suspeitos.
    Nao instala ferramentas externas (como Process Explorer) e nao altera configuracoes do sistema.
.PARAMETER IncluirLoopback
    Quando informado, inclui conexoes TCP locais (127.0.0.1 e ::1) na listagem de conexoes ativas.
.PARAMETER IncluirTarefasMicrosoft
    Quando informado, lista todas as tarefas agendadas ativas da pasta \Microsoft\ alem das de terceiros.
.PARAMETER CaminhoRelatorio
    Caminho completo de arquivo texto para exportar o relatorio da auditoria (nao sobrescreve arquivo existente).
.EXAMPLE
    .\verificar_seguranca_windows.ps1
.EXAMPLE
    .\verificar_seguranca_windows.ps1 -IncluirLoopback -IncluirTarefasMicrosoft
.EXAMPLE
    .\verificar_seguranca_windows.ps1 -CaminhoRelatorio "C:\Temp\auditoria_seguranca.txt"
.EXAMPLE
    .\verificar_seguranca_windows.ps1 -WhatIf
.NOTES
    Versao: 1.1
    Requisitos: Windows PowerShell 5.1 ou PowerShell 7 no Windows.
    Privilegios: Recomendado executar como Administrador para visibilidade completa de caminhos
    de processos elevados e tarefas agendadas de sistema; funciona sem elevacao em modo limitado.
    Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento pelo operador.
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
param(
    [Parameter(Mandatory = $false)]
    [switch]$IncluirLoopback,

    [Parameter(Mandatory = $false)]
    [switch]$IncluirTarefasMicrosoft,

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$CaminhoRelatorio
)

$ErrorActionPreference = 'Stop'
$codigoSaida = 1
$status = 'Falha'
$corStatus = 'Red'
$etapa = 'Validacao inicial'

function Test-PrivilegioAdministrador {
    <#
    .SYNOPSIS
        Verifica se a sessao atual do PowerShell esta em execucao com privilegios de Administrador.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidade)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-TituloSecao {
    <#
    .SYNOPSIS
        Exibe um cabecalho padronizado de secao no console.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Cabecalho visual de console para o operador')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Titulo
    )

    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host " $Titulo" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
}

function Show-LinhaComTag {
    <#
    .SYNOPSIS
        Exibe uma linha com selo colorido alinhado seguido pelo texto principal e cor secundaria opcional.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Renderizacao colorida de tags no console')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Tag,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CorTag,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Texto,

        [Parameter(Mandatory = $false)]
        [string]$CorTexto = 'White'
    )

    $tagFormatada = ("[$Tag]").PadRight(10)
    Write-Host ("  $tagFormatada ") -ForegroundColor $CorTag -NoNewline
    Write-Host $Texto -ForegroundColor $CorTexto
}

function Format-CaminhoCompacto {
    <#
    .SYNOPSIS
        Encurta caminhos muito longos no meio apenas para exibicao limpa no console.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Caminho,

        [Parameter(Mandatory = $false)]
        [int]$LarguraMaxima = 78
    )

    if ([string]::IsNullOrWhiteSpace($Caminho) -or $Caminho.Length -le $LarguraMaxima) {
        return $Caminho
    }

    $inicio = $Caminho.Substring(0, 32)
    $fim = $Caminho.Substring($Caminho.Length - 38)
    return "$inicio...$fim"
}

function Get-NomeServicoPorta {
    <#
    .SYNOPSIS
        Identifica servicos TCP conhecidos e indica se a porta exige atencao quando exposta na rede.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Porta
    )

    switch ($Porta) {
        21 { return [PSCustomObject]@{ Servico = 'FTP'; Sensivel = $true } }
        22 { return [PSCustomObject]@{ Servico = 'SSH'; Sensivel = $true } }
        23 { return [PSCustomObject]@{ Servico = 'Telnet'; Sensivel = $true } }
        80 { return [PSCustomObject]@{ Servico = 'HTTP'; Sensivel = $false } }
        135 { return [PSCustomObject]@{ Servico = 'RPC'; Sensivel = $false } }
        139 { return [PSCustomObject]@{ Servico = 'NetBIOS'; Sensivel = $true } }
        443 { return [PSCustomObject]@{ Servico = 'HTTPS'; Sensivel = $false } }
        445 { return [PSCustomObject]@{ Servico = 'SMB'; Sensivel = $true } }
        3389 { return [PSCustomObject]@{ Servico = 'RDP'; Sensivel = $true } }
        5985 { return [PSCustomObject]@{ Servico = 'WinRM-HTTP'; Sensivel = $true } }
        5986 { return [PSCustomObject]@{ Servico = 'WinRM-HTTPS'; Sensivel = $true } }
        default { return [PSCustomObject]@{ Servico = 'Porta-TCP'; Sensivel = $false } }
    }
}

function Test-CaminhoSuspeito {
    <#
    .SYNOPSIS
        Verifica se um caminho de executavel pertence a diretorios frequentemente usados para persistencia.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Caminho
    )

    if ([string]::IsNullOrWhiteSpace($Caminho)) {
        return $false
    }

    $padroes = @(
        '\\AppData\\',
        '\\Temp\\',
        '\\Windows\\Temp\\',
        '\\Downloads\\',
        '\\Users\\Public\\',
        '\\ProgramData\\'
    )

    foreach ($padrao in $padroes) {
        if ($Caminho -match $padrao) {
            return $true
        }
    }

    return $false
}

function Test-ComandoSuspeito {
    <#
    .SYNOPSIS
        Avalia se uma linha de comando ou acao de tarefa agendada contem indicadores suspeitos.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Comando
    )

    if ([string]::IsNullOrWhiteSpace($Comando)) {
        return $false
    }

    $possuiLolbin = $Comando -match '(?i)\b(powershell(\.exe)?|pwsh(\.exe)?|cmd(\.exe)?|mshta(\.exe)?|wscript(\.exe)?|cscript(\.exe)?|rundll32(\.exe)?|regsvr32(\.exe)?|certutil(\.exe)?|bitsadmin(\.exe)?)\b'
    if (-not $possuiLolbin) {
        return $false
    }

    if ($Comando -match '(?i)\b(mshta|wscript|cscript)(\.exe)?\b') {
        return $true
    }

    $possuiIndicadorRisco = $Comando -match '(?i)(-enc\b|-encodedcommand\b|frombase64string|downloadstring|invoke-webrequest|iwr\s+http|https?://|\\appdata\\|\\temp\\|\\users\\public\\)'
    return $possuiIndicadorRisco
}

function Get-MapaProcessoAtivo {
    <#
    .SYNOPSIS
        Mapeia processos ativos por PID com caminho do executavel e status de assinatura digital em cache.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $mapaProcessos = @{}
    $cacheAssinaturas = @{}

    $processosCim = $null
    try {
        $processosCim = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop
    }
    catch {
        $processosCim = $null
    }

    if ($null -ne $processosCim) {
        foreach ($proc in $processosCim) {
            $pidAtual = [int]$proc.ProcessId
            $caminhoExe = $proc.ExecutablePath
            $statusAssinatura = 'Nao verificado'

            if (-not [string]::IsNullOrWhiteSpace($caminhoExe)) {
                if ($cacheAssinaturas.ContainsKey($caminhoExe)) {
                    $statusAssinatura = $cacheAssinaturas[$caminhoExe]
                }
                elseif (Test-Path -LiteralPath $caminhoExe) {
                    try {
                        $assinatura = Get-AuthenticodeSignature -LiteralPath $caminhoExe -ErrorAction Stop
                        $statusAssinatura = [string]$assinatura.Status
                    }
                    catch {
                        $statusAssinatura = 'Erro na leitura'
                    }
                    $cacheAssinaturas[$caminhoExe] = $statusAssinatura
                }
                else {
                    $statusAssinatura = 'Arquivo nao localizado'
                    $cacheAssinaturas[$caminhoExe] = $statusAssinatura
                }
            }
            elseif ($pidAtual -eq 0 -or $pidAtual -eq 4) {
                $statusAssinatura = 'Kernel/Sistema'
            }

            $mapaProcessos[$pidAtual] = [PSCustomObject]@{
                PID             = $pidAtual
                Nome            = [string]$proc.Name
                Caminho         = [string]$caminhoExe
                Assinatura      = $statusAssinatura
                CaminhoSuspeito = (Test-CaminhoSuspeito -Caminho $caminhoExe)
            }
        }
        return $mapaProcessos
    }

    $processosFallback = Get-Process -ErrorAction SilentlyContinue
    foreach ($proc in $processosFallback) {
        $pidAtual = [int]$proc.Id
        $caminhoExe = ''
        try {
            $caminhoExe = [string]$proc.Path
        }
        catch {
            $caminhoExe = ''
        }

        $statusAssinatura = 'Nao verificado'
        if (-not [string]::IsNullOrWhiteSpace($caminhoExe)) {
            if ($cacheAssinaturas.ContainsKey($caminhoExe)) {
                $statusAssinatura = $cacheAssinaturas[$caminhoExe]
            }
            elseif (Test-Path -LiteralPath $caminhoExe) {
                try {
                    $assinatura = Get-AuthenticodeSignature -LiteralPath $caminhoExe -ErrorAction Stop
                    $statusAssinatura = [string]$assinatura.Status
                }
                catch {
                    $statusAssinatura = 'Erro na leitura'
                }
                $cacheAssinaturas[$caminhoExe] = $statusAssinatura
            }
        }

        $mapaProcessos[$pidAtual] = [PSCustomObject]@{
            PID             = $pidAtual
            Nome            = [string]$proc.ProcessName
            Caminho         = $caminhoExe
            Assinatura      = $statusAssinatura
            CaminhoSuspeito = (Test-CaminhoSuspeito -Caminho $caminhoExe)
        }
    }

    return $mapaProcessos
}

function Get-ConexoesTcpFallbackNetstat {
    <#
    .SYNOPSIS
        Le conexoes TCP via netstat.exe -ano quando Get-NetTCPConnection nao esta disponivel.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $saidaNetstat = & netstat.exe -ano 2>$null
    $netstatExit = $LASTEXITCODE
    if ($netstatExit -ne 0) {
        throw "Falha ao executar netstat.exe -ano (codigo $netstatExit)."
    }

    $lista = New-Object System.Collections.Generic.List[object]
    foreach ($linha in $saidaNetstat) {
        $texto = [string]$linha
        if ($texto -match '^\s*TCP\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s*$') {
            $origem = $Matches[1]
            $destino = $Matches[2]
            $estadoBruto = $Matches[3].ToUpperInvariant()
            $pidNumero = [int]$Matches[4]

            $localIp = $origem
            $localPort = 0
            if ($origem -match '^(.+):(\d+)$') {
                $localIp = $Matches[1].Trim('[', ']')
                $localPort = [int]$Matches[2]
            }

            $remotoIp = $destino
            $remotoPort = 0
            if ($destino -match '^(.+):(\d+)$') {
                $remotoIp = $Matches[1].Trim('[', ']')
                $remotoPort = [int]$Matches[2]
            }

            $estadoNormalizado = switch ($estadoBruto) {
                'LISTENING' { 'Listen' }
                'ESTABLISHED' { 'Established' }
                default { $estadoBruto }
            }

            $lista.Add([PSCustomObject]@{
                LocalAddress  = $localIp
                LocalPort     = $localPort
                RemoteAddress = $remotoIp
                RemotePort    = $remotoPort
                State         = $estadoNormalizado
                OwningProcess = $pidNumero
            })
        }
    }

    return $lista.ToArray()
}

function Invoke-AuditoriaRede {
    <#
    .SYNOPSIS
        Audita conexoes TCP agrupadas por processo e portas em escuta unificadas (IPv4/IPv6).
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Exibicao interativa dos resultados de rede no console')]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$MapaProcessos,

        [Parameter(Mandatory = $false)]
        [switch]$MostrarLoopback
    )

    Show-TituloSecao -Titulo '1. Auditoria de Rede e Processos (netstat + tasklist)'

    $linhasRelatorio = New-Object System.Collections.Generic.List[string]
    $linhasRelatorio.Add('=== 1. AUDITORIA DE REDE E PROCESSOS ===')
    $alertasConsolidados = New-Object System.Collections.Generic.List[string]

    $conexoes = $null
    if (Get-Command -Name 'Get-NetTCPConnection' -ErrorAction SilentlyContinue) {
        $conexoes = Get-NetTCPConnection -ErrorAction Stop
    }
    else {
        $conexoes = Get-ConexoesTcpFallbackNetstat
    }

    $enderecosLocais = @('127.0.0.1', '::1', '0.0.0.0', '::')
    $gruposConexoes = @{}
    $gruposEscuta = @{}
    $totalConexoesBrutas = 0

    foreach ($conn in $conexoes) {
        $estadoConn = [string]$conn.State
        $pidConn = [int]$conn.OwningProcess
        $infoProc = $MapaProcessos[$pidConn]

        $nomeProc = if ($null -ne $infoProc -and -not [string]::IsNullOrWhiteSpace($infoProc.Nome)) { $infoProc.Nome } else { "PID-$pidConn" }
        $caminhoProc = if ($null -ne $infoProc -and -not [string]::IsNullOrWhiteSpace($infoProc.Caminho)) { $infoProc.Caminho } else { '<sem acesso / sistema>' }
        $assinaturaProc = if ($null -ne $infoProc) { $infoProc.Assinatura } else { 'Nao verificado' }
        $caminhoSuspeito = if ($null -ne $infoProc) { [bool]$infoProc.CaminhoSuspeito } else { $false }

        if ($estadoConn -eq 'Established') {
            $remoto = [string]$conn.RemoteAddress
            $ehLoopback = ($enderecosLocais -contains $remoto)
            if (-not $MostrarLoopback -and $ehLoopback) {
                continue
            }

            $totalConexoesBrutas++
            if (-not $gruposConexoes.ContainsKey($pidConn)) {
                $gruposConexoes[$pidConn] = [PSCustomObject]@{
                    PID             = $pidConn
                    Processo        = $nomeProc
                    Assinatura      = $assinaturaProc
                    Caminho         = $caminhoProc
                    CaminhoSuspeito = $caminhoSuspeito
                    EhExterno       = (-not $ehLoopback)
                    Destinos        = (New-Object System.Collections.Generic.HashSet[string])
                    TotalConexoes   = 0
                }
            }

            $grupoAtual = $gruposConexoes[$pidConn]
            $grupoAtual.TotalConexoes++
            if (-not $ehLoopback) {
                $grupoAtual.EhExterno = $true
            }
            [void]$grupoAtual.Destinos.Add("${remoto}:$($conn.RemotePort)")
        }
        elseif ($estadoConn -eq 'Listen') {
            $localAddr = [string]$conn.LocalAddress
            $portaLocal = [int]$conn.LocalPort
            $chaveEscuta = "$pidConn|$portaLocal"

            if (-not $gruposEscuta.ContainsKey($chaveEscuta)) {
                $gruposEscuta[$chaveEscuta] = [PSCustomObject]@{
                    PID        = $pidConn
                    Processo   = $nomeProc
                    Assinatura = $assinaturaProc
                    Porta      = $portaLocal
                    Enderecos  = (New-Object System.Collections.Generic.HashSet[string])
                }
            }
            [void]$gruposEscuta[$chaveEscuta].Enderecos.Add($localAddr)
        }
    }

    $listaProcessosRede = New-Object System.Collections.Generic.List[object]
    foreach ($chave in $gruposConexoes.Keys) {
        $item = $gruposConexoes[$chave]
        $assinaturaInvalida = ($item.Assinatura -ne 'Valid' -and $item.Assinatura -ne 'Kernel/Sistema' -and $item.Assinatura -ne 'Nao verificado')
        $motivos = New-Object System.Collections.Generic.List[string]
        if ($item.EhExterno -and $assinaturaInvalida) {
            $motivos.Add("Assinatura $($item.Assinatura)")
        }
        if ($item.EhExterno -and $item.CaminhoSuspeito) {
            $motivos.Add('Caminho em pasta de usuario/temporaria')
        }

        $requerAtencao = ($motivos.Count -gt 0)
        $motivoTexto = if ($requerAtencao) { $motivos -join ' + ' } else { '' }
        if ($requerAtencao) {
            $alertasConsolidados.Add("[REDE] $($item.Processo) (PID $($item.PID)) - $motivoTexto")
        }

        $destinosOrdenados = @($item.Destinos) | Sort-Object
        $listaProcessosRede.Add([PSCustomObject]@{
            Prioridade    = if ($requerAtencao) { 0 } else { 1 }
            Tag           = if ($requerAtencao) { 'REVISAR' } else { 'OK' }
            PID           = $item.PID
            Processo      = $item.Processo
            Assinatura    = $item.Assinatura
            Caminho       = $item.Caminho
            TotalConexoes = $item.TotalConexoes
            Destinos      = $destinosOrdenados
            Motivo        = $motivoTexto
        })
    }

    $processosOrdenados = $listaProcessosRede | Sort-Object -Property Prioridade, Processo, PID
    Write-Host "Conexoes TCP Ativas ($($listaProcessosRede.Count) processos / $totalConexoesBrutas conexoes):" -ForegroundColor White
    $linhasRelatorio.Add("Conexoes TCP Ativas ($($listaProcessosRede.Count) processos / $totalConexoesBrutas conexoes):")

    if ($listaProcessosRede.Count -eq 0) {
        Write-Host "  Nenhuma conexao TCP externa estabelecida no momento." -ForegroundColor Green
        $linhasRelatorio.Add('Nenhuma conexao TCP externa estabelecida no momento.')
    }
    else {
        foreach ($procRede in $processosOrdenados) {
            $corTag = if ($procRede.Tag -eq 'REVISAR') { 'Yellow' } else { 'Green' }
            $sufixoConexoes = if ($procRede.TotalConexoes -eq 1) { '1 conexao' } else { "$($procRede.TotalConexoes) conexoes" }
            $nomePid = ("$($procRede.Processo) (PID $($procRede.PID))").PadRight(32)
            $assinaturaCol = ("Assinatura: $($procRede.Assinatura)").PadRight(26)
            $linhaTopo = "$nomePid | $assinaturaCol | $sufixoConexoes"

            Show-LinhaComTag -Tag $procRede.Tag -CorTag $corTag -Texto $linhaTopo -CorTexto 'White'

            $caminhoTela = if ($procRede.Tag -eq 'REVISAR') { $procRede.Caminho } else { Format-CaminhoCompacto -Caminho $procRede.Caminho }
            Write-Host "             Caminho:  $caminhoTela" -ForegroundColor DarkGray

            $destinosPreview = if ($procRede.Destinos.Count -gt 4) {
                (($procRede.Destinos | Select-Object -First 4) -join ', ') + " (+$($procRede.Destinos.Count - 4) IPs)"
            }
            else {
                $procRede.Destinos -join ', '
            }
            Write-Host "             Destinos: $destinosPreview" -ForegroundColor DarkGray

            if (-not [string]::IsNullOrWhiteSpace($procRede.Motivo)) {
                Write-Host "             Motivo:   $($procRede.Motivo)" -ForegroundColor Yellow
            }

            $linhasRelatorio.Add("[$($procRede.Tag)] $linhaTopo | Caminho: $($procRede.Caminho) | Destinos: $($procRede.Destinos -join ', ')")
        }
    }

    # Unificacao e classificacao de portas em escuta
    $expostasRede = New-Object System.Collections.Generic.List[object]
    $internasPorProc = @{}
    $totalPortasUnificadas = $gruposEscuta.Count

    foreach ($chave in $gruposEscuta.Keys) {
        $esc = $gruposEscuta[$chave]
        $addrs = @($esc.Enderecos)
        $temV4All = ($addrs -contains '0.0.0.0')
        $temV6All = ($addrs -contains '::')
        $apenasLoopback = $true
        foreach ($a in $addrs) {
            if ($a -ne '127.0.0.1' -and $a -ne '::1') {
                $apenasLoopback = $false
                break
            }
        }

        $bindLabel = if ($temV4All -and $temV6All) {
            "*:$($esc.Porta) (Dual)"
        }
        elseif ($temV4All) {
            "0.0.0.0:$($esc.Porta)"
        }
        elseif ($temV6All) {
            ":::$($esc.Porta)"
        }
        else {
            "$($addrs[0]):$($esc.Porta)"
        }

        $infoPorta = Get-NomeServicoPorta -Porta $esc.Porta
        $ehDinamica = ($esc.Porta -ge 49152)

        if ((-not $apenasLoopback) -and (-not $ehDinamica)) {
            $expostasRede.Add([PSCustomObject]@{
                Porta      = $esc.Porta
                Bind       = $bindLabel
                Servico    = $infoPorta.Servico
                Sensivel   = $infoPorta.Sensivel
                PID        = $esc.PID
                Processo   = $esc.Processo
                Assinatura = $esc.Assinatura
            })
        }
        else {
            $chaveProcInterno = "$($esc.PID)|$apenasLoopback"
            if (-not $internasPorProc.ContainsKey($chaveProcInterno)) {
                $internasPorProc[$chaveProcInterno] = [PSCustomObject]@{
                    PID        = $esc.PID
                    Processo   = $esc.Processo
                    Escopo     = if ($apenasLoopback) { 'Localhost' } else { 'RPC/Dinamica' }
                    Portas     = (New-Object System.Collections.Generic.List[int])
                }
            }
            $internasPorProc[$chaveProcInterno].Portas.Add($esc.Porta)
        }
    }

    Write-Host "`nPortas TCP em Escuta ($totalPortasUnificadas portas unificadas):" -ForegroundColor White
    $linhasRelatorio.Add("Portas TCP em Escuta ($totalPortasUnificadas portas unificadas):")

    if ($expostasRede.Count -gt 0) {
        Write-Host "  Portas Expostas na Rede:" -ForegroundColor White
        foreach ($exp in ($expostasRede | Sort-Object -Property Porta, PID)) {
            $tagPorta = if ($exp.Sensivel) { 'REDE!' } else { 'REDE' }
            $corPorta = if ($exp.Sensivel) { 'Yellow' } else { 'White' }
            $bindCol = $exp.Bind.PadRight(18)
            $svcCol = $exp.Servico.PadRight(11)
            $textoExp = "$bindCol | $svcCol | PID $($exp.PID) ($($exp.Processo))"
            Show-LinhaComTag -Tag $tagPorta -CorTag $corPorta -Texto $textoExp -CorTexto 'White'
            $linhasRelatorio.Add("[$tagPorta] $textoExp")
        }
    }

    if ($internasPorProc.Count -gt 0) {
        Write-Host "  Portas Locais / Dinamicas (agrupadas por processo):" -ForegroundColor DarkGray
        $listaInternas = $internasPorProc.Values | Sort-Object -Property Escopo, Processo, PID
        foreach ($intItem in $listaInternas) {
            $portasOrdenadas = ($intItem.Portas | Sort-Object) -join ', '
            $escopoCol = $intItem.Escopo.PadRight(12)
            $procCol = ("$($intItem.Processo) (PID $($intItem.PID))").PadRight(32)
            $linhaInt = "  [$escopoCol] $procCol -> $portasOrdenadas"
            Write-Host $linhaInt -ForegroundColor DarkGray
            $linhasRelatorio.Add($linhaInt.TrimStart())
        }
    }

    return [PSCustomObject]@{
        TotalProcessosRede    = $listaProcessosRede.Count
        TotalEstabelecidas    = $totalConexoesBrutas
        TotalEscuta           = $totalPortasUnificadas
        TotalAlertas          = $alertasConsolidados.Count
        Alertas               = $alertasConsolidados
        LinhasRelatorio       = $linhasRelatorio
    }
}

function Invoke-AuditoriaUsuarioLocal {
    <#
    .SYNOPSIS
        Lista contas locais em formato tabular alinhado, priorizando alertas no topo.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Exibicao interativa das contas locais no console')]
    param()

    Show-TituloSecao -Titulo '2. Auditoria de Contas de Usuario Locais (net user)'

    $linhasRelatorio = New-Object System.Collections.Generic.List[string]
    $linhasRelatorio.Add('=== 2. CONTAS DE USUARIO LOCAIS ===')
    $alertasConsolidados = New-Object System.Collections.Generic.List[string]

    $contas = New-Object System.Collections.Generic.List[object]
    if (Get-Command -Name 'Get-LocalUser' -ErrorAction SilentlyContinue) {
        $usuariosLocais = Get-LocalUser -ErrorAction Stop
        foreach ($usr in $usuariosLocais) {
            $sidTexto = [string]$usr.SID.Value
            $ehOculta = ([string]$usr.Name).EndsWith('$')
            $ehConvidadoAtivo = ($sidTexto -match '-501$') -and ([bool]$usr.Enabled)
            $alerta = $ehOculta -or $ehConvidadoAtivo

            $contas.Add([PSCustomObject]@{
                Prioridade  = if ($alerta) { 0 } elseif ($usr.Enabled) { 1 } else { 2 }
                Alerta      = $alerta
                Motivo      = if ($ehOculta) { 'Conta oculta terminada em $' } elseif ($ehConvidadoAtivo) { 'Conta Convidado/Guest habilitada' } else { '' }
                Nome        = [string]$usr.Name
                Habilitada  = [bool]$usr.Enabled
                UltimoLogon = if ($null -ne $usr.LastLogon) { $usr.LastLogon.ToString('yyyy-MM-dd HH:mm') } else { 'Nunca' }
            })
        }
    }
    else {
        $usuariosCim = Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop
        foreach ($usr in $usuariosCim) {
            $habilitada = (-not [bool]$usr.Disabled)
            $ehOculta = ([string]$usr.Name).EndsWith('$')
            $ehConvidadoAtivo = ([string]$usr.SID -match '-501$') -and $habilitada
            $alerta = $ehOculta -or $ehConvidadoAtivo

            $contas.Add([PSCustomObject]@{
                Prioridade  = if ($alerta) { 0 } elseif ($habilitada) { 1 } else { 2 }
                Alerta      = $alerta
                Motivo      = if ($ehOculta) { 'Conta oculta terminada em $' } elseif ($ehConvidadoAtivo) { 'Conta Convidado/Guest habilitada' } else { '' }
                Nome        = [string]$usr.Name
                Habilitada  = $habilitada
                UltimoLogon = 'Indisponivel'
            })
        }
    }

    Write-Host ("  {0,-10} {1,-24} {2,-12} {3}" -f 'STATUS', 'CONTA', 'ESTADO', 'ULTIMO LOGON') -ForegroundColor White
    Write-Host "  ------------------------------------------------------------------" -ForegroundColor DarkGray

    $ativas = 0
    foreach ($conta in ($contas | Sort-Object -Property Prioridade, Nome)) {
        if ($conta.Habilitada) {
            $ativas++
        }

        if ($conta.Alerta) {
            $alertasConsolidados.Add("[USUARIO] $($conta.Nome) - $($conta.Motivo)")
        }

        $estadoTexto = if ($conta.Habilitada) { 'Ativa' } else { 'Desativada' }
        $tag = if ($conta.Alerta) { 'REVISAR' } elseif ($conta.Habilitada) { 'ATIVA' } else { 'INATIVA' }
        $corTag = if ($conta.Alerta) { 'Yellow' } elseif ($conta.Habilitada) { 'Green' } else { 'DarkGray' }
        $corLinha = if ($conta.Alerta) { 'Yellow' } elseif ($conta.Habilitada) { 'White' } else { 'DarkGray' }

        $linhaTabela = "{0,-24} {1,-12} {2}" -f $conta.Nome, $estadoTexto, $conta.UltimoLogon
        Show-LinhaComTag -Tag $tag -CorTag $corTag -Texto $linhaTabela -CorTexto $corLinha
        if ($conta.Alerta) {
            Write-Host "             Motivo: $($conta.Motivo)" -ForegroundColor Yellow
        }
        $linhasRelatorio.Add("[$tag] $linhaTabela")
    }

    return [PSCustomObject]@{
        TotalContas     = $contas.Count
        ContasAtivas    = $ativas
        TotalAlertas    = $alertasConsolidados.Count
        Alertas         = $alertasConsolidados
        LinhasRelatorio = $linhasRelatorio
    }
}

function Invoke-AuditoriaGrupoAdmin {
    <#
    .SYNOPSIS
        Lista os membros do grupo local de Administradores pelo SID S-1-5-32-544 em formato alinhado.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Exibicao interativa dos membros administradores no console')]
    param()

    Show-TituloSecao -Titulo '3. Membros do Grupo Administradores (SID S-1-5-32-544)'

    $linhasRelatorio = New-Object System.Collections.Generic.List[string]
    $linhasRelatorio.Add('=== 3. GRUPO LOCAL DE ADMINISTRADORES ===')

    $membros = New-Object System.Collections.Generic.List[object]
    $usouFallback = $false

    if (Get-Command -Name 'Get-LocalGroupMember' -ErrorAction SilentlyContinue) {
        try {
            $resultado = Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop
            foreach ($membro in $resultado) {
                $membros.Add([PSCustomObject]@{
                    Conta  = [string]$membro.Name
                    Origem = "$($membro.ObjectClass) / $($membro.PrincipalSource)"
                })
            }
        }
        catch {
            $usouFallback = $true
        }
    }
    else {
        $usouFallback = $true
    }

    if ($usouFallback) {
        $sidAdmin = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $contaTraduzida = $sidAdmin.Translate([System.Security.Principal.NTAccount]).Value
        $nomeGrupo = ($contaTraduzida -split '\\')[-1]

        $saidaNet = & net.exe localgroup $nomeGrupo 2>$null
        $netExit = $LASTEXITCODE
        if ($netExit -ne 0) {
            throw "Nao foi possivel listar o grupo local de administradores ($nomeGrupo, codigo $netExit)."
        }

        $capturando = $false
        foreach ($linha in $saidaNet) {
            $texto = ([string]$linha).Trim()
            if ($texto -match '^-{4,}$') {
                $capturando = $true
                continue
            }
            if ($capturando) {
                if ([string]::IsNullOrWhiteSpace($texto)) {
                    continue
                }
                if ($texto -match '^(The command completed|Comando concluido)') {
                    break
                }
                $membros.Add([PSCustomObject]@{
                    Conta  = $texto
                    Origem = 'net localgroup'
                })
            }
        }
    }

    if ($membros.Count -eq 0) {
        Write-Host "  Nenhum membro retornado para o grupo de administradores." -ForegroundColor Yellow
        $linhasRelatorio.Add('Nenhum membro retornado para o grupo de administradores.')
    }
    else {
        Write-Host ("  {0,-10} {1,-34} {2}" -f 'SELO', 'CONTA', 'ORIGEM / TIPO') -ForegroundColor White
        Write-Host "  ------------------------------------------------------------------" -ForegroundColor DarkGray
        foreach ($membro in $membros) {
            $textoLinha = "{0,-34} {1}" -f $membro.Conta, $membro.Origem
            Show-LinhaComTag -Tag 'ADMIN' -CorTag 'Cyan' -Texto $textoLinha -CorTexto 'White'
            $linhasRelatorio.Add("[ADMIN] $textoLinha")
        }
    }

    return [PSCustomObject]@{
        TotalMembros    = $membros.Count
        LinhasRelatorio = $linhasRelatorio
    }
}

function Invoke-AuditoriaTarefaAgendada {
    <#
    .SYNOPSIS
        Audita tarefas agendadas ativas, priorizando comandos suspeitos no topo e separando detalhes.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Exibicao interativa das tarefas agendadas no console')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$MostrarMicrosoft
    )

    Show-TituloSecao -Titulo '4. Auditoria de Tarefas Agendadas (schtasks /query)'

    $linhasRelatorio = New-Object System.Collections.Generic.List[string]
    $linhasRelatorio.Add('=== 4. TAREFAS AGENDADAS ATIVAS ===')
    $alertasConsolidados = New-Object System.Collections.Generic.List[string]

    if (-not (Get-Command -Name 'Get-ScheduledTask' -ErrorAction SilentlyContinue)) {
        Write-Host "  Modulo ScheduledTasks indisponivel neste ambiente; pulando etapa." -ForegroundColor Yellow
        $linhasRelatorio.Add('Modulo ScheduledTasks indisponivel.')
        return [PSCustomObject]@{
            TotalNaoMicrosoft = 0
            TotalAlertas      = 0
            Alertas           = $alertasConsolidados
            LinhasRelatorio   = $linhasRelatorio
        }
    }

    $tarefasAtivas = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.State -ne 'Disabled' }
    $exibidas = New-Object System.Collections.Generic.List[object]
    $totalNaoMicrosoft = 0

    foreach ($tarefa in $tarefasAtivas) {
        $caminhoTarefa = [string]$tarefa.TaskPath
        $ehMicrosoft = $caminhoTarefa.StartsWith('\Microsoft\', [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $ehMicrosoft) {
            $totalNaoMicrosoft++
        }

        $listaAcoes = New-Object System.Collections.Generic.List[string]
        foreach ($acao in $tarefa.Actions) {
            if (-not [string]::IsNullOrWhiteSpace($acao.Execute)) {
                $cmdCompleto = "$($acao.Execute) $($acao.Arguments)".Trim()
                $listaAcoes.Add($cmdCompleto)
            }
        }
        $comandoConcatenado = ($listaAcoes -join ' ; ')
        $suspeita = Test-ComandoSuspeito -Comando $comandoConcatenado

        if ($suspeita) {
            $alertasConsolidados.Add("[TAREFA] $caminhoTarefa$($tarefa.TaskName) - Comando suspeito detectado")
        }

        if ($suspeita -or (-not $ehMicrosoft) -or $MostrarMicrosoft) {
            $exibidas.Add([PSCustomObject]@{
                Prioridade = if ($suspeita) { 0 } else { 1 }
                Tag        = if ($suspeita) { 'REVISAR' } else { 'INFO' }
                Caminho    = "$caminhoTarefa$($tarefa.TaskName)"
                Estado     = [string]$tarefa.State
                Comando    = if ([string]::IsNullOrWhiteSpace($comandoConcatenado)) { '<acao COM ou sem executavel>' } else { $comandoConcatenado }
            })
        }
    }

    if ($exibidas.Count -eq 0) {
        Write-Host "  Nenhuma tarefa ativa fora de \Microsoft\ ou com comando suspeito encontrada." -ForegroundColor Green
        $linhasRelatorio.Add('Nenhuma tarefa ativa fora de \Microsoft\ ou com comando suspeito encontrada.')
    }
    else {
        foreach ($item in ($exibidas | Sort-Object -Property Prioridade, Caminho)) {
            $corTag = if ($item.Tag -eq 'REVISAR') { 'Yellow' } else { 'Green' }
            $corTexto = if ($item.Tag -eq 'REVISAR') { 'Yellow' } else { 'White' }
            Show-LinhaComTag -Tag $item.Tag -CorTag $corTag -Texto "$($item.Caminho) [$($item.Estado)]" -CorTexto $corTexto
            Write-Host "             Acao: $($item.Comando)" -ForegroundColor DarkGray
            $linhasRelatorio.Add("[$($item.Tag)] $($item.Caminho) [$($item.Estado)] -> $($item.Comando)")
        }
    }

    return [PSCustomObject]@{
        TotalNaoMicrosoft = $totalNaoMicrosoft
        TotalAlertas      = $alertasConsolidados.Count
        Alertas           = $alertasConsolidados
        LinhasRelatorio   = $linhasRelatorio
    }
}

function Save-RelatorioAuditoria {
    <#
    .SYNOPSIS
        Grava o relatorio consolidado da auditoria em arquivo UTF-8 sem BOM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destino,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Linhas
    )

    $diretorioPai = Split-Path -Path $Destino -Parent
    if (-not [string]::IsNullOrWhiteSpace($diretorioPai) -and -not (Test-Path -LiteralPath $diretorioPai)) {
        New-Item -Path $diretorioPai -ItemType Directory -Force | Out-Null
    }

    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Destino, $Linhas, $utf8SemBom)
}

$ehAdmin = Test-PrivilegioAdministrador
$textoPrivilegio = if ($ehAdmin) { 'Administrador (visibilidade completa)' } else { 'Usuario padrao (visibilidade limitada)' }
$dataExecucao = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$usuarioAtual = [Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Auditoria Local de Seguranca Windows v1.1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Computador: $env:COMPUTERNAME | Usuario: $usuarioAtual" -ForegroundColor DarkGray
Write-Host "  Data/Hora:  $dataExecucao | Privilegio: $textoPrivilegio" -ForegroundColor DarkGray

$caminhoResolvido = $null
$relatorioSalvo = $false

$resumoRede = $null
$resumoUsuarios = $null
$resumoAdmins = $null
$resumoTarefas = $null
$alertasConsolidadosGerais = New-Object System.Collections.Generic.List[string]

try {
    if (-not $ehAdmin) {
        Write-Host "`n[AVISO] Sessao sem privilegios de Administrador. Alguns caminhos de processos e tarefas podem ficar ocultos." -ForegroundColor Yellow
    }

    if ($PSBoundParameters.ContainsKey('CaminhoRelatorio') -and [string]::IsNullOrWhiteSpace($CaminhoRelatorio)) {
        throw 'O parametro CaminhoRelatorio nao pode ser vazio.'
    }

    if (-not [string]::IsNullOrWhiteSpace($CaminhoRelatorio)) {
        $caminhoResolvido = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CaminhoRelatorio)
        if (Test-Path -LiteralPath $caminhoResolvido) {
            throw "O arquivo de relatorio informado ja existe: $caminhoResolvido"
        }
    }

    if (($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Executar auditoria de conexoes TCP, contas locais, administradores e tarefas agendadas')) {
        $etapa = 'Mapeamento de processos ativos'
        $mapaProcessos = Get-MapaProcessoAtivo

        $etapa = 'Auditoria de rede e processos'
        $resumoRede = Invoke-AuditoriaRede -MapaProcessos $mapaProcessos -MostrarLoopback:$IncluirLoopback
        foreach ($alertaItem in $resumoRede.Alertas) { $alertasConsolidadosGerais.Add($alertaItem) }

        $etapa = 'Auditoria de contas locais'
        $resumoUsuarios = Invoke-AuditoriaUsuarioLocal
        foreach ($alertaItem in $resumoUsuarios.Alertas) { $alertasConsolidadosGerais.Add($alertaItem) }

        $etapa = 'Auditoria de grupo administradores'
        $resumoAdmins = Invoke-AuditoriaGrupoAdmin

        $etapa = 'Auditoria de tarefas agendadas'
        $resumoTarefas = Invoke-AuditoriaTarefaAgendada -MostrarMicrosoft:$IncluirTarefasMicrosoft
        foreach ($alertaItem in $resumoTarefas.Alertas) { $alertasConsolidadosGerais.Add($alertaItem) }

        if ($alertasConsolidadosGerais.Count -gt 0) {
            Show-TituloSecao -Titulo 'ALERTAS CONSOLIDADOS PARA REVISAO'
            $indiceAlerta = 1
            foreach ($alertaDesc in $alertasConsolidadosGerais) {
                Write-Host "  [$indiceAlerta] $alertaDesc" -ForegroundColor Yellow
                $indiceAlerta++
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($caminhoResolvido)) {
            $etapa = 'Gravacao de relatorio'
            if (($null -eq $PSCmdlet) -or $PSCmdlet.ShouldProcess($caminhoResolvido, 'Salvar relatorio de auditoria em arquivo texto')) {
                $conteudoRelatorio = New-Object System.Collections.Generic.List[string]
                $conteudoRelatorio.Add("Auditoria Local de Seguranca Windows v1.1 - $dataExecucao")
                $conteudoRelatorio.Add("Computador: $env:COMPUTERNAME | Usuario: $usuarioAtual | Privilegio: $textoPrivilegio")
                $conteudoRelatorio.Add('')
                foreach ($l in $resumoRede.LinhasRelatorio) { $conteudoRelatorio.Add($l) }
                $conteudoRelatorio.Add('')
                foreach ($l in $resumoUsuarios.LinhasRelatorio) { $conteudoRelatorio.Add($l) }
                $conteudoRelatorio.Add('')
                foreach ($l in $resumoAdmins.LinhasRelatorio) { $conteudoRelatorio.Add($l) }
                $conteudoRelatorio.Add('')
                foreach ($l in $resumoTarefas.LinhasRelatorio) { $conteudoRelatorio.Add($l) }
                if ($alertasConsolidadosGerais.Count -gt 0) {
                    $conteudoRelatorio.Add('')
                    $conteudoRelatorio.Add('=== ALERTAS CONSOLIDADOS PARA REVISAO ===')
                    foreach ($alertaDesc in $alertasConsolidadosGerais) {
                        $conteudoRelatorio.Add($alertaDesc)
                    }
                }

                Save-RelatorioAuditoria -Destino $caminhoResolvido -Linhas $conteudoRelatorio.ToArray()
                $relatorioSalvo = $true
            }
        }

        if ($alertasConsolidadosGerais.Count -gt 0) {
            $status = "Concluido com $($alertasConsolidadosGerais.Count) alerta(s) unico(s) para revisao manual"
            $corStatus = 'Yellow'
        }
        else {
            $status = 'Concluido sem indicadores suspeitos nas regras locais'
            $corStatus = 'Green'
        }
        $codigoSaida = 0
    }
    elseif ($WhatIfPreference) {
        $status = 'Simulacao concluida; nenhuma varredura ou gravacao executada'
        $corStatus = 'Yellow'
        $codigoSaida = 0
    }
    else {
        $status = 'Cancelado pelo operador; nenhuma operacao executada'
        $corStatus = 'Yellow'
        $codigoSaida = 2
    }
}
catch {
    Write-Error -Message "Falha na etapa: $etapa. Nao foi possivel concluir a auditoria com seguranca." -ErrorAction Continue
    $status = 'Falha durante a execucao da auditoria'
    $corStatus = 'Red'
    $codigoSaida = 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  - Status:                     $status" -ForegroundColor $corStatus
Write-Host "  - Privilegio da sessao:       $textoPrivilegio" -ForegroundColor White
if ($null -ne $resumoRede) {
    Write-Host "  - Processos em rede ativa:    $($resumoRede.TotalProcessosRede) ($($resumoRede.TotalEstabelecidas) conexoes)" -ForegroundColor White
    Write-Host "  - Portas em escuta (unif.):   $($resumoRede.TotalEscuta)" -ForegroundColor White
}
if ($null -ne $resumoUsuarios) {
    Write-Host "  - Contas locais (ativas):     $($resumoUsuarios.TotalContas) ($($resumoUsuarios.ContasAtivas))" -ForegroundColor White
}
if ($null -ne $resumoAdmins) {
    Write-Host "  - Membros Administradores:    $($resumoAdmins.TotalMembros)" -ForegroundColor White
}
if ($null -ne $resumoTarefas) {
    Write-Host "  - Tarefas fora Microsoft:     $($resumoTarefas.TotalNaoMicrosoft)" -ForegroundColor White
}
Write-Host "  - Alertas unicos p/ revisao:  $($alertasConsolidadosGerais.Count)" -ForegroundColor $(if ($alertasConsolidadosGerais.Count -gt 0) { 'Yellow' } else { 'White' })
if ($relatorioSalvo) {
    Write-Host "  - Relatorio salvo em:         $caminhoResolvido" -ForegroundColor White
}
Write-Host "  - Codigo de saida:            $codigoSaida" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

# Quando executado via Invoke-Expression (iex), usa return para nao fechar a janela do PowerShell do operador
if ([string]::IsNullOrEmpty($PSCommandPath)) {
    return
}

exit $codigoSaida
