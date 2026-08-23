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
>    log_skipped() { echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }
>    print_alert_box() {
>        local msg="$1"
>        echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
>    }
>    ```
> 
> 3. **Interatividade e Coleta de Parâmetros com Feedback Visual Imediato**:
>    - Todas as perguntas (`read -p`) devem ser agrupadas no início em um bloco chamado `"COLETA DE PARÂMETROS"`.
>    - Utilize o padrão `  ${FG_YELLOW}${ARROW} Pergunta? (s/N): ${NC}` nas perguntas do `read` (onde `(s/N)` indica que o padrão ao apertar ENTER é Não).
>    - **Feedback Visual Imediato (`log_info`)**: Imediatamente após a coleta de qualquer entrada do usuário (seja um valor digitado, gerado aleatoriamente ou o valor padrão assumido ao dar ENTER), exiba uma linha com `log_info` confirmando o valor definido (ex: `log_info "Nome do Banco definido: ${FG_GREEN}${JOOMLA_DB_NAME}${NC}"`). Isso dá clareza e segurança visual ao operador.
> 
> 4. **Instalação Silenciosa e Limpa (`apt-get`)**:
>    - **Regra Obrigatória:** Sempre utilize **`apt-get`** em vez de `apt` para garantir máxima compatibilidade, estabilidade de CLI e execução não-interativa segura sem avisos ou caracteres ocultos nos arquivos de log.
>    - Execute a instalação de forma loopada e individual para cada pacote de forma silenciosa (`> /dev/null 2>&1`), exibindo um log claro de `log_success` se instalado, ou `log_warning` / `log_error` caso falhe.
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
>    ```
> 
> 6. **Configuração de Aliases do Shell (Seção Dedicada)**:
>    - Criar uma seção própria no fluxo do script com `print_header "ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)"`.
>    - Injetar/atualizar aliases nos perfis `/root/.bashrc`, `/etc/skel/.bashrc` e `/home/*/.bashrc`:
>    ```bash
>    print_header "ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)"
>    log_info "Configurando aliases de produtividade e segurança no Shell..."
>    for bashrc in /root/.bashrc /etc/skel/.bashrc /home/*/.bashrc; do
>      if [ -f "$bashrc" ]; then
>        grep -q "alias ll=" "$bashrc" && sed -i "s/alias ll=.*/alias ll='ls -alFh'/" "$bashrc" || grep -q "#alias ll=" "$bashrc" && sed -i "s/#alias ll=.*/alias ll='ls -alFh'/" "$bashrc" || echo "alias ll='ls -alFh'" >> "$bashrc"
>        grep -q "alias rm=" "$bashrc" || echo "alias rm='rm -i'" >> "$bashrc"
>        grep -q "alias cp=" "$bashrc" || echo "alias cp='cp -i'" >> "$bashrc"
>        grep -q "alias mv=" "$bashrc" || echo "alias mv='mv -i'" >> "$bashrc"
>        grep -q "alias df=" "$bashrc" || echo "alias df='df -h'" >> "$bashrc"
>        grep -q "alias free=" "$bashrc" || echo "alias free='free -h'" >> "$bashrc"
>        grep -q "alias ports=" "$bashrc" || echo "alias ports='sudo ss -tulanp'" >> "$bashrc"
>        grep -q "alias myip=" "$bashrc" || echo "alias myip='curl -s ifconfig.me; echo'" >> "$bashrc"
>        grep -q "alias \.\.=" "$bashrc" || echo "alias ..='cd ..'" >> "$bashrc"
>        grep -q "alias \.\.\.=" "$bashrc" || echo "alias ...='cd ../..'" >> "$bashrc"
>        grep -q "alias update=" "$bashrc" || echo "alias update='sudo apt-get update && sudo apt-get upgrade -y'" >> "$bashrc"
>        grep -q "alias clean=" "$bashrc" || echo "alias clean='sudo apt-get autoremove -y && sudo apt-get autoclean'" >> "$bashrc"
>        grep -q "alias reload=" "$bashrc" || echo "alias reload='source ~/.bashrc'" >> "$bashrc"
>      fi
>    done
>    log_success "Aliases de produtividade e segurança configurados nos perfis .bashrc."
>    ```
> 
> 7. **Hardening de Segurança e Manutenção**:
>    - **SSH Hardening**: Ajustar `PermitEmptyPasswords no`, `ClientAliveInterval 300` e `ClientAliveCountMax 2`.
>    - **Fail2Ban**: Instalar e ativar proteção contra força bruta no SSH quando for ambiente Server.
>    - **Firewall UFW**: Ativar regras de proteção de borda.
>    - **Limpeza do Sistema**: Executar `apt-get autoremove -y` e `apt-get autoclean -y` ao final das instalações.
> 
> 8. **Estrutura Sequencial e Numerada de Etapas**:
>    Todas as etapas lógicas de execução do script devem ser claramente identificadas por cabeçalhos e comentários numerados sequencialmente (ex: `# 1. VERIFICAÇÃO DE PRIVILÉGIOS`, `# 2. COLETA DE PARÂMETROS`, ..., `# N. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG`). Isso facilita a auditoria, leitura e manutenção do código.
> 
> 9. **Registro e Salvamento de Logs (Etapa Final Obrigatória)**:
>    - No início da execução (logo após validação de privilégios), inicialize a captura do console e arquivo temporário:
>      ```bash
>      LOG_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
>      LOG_FILENAME="nome_do_script_${LOG_TIMESTAMP}.log"
>      LOG_TMP="/tmp/${LOG_FILENAME}"
>      exec > >(tee -a "$LOG_TMP") 2>&1
>      ```
>    - Na **última etapa numerada do script**, salve automaticamente cópias timestamped e um atalho `<nome_do_script>_latest.log` no diretório `/root` e na Home do usuário real que executou o comando via `sudo`:
>      ```bash
>      # ==============================================================================
>      # [NÚMERO_ETAPA]. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
>      # ==============================================================================
>      print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"
>
>      # Salva cópias no diretório /root
>      cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
>      cp "$LOG_TMP" "/root/nome_do_script_latest.log" 2>/dev/null || true
>      log_success "Log salvo em: /root/${LOG_FILENAME}"
>      log_success "Atalho do último log: /root/nome_do_script_latest.log"
>
>      # Se executado via sudo, salva também na pasta home do usuário real
>      if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
>        REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
>        if [ -d "$REAL_USER_HOME" ]; then
>          cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
>          cp "$LOG_TMP" "${REAL_USER_HOME}/nome_do_script_latest.log" 2>/dev/null || true
>          chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/nome_do_script_latest.log" 2>/dev/null || true
>          log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
>        fi
>      fi
>
>      rm -f "$LOG_TMP" 2>/dev/null || true
>
>      draw_separator
>      echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
>      ```
> 
> 10. **Resultado Final Estruturado (Resumo da Instalação)**:
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
> 11. **Cabeçalho de Metadados e Comentários**:
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
