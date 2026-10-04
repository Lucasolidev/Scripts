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
>    - **Exceção Obrigatória para Segredos**: Senhas, tokens, chaves e outros segredos devem usar `read -r -s`/`read -r -sp`. O feedback deve confirmar apenas que o valor foi recebido ou gerado, sem revelar conteúdo, comprimento ou parte do segredo no console ou log.
>    - Na criação de contas, preferir o diálogo nativo `passwd`, sem eco e sem capturar a senha em variável. Esse diálogo ocorre após criar a conta; é exceção à coleta inicial para evitar armazenamento intermediário de credenciais.
>    - Antes de `passwd`, identificar explicitamente a conta e informar que será definida uma nova senha, seguida da confirmação. Com captura por `tee`, escrever essa orientação também diretamente no terminal (`/dev/tty`) para garantir que apareça antes do prompt nativo. Nunca registrar a senha.
>    - Se a conta já existe, anunciar explicitamente que criação e definição de senha foram puladas e que a senha atual foi preservada. Aplicar o mesmo feedback a contas administrativas e operacionais; repetir no resumo final, por conta solicitada, se foi criada ou preservada e o grupo vinculado. Não chamar `passwd` em conta existente somente porque a opção criar/garantir foi aceita.
>    - Falha de `passwd` na definição inicial deve oferecer nova tentativa (padrão Sim) ou cancelamento com código 2, preservando códigos de sinais. Não capturar senha nem usar `set -x`. Em reexecução, contas com campo de senha vazio, `!` ou `!!` podem ter definição inicial pendente: consultar emitindo somente essa classificação, nunca hash, e oferecer retomada com confirmação explícita (padrão Não). Senhas existentes, inclusive hashes bloqueados, e contas desabilitadas com `*` permanecem preservadas. Recusa da retomada registra pendência; não anunciar senha configurada.
> 
> 4. **Instalação Silenciosa e Limpa (`apt-get`)**:
>    - **Regra Obrigatória:** Sempre utilize **`apt-get`** em vez de `apt` para garantir máxima compatibilidade, estabilidade de CLI e execução não-interativa segura sem avisos ou caracteres ocultos nos arquivos de log.
>    - Instalar individualmente com feedback por pacote e espera limitada pelo lock do APT. Separar dependências essenciais de utilitários opcionais: falha essencial interrompe; falha opcional entra no resumo de pendências. Sucesso significa retorno verificado, nunca uma lista fixa de pacotes. Evitar registrar saídas que possam conter credenciais de repositórios.
> 
> 5. **Configuração de Teclado, Locales e Fuso Horário (America/Sao_Paulo)**:
>    - Selecionar o arquivo de locale conforme a versão e o layout oficial do pacote. No Ubuntu 26.04, usar `/etc/locale.conf`; no 24.04, preservar o layout legado ou usar `/etc/locale.conf` quando `/etc/default/locale` for seu link de compatibilidade. Validar esse destino conhecido, fazer backup do arquivo regular e preservar o link. Não liberar links arbitrários nas funções administrativas. Para escrita atômica, copiar os valores existentes para temporário privado, executar `update-locale --locale-file` nesse temporário e publicar com a função administrativa.
>    Quando houver configuração de locales, teclado e fuso horário, utilize o bloco padrão:
>    ```bash
>    log_info "Configurando suporte completo a UTF-8 (en_US.UTF-8 e pt_BR.UTF-8)..."
>    # Exemplo usa LOG_DIR privado e helpers de backup/escrita atômica.
>    sed -e 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' \
>        -e 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen > "$LOG_DIR/locale.gen"
>    install_config "$LOG_DIR/locale.gen" /etc/locale.gen
>    locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
>    if [[ -L /etc/default/locale ]]; then
>        [[ $(readlink -f -- /etc/default/locale) == /etc/locale.conf ]] || exit 1
>    fi
>    case "$VERSION_ID" in
>        24.04)
>            if [[ -L /etc/default/locale ]]; then LOCALE_FILE=/etc/locale.conf
>            else LOCALE_FILE=/etc/default/locale; fi
>            ;;
>        26.04) LOCALE_FILE=/etc/locale.conf ;;
>        *) exit 1 ;;
>    esac
>    backup_file "$LOCALE_FILE"
>    if [[ -f "$LOCALE_FILE" ]]; then cp -- "$LOCALE_FILE" "$LOG_DIR/locale"; fi
>    update-locale --locale-file "$LOG_DIR/locale" LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8
>    install_config "$LOG_DIR/locale" "$LOCALE_FILE"
>
>    log_info "Ajustando fuso horário (America/Sao_Paulo)..."
>    timedatectl set-timezone America/Sao_Paulo || exit 1
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
>    log_info "Configuração de teclado gravada; confira a aplicação no console."
>    if [ "$(timedatectl show -p NTPSynchronized --value)" = yes ]; then
>        log_success "NTP sincronizado."
>    else
>        log_warning "Sincronização NTP ainda não confirmada."
>    fi
>    ```
> 
> 6. **Configuração de Aliases do Shell (Seção Dedicada)**:
>    - Criar uma seção própria no fluxo do script com `print_header "ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)"`.
>    - Manter aliases compartilhados em arquivo administrativo, por exemplo `/etc/pos-install-server/bash_aliases`, modo `0644`, restrito a shells interativos. Incluir uma única chamada nos perfis, preservando o conteúdo existente.
>    - Informar se o arquivo compartilhado foi instalado, atualizado ou já tinha o conteúdo esperado, e se a chamada em cada perfil foi adicionada ou já existia. Anunciar sucesso somente após a gravação; falhas por perfil entram nas pendências. Explicar que persistência não carrega aliases na sessão atual: eles ficam disponíveis no próximo Bash interativo ou após `source ~/.bashrc` pelo próprio usuário.
>    - Para `/root` e `/etc/skel`, usar backup e substituição atômica em diretório controlado por root. Para homes, obter conta/home pelo NSS (`getent passwd`) e executar toda a escrita e o backup com os privilégios do proprietário (`runuser`), sem carregar o perfil do usuário ou `BASH_ENV`.
>    - Nunca executar redirecionamentos, cópias ou `chown -R` como root sobre caminhos controlados por usuários. Rejeitar links antes de editar perfis e abandonar root antes da escrita para que a segurança não dependa somente de uma checagem sujeita a corrida.
>    - Exemplo da chamada a adicionar uma única vez ao `.bashrc`:
>    ```bash
>    [ ! -r /etc/pos-install-server/bash_aliases ] || . /etc/pos-install-server/bash_aliases
>    ```
>
> 7. **Hardening de Segurança e Manutenção**:
>    - **SSH Hardening**: Validar `PermitEmptyPasswords no`, `ClientAliveInterval 300` e `ClientAliveCountMax 2` na configuração efetiva. ClientAlive verifica clientes sem resposta; não é timeout de inatividade humana. Aplicar as regras de acesso e recuperação do item 18.
>    - **Fail2Ban**: Instalar e ativar proteção contra força bruta no SSH quando for ambiente Server.
>    - **Firewall UFW**: Ativar regras de proteção de borda.
>    - **Limpeza do Sistema**: `autoremove` pode remover pacotes em uso fora do controle do instalador. Fazer limpeza somente quando solicitada e com revisão dos candidatos; disponibilizar aliases de manutenção não autoriza executá-los automaticamente.
> 
> 8. **Estrutura Sequencial e Numerada de Etapas (Seções e Subseções)**:
>    - Todas as etapas lógicas de execução do script devem ser claramente identificadas por blocos de comentários numerados sequencialmente. Use números inteiros para grandes blocos e decimais (ex: 1.1, 1.2) para sub-etapas do mesmo contexto.
>    - Padrão de Separadores Obrigatório:
>      ```bash
>      # ==============================================================================
>      # 1 - INICIALIZAÇÃO E FUNÇÕES BASE
>      # ==============================================================================
>      
>      # 1.1 - FUNÇÕES DE HIGHLIGHT E LOGGING
>      ... (código) ...
>      
>      # 1.2 - VALIDAÇÃO DE PRIVILÉGIOS E LOGS PADRONIZADOS
>      ... (código) ...
>      
>      # ==============================================================================
>      # 2 - COLETA DE PARÂMETROS
>      # ==============================================================================
>      ```
>      Isso facilita a auditoria, leitura visual hierárquica e manutenção do código.
> 
> 9. **Gestão de Permissões Granulares e POSIX ACLs (Herança Web & Desenvolvedores)**:
>    - **Travessia com Menor Privilégio**: Nunca aplique `chmod o+x` indiscriminadamente em toda a árvore pai. Quando necessário, conceda somente travessia ao usuário ou grupo do serviço com ACL específica, por exemplo `setfacl -m u:www-data:--x <diretorio>`, após validar e resolver o caminho absoluto.
>    - **Código Não Gravável pelo Serviço Web**: O código da aplicação deve pertencer a `root` ou ao usuário de deploy e ser apenas legível pelo processo web. Conceda escrita ao `www-data` exclusivamente nas pastas documentadas como mutáveis (uploads, cache, sessões e temporários).
>    - **Default ACLs Restritas**: Aplique ACLs recursivas e padrão somente dentro das pastas mutáveis. É proibido conceder `rwx` recursivo ao serviço web sobre todo o `DocumentRoot`.
> 
> 10. **Isolamento e Separação Rígida por Versão da Distribuição (OS Release Branching)**:
>    - **Regra Arquitetural Obrigatória:** Quando houver diferenças de repositórios, versões de pacotes ou comportamentos entre versões de SO (ex: Ubuntu 22.04 / 24.04 LTS vs Ubuntu 26.04), **SEPARE RIGOROSAMENTE** os blocos de código em condicionais explícitas baseadas em `lsb_release -rs` ou `/etc/os-release`.
>    - **Proteção do Ambiente Estável de Produção:** Mudanças ou adaptações para outras versões **JAMAIS** devem alterar, sobrescrever ou arriscar o fluxo de versões já homologadas em produção. Mantenha fluxos de código isolados e dedicados por ramo de distribuição.
> 
> 11. **Registro e Salvamento de Logs Padronizados (`relatorio_*`) (Etapa Final Obrigatória)**:
>    - **Regra Arquitetural de Nomenclatura:** Todos os logs gerados pelos scripts devem obrigatoriamente iniciar com o prefixo **`relatorio_`** e utilizar a formatação de data/hora no padrão brasileiro **`DDMMYYYY_HHMM`** (ex: `relatorio_install_lamp_ubuntu_joomla5_25082026_2015.log`). Isso facilita a busca e auto-complete no terminal (`ls /root/relatorio_*`).
>    - Após validar root e ambiente, criar temporário privado com `mktemp -d` e `umask 077`. Capturar stdout/stderr com `tee`, guardando os descritores originais e o PID do processo de captura.
>    - Registrar um finalizador `EXIT`, além de handlers de sinais que encerram com código próprio. O finalizador deve preservar a falha original, salvar o relatório também em erro/cancelamento e só remover os temporários quando a cópia administrativa estiver confirmada.
>    - Antes de copiar o relatório, restaurar stdout/stderr e aguardar `tee`; copiar enquanto a captura ainda escreve pode truncar as últimas mensagens. Não imprimir comandos completos, variáveis de senha, arquivos de autenticação ou saídas potencialmente sensíveis no handler de erros.
>    - Publicar as cópias em `/root` com modo `0600`, por arquivo temporário no mesmo diretório e rename atômico. `latest` é uma cópia regular. Evitar colisões de nomes em execuções no mesmo minuto.
>    - Na home do usuário sudo, abrir a origem administrativa antes de abandonar root e transmitir pelo stdin para um processo do próprio usuário. Criar o temporário e fazer rename já sem root. Não copiar como root seguido de `chown` em diretório do usuário.
>    - Falhas ao salvar o relatório devem ser informadas, preservando a origem e o código de falha. Funções chamadas por `if`, `!` ou `||` precisam propagar erros explicitamente: `set -e` pode estar desabilitado nesses contextos.
>    - A última etapa numerada deve anunciar o salvamento pelo finalizador. Referência de implementação: funções `install_config`, `copy_to_home` e `finalizar` do `pos_install_server.sh`.
>
> 12. **Resultado Final Estruturado (Resumo da Instalação)**:
>    No final de todo script, exiba obrigatoriamente um painel de encerramento utilizando a função `print_header "RESUMO DA INSTALAÇÃO"`.
>    - Preservar o resumo colorido nas refatorações: rótulos em negrito, informações em ciano, estados confirmados em verde e pendências/estados não verificados em amarelo. Não usar verde para auditoria apenas gravada ou sincronização não confirmada. Ao usar `printf`, reservar `%b` aos estilos ANSI controlados e `%s` aos valores para não interpretar escapes nos dados. Referência: `print_summary` do `pos_install_server.sh`.
>    - Agrupar o painel por assunto e manter cada serviço importante em um bloco identificado, com espaço e separador: estado, configuração, regras ou agendamento e histórico quando aplicável. Saídas nativas, como `ufw status`, pertencem ao bloco do próprio serviço, com indentação; nunca anexá-las sem título ao serviço anterior. Distinguir ferramentas manuais (como ACL) de serviços ativos e controles efetivamente aplicados. Quebrar listas extensas de pacotes em linhas e alinhar rótulos considerando caracteres acentuados, não apenas bytes.
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
>    # Anunciar sucesso somente quando as verificações obrigatórias passarem.
>    # Caso contrário, listar pendências ou falha e retornar o código correspondente.
>    echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
>    echo -e "  ${BOLD}Status do Sistema:${NC}     ${STATUS_VERIFICADO}"
>    echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
>    echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}pt_BR.UTF-8 / en_US.UTF-8 (Gerados)${NC}"
>    echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
>    echo -e "  ${BOLD}Layout Ativo:${NC}          ${FG_GREEN}US-International (us:intl)${NC}"
>    echo -e "  ${BOLD}Fuso Horário:${NC}          $(timedatectl show -p Timezone --value) / NTP: ${NTP_STATUS}"
>    echo -e "  ${BOLD}Serviço Principal:${NC}     $(get_service_status nome_do_servico)"
>    echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
>    echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"
>    ```
> 
> 13. **Cabeçalho de Metadados, Comentários e Versionamento**:
>    Todo script deve começar com o seguinte bloco de metadados padrão, certificando-se de alterar a string `NOME_DO_SCRIPT_AQUI.sh` e a descrição para refletir os dados reais do script atual.
>    **Regra de Versionamento:** Utilize sempre o padrão de versionamento de dois dígitos (`MAJOR.MINOR`). É estritamente proibido o uso de `PATCH` (ex: incorreto `VERSION="1.1.0"` | correto `VERSION="1.1"`, `VERSION="1.2"`).
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
> 14. **Gestão Segura de Credenciais e Prevenção de Falsos Positivos (GitGuardian / Secret Scanners)**:
>    - **Zero Hardcoded Secrets**: Nunca inclua senhas, tokens de API ou chaves em texto plano no código dos scripts.
>    - **Geração e Coleta Segura**: Senhas devem ser geradas dinamicamente em tempo de execução via `openssl rand -hex 18` ou solicitadas interativamente com entrada oculta via `read -r -sp`.
>    - **Segredos Fora dos Logs**: Nunca imprimir credenciais no resumo, em funções `log_*`, em argumentos de linha de comando ou em arquivos de relatório. Quando for indispensável persistir uma credencial, usar arquivo dedicado, proprietário `root:root`, modo `0600`, fora do `DocumentRoot` e informar somente seu caminho.
>    - **Placeholders Padronizados em Exemplos**: Em qualquer documentação, comentário ou mensagem do script, utilize obrigatoriamente tags genéricas entre colchetes angulares (`<senha_do_usuario>`, `<chave_secreta>`, `<host_smtp>`) para evitar o disparo acidental de ferramentas de auditoria e scanners de segredos.
> 
> 15. **Execução Estrita, Validação e Falha Segura**:
>    - Iniciar scripts Bash com `set -Eeuo pipefail` e `umask 077`. Usar `trap` para limpeza de temporários e tratamento de interrupções.
>    - Validar por lista de permissões todos os valores usados em caminhos, nomes de arquivos, SQL, cron, systemd, Apache/Nginx e outras configurações privilegiadas. Rejeitar quebras de linha, caracteres de controle, caminhos relativos e destinos críticos.
>    - Não mascarar falhas críticas com `|| true`. Instalação de dependências, validação de configuração e início de serviços devem abortar com mensagem clara. Antes de recarregar um serviço, executar seu teste nativo de configuração.
> 
> 16. **Cadeia de Suprimentos e Arquivos Temporários**:
>    - É proibido executar conteúdo remoto diretamente com construções como `curl ... | bash` ou `wget ... | sh`. Baixar por HTTPS, fixar a origem/versão e verificar assinatura ou checksum publicado por canal oficial antes de executar ou extrair.
>    - Para plugins distribuídos por Git, fixar commits consultados no repositório oficial via HTTPS e conferir o objeto obtido antes de publicar. Não carregar código de branches móveis como root. Fixação garante reprodutibilidade, não revisão da segurança do fornecedor.
>    - Nunca usar nomes previsíveis em `/tmp`. Criar diretório privado com `mktemp -d`, modo `0700`, arquivos modo `0600` e limpeza via `trap`. Validar arquivos compactados contra caminhos absolutos e travessia (`../`) antes da extração.
> 
> 17. **Menor Privilégio para Bancos, Rede e Serviços Web**:
>    - Usuários de aplicação devem ser restritos ao host necessário, sem curingas como `'%'` e sem `GRANT OPTION`, salvo requisito explícito documentado. Bancos locais devem escutar apenas em loopback.
>    - Firewalls devem preservar primeiro a porta SSH efetivamente configurada, aplicar política de entrada restritiva e abrir somente serviços instalados e validados.
>    - Aplicações com autenticação devem oferecer HTTPS antes do uso em produção; habilitar redirecionamento, cookies `Secure` e HSTS somente após um certificado válido estar ativo.
>    - Quando um controle depender do kernel ou do ambiente (por exemplo, regras do `auditd`), detectar explicitamente ambientes restritos como WSL. Nunca silenciar a falha: informar no resumo final que a proteção ficou indisponível e manter a falha bloqueante nos servidores Linux suportados.
>    - Se uma instalação web exigir o arquivo de configuração inicial, preferir o fluxo que exporta a configuração para instalação controlada como administrador. Não criar arquivo vazio quando a aplicação o interpretar como configuração válida e nunca liberar escrita do processo web no diretório inteiro de código.
>    - O padrão de produção é código sem escrita pelo processo web. Atualizações pelo painel exigem janela de manutenção com acesso restrito e revogação de ACLs temporárias ao terminar, inclusive para arquivos novos. Não habilitar escrita persistente como padrão de instalação.
>    - Toda pasta declarada gravável deve receber simultaneamente bloqueio HTTP de scripts, incluindo variantes de extensão, e não interpretar .htaccess. Bloqueio HTTP não impede inclusão interna de arquivos pela aplicação.
>    - Aplicar limites PHP por pool FPM e selecionar o socket exato; preservar CLI e outras aplicações. Módulos opcionais devem ser selecionados por necessidade, sem classificar uma extensão como vulnerável apenas por existir. Manter cURL para integrações e atualizações.
>    - Instaladores para servidor novo devem recusar sobreposição de DocumentRoot não vazio e sites personalizados ativos. Falha em configuração ou dependência essencial deve interromper sem anunciar proteção ativa.
>    - Documentar separadamente o que foi validado estaticamente e o que ainda depende de homologação. ShellCheck não valida configuração Apache/Nginx/FPM, comportamento HTTP ou segurança de mídia migrada.
> 
> 18. **Acesso Administrativo, SSH e Recuperação**:
>    - Sudo amplo (`ALL`) com negações de comandos é uma barreira operacional contornável, não separação de privilégios. Documentar essa escolha quando o proprietário exigir autonomia para instalar e configurar aplicações. Não prometer impedir tomada de controle por outro administrador.
>    - Respeitar as escolhas do operador em todas as etapas relacionadas: recusar gestão de grupos também preserva suas regras. Aplicar a política somente ao grupo explicitamente informado, sem criar conjuntos padrão implicitamente. Preservar maiúsculas/minúsculas do nome tanto na identidade NSS quanto no sudoers; evitar colisões de nomes de arquivo. Reutilizar arquivo legado somente quando sua regra corresponde ao grupo exato, sem sobrescrever regras de outro grupo. Não remover grupos/regras anteriores automaticamente. Permitir gestão do grupo sem exigir criação de usuário.
>    - Validar nomes de contas/grupos antes de compor sudoers. Preparar arquivo temporário, validar com o `visudo` instalado, aplicar com modo `0440`, conferir a configuração completa e restaurar o arquivo anterior se houver erro.
>    - Conferir recursos no parser de cada runtime suportado: sudo-rs pode rejeitar curingas em argumentos aceitos pelo sudo tradicional. Para uma política comum, preferir formas explícitas e documentar o alcance dos bloqueios; não generalizar compatibilidade pela versão do Ubuntu.
>    - Preparar contas antes de restringir SSH. Desabilitar root somente após declaração de login alternativo previamente testado e verificações locais compatíveis. Se não for possível comprovar as condições, preservar a política anterior e registrar pendência.
>    - Preservar personalizações e considerar a precedência de `Include` e `Match`. Validar com `sshd -t` e `sshd -T`, incluindo contextos conhecidos com `-C`. Isso não prova acesso a partir de todas as origens nem substitui uma nova conexão real.
>    - Quando a política deve ficar no `sshd_config` principal, atualizar a primeira ocorrência global da diretiva, inclusive comentada, no mesmo local e remover duplicatas globais dessa diretiva. Preservar os demais parâmetros e todos os blocos `Match`. Inserir diretivas ausentes antes do primeiro `Match`, evitando escrever opções globais dentro de contexto condicional. Não apagar Includes de terceiros para forçar precedência; conflito efetivo exige restauração e revisão.
>    - Na migração de política separada gerada por versão anterior, fazer backup do principal e do legado, reconhecer origem e conteúdo gerenciado antes da remoção e recusar arquivos personalizados ou Includes complexos. Remover o Include legado e publicar as diretivas no principal na mesma etapa protegida por restauração; validar antes de recarregar. A restauração deve recuperar os dois arquivos e suas permissões anteriores.
>    - Usar backup e restauração em falha/interrupção da etapa SSH, preferindo reload a restart. Não ativar firewall antes de permitir portas efetivas, listeners de `ssh.socket` e a porta da conexão atual, quando disponíveis. Exceções de firewall explicitamente solicitadas devem ser documentadas.
>    - Logs locais podem ser modificados por root. Encaminhamento externo requer destino e política próprios; não inventar endpoints, credenciais ou configurar integração não solicitada.
>
> 19. **Configuração Reexecutável e Validação de Estado**:
>
>    - Na homologação, verificar o componente efetivamente instalado/ativado: pacotes virtuais podem ser atendidos por `Provides`, serviços podem iniciar por sockets habilitados e ações de firewall podem usar nftables em vez de iptables. Não presumir nomes de cadeias ou exigir dois mecanismos de inicialização simultâneos. Confirmar o provedor, a unidade ou o backend real e testar o comportamento correspondente.
>    - Para validar plugins/configurações de editor, abrir como usuário comum com o mesmo modo de inicialização do uso real. No Vim, `-es` ignora inicializações sem `-u`; um teste com esse modo não comprova descoberta automática do `.vimrc`. Não executar plugins como root apenas para validar a instalação.
>    - Registrar código de cada execução, verificações aprovadas/falhas/limitadas, ambiente e versão do artefato. Preservar evidência de testes corrigidos e a razão da correção. Unidades de kernel falhas no WSL devem ser informadas explicitamente como indisponíveis; não ocultar com `reset-failed` nem declarar todos os serviços ativos.
>    - Aplicar arquivos por substituição atômica, com backup por execução e retorno explícito de erros. Separar configuração solicitada, gravada, ativa e efetivamente verificada.
>    - Sucesso do gerenciador de pacotes não comprova os pré-requisitos do serviço. Conferir contas de serviço antes de configurar o daemon e usar a definição sysusers oficial do pacote, sem inventar UID/GID. Não remover ou contornar genericamente diversions/stubs. Exceção documentada do Ubuntu 26.04 em WSL: se o stub conhecido contém somente `#!/bin/sh` e `exit 0`, a diversion aponta exatamente para `.real` e o binário original regular tem proprietário root, permissões sem escrita de grupo/outros, checksum correspondente aos metadados instalados e identificação systemd, pode usá-lo diretamente, anunciando a recuperação. Não executar todos os arquivos sysusers, apenas a definição do serviço necessário. Casos desconhecidos continuam interrompendo.
>    - Preferir arquivo próprio em `jail.d` a sobrescrever `jail.local`; conferir configuração e disponibilidade da jaula após o serviço iniciar. Exceções de redes são parâmetros, não pressuposições de confiança.
>    - Não deduzir que atualizações automáticas funcionam apenas por `unattended-upgrades.service`, que pode ser um auxiliar de encerramento. Conferir os parâmetros efetivos de atualização de índices e instalação automática do APT, timers ativos e habilitados e próxima execução calculada; mostrar esses dados no resumo. Preservar horários existentes e distinguir agendamento de execução comprovada no histórico. Serviços oneshot podem ficar inativos entre disparos sem indicar falha; execução real e origens ainda requerem homologação.
>    - Gerar regras auditd para caminhos existentes e confirmar regras no kernel. Conferir `/dev/shm` com `findmnt`; localizar uma string no fstab não comprova flags de montagem.
>    - Personalizações de editores devem ser opcionais, com perfis existentes preservados e sem copiar diretórios pessoais de root para usuários.
>    - Etapas opcionais de editores devem informar progresso de obtenção/verificação por plugin e resumir pacote instalado/existente, recursos configurados e resultados por perfil (adicionado, já vinculado, personalizado preservado ou falha). Conferir os diretórios esperados antes de anunciar plugins disponíveis. Instalação compartilhada não comprova carregamento em perfil personalizado preservado; anunciar essa distinção e informar recusa/falha explicitamente.
>    - Documentar códigos de saída. Convenção de referência: 0 = etapas solicitadas verificadas; 1 = falha; 2 = cancelamento; 3 = conclusão com pendências; sinais mantêm códigos convencionais.
>    - Homologação dinâmica deve ocorrer somente nos ambientes descartáveis autorizados. Se o proprietário fará a instalação, executar apenas análise estática e entregar roteiro de verificação manual, incluindo reexecução, opção de recusa, falhas e restauração.
>
> Aqui está o script original que deve ser adaptado:
> `[INSIRA O SCRIPT AQUI]`"
