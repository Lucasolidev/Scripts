#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E ZABBIX AGENT 7.0 - UBUNTU 24.04
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_zabbix7_agent.sh
# ==============================================================================
# Baixar o script:
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh
# curl -O https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh
#
# Visualizar o script antes de executar:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh
#
# Executar via URL diretamente (exige sudo):
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh | sudo bash
# sudo bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh)
# sudo bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zabbix7_agent.sh | sudo bash
#
# ==============================================================================

# ==========================================
# PALETA DE CORES (ANSI ESCAPE CODES) E FUNÇÕES
# ==========================================
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

FG_CYAN='\033[36m'
FG_YELLOW='\033[33m'
FG_GREEN='\033[32m'
FG_RED='\033[31m'
FG_WHITE='\033[37m'

ARROW="❯"

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
# INÍCIO DO SCRIPT
# ==============================================================================

clear

# Verificar se o script está rodando como root
if [ "$(id -u)" -ne 0 ]; then 
  log_error "Por favor, execute como root (sudo)"
  exit 1
fi

# Configurações padrão
DEFAULT_HOSTNAME="Cliente_ServBkp"
DEFAULT_SERVER="192.168.1.254"

# Se executado via pipe (ex: wget -qO- URL | sudo bash), reconecta o STDIN ao terminal para permitir leitura interativa
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec 0</dev/tty
fi

# ==============================================================================
# BLOCO DE INTERATIVIDADE E COLETAS DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o Hostname (Padrão: $DEFAULT_HOSTNAME): ${NC}")" INPUT_HOSTNAME
HOSTNAME=${INPUT_HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o IP do Servidor Zabbix (Padrão: $DEFAULT_SERVER): ${NC}")" INPUT_SERVER
SERVER=${INPUT_SERVER:-$DEFAULT_SERVER}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja aplicar estas configurações ao arquivo final? (s/n): ${NC}")" CONFIRMAR

draw_separator
log_info "Parâmetros coletados. Iniciando instalação..."

# ==============================================================================
# 1. DOWNLOAD E INSTALAÇÃO DO REPOSITÓRIO
# ==============================================================================
print_header "INSTALAÇÃO DO ZABBIX AGENT"
log_info "Configurando repositório Zabbix..."
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
if dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb > /dev/null 2>&1; then
    log_success "Repositório configurado."
else
    log_error "Falha ao configurar o repositório Zabbix."
fi

log_info "Atualizando pacotes e instalando Zabbix Agent..."
apt update -y > /dev/null 2>&1
if apt install -y zabbix-agent > /dev/null 2>&1; then
    log_success "Zabbix Agent instalado."
else
    log_error "Falha ao instalar o Zabbix Agent."
fi

log_info "Configurando permissões e diretórios..."
mkdir -p /var/log/zabbix
mkdir -p /var/run/zabbix
chown -R zabbix:zabbix /var/log/zabbix
chown -R zabbix:zabbix /var/run/zabbix
log_success "Diretórios configurados."

# ==============================================================================
# 3. CONFIGURAÇÃO DO ARQUIVO ZABBIX_AGENTD.CONF
# ==============================================================================
print_header "CONFIGURAÇÃO DO SERVIÇO"
if [[ "$CONFIRMAR" =~ ^[Ss]$ ]]; then
    log_info "Aplicando arquivo de configurações customizadas..."
    cat <<EOF > /etc/zabbix/zabbix_agentd.conf
### Agente Zabbix ###

Hostname=$HOSTNAME
Server=$SERVER
ServerActive=$SERVER

ListenPort=10050
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=2
DebugLevel=3
Timeout=30

# Endereco IP WAN
UserParameter=net.ipaddress,curl -s -L -k http://www.geset.com.br/suporte/ip.php
EOF
    log_success "Configurações aplicadas com sucesso."
else
    log_warning "Configuração automática pulada. Ajuste manualmente."
fi

# ==============================================================================
# 4. CONFIGURAR REGRAS DE FIREWALL (UFW)
# ==============================================================================
if command -v ufw >/dev/null 2>&1; then
  log_info "Configurando regra no UFW..."
  if ufw allow 10050/tcp comment 'Zabbix Agent Port' > /dev/null 2>&1; then
      log_success "Regra 10050/tcp (Zabbix) configurada."
  fi
else
  log_warning "UFW não encontrado. Pulando firewall."
fi

# ==============================================================================
# 5. HABILITAR E INICIAR O SERVIÇO
# ==============================================================================
log_info "Reiniciando serviço Zabbix Agent..."
chown -R zabbix:zabbix /var/run/zabbix
if systemctl enable zabbix-agent > /dev/null 2>&1 && systemctl restart zabbix-agent > /dev/null 2>&1; then
    log_success "Zabbix Agent reiniciado e habilitado."
else
    log_error "Falha ao reiniciar o serviço Zabbix Agent."
fi

# ==============================================================================
# OUTCOME VISUAL FINAL
# ==============================================================================
print_header "RESUMO DO SISTEMA"
log_success "Instalação do Zabbix Agent concluída com sucesso!"

echo -e "\n  ${FG_CYAN}${BOLD}Status do Serviço:${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"
echo -e "  ${FG_WHITE}Zabbix Agent : ${NC}$(systemctl is-active zabbix-agent 2>/dev/null)"
echo -e "  ${FG_WHITE}Log Recente  : ${NC}"
sleep 3
tail -n 5 /var/log/zabbix/zabbix_agentd.log 2>/dev/null | sed 's/^/    /' || echo "    (Sem logs gerados no momento)"

echo ""
draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
