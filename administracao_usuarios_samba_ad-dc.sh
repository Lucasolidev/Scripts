#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# Administracao de Usuarios Samba AD
# ==============================================================================
# RESUMO DO SCRIPT:
# Este script fornece uma interface interativa via terminal para facilitar a 
# administração de um domínio Active Directory provido pelo Samba 4 (AD DC). 
# Ele automatiza tarefas complexas com ldbmodify e samba-tool, incluindo:
# - Criação de usuários completos com atributos POSIX (UID, GID, loginShell).
# - Criação e aplicação de permissões (chown/chmod) no diretório home do usuário.
# - Correção de usuários antigos para injetar os atributos POSIX faltantes.
# - Listagem e consulta de usuários e computadores do Active Directory.
# - Exclusão de computadores e exclusão de usuários (gerenciando também a pasta home).
#
# COMPATIBILIDADE (Samba AD DC):
# O script exige que o Samba 4 esteja configurado como um Active Directory 
# Domain Controller (AD DC). Se o seu servidor for apenas um servidor de arquivos 
# comum (Standalone Server), o script não vai funcionar porque os comandos 
# 'samba-tool user' não existem nesse modo.
# ==============================================================================
# Baixar o script:
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh
# curl -O https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh
#
# Visualizar o script antes de executar:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh
#
# Executar via URL diretamente (exige sudo):
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh | sudo bash
# sudo bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh)
# sudo bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/administracao_usuarios_samba_ad-dc.sh | sudo bash
#
# ==============================================================================

# --- Configurações ESPECÍFICAS (ALTERAR ANTES DE USAR) ---
# ATENÇÃO: Revise estas variáveis para adequar à infraestrutura do seu servidor.
# O caminho do sam.ldb, por exemplo, pode mudar conforme o sistema operacional.
BASE_UID=10000 
HOME_BASE="/arquivos/usuarios" # Pasta base onde as homes físicas serão criadas
SAM_LDB="/var/lib/samba/private/sam.ldb" # Caminho do banco de dados do Samba
DEFAULT_SHELL="/bin/bash"
HOME_DIR_TEMPLATE="/home/domain/%U"
 
PRIMARY_LINUX_GROUP="Domain Users" 
PRIMARY_LINUX_GID=10500 

# --- Paleta de Cores e Estilos (ANSI) ---
NC="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
FG_CYAN="\033[36m"
FG_YELLOW="\033[33m"
FG_GREEN="\033[32m"
FG_RED="\033[31m"
FG_WHITE="\033[37m"
ARROW="❯"

# --- Funções Auxiliares de Visual ---
draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}
print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}=== SYSTEM MANAGER ===${NC}"
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
}
log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# --- Obter informações do domínio dinamicamente ---
DOMAIN_DN=$(sudo ldbsearch -H "$SAM_LDB" -b "" -s base defaultNamingContext 2>/dev/null | grep defaultNamingContext | awk '{print $2}')
if [ -z "$DOMAIN_DN" ]; then
    log_error "Não foi possível determinar o DN do domínio a partir de $SAM_LDB."
    exit 1
fi
# ATENÇÃO: Altere a estrutura de OUs abaixo para corresponder à árvore do seu AD.
# Por exemplo, se seus usuários ficam na OU TI, dentro da OU Colaboradores, use:
# TARGET_OU="OU=TI,OU=Colaboradores,$DOMAIN_DN"
TARGET_OU="OU=Users,$DOMAIN_DN" 
WORKGROUP=$(sudo samba-tool testparm --suppress-prompt 2>/dev/null | grep 'workgroup =' | awk '{print $3}')
if [ -z "$WORKGROUP" ]; then
    log_error "Não foi possível determinar o nome do Workgroup (NetBIOS) do smb.conf."
    exit 1
fi

# --- Função de Verificação ---
func_get_user_dn() {
    local username_to_check="$1"
    local user_dn
    user_dn=$(sudo ldbsearch -H "$SAM_LDB" "sAMAccountName=$username_to_check" dn 2>/dev/null | awk -F': ' '/^dn: / {print $2}' | xargs)
    echo "$user_dn"
}

