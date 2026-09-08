#!/bin/bash
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO ZABBIX AGENT 7.0 - UBUNTU 24.04
# ==============================================================================
# Versão: 1.1.0
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh -O install_zabbix7_agent.sh && sudo chmod +x install_zabbix7_agent.sh && sudo ./install_zabbix7_agent.sh
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONSTANTES E CONFIGURAÇÕES GLOBAIS
# ==============================================================================
readonly VERSION="1.1.0"
readonly DEFAULT_HOSTNAME="Cliente_ServBkp"
readonly DEFAULT_SERVER="192.168.1.254"
readonly ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb"
readonly ZABBIX_CONF_DIR="/etc/zabbix"
readonly ZABBIX_CONF_FILE="${ZABBIX_CONF_DIR}/zabbix_agentd.conf"
readonly ZABBIX_LOG_FILE="/var/log/zabbix/zabbix_agentd.log"
readonly ZABBIX_PID_FILE="/var/run/zabbix/zabbix_agentd.pid"

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

# Variáveis de Execução
HOSTNAME_VAL=""
SERVER_VAL=""
CONFIRMAR=""
TMP_DIR=""

# ==============================================================================
# FUNÇÕES DE FORMATAÇÃO E LOGS
# ==============================================================================
draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }

# ==============================================================================
# TRATAMENTO DE LIMPEZA E ERROS
# ==============================================================================
cleanup() {
    local exit_code=$?
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        log_error "Ocorreu uma falha durante a execução (Código de saída: ${exit_code})."
    fi
}
trap cleanup EXIT

# ==============================================================================
# ETAPAS DO PROCESSO
# ==============================================================================
check_privileges() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "Este script requer privilégios de superusuário. Execute como root (sudo)."
        exit 1
    fi
}

check_dependencies() {
    log_info "Verificando dependências básicas..."
    local deps=("wget" "curl")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Instalando dependências ausentes: ${missing[*]}..."
        apt-get update -y >/dev/null 2>&1
        apt-get install -y "${missing[@]}" >/dev/null 2>&1 || {
            log_error "Falha ao instalar dependências (${missing[*]})."
            exit 1
        }
    fi
}

collect_inputs() {
    print_header "COLETA DE PARÂMETROS"

    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o Hostname (Padrão: ${DEFAULT_HOSTNAME}): ${NC}")" input_hostname
    HOSTNAME_VAL="${input_hostname:-$DEFAULT_HOSTNAME}"

    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o IP do Servidor Zabbix (Padrão: ${DEFAULT_SERVER}): ${NC}")" input_server
    SERVER_VAL="${input_server:-$DEFAULT_SERVER}"

    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja aplicar estas configurações ao arquivo final? [S/n]: ${NC}")" input_confirm
    CONFIRMAR="${input_confirm:-S}"

    draw_separator
    log_info "Parâmetros coletados. Iniciando instalação..."
}

setup_repository() {
    print_header "INSTALAÇÃO DO ZABBIX AGENT"
    log_info "Configurando repositório oficial do Zabbix 7.0 LTS..."

    TMP_DIR="$(mktemp -d)"
    local deb_package="${TMP_DIR}/zabbix-release.deb"

    if wget -q "$ZABBIX_REPO_URL" -O "$deb_package"; then
        if dpkg -i "$deb_package" >/dev/null 2>&1; then
            log_success "Pacote do repositório Zabbix instalado."
        else
            log_error "Falha ao instalar o pacote do repositório com dpkg."
            exit 1
        fi
    else
        log_error "Falha ao baixar o pacote do repositório em: ${ZABBIX_REPO_URL}"
        exit 1
    fi
}

