#!/bin/bash
# shellcheck disable=SC2317
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO NUT (NETWORK UPS TOOLS) COM ZABBIX 7.0
# MONITORAMENTO UNIVERSAL DE NOBREAKS VIA USB (UBUNTU SERVER 24.04 / 26.04)
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_nut_ups_zabbix.sh -O install_nut_ups_zabbix.sh && sudo chmod +x install_nut_ups_zabbix.sh && sudo ./install_nut_ups_zabbix.sh
# ==============================================================================

set -Eeuo pipefail

# ==============================================================================
# CONSTANTES E CONFIGURAÇÕES GLOBAIS
# ==============================================================================
readonly DEFAULT_UPS_NAME="Canacampo_Nobreak"
readonly DEFAULT_UPS_DRIVER="usbhid-ups"
readonly DEFAULT_UPS_PORT="auto"
readonly DEFAULT_UPS_DESC="APC Smart-UPS BR 2200VA"
readonly DEFAULT_NOMINAL_POWER="2200"

readonly NUT_CONF_DIR="/etc/nut"
readonly NUT_CONF_FILE="${NUT_CONF_DIR}/nut.conf"
readonly UPS_CONF_FILE="${NUT_CONF_DIR}/ups.conf"
readonly UPSD_CONF_FILE="${NUT_CONF_DIR}/upsd.conf"
readonly UPSD_USERS_FILE="${NUT_CONF_DIR}/upsd.users"
readonly UPSMON_CONF_FILE="${NUT_CONF_DIR}/upsmon.conf"

readonly ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts"
readonly ZABBIX_AGENT_CONF_DIR="/etc/zabbix/zabbix_agentd.d"
readonly ZABBIX_AGENT2_CONF_DIR="/etc/zabbix/zabbix_agent2.d"

# ==============================================================================
# 1 - INICIALIZAÇÃO E FUNÇÕES BASE
# ==============================================================================

# 1.1 - FUNÇÕES DE HIGHLIGHT E LOGGING (Paleta ANSI)
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
UPS_NAME_VAL=""
UPS_DRIVER_VAL=""
UPS_DESC_VAL=""
UPS_POWER_VAL=""
CONFIRMAR=""
PACOTES_INSTALADOS=()
OS_DISTRO=""
OS_VERSION=""
OS_CODENAME=""

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
    "24.04"|"26.04")
        log_info "Sistema homologado detectado: Ubuntu ${OS_VERSION} (${OS_CODENAME})."
        ;;
    *)
        log_error "Versão do Ubuntu não suportada: '${OS_VERSION}' (${OS_CODENAME}). Versões homologadas: 24.04 LTS ou 26.04 LTS."
        exit 1
        ;;
esac