# Se executado via pipe (ex: wget -qO- URL | sudo bash), reconecta o STDIN ao terminal para permitir leitura interativa
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec 0</dev/tty
fi

# --- Loop do Menu Principal ---
while true; do
    clear
    print_header "Administração do Samba AD (servldap)"
    echo -e "  ${FG_CYAN}${BOLD}--- CRIAÇÃO ---${NC}"
    echo -e "  1. Criar novo usuário (com pasta home)"
    echo -e "  2. Criar novo usuário (SEM pasta home)"
    echo ""
    echo -e "  ${FG_CYAN}${BOLD}--- CONSULTA / MODIFICAÇÃO ---${NC}"
    echo -e "  3. Listar todos os usuários"
    echo -e "  4. Listar todos os computadores"
    echo -e "  5. Consultar usuário específico"
    echo -e "  6. Corrigir usuário (Adicionar POSIX / Criar Home)"
    echo ""
    echo -e "  ${FG_CYAN}${BOLD}--- EXCLUSÃO ---${NC}"
    echo -e "  7. Excluir usuário (MANTER pasta home)"
    echo -e "  8. Excluir usuário (e perguntar da pasta home)"
    echo -e "  9. Excluir computador do domínio"
    echo ""
    draw_separator
    echo -e "  10. Sair"
    draw_separator
    read -p "  ${FG_YELLOW}${ARROW} Escolha uma opção [1-10]: ${NC}" choice

    case "$choice" in
        1 | 2)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome de login do usuário (ex: joao.silva): ${NC}" USERNAME
            if [ -z "$USERNAME" ]; then
                log_error "Nome de login não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            USER_DN_CHECK=$(func_get_user_dn "$USERNAME")
            if [ -n "$USER_DN_CHECK" ]; then
                log_error "O usuário '$USERNAME' já existe no domínio (DN: $USER_DN_CHECK)."
                log_warning "Ação cancelada. Use a Opção 6 para corrigir usuários existentes."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            log_info "Usuário '$USERNAME' não encontrado. Prosseguindo com a coleta..."
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome completo do usuário (ex: João da Silva): ${NC}" FULLNAME
            if [ -z "$FULLNAME" ]; then
                log_error "Nome completo não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            while true; do
                read -sp "  ${FG_YELLOW}${ARROW} Digite a senha para o usuário '$USERNAME': ${NC}" PASSWORD
                echo
                read -sp "  ${FG_YELLOW}${ARROW} Confirme a senha: ${NC}" PASSWORD_CONFIRM
                echo
                [ "$PASSWORD" = "$PASSWORD_CONFIRM" ] && [ -n "$PASSWORD" ] && break
                log_warning "Senhas não conferem ou estão vazias. Tente novamente."
            done

            print_header "CRIANDO USUÁRIO: $USERNAME"
            log_info "Criando usuário '$USERNAME' no container padrão..."
            if ! sudo samba-tool user create "$USERNAME" "$PASSWORD" > /dev/null 2>&1; then
                log_error "Falha ao criar o usuário '$USERNAME' no AD."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            log_success "Usuário criado no container padrão."
            
            log_info "Movendo usuário '$USERNAME' para a OU '$TARGET_OU'..."
            if ! sudo samba-tool user move "$USERNAME" "$TARGET_OU" > /dev/null 2>&1; then
                log_error "Falha ao mover o usuário '$USERNAME'."
                log_warning "Tentando remover o usuário '$USERNAME' para limpeza..."
                sudo samba-tool user delete "$USERNAME" > /dev/null 2>&1
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            log_success "Usuário movido para a OU alvo."
            USER_DN_BEFORE_RENAME="CN=$USERNAME,$TARGET_OU"

            log_info "Renomeando CN do usuário para '$FULLNAME'..."
            LDIF_RENAME_FILE="/tmp/rename_cn_${USERNAME}.ldif"
            cat << EOF > $LDIF_RENAME_FILE
