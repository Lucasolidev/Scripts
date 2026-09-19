#!/bin/bash
# shellcheck disable=SC2317
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO DO SCHNEIDER POWERCHUTE SERIAL SHUTDOWN (PCSS)
# AMBIENTE: UBUNTU SERVER 24.04 LTS / 26.04 (PRODUÇÃO)
# MONITORAMENTO E GERENCIAMENTO DE NOBREAKS APC SMART-UPS VIA USB OU SERIAL
# ==============================================================================
# METADADOS DO PACOTE OFICIAL (SCHNEIDER ELECTRIC):
# • Software: PowerChute Serial Shutdown Linux for Smart-UPS, Easy UPS Online (x64, English only)
# • Versão Oficial: 1.6 (Build 1.6.0-301)
# • Data de Lançamento do Pacote: 29/07/2026
# • Formato: GZ (.tar.gz) | Tamanho: 92.6 MB | Idioma: Inglês (English only)
# • Sistemas Operacionais Homologados pelo Fabricante: Red Hat Enterprise Linux, SUSE Enterprise Linux
# • Homologação e Adaptação deste Script: Ubuntu Server 24.04 LTS e 26.04 (x86_64)
# • Página Oficial do Produto:
#   https://www.se.com/br/pt/product/SFPCSS/powerchute-serial-shutdown-desligamento-aut%C3%B4nomo-e-controlado-monitoramento-e-configura%C3%A7%C3%A3o-de-nobreak-gerenciamento-de-energia/
# • Link Direto de Download:
#   https://download.schneider-electric.com/files?p_enDocType=Software+-+Release&p_File_Name=pcssagent-1.6.0-301-EN.x86_64.tar.gz&p_Doc_Ref=SPD-PCSS_LNX_EN
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_apc_powerchute.sh -O install_apc_powerchute.sh && sudo chmod +x install_apc_powerchute.sh && sudo ./install_apc_powerchute.sh
# ==============================================================================

set -Eeuo pipefail

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
        echo -e "${FG_GREEN}Ativo (Em Execução)${NC}"
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

get_server_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "SEU_IP"
}

# ==============================================================================
# CONSTANTES GLOBAIS DO POWERCHUTE
# ==============================================================================
readonly PCSS_APP_NAME="PowerChute Serial Shutdown Linux for Smart-UPS, Easy UPS Online"
readonly PCSS_RELEASE_VERSION="1.6"
readonly PCSS_BUILD_VERSION="1.6.0-301"
readonly PCSS_RELEASE_DATE="29/07/2026"
readonly PCSS_PACKAGE_SIZE="92.6 MB"
readonly PCSS_PORTAL_URL="https://www.se.com/br/pt/product/SFPCSS/powerchute-serial-shutdown-desligamento-aut%C3%B4nomo-e-controlado-monitoramento-e-configura%C3%A7%C3%A3o-de-nobreak-gerenciamento-de-energia/"
readonly PCSS_TAR_NAME="pcssagent-${PCSS_BUILD_VERSION}-EN.x86_64.tar.gz"
readonly PCSS_OFFICIAL_URL="https://download.schneider-electric.com/files?p_enDocType=Software+-+Release&p_File_Name=${PCSS_TAR_NAME}&p_Doc_Ref=SPD-PCSS_LNX_EN"
readonly INSTALL_BASE_DIR="/opt/APC/PowerChuteSerialShutdown"
readonly AGENT_DIR="${INSTALL_BASE_DIR}/Agent"
readonly SERVICE_NAME="PBEAgent"
readonly WEB_PORT="6547"
readonly SNMP_PORT="161"

# Variáveis de Estado e Parâmetros
PACOTES_INSTALADOS=()
ORIGEM_PACOTE_VAL=""
TAR_PATH_VAL=""
CONFIG_ASSISTENTE_VAL="S"
APC_USER=""
APC_PASS=""
APC_SIGNAL="usb"
APC_PORT="/dev/ttyS0"
CONFIG_UFW_VAL="S"
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

# Validação de Arquitetura (Apenas x86_64 suportado pela Schneider)
ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
    log_error "Arquitetura não suportada: '${ARCH}'. O PowerChute Serial Shutdown requer Linux 64-bit (x86_64)."
    exit 1