# Inicialização da Captura de Logs Padronizada
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_nut_ups_zabbix_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_nut_ups_zabbix_latest.log"
umask 077
RUNTIME_DIR=$(mktemp -d -p /tmp nut_install.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALAÇÃO E CONFIGURAÇÃO DO NUT COM ZABBIX 7.0 (v${VERSION})"
echo -e "  ${DIM}Iniciando execução em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

# ==============================================================================
# 2 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

# 2.1 - Nome do Nobreak
echo -e "  Defina o identificador do Nobreak no NUT (sem espaços, ex: Canacampo_Nobreak, AMO_Nobreak)."
echo -ne "  ${FG_YELLOW}${ARROW} Nome do Nobreak [${DEFAULT_UPS_NAME}]: ${NC}"
read -r UPS_NAME_INPUT
UPS_NAME_VAL="${UPS_NAME_INPUT:-$DEFAULT_UPS_NAME}"
UPS_NAME_VAL=$(echo "$UPS_NAME_VAL" | tr -cd 'a-zA-Z0-9_-')
if [[ -z "$UPS_NAME_VAL" ]]; then
    UPS_NAME_VAL="$DEFAULT_UPS_NAME"
fi
log_info "Nome do Nobreak definido: ${FG_GREEN}${UPS_NAME_VAL}${NC}"

# 2.2 - Driver do Nobreak
echo -e "\n  ${BOLD}Defina o driver de comunicação do nobreak (NUT Driver):${NC}"
echo -e "    ${FG_GREEN}1)${NC} ${BOLD}usbhid-ups${NC}  ➔ (Padrão/Recomendado) Para APC Smart-UPS (SMC2200BI-BR), Back-UPS, Eaton, CyberPower e Tripp Lite via USB."
echo -e "    ${FG_GREEN}2)${NC} ${BOLD}blazer_usb${NC}  ➔ Para nobreaks nacionais (SMS, Ragtech, NHS, TS Shara) com protocolo Megatec via USB."
echo -e "    ${FG_GREEN}3)${NC} ${BOLD}apcsmart${NC}    ➔ Para nobreaks APC legados que utilizam cabo Serial RS-232."
echo -e "    ${FG_GREEN}4)${NC} ${BOLD}Outro${NC}       ➔ Digite manualmente o nome de qualquer outro driver da lista HCL do NUT."
echo -ne "  ${FG_YELLOW}${ARROW} Escolha o driver [1=${DEFAULT_UPS_DRIVER}]: ${NC}"
read -r UPS_DRIVER_INPUT
case "${UPS_DRIVER_INPUT:-1}" in
    1|"${DEFAULT_UPS_DRIVER}"|"") UPS_DRIVER_VAL="${DEFAULT_UPS_DRIVER}" ;;
    2|"blazer_usb")               UPS_DRIVER_VAL="blazer_usb" ;;
    3|"apcsmart")                 UPS_DRIVER_VAL="apcsmart" ;;
    *)                            UPS_DRIVER_VAL="$UPS_DRIVER_INPUT" ;;
esac
log_info "Driver do Nobreak definido: ${FG_GREEN}${UPS_DRIVER_VAL}${NC}"

# 2.3 - Descrição do Nobreak
echo -e "\n  ${BOLD}Descrição / Rótulo Amigável do Nobreak:${NC}"
echo -e "  ${DIM}Texto descritivo livre para identificar o equipamento (ex: modelo ou localização física).${NC}"
echo -e "  ${DIM}Exemplos: 'APC Smart-UPS BR 2200VA', 'Nobreak Rack CPD', 'APC Sala de Servidores'.${NC}"
echo -ne "  ${FG_YELLOW}${ARROW} Descrição do Nobreak [${DEFAULT_UPS_DESC}]: ${NC}"
read -r UPS_DESC_INPUT
UPS_DESC_VAL="${UPS_DESC_INPUT:-$DEFAULT_UPS_DESC}"
log_info "Descrição definida: ${FG_GREEN}${UPS_DESC_VAL}${NC}"

# 2.4 - Potência Nominal em Watts
echo -e "\n  ${BOLD}Potência Nominal do Equipamento (Watts):${NC}"
echo -e "  ${DIM}Utilizado para calcular o consumo em Watts e Amperes no Zabbix (SMC2200BI-BR = 2200W).${NC}"
echo -ne "  ${FG_YELLOW}${ARROW} Potência Nominal em Watts [${DEFAULT_NOMINAL_POWER}]: ${NC}"
read -r UPS_POWER_INPUT
UPS_POWER_VAL="${UPS_POWER_INPUT:-$DEFAULT_NOMINAL_POWER}"
if ! [[ "$UPS_POWER_VAL" =~ ^[0-9]+$ ]]; then
    UPS_POWER_VAL="$DEFAULT_NOMINAL_POWER"
fi
log_info "Potência Nominal definida: ${FG_GREEN}${UPS_POWER_VAL} W${NC}"

# 2.5 - Status do Desligamento Automático do Servidor
echo -e "\n  ${BOLD}Política de Desligamento do Servidor:${NC}"
log_info "Desligamento automático do servidor em falta de energia: ${FG_YELLOW}${BOLD}DESATIVADO${NC}"
log_info "O servidor ${FG_GREEN}NÃO SERÁ DESLIGADO${NC} automaticamente pelo NUT. O Zabbix gerenciará os alertas."

