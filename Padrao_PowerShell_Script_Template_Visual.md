### 📝 Prompt de Padronização de Scripts PowerShell (Template Visual e Estrutural)

> "Por favor, reestruture o script PowerShell abaixo aplicando o seguinte padrao de design visual e logica de execucao estruturada. Mantenha toda a logica original do script e os comentarios importantes, mas siga estritamente estas 4 regras de formatacao:
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
>        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/seu-user/repo/main/script.ps1 | iex
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
>    * **Sucesso/Conclusao:** Cor `Green`. Ex: `Write-Host "\nOperacao concluida com exito!" -ForegroundColor Green`
>    * **Avisos ou Ignorados (Nao necessario):** Cor `Yellow`.
>    * **Erros:** Cor `Red`.
> 
> 4. **Tratamento de Erros e Saidas Limpas**:
>    Evite que comandos nativos inundem a tela com mensagens inuteis. Jogue o output desnecessario para fora usando `| Out-Null` ou usando `-ErrorAction SilentlyContinue`. Se a operacao for critica, agrupe-a em um bloco `try { ... } catch { ... }` onde o catch utilize o `Write-Host` na cor vermelha para detalhar `$_.Exception.Message`.
> "
