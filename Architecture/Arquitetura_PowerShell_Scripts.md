### 📝 Prompt de Padronização de Scripts PowerShell (Template Visual e Estrutural)

> "Por favor, reestruture o script PowerShell abaixo aplicando o seguinte padrao de design visual e logica de execucao estruturada. Mantenha toda a logica original do script e os comentarios importantes, mas siga estritamente as regras abaixo:
> 
> 1. **Ausencia Absoluta de Acentuacao**:
>    Por convencao visual do projeto, use texto ASCII, sem acentos, nas mensagens fixas de console e nos comentarios dos scripts. Nao altere dados, caminhos ou entradas do usuario para remover acentos. Essa convencao nao substitui a escolha correta de codificacao do arquivo e do terminal, descrita na secao 10.
>
> 2. **Cabecalho de Metadados (Documentation Block), Requisitos e Versionamento**:
>    O script deve obrigatoriamente iniciar com o bloco padrao de metadados do PowerShell, seguido das diretivas `#Requires` de ambiente.
>    **Regra de Versionamento:** Utilize sempre dois componentes (`MAJOR.MINOR`), por convencao do projeto, sem `PATCH` (ex: incorreto `1.1.0` | correto `1.1`, `1.2`). Registre a versao dentro de `.NOTES`; `.VERSION` nao e uma palavra-chave oficial da ajuda baseada em comentarios. Documente parametros publicos com `.PARAMETER` e exemplos reais com `.EXAMPLE`.
>    **Menor Privilegio:** Inclua `#Requires -RunAsAdministrator` somente quando as operacoes exigirem elevacao, explicando o motivo em `.NOTES`. `#Requires -Version 5.1` define a versao minima, mas nao comprova compatibilidade com todos os comandos e sistemas posteriores.
>    ```powershell
>    <#
>    .SYNOPSIS
>        Breve descricao de uma linha do que o script faz.
>    .DESCRIPTION
>        Script PowerShell compativel com versoes antigas e recentes.
>        Detalhes extras.
>    .EXAMPLE
>        .\NomeDoScript.ps1
>    .NOTES
>        Versao: 1.0
>        Documentar requisitos de sistema, modulos e privilegios aplicaveis.
>    #>
>
>    #Requires -Version 5.1
>    ```
> 
> 3. **Padrao Visual de Cores (Write-Host) vs Streams e PSScriptAnalyzer**:
>    - **Distincao entre Interface de Console (UI) e Pipeline (Dados):**
>      * `Write-Host` destina-se exclusivamente a interfaces de console e scripts interativos voltados a operadores humanos (titulos, menus, banners e status coloridos). Ele renderiza informacoes na tela sem poluir o pipeline de saida de dados (Stream 1).
>      * Em modulos reutilizaveis, cmdlets ou funcoes que produzem dados para pipeline, **NUNCA** utilize `Write-Host`. Utilize `Write-Output` (para trafegar dados/objetos), `Write-Verbose` (mensagens de diagnostico com `-Verbose`), `Write-Warning` ou `Write-Error`.
>    - **Supressao Oficial da Regra `PSAvoidUsingWriteHost`:**
>      * Para scripts de console onde o uso de cores via `Write-Host` e intencional e essencial a experiencia visual do operador, declare o atributo oficial de supressao do `PSScriptAnalyzer` imediatamente antes do bloco `param()`:
>        ```powershell
>        [CmdletBinding()]
>        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
>        param(
>            # Parametros tipados
>        )
>        ```
>        Isso suprime somente a regra indicada no escopo decorado. Outras regras continuam ativas; mantenha a justificativa e o menor escopo adequado, sem ocultar problemas para obter uma analise limpa.
>    - **Paleta de Cores Padrao:**
>      * **Titulos/Cabecalhos de Secao:** Cor `Cyan`. O titulo deve estar imprensado entre dois separadores de "=" com mesmo tamanho. Ex:
>        ```powershell
>        Write-Host "==========================================================" -ForegroundColor Cyan
>        Write-Host " Iniciando instalacao / processo xyz..." -ForegroundColor Cyan
>        Write-Host "==========================================================" -ForegroundColor Cyan
>        ```
>      * **Sucesso/Conclusao:** Cor `Green`. Ex: ``Write-Host "`nOperacao concluida com exito!" -ForegroundColor Green``
>      * **Avisos ou Ignorados (Nao necessario):** Cor `Yellow`.
>      * **Erros:** Cor `Red`.
>      * **Valores e Detalhes de Resumo:** Cor `White` para texto de chave/valor e `DarkGray` para linhas tracejadas.
>
> 4. **Conformidade Estatica com PSScriptAnalyzer e Boas Praticas de Codificacao**:
>    - **Proibicao de Aliases (`PSAvoidUsingCmdletAliases`):** Nunca utilize apelidos em scripts (ex: use `Get-ChildItem` em vez de `dir`/`ls`, `Where-Object` em vez de `?`, `ForEach-Object` em vez de `%`, `Select-Object` em vez de `select`, `Remove-Item` em vez de `rm`/`del`).
>    - **Nomenclatura de Funcoes (`PSUseApprovedVerbs`):** Funcoes internas auxiliares devem obrigatoriamente seguir a convencao `Verbo-Substantivo` com verbos oficiais da Microsoft (`Get-Verb`, ex: `Invoke-`, `Start-`, `Test-`, `Show-`).
>    - **Tipagem Forte e Validacao de Parametros:** Declare tipos explicitos para todos os parametros (`[string]`, `[int]`, `[switch]`, `[DateTime]`) e utilize validadores nativos quando aplicavel (`[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, `[ValidatePattern()]`).
>    - **Variaveis Declaradas e Utilizadas (`PSUseDeclaredVarsMoreThanAssignments`):** Nao deixe variaveis declaradas que nunca sejam consumidas.
>    - **Validacao Continua:** Antes de finalizar qualquer script, execute `Invoke-ScriptAnalyzer -Path .\NomeDoScript.ps1` garantindo zero erros e avisos.
>    - **Compatibilidade e Execucao:** Valide a sintaxe nos runtimes declarados (Windows PowerShell 5.1 e PowerShell 7, quando ambos forem suportados). A analise estatica nao comprova seguranca nem comportamento em execucao. Testes que alterem registro, servicos, tarefas agendadas, instalacoes ou dados devem ocorrer exclusivamente no Windows Sandbox. Verifique sucesso, falha, repeticao, cancelamento e `-WhatIf`, conforme aplicavel; registre os limites do que foi testado.
> 
> 5. **Tratamento de Erros e Saidas Limpas**:
>    - `Out-Null` descarta a saida de sucesso; `-ErrorAction SilentlyContinue` oculta erros e nao deve ser usado para limpar a tela em operacoes criticas. Uma falha esperada so pode ser silenciada com tratamento explicito do resultado.
>    - Use `try/catch` com `-ErrorAction Stop` nos cmdlets criticos ou `$ErrorActionPreference = 'Stop'` no escopo do script. `catch` trata erros terminantes; comandos nativos exigem a verificacao separada descrita na secao 9. `-ErrorAction` nao e um parametro comum de executaveis nativos.
>    - Funcoes reutilizaveis devem propagar falhas com `throw`, preservando o erro original quando seguro. No ponto de entrada de um script executavel, documente e devolva codigos de saida: `0` para sucesso ou simulacao concluida, `1` para falha e `2` para cancelamento pelo operador. Nao use `exit` dentro de funcoes reutilizaveis.
>    - No `catch`, apresente uma mensagem segura sobre a etapa que falhou. Nao imprima automaticamente `$_.Exception.Message`, o objeto de erro inteiro, argumentos ou saidas nativas: podem conter segredos. Detalhes adicionais devem ser revisados e sanitizados antes de qualquer stream ou log, inclusive com `-Verbose`.
>    - Use `finally` para liberar recursos e restaurar estados temporarios quando necessario; nao anuncie sucesso dentro dele, pois tambem executa em caso de falha.
> 
> 6. **Painel de Resumo Final (Resultado Estruturado)**:
>    Em scripts interativos de console, apresente um painel final com `Write-Host`, baseado nos resultados verificados de cada etapa. Diferencie sucesso (Green), falha ou falha parcial (Red), cancelamento e simulacao (Yellow). Sob `-WhatIf`, descreva apenas o planejado, sem afirmar que foi aplicado. Funcoes e scripts para pipeline devem retornar objetos estruturados, sem painel visual. Exemplo de painel apenas apos confirmar o sucesso das etapas:
>    ```powershell
>    Write-Host "==========================================================" -ForegroundColor Cyan
>    Write-Host "  [OK] RESUMO DA EXECUCAO - PROCESSO CONCLUIDO COM EXITO" -ForegroundColor Green
>    Write-Host "==========================================================" -ForegroundColor Cyan
>    Write-Host "  - Servico XYZ:           Ativo e Executando" -ForegroundColor White
>    Write-Host "  - Configuracao ABC:      Aplicada" -ForegroundColor White
>    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
>    ```
> 
> 7. **Gestao Segura de Credenciais e Placeholders**:
>    - Nunca utilize credenciais fixas (hardcoded) no script. Solicite senhas interativamente via `Read-Host -AsSecureString` ou gere dinamicamente via gerador criptografico.
>    - Em comentarios, metadados e documentacoes de ajuda, use placeholders entre colchetes angulares (ex: `<senha_do_usuario>`, `<usuario_smtp>`, `<chave_secreta_unica>`, `<host_servidor_smtp>`). A finalidade e impedir a exposicao de segredos; ausencia de alertas de um detector nao comprova seguranca.
>    - Se um comando nativo exigir texto puro, converta o `SecureString` apenas imediatamente antes do uso, nunca passe a senha como argumento de linha de comando e libere o BSTR com `ZeroFreeBSTR` em um bloco `finally`.
>    - `ZeroFreeBSTR` limpa somente o buffer BSTR; nao apaga copias convertidas para `System.String`, que sao imutaveis. Evite essas copias e prefira APIs que aceitem `PSCredential` ou `SecureString`. Quando indispensavel, utilize um canal de entrada documentado pela ferramenta, sem eco ou registro do segredo.
>    - Nunca imprima, registre em log ou inclua a credencial no painel de resumo. Se o requisito exigir um arquivo de credenciais, prepare a ACL restrita antes de gravar o segredo, limite sua permanencia e exiba um aviso explicito sobre texto puro. Nao versione esse arquivo.
>
> 8. **Operacoes Destrutivas e Idempotencia**:
>    - Antes de excluir, sobrescrever, desregistrar ou mover dados, valide os alvos exatos e confirme que backups ou exportacoes foram criados com sucesso e possuem conteudo.
>    - Em scripts e funcoes que alterem estado, declare `[CmdletBinding(SupportsShouldProcess = $true)]` e envolva cada alteracao em `$PSCmdlet.ShouldProcess($alvo, $operacao)`. Ajuste `ConfirmImpact` ao risco. O atributo disponibiliza `-WhatIf` e `-Confirm`, mas nao bloqueia sozinho comandos nativos, APIs .NET ou etapas auxiliares.
>    - Em `-WhatIf`, permita apenas leitura e planejamento: inclusive criacao de backups e arquivos deve respeitar a simulacao. Execute a confirmacao textual adicional somente depois de `ShouldProcess` autorizar a etapa, sem prompts extras durante a simulacao.
>    - Solicite uma confirmacao textual explicita antes da etapa irreversivel. Uma opcao para ignorar a confirmacao so pode existir quando seu nome deixa o risco evidente.
>    - Se um arquivo de destino ja existir, preserve-o e interrompa a execucao por padrao. Nunca sobrescreva silenciosamente backups ou imagens-base.
>    - Estruture o script para poder ser executado novamente com seguranca ou para interromper com uma mensagem clara sobre o estado encontrado.
>
> 9. **Comandos Nativos e Codigos de Saida**:
>    - Apos uma chamada direta com `&` a programas como `wsl.exe`, `robocopy.exe`, `icacls.exe` ou instaladores, capture imediatamente `$LASTEXITCODE` em uma variavel local. Verifique tambem falhas ao iniciar o processo. Com `Start-Process`, use `-Wait -PassThru` e examine `ExitCode` do processo retornado, em vez de `$LASTEXITCODE`.
>    - Defina os codigos aceitos por ferramenta: no `robocopy`, `0` a `7` nao indicam falha de copia, mas podem sinalizar diferencas que exigem avaliacao; `8` ou mais indicam falha. Instaladores podem ter codigos especificos de reinicializacao necessaria, que devem aparecer no resumo.
>    - Centralize chamadas repetidas em uma funcao auxiliar que receba o executavel, os argumentos, os codigos aceitos e uma mensagem de falha segura. Preserve a classificacao do resultado; nao trate todo codigo diferente de zero como falha, nem descarte avisos relevantes.
>    - Passe argumentos como array na chamada direta com `&` e nunca use `Invoke-Expression` para montar comandos dinamicos. Teste argumentos com espacos e aspas nas versoes suportadas: o repasse para executaveis varia entre Windows PowerShell 5.1 e PowerShell 7; `Start-Process -ArgumentList` nao preserva automaticamente os limites de um array.
>
> 10. **Compatibilidade de Caminhos, Perfil e Codificacao**:
>    - Use `Join-Path`, `-LiteralPath` e caminhos absolutos para operacoes sensiveis.
>    - Para arquivos relativos ao script, use `$PSScriptRoot` com `Join-Path`. Para o perfil do usuario que executa o processo no Windows, use `$env:USERPROFILE`; `$HOME` tambem existe no Windows PowerShell 5.1. Nao presuma que o usuario do processo elevado ou agendado seja o operador interativo.
>    - Para scripts `.ps1` que contenham caracteres nao ASCII e devam funcionar no Windows PowerShell 5.1, use UTF-8 com BOM. Texto ASCII e um subconjunto de UTF-8, mas mensagens de ferramentas externas ainda dependem da codificacao do terminal.
>    - Para arquivos consumidos por ferramentas externas, siga a codificacao exigida pelo consumidor e declare-a no codigo. No Windows PowerShell 5.1, `-Encoding UTF8` grava BOM; no PowerShell 7, o padrao de saida textual e UTF-8 sem BOM. Quando necessario em ambos, use `System.Text.UTF8Encoding` com BOM desabilitado e uma API de escrita apropriada, respeitando as protecoes contra sobrescrita.
>
> 11. **Execucao Remota Segura**:
>    - Nao recomende `irm <URL> | iex` nos metadados ou exemplos. Oriente o operador a baixar o arquivo, revisar seu conteudo e executar a copia local validada.
> "
>
> ---
>
> ### 🏛️ Template Estrutural de Referencia (Esqueleto Limpo)
>
> Este esqueleto destina-se a um script executavel de console, chamado com `-File` ou `&`, e nao a dot-sourcing ou importacao como modulo, pois utiliza `exit`. Substitua o `throw` de operacao pendente pela implementacao e pela verificacao de sua pos-condicao antes de usar em producao. Enquanto nao adaptado, o caminho normal falha explicitamente; `-WhatIf` apenas mostra o planejamento. Para etapas irreversiveis, acrescente a confirmacao textual e as validacoes de backup da secao 8 dentro do bloco autorizado.
>
> ```powershell
> <#
> .SYNOPSIS
>     Template estrutural de referencia para scripts PowerShell.
> .DESCRIPTION
>     Esqueleto de console com simulacao e propagacao de falhas ao chamador.
>     A operacao principal precisa ser implementada antes do uso real.
> .PARAMETER ParametroExemplo
>     Identificador publico e nao sensivel do alvo da operacao.
> .EXAMPLE
>     .\TemplateScript.ps1 -ParametroExemplo "AlvoDeExemplo" -WhatIf
> .NOTES
>     Versao: 1.0
>     Alvos de compatibilidade: Windows PowerShell 5.1 e PowerShell 7 no Windows.
>     Saida: 0 = sucesso ou simulacao; 1 = falha; 2 = cancelamento.
> #>
>
> #Requires -Version 5.1
>
> [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
> [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Script interativo de console com interface visual para o operador')]
> param(
>     [Parameter(Mandatory = $true)]
>     [ValidateNotNullOrEmpty()]
>     [string]$ParametroExemplo
> )
>
> $ErrorActionPreference = 'Stop'
> $codigoSaida = 1
> $status = 'Falha'
> $corStatus = 'Red'
> $etapa = 'Validacao inicial'
>
> Write-Host "==========================================================" -ForegroundColor Cyan
> Write-Host " Script de Exemplo v1.0" -ForegroundColor Cyan
> Write-Host "==========================================================" -ForegroundColor Cyan
>
> try {
>     # Validar aqui o alvo exato e as pre-condicoes, usando apenas leitura.
>     if ($PSCmdlet.ShouldProcess($ParametroExemplo, 'Executar operacao principal')) {
>         $etapa = 'Operacao principal'
>         # Substituir o throw pela operacao e verificar o resultado antes do sucesso.
>         throw 'Operacao principal ainda nao implementada.'
>         $status = 'Concluido e verificado'
>         $corStatus = 'Green'
>         $codigoSaida = 0
>     }
>     elseif ($WhatIfPreference) {
>         $status = 'Simulacao concluida; nenhuma alteracao aplicada'
>         $corStatus = 'Yellow'
>         $codigoSaida = 0
>     }
>     else {
>         $status = 'Cancelado pelo operador; nenhuma alteracao aplicada'
>         $corStatus = 'Yellow'
>         $codigoSaida = 2
>     }
> }
> catch {
>     # A mensagem original pode conter segredos. Exibir somente contexto seguro.
>     Write-Error -Message "Falha na etapa: $etapa. Operacao interrompida; verifique o estado do alvo antes de repetir." -ErrorAction Continue
>     $status = 'Falha; podem existir etapas parcialmente aplicadas'
>     $corStatus = 'Red'
>     $codigoSaida = 1
> }
>
> Write-Host "`n==========================================================" -ForegroundColor Cyan
> Write-Host "  RESUMO DA EXECUCAO" -ForegroundColor Cyan
> Write-Host "==========================================================" -ForegroundColor Cyan
> Write-Host "  - Status: $status" -ForegroundColor $corStatus
> Write-Host "  - Codigo de saida: $codigoSaida" -ForegroundColor White
> Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
> exit $codigoSaida
> ```

### Referencias oficiais

- [Tratamento de erros com try/catch/finally](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally)
- [ShouldProcess, WhatIf e Confirm](https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess)
- [Codigos de saida do Robocopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy)
- [Ajuda baseada em comentarios](https://learn.microsoft.com/en-us/powershell/scripting/developer/help/comment-based-help-keywords)
- [Codificacao de caracteres](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding)
- [Supressoes no PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer)
- [Limites de SecureString](https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring)
