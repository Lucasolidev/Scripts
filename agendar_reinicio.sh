#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE AGENDAMENTO DE REINÍCIO DO SISTEMA - LINUX
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/agendar_reinicio.sh -O agendar_reinicio.sh && sudo chmod +x agendar_reinicio.sh && sudo ./agendar_reinicio.sh
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
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
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

if ! command -v shutdown > /dev/null 2>&1; then
    echo -e "\n  ${FG_RED}${BOLD}[x] ERRO:${NC} Comando 'shutdown' não encontrado no sistema.\n"
    exit 1
fi

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_agendar_reinicio_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_agendar_reinicio_latest.log"

RUNTIME_DIR=$(mktemp -d -p /tmp agendar_reinicio.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP

exec > >(tee -a "$LOG_TMP") 2>&1

# ==============================================================================
# 2 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

HORA_ALVO=""
while [ -z "$HORA_ALVO" ]; do
    read -r -p "  ${FG_YELLOW}${ARROW} Digite o horário de reinício (formato HH:MM, ex: 23:30): ${NC}" ENTRADA_HORA
    ENTRADA_HORA=$(echo "$ENTRADA_HORA" | xargs)

    if [[ "$ENTRADA_HORA" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        HORA_ALVO="$ENTRADA_HORA"
        log_info "Horário definido para o reinício: ${FG_GREEN}${HORA_ALVO}${NC}"
    else
        log_warning "Formato inválido. Utilize estritamente o formato HH:MM (ex: 02:00, 23:30)."
    fi
done

# ==============================================================================
# 3 - EXECUÇÃO DO AGENDAMENTO
# ==============================================================================
print_header "AGENDAMENTO DO REINÍCIO"

log_info "Cancelando agendamentos prévios de shutdown (se existentes)..."
shutdown -c > /dev/null 2>&1 || true

log_info "Agendando reinício do sistema para às ${BOLD}${HORA_ALVO}${NC}..."
shutdown -r "$HORA_ALVO" "Reinicio programado pelo administrador para as $HORA_ALVO." > /dev/null 2>&1

log_success "Reinício agendado com sucesso para às ${HORA_ALVO}."
print_alert_box "Para CANCELAR este reinício a qualquer momento, execute: sudo shutdown -c"

# ==============================================================================
# 4 - RESUMO DA EXECUÇÃO
# ==============================================================================
print_header "RESUMO DA EXECUÇÃO"

echo -e "  ${FG_GREEN}${BOLD}✔ AGENDAMENTO CONCLUÍDO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Agendamento:${NC} ${FG_GREEN}Ativo no Sistema${NC}"
echo -e "  ${BOLD}Horário Programado:${NC}    ${FG_CYAN}${HORA_ALVO}${NC}"
echo -e "  ${BOLD}Comando de Cancelar:${NC}   ${FG_YELLOW}sudo shutdown -c${NC}"
echo -e "  ${BOLD}Versão do Script:${NC}      ${FG_WHITE}${VERSION}${NC}"
echo -e "  ${BOLD}Log de Execução:${NC}       ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 5 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG
# ==============================================================================
print_header "ARQUIVOS DE LOG DA EXECUÇÃO"

cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chmod 600 "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
    fi
fi

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
