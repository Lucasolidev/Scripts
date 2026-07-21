#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# Execução recomendada via repositório: lucasolidev gerencia_backup_veeam.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/gerencia_backup_veeam.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/gerencia_backup_veeam.sh
#
# Executar via URL
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/gerencia_backup_veeam.sh
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/gerencia_backup_veeam.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/gerencia_backup_veeam.sh | bash
#
# ==============================================================================
# ==============================================================================
# SCRIPT: gerencia_backup_veeam.sh
# DESCRIÇÃO: Este script provê um menu interativo para gerenciar usuários,
#            pastas e cotas de disco (XFS) focados no serviço de cópia de
#            backups do Veeam.
#
# FUNCIONALIDADES:
#   1. Criação de usuários específicos (atrelados ao grupo 'Veeam').
#   2. Criação automática de pastas de destino com permissões exclusivas (700).
#   3. Definição e modificação de cotas de disco (Soft e Hard) utilizando XFS.
#   4. Exclusão de usuários e, opcionalmente, de seus dados de backup.
#   5. Visualização rápida do relatório de cotas no sistema de arquivos.
#   6. Correção de permissões recursivas nas pastas de backup.
# ==============================================================================

# ==============================================================================
# Paleta de Cores e Estilos (ANSI)
# ==============================================================================
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

FG_CYAN='\033[36m'
FG_YELLOW='\033[33m'
FG_GREEN='\033[32m'
FG_RED='\033[31m'
FG_WHITE='\033[37m'
ARROW="❯"

# ==============================================================================
# Funções Auxiliares de Visual
# ==============================================================================
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

# ==============================================================================
# Verificação de Permissões
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
  log_error "Este script precisa ser executado como root (use sudo)."
  exit 1
fi

DIRETORIO_BASE="/arquivos"

# ==============================================================================
# FUNÇÕES PRINCIPAIS
# ==============================================================================

criar_usuario() {
    print_header "COLETA DE PARÂMETROS - CRIAR USUÁRIO"

    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do usuário de backup (ex: pastoral): ${NC}")" USUARIO
    read -s -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha para o usuário de backup: ${NC}")" SENHA
    echo ""
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Cota Soft (ex: 3700g): ${NC}")" COTA_SOFT
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Cota Hard (ex: 4t): ${NC}")" COTA_HARD

    if [ -z "$USUARIO" ] || [ -z "$COTA_SOFT" ] || [ -z "$COTA_HARD" ] || [ -z "$SENHA" ]; then
        log_error "Todos os parâmetros (incluindo a senha) são obrigatórios."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    print_header "INICIANDO CONFIGURAÇÃO"

    # 1. Criação do grupo Veeam
    log_info "Verificando grupo 'Veeam'..."
    if ! getent group Veeam > /dev/null 2>&1; then
        if groupadd Veeam > /dev/null 2>&1; then
            log_success "Grupo 'Veeam' criado."
        else
            log_error "Falha ao criar o grupo 'Veeam'."
            exit 1
        fi
    fi

    # 2. Criação do usuário
    log_info "Verificando usuário '$USUARIO'..."
    if id "$USUARIO" &>/dev/null; then
        log_warning "O usuário '$USUARIO' já existe. Pulando criação."
    else
        if useradd -m -s /bin/bash -G Veeam,sudo "$USUARIO" > /dev/null 2>&1; then
            log_success "Usuário '$USUARIO' criado e adicionado aos grupos 'Veeam' e 'sudo'."
            echo "$USUARIO:$SENHA" | chpasswd
            log_success "Senha definida para o usuário '$USUARIO'."
        else
            log_error "Falha ao criar o usuário '$USUARIO'."
            exit 1
        fi
    fi

    # 3. Criação do diretório
    log_info "Verificando diretório $DIRETORIO_USUARIO..."
    if [ ! -d "$DIRETORIO_USUARIO" ]; then
        if mkdir -p "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
            log_success "Diretório $DIRETORIO_USUARIO criado."
        else
            log_error "Falha ao criar o diretório $DIRETORIO_USUARIO."
            exit 1
        fi
    else
        log_warning "Diretório $DIRETORIO_USUARIO já existe."
    fi

    # 4. Ajuste de permissões
    log_info "Ajustando permissões da pasta..."
    if chown -R "$USUARIO:$USUARIO" "$DIRETORIO_USUARIO" > /dev/null 2>&1 && chmod 700 "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
        log_success "Permissões aplicadas (Proprietário: $USUARIO, Permissão: 700)."
    else
        log_error "Falha ao ajustar permissões."
        exit 1
    fi

    # 5. Configuração de cota XFS
    log_info "Configurando cota XFS para '$USUARIO'..."
    if xfs_quota -x -c "limit bsoft=${COTA_SOFT} bhard=${COTA_HARD} ${USUARIO}" "$DIRETORIO_BASE" > /dev/null 2>&1; then
        log_success "Cota XFS configurada (Soft: $COTA_SOFT, Hard: $COTA_HARD)."
    else
        log_error "Falha ao configurar a cota XFS. Verifique se o diretório base suporta quota."
    fi

    print_header "RESUMO DO SISTEMA"
    echo -e "  Usuário:           ${FG_WHITE}${BOLD}${USUARIO}${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Diretório:         ${FG_WHITE}${BOLD}${DIRETORIO_USUARIO}${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Cota Soft:         ${FG_WHITE}${BOLD}${COTA_SOFT}${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  Cota Hard:         ${FG_WHITE}${BOLD}${COTA_HARD}${NC}"
    echo -e ""
    
    print_alert_box "Usuario no grupo SUDO e Veeam, após finalizar a implantação e realizar o primeiro backup full remover o usuário do grupo SUDO. Após o Veeam criar o primeiro backup ajustar permissão dos arquivos dentro da pasta."

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read
}

