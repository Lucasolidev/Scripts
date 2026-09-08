#!/bin/bash
# ------------------------------------------------
# Version: 1.2
# ------------------------------------------------
VERSION="1.2"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO ZABBIX AGENT 7.0 LTS - UBUNTU 24.04 / 26.04
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh -O install_zabbix7_agent.sh && sudo chmod +x install_zabbix7_agent.sh && sudo ./install_zabbix7_agent.sh
# ==============================================================================

set -Eeuo pipefail

# ==============================================================================
# CONSTANTES E CONFIGURAÇÕES GLOBAIS
# ==============================================================================
readonly DEFAULT_HOSTNAME="Cliente_ServBkp"
readonly DEFAULT_SERVER="192.168.1.254"
readonly ZABBIX_REPO_URL_2404="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb"
readonly ZABBIX_REPO_URL_2604="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu26.04_all.deb"
readonly ZABBIX_CONF_DIR="/etc/zabbix"
readonly ZABBIX_CONF_FILE="${ZABBIX_CONF_DIR}/zabbix_agentd.conf"
readonly ZABBIX_LOG_FILE="/var/log/zabbix/zabbix_agentd.log"
readonly ZABBIX_PID_FILE="/var/run/zabbix/zabbix_agentd.pid"

# ==============================================================================
# 1 - INICIALIZAÇÃO E FUNÇÕES BASE
# ==============================================================================

# 1.1 - FUNÇÕES DE HIGHLIGHT E LOGGING
# ==============================================================================
# Paleta de Cores e Estilos (ANSI Escape Codes)
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

# Variáveis de Execução
HOSTNAME_VAL=""
SERVER_VAL=""
CONFIRMAR=""
PACOTES_INSTALADOS=()
OS_DISTRO=""
OS_VERSION=""
OS_CODENAME=""
ZABBIX_REPO_URL=""

# ==============================================================================
# 1.2 - VALIDAÇÃO DE PRIVILÉGIOS E INICIALIZAÇÃO DE LOGS PADRONIZADOS
# ==============================================================================
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script requer privilégios de superusuário. Execute como root (sudo)."
    exit 1
fi

# Detecção e Validação do Sistema Operacional (Ubuntu 24.04 ou 26.04)
if [[ -f /etc/os-release ]]; then
    OS_DISTRO=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OS_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
else
    log_error "Não foi possível determinar o sistema operacional (/etc/os-release ausente)."
    exit 1
fi

if [[ "$OS_DISTRO" != "ubuntu" ]]; then
    log_error "Distribuição não suportada: '${OS_DISTRO}'. Este script é exclusivo para Ubuntu."
    exit 1
fi

case "$OS_VERSION" in
    "24.04")
        ZABBIX_REPO_URL="$ZABBIX_REPO_URL_2404"
        ;;
    "26.04")
        ZABBIX_REPO_URL="$ZABBIX_REPO_URL_2604"
        ;;
    *)
        log_error "Versão do Ubuntu não suportada: '${OS_VERSION}' (${OS_CODENAME}). Versões homologadas: 24.04 LTS (Noble) ou 26.04 LTS (Resolute)."
        exit 1
        ;;
esac

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_zabbix7_agent_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_zabbix7_agent_latest.log"
umask 077
RUNTIME_DIR=$(mktemp -d -p /tmp install_zabbix7_agent.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    local exit_code=$?
    rm -rf -- "$RUNTIME_DIR"
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        log_error "Ocorreu uma falha durante a execução (Código de saída: ${exit_code})."
    fi
}
trap cleanup EXIT INT TERM HUP
exec > >(tee -a "$LOG_TMP") 2>&1

# ==============================================================================
# 2 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

log_info "Sistema detectado: ${FG_GREEN}Ubuntu ${OS_VERSION} (${OS_CODENAME})${NC}"

read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o Hostname (Padrão: ${DEFAULT_HOSTNAME}): ${NC}")" input_hostname
HOSTNAME_VAL="${input_hostname:-$DEFAULT_HOSTNAME}"
log_info "Hostname definido: ${FG_GREEN}${HOSTNAME_VAL}${NC}"