dn: $USER_DN_BEFORE_RENAME
changetype: modrdn
newrdn: CN=$FULLNAME
deleteoldrdn: 1
EOF
            LDIF_OUTPUT=$(sudo ldbmodify -H "$SAM_LDB" $LDIF_RENAME_FILE 2>&1)
            if [ $? -ne 0 ] || [[ "$LDIF_OUTPUT" == *"Error:"* ]] || [[ "$LDIF_OUTPUT" == *"ERR:"* ]] || [[ "$LDIF_OUTPUT" == *"failed"* ]]; then
                log_error "Falha ao renomear o CN do usuário para '$FULLNAME'."
                log_error "Saída do LDB: $LDIF_OUTPUT"
                rm -f $LDIF_RENAME_FILE
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            rm -f $LDIF_RENAME_FILE
            USER_DN_FINAL="CN=$FULLNAME,$TARGET_OU"
            log_success "CN renomeado. DN final: $USER_DN_FINAL"

            log_info "Definindo atributos de nome (Nome Completo, Nome, Sobrenome)..."
            GIVEN_NAME=$(echo "$FULLNAME" | awk '{print $1}')
            SURNAME=$(echo "$FULLNAME" | cut -d' ' -f2-)
            LDIF_NAME_FILE="/tmp/set_name_${USERNAME}.ldif"
            cat << EOF > $LDIF_NAME_FILE
dn: $USER_DN_FINAL 
changetype: modify
replace: displayName
displayName: $FULLNAME
-
replace: givenName
givenName: $GIVEN_NAME
-
replace: sn
sn: $SURNAME
EOF
            LDIF_OUTPUT=$(sudo ldbmodify -H "$SAM_LDB" $LDIF_NAME_FILE 2>&1)
            if [ $? -ne 0 ] || [[ "$LDIF_OUTPUT" == *"Error:"* ]] || [[ "$LDIF_OUTPUT" == *"ERR:"* ]] || [[ "$LDIF_OUTPUT" == *"failed"* ]]; then
                log_error "Falha ao definir atributos de nome para '$USERNAME'."
                log_error "Saída do LDB: $LDIF_OUTPUT"
                log_warning "Tentando remover o usuário '$USERNAME' para limpeza..."
                sudo samba-tool user delete "$USERNAME" > /dev/null 2>&1
                rm -f $LDIF_NAME_FILE
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            rm -f $LDIF_NAME_FILE
            log_success "Atributos de nome definidos."
            
            log_info "Determinando o próximo UID disponível (a partir de $BASE_UID)..."
            LAST_UID=$(sudo ldbsearch -H "$SAM_LDB" '(uidNumber=*)' uidNumber --sorted 2>/dev/null | grep uidNumber | awk '{print $2}' | sort -n | tail -n 1)
            if [ -z "$LAST_UID" ] || [ "$LAST_UID" -lt "$BASE_UID" ]; then
                NEXT_UID=$BASE_UID
            else
                NEXT_UID=$((LAST_UID + 1))
            fi
            while sudo ldbsearch -H "$SAM_LDB" "uidNumber=$NEXT_UID" cn 2>/dev/null | grep -q "num_entries: 1"; do
              log_warning "UID $NEXT_UID já existe, tentando o próximo..."
              NEXT_UID=$((NEXT_UID + 1))
            done
            log_success "Próximo UID a ser usado: $NEXT_UID"
            USER_UID=$NEXT_UID

            log_info "Atribuindo atributos POSIX para '$USERNAME'..."
            LDIF_POSIX_FILE="/tmp/set_posix_${USERNAME}.ldif"
            cat << EOF > $LDIF_POSIX_FILE