# 2.6 - Confirmação para Prosseguir
echo -e ""
echo -ne "  ${FG_YELLOW}${ARROW} Deseja aplicar as configurações acima e prosseguir? (S/n): ${NC}"
read -r CONFIRMAR
CONFIRMAR="${CONFIRMAR:-S}"
if [[ ! "$CONFIRMAR" =~ ^[Ss]$ ]]; then
    log_warning "Operação cancelada pelo operador."
    exit 0
fi

# 2.7 - Tratamento de Serviços Conflitantes Anteriores (apcupsd)
if systemctl is-active --quiet apcupsd 2>/dev/null || dpkg -s apcupsd > /dev/null 2>&1; then
    log_warning "Detectado serviço conflitante 'apcupsd' no sistema."
    log_info "Parando e desabilitando o apcupsd para liberar a porta USB para o NUT..."
    systemctl stop apcupsd > /dev/null 2>&1 || true
    systemctl disable apcupsd > /dev/null 2>&1 || true
    systemctl mask apcupsd > /dev/null 2>&1 || true
    log_success "Serviço apcupsd desativado com sucesso (porta USB liberada)."
fi

# ==============================================================================
# 3 - INSTALAÇÃO DE PACOTES E DEPENDÊNCIAS
# ==============================================================================
print_header "INSTALAÇÃO DE PACOTES (NUT, CLIENTES E UTILITÁRIOS)"

log_info "Atualizando índices de pacotes via apt-get..."
apt-get update -y > /dev/null 2>&1 || {
    log_error "Falha ao executar apt-get update."
    exit 1
}

PACOTES_NECESSARIOS=("nut" "nut-client" "nut-server" "udev" "jq" "bc")

for pct in "${PACOTES_NECESSARIOS[@]}"; do
    if dpkg -s "$pct" > /dev/null 2>&1; then
        log_info "Pacote já instalado: ${FG_WHITE}${pct}${NC}"
    else
        log_info "Instalando pacote: ${FG_WHITE}${pct}${NC}..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pct" > /dev/null 2>&1; then
            log_success "Pacote instalado: ${FG_GREEN}${pct}${NC}"
            PACOTES_INSTALADOS+=("$pct")
        else
            log_error "Falha na instalação do pacote: ${pct}"
            exit 1
        fi
    fi
done

# ==============================================================================
# 4 - CONFIGURAÇÃO DO NUT (NETWORK UPS TOOLS)
# ==============================================================================
print_header "CONFIGURAÇÃO DO NUT (NETWORK UPS TOOLS)"

mkdir -p "$NUT_CONF_DIR"

# 4.1 - Modo de Operação (nut.conf)
log_info "Configurando ${NUT_CONF_FILE} (MODE=standalone)..."
cat <<EOF > "$NUT_CONF_FILE"
# Configuração do modo de operação do NUT
# Gerado automaticamente pelo install_nut_ups_zabbix.sh em $(date '+%Y-%m-%d %H:%M:%S')
MODE=standalone
EOF
chmod 644 "$NUT_CONF_FILE"
log_success "Modo standalone configurado com sucesso."

# 4.2 - Configuração do Dispositivo Nobreak (ups.conf)
log_info "Configurando ${UPS_CONF_FILE} para o nobreak '${UPS_NAME_VAL}'..."
cat <<EOF > "$UPS_CONF_FILE"
# Configuração de Nobreaks conectados
# Gerado automaticamente pelo install_nut_ups_zabbix.sh

maxretry = 3

[${UPS_NAME_VAL}]
    driver = ${UPS_DRIVER_VAL}
    port = ${DEFAULT_UPS_PORT}
    desc = "${UPS_DESC_VAL}"
    pollinterval = 2
EOF
chmod 640 "$UPS_CONF_FILE"
chown root:nut "$UPS_CONF_FILE" 2>/dev/null || true
log_success "Nobreak '${UPS_NAME_VAL}' configurado em ups.conf."