read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o IP do Servidor Zabbix (Padrão: ${DEFAULT_SERVER}): ${NC}")" input_server
SERVER_VAL="${input_server:-$DEFAULT_SERVER}"
log_info "Servidor Zabbix definido: ${FG_GREEN}${SERVER_VAL}${NC}"

read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja aplicar estas configurações ao arquivo final? [S/n]: ${NC}")" input_confirm
CONFIRMAR="${input_confirm:-S}"
log_info "Aplicar configurações customizadas: ${FG_GREEN}${CONFIRMAR}${NC}"

draw_separator
log_info "Parâmetros coletados. Iniciando instalação..."

# ==============================================================================
# 3 - VERIFICAÇÃO DE DEPENDÊNCIAS BÁSICAS
# ==============================================================================
print_header "VERIFICAÇÃO DE DEPENDÊNCIAS"
log_info "Verificando dependências essenciais do sistema..."

DEPS=("wget" "curl")
DEPS_TO_INSTALL=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        DEPS_TO_INSTALL+=("$dep")
    fi
done

if [[ ${#DEPS_TO_INSTALL[@]} -gt 0 ]]; then
    log_info "Atualizando índices de pacotes..."
    apt-get update -y >/dev/null 2>&1
    for pkg in "${DEPS_TO_INSTALL[@]}"; do
        log_info "Instalando dependência ${pkg}..."
        if apt-get install -y "$pkg" >/dev/null 2>&1; then
            log_success "Dependência instalada: ${pkg}."
            PACOTES_INSTALADOS+=("$pkg")
        else
            log_error "Falha ao instalar a dependência: ${pkg}."
            exit 1
        fi
    done
else
    log_success "Todas as dependências essenciais já estão presentes."
fi

# ==============================================================================
# 4 - DOWNLOAD E INSTALAÇÃO DO REPOSITÓRIO ZABBIX 7.0
# ==============================================================================
print_header "INSTALAÇÃO DO ZABBIX AGENT"
log_info "Configurando repositório oficial Zabbix 7.0 LTS para Ubuntu ${OS_VERSION} (${OS_CODENAME})..."

DEB_PACKAGE="${RUNTIME_DIR}/zabbix-release.deb"
if wget -q "$ZABBIX_REPO_URL" -O "$DEB_PACKAGE"; then
    if dpkg -i "$DEB_PACKAGE" >/dev/null 2>&1; then
        log_success "Repositório Zabbix 7.0 configurado para Ubuntu ${OS_VERSION}."
        PACOTES_INSTALADOS+=("zabbix-release")
    else
        log_error "Falha ao instalar pacote do repositório Zabbix via dpkg."
        exit 1
    fi
else
    log_error "Falha ao realizar download do repositório Zabbix em: ${ZABBIX_REPO_URL}"
    exit 1
fi

# ==============================================================================
# 5 - INSTALAÇÃO DO PACOTE ZABBIX AGENT
# ==============================================================================
log_info "Atualizando repositórios locais..."
apt-get update -y >/dev/null 2>&1

log_info "Instalando pacote zabbix-agent..."
if apt-get install -y zabbix-agent >/dev/null 2>&1; then
    log_success "Pacote zabbix-agent instalado com sucesso."
    PACOTES_INSTALADOS+=("zabbix-agent")
else
    log_error "Falha na instalação do pacote zabbix-agent."
    exit 1
fi

log_info "Configurando diretórios e permissões do Zabbix..."
mkdir -p /var/log/zabbix
mkdir -p /var/run/zabbix
chown -R zabbix:zabbix /var/log/zabbix
chown -R zabbix:zabbix /var/run/zabbix
log_success "Diretórios e permissões aplicados."

# ==============================================================================
# 6 - CONFIGURAÇÃO DO SERVIÇO ZABBIX AGENT
# ==============================================================================
print_header "CONFIGURAÇÃO DO SERVIÇO"

if [[ "$CONFIRMAR" =~ ^[Ss]$ ]]; then
    if [[ -f "$ZABBIX_CONF_FILE" ]]; then
        BACKUP_FILE="${ZABBIX_CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$ZABBIX_CONF_FILE" "$BACKUP_FILE"
        log_info "Backup da configuração anterior salvo em: ${BACKUP_FILE}"
    fi

    log_info "Gerando arquivo de configuração customizado..."
    cat <<EOF > "$ZABBIX_CONF_FILE"
### Agente Zabbix ###

Hostname=${HOSTNAME_VAL}
Server=${SERVER_VAL}
ServerActive=${SERVER_VAL}

ListenPort=10050
PidFile=${ZABBIX_PID_FILE}
LogFile=${ZABBIX_LOG_FILE}
LogFileSize=2
DebugLevel=3
Timeout=30

# Endereco IP WAN
UserParameter=net.ipaddress,curl -s -L -k http://www.geset.com.br/suporte/ip.php
EOF
    log_success "Configurações aplicadas em ${ZABBIX_CONF_FILE}."
else
    log_warning "Configuração customizada pulada pelo usuário. Arquivo original mantido."
fi

# ==============================================================================
# 7 - CONFIGURAÇÃO DE REGRAS DE FIREWALL (UFW)
# ==============================================================================
if command -v ufw >/dev/null 2>&1; then
    log_info "UFW detectado. Verificando regra para porta 10050/tcp..."
    if ufw allow 10050/tcp comment 'Zabbix Agent Port' >/dev/null 2>&1; then
        log_success "Regra 10050/tcp configurada no UFW."
    else
        log_warning "Não foi possível aplicar regra no UFW."
    fi
else
    log_skipped "UFW não detectado. Etapa de firewall pulada."
fi

# ==============================================================================
# 8 - HABILITAÇÃO E INICIALIZAÇÃO DO SERVIÇO
# ==============================================================================
log_info "Habilitando e reiniciando o serviço zabbix-agent..."
chown -R zabbix:zabbix /var/run/zabbix

if systemctl enable zabbix-agent >/dev/null 2>&1 && systemctl restart zabbix-agent >/dev/null 2>&1; then
    log_success "Zabbix Agent habilitado e iniciado no systemd."
else
    log_error "Falha ao iniciar o serviço zabbix-agent."
    exit 1
fi

# ==============================================================================
# 9 - LIMPEZA DO SISTEMA
# ==============================================================================
log_info "Executando limpeza de pacotes desnecessários..."
apt-get autoremove -y >/dev/null 2>&1 || true
apt-get autoclean -y >/dev/null 2>&1 || true
log_success "Limpeza de pacotes concluída."

# ==============================================================================
# 10 - RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"
echo -e "  ${FG_GREEN}${BOLD}✔ PROCESSO FINALIZADO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Sistema:${NC}     ${FG_GREEN}Operacional${NC}"
echo -e "  ${BOLD}Sistema Operacional:${NC}   ${FG_CYAN}Ubuntu ${OS_VERSION} (${OS_CODENAME})${NC}"
echo -e "  ${BOLD}Versão do Script:${NC}      ${FG_WHITE}v${VERSION}${NC}"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
echo -e "  ${BOLD}Serviço Principal:${NC}     $(get_service_status zabbix-agent)"
echo -e "  ${BOLD}Configuração:${NC}          ${FG_WHITE}${ZABBIX_CONF_FILE}${NC}"
echo -e "  ${BOLD}Log do Serviço:${NC}        ${FG_YELLOW}${ZABBIX_LOG_FILE}${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${FG_CYAN}${BOLD}Comandos Rápidos para Verificação de Logs:${NC}"
echo -e "  ${FG_WHITE}Ver logs do Agent    : ${NC}${FG_GREEN}sudo cat ${ZABBIX_LOG_FILE}${NC}"
echo -e "  ${FG_WHITE}Acompanhar Agent     : ${NC}${FG_GREEN}sudo tail -f ${ZABBIX_LOG_FILE}${NC}"
echo -e "  ${FG_WHITE}Ver log da Instalação: ${NC}${FG_GREEN}sudo cat /root/${LOG_FILENAME}${NC}"

echo -e "\n  ${FG_CYAN}${BOLD}Últimas linhas do log do Zabbix Agent:${NC}"
sleep 2
if [[ -f "$ZABBIX_LOG_FILE" ]]; then
    tail -n 5 "$ZABBIX_LOG_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (Nenhum log gravado até o momento)"
else
    echo "    (Arquivo de log ainda não foi gerado)"
fi

# ==============================================================================
# 11 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

# Salva cópias no diretório /root
cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

# Se executado via sudo, salva também na pasta home do usuário real
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
