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
>        echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
>        draw_separator
>    }
>    get_service_status() {
>        local service="$1"
>        if systemctl is-active --quiet "$service" 2>/dev/null; then
>            echo -e "${FG_GREEN}Ativo${NC}"
>        else
>            echo -e "${FG_YELLOW}Inativo${NC}"
>        fi
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
> 5. **Configuração de Teclado e Locales (UTF-8 + US-Intl + ABNT2 com Alt+Space)**:
>    Quando houver configuração de locales e teclado, utilize o bloco padrão com `XKBOPTIONS="grp:alt_space_toggle"` para alternância de layout com **Alt+Space**:
>    ```bash
>    log_info "Configurando suporte completo a UTF-8 (en_US.UTF-8 e pt_BR.UTF-8)..."
>    sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
>    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
>    locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
>    update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8 > /dev/null 2>&1
>
>    log_info "Configurando layouts de teclado (US-International com Acentos + ABNT2)..."
>    cat <<EOF > /etc/default/keyboard
>    XKBMODEL="pc105"
>    XKBLAYOUT="us,br"
>    XKBVARIANT="intl,"
>    XKBOPTIONS="grp:alt_space_toggle"
>    BACKSPACE="guess"
>    EOF
>
>    udevadm trigger --subsystem-match=input --action=change > /dev/null 2>&1 || true
>    setupcon --force > /dev/null 2>&1 || true
>    log_success "Teclado configurado: US-International (para acentos em teclado americano) + ABNT2 (Alterna com Alt+Space)."
>    ```
> 
> 6. **Resultado Final Estruturado (Resumo da Instalação)**:
>    No final de todo script, exiba obrigatoriamente um painel de encerramento utilizando a função `print_header "RESUMO DA INSTALAÇÃO"`.
>    Para detecção dinâmica do status do teclado no resumo, utilize:
>    ```bash
>    KEYBOARD_STATUS="Não configurado"
>    if [ -f /etc/default/keyboard ]; then
>      if grep -q 'XKBLAYOUT="us,br"' /etc/default/keyboard 2>/dev/null; then
>        KEYBOARD_STATUS="US-International (Acentos) + ABNT2 (Alt+Space)"
>      else
>        LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d'=' -f2 | tr -d '"')
>        KEYBOARD_STATUS="${LAYOUT:-Padrao}"
>      fi
>    fi
>    ```
>    Utilize a função `get_service_status` para listar o status limpo de serviços (`Ativo`/`Inativo`, evitando saídas duplicadas do `systemctl`). O painel deve listar de forma organizada, alinhada e tabulada todo o status final das ações realizadas com sucesso, separando os blocos com linhas discretas `${DIM}────────────────────────────────────────────────────────────────${NC}`.
> 
> 7. **Cabeçalho de Metadados e Comentários**:
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
