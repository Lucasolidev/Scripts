### 📝 Prompt de Padronização de Scripts PowerShell (Template Visual e Estrutural)

> "Por favor, reestruture o script PowerShell abaixo aplicando o seguinte padrao de design visual e logica de execucao estruturada. Mantenha toda a logica original do script e os comentarios importantes, mas siga estritamente as regras abaixo:
> 
> 1. **Ausencia Absoluta de Acentuacao**:
>    Para garantir compatibilidade com versoes antigas do Windows Server e do PowerShell (que utilizam codificacoes legadas como CP850/OEM), **remova todos os acentos** de strings impressas (Write-Host) e de comentarios ao longo do script. Nao use 'ç', 'á', 'é', 'ã', etc.
>
> 2. **Cabecalho de Metadados (Documentation Block)**:
>    O script deve obrigatoriamente iniciar com o bloco padrao de metadados do PowerShell:
>    ```powershell
>    <#
>    .SYNOPSIS
>        Breve descricao de uma linha do que o script faz.
>    .DESCRIPTION
>        Script PowerShell compativel com versoes antigas e recentes.
>        Detalhes extras.
>    .EXAMPLE
>        .\NomeDoScript.ps1
>    .VERSION
>        1.0
>    .NOTES
>        Requer privilegios de Administrador.
>    #>
>    ```
> 
> 3. **Padrao Visual de Cores (Write-Host)**:
>    Sempre utilize o cmdlet `Write-Host` acompanhado do parametro `-ForegroundColor`. Siga a seguinte paleta:
>    * **Titulos/Cabecalhos de Secao:** Cor `Cyan`. O titulo deve estar imprensado entre dois separadores de "=" com mesmo tamanho. Ex:
>      ```powershell
>      Write-Host "==========================================================" -ForegroundColor Cyan
>      Write-Host " Iniciando instalacao / processo xyz..." -ForegroundColor Cyan
>      Write-Host "==========================================================" -ForegroundColor Cyan
>      ```
>    * **Sucesso/Conclusao:** Cor `Green`. Ex: ``Write-Host "`nOperacao concluida com exito!" -ForegroundColor Green``
>    * **Avisos ou Ignorados (Nao necessario):** Cor `Yellow`.
>    * **Erros:** Cor `Red`.
> 
> 4. **Tratamento de Erros e Saidas Limpas**:
>    Evite que comandos nativos inundem a tela com mensagens inuteis. Jogue o output desnecessario para fora usando `| Out-Null` ou usando `-ErrorAction SilentlyContinue`. Se a operacao for critica, agrupe-a em um bloco `try { ... } catch { ... }` onde o catch utilize o `Write-Host` na cor vermelha para detalhar `$_.Exception.Message`.
> 
> 5. **Painel de Resumo Final (Resultado Estruturado)**:
>    No final de todo script PowerShell, apresente obrigatoriamente um painel de encerramento detalhado em cor `Cyan` e `Green` utilizando `Write-Host`. O resumo deve listar de forma organizada tudo o que foi executado com sucesso (ex: servicos iniciados, pacotes/recursos configurados, permissoes ou regras aplicadas), dando visibilidade imediata ao operador. Ex:
>    ```powershell
>    Write-Host "==========================================================" -ForegroundColor Cyan
>    Write-Host "  [OK] RESUMO DA EXECUCAO - PROCESSO CONCLUIDO COM EXITO" -ForegroundColor Green
>    Write-Host "==========================================================" -ForegroundColor Cyan
>    Write-Host "  - Servico XYZ:           Ativo e Executando" -ForegroundColor White
>    Write-Host "  - Configuracao ABC:      Aplicada" -ForegroundColor White
>    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
>    ```
> 
> 6. **Gestao Segura de Credenciais e Placeholders (Prevencao GitGuardian)**:
>    - Nunca utilize credenciais fixas (hardcoded) no script. Solicite senhas interativamente via `Read-Host -AsSecureString` ou gere dinamicamente via gerador criptografico.
>    - Em comentarios, metadados e documentacoes de ajuda, use sempre tags genericas entre colchetes angulares (ex: `<SuaSenha>`, `<UsuarioAdmin>`, `<ChaveAPI>`, `<ServidorSMTP>`) para nao ativar detectores de segredos do GitHub/GitGuardian.
>    - Se um comando nativo exigir texto puro, converta o `SecureString` apenas imediatamente antes do uso, nunca passe a senha como argumento de linha de comando e libere o BSTR com `ZeroFreeBSTR` em um bloco `finally`.
>    - Nunca imprima, registre em log ou inclua a credencial no painel de resumo. Se o requisito exigir um arquivo de credenciais, restrinja sua ACL e exiba um aviso explicito sobre texto puro.
>
> 7. **Operacoes Destrutivas e Idempotencia**:
>    - Antes de excluir, sobrescrever, desregistrar ou mover dados, valide os alvos exatos e confirme que backups ou exportacoes foram criados com sucesso e possuem conteudo.
>    - Solicite uma confirmacao textual explicita antes da etapa irreversivel. Uma opcao para ignorar a confirmacao so pode existir quando seu nome deixa o risco evidente.
>    - Se um arquivo de destino ja existir, preserve-o e interrompa a execucao por padrao. Nunca sobrescreva silenciosamente backups ou imagens-base.
>    - Estruture o script para poder ser executado novamente com seguranca ou para interromper com uma mensagem clara sobre o estado encontrado.
>
> 8. **Comandos Nativos e Codigos de Saida**:
>    - Depois de executar programas como `wsl.exe`, `robocopy.exe`, `icacls.exe` ou instaladores, valide `$LASTEXITCODE`. O fato de o PowerShell nao gerar uma excecao nao significa que o comando nativo funcionou.
>    - Centralize chamadas repetidas em uma funcao auxiliar que receba o executavel, os argumentos e a mensagem de falha.
>    - Passe argumentos como array e nunca use `Invoke-Expression` para montar comandos dinamicos.
>
> 9. **Compatibilidade de Caminhos, Perfil e Codificacao**:
>    - Use `Join-Path`, `-LiteralPath` e caminhos absolutos para operacoes sensiveis.
>    - Para o perfil atual, prefira `$env:USERPROFILE` em vez de `$HOME` quando o alvo for Windows PowerShell 5.1.
>    - Para arquivos de configuracao consumidos por ferramentas externas, grave UTF-8 sem BOM quando necessario e declare essa escolha no codigo.
>
> 10. **Execucao Remota Segura**:
>    - Nao recomende `irm <URL> | iex`. Oriente o operador a baixar o arquivo, revisar seu conteudo e executar a copia local validada.
>    - Inclua `#Requires -Version` e, quando aplicavel, `#Requires -RunAsAdministrator`.
> "