install_agent() {
    log_info "Atualizando listas de pacotes e instalando zabbix-agent..."
    apt-get update -y >/dev/null 2>&1
    if apt-get install -y zabbix-agent >/dev/null 2>&1; then
        log_success "Zabbix Agent instalado com sucesso."
    else
        log_error "Falha ao instalar o pacote zabbix-agent via apt-get."
        exit 1
    fi

    log_info "Configurando diretórios e permissões do Zabbix..."
    mkdir -p /var/log/zabbix
    mkdir -p /var/run/zabbix
    chown -R zabbix:zabbix /var/log/zabbix
    chown -R zabbix:zabbix /var/run/zabbix
    log_success "Diretórios e permissões aplicados."
}

configure_agent() {
    print_header "CONFIGURAÇÃO DO SERVIÇO"

    if [[ "$CONFIRMAR" =~ ^[Ss]$ ]]; then
        # Backup da configuração original caso exista
        if [[ -f "$ZABBIX_CONF_FILE" ]]; then
            local timestamp
            timestamp="$(date +%Y%m%d_%H%M%S)"
            local backup_file="${ZABBIX_CONF_FILE}.bak.${timestamp}"
            cp "$ZABBIX_CONF_FILE" "$backup_file"
            log_info "Backup da configuração anterior salvo em: ${backup_file}"
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
        log_warning "Configuração customizada pulada pelo usuário. O arquivo existente foi mantido."
    fi
}

configure_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        log_info "UFW detectado. Verificando porta 10050/tcp..."
        if ufw allow 10050/tcp comment 'Zabbix Agent Port' >/dev/null 2>&1; then
            log_success "Regra de firewall (10050/tcp) configurada no UFW."
        else
            log_warning "Não foi possível aplicar a regra no UFW."
        fi
    else
        log_warning "UFW não está instalado ou ativo. Pulando etapa de firewall."
    fi
}

start_service() {
    log_info "Habilitando e reiniciando o serviço zabbix-agent..."
    chown -R zabbix:zabbix /var/run/zabbix

    if systemctl enable zabbix-agent >/dev/null 2>&1 && systemctl restart zabbix-agent >/dev/null 2>&1; then
        log_success "Serviço Zabbix Agent habilitado e iniciado."
    else
        log_error "Falha ao iniciar o serviço zabbix-agent."
        exit 1
    fi
}

show_summary() {
    print_header "RESUMO DO SISTEMA - ZABBIX AGENT v${VERSION}"
    log_success "Processo de instalação e configuração concluído com sucesso!"

    local status
    status="$(systemctl is-active zabbix-agent 2>/dev/null || echo 'inativo')"

    echo -e "\n  ${FG_CYAN}${BOLD}Status do Serviço:${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  ${FG_WHITE}Serviço      : ${NC}zabbix-agent"
    echo -e "  ${FG_WHITE}Status Ativo : ${NC}${status}"
    echo -e "  ${FG_WHITE}Configuração : ${NC}${ZABBIX_CONF_FILE}"

    echo -e "\n  ${FG_CYAN}${BOLD}Logs do Zabbix Agent:${NC}"
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
    echo -e "  ${FG_WHITE}Arquivo de Log : ${NC}${FG_YELLOW}${ZABBIX_LOG_FILE}${NC}"
    echo -e "  ${FG_WHITE}Ver logs       : ${NC}${FG_GREEN}sudo cat ${ZABBIX_LOG_FILE}${NC}"
    echo -e "  ${FG_WHITE}Acompanhar log : ${NC}${FG_GREEN}sudo tail -f ${ZABBIX_LOG_FILE}${NC}"

    echo -e "\n  ${FG_CYAN}${BOLD}Últimas linhas do log:${NC}"
    sleep 2
    if [[ -f "$ZABBIX_LOG_FILE" ]]; then
        tail -n 5 "$ZABBIX_LOG_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (Nenhum log gravado até o momento)"
    else
        echo "    (Arquivo de log ainda não foi gerado)"
    fi

    echo ""
    draw_separator
    echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
}

# ==============================================================================
# PONTO DE ENTRADA PRINCIPAL
# ==============================================================================
main() {
    clear
    check_privileges
    check_dependencies
    collect_inputs
    setup_repository
    install_agent
    configure_agent
    configure_firewall
    start_service
    show_summary
}

main "$@"
