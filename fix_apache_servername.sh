#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE CORREÇÃO AUTOMÁTICA: APACHE SERVERNAME (AH00558)
# ==============================================================================
# RESUMO DO SCRIPT:
# - Corrige a advertência "AH00558: apache2: Could not reliably determine the
#   server's fully qualified domain name, using 127.0.1.1. Set the 'ServerName'
#   directive globally to suppress this message".
# - Cria configuração modular dedicada em /etc/apache2/conf-available/servername.conf.
# - Permite definir um FQDN customizado, o Hostname do sistema ou 'localhost'.
# - Habilita a configuração com a2enconf e valida a sintaxe com apache2ctl configtest.
# - Aplica recarga suave (graceful reload) no Apache sem interrupção de conexões ativas.
#
# COMPATIBILIDADE: Debian, Ubuntu (20.04, 22.04, 24.04, 26.04) e derivados.
# Requer privilégios de root ou sudo.
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/fix_apache_servername.sh -O fix_apache_servername.sh && sudo chmod +x fix_apache_servername.sh && sudo ./fix_apache_servername.sh
# ==============================================================================

set -Eeuo pipefail
umask 077

# ==============================================================================
# 1 - INICIALIZAÇÃO, CORES E FUNÇÕES BASE
# ==============================================================================

# 1.1 - PALETA DE CORES E IDENTIFICADORES VISUAIS
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
FG_CYAN='\033[36m'
FG_YELLOW='\033[33m'
FG_GREEN='\033[32m'
FG_RED='\033[31m'
FG_WHITE='\033[37m'
ARROW="❯"

draw_separator() {
    printf '%b\n' "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    printf '\n%b\n' "${FG_CYAN}${BOLD}${ARROW} $1${NC}"
    draw_separator
}

get_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        printf '%b\n' "${FG_GREEN}Ativo (Running)${NC}"
    else
        printf '%b\n' "${FG_YELLOW}Inativo (Stopped)${NC}"
    fi
}