excluir_usuario() {
    print_header "EXCLUIR USUÁRIO"

    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do usuário a ser excluído: ${NC}")" USUARIO

    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    read -p "$(echo -e "  ${FG_RED}${ARROW} TEM CERTEZA que deseja excluir o usuário '$USUARIO'? (s/n): ${NC}")" CONFIRMA_USER
    if [[ "$CONFIRMA_USER" =~ ^[Ss]$ ]]; then
        read -p "$(echo -e "  ${FG_RED}${ARROW} Deseja excluir também o diretório HOME padrão do usuário (ex: /home/$USUARIO)? (s/n): ${NC}")" CONFIRMA_HOME
        
        log_info "Removendo limites de cota XFS do usuário '$USUARIO'..."
        xfs_quota -x -c "limit bsoft=0 bhard=0 $USUARIO" "$DIRETORIO_BASE" > /dev/null 2>&1

        log_info "Excluindo usuário '$USUARIO'..."
        if [[ "$CONFIRMA_HOME" =~ ^[Ss]$ ]]; then
            DEL_CMD="userdel -r"
        else
            DEL_CMD="userdel"
        fi

        if $DEL_CMD "$USUARIO" > /dev/null 2>&1; then
            log_success "Usuário '$USUARIO' excluído com sucesso."
        else
            log_error "Falha ao excluir o usuário '$USUARIO'."
        fi
    else
        log_warning "Operação de exclusão de usuário cancelada."
    fi

    if [ -d "$DIRETORIO_USUARIO" ]; then
        echo ""
        read -p "$(echo -e "  ${FG_RED}${ARROW} Deseja excluir TODA a pasta de backup ($DIRETORIO_USUARIO)? ISSO APAGARÁ TODOS OS DADOS! (s/n): ${NC}")" CONFIRMA_PASTA
        if [[ "$CONFIRMA_PASTA" =~ ^[Ss]$ ]]; then
            log_info "Excluindo diretório '$DIRETORIO_USUARIO' e todo o seu conteúdo..."
            if rm -rf "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
                log_success "Diretório excluído com sucesso."
            else
                log_error "Falha ao excluir o diretório '$DIRETORIO_USUARIO'."
            fi
        else
            log_info "A pasta $DIRETORIO_USUARIO foi mantida."
        fi
    fi

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read
}

ver_cotas() {
    print_header "RELATÓRIO DE COTAS XFS"
    xfs_quota -x -c 'report -h' "$DIRETORIO_BASE"
    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read
}

modificar_cota() {
    print_header "MODIFICAR COTA"

    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do usuário de backup (ex: pastoral): ${NC}")" USUARIO
    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nova Cota Soft (ex: 3700g): ${NC}")" COTA_SOFT
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nova Cota Hard (ex: 4t): ${NC}")" COTA_HARD

    if [ -z "$COTA_SOFT" ] || [ -z "$COTA_HARD" ]; then
        log_error "As cotas são obrigatórias."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    log_info "Configurando nova cota XFS para '$USUARIO'..."
    if xfs_quota -x -c "limit bsoft=${COTA_SOFT} bhard=${COTA_HARD} ${USUARIO}" "$DIRETORIO_BASE" > /dev/null 2>&1; then
        log_success "Cota XFS atualizada (Soft: $COTA_SOFT, Hard: $COTA_HARD)."
    else
        log_error "Falha ao configurar a cota XFS. Verifique se o diretório base suporta quota."
    fi

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read
}

corrigir_permissao() {
    print_header "CORREÇÃO DE PERMISSÕES"

    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do usuário/pasta (ex: pastoral): ${NC}")" USUARIO
    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe no sistema."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    if [ ! -d "$DIRETORIO_USUARIO" ]; then
        log_error "O diretório $DIRETORIO_USUARIO não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read
        return
    fi

    log_info "Ajustando dono e permissões recursivas na pasta '$DIRETORIO_USUARIO'..."
    if chown -R "$USUARIO:$USUARIO" "$DIRETORIO_USUARIO" > /dev/null 2>&1 && chmod 700 "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
        log_success "Permissões corrigidas (Proprietário: $USUARIO, Permissão: 700) para todo o conteúdo de $DIRETORIO_USUARIO."
    else
        log_error "Falha ao corrigir permissões."
    fi

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

while true; do
    clear
    print_header "MENU PRINCIPAL - CRIAÇÃO E CONTROLE DE COTAS DO BACKUP VEEAM"
    echo -e "  ${FG_WHITE}${BOLD}1.${NC} Criar usuário, pasta e cota"
    echo -e "  ${FG_WHITE}${BOLD}2.${NC} Excluir usuário (e opcionalmente a pasta)"
    echo -e "  ${FG_WHITE}${BOLD}3.${NC} Ver cotas atuais"
    echo -e "  ${FG_WHITE}${BOLD}4.${NC} Modificar cota de um usuário"
    echo -e "  ${FG_WHITE}${BOLD}5.${NC} Corrigir permissão da pasta do usuário"
    echo -e "  ${FG_WHITE}${BOLD}0.${NC} Sair"
    echo -e ""
    
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Escolha uma opção: ${NC}")" OPCAO
    
    case $OPCAO in
        1)
            criar_usuario
            ;;
        2)
            excluir_usuario
            ;;
        3)
            ver_cotas
            ;;
        4)
            modificar_cota
            ;;
        5)
            corrigir_permissao
            ;;
        0)
            log_success "Saindo..."
            exit 0
            ;;
        *)
            log_error "Opção inválida."
            sleep 1
            ;;
    esac
done
