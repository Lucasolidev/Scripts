### 📝 Prompt de Padronização de Scripts Shell (Template Visual)

> "Por favor, reestruture o script shell abaixo aplicando o seguinte padrão de design visual e lógica de execução estruturada. Mantenha toda a lógica original do script e os comentários importantes:
> 
> 1. **Paleta de Cores e Estilos (ANSI)**:
>    Defina no topo do arquivo a paleta de cores padrão utilizando as variáveis:
>    * `NC` (reset/sem cor), `BOLD` (negrito), `DIM` (estilo suave)
>    * Cores de Fonte (`FG_CYAN`, `FG_YELLOW`, `FG_GREEN`, `FG_RED`, `FG_WHITE`)
>    * Símbolo indicador `ARROW="❯"`
> 
> 2. **Funções Auxiliares de Visual**:
>    Implemente no topo do script as seguintes funções:
>    ```bash
>    draw_separator() {
>        echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
>    }
>    print_header() {
>        local title="$1"
>        echo -e ""
>        echo -e "${FG_CYAN}${BOLD}=== SYSTEM MANAGER ===${NC}"
>        echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
>        draw_separator
>    }
>    log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
>    log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
>    log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
>    log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
>    print_alert_box() {
>        local msg="$1"
>        echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
>    }
>    ```
> 
> 3. **Interatividade e Coleta de Parâmetros**:
>    Todas as perguntas (`read -p`) devem ser agrupadas no início em um bloco chamado `"COLETA DE PARÂMETROS"`. Utilize o padrão `  ${FG_YELLOW}${ARROW} Pergunta? (s/n): ${NC}` nas perguntas do `read`.
> 
> 4. **Instalação Silenciosa e Limpa**:
>    Quando houver instalação de pacotes via `apt` ou outro gerenciador, execute de forma loopada e individual para cada pacote de forma silenciosa (`> /dev/null 2>&1`), exibindo um log claro de `log_success` se instalado, ou `log_warning` / `log_error` caso falhe.
> 
> 5. **Resultado Final Estruturado (Resumo do Sistema)**:
>    No final de todo script, exiba obrigatoriamente um painel de encerramento utilizando a função `print_header "RESUMO DO SISTEMA - [PROCESSO] CONCLUÍDO"`. O painel deve listar de forma organizada, alinhada e tabulada todo o status final das ações realizadas com sucesso (ex: serviços iniciados, pacotes instalados, configurações de segurança aplicadas, usuários ou permissões), separando os blocos com linhas discretas `${DIM}────────────────────────────────────────────────────────────────${NC}`.
> 
> 6. **Cabeçalho de Metadados e Comentários**:
>    Todo script deve começar com o seguinte bloco de metadados padrão, certificando-se de alterar a string `NOME_DO_SCRIPT_AQUI.sh` e a descrição para refletir os dados reais do script atual que está sendo criado nas URLs de exemplo:
>    ```bash
>    #!/bin/bash
>    # ------------------------------------------------
>    # Version: 1.0
>    # ------------------------------------------------
>    VERSION="1.0"
>    # ==============================================================================
>    # [TITULO DO SCRIPT AQUI]
>    # ==============================================================================
>    # Execução recomendada via repositório: lucasolidev NOME_DO_SCRIPT_AQUI.sh
>    # ==============================================================================
>    # visualizar o script antes de executar:
>    #
>    # curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh
>    # wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh
>    #
>    # Executar via URL
>    # wget https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh
>    # bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh)
>    # curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh | bash
>    #
>    # ==============================================================================
>    ```
> 
> Aqui está o script original que deve ser adaptado:
> `[INSIRA O SCRIPT AQUI]`"