# 4.3 - Configuração de Escuta Local do Servidor (upsd.conf)
log_info "Configurando ${UPSD_CONF_FILE} para escuta local (127.0.0.1:3493)..."
cat <<EOF > "$UPSD_CONF_FILE"
# Configuração do daemon do servidor NUT (upsd)
LISTEN 127.0.0.1 3493
LISTEN ::1 3493
MAXAGE 15
EOF
chmod 640 "$UPSD_CONF_FILE"
chown root:nut "$UPSD_CONF_FILE" 2>/dev/null || true
log_success "Daemon upsd configurado para escuta local."

# 4.4 - Geração de Usuários de Autenticação Seguros (upsd.users)
log_info "Gerando credenciais de acesso seguras para monitoramento..."
NUT_MON_PASS=$(openssl rand -hex 16)
NUT_ADMIN_PASS=$(openssl rand -hex 16)

cat <<EOF > "$UPSD_USERS_FILE"
# Usuários do NUT upsd
# Gerado automaticamente pelo install_nut_ups_zabbix.sh
[admin]
    password = ${NUT_ADMIN_PASS}
    actions = SET
    instcmds = ALL

[monuser]
    password = ${NUT_MON_PASS}
    upsmon master
EOF
chmod 640 "$UPSD_USERS_FILE"
chown root:nut "$UPSD_USERS_FILE" 2>/dev/null || true
log_success "Usuários e senhas de serviço gerados com segurança."

# 4.5 - Configuração do Monitoramento com Desligamento Automático Desativado (upsmon.conf)
log_info "Configurando ${UPSMON_CONF_FILE} com desligamento automático DESATIVADO..."
cat <<EOF > "$UPSMON_CONF_FILE"
# Configuração do Monitor do NUT (upsmon)
# ATENÇÃO: O desligamento automático do servidor está DESATIVADO por requisição de projeto.
# O sistema apenas registrará o alerta no syslog e o Zabbix gerenciará as notificações.

RUN_AS_USER nut

MONITOR ${UPS_NAME_VAL}@localhost 1 monuser ${NUT_MON_PASS} master

MINSUPPLIES 1

# Comando de shutdown inócuo que apenas registra em log sem desligar o servidor
SHUTDOWNCMD "/usr/bin/logger -t nut-upsmon 'ALERTA CRITICO: Nobreak em nivel critico de bateria! Desligamento automatico desativado por configuracao.'"

NOTIFYCMD /sbin/upssched
POLLFREQ 5
POLLFREQALERT 2
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower

NOTIFYFLAG ONLINE    SYSLOG+WALL
NOTIFYFLAG ONBATT    SYSLOG+WALL
NOTIFYFLAG LOWBATT   SYSLOG+WALL
NOTIFYFLAG FSD       SYSLOG+WALL
NOTIFYFLAG COMMOK    SYSLOG+WALL
NOTIFYFLAG COMMBAD   SYSLOG+WALL
NOTIFYFLAG SHUTDOWN  SYSLOG+WALL
NOTIFYFLAG REPLBATT  SYSLOG+WALL
NOTIFYFLAG NOCOMM    SYSLOG+WALL
NOTIFYFLAG NOPARENT  SYSLOG+WALL
EOF
chmod 640 "$UPSMON_CONF_FILE"
chown root:nut "$UPSMON_CONF_FILE" 2>/dev/null || true
log_success "Arquivo upsmon.conf configurado (Shutdown desabilitado)."

