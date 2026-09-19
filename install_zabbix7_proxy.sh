#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO ZABBIX PROXY 7.0 LTS - UBUNTU 24.04
# COM SUPORTE A SQLITE3, AGENTE ZABBIX, SNMP E CRIPTOGRAFIA PSK
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_zabbix7_proxy.sh -O install_zabbix7_proxy.sh && sudo chmod +x install_zabbix7_proxy.sh && sudo ./install_zabbix7_proxy.sh
# ==============================================================================

set -Eeuo pipefail
umask 077
export DEBIAN_FRONTEND=noninteractive

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
LOG_FILENAME="relatorio_install_zabbix7_proxy_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_zabbix7_proxy_latest.log"

RUNTIME_DIR=$(mktemp -d -p /tmp install_zabbix_proxy.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP

exec > >(tee -a "$LOG_TMP") 2>&1

PACOTES_INSTALADOS=()

# ==============================================================================
# 2 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

DEFAULT_PROXY_HOSTNAME="Cliente_ZabbixProxy"
read -r -p "  ${FG_YELLOW}${ARROW} Hostname do Proxy [${DEFAULT_PROXY_HOSTNAME}]: ${NC}" PROXY_HOSTNAME
PROXY_HOSTNAME=${PROXY_HOSTNAME:-$DEFAULT_PROXY_HOSTNAME}
log_info "Hostname do Proxy definido: ${FG_GREEN}${PROXY_HOSTNAME}${NC}"

DEFAULT_AGENT_HOSTNAME="Cliente_ServProg"
read -r -p "  ${FG_YELLOW}${ARROW} Hostname do Agente [${DEFAULT_AGENT_HOSTNAME}]: ${NC}" AGENT_HOSTNAME
AGENT_HOSTNAME=${AGENT_HOSTNAME:-$DEFAULT_AGENT_HOSTNAME}
log_info "Hostname do Agente definido: ${FG_GREEN}${AGENT_HOSTNAME}${NC}"

DEFAULT_SERVER_HOST="monitor.geset.com.br"
read -r -p "  ${FG_YELLOW}${ARROW} Servidor Zabbix Server central [${DEFAULT_SERVER_HOST}]: ${NC}" ZBX_SERVER_HOST
ZBX_SERVER_HOST=${ZBX_SERVER_HOST:-$DEFAULT_SERVER_HOST}
log_info "Servidor central definido: ${FG_GREEN}${ZBX_SERVER_HOST}${NC}"

DEFAULT_PROXY_IP="192.168.1.254"
read -r -p "  ${FG_YELLOW}${ARROW} IP do servidor Zabbix/Proxy local [${DEFAULT_PROXY_IP}]: ${NC}" PROXY_IP
PROXY_IP=${PROXY_IP:-$DEFAULT_PROXY_IP}
log_info "IP do Proxy local definido: ${FG_GREEN}${PROXY_IP}${NC}"

# ==============================================================================
# 3 - REPOSITÓRIO OFICIAL E INSTALAÇÃO DE PACOTES
# ==============================================================================
print_header "REPOSITÓRIO E INSTALAÇÃO DE PACOTES"

REPO_DEB="zabbix-release_latest_7.0+ubuntu24.04_all.deb"
REPO_URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/${REPO_DEB}"

log_info "Baixando pacote do repositório oficial Zabbix 7.0 LTS (Ubuntu 24.04)..."
curl -fsSL "$REPO_URL" -o "${RUNTIME_DIR}/${REPO_DEB}"
dpkg -i "${RUNTIME_DIR}/${REPO_DEB}" > /dev/null 2>&1
log_success "Repositório Zabbix 7.0 adicionado."

log_info "Atualizando catálogo de pacotes..."
apt-get update -y > /dev/null 2>&1 || true

DEPENDENCIAS=(
    "zabbix-proxy-sqlite3"
    "zabbix-agent"
    "curl"
    "snmpd"
    "snmp-mibs-downloader"
    "fping"
    "openssl"
    "snmp"
    "sqlite3"
)

for pkg in "${DEPENDENCIAS[@]}"; do
    log_info "Instalando pacote: ${pkg}..."
    if apt-get install -y "$pkg" > /dev/null 2>&1; then
        log_success "Pacote '$pkg' instalado com sucesso."
        PACOTES_INSTALADOS+=("$pkg")
    else
        log_error "Falha na instalação do pacote '$pkg'."
    fi
done

# ==============================================================================
# 4 - PREPARAÇÃO DE DIRETÓRIOS E BANCO DE DADOS
# ==============================================================================
print_header "ESTRUTURA DE DIRETÓRIOS E BANCO DE DADOS (SQLITE3)"

mkdir -p /var/log/zabbix /var/lib/zabbix /var/run/zabbix /etc/zabbix
chown -R zabbix:zabbix /var/log/zabbix /var/lib/zabbix /var/run/zabbix
chmod 775 /var/log/zabbix /var/lib/zabbix /var/run/zabbix

DB_PATH="/var/lib/zabbix/zabbix.db"
if [ ! -f "$DB_PATH" ]; then
    log_info "Populando schema inicial do SQLite3 para o Zabbix Proxy..."
    SCHEMA_PATH="/usr/share/doc/zabbix-proxy-sqlite3/schema.sql.gz"
    if [ -f "$SCHEMA_PATH" ]; then
        zcat "$SCHEMA_PATH" | sqlite3 "$DB_PATH"
        chown zabbix:zabbix "$DB_PATH"
        chmod 660 "$DB_PATH"
        log_success "Banco de dados SQLite inicializado em: $DB_PATH"
    else
        log_warning "Arquivo de schema '$SCHEMA_PATH' não encontrado."
    fi
else
    log_skipped "Banco de dados SQLite já existente em: $DB_PATH"
fi

# ==============================================================================
# 5 - GERAÇÃO DE CHAVE CRIPTOGRÁFICA PSK (SEGURA)
# ==============================================================================
print_header "CHAVE CRIPTOGRÁFICA PSK"

PSK_FILE="/etc/zabbix/zabbix_proxy.psk"
if [ ! -f "$PSK_FILE" ]; then
    log_info "Gerando nova chave PSK de 256 bits..."
    openssl rand -hex 32 > "$PSK_FILE"
    chown zabbix:zabbix "$PSK_FILE"
    chmod 600 "$PSK_FILE"
    log_success "Chave PSK gerada com sucesso e permissões 0600 aplicadas."
else
    log_skipped "Chave PSK já existente em: $PSK_FILE (preservada)."
fi

# ==============================================================================
# 6 - ARQUIVOS DE CONFIGURAÇÃO (PROXY, AGENTE E SNMP)
# ==============================================================================
print_header "CONFIGURAÇÃO DOS SERVIÇOS"

log_info "Configurando /etc/zabbix/zabbix_proxy.conf..."
cat << EOF > /etc/zabbix/zabbix_proxy.conf
Server=$ZBX_SERVER_HOST
Hostname=$PROXY_HOSTNAME
DBName=/var/lib/zabbix/zabbix.db
LogFile=/var/log/zabbix/zabbix_proxy.log
PidFile=/var/run/zabbix/zabbix_proxy.pid
FpingLocation=/usr/bin/fping
ProxyMode=0
LogFileSize=10
DebugLevel=3
CacheSize=2G
DataSenderFrequency=30
ProxyOfflineBuffer=24
ProxyLocalBuffer=4
UnavailableDelay=20
UnreachablePeriod=60
ProxyConfigFrequency=60
HistoryCacheSize=32M
StartIPMIPollers=1
Timeout=5
StartPingers=5
StartDiscoverers=5
StartVMwareCollectors=5
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=$PROXY_HOSTNAME
TLSPSKFile=/etc/zabbix/zabbix_proxy.psk
EOF
chown zabbix:zabbix /etc/zabbix/zabbix_proxy.conf
chmod 640 /etc/zabbix/zabbix_proxy.conf
log_success "Configuração do Zabbix Proxy gravada."

log_info "Configurando /etc/zabbix/zabbix_agentd.conf..."
cat << EOF > /etc/zabbix/zabbix_agentd.conf
Hostname=$AGENT_HOSTNAME
Server=127.0.0.1,$PROXY_IP
ServerActive=127.0.0.1,$PROXY_IP
ListenPort=10050
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=2
DebugLevel=3
Timeout=3
UserParameter=net.ipaddress,curl -s -L -k http://www.geset.com.br/suporte/ip.php
EOF
chown zabbix:zabbix /etc/zabbix/zabbix_agentd.conf
chmod 640 /etc/zabbix/zabbix_agentd.conf
log_success "Configuração do Zabbix Agent gravada."

log_info "Configurando serviço SNMP (/etc/snmp/snmpd.conf)..."
mkdir -p /etc/snmp
echo "mibs :" > /etc/snmp/snmp.conf
cat << 'EOF' > /etc/snmp/snmpd.conf
rocommunity cliente_snmp 127.0.0.1 .1
rocommunity cliente_snmp 192.168.0.0/16 .1
EOF
chmod 640 /etc/snmp/snmpd.conf
log_success "Configuração do SNMP gravada."

# ==============================================================================
# 7 - REGRAS DE FIREWALL (UFW)
# ==============================================================================
print_header "FIREWALL UFW"

if command -v ufw >/dev/null 2>&1; then
    log_info "Aplicando regras para as portas do Zabbix e SNMP..."
    ufw allow 10050/tcp comment 'Zabbix Agent Port' > /dev/null 2>&1 || true
    ufw allow 10051/tcp comment 'Zabbix Proxy Port' > /dev/null 2>&1 || true
    ufw allow 22/tcp comment 'Acesso SSH Remoto' > /dev/null 2>&1 || true
    ufw allow 161/udp comment 'SNMP Polling Port' > /dev/null 2>&1 || true
    ufw allow 1161/udp comment 'SNMP Traps / Custom Port' > /dev/null 2>&1 || true
    log_success "Regras de firewall configuradas com sucesso."
else
    log_skipped "UFW não está instalado neste servidor."
fi

# ==============================================================================
# 8 - HABILITAÇÃO E INICIALIZAÇÃO DE SERVIÇOS
# ==============================================================================
print_header "INICIALIZAÇÃO DOS SERVIÇOS"

SERVICOS=("snmpd" "zabbix-proxy" "zabbix-agent")
for servico in "${SERVICOS[@]}"; do
    log_info "Ativando e iniciando serviço '$servico'..."
    systemctl restart "$servico" > /dev/null 2>&1 || log_warning "Não foi possível reiniciar $servico."
    systemctl enable "$servico" > /dev/null 2>&1 || log_warning "Não foi possível habilitar $servico no boot."
    log_success "Serviço '$servico': $(get_service_status "$servico")"
done

# ==============================================================================
# 9 - RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DO ZABBIX PROXY 7.0 LTS CONCLUÍDA!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Proxy:${NC}       $(get_service_status zabbix-proxy)"
echo -e "  ${BOLD}Status do Agente:${NC}      $(get_service_status zabbix-agent)"
echo -e "  ${BOLD}Status do SNMP:${NC}        $(get_service_status snmpd)"
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
echo -e "  ${BOLD}Proxy Hostname:${NC}        ${FG_GREEN}${PROXY_HOSTNAME}${NC}"
echo -e "  ${BOLD}Identity PSK:${NC}          ${FG_GREEN}${PROXY_HOSTNAME}${NC}"
echo -e "  ${BOLD}Arquivo da Chave PSK:${NC}  ${FG_CYAN}${PSK_FILE}${NC} ${DIM}(Permissão 0600)${NC}"
echo -e "  ${BOLD}Versão do Script:${NC}      ${FG_WHITE}${VERSION}${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

print_alert_box "Para vincular o proxy no Zabbix Server, utilize a Identity '${PROXY_HOSTNAME}' e consulte o arquivo protegido '${PSK_FILE}' como root."

# ==============================================================================
# 10 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

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