dn: $USER_DN_FINAL 
changetype: modify
replace: uidNumber
uidNumber: $NEXT_UID
-
replace: gidNumber
gidNumber: $PRIMARY_LINUX_GID
-
replace: loginShell
loginShell: $DEFAULT_SHELL
-
replace: unixHomeDirectory
unixHomeDirectory: $HOME_DIR_TEMPLATE
EOF
            LDIF_OUTPUT=$(sudo ldbmodify -H "$SAM_LDB" $LDIF_POSIX_FILE 2>&1)
            if [ $? -ne 0 ] || [[ "$LDIF_OUTPUT" == *"Error:"* ]] || [[ "$LDIF_OUTPUT" == *"ERR:"* ]] || [[ "$LDIF_OUTPUT" == *"failed"* ]]; then
                log_error "Falha ao aplicar atributos POSIX para '$USERNAME'."
                log_error "Saída do LDB: $LDIF_OUTPUT"
                log_warning "Tentando remover o usuário '$USERNAME' para limpeza..."
                sudo samba-tool user delete "$USERNAME" > /dev/null 2>&1
                rm -f $LDIF_POSIX_FILE
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            rm -f $LDIF_POSIX_FILE
            log_success "Atributos POSIX definidos com sucesso."

            if [ "$choice" = "1" ]; then
                USER_HOME_PATH="$HOME_BASE/$USERNAME"
                log_info "Verificando/Criando diretório home físico em $USER_HOME_PATH..."
                if [ ! -d "$USER_HOME_PATH" ]; then
                    sudo mkdir -p "$USER_HOME_PATH"
                    if [ $? -ne 0 ]; then
                        log_error "Falha ao criar o diretório $USER_HOME_PATH."
                        log_warning "O usuário '$USERNAME' foi criado, mas a pasta home falhou."
                        read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                        continue
                    fi
                fi
                
                QUALIFIED_USERNAME="${WORKGROUP}\\${USERNAME}"
                log_info "Definindo proprietário ($USER_UID:$PRIMARY_LINUX_GROUP) e permissões (2770) para $USER_HOME_PATH..."
                sudo net cache flush 2>/dev/null
                sleep 1 
                
                if ! sudo chown "$QUALIFIED_USERNAME":"${WORKGROUP}\\Domain Users" "$USER_HOME_PATH" 2>/dev/null || ! sudo chmod 700 "$USER_HOME_PATH" 2>/dev/null; then
                    log_warning "Falha ao usar '$QUALIFIED_USERNAME' para chown. Tentando com UID numérico '$USER_UID'..."
                    if ! sudo chown "$USER_UID:$PRIMARY_LINUX_GROUP" "$USER_HOME_PATH" 2>/dev/null; then
                      log_error "Falha ao definir o proprietário/grupo para $USER_HOME_PATH."
                      read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                      continue
                    fi
                fi
                if ! sudo chmod 2770 "$USER_HOME_PATH" 2>/dev/null; then
                     log_error "Falha ao definir permissões para $USER_HOME_PATH."
                     read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                     continue
                fi
                log_success "Permissões do diretório home definidas."
            fi

            print_header "RESUMO DO SISTEMA"
            echo -e "  Usuário '$USERNAME' ($FULLNAME) criado com sucesso!"
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            echo -e "  UID (Definido): $USER_UID"
            echo -e "  GID Primário  : $PRIMARY_LINUX_GID ($PRIMARY_LINUX_GROUP)"
            echo -e "  DN Final no AD: $USER_DN_FINAL"
            if [ "$choice" = "1" ]; then
                echo -e "  Home (Físico) : $USER_HOME_PATH"
            else
                echo -e "  ${FG_YELLOW}Home (Físico) : Não criada por opção${NC}"
            fi
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            ;;
        
        3)
            print_header "Listando Todos os Usuários"
            log_info "Pressione 'q' para sair da lista."
            sleep 1
            sudo samba-tool user list | less
            log_success "Listagem concluída."
            ;;
            
        4)
            print_header "Listando Todos os Computadores"
            log_info "Pressione 'q' para sair da lista."
            sleep 1
            sudo samba-tool computer list | less
            log_success "Listagem concluída."
            ;;
            
        5)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome de login do usuário a consultar: ${NC}" USERNAME
            if [ -z "$USERNAME" ]; then
                log_error "Nome de login não pode ser vazio."
            else
                print_header "Consultar Usuário Específico"
                log_info "Consultando atributos para '$USERNAME'..."
                log_info "Pressione 'q' para sair da lista."
                sleep 1
                sudo samba-tool user show "$USERNAME" 2>/dev/null | less
                log_success "Consulta concluída."
            fi
            ;;

        6)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome de login do usuário a CORRIGIR: ${NC}" USERNAME
            if [ -z "$USERNAME" ]; then
                log_error "Nome de login não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            print_header "CORRIGIR USUÁRIO: $USERNAME"
            USER_DN_FINAL=$(func_get_user_dn "$USERNAME")
            if [ -z "$USER_DN_FINAL" ]; then
                log_error "O usuário '$USERNAME' não foi encontrado no domínio."
                log_warning "Ação cancelada. Use a Opção 1 para criar."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            log_info "Usuário '$USERNAME' encontrado (DN: $USER_DN_FINAL). Verificando atributos POSIX..."
            if ! sudo samba-tool group listmembers usuarios 2>/dev/null | grep -q "^$USERNAME$"; then
              log_info "Adicionando '$USERNAME' ao grupo AD 'usuarios'..."
              sudo samba-tool group addmembers usuarios "$USERNAME" >/dev/null 2>&1 || true
            fi
            
            USER_UID=$(sudo ldbsearch -H "$SAM_LDB" -b "$USER_DN_FINAL" '(objectClass=user)' uidNumber 2>/dev/null | grep uidNumber | awk '{print $2}')
            
            if [ -n "$USER_UID" ]; then
                log_warning "Usuário '$USERNAME' já possui uidNumber ($USER_UID). Pulando adição de POSIX."
            else
                log_info "Atributos POSIX não encontrados. Adicionando..."
                
                log_info "Determinando o próximo UID disponível (a partir de $BASE_UID)..."
                LAST_UID=$(sudo ldbsearch -H "$SAM_LDB" '(uidNumber=*)' uidNumber --sorted 2>/dev/null | grep uidNumber | awk '{print $2}' | sort -n | tail -n 1)
                if [ -z "$LAST_UID" ] || [ "$LAST_UID" -lt "$BASE_UID" ]; then
                    NEXT_UID=$BASE_UID
                else
                    NEXT_UID=$((LAST_UID + 1))
                fi
                while sudo ldbsearch -H "$SAM_LDB" "uidNumber=$NEXT_UID" cn 2>/dev/null | grep -q "num_entries: 1"; do
                  log_warning "UID $NEXT_UID já existe, tentando o próximo..."
                  NEXT_UID=$((NEXT_UID + 1))
                done
                log_success "Próximo UID a ser usado: $NEXT_UID"
                USER_UID=$NEXT_UID 
                
                LDIF_POSIX_FILE="/tmp/set_posix_${USERNAME}.ldif"
                cat << EOF > $LDIF_POSIX_FILE