# 4.6 - Regras de Permissão UDEV para Comunicação USB
log_info "Configurando regras UDEV (/etc/udev/rules.d/90-nut-ups.rules)..."
cat <<'EOF' > /etc/udev/rules.d/90-nut-ups.rules
# Regras UDEV para acesso de nobreaks USB pelo grupo nut
# APC (American Power Conversion)
SUBSYSTEM=="usb", ATTR{idVendor}=="051d", MODE="0660", GROUP="nut"
# SMS Tecnologia Eletronica
SUBSYSTEM=="usb", ATTR{idVendor}=="0fc5", MODE="0660", GROUP="nut"
# Cypress / Genérico HID
SUBSYSTEM=="usb", ATTR{idVendor}=="04b4", MODE="0660", GROUP="nut"
# Eaton / Powerware
SUBSYSTEM=="usb", ATTR{idVendor}=="0592", MODE="0660", GROUP="nut"
# Cyber Power System
SUBSYSTEM=="usb", ATTR{idVendor}=="0764", MODE="0660", GROUP="nut"
EOF
udevadm control --reload-rules > /dev/null 2>&1 || true
udevadm trigger --subsystem-match=usb > /dev/null 2>&1 || true
log_success "Regras UDEV configuradas e recarregadas."

# ==============================================================================
# 5 - INTEGRAÇÃO COM O ZABBIX AGENT 7.0
# ==============================================================================
print_header "INTEGRAÇÃO COM O ZABBIX AGENT 7.0"

# 5.1 - Adição do usuário zabbix ao grupo nut
if id "zabbix" > /dev/null 2>&1; then
    usermod -a -G nut zabbix 2>/dev/null || true
    log_success "Usuário 'zabbix' adicionado ao grupo 'nut'."
else
    log_warning "Usuário 'zabbix' não encontrado no sistema. O Zabbix Agent deverá ser instalado posteriormente."
fi

# 5.2 - Script Utilitário de Coleta Otimizada (/etc/zabbix/scripts/nut-ups-status.sh)
mkdir -p "$ZABBIX_SCRIPTS_DIR"
log_info "Criando script de coleta para o Zabbix em ${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh..."

cat <<'EOF' > "${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh"
#!/bin/bash
# Script de coleta de métricas do NUT para Zabbix Agent
# Uso: nut-ups-status.sh <nome_ups> <metrica> [potencia_nominal_watts]

set -e

UPS="${1:-Canacampo_Nobreak}"
METRIC="${2:-status}"
NOMINAL_POWER="${3:-2200}"

case "$METRIC" in
    discovery)
        # Descoberta LLD em formato JSON para o Zabbix
        UPS_LIST=$(upsc -l 2>/dev/null || echo "")
        echo -n '{"data":['
        FIRST=1
        for u in $UPS_LIST; do
            [ $FIRST -eq 0 ] && echo -n ','
            echo -n "{\"{#UPSNAME}\":\"$u\"}"
            FIRST=0
        done
        echo ']}'
        ;;
    all_json)
        # Exporta todas as variáveis em formato JSON em uma única consulta
        upsc "$UPS" 2>/dev/null | awk -F': ' '
        BEGIN { printf "{" }
        {
            gsub(/"/, "\\\"", $2);
            if (NR > 1) printf ",";
            printf "\"%s\":\"%s\"", $1, $2;
        }
        END { printf "}" }'
        ;;
    power_watts)
        # Calcula a potência real estimada em Watts a partir da carga (%) e da potência nominal
        LOAD=$(upsc "$UPS" ups.load 2>/dev/null || echo "0")
        if [[ "$LOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "$LOAD" "$NOMINAL_POWER" | awk '{printf "%.1f", ($1 / 100.0) * $2}'
        else
            echo "0.0"
        fi
        ;;
    load_amps)
        # Calcula corrente estimada em Amperes: Watts / Tensão de saída
        LOAD=$(upsc "$UPS" ups.load 2>/dev/null || echo "0")
        OUT_V=$(upsc "$UPS" output.voltage 2>/dev/null || echo "127")
        if [[ "$LOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$OUT_V" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$OUT_V > 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "$LOAD" "$NOMINAL_POWER" "$OUT_V" | awk '{watts = ($1 / 100.0) * $2; printf "%.1f", watts / $3}'
        else
            echo "0.0"
        fi
        ;;
    battery_status_code)
        # Mapeia o status da bateria para códigos compatíveis com os templates APC SNMP
        # 1=unknown, 2=batteryNormal, 3=batteryLow, 4=batteryInFault
        BSTATUS=$(upsc "$UPS" ups.status 2>/dev/null || echo "")
        if [[ "$BSTATUS" =~ "LB" ]]; then
            echo "3" # batteryLow
        elif [[ "$BSTATUS" =~ "RB" ]]; then
            echo "4" # batteryInFault / Replace
        elif [[ -n "$BSTATUS" ]]; then
            echo "2" # batteryNormal
        else
            echo "1" # unknown
        fi
        ;;
    ups_status_code)
        # Mapeia o status do UPS: 1=unknown, 2=onLine, 3=onBattery, 4=onBoost, 5=sleeping, 6=onBypass, 7=rebooting
        STATUS=$(upsc "$UPS" ups.status 2>/dev/null || echo "")
        if [[ "$STATUS" =~ "OL" ]]; then
            echo "2" # onLine
        elif [[ "$STATUS" =~ "OB" ]]; then
            echo "3" # onBattery
        elif [[ "$STATUS" =~ "BOOST" ]]; then
            echo "4" # onBoost
        elif [[ "$STATUS" =~ "BYPASS" ]]; then
            echo "6" # onBypass
        elif [[ -n "$STATUS" ]]; then
            echo "2" # onLine padrão
        else
            echo "1" # unknown
        fi
        ;;
    *)
        # Consulta direta de qualquer chave do NUT (ex: battery.charge, input.voltage)
        VAL=$(upsc "$UPS" "$METRIC" 2>/dev/null || echo "")
        if [ -n "$VAL" ]; then
            echo "$VAL"
        else
            echo "0"
        fi
        ;;