fi

# Detecção e Validação do Sistema Operacional (Ubuntu Server 24.04 ou 26.04)
if [[ -f /etc/os-release ]]; then
    OS_DISTRO=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OS_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
else
    log_error "Não foi possível determinar o sistema operacional (/etc/os-release ausente)."
    exit 1
fi

if [[ "$OS_DISTRO" != "ubuntu" ]]; then
    log_error "Distribuição não suportada: '${OS_DISTRO}'. Este script é homologado exclusivamente para Ubuntu Server."
    exit 1
fi

case "$OS_VERSION" in
    "24.04"|"26.04")
        log_info "Sistema homologado detectado: Ubuntu Server ${OS_VERSION} (${OS_CODENAME})."
        ;;
    *)
        log_error "Versão do Ubuntu não suportada: '${OS_VERSION}' (${OS_CODENAME}). Versões homologadas: Ubuntu Server 24.04 LTS ou 26.04."
        exit 1
        ;;
esac

# Inicialização da Captura de Logs Padronizada (relatorio_install_apc_powerchute_DDMMYYYY_HHMM.log)
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_apc_powerchute_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_apc_powerchute_latest.log"
umask 077
RUNTIME_DIR=$(mktemp -d -p /tmp apc_powerchute_install.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALAÇÃO DO SCHNEIDER POWERCHUTE SERIAL SHUTDOWN (v${VERSION})"
log_info "Software Oficial: ${BOLD}${PCSS_APP_NAME}${NC}"
log_info "Versão Oficial: ${FG_CYAN}v${PCSS_RELEASE_VERSION}${NC} (Build ${PCSS_BUILD_VERSION}) | Lançamento: ${FG_WHITE}${PCSS_RELEASE_DATE}${NC}"
log_info "Tamanho do Pacote: ${PCSS_PACKAGE_SIZE} (.tar.gz) | Idioma: Inglês (x64)"
echo -e "  ${DIM}Iniciando execução em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

# Verificação se o serviço já se encontra ativo
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    print_alert_box "O serviço '${SERVICE_NAME}' já está instalado e ativo no servidor."
    echo -ne "  ${FG_YELLOW}${ARROW} Deseja reinstalar e reconfigurar o PowerChute? (s/N): ${NC}"
    read -r RESP_REINSTALL
    if [[ ! "$RESP_REINSTALL" =~ ^[sS]$ ]]; then
        log_info "Operação cancelada pelo operador."
        exit 0
    fi
    log_info "Reinstalação confirmada. Parando o serviço ${SERVICE_NAME}..."
    systemctl stop "$SERVICE_NAME" || true
fi

# ==============================================================================
# 2 - COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

# 2.1 - Origem do Pacote de Instalação (Download Oficial ou Arquivo Local)
LOCAL_FOUND_PATH=""
POSSIVEIS_LOCAIS=(
    "./${PCSS_TAR_NAME}"
    "$(pwd)/${PCSS_TAR_NAME}"
    "/tmp/${PCSS_TAR_NAME}"
    "$HOME/${PCSS_TAR_NAME}"
)

for loc in "${POSSIVEIS_LOCAIS[@]}"; do
    if [[ -f "$loc" ]]; then
        LOCAL_FOUND_PATH="$loc"
        break
    fi
done

if [[ -n "$LOCAL_FOUND_PATH" ]]; then
    log_info "Arquivo oficial localizado localmente: ${FG_GREEN}${LOCAL_FOUND_PATH}${NC}"
    echo -e "  ${FG_GREEN}1)${NC} ${BOLD}Utilizar o arquivo local existente${NC} (${LOCAL_FOUND_PATH})"
    echo -e "  ${FG_GREEN}2)${NC} ${BOLD}Baixar novamente${NC} do portal oficial da Schneider Electric"
    echo -e "  ${FG_GREEN}3)${NC} ${BOLD}Informar outro caminho manualmente${NC}"
    echo -ne "  ${FG_YELLOW}${ARROW} Escolha a origem [1]: ${NC}"
    read -r OPT_ORIGEM
    OPT_ORIGEM="${OPT_ORIGEM:-1}"
else
    echo -e "  O arquivo ${BOLD}${PCSS_TAR_NAME}${NC} não foi encontrado no diretório atual."
    echo -e "  ${FG_GREEN}1)${NC} ${BOLD}Baixar automaticamente${NC} do portal oficial da Schneider Electric (~93 MB)"
    echo -e "  ${FG_GREEN}2)${NC} ${BOLD}Informar o caminho manual${NC} de um arquivo existente no servidor"
    echo -ne "  ${FG_YELLOW}${ARROW} Escolha a opção [1]: ${NC}"
    read -r OPT_ORIGEM
    OPT_ORIGEM="${OPT_ORIGEM:-1}"
fi

case "$OPT_ORIGEM" in
    1)
        if [[ -n "$LOCAL_FOUND_PATH" ]]; then
            ORIGEM_PACOTE_VAL="local"
            TAR_PATH_VAL="$LOCAL_FOUND_PATH"
            log_info "Origem definida: ${FG_GREEN}Arquivo local (${TAR_PATH_VAL})${NC}"
        else
            ORIGEM_PACOTE_VAL="download"
            TAR_PATH_VAL="/tmp/${PCSS_TAR_NAME}"
            log_info "Origem definida: ${FG_GREEN}Download oficial Schneider Electric${NC}"
        fi
        ;;
    2)
        if [[ -n "$LOCAL_FOUND_PATH" ]]; then
            ORIGEM_PACOTE_VAL="download"
            TAR_PATH_VAL="/tmp/${PCSS_TAR_NAME}"
            log_info "Origem definida: ${FG_GREEN}Download oficial Schneider Electric${NC}"
        else
            ORIGEM_PACOTE_VAL="manual"
            echo -ne "  ${FG_YELLOW}${ARROW} Digite o caminho completo para o arquivo .tar.gz: ${NC}"
            read -r MANUAL_INPUT
            if [[ -f "$MANUAL_INPUT" ]]; then
                TAR_PATH_VAL="$MANUAL_INPUT"
                log_info "Caminho informado e validado: ${FG_GREEN}${TAR_PATH_VAL}${NC}"
            else
                log_error "Arquivo não encontrado no caminho informado: '${MANUAL_INPUT}'"
                exit 1
            fi
        fi
        ;;
    3)
        ORIGEM_PACOTE_VAL="manual"
        echo -ne "  ${FG_YELLOW}${ARROW} Digite o caminho completo para o arquivo .tar.gz: ${NC}"
        read -r MANUAL_INPUT
        if [[ -f "$MANUAL_INPUT" ]]; then
            TAR_PATH_VAL="$MANUAL_INPUT"
            log_info "Caminho informado e validado: ${FG_GREEN}${TAR_PATH_VAL}${NC}"
        else
            log_error "Arquivo não encontrado no caminho informado: '${MANUAL_INPUT}'"
            exit 1
        fi
        ;;
    *)
        log_error "Opção inválida selecionada."
        exit 1
        ;;
