#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
# ==============================================================================
# SCRIPT DE GERENCIAMENTO DE BACKUP VEEAM SERVER S3 - USUÁRIOS E COTAS XFS
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/gerencia_backup_veeam_server_s3.sh -O gerencia_backup_veeam_server_s3.sh && sudo chmod +x gerencia_backup_veeam_server_s3.sh && sudo ./gerencia_backup_veeam_server_s3.sh
# ==============================================================================

set -Eeuo pipefail
umask 077

# ==============================================================================
# 1 - INICIALIZAÇÃO E FUNÇÕES BASE
# ==============================================================================

# 1.1 - PALETA DE CORES E ESTILOS (ANSI)
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

readonly FG_CYAN='\033[36m'
readonly FG_YELLOW='\033[33m'
readonly FG_GREEN='\033[32m'
readonly FG_RED='\033[31m'
readonly FG_WHITE='\033[37m'

readonly ARROW="❯"

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}${ARROW} ${title}${NC}"
    draw_separator
}

get_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${FG_GREEN}Ativo${NC}"
    else
        echo -e "${FG_YELLOW}Inativo${NC}"
    fi
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
log_skipped() { echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# 1.2 - VALIDAÇÃO DE PRIVILÉGIOS E INICIALIZAÇÃO DE LOG
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\n  ${FG_RED}${BOLD}[x] ERRO:${NC} Este script precisa ser executado como root (use sudo).\n"
    exit 1
fi

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_gerencia_backup_veeam_s3_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_gerencia_backup_veeam_s3_latest.log"

RUNTIME_DIR=$(mktemp -d -p /tmp veeam_backup.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

salvar_logs_finais() {
    cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
    cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
    chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true

    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -d "$REAL_USER_HOME" ]; then
            cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
            cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
            chmod 600 "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
            chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        fi
    fi
    rm -rf -- "$RUNTIME_DIR"
}
trap salvar_logs_finais EXIT INT TERM HUP

exec > >(tee -a "$LOG_TMP") 2>&1

DIRETORIO_BASE="/arquivos"

# ==============================================================================
# 2 - FUNÇÕES OPERACIONAIS
# ==============================================================================

criar_usuario() {
    print_header "COLETA DE PARÂMETROS - CRIAR USUÁRIO"

    read -r -p "  ${FG_YELLOW}${ARROW} Nome do usuário de backup (ex: pastoral): ${NC}" USUARIO
    read -r -s -p "  ${FG_YELLOW}${ARROW} Senha para o usuário de backup: ${NC}" SENHA
    echo ""
    read -r -p "  ${FG_YELLOW}${ARROW} Cota Soft (ex: 3700g): ${NC}" COTA_SOFT
    read -r -p "  ${FG_YELLOW}${ARROW} Cota Hard (ex: 4t): ${NC}" COTA_HARD

    if [ -z "$USUARIO" ] || [ -z "$COTA_SOFT" ] || [ -z "$COTA_HARD" ] || [ -z "$SENHA" ]; then
        log_error "Todos os parâmetros (incluindo a senha) são obrigatórios."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    print_header "CONFIGURAÇÃO DE USUÁRIO E PASTA"

    log_info "Verificando grupo 'Veeam'..."
    if ! getent group Veeam > /dev/null 2>&1; then
        if groupadd Veeam > /dev/null 2>&1; then
            log_success "Grupo 'Veeam' criado."
        else
            log_error "Falha ao criar o grupo 'Veeam'."
            return
        fi
    fi

    log_info "Verificando usuário '$USUARIO'..."
    if id "$USUARIO" &>/dev/null; then
        log_warning "O usuário '$USUARIO' já existe. Pulando criação."
    else
        if useradd -m -s /bin/bash -G Veeam,sudo "$USUARIO" > /dev/null 2>&1; then
            log_success "Usuário '$USUARIO' criado e associado aos grupos 'Veeam' e 'sudo'."
            echo "$USUARIO:$SENHA" | chpasswd
            log_success "Senha definida com segurança para '$USUARIO'."
        else
            log_error "Falha ao criar o usuário '$USUARIO'."
            return
        fi
    fi

    log_info "Verificando diretório $DIRETORIO_USUARIO..."
    if [ ! -d "$DIRETORIO_USUARIO" ]; then
        if mkdir -p "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
            log_success "Diretório $DIRETORIO_USUARIO criado."
        else
            log_error "Falha ao criar o diretório $DIRETORIO_USUARIO."
            return
        fi
    else
        log_warning "Diretório $DIRETORIO_USUARIO já existe."
    fi

    log_info "Ajustando permissões exclusivas (700)..."
    if chown -R "$USUARIO:$USUARIO" "$DIRETORIO_USUARIO" > /dev/null 2>&1 && chmod 700 "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
        log_success "Permissões aplicadas (Proprietário: $USUARIO, Modo: 700)."
    else
        log_error "Falha ao ajustar permissões."
        return
    fi

    log_info "Configurando cota XFS para '$USUARIO'..."
    if xfs_quota -x -c "limit bsoft=${COTA_SOFT} bhard=${COTA_HARD} ${USUARIO}" "$DIRETORIO_BASE" > /dev/null 2>&1; then
        log_success "Cota XFS configurada (Soft: $COTA_SOFT, Hard: $COTA_HARD)."
    else
        log_warning "Falha ao configurar a cota XFS. Verifique se o diretório base suporta quota."
    fi

    print_header "RESUMO DO USUÁRIO CRIADO"
    echo -e "  ${BOLD}Usuário:${NC}           ${FG_GREEN}${USUARIO}${NC}"
    echo -e "  ${BOLD}Diretório:${NC}         ${FG_CYAN}${DIRETORIO_USUARIO}${NC}"
    echo -e "  ${BOLD}Cota Soft:${NC}         ${FG_WHITE}${COTA_SOFT}${NC}"
    echo -e "  ${BOLD}Cota Hard:${NC}         ${FG_WHITE}${COTA_HARD}${NC}"
    echo -e "  ${BOLD}Versão do Script:${NC}  ${FG_WHITE}${VERSION}${NC}"
    
    print_alert_box "Após a conclusão do primeiro backup full pelo Veeam, remova o usuário do grupo SUDO por segurança."

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read -r
}

excluir_usuario() {
    print_header "EXCLUIR USUÁRIO"

    read -r -p "  ${FG_YELLOW}${ARROW} Nome do usuário a ser excluído: ${NC}" USUARIO

    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    read -r -p "  ${FG_RED}${ARROW} TEM CERTEZA que deseja excluir o usuário '$USUARIO'? (s/N): ${NC}" CONFIRMA_USER
    if [[ "$CONFIRMA_USER" =~ ^[Ss]$ ]]; then
        read -r -p "  ${FG_RED}${ARROW} Deseja excluir também a home padrão (/home/$USUARIO)? (s/N): ${NC}" CONFIRMA_HOME
        
        log_info "Removendo limites de cota XFS do usuário '$USUARIO'..."
        xfs_quota -x -c "limit bsoft=0 bhard=0 $USUARIO" "$DIRETORIO_BASE" > /dev/null 2>&1 || true

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
        read -r -p "  ${FG_RED}${ARROW} Deseja excluir a pasta de backup ($DIRETORIO_USUARIO)? (s/N): ${NC}" CONFIRMA_PASTA
        if [[ "$CONFIRMA_PASTA" =~ ^[Ss]$ ]]; then
            log_info "Excluindo diretório '$DIRETORIO_USUARIO'..."
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
    read -r
}

ver_cotas() {
    print_header "RELATÓRIO DE COTAS XFS"
    xfs_quota -x -c 'report -h' "$DIRETORIO_BASE" 2>/dev/null || log_warning "Não foi possível emitir relatório de cotas para $DIRETORIO_BASE."
    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read -r
}

modificar_cota() {
    print_header "MODIFICAR COTA"

    read -r -p "  ${FG_YELLOW}${ARROW} Nome do usuário de backup (ex: pastoral): ${NC}" USUARIO
    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    read -r -p "  ${FG_YELLOW}${ARROW} Nova Cota Soft (ex: 3700g): ${NC}" COTA_SOFT
    read -r -p "  ${FG_YELLOW}${ARROW} Nova Cota Hard (ex: 4t): ${NC}" COTA_HARD

    if [ -z "$COTA_SOFT" ] || [ -z "$COTA_HARD" ]; then
        log_error "As cotas são obrigatórias."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    log_info "Configurando nova cota XFS para '$USUARIO'..."
    if xfs_quota -x -c "limit bsoft=${COTA_SOFT} bhard=${COTA_HARD} ${USUARIO}" "$DIRETORIO_BASE" > /dev/null 2>&1; then
        log_success "Cota XFS atualizada (Soft: $COTA_SOFT, Hard: $COTA_HARD)."
    else
        log_error "Falha ao configurar a cota XFS."
    fi

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read -r
}

corrigir_permissao() {
    print_header "CORREÇÃO DE PERMISSÕES"

    read -r -p "  ${FG_YELLOW}${ARROW} Nome do usuário/pasta (ex: pastoral): ${NC}" USUARIO
    if [ -z "$USUARIO" ]; then
        log_error "O nome do usuário não pode ser vazio."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    if ! id "$USUARIO" &>/dev/null; then
        log_error "O usuário '$USUARIO' não existe no sistema."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    DIRETORIO_USUARIO="${DIRETORIO_BASE}/${USUARIO}"

    if [ ! -d "$DIRETORIO_USUARIO" ]; then
        log_error "O diretório $DIRETORIO_USUARIO não existe."
        echo -e "\nPressione [ENTER] para voltar ao menu..."
        read -r
        return
    fi

    log_info "Ajustando dono e permissões recursivas na pasta '$DIRETORIO_USUARIO'..."
    if chown -R "$USUARIO:$USUARIO" "$DIRETORIO_USUARIO" > /dev/null 2>&1 && chmod 700 "$DIRETORIO_USUARIO" > /dev/null 2>&1; then
        log_success "Permissões corrigidas (Proprietário: $USUARIO, Modo: 700) para $DIRETORIO_USUARIO."
    else
        log_error "Falha ao corrigir permissões."
    fi

    echo -e "\nPressione [ENTER] para voltar ao menu..."
    read -r
}

# ==============================================================================
# 3 - MENU PRINCIPAL
# ==============================================================================

while true; do
    clear
    print_header "MENU PRINCIPAL - GERENCIADOR DE BACKUP VEEAM S3"
    echo -e "  ${FG_WHITE}${BOLD}1.${NC} Criar usuário, pasta e cota"
    echo -e "  ${FG_WHITE}${BOLD}2.${NC} Excluir usuário (e opcionalmente a pasta)"
    echo -e "  ${FG_WHITE}${BOLD}3.${NC} Ver cotas atuais"
    echo -e "  ${FG_WHITE}${BOLD}4.${NC} Modificar cota de um usuário"
    echo -e "  ${FG_WHITE}${BOLD}5.${NC} Corrigir permissão da pasta do usuário"
    echo -e "  ${FG_WHITE}${BOLD}0.${NC} Sair"
    echo -e ""
    
    read -r -p "  ${FG_YELLOW}${ARROW} Escolha uma opção [0-5]: ${NC}" OPCAO
    
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
            log_success "Encerrando sessão do gerenciador..."
            break
            ;;
        *)
            log_error "Opção inválida."
            sleep 1
            ;;
    esac
done

print_header "ARQUIVOS DE LOG DA SESSÃO"
log_success "Relatório de ações gravado em: /root/${LOG_FILENAME}"
draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