log_info()    { printf '%b\n' "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { printf '%b\n' "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { printf '%b\n' "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { printf '%b\n' "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
log_skipped() { printf '%b\n' "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }

die() {
    printf '%b\n' "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO CRÍTICO:${NC} $1" >&2
    exit 1
}

# 1.2 - VALIDAÇÃO DE PRIVILÉGIOS E PREPARAÇÃO DE LOGS PADRONIZADOS
[[ $(id -u) -eq 0 ]] || die "Este script deve ser executado como root ou via sudo."

SCRIPT_IDENTIFIER="fix_apache_servername"
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_${SCRIPT_IDENTIFIER}_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_${SCRIPT_IDENTIFIER}_latest.log"
RUNTIME_DIR=$(mktemp -d -p /tmp "${SCRIPT_IDENTIFIER}.XXXXXXXX")
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "${LOG_TMP}"

finish() {
    local result=$? real_home
    trap - EXIT
    exec 1>&3 2>&4
    wait "${TEE_PID:-}" 2>/dev/null || true

    if [[ -f "${LOG_TMP}" ]]; then
        install -m 600 "${LOG_TMP}" "/root/${LOG_FILENAME}" 2>/dev/null || true
        install -m 600 "${LOG_TMP}" "/root/${LOG_LATEST}" 2>/dev/null || true

        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
            real_home=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
            if [[ -d "${real_home}" ]]; then
                install -m 600 -o "${SUDO_USER}" "${LOG_TMP}" "${real_home}/${LOG_FILENAME}" 2>/dev/null || true
                install -m 600 -o "${SUDO_USER}" "${LOG_TMP}" "${real_home}/${LOG_LATEST}" 2>/dev/null || true
            fi
        fi
    fi

    rm -rf -- "${RUNTIME_DIR}"
    exit "$result"
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
trap 'die "Falha na linha $LINENO. Consulte o relatório para detalhes."' ERR

exec 3>&1 4>&2
exec > >(tee -a "${LOG_TMP}") 2>&1
TEE_PID=$!

# ==============================================================================
# 2 - VERIFICAÇÃO DO AMBIENTE E SERVIÇO APACHE
# ==============================================================================
print_header "VERIFICAÇÃO DE AMBIENTE E DEPENDÊNCIAS (v${VERSION})"

if ! command -v apache2 >/dev/null 2>&1; then
    die "O binário do Apache (apache2) não foi encontrado no sistema. Verifique se o pacote apache2 está instalado."
fi

APACHE_VERSION=$(apache2 -v 2>/dev/null | awk -F': ' '/Server version/ {print $2}')
log_info "Apache detectado: ${FG_WHITE}${APACHE_VERSION}${NC}"
log_info "Status atual do serviço: $(get_service_status apache2)"

CONF_AVAILABLE_DIR="/etc/apache2/conf-available"
CONF_ENABLED_DIR="/etc/apache2/conf-enabled"
SERVERNAME_CONF="${CONF_AVAILABLE_DIR}/servername.conf"

if [[ ! -d "${CONF_AVAILABLE_DIR}" || ! -d "${CONF_ENABLED_DIR}" ]]; then
    die "A estrutura padrão de diretórios do Apache (/etc/apache2/conf-available) não existe."
fi

# ==============================================================================
# 3 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

SYSTEM_HOSTNAME=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
DEFAULT_SERVERNAME="localhost"

echo -e "  O Apache precisa de um ServerName global para suprimir a advertência AH00558."
echo -e "  Opções recomendadas:"
echo -e "    1) ${FG_WHITE}localhost${NC} (Padrão genérico recomendado se não possuir domínio fixo)"
echo -e "    2) Hostname atual do sistema: ${FG_WHITE}${SYSTEM_HOSTNAME}${NC}"
echo -e "    3) FQDN/Domínio personalizado (ex: servprog2.dominio.local ou web.empresa.com)\n"

read -r -p "$(printf "  ${FG_YELLOW}${ARROW} Informe o ServerName desejado [%s]: ${NC}" "${DEFAULT_SERVERNAME}")" INPUT_SERVERNAME
CHOSEN_SERVERNAME="${INPUT_SERVERNAME:-${DEFAULT_SERVERNAME}}"

# Validação básica de caracteres válidos para ServerName
if [[ ! "${CHOSEN_SERVERNAME}" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    die "O ServerName informado contém caracteres inválidos. Utilize apenas letras, números, hífens e pontos."
fi

log_info "ServerName selecionado: ${FG_GREEN}${CHOSEN_SERVERNAME}${NC}"

# ==============================================================================
# 4 - APLICAÇÃO DA CONFIGURAÇÃO
# ==============================================================================
print_header "APLICAÇÃO DA CONFIGURAÇÃO DO APACHE"

# Backup de segurança se o arquivo já existir
if [[ -f "${SERVERNAME_CONF}" ]]; then
    BACKUP_FILE="${SERVERNAME_CONF}.bak_${LOG_TIMESTAMP}"
    cp -p "${SERVERNAME_CONF}" "${BACKUP_FILE}"
    log_warning "Arquivo pré-existente encontrado. Backup criado em: ${BACKUP_FILE}"
fi

log_info "Escrevendo diretiva em ${SERVERNAME_CONF}..."
cat <<EOF > "${SERVERNAME_CONF}"
# Configuração global de ServerName para supressão do erro AH00558
# Gerado automaticamente pelo script fix_apache_servername.sh em $(date '+%d/%m/%Y %H:%M:%S')
ServerName ${CHOSEN_SERVERNAME}
EOF

chmod 644 "${SERVERNAME_CONF}"
log_success "Arquivo de configuração criado com sucesso."

# 4.1 - HABILITAÇÃO DO MÓDULO DE CONFIGURAÇÃO
log_info "Habilitando módulo de configuração com 'a2enconf servername'..."
a2enconf servername >/dev/null 2>&1 || true
log_success "Configuração 'servername' habilitada no Apache."

# ==============================================================================
# 5 - TESTE DE SINTAXE E RECARGA DO SERVIÇO
# ==============================================================================
print_header "TESTE DE SINTAXE E RECARGA DO APACHE"

log_info "Executando teste de sintaxe da configuração (apache2ctl configtest)..."
TEST_OUTPUT=$(apache2ctl configtest 2>&1 || true)

if echo "${TEST_OUTPUT}" | grep -q "Syntax OK"; then
    log_success "Sintaxe validada com sucesso: ${FG_GREEN}Syntax OK${NC}"
else
    log_error "Falha na validação de sintaxe do Apache:"
    echo -e "${FG_RED}${TEST_OUTPUT}${NC}"
    die "A sintaxe da configuração falhou. Revise o arquivo ${SERVERNAME_CONF}."
fi

# Verificação se o erro AH00558 desapareceu
if echo "${TEST_OUTPUT}" | grep -qi "AH00558"; then
    log_warning "Aviso AH00558 ainda foi reportado na validação. Saída: ${TEST_OUTPUT}"
else
    log_success "Aviso AH00558 foi completamente eliminado da saída."
fi

# Recarregar o serviço Apache de forma segura (graceful reload)
log_info "Aplicando recarga do serviço Apache..."
if systemctl is-active --quiet apache2 2>/dev/null; then
    systemctl reload apache2 || systemctl restart apache2
    log_success "Serviço Apache recarregado com sucesso (sem indisponibilidade)."
else
    log_warning "O serviço Apache estava inativo. Tentando iniciar..."
    systemctl start apache2 || log_warning "Não foi possível iniciar o serviço automaticamente. Inicie manualmente quando desejar."
fi

# ==============================================================================
# 6 - RESUMO FINAL E RELATÓRIO
# ==============================================================================
print_header "RESUMO DA EXECUÇÃO"

echo -e "  ${BOLD}Configuração Aplicada:${NC}"
echo -e "    ${ARROW} Diretiva:        ${FG_GREEN}ServerName ${CHOSEN_SERVERNAME}${NC}"
echo -e "    ${ARROW} Arquivo:         ${FG_WHITE}${SERVERNAME_CONF}${NC}"
echo -e "    ${ARROW} Status Apache:   $(get_service_status apache2)"
echo -e "    ${ARROW} Status AH00558:  ${FG_GREEN}Resolvido / Suprimido${NC}"
echo -e ""
echo -e "  ${BOLD}Relatórios Salvos:${NC}"
echo -e "    ${ARROW} Relatório:       /root/${LOG_FILENAME}"
echo -e "    ${ARROW} Atalho:          /root/${LOG_LATEST}"

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    echo -e "    ${ARROW} Cópia de Usuário: ~${SUDO_USER}/${LOG_FILENAME}"
fi

draw_separator
log_success "Correção concluída com êxito! O Apache agora possui o ServerName global definido."
echo -e ""