esac
EOF
chmod 755 "${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh"
chown root:root "${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh"
log_success "Script de métricas criado com sucesso."

# 5.3 - Configuração dos UserParameters do Zabbix Agent
USERPARAM_CONTENT="# Configuração de Coleta do NUT UPS para Zabbix Agent 7.0
# Gerado automaticamente pelo install_nut_ups_zabbix.sh
UserParameter=nut.discovery,${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '' discovery
UserParameter=nut.all_json[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' all_json
UserParameter=nut.get[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' '\$2' '\$3'
UserParameter=nut.power_watts[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' power_watts '\$2'
UserParameter=nut.load_amps[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' load_amps '\$2'
UserParameter=nut.battery_status_code[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' battery_status_code
UserParameter=nut.ups_status_code[*],${ZABBIX_SCRIPTS_DIR}/nut-ups-status.sh '\$1' ups_status_code
"

if [ -d "$ZABBIX_AGENT_CONF_DIR" ]; then
    echo "$USERPARAM_CONTENT" > "${ZABBIX_AGENT_CONF_DIR}/userparameter_nut.conf"
    chmod 644 "${ZABBIX_AGENT_CONF_DIR}/userparameter_nut.conf"
    log_success "UserParameters injetados em: ${ZABBIX_AGENT_CONF_DIR}/userparameter_nut.conf"
fi

if [ -d "$ZABBIX_AGENT2_CONF_DIR" ]; then
    echo "$USERPARAM_CONTENT" > "${ZABBIX_AGENT2_CONF_DIR}/userparameter_nut.conf"
    chmod 644 "${ZABBIX_AGENT2_CONF_DIR}/userparameter_nut.conf"
    log_success "UserParameters injetados em: ${ZABBIX_AGENT2_CONF_DIR}/userparameter_nut.conf"
fi

# ==============================================================================
# 6 - INICIALIZAÇÃO E ATIVAÇÃO DOS SERVIÇOS SYSTEMD
# ==============================================================================
print_header "INICIALIZAÇÃO DOS SERVIÇOS DO NUT E ZABBIX"

log_info "Habilitando e iniciando nut-server e nut-client..."
systemctl daemon-reload > /dev/null 2>&1 || true
systemctl enable nut-server > /dev/null 2>&1 || true
systemctl enable nut-client > /dev/null 2>&1 || true

# Tenta reiniciar o driver do NUT
upsdrvctl stop > /dev/null 2>&1 || true
upsdrvctl start > /dev/null 2>&1 || {
    log_warning "Driver USB não iniciou imediatamente (o cabo USB pode não estar conectado agora)."
}

systemctl restart nut-server > /dev/null 2>&1 || true
systemctl restart nut-client > /dev/null 2>&1 || true

# Reinicia o Zabbix Agent se instalado
if systemctl list-unit-files | grep -q "zabbix-agent.service"; then
    log_info "Reiniciando serviço zabbix-agent..."
    systemctl restart zabbix-agent > /dev/null 2>&1 || true
    log_success "Serviço zabbix-agent reiniciado com as novas métricas do NUT."
elif systemctl list-unit-files | grep -q "zabbix-agent2.service"; then
    log_info "Reiniciando serviço zabbix-agent2..."
    systemctl restart zabbix-agent2 > /dev/null 2>&1 || true
    log_success "Serviço zabbix-agent2 reiniciado com as novas métricas do NUT."
else
    log_info "Zabbix Agent ainda não instalado. As métricas entrarão em vigor após a instalação do agente."
fi

# ==============================================================================
# 7 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
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

# ==============================================================================
# 8 - RESUMO DA INSTALAÇÃO E TESTE OPERACIONAL
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")
STATUS_NUT_SERVER=$(get_service_status nut-server)
STATUS_NUT_CLIENT=$(get_service_status nut-client)

echo -e "  ${FG_GREEN}${BOLD}✔ PROCESSO FINALIZADO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Sistema:${NC}          ${FG_GREEN}Operacional${NC}"
echo -e "  ${BOLD}Pacotes Instalados:${NC}         ${FG_CYAN}${LISTA_PACOTES:-Nenhum (já presentes)}${NC}"
echo -e "  ${BOLD}Serviço nut-server:${NC}         ${STATUS_NUT_SERVER}"
echo -e "  ${BOLD}Serviço nut-client:${NC}         ${STATUS_NUT_CLIENT}"
echo -e "  ${BOLD}Identificador do UPS:${NC}       ${FG_GREEN}${UPS_NAME_VAL}${NC}"
echo -e "  ${BOLD}Driver de Comunicação:${NC}      ${FG_CYAN}${UPS_DRIVER_VAL}${NC}"
echo -e "  ${BOLD}Porta do Dispositivo:${NC}       ${FG_CYAN}${DEFAULT_UPS_PORT} (Detecção Automática USB)${NC}"
echo -e "  ${BOLD}Shutdown Automático:${NC}        ${FG_YELLOW}${BOLD}DESATIVADO${NC} ${DIM}(Servidor permanece ligado)${NC}"
echo -e "  ${BOLD}Integração Zabbix:${NC}          ${FG_GREEN}Configurada (/etc/zabbix/scripts/nut-ups-status.sh)${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}          ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

print_header "TESTE DE COMUNICAÇÃO COM O NOBREAK (upsc)"
if upsc "${UPS_NAME_VAL}@localhost" > /dev/null 2>&1; then
    echo -e "  ${FG_GREEN}${BOLD}Conexão USB bem-sucedida! Principais dados coletados:${NC}\n"
    upsc "${UPS_NAME_VAL}@localhost" | grep -E 'battery\.(charge|runtime|voltage|temperature)|input\.voltage|output\.voltage|ups\.(load|status|model|serial)' | sed 's/^/    /' || true
else
    echo -e "  ${FG_YELLOW}[!] O nobreak ainda não respondeu ao comando 'upsc ${UPS_NAME_VAL}@localhost'.${NC}"
    echo -e "      ${DIM}Verifique se o cabo USB está conectado à porta USB do servidor e execute:${NC}"
    echo -e "      ${BOLD}sudo upsdrvctl restart && sudo systemctl restart nut-server${NC}"
    echo -e "      ${BOLD}upsc ${UPS_NAME_VAL}@localhost${NC}\n"
fi

exit 0