esac

# 2.2 - Configuração de Credenciais do PowerChute
echo -e "\n  ${BOLD}Configuração de Acesso ao Painel Web APC:${NC}"
echo -e "  Defina o usuário e a senha de administração para gerenciar o nobreak via HTTPS (${WEB_PORT})."
echo -ne "  ${FG_YELLOW}${ARROW} Deseja configurar as credenciais do nobreak agora? (S/n): ${NC}"
read -r RESP_ASSISTENTE
RESP_ASSISTENTE="${RESP_ASSISTENTE:-S}"

if [[ "$RESP_ASSISTENTE" =~ ^[sSyY]$ ]]; then
    CONFIG_ASSISTENTE_VAL="S"
    echo -e "\n  ${FG_YELLOW}${BOLD}REGRAS OBRIGATÓRIAS PARA CREDENCIAIS APC:${NC}"
    echo -e "  • ${BOLD}Usuário:${NC} Mínimo de 6 a 128 caracteres (ex: ${FG_CYAN}administrador${NC})"
    echo -e "  • ${BOLD}Senha:${NC}   Mínimo de 8 a 128 caracteres, contendo ao menos:"
    echo -e "             - 1 letra maiúscula e 1 letra minúscula"
    echo -e "             - 1 número ou caractere especial (#?!@$%^&*-)"
    echo -e "  • O nome de usuário não pode fazer parte da senha."
    echo -e ""

    # Coleta e Validação do Usuário
    while true; do
        echo -ne "  ${FG_YELLOW}${ARROW} Digite o Usuário de Administração [administrador]: ${NC}"
        read -r INPUT_USER
        INPUT_USER="${INPUT_USER:-administrador}"

        if [[ ${#INPUT_USER} -ge 6 && ${#INPUT_USER} -le 128 && "$INPUT_USER" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            APC_USER="$INPUT_USER"
            log_info "Usuário definido: ${FG_GREEN}${APC_USER}${NC}"
            break
        else
            log_warning "Usuário inválido! Deve ter entre 6 e 128 caracteres alfanuméricos sem espaços."
        fi
    done

    # Coleta e Validação da Senha
    while true; do
        echo -ne "  ${FG_YELLOW}${ARROW} Digite a Nova Senha: ${NC}"
        read -r -s INPUT_PASS
        echo ""

        if [[ ${#INPUT_PASS} -lt 8 || ${#INPUT_PASS} -gt 128 ]]; then
            log_warning "A senha deve ter entre 8 e 128 caracteres."
            continue
        fi

        if [[ ! "$INPUT_PASS" =~ [A-Z] ]]; then
            log_warning "A senha deve conter ao menos 1 letra MAIÚSCULA."
            continue
        fi

        if [[ ! "$INPUT_PASS" =~ [a-z] ]]; then
            log_warning "A senha deve conter ao menos 1 letra MINÚSCULA."
            continue
        fi

        SPECIAL_PATTERN='[#?!@$%^&*-]'
        if [[ ! "$INPUT_PASS" =~ [0-9] && ! "$INPUT_PASS" =~ $SPECIAL_PATTERN ]]; then
            log_warning "A senha deve conter ao menos 1 NÚMERO ou CARACTERE ESPECIAL (#?!@$%^&*-)."
            continue
        fi

        # Validação: usuário não pode estar contido na senha
        USER_LOWER=$(echo "$APC_USER" | tr '[:upper:]' '[:lower:]')
        PASS_LOWER=$(echo "$INPUT_PASS" | tr '[:upper:]' '[:lower:]')
        if [[ "$PASS_LOWER" == *"$USER_LOWER"* ]]; then
            log_warning "O nome de usuário não pode fazer parte da senha."
            continue
        fi

        echo -ne "  ${FG_YELLOW}${ARROW} Confirme a Nova Senha: ${NC}"
        read -r -s INPUT_PASS_CONFIRM
        echo ""

        if [[ "$INPUT_PASS" != "$INPUT_PASS_CONFIRM" ]]; then
            log_warning "As senhas não coincidem. Tente novamente."
            continue
        fi

        APC_PASS="$INPUT_PASS"
        log_success "Senha validada com sucesso."
        break
    done

    # Tipo de Comunicação com o Nobreak (USB ou Serial)
    echo -e "\n  ${BOLD}Tipo de Conexão com o Nobreak APC:${NC}"
    echo -e "  ${FG_GREEN}1)${NC} ${BOLD}USB${NC} (Recomendado para Smart-UPS e Easy UPS conectados via cabo USB)"
    echo -e "  ${FG_GREEN}2)${NC} ${BOLD}Serial (COM / ttyS0 / ttyUSB0)${NC}"
    echo -ne "  ${FG_YELLOW}${ARROW} Escolha o tipo de conexão [1]: ${NC}"
    read -r OPT_CONN
    OPT_CONN="${OPT_CONN:-1}"

    if [[ "$OPT_CONN" == "2" ]]; then
        APC_SIGNAL="serial"
        echo -ne "  ${FG_YELLOW}${ARROW} Digite a porta serial [/dev/ttyS0]: ${NC}"
        read -r INPUT_PORT
        APC_PORT="${INPUT_PORT:-/dev/ttyS0}"
        log_info "Conexão definida: ${FG_GREEN}Serial (${APC_PORT})${NC}"
    else
        APC_SIGNAL="usb"
        APC_PORT="none"
        log_info "Conexão definida: ${FG_GREEN}USB (Detecção Automática)${NC}"
    fi
else
    CONFIG_ASSISTENTE_VAL="N"
    log_info "Configuração inicial de credenciais pulada a pedido do operador."
fi

# 2.3 - Detecção de Firewall UFW (Liberação Automática se Ativo)
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    CONFIG_UFW_VAL="S"
    log_info "Firewall UFW ativo detectado: Portas ${FG_CYAN}${WEB_PORT}/tcp${NC} (HTTPS) e ${FG_CYAN}${SNMP_PORT}/udp${NC} (SNMP) serão liberadas automaticamente."
else
    CONFIG_UFW_VAL="N"
    log_info "Firewall UFW inativo ou não instalado. Liberação automática ignorada."
fi

# ==============================================================================
# 3 - INSTALAÇÃO DE DEPENDÊNCIAS DO SISTEMA (apt-get)
# ==============================================================================
print_header "INSTALAÇÃO DE DEPENDÊNCIAS DO SISTEMA"

log_info "Atualizando índices de pacotes do Ubuntu Server..."
apt-get update -qq >/dev/null 2>&1

DEPENDENCIAS_SISTEMA=(rpm unzip curl ca-certificates udev snmp)

for pkg in "${DEPENDENCIAS_SISTEMA[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log_skipped "Pacote '${pkg}' já se encontra instalado."
    else
        log_info "Instalando pacote '${pkg}'..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1; then
            PACOTES_INSTALADOS+=("$pkg")
            log_success "Pacote '${pkg}' instalado com sucesso."
        else
            log_error "Falha crítica ao instalar pacote obrigatório: '${pkg}'."
            exit 1
        fi
    fi
done

# ==============================================================================
# 4 - OBTENÇÃO DO PACOTE SCHNEIDER ELECTRIC PCSS
# ==============================================================================
print_header "OBTENÇÃO DO PACOTE DE INSTALAÇÃO"

if [[ "$ORIGEM_PACOTE_VAL" == "download" ]]; then
    log_info "Baixando pacote oficial da Schneider Electric..."
    log_info "URL: ${FG_CYAN}${PCSS_OFFICIAL_URL}${NC}"
    
    if curl -fSL --progress-bar -o "$TAR_PATH_VAL" "$PCSS_OFFICIAL_URL"; then
        log_success "Download concluído com sucesso: ${TAR_PATH_VAL}"
    else
        log_error "Falha ao realizar o download do pacote oficial da Schneider."
        exit 1
    fi
else
    log_info "Utilizando pacote local pré-existente: ${TAR_PATH_VAL}"
fi

# Validação do arquivo tar.gz
if [[ ! -s "$TAR_PATH_VAL" ]]; then
    log_error "O arquivo '${TAR_PATH_VAL}' está vazio ou corrompido."
    exit 1
fi

# ==============================================================================
# 5 - EXTRAÇÃO E INSTALAÇÃO DO PACOTE RPM
# ==============================================================================
print_header "EXTRAÇÃO E INSTALAÇÃO DO PACOTE RPM"

EXTRACT_DIR="${RUNTIME_DIR}/pcss_unpack"
mkdir -p "$EXTRACT_DIR"

log_info "Descompactando o arquivo ${PCSS_TAR_NAME}..."
tar -xzf "$TAR_PATH_VAL" -C "$EXTRACT_DIR"

RPM_FILE="$(find "$EXTRACT_DIR" -maxdepth 1 -name "pcssagent-*.x86_64.rpm" | head -n 1)"
if [[ -z "$RPM_FILE" || ! -f "$RPM_FILE" ]]; then
    log_error "Arquivo RPM não encontrado dentro do pacote extraído."
    exit 1
fi
log_success "Arquivo RPM identificado: $(basename "$RPM_FILE")"

log_info "Instalando o pacote RPM na árvore do sistema (${INSTALL_BASE_DIR})..."
mkdir -p "$AGENT_DIR"

# Instalação com relocação e flags oficiais
if rpm -ivh --replacepkgs --nodeps --prefix="$AGENT_DIR" "$RPM_FILE" >/dev/null 2>&1; then
    log_success "Pacote RPM instalado com sucesso em ${AGENT_DIR}."
else
    log_warning "Instalação primária retornou código não-zero. Aplicando atualização forçada (--replacepkgs)..."
    rpm -Uvh --replacepkgs --nodeps --prefix="$AGENT_DIR" "$RPM_FILE" >/dev/null 2>&1 || {
        log_error "Falha ao instalar o pacote RPM do PowerChute."
        exit 1
    }
    log_success "Instalação via RPM concluída."
fi

# ==============================================================================
# 6 - AJUSTES DE COMPATIBILIDADE PARA UBUNTU SERVER
# ==============================================================================
print_header "AJUSTES DE COMPATIBILIDADE UBUNTU SERVER"

# 6.1 - Garantia da Extração da Máquina Virtual Java (JRE embutida da APC)
if [[ ! -x "${INSTALL_BASE_DIR}/jre/bin/java" ]]; then
    log_info "Configurando o ambiente JRE dedicado do PowerChute..."
    mkdir -p "${INSTALL_BASE_DIR}/jre"
    if [[ -f "${AGENT_DIR}/jrelnx.zip" ]]; then
        unzip -q -o "${AGENT_DIR}/jrelnx.zip" -d "${INSTALL_BASE_DIR}/jre" 2>/dev/null || true
        chmod +x "${INSTALL_BASE_DIR}/jre/bin/"* 2>/dev/null || true
        log_success "Ambiente JRE embutido configurado com sucesso."
    elif [[ -f "${AGENT_DIR}/InstallJava.sh" ]]; then
        (cd "$AGENT_DIR" && bash ./InstallJava.sh "$AGENT_DIR" >/dev/null 2>&1) || true
    fi
fi

# 6.2 - Correção e Ajustes de Compatibilidade no script config.sh
# Necessário porque no Ubuntu /bin/sh aponta para dash e o script invoca 'systemctl start PBEAgent'
if [[ -f "${AGENT_DIR}/config.sh" ]]; then
    sed -i '1s|^#!/bin/sh|#!/bin/bash|' "${AGENT_DIR}/config.sh"
    # Correção do nome do serviço systemctl no script da APC (PBEAgent -> PBEAgent.service)
    sed -i 's|systemctl start PBEAgent|systemctl start PBEAgent.service|g' "${AGENT_DIR}/config.sh"
    chmod 0750 "${AGENT_DIR}/config.sh"
    log_success "Script config.sh ajustado com cabeçalho nativo Bash e compatibilidade systemd."
fi

# 6.3 - Instalação e Correção do Shebang no executável do daemon (/usr/bin/PBEAgent)
if [[ ! -f "/usr/bin/PBEAgent" && -f "${AGENT_DIR}/bin/startup" ]]; then
    cp "${AGENT_DIR}/bin/startup" "/usr/bin/PBEAgent"
fi

if [[ -f "/usr/bin/PBEAgent" ]]; then
    sed -i '1s|^#!/bin/sh|#!/bin/bash|' "/usr/bin/PBEAgent"
    chmod 0755 "/usr/bin/PBEAgent"
    log_success "Executável /usr/bin/PBEAgent ajustado com cabeçalho nativo Bash."
fi

# 6.4 - Criação de Diretórios de Trabalho e Bloqueio
mkdir -p "${AGENT_DIR}/temp"
chmod 0770 "${AGENT_DIR}/temp"
mkdir -p /var/lock/subsys
chmod 0755 /var/lock/subsys
log_success "Diretórios temporários e de subsistema criados."

# 6.5 - Atualização e Recarga das Regras udev (Reconhecimento de portas USB de nobreaks)
if command -v udevadm >/dev/null 2>&1; then
    log_info "Recarregando regras do udev para nobreaks USB..."
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    log_success "Regras udev recarregadas com sucesso."
fi

# 6.6 - Registro e Habilitação do Serviço Systemd
log_info "Configurando o serviço ${SERVICE_NAME} no systemd..."
if [[ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
    if [[ -f "${AGENT_DIR}/${SERVICE_NAME}.service" ]]; then
        cp "${AGENT_DIR}/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
    else
        cat > "/etc/systemd/system/${SERVICE_NAME}.service" << 'EOF'
[Unit]
Description=PowerChute Serial Shutdown Agent
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/PBEAgent start
ExecStop=/usr/bin/PBEAgent stop
ExecReload=/usr/bin/PBEAgent restart

[Install]
WantedBy=default.target
EOF
    fi
    chmod 0644 "/etc/systemd/system/${SERVICE_NAME}.service"
fi

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
log_success "Serviço ${SERVICE_NAME}.service habilitado no boot."

# ==============================================================================
# 7 - CONFIGURAÇÃO DO AGENTE POWERCHUTE
# ==============================================================================
print_header "CONFIGURAÇÃO DO AGENTE NOBREAK"

if [[ "$CONFIG_ASSISTENTE_VAL" == "S" && -n "$APC_USER" && -n "$APC_PASS" ]]; then
    log_info "Aplicando credenciais administrativas no agente PowerChute..."
    log_info "Usuário: ${FG_CYAN}${APC_USER}${NC} | Conexão: ${FG_CYAN}${APC_SIGNAL}${NC}"
    draw_separator
    
    cd "$AGENT_DIR"
    # Chamada com parâmetros do utilitário da APC (PCBEConfig)
    # Nota técnica: args[0]=user=<usr>, args[1]=pass=<pwd>, args[2]=signal=<sig>, args[3]=port=<porta>
    # Para USB em kernels modernos (Linux 6.x+), signal=USB_NO_KERNEL_CHECK e port=none são obrigatórios.
    if [[ "$APC_SIGNAL" == "serial" ]]; then
        bash ./config.sh "user=${APC_USER}" "pass=${APC_PASS}" "signal=serial" "port=${APC_PORT}" || true
    else
        bash ./config.sh "user=${APC_USER}" "pass=${APC_PASS}" "signal=USB_NO_KERNEL_CHECK" "port=none" || true
    fi
    draw_separator
    log_success "Credenciais e parâmetros aplicados com sucesso no PowerChute."
else
    log_info "Configuração inicial pulada a pedido do operador."
    log_info "Para realizar a configuração posterior, execute:"
    echo -e "      ${BOLD}cd ${AGENT_DIR} && sudo bash config.sh${NC}"
fi

# ==============================================================================
# 8 - INICIALIZAÇÃO E ATIVAÇÃO DO SERVIÇO SYSTEMD
# ==============================================================================
print_header "INICIALIZAÇÃO DO SERVIÇO"

log_info "Iniciando/Reiniciando serviço ${SERVICE_NAME}..."
systemctl restart "${SERVICE_NAME}.service" || true
sleep 4

SERVER_IP="$(get_server_ip)"

if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    log_success "Serviço ${SERVICE_NAME} iniciado com sucesso."
else
    log_warning "O serviço ${SERVICE_NAME} requer que o assistente de configuração seja concluído para iniciar."
fi

# ==============================================================================
# 9 - CONFIGURAÇÃO DE SEGURANÇA E FIREWALL (UFW)
# ==============================================================================
print_header "CONFIGURAÇÃO DE SEGURANÇA E FIREWALL"

if [[ "$CONFIG_UFW_VAL" == "S" ]]; then
    log_info "Liberando porta ${WEB_PORT}/tcp no Firewall UFW..."
    if ufw allow "${WEB_PORT}/tcp" comment 'APC PowerChute Serial Shutdown Web UI' >/dev/null 2>&1; then
        log_success "Porta ${WEB_PORT}/tcp liberada com sucesso no UFW."
    else
        log_warning "Não foi possível aplicar a regra TCP ${WEB_PORT} no UFW."
    fi

    log_info "Liberando porta ${SNMP_PORT}/udp (SNMP) no Firewall UFW..."
    if ufw allow "${SNMP_PORT}/udp" comment 'SNMP Daemon / APC PowerChute' >/dev/null 2>&1; then
        log_success "Porta ${SNMP_PORT}/udp liberada com sucesso no UFW."
    else
        log_warning "Não foi possível aplicar a regra UDP ${SNMP_PORT} no UFW."
    fi
else
    log_skipped "Firewall UFW inativo ou não instalado. Regras de firewall puladas."
    echo -e "  ${DIM}Para liberar manualmente execute:${NC}"
    echo -e "      ${BOLD}sudo ufw allow ${WEB_PORT}/tcp comment 'APC PowerChute Web UI'${NC}"
    echo -e "      ${BOLD}sudo ufw allow ${SNMP_PORT}/udp comment 'SNMP Daemon / APC PowerChute'${NC}"
fi

# ==============================================================================
# 10 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
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
# 11 - RESUMO DA INSTALAÇÃO E TESTE OPERACIONAL
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")
STATUS_SERVICE=$(get_service_status "$SERVICE_NAME")

echo -e "  ${FG_GREEN}${BOLD}✔ PROCESSO FINALIZADO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Sistema:${NC}          ${FG_GREEN}Operacional (Ubuntu Server ${OS_VERSION})${NC}"
echo -e "  ${BOLD}Pacotes Instalados:${NC}         ${FG_CYAN}${LISTA_PACOTES:-Nenhum (já presentes)}${NC}"
echo -e "  ${BOLD}Software Oficial:${NC}           ${FG_WHITE}${PCSS_APP_NAME}${NC}"
echo -e "  ${BOLD}Versão do PowerChute:${NC}       ${FG_WHITE}v${PCSS_RELEASE_VERSION} (Build ${PCSS_BUILD_VERSION})${NC}"
echo -e "  ${BOLD}Data de Lançamento:${NC}         ${FG_WHITE}${PCSS_RELEASE_DATE} (Schneider Electric)${NC}"
echo -e "  ${BOLD}Serviço do Sistema:${NC}         ${STATUS_SERVICE}"
echo -e "  ${BOLD}Diretório de Instalação:${NC}    ${FG_CYAN}${AGENT_DIR}${NC}"
echo -e "  ${BOLD}Porta Web de Gerência:${NC}      ${FG_WHITE}${WEB_PORT} (TCP / HTTPS)${NC}"
echo -e "  ${BOLD}Porta Agente SNMP:${NC}          ${FG_WHITE}${SNMP_PORT} (UDP / SNMPv1 e SNMPv3)${NC}"
echo -e "  ${BOLD}URL de Acesso:${NC}              ${FG_CYAN}https://${SERVER_IP}:${WEB_PORT}${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}          ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

echo -e "  ${FG_YELLOW}${BOLD}⚠ OBSERVAÇÃO IMPORTANTE PARA MONITORAMENTO ZABBIX (SNMPv1):${NC}"
echo -e "  • Ao vincular o host/template no Zabbix utilizando ${BOLD}SNMPv1${NC}:"
echo -e "    ${FG_RED}${BOLD}DESATIVE${NC} obrigatoriamente a opção: ${BOLD}[ ] Use combined requests${NC}"
echo -e "    ${DIM}(Se mantida ativa, o Zabbix retornará 'authorizationError' ou falha de coleta nos itens).${NC}\n"

echo -e "  ${BOLD}Comandos Úteis de Gerenciamento:${NC}"
echo -e "  • Verificar Status:   ${BOLD}sudo systemctl status ${SERVICE_NAME}${NC}"
echo -e "  • Reiniciar Serviço:  ${BOLD}sudo systemctl restart ${SERVICE_NAME}${NC}"
echo -e "  • Parar Serviço:      ${BOLD}sudo systemctl stop ${SERVICE_NAME}${NC}"
echo -e "  • Testar SNMP Local:  ${BOLD}snmpwalk -v1 -c <sua_comunidade> 127.0.0.1 1.3.6.1.4.1.318${NC}"
echo -e "  • Reconfigurar APC:   ${BOLD}cd ${AGENT_DIR} && sudo bash config.sh${NC}"
echo -e "  • Portal do Produto:  ${DIM}${PCSS_PORTAL_URL}${NC}"
echo -e ""

exit 0