dn: $USER_DN_FINAL 
changetype: modify
replace: uidNumber
uidNumber: $NEXT_UID
-
replace: gidNumber
gidNumber: $PRIMARY_LINUX_GID
-
replace: loginShell
loginShell: $DEFAULT_SHELL
-
replace: unixHomeDirectory
unixHomeDirectory: $HOME_DIR_TEMPLATE
EOF
                LDIF_OUTPUT=$(sudo ldbmodify -H "$SAM_LDB" $LDIF_POSIX_FILE 2>&1)
                if [ $? -ne 0 ] || [[ "$LDIF_OUTPUT" == *"Error:"* ]] || [[ "$LDIF_OUTPUT" == *"ERR:"* ]] || [[ "$LDIF_OUTPUT" == *"failed"* ]]; then
                    log_error "Falha ao aplicar atributos POSIX para '$USERNAME'."
                    log_error "Saída do LDB: $LDIF_OUTPUT"
                    rm -f $LDIF_POSIX_FILE
                    read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                    continue
                fi
                rm -f $LDIF_POSIX_FILE
                log_success "Atributos POSIX definidos com sucesso."
            fi
            
            USER_HOME_PATH="$HOME_BASE/$USERNAME"
            log_info "Verificando/Criando diretório home físico em $USER_HOME_PATH..."
            if [ ! -d "$USER_HOME_PATH" ]; then
                sudo mkdir -p "$USER_HOME_PATH"
                if [ $? -ne 0 ]; then
                    log_error "Falha ao criar o diretório $USER_HOME_PATH."
                    read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                    continue
                fi
            else
                log_success "Pasta home já existe."
            fi
            
            QUALIFIED_USERNAME="${WORKGROUP}\\${USERNAME}"
            log_info "Definindo proprietário ($USER_UID:$PRIMARY_LINUX_GROUP) e permissões (2770) para $USER_HOME_PATH..."
            sudo net cache flush 2>/dev/null
            sleep 1 
            
            if ! sudo chown "$QUALIFIED_USERNAME":"${WORKGROUP}\\Domain Users" "$USER_HOME_PATH" 2>/dev/null || ! sudo chmod 700 "$USER_HOME_PATH" 2>/dev/null; then
                log_warning "Falha ao usar '$QUALIFIED_USERNAME'. Tentando com UID numérico '$USER_UID'..."
                if [ -z "$USER_UID" ]; then
                     log_error "Não foi possível determinar o UID para o chown."
                     read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                     continue
                fi
                if ! sudo chown "$USER_UID:$PRIMARY_LINUX_GROUP" "$USER_HOME_PATH" 2>/dev/null; then
                  log_error "Falha ao definir o proprietário/grupo para $USER_HOME_PATH."
                  read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                  continue
                fi
            fi
            
            if ! sudo chmod 2770 "$USER_HOME_PATH" 2>/dev/null; then
                 log_error "Falha ao definir permissões para $USER_HOME_PATH."
                 read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                 continue
            fi
            
            log_success "Permissões do diretório home definidas."

            print_header "RESUMO DO SISTEMA"
            echo -e "  Usuário '$USERNAME' corrigido com sucesso!"
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            ;;

        7)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome de login do usuário a EXCLUIR: ${NC}" USERNAME
            if [ -z "$USERNAME" ]; then
                log_error "Nome de login não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            USER_DN_CHECK=$(func_get_user_dn "$USERNAME")
            if [ -z "$USER_DN_CHECK" ]; then
                log_error "O usuário '$USERNAME' não foi encontrado no domínio."
                log_warning "Ação cancelada."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            print_alert_box "TEM CERTEZA que deseja excluir permanentemente o usuário '$USERNAME' (DN: $USER_DN_CHECK)?\nA pasta home será MANTIDA."
            read -p "  ${FG_YELLOW}${ARROW} Confirmar [s/N]: ${NC}" confirm
            
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                log_warning "Exclusão cancelada."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            print_header "EXCLUINDO USUÁRIO (MANTER HOME): $USERNAME"
            log_info "Excluindo usuário '$USERNAME' do Active Directory..."
            if ! sudo samba-tool user delete "$USERNAME" >/dev/null 2>&1; then
                log_error "Falha ao excluir o usuário '$USERNAME' do AD."
            else
                log_success "Usuário '$USERNAME' excluído do AD com sucesso."
                log_info "A pasta home em $HOME_BASE/$USERNAME foi MANTIDA."
            fi

            print_header "RESUMO DO SISTEMA"
            echo -e "  Operação de exclusão de '$USERNAME' finalizada."
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            ;;
            
        8)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome de login do usuário a EXCLUIR: ${NC}" USERNAME
            if [ -z "$USERNAME" ]; then
                log_error "Nome de login não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            USER_DN_CHECK=$(func_get_user_dn "$USERNAME")
            if [ -z "$USER_DN_CHECK" ]; then
                log_error "O usuário '$USERNAME' não foi encontrado no domínio."
                log_warning "Ação cancelada."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            print_alert_box "TEM CERTEZA que deseja excluir permanentemente o usuário '$USERNAME' (DN: $USER_DN_CHECK)?"
            read -p "  ${FG_YELLOW}${ARROW} Confirmar [s/N]: ${NC}" confirm
            
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                log_warning "Exclusão cancelada."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            print_header "EXCLUINDO USUÁRIO (COM HOME): $USERNAME"
            log_info "Excluindo usuário '$USERNAME' do Active Directory..."
            if ! sudo samba-tool user delete "$USERNAME" >/dev/null 2>&1; then
                log_error "Falha ao excluir o usuário '$USERNAME' do AD."
            else
                log_success "Usuário '$USERNAME' excluído do AD com sucesso."
            fi

            USER_HOME_PATH="$HOME_BASE/$USERNAME"
            if [ -d "$USER_HOME_PATH" ]; then
                log_info "Pasta home encontrada em $USER_HOME_PATH."
                
                print_alert_box "Deseja excluir permanentemente a pasta home $USER_HOME_PATH?"
                read -p "  ${FG_YELLOW}${ARROW} Confirmar [s/N]: ${NC}" confirm_home
                
                if [[ "$confirm_home" == "s" || "$confirm_home" == "S" ]]; then
                    log_info "Excluindo pasta home $USER_HOME_PATH..."
                    if ! sudo rm -rf "$USER_HOME_PATH"; then
                        log_error "Falha ao excluir a pasta $USER_HOME_PATH."
                    else
                        log_success "Pasta home $USER_HOME_PATH excluída com sucesso."
                    fi
                else
                    log_warning "Exclusão da pasta home cancelada."
                fi
            else
                log_success "Nenhuma pasta home encontrada em $USER_HOME_PATH."
            fi

            print_header "RESUMO DO SISTEMA"
            echo -e "  Operação de exclusão de '$USERNAME' finalizada."
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            ;;

        9)
            echo -e "\n  ${FG_CYAN}${BOLD}=== COLETA DE PARÂMETROS ===${NC}"
            read -p "  ${FG_YELLOW}${ARROW} Digite o nome do computador a EXCLUIR (ex: ESTACAO-01): ${NC}" COMP_NAME
            if [ -z "$COMP_NAME" ]; then
                log_error "Nome do computador não pode ser vazio."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi
            
            if [[ "$COMP_NAME" != *\$ ]]; then
                COMP_NAME="${COMP_NAME}\$"
                log_warning "Adicionando '$' ao nome. Nome no AD: $COMP_NAME"
            fi

            print_alert_box "TEM CERTEZA que deseja excluir permanentemente o computador '$COMP_NAME' do domínio?"
            read -p "  ${FG_YELLOW}${ARROW} Confirmar [s/N]: ${NC}" confirm
            
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                log_warning "Exclusão cancelada."
                read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para continuar... ${NC}"
                continue
            fi

            print_header "EXCLUINDO COMPUTADOR: $COMP_NAME"
            log_info "Excluindo computador '$COMP_NAME' do Active Directory..."
            if ! sudo samba-tool computer delete "$COMP_NAME" >/dev/null 2>&1; then
                log_error "Falha ao excluir o computador '$COMP_NAME'. (Ele realmente existe?)"
            else
                log_success "Computador '$COMP_NAME' excluído do AD com sucesso."
            fi

            print_header "RESUMO DO SISTEMA"
            echo -e "  Operação de exclusão de computador finalizada."
            echo -e "  ${DIM}────────────────────────────────────────${NC}"
            ;;

        10)
            log_success "Saindo..."
            break
            ;;

        *)
            log_warning "Opção inválida. Por favor, tente novamente."
            ;;
    esac

    if [ "$choice" != "10" ]; then
        echo ""
        read -r -p "  ${FG_YELLOW}${ARROW} Pressione [Enter] para voltar ao menu... ${NC}"
    fi
done

exit 0
