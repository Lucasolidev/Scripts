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
>    Todas as perguntas (`read -p`) devem ser agrupadas no início em um bloco chamado `"COLETA DE PARÂMETROS"`. Utilize o padrão `  ${FG_YELLOW}${ARROW} Pergunta? (s/N): ${NC}` nas perguntas do `read` (onde `(s/N)` indica que o padrão ao apertar ENTER é Não).
> 
> 4. **Instalação Silenciosa e Limpa**:
>    Quando houver instalação de pacotes via `apt` ou outro gerenciador, execute de forma loopada e individual para cada pacote de forma silenciosa (`> /dev/null 2>&1`), exibindo um log claro de `log_success` se instalado, ou `log_warning` / `log_error` caso falhe.
> 
> 5. **Configuração de Teclado, Locales e Fuso Horário (America/Sao_Paulo)**:
>    Quando houver configuração de locales, teclado e fuso horário, utilize o bloco padrão:
>    ```bash
>    log_info "Configurando suporte completo a UTF-8 (en_US.UTF-8 e pt_BR.UTF-8)..."
>    sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
>    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
>    locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
>    update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8 > /dev/null 2>&1
>
>    log_info "Ajustando fuso horário (America/Sao_Paulo)..."
>    timedatectl set-timezone America/Sao_Paulo > /dev/null 2>&1 || true
>
>    log_info "Configurando layouts de teclado (US-International com Acentos + ABNT2)..."
>    cat <<EOF > /etc/default/keyboard
>    XKBMODEL="pc105"
>    XKBLAYOUT="us,br"
>    XKBVARIANT="intl,"
>    XKBOPTIONS="grp:alt_shift_toggle"
>    BACKSPACE="guess"
>    EOF
>
>    udevadm trigger --subsystem-match=input --action=change > /dev/null 2>&1 || true
>    setupcon --force > /dev/null 2>&1 || true
>    log_success "Teclado e fuso horário ajustados com sucesso."
>
>    log_info "Ajustando alias 'll' para 'ls -alFh' (tamanhos em KB/MB/GB)..."
>    for bashrc in /root/.bashrc /etc/skel/.bashrc /home/*/.bashrc; do
>      if [ -f "$bashrc" ]; then
>        if grep -q "alias ll=" "$bashrc"; then
>          sed -i "s/alias ll=.*/alias ll='ls -alFh'/" "$bashrc"
>        elif grep -q "#alias ll=" "$bashrc"; then
>          sed -i "s/#alias ll=.*/alias ll='ls -alFh'/" "$bashrc"
>        else
>          echo "alias ll='ls -alFh'" >> "$bashrc"
>        fi
>      fi
>    done
>    log_success "Alias 'll' ('ls -alFh') configurado nos perfis .bashrc do sistema."
>    ```
> 
> 6. **Hardening de Segurança e Manutenção**:
>    - **SSH Hardening**: Ajustar `PermitEmptyPasswords no`, `ClientAliveInterval 300` e `ClientAliveCountMax 2`.
>    - **Fail2Ban**: Instalar e ativar proteção contra força bruta no SSH quando for ambiente Server.
>    - **Firewall UFW**: Ativar regras de proteção de borda.
>    - **Limpeza do Sistema**: Executar `apt autoremove -y` e `apt autoclean -y` ao final das instalações.
> 
> 7. **Registro de Logs e Compatibilidade com Leitura Interativa (`read`)**:
>    No início da execução, inicialize a captura do console usando `exec > >(tee -a "$LOG_TMP") 2>&1`.
>    Para garantir que comandos `read` funcionem interativamente mesmo via pipe (`wget ... | sudo bash`), adicione `</dev/tty` ao final das chamadas `read -p "..." VAR </dev/tty` (jamais use `exec 0</dev/tty` globalmente, pois ele encerra a leitura do script vindo do pipe).
>    No final do script, salve automaticamente cópias timestamped e um atalho `latest.log` no diretório `/root` e na Home do usuário real que executou o comando via Sudo.
> 
> 8. **Resultado Final Estruturado (Resumo da Instalação)**:
>    No final de todo script, exiba obrigatoriamente um painel de encerramento utilizando a função `print_header "RESUMO DA INSTALAÇÃO"`.
>    **Obrigatório**: É fundamental incluir a linha de **Pacotes/Programas Instalados** detalhando os softwares adicionados ao sistema durante a execução (armazenando na array `PACOTES_INSTALADOS` e formatando com `LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")`).
>    
>    Exemplo de bloco de resumo:
>    ```bash
>    KEYBOARD_STATUS="Não configurado"
>    if [ -f /etc/default/keyboard ]; then
>      if grep -q 'XKBLAYOUT="us,br"' /etc/default/keyboard 2>/dev/null; then
>        KEYBOARD_STATUS="US-International (Acentos) + ABNT2 (Alterna com Alt+Shift)"
>      else
>        LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d'=' -f2 | tr -d '"')
>        KEYBOARD_STATUS="${LAYOUT:-Padrao}"
>      fi
>    fi
>    LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")
>
>    echo -e "  ${FG_GREEN}${BOLD}✔ PROCESSO FINALIZADO COM SUCESSO!${NC}\n"
>    echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
>    echo -e "  ${BOLD}Status do Sistema:${NC}     ${FG_GREEN}Operacional${NC}"
>    echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
>    echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}pt_BR.UTF-8 / en_US.UTF-8 (Gerados)${NC}"
>    echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
>    echo -e "  ${BOLD}Layout Ativo:${NC}          ${FG_GREEN}US-International (us:intl)${NC}"
>    echo -e "  ${BOLD}Fuso Horário:${NC}          ${FG_GREEN}America/Sao_Paulo (NTP Ativo)${NC}"
>    echo -e "  ${BOLD}Serviço Principal:${NC}     $(get_service_status nome_do_servico)"
>    echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
>    echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"
>    ```
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
>    # Execução recomendada (download e execução local):
>    # wget https://raw.githubusercontent.com/lucasolidev/scripts/main/NOME_DO_SCRIPT_AQUI.sh
>    # chmod +x NOME_DO_SCRIPT_AQUI.sh
>    # sudo ./NOME_DO_SCRIPT_AQUI.sh
>    # ==============================================================================
>    ```
> 
> Aqui está o script original que deve ser adaptado:
> `[INSIRA O SCRIPT AQUI]`"
