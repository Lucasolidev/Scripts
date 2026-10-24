#!/bin/bash
# ------------------------------------------------
# Version: 2.4
# ------------------------------------------------
VERSION="2.4"
# ==============================================================================
# AUDITORIA, VARREDURA E INVENTÁRIO 360° DO SERVIDOR LINUX (MULTI-DISTRO)
# ==============================================================================
# Script: auditoria_servidor_inventario.sh
# Descrição: Raio-X completo e 100% passivo (somente leitura) organizado por:
#            1. Sistema Operacional, Atualizações Pendentes e Reboot Pendente;
#            2. Usuários Ativos, Grupos Pertencentes, Sudos e LDAP/AD;
#            3. Armazenamento, Unidades no FSTAB, NFS e SAMBA (Cliente/Servidor);
#            4. Aplicações, Web, PHP Profundo, Runtimes, CMSs e Containers;
#            5. Bancos de Dados (Quais, Versões, Datadir, Tamanhos e Schemas);
#            6. Firewall (Ativo/Inativo), Regras de Filtragem e Segurança;
#            7. Portas Abertas (LISTEN), Rede, /etc/hosts e Conexões Ativas;
#            8. Crontabs, Systemd Timers, Scripts e Backups Locais.
#            Grava o relatório exclusivamente na Home do usuário executor.
# Autor: Lucas Oliveira
# Repositório: https://github.com/Lucasolidev/Scripts
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/auditoria_servidor_inventario.sh -O auditoria_servidor_inventario.sh && sudo chmod +x auditoria_servidor_inventario.sh && sudo ./auditoria_servidor_inventario.sh
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Sistema Operacional: Identifica distro, versão, kernel, hardware/VM, verifica se está atualizado, lista quais pacotes estão pendentes e se aguarda reinicialização (reboot required).
# 2. Usuários, Grupos, Sudo e LDAP/AD: Lista usuários ativos e todos os grupos a que pertencem, quem são os usuários/grupos sudo, histórico de acessos e integração LDAP/Active Directory/SSSD/Winbind.
# 3. Armazenamento, FSTAB, NFS e SAMBA: Mostra discos/partições, valida todas as entradas do /etc/fstab (montadas ou não), mapeia cliente/servidor NFS (/etc/exports) e cliente/servidor Samba (smb.conf shares).
# 4. Aplicações (Quais e Versões): Inventaria Servidores Web (Apache, Nginx, Caddy, HAProxy, Tomcat), PHP (CLI, FPM, CGI, mod_php, php.ini, CVEs/EOL), Runtimes (Node, Python, Java, .NET, Go), CMSs/Sistemas no disco (Joomla, WordPress, Laravel, GLPI, Zabbix, Moodle, Nextcloud, etc.) e Contêineres Docker/Podman (inspeção interna).
# 5. Bancos de Dados (Quais, Versões e Relevantes): Detecta MariaDB/MySQL, PostgreSQL, Redis, MongoDB, Firebird, MSSQL, SQLite, mostrando versão, status, porta/bind, datadir, tamanho em disco e schemas/bases criadas.
# 6. Firewall e Segurança: Verifica se o Firewall está ativo ou inativo (UFW, Firewalld, NFTables, IPTables), lista as regras reais configuradas, audita SSH, Fail2Ban, SELinux/AppArmor e unidades systemd com falha.
# 7. Portas Abertas e Rede: Lista todas as portas TCP/UDP abertas com PID, processo, serviço systemd e diretório (CWD), além de IPs, rotas, DNS, /etc/hosts e conexões estabelecidas.
# 8. Automação, Scripts, Backups e Resumo Executivo: Lista crontabs, timers, scripts locais (.sh/.py), dumps/backups (.sql/.tar.gz) e salva o relatório limpo apenas na Home de quem executou.
# ==============================================================================

set -Eeuo pipefail
umask 077

export VERSION
export DEBIAN_FRONTEND=noninteractive
if locale -a 2>/dev/null | grep -qiE '^C\.utf-?8$'; then
    export LC_ALL=C.UTF-8
else
    export LC_ALL=C
fi
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==============================================================================
# 1 - INICIALIZAÇÃO E FUNÇÕES BASE (100% SOMENTE LEITURA NO SISTEMA)
# ==============================================================================

# 1.1 - PALETA DE CORES E ESTILOS (ANSI)
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_CYAN='\033[36m'
FG_WHITE='\033[37m'

ARROW="❯"

# 1.2 - FUNÇÕES AUXILIARES DE VISUAL E DETECÇÃO MULTI-DISTRO DE SERVIÇOS
draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}❯ ${FG_WHITE}${title}${NC}"
    draw_separator
}

get_service_status_plain() {
    local service="$1"
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            printf 'Ativo'
            return 0
        elif systemctl list-unit-files "${service}.service" 2>/dev/null | grep -q "^${service}\.service" ||
             [[ -f "/lib/systemd/system/${service}.service" || -f "/usr/lib/systemd/system/${service}.service" || -f "/etc/systemd/system/${service}.service" ]]; then
            printf 'Inativo'
            return 0
        fi
    fi
    if [[ -x "/etc/init.d/${service}" ]]; then
        if "/etc/init.d/${service}" status >/dev/null 2>&1; then
            printf 'Ativo'
        else
            printf 'Inativo'
        fi
        return 0
    fi
    printf 'Não instalado'
}

get_service_status() {
    local service="$1"
    local plain
    plain=$(get_service_status_plain "$service")
    case "$plain" in
        Ativo)   echo -e "${FG_GREEN}Ativo${NC}" ;;
        Inativo) echo -e "${FG_YELLOW}Inativo${NC}" ;;
        *)       echo -e "${DIM}Não instalado${NC}" ;;
    esac
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
# shellcheck disable=SC2317,SC2329
log_skipped() { echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }
log_item()    { echo -e "    • ${BOLD}$1:${NC} $2"; }

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

print_summary() {
    local label="$1"
    local val="$2"
    local color="${3:-$FG_CYAN}"
    local padding=$((28 - ${#label}))
    if (( padding < 1 )); then padding=1; fi
    printf '  %b%s%*s%b%b%s%b\n' "$BOLD" "$label" "$padding" '' "$NC" "$color" "$val" "$NC"
}

# Arrays acumuladoras para o Resumo Executivo
PAPEIS_DETECTADOS=()
ALERTAS_AUDITORIA=()
RESUMO_APPS_VERSOES=()
RESUMO_PHP_VERSOES=()
RESUMO_SITES_DETECTADOS=()
RESUMO_BANCOS_ATIVOS=()
RESUMO_CONTAINERS_ATIVOS=()
RESUMO_USUARIOS_SUDO=()
RESUMO_GRUPOS_SUDO=()
RESUMO_STORAGE_REDE=()
PACOTES_INSTALADOS=()

add_role() {
    local role="$1"
    local r
    for r in "${PAPEIS_DETECTADOS[@]:-}"; do
        [[ "$r" == "$role" ]] && return 0
    done
    PAPEIS_DETECTADOS+=("$role")
}

add_alert() {
    ALERTAS_AUDITORIA+=("$1")
}

add_unique_item() {
    local arr_name="$1" val="$2"
    [[ -z "$val" ]] && return 0
    eval "local existing=(\"\${${arr_name}[@]:-}\")"
    local item
    for item in "${existing[@]:-}"; do
        [[ "$item" == "$val" ]] && return 0
    done
    eval "${arr_name}+=(\"\$val\")"
}

# 1.3 - FUNÇÕES DE ESCRITA EXCLUSIVA NA HOME DO EXECUTOR (NADA FORA DA HOME É ALTERADO)
# shellcheck disable=SC2317,SC2329
save_direct_report() {
    local src="$1" dest="$2" mode="${3:-600}" tmp
    [[ ! -L "$dest" ]] || return 1
    tmp=$(mktemp "$(dirname "$dest")/.inventario.XXXXXXXX") || return 1
    if ! install -m "$mode" -- "$src" "$tmp" || ! mv -fT -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# shellcheck disable=SC2317,SC2329,SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 1
    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
            set -eu
            umask 077
            cd -- "$1"
            tmp=$(mktemp .inventario.XXXXXXXX)
            trap '\''rm -f -- "$tmp"'\'' EXIT
            cat > "$tmp"
            mv -fT -- "$tmp" "$2"
        ' bash "$home_dir" "$name" < "$src"
    else
        su -s /bin/bash "$user" -c "umask 077 && cd -- '$home_dir' && cat > '$name'" < "$src"
    fi
}

# shellcheck disable=SC2317,SC2329
finalizar() {
    local rc="$1" saved_any=0
    trap - EXIT ERR INT TERM HUP
    set +e

    if [[ -n "${TEE_PID:-}" ]]; then
        exec 1>&3 2>&4
        wait "$TEE_PID" 2>/dev/null || true
    fi

    if [[ -f "${LOG_FILE:-}" ]]; then
        sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g' "$LOG_FILE" > "$CLEAN_LOG_FILE" 2>/dev/null || cp "$LOG_FILE" "$CLEAN_LOG_FILE"

        echo -e ""
        print_header "9. GERAÇÃO E SALVAMENTO DO RELATÓRIO NA HOME DO EXECUTOR"

        if [[ -n "${EXECUTOR_HOME:-}" && -d "$EXECUTOR_HOME" ]]; then
            if [[ "$(id -u)" -eq 0 && -n "${EXECUTOR_USER:-}" && "$EXECUTOR_USER" != "root" ]] && id "$EXECUTOR_USER" >/dev/null 2>&1; then
                if copy_to_home "$EXECUTOR_USER" "$EXECUTOR_HOME" "$CLEAN_LOG_FILE" "$LOG_FILENAME" &&
                   copy_to_home "$EXECUTOR_USER" "$EXECUTOR_HOME" "$CLEAN_LOG_FILE" "$LOG_LATEST"; then
                    saved_any=1
                    log_success "Relatório salvo na Home de ${EXECUTOR_USER}: ${FG_CYAN}${EXECUTOR_HOME}/${LOG_FILENAME}${NC}"
                    log_info "Atalho atualizado: ${FG_CYAN}${EXECUTOR_HOME}/${LOG_LATEST}${NC}"
                else
                    log_warning "Não foi possível gravar na Home (${EXECUTOR_HOME})."
                fi
            else
                if save_direct_report "$CLEAN_LOG_FILE" "${EXECUTOR_HOME}/${LOG_FILENAME}" 600 &&
                   save_direct_report "$CLEAN_LOG_FILE" "${EXECUTOR_HOME}/${LOG_LATEST}" 600; then
                    saved_any=1
                    log_success "Relatório salvo na Home (${EXECUTOR_USER}): ${FG_CYAN}${EXECUTOR_HOME}/${LOG_FILENAME}${NC}"
                    log_info "Atalho atualizado: ${FG_CYAN}${EXECUTOR_HOME}/${LOG_LATEST}${NC}"
                else
                    log_warning "Não foi possível gravar na Home (${EXECUTOR_HOME})."
                fi
            fi
        fi

        if (( saved_any )); then
            rm -rf -- "$LOG_DIR" 2>/dev/null || true
        else
            log_warning "Relatório temporário mantido em: ${CLEAN_LOG_FILE}"
        fi
    fi

    draw_separator
    echo -e "  ${DIM}Varredura concluída em: $(date '+%d/%m/%Y %H:%M:%S') (Código: ${rc})${NC}\n"
    exit "$rc"
}

# ==============================================================================
# 2 - COLETA DE PARÂMETROS, IDENTIFICAÇÃO DO EXECUTOR E PRIVILÉGIOS
# ==============================================================================
IS_ROOT=0
if [[ "$(id -u)" -eq 0 ]]; then
    IS_ROOT=1
else
    print_header "COLETA DE PARÂMETROS E PRIVILÉGIOS"
    print_alert_box "Recomenda-se executar com ROOT (sudo) para auditar todos os processos, contêineres, bancos, firewall e sudoers."
    echo -e "  Comando recomendado: ${FG_YELLOW}sudo ./$(basename "$0")${NC}\n"
    if [[ -t 0 ]]; then
        read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja continuar a auditoria com privilégios limitados? (s/N): ${NC}")" CONTINUAR_SEM_ROOT || true
        if [[ ! "${CONTINUAR_SEM_ROOT:-}" =~ ^[Ss]$ ]]; then
            log_info "Resposta selecionada: Não"
            log_error "Execução cancelada pelo operador para reexecução com sudo."
            exit 2
        fi
        log_info "Modo de execução definido: ${FG_YELLOW}Usuário comum (Leitura parcial)${NC}"
    else
        log_warning "Terminal não-interativo detectado; prosseguindo com leitura parcial sem root."
    fi
    add_alert "Auditoria executada sem privilégios de root (PIDs de portas, docker, bancos, firewall, sudoers e crontabs podem estar incompletos)."
fi

EXECUTOR_USER="${SUDO_USER:-$(id -un 2>/dev/null || echo root)}"
EXECUTOR_HOME=$(getent passwd "$EXECUTOR_USER" 2>/dev/null | cut -d: -f6 || true)
[[ -z "$EXECUTOR_HOME" || ! -d "$EXECUTOR_HOME" ]] && EXECUTOR_HOME="${HOME:-/tmp}"

HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname 2>/dev/null || uname -n 2>/dev/null || echo "servidor")
HOSTNAME_SHORT=$(echo "$HOSTNAME_SHORT" | tr -cd 'a-zA-Z0-9_-')
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_inventario_${HOSTNAME_SHORT}_${LOG_TIMESTAMP}.log"
if [[ -e "${EXECUTOR_HOME}/${LOG_FILENAME}" || -L "${EXECUTOR_HOME}/${LOG_FILENAME}" ]]; then
    LOG_FILENAME="relatorio_inventario_${HOSTNAME_SHORT}_${LOG_TIMESTAMP}_$$.log"
fi
LOG_LATEST="relatorio_inventario_latest.log"
LOG_DIR=$(mktemp -d -p /tmp auditoria_inventario.XXXXXXXX)
LOG_FILE="${LOG_DIR}/${LOG_FILENAME}.raw"
CLEAN_LOG_FILE="${LOG_DIR}/${LOG_FILENAME}"
touch "$LOG_FILE"

exec 3>&1 4>&2
exec > >(tee -a "$LOG_FILE") 2>&1
TEE_PID=$!

trap 'finalizar "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if [[ -t 1 ]] && [[ -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]; then
    clear 2>/dev/null || true
fi

echo -e "\n${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "${FG_CYAN}${BOLD}   AUDITORIA 360°, VARREDURA E INVENTÁRIO DO SERVIDOR LINUX     ${NC}"
echo -e "${FG_CYAN}${BOLD}   SO, USUÁRIOS/SUDO, STORAGE, APPS, BANCOS, FIREWALL E PORTAS  ${NC}"
echo -e "${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "  ${DIM}Versão do Script:${NC}  v${VERSION} (Multi-Distro + Inspeção 360° Host & Containers)"
echo -e "  ${DIM}Data da Varredura:${NC} $(date '+%d/%m/%Y %H:%M:%S')"
echo -e "  ${DIM}Hostname / FQDN:${NC}   $(hostname -f 2>/dev/null || hostname 2>/dev/null || uname -n)"
echo -e "  ${DIM}Executor / Destino:${NC} ${EXECUTOR_USER} (${EXECUTOR_HOME}/${LOG_FILENAME})"
echo -e "  ${DIM}Modo de Execução:${NC}  100% Passivo / Somente Leitura (Nenhuma alteração no SO)\n"

# ==============================================================================
# SEÇÃO 1 - SISTEMA OPERACIONAL, HARDWARE, ATUALIZAÇÕES PENDENTES E REBOOT
# ==============================================================================
print_header "1. SISTEMA OPERACIONAL, ATUALIZAÇÕES PENDENTES E REINICIALIZAÇÃO"

# 1.1 - Identificação da Distribuição (Ubuntu, Debian, RHEL, CentOS, Rocky, Alma, SUSE, Alpine)
OS_NAME="Desconhecido"
OS_FAMILY="generic"
if [[ -r /etc/os-release ]]; then
    OS_NAME=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"'\''')
    OS_ID_RAW=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"'\''' | tr '[:upper:]' '[:lower:]')
    OS_LIKE_RAW=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | tr -d '"'\''' | tr '[:upper:]' '[:lower:]')
    if [[ "$OS_ID_RAW" =~ ^(debian|ubuntu|kali|linuxmint|raspbian|proxmox)$ ]] || [[ "$OS_LIKE_RAW" == *debian* ]]; then
        OS_FAMILY="debian"
    elif [[ "$OS_ID_RAW" =~ ^(rhel|centos|rocky|almalinux|ol|fedora|amzn)$ ]] || [[ "$OS_LIKE_RAW" =~ (rhel|fedora|centos) ]]; then
        OS_FAMILY="rhel"
    elif [[ "$OS_ID_RAW" =~ ^(sles|opensuse|opensuse-leap|opensuse-tumbleweed)$ ]] || [[ "$OS_LIKE_RAW" == *suse* ]]; then
        OS_FAMILY="suse"
    elif [[ "$OS_ID_RAW" == "alpine" ]]; then
        OS_FAMILY="alpine"
    fi
elif [[ -f /etc/redhat-release ]]; then
    OS_NAME=$(cat /etc/redhat-release)
    OS_FAMILY="rhel"
elif [[ -f /etc/debian_version ]]; then
    OS_NAME="Debian $(cat /etc/debian_version)"
    OS_FAMILY="debian"
fi

KERNEL_VER=$(uname -r)
ARCH=$(uname -m)
UPTIME_STR=$(uptime -p 2>/dev/null || uptime)
LAST_BOOT=$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || echo "N/A")
LOAD_AVG=$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg 2>/dev/null || echo "N/A")

# 1.2 - Identidade Física / Hypervisor / Fabricante / UUID
VIRT_TYPE="Físico / Bare-Metal"
if grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
    VIRT_TYPE="WSL (Windows Subsystem for Linux)"
elif command -v systemd-detect-virt >/dev/null 2>&1; then
    DETECTED_VIRT=$(systemd-detect-virt 2>/dev/null || true)
    [[ -n "$DETECTED_VIRT" && "$DETECTED_VIRT" != "none" ]] && VIRT_TYPE="Virtualizado / Container (${DETECTED_VIRT})"
fi

SYS_VENDOR=""
PRODUCT_NAME=""
PRODUCT_UUID=""
PRODUCT_SERIAL=""
[[ -r /sys/class/dmi/id/sys_vendor ]] && SYS_VENDOR=$(xargs < /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_name ]] && PRODUCT_NAME=$(xargs < /sys/class/dmi/id/product_name 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_uuid ]] && PRODUCT_UUID=$(xargs < /sys/class/dmi/id/product_uuid 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_serial ]] && PRODUCT_SERIAL=$(xargs < /sys/class/dmi/id/product_serial 2>/dev/null || true)
HW_IDENTITY="${SYS_VENDOR:-Genérico}${PRODUCT_NAME:+ ${PRODUCT_NAME}}"

TZ_VAL="Desconhecido"
NTP_SYNC="Não verificado"
if command -v timedatectl >/dev/null 2>&1; then
    TZ_VAL=$(timedatectl show -p Timezone --value 2>/dev/null || echo "Desconhecido")
    if [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)" == "yes" ]]; then
        NTP_SYNC="${FG_GREEN}Sincronizado${NC}"
    else
        NTP_SYNC="${FG_YELLOW}Não sincronizado${NC}"
    fi
elif [[ -f /etc/timezone ]]; then
    TZ_VAL=$(cat /etc/timezone 2>/dev/null || echo "Desconhecido")
elif [[ -L /etc/localtime ]]; then
    TZ_VAL=$(readlink -f /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "Desconhecido")
fi

# 1.3 - Hardware (CPU e Memória)
CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | xargs || lscpu 2>/dev/null | awk -F: '/Model name/ {print $2}' | xargs || echo "Desconhecido")
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")

MEM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')
SWAP_TOTAL=$(free -h 2>/dev/null | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -h 2>/dev/null | awk '/^Swap:/ {print $3}')

log_item "Sistema Operacional" "${FG_GREEN}${BOLD}${OS_NAME}${NC} (${ARCH} | Família: ${OS_FAMILY^^})"
log_item "Ambiente / Host"     "${FG_CYAN}${VIRT_TYPE}${NC} — Hardware/VM: ${BOLD}${HW_IDENTITY}${NC}"
[[ -n "$PRODUCT_UUID" || -n "$PRODUCT_SERIAL" ]] && log_item "UUID / Serial VM" "UUID: ${FG_CYAN}${PRODUCT_UUID:-Requer root}${NC} | Serial: ${PRODUCT_SERIAL:-Requer root}"
log_item "Kernel em Execução"  "${KERNEL_VER}"
log_item "Tempo de Atividade"  "${UPTIME_STR} (Último Boot: ${LAST_BOOT} | Load Avg: ${LOAD_AVG})"
log_item "Fuso Horário / NTP"  "${TZ_VAL} (NTP: ${NTP_SYNC})"
log_item "Processador (CPU)"   "${CPU_MODEL:-Desconhecido} (${CPU_CORES} vCPU/Core(s))"
log_item "Memória RAM"         "${MEM_TOTAL:-N/A} Total (Em uso: ${MEM_USED:-N/A} | Disponível: ${MEM_AVAIL:-N/A})"
log_item "Memória Swap"        "${SWAP_TOTAL:-N/A} Total (Em uso: ${SWAP_USED:-0B})"

# 1.4 - O Sistema está atualizado? Quais atualizações estão pendentes?
echo -e "\n  ${BOLD}Status de Atualização do Sistema Operacional e Pacotes Pendentes:${NC}"
PENDING_UPDATES_COUNT=0
CRITICAL_PKGS_PENDING=""
PENDING_LIST_DETAILS=""
APT_SIM=""

if command -v apt-get >/dev/null 2>&1; then
    APT_SIM=$(apt-get -s upgrade 2>/dev/null || true)
    PENDING_UPDATES_COUNT=$(echo "$APT_SIM" | grep -c "^Inst " || true)
    PENDING_LIST_DETAILS=$(echo "$APT_SIM" | awk '/^Inst / {print $2 " " $3 " -> " $4}' || true)
    CRITICAL_PKGS_PENDING=$(echo "$APT_SIM" | awk '/^Inst / {print $2}' | grep -E '^(php|libapache2-mod-php|apache2|nginx|mariadb|mysql|postgresql|openssh|openssl|linux-image|docker|samba|bind9|sudo)' | xargs || true)
elif command -v dnf >/dev/null 2>&1; then
    DNF_SIM=$(dnf check-update -q --cacheonly 2>/dev/null || true)
    PENDING_UPDATES_COUNT=$(echo "$DNF_SIM" | awk 'NF>=3 && $1 !~ /^(Last|Obsoleting|Security:)/ {count++} END {print count+0}')
    PENDING_LIST_DETAILS=$(echo "$DNF_SIM" | awk 'NF>=3 && $1 !~ /^(Last|Obsoleting|Security:)/ {print $1 " -> " $2 " (" $3 ")"}' || true)
    CRITICAL_PKGS_PENDING=$(echo "$DNF_SIM" | awk 'NF>=3 {print $1}' | grep -E '^(php|httpd|nginx|mariadb|mysql|postgresql|openssh|openssl|kernel|docker|samba|bind|sudo)' | xargs || true)
elif command -v yum >/dev/null 2>&1; then
    YUM_SIM=$(yum check-update -q -C 2>/dev/null || true)
    PENDING_UPDATES_COUNT=$(echo "$YUM_SIM" | awk 'NF>=3 && $1 !~ /^(Loaded|Obsoleting|Security:)/ {count++} END {print count+0}')
    PENDING_LIST_DETAILS=$(echo "$YUM_SIM" | awk 'NF>=3 && $1 !~ /^(Loaded|Obsoleting|Security:)/ {print $1 " -> " $2 " (" $3 ")"}' || true)
    CRITICAL_PKGS_PENDING=$(echo "$YUM_SIM" | awk 'NF>=3 {print $1}' | grep -E '^(php|httpd|nginx|mariadb|mysql|postgresql|openssh|openssl|kernel|docker|samba|bind|sudo)' | xargs || true)
elif command -v zypper >/dev/null 2>&1; then
    ZYP_SIM=$(zypper --non-interactive list-updates 2>/dev/null | awk -F'|' 'NR>4 && NF>=5 {gsub(/^[ \t]+|[ \t]+$/, "", $3); gsub(/^[ \t]+|[ \t]+$/, "", $4); gsub(/^[ \t]+|[ \t]+$/, "", $5); if ($3!="") print $3 " (" $4 " -> " $5 ")"}' || true)
    if [[ -n "$ZYP_SIM" ]]; then
        PENDING_UPDATES_COUNT=$(echo "$ZYP_SIM" | wc -l)
        PENDING_LIST_DETAILS="$ZYP_SIM"
    fi
elif command -v apk >/dev/null 2>&1; then
    APK_SIM=$(apk version -l '<' 2>/dev/null | grep -v '^Installed:' || true)
    if [[ -n "$APK_SIM" ]]; then
        PENDING_UPDATES_COUNT=$(echo "$APK_SIM" | wc -l)
        PENDING_LIST_DETAILS="$APK_SIM"
    fi
fi

OS_UPDATE_STATUS_STR="ATUALIZADO (0 pacotes pendentes)"
if (( PENDING_UPDATES_COUNT > 0 )); then
    OS_UPDATE_STATUS_STR="DESATUALIZADO (${PENDING_UPDATES_COUNT} pacotes pendentes)"
    log_item "Situação do SO" "${FG_YELLOW}${BOLD}DESATUALIZADO${NC} — Existem ${FG_YELLOW}${BOLD}${PENDING_UPDATES_COUNT}${NC} pacote(s) aguardando atualização (cache local)"
    if [[ -n "$CRITICAL_PKGS_PENDING" ]]; then
        log_warning "Atualizações de pacotes críticos pendentes: ${FG_YELLOW}${CRITICAL_PKGS_PENDING}${NC}"
        add_alert "Servidor com ${PENDING_UPDATES_COUNT} atualizações pendentes (Críticos: ${CRITICAL_PKGS_PENDING})."
    else
        add_alert "Servidor possui ${PENDING_UPDATES_COUNT} pacote(s) pendente(s) de atualização."
    fi
    if [[ -n "$PENDING_LIST_DETAILS" ]]; then
        echo -e "    • ${BOLD}Lista de Atualizações Pendentes (Top 25):${NC}"
        while IFS= read -r upd_line; do
            [[ -z "$upd_line" ]] && continue
            echo -e "      ├─ ${FG_YELLOW}${upd_line}${NC}"
        done < <(echo "$PENDING_LIST_DETAILS" | head -n 25)
        if (( PENDING_UPDATES_COUNT > 25 )); then
            echo -e "      └─ ${DIM}... e mais $((PENDING_UPDATES_COUNT - 25)) pacote(s) pendente(s).${NC}"
        fi
    fi
else
    log_item "Situação do SO" "${FG_GREEN}${BOLD}ATUALIZADO${NC} — 0 pacotes pendentes no cache local do gerenciador de pacotes"
fi

# 1.5 - O Servidor está aguardando reinicialização (Reboot Required)?
REBOOT_NEEDED="Não"
REBOOT_REASON=""
REBOOT_PKGS=""
if [[ -f /var/run/reboot-required ]]; then
    REBOOT_NEEDED="Sim"
    REBOOT_REASON="Sinalizado em /var/run/reboot-required"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        REBOOT_PKGS=$(sort -u /var/run/reboot-required.pkgs 2>/dev/null | paste -sd ', ' - || true)
    fi
elif command -v needs-restarting >/dev/null 2>&1; then
    if ! needs-restarting -r >/dev/null 2>&1; then
        REBOOT_NEEDED="Sim"
        REBOOT_REASON="Sinalizado por needs-restarting -r (Kernel ou bibliotecas core)"
    fi
fi

if [[ "$REBOOT_NEEDED" == "Não" && "$VIRT_TYPE" != WSL* ]] && compgen -G "/boot/vmlinuz-*" >/dev/null 2>&1; then
    LATEST_BOOT_KERNEL=$(find /boot -maxdepth 1 -name "vmlinuz-*" ! -name "*rescue*" 2>/dev/null | sed 's|/boot/vmlinuz-||' | sort -V | tail -n 1 || true)
    if [[ -n "$LATEST_BOOT_KERNEL" && "$LATEST_BOOT_KERNEL" != "$KERNEL_VER" ]]; then
        REBOOT_NEEDED="Sim"
        REBOOT_REASON="Kernel novo instalado aguarda boot (Atual: ${KERNEL_VER} -> Novo: ${LATEST_BOOT_KERNEL})"
    fi
fi

if [[ "$REBOOT_NEEDED" == "Sim" ]]; then
    log_item "Aguardando Reboot?" "${FG_RED}${BOLD}SIM — REINICIALIZAÇÃO PENDENTE${NC} (${REBOOT_REASON})"
    [[ -n "$REBOOT_PKGS" ]] && log_item "Pacotes que pedem Reboot" "${FG_YELLOW}${REBOOT_PKGS}${NC}"
    add_alert "O servidor está aguardando reinicialização (${REBOOT_REASON}${REBOOT_PKGS:+: $REBOOT_PKGS})."
else
    log_item "Aguardando Reboot?" "${FG_GREEN}${BOLD}NÃO${NC} (Nenhuma reinicialização pendente)"
fi

echo -e "\n  ${BOLD}Top 5 Processos por Consumo de Memória / CPU Agora:${NC}"
ps -eo pid,user,%cpu,%mem,comm --sort=-%mem 2>/dev/null | head -n 6 | awk '
    NR==1 {printf "    %-8s %-14s %-8s %-8s %s\n", "PID", "USUÁRIO", "%CPU", "%MEM", "PROCESSO"}
    NR>1  {printf "    %-8s %-14s %-8s %-8s %s\n", $1, $2, $3, $4, $5}
' || true

# ==============================================================================
# SEÇÃO 2 - USUÁRIOS ATIVOS, GRUPOS PERTENCENTES, SUDOERS E DIRETÓRIO (LDAP/AD)
# ==============================================================================
print_header "2. USUÁRIOS ATIVOS, GRUPOS PERTENCENTES, SUDOERS E AUTENTICAÇÃO (LDAP/AD)"

# 2.1 - Usuários Ativos com Shell de Login e todos os Grupos aos quais pertencem
echo -e "  ${BOLD}Usuários Ativos no Sistema (Com Shell de Login) e Grupos a que Pertencem:${NC}"
ACTIVE_USERS_COUNT=0
while IFS=: read -r u_name _ u_uid _ _ u_home u_shell; do
    [[ -z "$u_name" ]] && continue
    if (( u_uid == 0 || (u_uid >= 1000 && u_uid < 65534) )) && [[ ! "$u_shell" =~ (nologin|false|sync|halt|shutdown)$ ]]; then
        ACTIVE_USERS_COUNT=$((ACTIVE_USERS_COUNT + 1))
        U_GROUPS=$(id -Gn "$u_name" 2>/dev/null | tr ' ' ', ' || echo "N/A")
        PASS_STATE="Não verificado"
        if (( IS_ROOT == 1 )) && command -v passwd >/dev/null 2>&1; then
            P_RAW=$(passwd -S "$u_name" 2>/dev/null | awk '{print $2}' || true)
            case "$P_RAW" in
                P|PS) PASS_STATE="${FG_GREEN}Conta Ativa (Com Senha)${NC}" ;;
                L|LK) PASS_STATE="${FG_RED}Conta Bloqueada (Locked)${NC}" ;;
                NP)   PASS_STATE="${FG_YELLOW}Sem Senha Definida${NC}" ;;
                *)    PASS_STATE="${P_RAW:-Ativa}" ;;
            esac
        fi
        SSH_KEYS_INFO="Nenhuma"
        if [[ -r "${u_home}/.ssh/authorized_keys" ]]; then
            K_COUNT=$(grep -cE "^(ssh-|ecdsa-)" "${u_home}/.ssh/authorized_keys" 2>/dev/null || echo 0)
            (( K_COUNT > 0 )) && SSH_KEYS_INFO="${FG_GREEN}${K_COUNT} chave(s) SSH autorizada(s)${NC}"
        fi
        echo -e "    • Usuário: ${FG_CYAN}${BOLD}${u_name}${NC} (UID: ${u_uid}) | Status: ${PASS_STATE} | Home: ${u_home} | Shell: ${DIM}${u_shell}${NC}"
        echo -e "      ├─ ${BOLD}Grupos a que pertence:${NC} ${FG_YELLOW}${U_GROUPS}${NC}"
        echo -e "      └─ ${BOLD}Chaves SSH:${NC}            ${SSH_KEYS_INFO}"
    fi
done < /etc/passwd

# 2.2 - Quem são os Sudos? (Grupos Administrativos e Regras em /etc/sudoers)
echo -e "\n  ${BOLD}Quem são os Sudos? (Grupos de Administração: sudo, wheel, admin, adm, docker, lxd):${NC}"
for priv_grp in sudo wheel admin adm docker lxd; do
    GRP_ENTRY=$(getent group "$priv_grp" 2>/dev/null || true)
    [[ -z "$GRP_ENTRY" ]] && continue
    GRP_GID=$(echo "$GRP_ENTRY" | cut -d: -f3)
    GRP_USERS=$(echo "$GRP_ENTRY" | cut -d: -f4 | tr ',' ' ' | xargs || true)
    PRI_USERS=$(awk -F: -v gid="$GRP_GID" '$4 == gid {print $1}' /etc/passwd 2>/dev/null | xargs || true)
    ALL_GRP_MEMBERS=$(echo "${GRP_USERS} ${PRI_USERS}" | xargs -n1 2>/dev/null | sort -u | xargs || true)

    echo -e "    • Grupo ${FG_YELLOW}${BOLD}${priv_grp}${NC} (GID ${GRP_GID}): Membros -> ${FG_GREEN}${BOLD}${ALL_GRP_MEMBERS:-Nenhum membro cadastrado}${NC}"
    if [[ "$priv_grp" =~ ^(sudo|wheel|admin)$ ]]; then
        add_unique_item RESUMO_GRUPOS_SUDO "%${priv_grp} (${ALL_GRP_MEMBERS:-vazio})"
        for m_usr in $ALL_GRP_MEMBERS; do
            add_unique_item RESUMO_USUARIOS_SUDO "${m_usr} (grupo ${priv_grp})"
        done
    elif [[ "$priv_grp" == "docker" && -n "$ALL_GRP_MEMBERS" ]]; then
        for m_usr in $ALL_GRP_MEMBERS; do
            add_unique_item RESUMO_USUARIOS_SUDO "${m_usr} (grupo docker/root-equiv)"
        done
    fi
done

echo -e "\n  ${BOLD}Permissões Explícitas de Sudoers (/etc/sudoers e /etc/sudoers.d/*):${NC}"
if [[ -r /etc/sudoers ]]; then
    SUDOERS_FILES=("/etc/sudoers")
    if [[ -d /etc/sudoers.d ]]; then
        for sd_file in /etc/sudoers.d/*; do
            [[ -f "$sd_file" ]] || continue
            [[ "$(basename "$sd_file")" == "README" || "$sd_file" == *~ || "$sd_file" == *.bak ]] && continue
            SUDOERS_FILES+=("$sd_file")
        done
    fi

    SUDO_RULES_COUNT=0
    for s_file in "${SUDOERS_FILES[@]}"; do
        [[ -r "$s_file" ]] || continue
        while IFS= read -r s_line; do
            [[ -z "$s_line" ]] && continue
            SUDO_RULES_COUNT=$((SUDO_RULES_COUNT + 1))
            ENTITY=$(echo "$s_line" | awk '{print $1}')
            echo -e "    • [${FG_CYAN}$(basename "$s_file")${NC}] ${BOLD}${ENTITY}${NC} -> ${DIM}${s_line}${NC}"
            if [[ "$ENTITY" == %* ]]; then
                GRP_CLEAN="${ENTITY#%}"
                GRP_MEM=$(getent group "$GRP_CLEAN" 2>/dev/null | cut -d: -f4 | tr ',' ' ' | xargs || true)
                add_unique_item RESUMO_GRUPOS_SUDO "${ENTITY} (${GRP_MEM:-vazio})"
                for gm in $GRP_MEM; do
                    add_unique_item RESUMO_USUARIOS_SUDO "${gm} (grupo ${GRP_CLEAN})"
                done
            elif [[ "$ENTITY" != "Defaults"* && "$ENTITY" != "@include"* && "$ENTITY" != "User_Alias" && "$ENTITY" != "Cmnd_Alias" && "$ENTITY" != "Host_Alias" && "$ENTITY" != "Runas_Alias" ]]; then
                add_unique_item RESUMO_USUARIOS_SUDO "${ENTITY} (regra direta em $(basename "$s_file"))"
            fi
        done < <(grep -vE "^\s*#|^\s*$|^\s*@include|^\s*Defaults|^\s*(User|Runas|Host|Cmnd)_Alias" "$s_file" 2>/dev/null || true)
    done
    (( SUDO_RULES_COUNT == 0 )) && echo -e "    • Nenhuma regra explícita ativa encontrada."
else
    echo -e "    • ${FG_YELLOW}Sem permissão de leitura em /etc/sudoers (requer sudo/root).${NC}"
fi

# 2.3 - Sessões Conectadas Agora e Últimos Logins
ACTIVE_WHO=$(who 2>/dev/null || true)
if [[ -n "$ACTIVE_WHO" ]]; then
    echo -e "\n  ${BOLD}Usuários Conectados Neste Momento (who):${NC}"
    while IFS= read -r w_line; do
        echo -e "    • ${FG_GREEN}${w_line}${NC}"
    done <<< "$ACTIVE_WHO"
fi

if command -v last >/dev/null 2>&1; then
    LAST_LOGINS=$(last -n 8 -w 2>/dev/null | grep -vE "^reboot|^wtmp begins|^$" | head -n 5 || true)
    if [[ -n "$LAST_LOGINS" ]]; then
        echo -e "\n  ${BOLD}Histórico dos Últimos Logins no Servidor:${NC}"
        while IFS= read -r l_line; do
            echo -e "    • ${DIM}${l_line}${NC}"
        done <<< "$LAST_LOGINS"
    fi
fi

# 2.4 - Integração com Serviços de Diretório / Autenticação (LDAP, Active Directory, SSSD, Winbind, Kerberos)
echo -e "\n  ${BOLD}Autenticação de Rede e Serviços de Diretório (LDAP / Active Directory / SSSD / Winbind):${NC}"
DIR_AUTH_FOUND=0
NSS_PASSWD=$(awk -F: '/^\s*passwd:/ {gsub(/^[ \t]+/,"",$2); print $2}' /etc/nsswitch.conf 2>/dev/null || true)
[[ -n "$NSS_PASSWD" ]] && echo -e "    • Provedores NSSwitch (passwd): ${FG_CYAN}${NSS_PASSWD}${NC}"

# Verifica Servidor ou Cliente LDAP
if [[ "$(get_service_status_plain slapd)" != "Não instalado" ]] || pgrep -x "slapd" >/dev/null 2>&1; then
    DIR_AUTH_FOUND=1
    echo -e "    • ${FG_GREEN}${BOLD}Servidor OpenLDAP (slapd):${NC} [$(get_service_status slapd)]"
    add_role "Servidor de Diretório LDAP (OpenLDAP)"
fi

for ldap_cfg in /etc/ldap/ldap.conf /etc/openldap/ldap.conf /etc/nslcd.conf /etc/pam_ldap.conf; do
    [[ -r "$ldap_cfg" ]] || continue
    LDAP_URI=$(grep -iE "^\s*URI\s+" "$ldap_cfg" 2>/dev/null | awk '{$1=""; print $0}' | xargs || true)
    LDAP_BASE=$(grep -iE "^\s*BASE\s+" "$ldap_cfg" 2>/dev/null | awk '{$1=""; print $0}' | xargs || true)
    if [[ -n "$LDAP_URI" || -n "$LDAP_BASE" ]]; then
        DIR_AUTH_FOUND=1
        echo -e "    • ${FG_YELLOW}${BOLD}Cliente LDAP Configurado (${ldap_cfg}):${NC} URI=${FG_CYAN}${LDAP_URI:-N/A}${NC} | Base=${FG_CYAN}${LDAP_BASE:-N/A}${NC}"
        add_unique_item RESUMO_STORAGE_REDE "LDAP(${LDAP_URI:-$LDAP_BASE})"
    fi
done

if [[ "$(get_service_status_plain nslcd)" != "Não instalado" ]]; then
    DIR_AUTH_FOUND=1
    echo -e "    • Daemon Cliente LDAP (nslcd): [$(get_service_status nslcd)]"
fi

# Verifica SSSD / Realmd / Active Directory / Winbind / Kerberos
if [[ "$(get_service_status_plain sssd)" != "Não instalado" ]] || [[ -f /etc/sssd/sssd.conf ]]; then
    DIR_AUTH_FOUND=1
    SSSD_DOMAINS=""
    [[ -r /etc/sssd/sssd.conf ]] && SSSD_DOMAINS=$(awk -F'=' '/^\s*domains\s*=/ {gsub(/[ \t]/,"",$2); print $2}' /etc/sssd/sssd.conf 2>/dev/null | head -n 1 || true)
    echo -e "    • ${BOLD}Cliente SSSD (LDAP/AD/FreeIPA):${NC} [$(get_service_status sssd)]${SSSD_DOMAINS:+ — Domínio(s): ${FG_YELLOW}${SSSD_DOMAINS}${NC}}"
    [[ -n "$SSSD_DOMAINS" ]] && add_unique_item RESUMO_STORAGE_REDE "SSSD/AD(${SSSD_DOMAINS})"
fi

if command -v realm >/dev/null 2>&1; then
    REALM_INFO=$(realm list --name-only 2>/dev/null | xargs || true)
    if [[ -n "$REALM_INFO" ]]; then
        DIR_AUTH_FOUND=1
        echo -e "    • ${BOLD}Domínio Active Directory (realmd):${NC} ${FG_YELLOW}${REALM_INFO}${NC}"
        add_unique_item RESUMO_STORAGE_REDE "AD-Realm(${REALM_INFO})"
    fi
fi

if [[ "$(get_service_status_plain winbind)" != "Não instalado" ]]; then
    DIR_AUTH_FOUND=1
    echo -e "    • ${BOLD}Samba Winbind (Integração AD):${NC} [$(get_service_status winbind)]"
fi

if [[ -r /etc/krb5.conf ]]; then
    KRB_REALM=$(awk -F'=' '/^\s*default_realm\s*=/ {gsub(/[ \t]/,"",$2); print $2}' /etc/krb5.conf 2>/dev/null | head -n 1 || true)
    if [[ -n "$KRB_REALM" ]]; then
        DIR_AUTH_FOUND=1
        echo -e "    • ${BOLD}Kerberos Default Realm (/etc/krb5.conf):${NC} ${FG_CYAN}${KRB_REALM}${NC}"
    fi
fi

(( DIR_AUTH_FOUND == 0 )) && echo -e "    • Autenticação exclusivamente local (/etc/passwd e /etc/shadow) — Nenhuma integração LDAP/AD ativa detectada."

# ==============================================================================
# SEÇÃO 3 - ARMAZENAMENTO, UNIDADES NO FSTAB, NFS E SAMBA (CLIENTE E SERVIDOR)
# ==============================================================================
print_header "3. ARMAZENAMENTO, UNIDADES NO FSTAB, NFS E SAMBA (CLIENTE E SERVIDOR)"

# 3.1 - Partições Montadas e Uso de Espaço
echo -e "  ${BOLD}Unidades de Armazenamento Montadas Agora (df -hT):${NC}"
df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk '
    NR==1 {printf "    %-24s %-10s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6, $7}
    NR>1  {printf "    %-24s %-10s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6, $7}
' || df -h 2>/dev/null | sed 's/^/    /' || true

while IFS= read -r disk_line; do
    [[ -z "$disk_line" ]] && continue
    USE_PCT=$(echo "$disk_line" | awk '{gsub(/%/,"",$5); print $5}')
    MNT_PT=$(echo "$disk_line" | awk '{print $6}')
    if [[ "$USE_PCT" =~ ^[0-9]+$ ]] && (( USE_PCT >= 85 )); then
        log_warning "Partição ${MNT_PT} está com uso elevado: ${USE_PCT}%"
        add_alert "Disco com uso crítico (${USE_PCT}%) na partição ${MNT_PT}."
    fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1')

if command -v lsblk >/dev/null 2>&1; then
    echo -e "\n  ${BOLD}Topologia de Discos Físicos, Partições e LVM (lsblk):${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v "^loop" | sed 's/^/    /' || true
fi

# 3.2 - Análise Completa do /etc/fstab (Verifica se cada entrada está montada ou não)
echo -e "\n  ${BOLD}Unidades Configuradas no /etc/fstab (Persistência de Montagem):${NC}"
if [[ -r /etc/fstab ]]; then
    FSTAB_ENTRIES=$(grep -vE "^\s*#|^\s*$" /etc/fstab 2>/dev/null || true)
    if [[ -n "$FSTAB_ENTRIES" ]]; then
        while IFS= read -r fs_line; do
            [[ -z "$fs_line" ]] && continue
            fs_src=$(echo "$fs_line" | awk '{print $1}')
            fs_mnt=$(echo "$fs_line" | awk '{print $2}')
            fs_type=$(echo "$fs_line" | awk '{print $3}')
            fs_opts=$(echo "$fs_line" | awk '{print $4}')

            MNT_STATE="${FG_GREEN}[MONTADO]${NC}"
            if [[ "$fs_type" == "swap" || "$fs_mnt" == "none" || "$fs_mnt" == "swap" ]]; then
                if [[ "$(free 2>/dev/null | awk '/^Swap:/ {print $2}')" -gt 0 ]]; then
                    MNT_STATE="${FG_GREEN}[SWAP ATIVO]${NC}"
                else
                    MNT_STATE="${FG_YELLOW}[SWAP INATIVO]${NC}"
                fi
            elif command -v findmnt >/dev/null 2>&1; then
                if ! findmnt -rn -M "$fs_mnt" >/dev/null 2>&1; then
                    MNT_STATE="${FG_RED}[NÃO MONTADO]${NC}"
                    add_alert "Unidade configurada no /etc/fstab (${fs_src} -> ${fs_mnt}) NÃO está montada no momento."
                fi
            fi
            echo -e "    • ${MNT_STATE} Ponto: ${FG_CYAN}${BOLD}${fs_mnt}${NC} | Tipo: ${FG_YELLOW}${fs_type}${NC} | Origem: ${fs_src} ${DIM}(Opts: ${fs_opts})${NC}"
        done <<< "$FSTAB_ENTRIES"
    else
        echo -e "    • Nenhuma unidade configurada em /etc/fstab (arquivo vazio ou apenas comentários)."
    fi
else
    echo -e "    • /etc/fstab não encontrado."
fi

# 3.3 - Auditoria de NFS (Cliente NFS Montado + Servidor NFS /etc/exports)
echo -e "\n  ${BOLD}Auditoria de NFS (Network File System — Cliente e Servidor):${NC}"
NFS_FOUND=0
NFS_CLIENT_MOUNTS=$(findmnt -t nfs,nfs4 -no TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true)
NFS_FSTAB=$(grep -vE "^\s*#|^\s*$" /etc/fstab 2>/dev/null | awk '$3 ~ /^nfs/ {print $1 " -> " $2 " (" $3 ")"}' || true)

if [[ -n "$NFS_CLIENT_MOUNTS" ]]; then
    NFS_FOUND=1
    while IFS= read -r ncm; do
        echo -e "    • ${FG_GREEN}[Cliente NFS Montado]${NC} ${FG_CYAN}${ncm}${NC}"
        add_unique_item RESUMO_STORAGE_REDE "NFS-Client(${ncm%% *})"
    done <<< "$NFS_CLIENT_MOUNTS"
fi
if [[ -n "$NFS_FSTAB" ]]; then
    NFS_FOUND=1
    while IFS= read -r nf; do
        echo -e "    • ${FG_YELLOW}[Cliente NFS no fstab]${NC} ${nf}"
    done <<< "$NFS_FSTAB"
fi

if [[ "$(get_service_status_plain nfs-kernel-server)" != "Não instalado" ]] || [[ "$(get_service_status_plain nfs-server)" != "Não instalado" ]] || [[ -s /etc/exports ]]; then
    NFS_SVC="nfs-server"
    [[ "$(get_service_status_plain nfs-kernel-server)" != "Não instalado" ]] && NFS_SVC="nfs-kernel-server"
    NFS_EXPORTS=$(grep -vE "^\s*#|^\s*$" /etc/exports /etc/exports.d/*.exports 2>/dev/null || true)
    if [[ "$(get_service_status_plain "$NFS_SVC")" == "Ativo" || -n "$NFS_EXPORTS" ]]; then
        NFS_FOUND=1
        echo -e "    • ${FG_GREEN}[Servidor NFS (${NFS_SVC})]${NC} Status: [$(get_service_status "$NFS_SVC")]"
        [[ "$(get_service_status_plain "$NFS_SVC")" == "Ativo" ]] && add_role "Servidor de Arquivos NFS"
        if [[ -n "$NFS_EXPORTS" ]]; then
            echo -e "      └─ ${BOLD}Pastas Exportadas (/etc/exports):${NC}"
            while IFS= read -r exp_line; do
                echo -e "         • ${FG_YELLOW}${exp_line}${NC}"
                add_unique_item RESUMO_STORAGE_REDE "NFS-Server(${exp_line%% *})"
            done <<< "$NFS_EXPORTS"
        fi
    fi
fi
(( NFS_FOUND == 0 )) && echo -e "    • Nenhuma montagem Cliente NFS ou exportação de Servidor NFS ativa neste host."

# 3.4 - Auditoria de SAMBA / CIFS (Cliente SMB Montado + Servidor Samba /etc/samba/smb.conf)
echo -e "\n  ${BOLD}Auditoria de SAMBA / CIFS (Compartilhamentos Windows/SMB — Cliente e Servidor):${NC}"
SMB_FOUND=0
SMB_CLIENT_MOUNTS=$(findmnt -t cifs,smb3 -no TARGET,SOURCE,FSTYPE 2>/dev/null || true)
SMB_FSTAB=$(grep -vE "^\s*#|^\s*$" /etc/fstab 2>/dev/null | awk '$3 ~ /^(cifs|smb)/ {print $1 " -> " $2 " (" $3 ")"}' || true)

if [[ -n "$SMB_CLIENT_MOUNTS" ]]; then
    SMB_FOUND=1
    while IFS= read -r scm; do
        echo -e "    • ${FG_GREEN}[Cliente SMB/CIFS Montado]${NC} ${FG_CYAN}${scm}${NC}"
        add_unique_item RESUMO_STORAGE_REDE "SMB-Client(${scm%% *})"
    done <<< "$SMB_CLIENT_MOUNTS"
fi
if [[ -n "$SMB_FSTAB" ]]; then
    SMB_FOUND=1
    while IFS= read -r sf; do
        echo -e "    • ${FG_YELLOW}[Cliente SMB/CIFS no fstab]${NC} ${sf}"
    done <<< "$SMB_FSTAB"
fi

if command -v smbd >/dev/null 2>&1 || [[ -f /etc/samba/smb.conf ]]; then
    SMB_FOUND=1
    SMBD_VER=$(smbd --version 2>/dev/null || echo "Instalado")
    SMB_SVC="smbd"
    [[ "$(get_service_status_plain smbd)" == "Não instalado" && "$(get_service_status_plain smb)" != "Não instalado" ]] && SMB_SVC="smb"
    [[ "$(get_service_status_plain samba-ad-dc)" == "Ativo" ]] && SMB_SVC="samba-ad-dc"

    echo -e "    • ${FG_GREEN}[Servidor Samba (${SMB_SVC})]${NC} Versão: ${BOLD}${SMBD_VER}${NC} | Status: [$(get_service_status "$SMB_SVC")]"
    if [[ "$(get_service_status_plain "$SMB_SVC")" == "Ativo" ]]; then
        add_role "Servidor de Arquivos Samba (${SMBD_VER})"
        add_unique_item RESUMO_APPS_VERSOES "Samba:${SMBD_VER}"
    fi

    if [[ -r /etc/samba/smb.conf ]]; then
        SMB_WG=$(awk -F'=' '/^\s*workgroup\s*=/ {gsub(/[ \t]/,"",$2); print $2}' /etc/samba/smb.conf 2>/dev/null | head -n 1 || true)
        SMB_RLM=$(awk -F'=' '/^\s*realm\s*=/ {gsub(/[ \t]/,"",$2); print $2}' /etc/samba/smb.conf 2>/dev/null | head -n 1 || true)
        echo -e "      ├─ Workgroup: ${FG_CYAN}${SMB_WG:-WORKGROUP}${NC}${SMB_RLM:+ | Realm: ${FG_CYAN}${SMB_RLM}${NC}}"

        SMB_SHARES_LIST=$(awk '
            /^\[.*\]/ {
                sect=$0; gsub(/\[|\]|[ \t\r]/, "", sect)
                in_share = (tolower(sect) != "global" && tolower(sect) != "printers" && tolower(sect) != "print$")
                if (in_share) share_name=sect
            }
            in_share && /^\s*path\s*=/ {
                sub(/^\s*path\s*=\s*/, "", $0); gsub(/\r/, "", $0)
                print share_name " -> " $0
                in_share=0
            }
        ' /etc/samba/smb.conf 2>/dev/null || true)

        if [[ -n "$SMB_SHARES_LIST" ]]; then
            echo -e "      └─ ${BOLD}Compartilhamentos Configurados em /etc/samba/smb.conf:${NC}"
            while IFS= read -r sh_line; do
                echo -e "         • ${FG_YELLOW}[${sh_line/ -> /] -> Pasta: }${NC}"
                add_unique_item RESUMO_STORAGE_REDE "Samba-Share(${sh_line%% *})"
            done <<< "$SMB_SHARES_LIST"
        fi
    fi
fi
(( SMB_FOUND == 0 )) && echo -e "    • Nenhum compartilhamento Samba/CIFS (cliente ou servidor) ativo neste host."

# ==============================================================================
# SEÇÃO 4 - APLICAÇÕES, WEB, PHP, RUNTIMES, CMSS E CONTAINERS (QUAIS E VERSÕES)
# ==============================================================================
print_header "4. APLICAÇÕES, SERVIDORES WEB, PHP, RUNTIMES E CONTAINERS (QUAIS E VERSÕES)"

# 4.1 - Servidores Web, Proxies Reversos e Balanceadores (Quais e Versões)
echo -e "  ${BOLD}4.1 Servidores Web, Proxies Reversos e Balanceadores (Quais e Versões):${NC}"
WEB_FOUND=0

if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
    WEB_FOUND=1
    APACHE_BIN=$(command -v apache2 || command -v httpd)
    APACHE_SVC="apache2"
    if [[ "$(get_service_status_plain apache2)" == "Não instalado" && "$(get_service_status_plain httpd)" != "Não instalado" ]]; then
        APACHE_SVC="httpd"
    fi
    APACHE_VER=$($APACHE_BIN -v 2>/dev/null | head -n 1 | cut -d':' -f2 | xargs || echo "Instalado")
    log_success "Apache (${APACHE_SVC}): ${BOLD}${APACHE_VER}${NC} [$(get_service_status "$APACHE_SVC")]"
    add_unique_item RESUMO_APPS_VERSOES "Apache:${APACHE_VER}"
    if [[ "$(get_service_status_plain "$APACHE_SVC")" == "Ativo" ]]; then
        add_role "Web Server Apache (${APACHE_VER})"
    fi

    APACHE_CTL=$(command -v apache2ctl || command -v apachectl || echo "$APACHE_BIN")
    APACHE_MPM=$($APACHE_CTL -V 2>/dev/null | awk -F': ' '/Server MPM/ {print $2}' | xargs || true)
    [[ -n "$APACHE_MPM" ]] && log_item "Modo MPM" "${FG_CYAN}${APACHE_MPM}${NC}"

    APACHE_MODS=$($APACHE_CTL -M 2>/dev/null | awk '/_module/ {sub(/_module/,"",$1); print $1}' | sort -u | xargs || true)
    echo -e "    • ${BOLD}Módulos Ativos:${NC} ${DIM}${APACHE_MODS:-Não foi possível listar}${NC}"

    echo -e "\n    ${BOLD}VirtualHosts e Sites Habilitados no Apache:${NC}"
    APACHE_SITES_COUNT=0
    for vhost_file in /etc/apache2/sites-enabled/* /etc/httpd/conf.d/*.conf /etc/apache2/vhosts.d/*.conf; do
        [[ -f "$vhost_file" ]] || continue
        APACHE_SITES_COUNT=$((APACHE_SITES_COUNT + 1))
        VH_NAME=$(grep -iE "^\s*ServerName\s+" "$vhost_file" 2>/dev/null | awk '{print $2}' | tr -d ';' | xargs || true)
        VH_ALIAS=$(grep -iE "^\s*ServerAlias\s+" "$vhost_file" 2>/dev/null | sed -E 's/^\s*ServerAlias\s+//I' | xargs || true)
        VH_ROOT=$(grep -iE "^\s*DocumentRoot\s+" "$vhost_file" 2>/dev/null | awk '{print $2}' | tr -d '"' | head -n 1 || true)
        VH_PROXY=$(grep -iE "^\s*ProxyPass\s+" "$vhost_file" 2>/dev/null | grep -v "!" | awk '{print $2 " -> " $3}' | head -n 2 | xargs || true)
        VH_PHP_FPM=$(grep -iE "SetHandler\s+.*proxy:(unix|fcgi):" "$vhost_file" 2>/dev/null | grep -oE "php[0-9.]*-?fpm|unix:[^|\"']+|fcgi://[^\"']+" | head -n 1 || true)

        echo -e "      • Arquivo: ${FG_CYAN}$(basename "$vhost_file")${NC} | ServerName: ${FG_YELLOW}${VH_NAME:-Padrão/ Sem ServerName}${NC}${VH_ALIAS:+ (Alias: $VH_ALIAS)}"
        [[ -n "$VH_ROOT" ]]    && echo -e "        ├─ DocumentRoot: ${FG_GREEN}${VH_ROOT}${NC}"
        [[ -n "$VH_PROXY" ]]   && echo -e "        ├─ ProxyPass:    ${FG_CYAN}${VH_PROXY}${NC}"
        [[ -n "$VH_PHP_FPM" ]] && echo -e "        └─ Handler PHP:  ${FG_YELLOW}${VH_PHP_FPM}${NC}"
        add_unique_item RESUMO_SITES_DETECTADOS "Apache: ${VH_NAME:-$(basename "$vhost_file")} (${VH_ROOT:-${VH_PROXY:-N/A}})"
    done
    (( APACHE_SITES_COUNT == 0 )) && echo -e "      • Nenhum arquivo de VirtualHost dedicado encontrado."
    echo -e ""
fi

if command -v nginx >/dev/null 2>&1; then
    WEB_FOUND=1
    NGINX_VER=$(nginx -v 2>&1 | cut -d':' -f2 | xargs || echo "Instalado")
    log_success "Nginx: ${BOLD}${NGINX_VER}${NC} [$(get_service_status nginx)]"
    add_unique_item RESUMO_APPS_VERSOES "Nginx:${NGINX_VER}"
    if [[ "$(get_service_status_plain nginx)" == "Ativo" ]]; then
        add_role "Web Server / Proxy Nginx (${NGINX_VER})"
    fi

    echo -e "\n    ${BOLD}Server Blocks / Domínios Configurados no Nginx:${NC}"
    NGINX_SITES_COUNT=0
    for conf in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
        [[ -f "$conf" ]] || continue
        NGINX_SITES_COUNT=$((NGINX_SITES_COUNT + 1))
        DOMAINS=$(grep -E "^\s*server_name\s+" "$conf" 2>/dev/null | sed -E 's/^\s*server_name\s+//; s/;//g' | xargs || true)
        DOC_ROOT=$(grep -E "^\s*root\s+" "$conf" 2>/dev/null | sed -E 's/^\s*root\s+//; s/;//g' | head -n 1 | xargs || true)
        PROXY_PASS=$(grep -E "^\s*proxy_pass\s+" "$conf" 2>/dev/null | sed -E 's/^\s*proxy_pass\s+//; s/;//g' | head -n 2 | xargs || true)
        FASTCGI_PASS=$(grep -E "^\s*fastcgi_pass\s+" "$conf" 2>/dev/null | sed -E 's/^\s*fastcgi_pass\s+//; s/;//g' | head -n 1 | xargs || true)

        echo -e "      • Arquivo: ${FG_CYAN}$(basename "$conf")${NC} | Domínios: ${FG_YELLOW}${DOMAINS:-_}${NC}"
        [[ -n "$DOC_ROOT" ]]     && echo -e "        ├─ Root:         ${FG_GREEN}${DOC_ROOT}${NC}"
        [[ -n "$PROXY_PASS" ]]   && echo -e "        ├─ Proxy Reverso:${FG_CYAN} ${PROXY_PASS}${NC}"
        [[ -n "$FASTCGI_PASS" ]] && echo -e "        └─ PHP FastCGI:  ${FG_YELLOW}${FASTCGI_PASS}${NC}"
        add_unique_item RESUMO_SITES_DETECTADOS "Nginx: ${DOMAINS:-$(basename "$conf")} (${DOC_ROOT:-${PROXY_PASS:-N/A}})"
    done
    (( NGINX_SITES_COUNT == 0 )) && echo -e "      • Nenhum Server Block ativo encontrado em /etc/nginx."
    echo -e ""
fi

for other_web in caddy haproxy traefik lighttpd lsws tomcat tomcat9 tomcat10 squid varnish webmin cockpit; do
    if command -v "$other_web" >/dev/null 2>&1 || [[ "$(get_service_status_plain "$other_web")" != "Não instalado" ]]; then
        WEB_FOUND=1
        OW_VER=$($other_web --version 2>/dev/null | head -n 1 || $other_web -v 2>/dev/null | head -n 1 || echo "Instalado")
        log_success "Serviço Web/Proxy/Painel: ${BOLD}${other_web}${NC} (${OW_VER}) [$(get_service_status "$other_web")]"
        add_unique_item RESUMO_APPS_VERSOES "${other_web}:${OW_VER}"
        [[ "$(get_service_status_plain "$other_web")" == "Ativo" ]] && add_role "Proxy/Web/Painel (${other_web})"
    fi
done

(( WEB_FOUND == 0 )) && log_info "Nenhum servidor web tradicional (Apache/Nginx/Caddy/HAProxy) instalado diretamente no host."

if [[ -d /etc/letsencrypt/live ]] && command -v openssl >/dev/null 2>&1; then
    CERT_COUNT=0
    for cert_pem in /etc/letsencrypt/live/*/cert.pem; do
        [[ -f "$cert_pem" ]] || continue
        CERT_COUNT=$((CERT_COUNT + 1))
        (( CERT_COUNT == 1 )) && echo -e "\n    ${BOLD}Certificados SSL/TLS (Let's Encrypt):${NC}"
        CERT_DOMAIN=$(basename "$(dirname "$cert_pem")")
        END_DATE=$(openssl x509 -enddate -noout -in "$cert_pem" 2>/dev/null | cut -d'=' -f2 || true)
        END_EPOCH=$(date -d "$END_DATE" +%s 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))
        if (( DAYS_LEFT < 0 )); then
            echo -e "      • ${BOLD}${CERT_DOMAIN}:${NC} ${FG_RED}EXPIRADO há $(( -DAYS_LEFT )) dia(s) (${END_DATE})${NC}"
            add_alert "Certificado SSL do domínio ${CERT_DOMAIN} está EXPIRADO!"
        elif (( DAYS_LEFT < 15 )); then
            echo -e "      • ${BOLD}${CERT_DOMAIN}:${NC} ${FG_YELLOW}Expira em ${DAYS_LEFT} dia(s) (${END_DATE})${NC}"
            add_alert "Certificado SSL do domínio ${CERT_DOMAIN} expira em ${DAYS_LEFT} dias."
        else
            echo -e "      • ${BOLD}${CERT_DOMAIN}:${NC} ${FG_GREEN}Válido por ${DAYS_LEFT} dias${NC} ${DIM}(Expira: ${END_DATE})${NC}"
        fi
    done
fi

# 4.2 - Diagnóstico Profundo do PHP no Host (Versões, FPM, CGI, mod_php, php.ini e EOL)
echo -e "\n  ${BOLD}4.2 Diagnóstico Profundo do PHP no Host (Versões, FPM, CGI e Segurança):${NC}"
PHP_ANY_FOUND=0

if command -v php >/dev/null 2>&1; then
    PHP_ANY_FOUND=1
    CLI_PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null || php -v 2>/dev/null | head -n 1 || true)
    CLI_PHP_BIN=$(readlink -f "$(command -v php)" 2>/dev/null || command -v php)
    log_success "PHP CLI Padrão: ${BOLD}PHP ${CLI_PHP_VER}${NC} (${FG_CYAN}${CLI_PHP_BIN}${NC})"
    add_unique_item RESUMO_PHP_VERSOES "Host-CLI:${CLI_PHP_VER}"
    add_unique_item RESUMO_APPS_VERSOES "PHP:${CLI_PHP_VER}"
    if [[ "$CLI_PHP_VER" =~ ^(5\.|7\.|8\.0\.) ]]; then
        add_alert "PHP CLI padrão no host (${CLI_PHP_VER}) está em End-of-Life (Sem suporte de segurança oficial)."
    fi
fi

ALL_PHP_BINS=$(find /usr/bin /usr/local/bin /opt /www/server/php -maxdepth 5 -type f -regextype posix-extended -regex '.*/php([0-9]+\.[0-9]+)?$' 2>/dev/null | sort -u || true)
if [[ -n "$ALL_PHP_BINS" ]]; then
    PHP_ANY_FOUND=1
    echo -e "    • ${BOLD}Binários PHP Encontrados no Host:${NC}"
    while IFS= read -r bin_path; do
        [[ -x "$bin_path" ]] || continue
        B_VER=$("$bin_path" -r 'echo PHP_VERSION;' 2>/dev/null || true)
        [[ -n "$B_VER" ]] && echo -e "      ├─ ${FG_CYAN}${bin_path}${NC} -> ${BOLD}PHP ${B_VER}${NC}"
    done <<< "$ALL_PHP_BINS"
fi

if command -v php-cgi >/dev/null 2>&1 || pgrep -fa "php-cgi" >/dev/null 2>&1; then
    PHP_ANY_FOUND=1
    CGI_BIN=$(command -v php-cgi || echo "Processo ativo")
    log_warning "Binário/Processo PHP-CGI detectado no host (${CGI_BIN})! Verifique exposição CGI."
    add_alert "PHP-CGI detectado no host (${CGI_BIN}) — validar exposição a CVEs de argumento CGI."
fi

APACHE_PHP_MOD=$(find /etc/apache2/mods-enabled/ /etc/httpd/conf.modules.d/ -maxdepth 1 -name "*php*.load" -o -name "*php*.conf" 2>/dev/null | head -n 1 || true)
if [[ -n "$APACHE_PHP_MOD" ]]; then
    PHP_ANY_FOUND=1
    AP_VER=$(basename "$APACHE_PHP_MOD" | sed -E 's/\.(load|conf)$//; s/^[0-9]+-//; s/php//')
    log_success "Módulo Apache (mod_php) Configurado: ${BOLD}PHP ${AP_VER:-Ativo}${NC} (${APACHE_PHP_MOD})"
    add_unique_item RESUMO_PHP_VERSOES "Host-ApacheMod:${AP_VER:-Ativo}"
fi

if [[ -d /etc/php ]]; then
    PHP_ANY_FOUND=1
    echo -e "    • ${BOLD}Instalações em /etc/php/ (Debian/Ubuntu — Status FPM, Pools e php.ini):${NC}"
    for php_dir in /etc/php/*; do
        [[ -d "$php_dir" ]] || continue
        V=$(basename "$php_dir")
        FPM_SVC="php${V}-fpm"
        FPM_STATE=$(get_service_status "$FPM_SVC")
        FPM_PLAIN=$(get_service_status_plain "$FPM_SVC")

        if [[ "$FPM_PLAIN" == "Ativo" ]]; then
            add_role "Application Server (PHP ${V}-FPM)"
            add_unique_item RESUMO_PHP_VERSOES "Host-FPM-${V}:Ativo"
        fi
        if [[ "$V" =~ ^(5\.|7\.|8\.0)$ ]]; then
            add_alert "PHP ${V} instalado em /etc/php/${V} está em End-of-Life."
        fi

        echo -e "      ├─ ${BOLD}PHP ${V}${NC} — Serviço FPM: [${FPM_STATE}]"
        if [[ -d "${php_dir}/fpm/pool.d" ]]; then
            for pool_conf in "${php_dir}/fpm/pool.d/"*.conf; do
                [[ -f "$pool_conf" ]] || continue
                POOL_NAME=$(grep -E "^\[.*\]" "$pool_conf" 2>/dev/null | head -n 1 | tr -d '[]' || true)
                POOL_LISTEN=$(grep -E "^\s*listen\s*=" "$pool_conf" 2>/dev/null | cut -d'=' -f2 | xargs || true)
                POOL_USER=$(grep -E "^\s*user\s*=" "$pool_conf" 2>/dev/null | cut -d'=' -f2 | xargs || true)
                echo -e "         ├─ Pool FPM [${FG_CYAN}${POOL_NAME:-www}${NC}]: Usuário=${POOL_USER:-www-data} | Listen=${FG_YELLOW}${POOL_LISTEN:-N/A}${NC}"
            done
        fi
        for sapi in fpm apache2 cli; do
            INI_FILE="${php_dir}/${sapi}/php.ini"
            [[ -f "$INI_FILE" ]] || continue
            EXPOSE_PHP=$(awk -F'=' '/^\s*expose_php\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            MEM_LIMIT=$(awk -F'=' '/^\s*memory_limit\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            UPLOAD_MAX=$(awk -F'=' '/^\s*upload_max_filesize\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            DISABLE_FN=$(awk -F'=' '/^\s*disable_functions\s*=/ {print $2}' "$INI_FILE" | tail -n 1 | xargs || true)
            echo -e "         └─ php.ini (${sapi}): expose_php=${EXPOSE_PHP:-On} | memory_limit=${MEM_LIMIT:-128M} | upload_max=${UPLOAD_MAX:-2M} | disable_functions=${DISABLE_FN:+Configurado}${DISABLE_FN:-Vazio}"
            break
        done
    done
fi

if [[ -f /etc/php.ini ]] || [[ -d /etc/php-fpm.d ]] || [[ -d /etc/opt/remi ]]; then
    PHP_ANY_FOUND=1
    echo -e "    • ${BOLD}Instalações PHP Padrão RHEL/CentOS/Remi (/etc/php.ini e /etc/opt/remi):${NC}"
    if [[ "$(get_service_status_plain php-fpm)" != "Não instalado" ]]; then
        echo -e "      ├─ ${BOLD}Serviço php-fpm padrão:${NC} [$(get_service_status php-fpm)]"
        [[ "$(get_service_status_plain php-fpm)" == "Ativo" ]] && add_role "Application Server (php-fpm)" && add_unique_item RESUMO_PHP_VERSOES "Host-php-fpm:Ativo"
    fi
    for remi_dir in /etc/opt/remi/php*; do
        [[ -d "$remi_dir" ]] || continue
        REMI_NAME=$(basename "$remi_dir")
        REMI_SVC="${REMI_NAME}-php-fpm"
        echo -e "      ├─ ${BOLD}Remi ${REMI_NAME}:${NC} Serviço FPM [${REMI_SVC}: $(get_service_status "$REMI_SVC")]"
        [[ "$(get_service_status_plain "$REMI_SVC")" == "Ativo" ]] && add_unique_item RESUMO_PHP_VERSOES "Host-${REMI_SVC}:Ativo"
    done
fi

if (( PHP_ANY_FOUND == 1 )); then
    if command -v dpkg-query >/dev/null 2>&1; then
        PHP_REPO_ORIGIN=$(apt-cache policy php-common 2>/dev/null | grep -A 1 "\*\*\*" | tail -n 1 | awk '{print $2, $3}' || true)
        [[ -n "$PHP_REPO_ORIGIN" ]] && log_item "Repositório PHP" "${FG_CYAN}${PHP_REPO_ORIGIN}${NC}"
        if [[ -n "${APT_SIM:-}" ]]; then
            PHP_UPGRADABLE=$(echo "$APT_SIM" | awk '/^Inst / && $2 ~ /php/ {print $2 " (" $3 " -> " $4 ")"}' || true)
            if [[ -n "$PHP_UPGRADABLE" ]]; then
                print_alert_box "Há atualizações de pacotes PHP pendentes no APT!"
                while IFS= read -r upg_line; do
                    echo -e "      • ${FG_YELLOW}${upg_line}${NC}"
                done <<< "$PHP_UPGRADABLE"
            fi
        fi
    fi
else
    log_info "PHP no Host: Não instalado diretamente no SO (verifique a subseção 4.5 de Contêineres)."
fi

# 4.3 - Outras Linguagens, Runtimes e Aplicações em Execução (Node.js, Python, Java, .NET, Go, Ruby)
echo -e "\n  ${BOLD}4.3 Outras Linguagens e Runtimes Instalados (Quais e Versões):${NC}"
RUNTIME_FOUND=0

if command -v node >/dev/null 2>&1; then
    RUNTIME_FOUND=$((RUNTIME_FOUND + 1))
    NODE_V=$(node -v 2>/dev/null || echo "Instalado")
    NPM_V=$( command -v npm >/dev/null 2>&1 && npm -v 2>/dev/null || echo "N/A" )
    echo -e "    • ${BOLD}Node.js:${NC} ${FG_GREEN}${NODE_V}${NC} (NPM: ${NPM_V})"
    add_unique_item RESUMO_APPS_VERSOES "Node.js:${NODE_V}"
    NODE_PROCS=$(pgrep -fa "node " 2>/dev/null | grep -v "grep" || true)
    if [[ -n "$NODE_PROCS" ]]; then
        add_role "App Server (Node.js ${NODE_V})"
        while IFS= read -r np; do
            echo -e "      └─ Processo Node Ativo: ${FG_CYAN}$(echo "$np" | cut -c1-110)${NC}"
        done <<< "$NODE_PROCS"
    fi
fi

if command -v python3 >/dev/null 2>&1; then
    RUNTIME_FOUND=$((RUNTIME_FOUND + 1))
    PY_V=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "Instalado")
    echo -e "    • ${BOLD}Python 3:${NC} ${FG_GREEN}v${PY_V}${NC}"
    add_unique_item RESUMO_APPS_VERSOES "Python:${PY_V}"
    PY_APPS=$(pgrep -fa "gunicorn|uvicorn|celery|manage\.py|flask|fastapi" 2>/dev/null | grep -v "grep" || true)
    if [[ -n "$PY_APPS" ]]; then
        add_role "App Server (Python Web/Worker)"
        while IFS= read -r pp; do
            echo -e "      └─ Processo Python Web: ${FG_CYAN}$(echo "$pp" | cut -c1-110)${NC}"
        done <<< "$PY_APPS"
    fi
fi

if command -v java >/dev/null 2>&1; then
    RUNTIME_FOUND=$((RUNTIME_FOUND + 1))
    JAVA_VER=$(java -version 2>&1 | head -n 1 | tr -d '"' || echo "Instalado")
    echo -e "    • ${BOLD}Java (JVM):${NC} ${FG_GREEN}${JAVA_VER}${NC}"
    add_unique_item RESUMO_APPS_VERSOES "Java:${JAVA_VER}"
    JAVA_PROCS=$(pgrep -fa "java " 2>/dev/null | grep -v "grep" || true)
    if [[ -n "$JAVA_PROCS" ]]; then
        add_role "App Server (Java/JVM)"
        while IFS= read -r jp; do
            echo -e "      └─ Processo JVM Ativo: ${FG_CYAN}$(echo "$jp" | cut -c1-110)${NC}"
        done <<< "$JAVA_PROCS"
    fi
fi

if command -v dotnet >/dev/null 2>&1; then
    RUNTIME_FOUND=$((RUNTIME_FOUND + 1))
    DOTNET_V=$(dotnet --version 2>/dev/null || dotnet --info 2>/dev/null | awk '/Version:/ {print $2; exit}' || echo "Instalado")
    echo -e "    • ${BOLD}.NET Runtime/SDK:${NC} ${FG_GREEN}${DOTNET_V}${NC}"
    add_unique_item RESUMO_APPS_VERSOES ".NET:${DOTNET_V}"
    DOTNET_APPS=$(pgrep -fa "dotnet " 2>/dev/null | grep -v "grep" || true)
    if [[ -n "$DOTNET_APPS" ]]; then
        add_role "App Server (.NET)"
        while IFS= read -r dp; do
            echo -e "      └─ Processo .NET Ativo: ${FG_CYAN}$(echo "$dp" | cut -c1-110)${NC}"
        done <<< "$DOTNET_APPS"
    fi
fi

if command -v go >/dev/null 2>&1; then
    RUNTIME_FOUND=$((RUNTIME_FOUND + 1))
    GO_V=$(go version 2>/dev/null | awk '{print $3}' || echo "Instalado")
    echo -e "    • ${BOLD}Go (Golang):${NC} ${FG_GREEN}${GO_V}${NC}"
    add_unique_item RESUMO_APPS_VERSOES "Go:${GO_V}"
fi

# 4.4 - Aplicações Web, CMSs e Sistemas Instalados no Disco (Quais e Versões)
echo -e "\n  ${BOLD}4.4 Aplicações Web, CMSs e Sistemas Identificados no Disco (Quais e Versões):${NC}"
SCAN_DIRS=("/var/www" "/srv" "/home" "/opt" "/usr/share/zabbix" "/usr/share/glpi" "/usr/share/roundcube")
FOUND_APPS=0

for base_dir in "${SCAN_DIRS[@]}"; do
    [[ -d "$base_dir" ]] || continue

    # Joomla
    while IFS= read -r joomla_ver_file; do
        [[ -f "$joomla_ver_file" ]] || continue
        if [[ "$joomla_ver_file" == */libraries/src/Version.php ]]; then
            APP_DIR=$(dirname "$(dirname "$(dirname "$joomla_ver_file")")")
        else
            APP_DIR=$(dirname "$(dirname "$joomla_ver_file")")
        fi
        J_VER_EXACT=""
        if command -v php >/dev/null 2>&1; then
            J_VER_EXACT=$(php -r "require_once '$joomla_ver_file'; if (class_exists('Joomla\CMS\Version')) { echo \Joomla\CMS\Version::MAJOR_VERSION . '.' . \Joomla\CMS\Version::MINOR_VERSION . '.' . \Joomla\CMS\Version::PATCH_VERSION; } elseif (class_exists('JVersion')) { \$v = new JVersion(); echo \$v->getShortVersion(); }" 2>/dev/null || true)
        fi
        if [[ -z "$J_VER_EXACT" ]]; then
            MAJOR=$(grep -E "const\s+MAJOR_VERSION|public\s+\$RELEASE" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"" || true)
            MINOR=$(grep -E "const\s+MINOR_VERSION|public\s+\$DEV_LEVEL" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"" || true)
            PATCH=$(grep -E "const\s+PATCH_VERSION|public\s+\$BUILD" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"" || true)
            [[ -n "$MAJOR" ]] && J_VER_EXACT="${MAJOR}.${MINOR:-0}.${PATCH:-0}"
        fi
        J_DB=""
        [[ -f "${APP_DIR}/configuration.php" ]] && J_DB=$(grep -E "public\s+\\\$db\s*=" "${APP_DIR}/configuration.php" 2>/dev/null | cut -d"'" -f2 || true)
        echo -e "    • ${FG_GREEN}${BOLD}Joomla v${J_VER_EXACT:-Detectado}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${J_DB:+ (Banco: ${FG_YELLOW}${J_DB}${NC})}"
        add_role "Hospedagem Joomla (${J_VER_EXACT:-CMS})"
        add_unique_item RESUMO_APPS_VERSOES "Joomla:${J_VER_EXACT:-CMS}"
        add_unique_item RESUMO_SITES_DETECTADOS "Joomla ${J_VER_EXACT:-CMS}: ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 6 -type f \( -path "*/libraries/src/Version.php" -o -path "*/includes/version.php" \) 2>/dev/null)

    # WordPress
    while IFS= read -r wp_ver_file; do
        [[ -f "$wp_ver_file" ]] || continue
        APP_DIR=$(dirname "$(dirname "$wp_ver_file")")
        WP_VER=$(grep "^\$wp_version\s*=" "$wp_ver_file" 2>/dev/null | cut -d"'" -f2 || true)
        WP_DB=""
        [[ -f "${APP_DIR}/wp-config.php" ]] && WP_DB=$(grep -E "define\(\s*'DB_NAME'" "${APP_DIR}/wp-config.php" 2>/dev/null | cut -d"'" -f4 || true)
        echo -e "    • ${FG_GREEN}${BOLD}WordPress v${WP_VER:-Detectado}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${WP_DB:+ (Banco: ${FG_YELLOW}${WP_DB}${NC})}"
        add_role "Hospedagem WordPress (${WP_VER:-CMS})"
        add_unique_item RESUMO_APPS_VERSOES "WordPress:${WP_VER:-CMS}"
        add_unique_item RESUMO_SITES_DETECTADOS "WordPress ${WP_VER:-CMS}: ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 5 -type f -path "*/wp-includes/version.php" 2>/dev/null)

    # Laravel
    while IFS= read -r artisan_file; do
        [[ -f "$artisan_file" ]] || continue
        APP_DIR=$(dirname "$artisan_file")
        APP_NAME_ENV=""
        DB_NAME_ENV=""
        if [[ -f "${APP_DIR}/.env" ]]; then
            APP_NAME_ENV=$(awk -F'=' '/^APP_NAME=/ {gsub(/["'\'']/,"",$2); print $2}' "${APP_DIR}/.env" 2>/dev/null | head -n 1 || true)
            DB_NAME_ENV=$(awk -F'=' '/^DB_DATABASE=/ {gsub(/["'\'']/,"",$2); print $2}' "${APP_DIR}/.env" 2>/dev/null | head -n 1 || true)
        fi
        echo -e "    • ${FG_GREEN}${BOLD}Laravel (${APP_NAME_ENV:-App PHP})${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${DB_NAME_ENV:+ (Banco: ${FG_YELLOW}${DB_NAME_ENV}${NC})}"
        add_role "App Laravel (${APP_NAME_ENV:-PHP})"
        add_unique_item RESUMO_APPS_VERSOES "Laravel(${APP_NAME_ENV:-App})"
        add_unique_item RESUMO_SITES_DETECTADOS "Laravel (${APP_NAME_ENV:-App}): ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 4 -type f -name "artisan" 2>/dev/null)

    # GLPI, Zabbix, Drupal, Nextcloud, Moodle, phpMyAdmin/Adminer
    while IFS= read -r special_marker; do
        [[ -f "$special_marker" ]] || continue
        case "$special_marker" in
            */inc/define.php)
                if grep -q "GLPI_VERSION" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$(dirname "$special_marker")")
                    GLPI_V=$(grep -E "define\('GLPI_VERSION'" "$special_marker" 2>/dev/null | cut -d"'" -f4 || echo "Detectado")
                    echo -e "    • ${FG_GREEN}${BOLD}GLPI v${GLPI_V}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    add_role "Sistema GLPI (${GLPI_V})"
                    add_unique_item RESUMO_APPS_VERSOES "GLPI:${GLPI_V}"
                    add_unique_item RESUMO_SITES_DETECTADOS "GLPI ${GLPI_V}: ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            */zabbix.php)
                APP_DIR=$(dirname "$special_marker")
                echo -e "    • ${FG_GREEN}${BOLD}Zabbix Web Frontend${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                add_role "Zabbix Frontend Web"
                add_unique_item RESUMO_SITES_DETECTADOS "Zabbix Frontend: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */core/lib/Drupal.php)
                APP_DIR=$(dirname "$(dirname "$(dirname "$special_marker")")")
                echo -e "    • ${FG_GREEN}${BOLD}CMS Drupal${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                add_role "Hospedagem Drupal"
                add_unique_item RESUMO_SITES_DETECTADOS "Drupal: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */version.php)
                if grep -q "\$OC_VersionString" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$special_marker")
                    NC_V=$(grep "\$OC_VersionString" "$special_marker" 2>/dev/null | cut -d"'" -f2 || echo "Detectado")
                    echo -e "    • ${FG_GREEN}${BOLD}Nextcloud / ownCloud v${NC_V}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    add_role "Storage Nuvem (Nextcloud ${NC_V})"
                    add_unique_item RESUMO_APPS_VERSOES "Nextcloud:${NC_V}"
                    add_unique_item RESUMO_SITES_DETECTADOS "Nextcloud ${NC_V}: ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                elif grep -q "MOODLE_INTERNAL" "$special_marker" 2>/dev/null && [[ -f "$(dirname "$special_marker")/config.php" ]]; then
                    APP_DIR=$(dirname "$special_marker")
                    MDL_V=$(grep "^\$release\s*=" "$special_marker" 2>/dev/null | cut -d"'" -f2 || echo "Detectado")
                    echo -e "    • ${FG_GREEN}${BOLD}Moodle v${MDL_V}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    add_role "Plataforma EAD (Moodle)"
                    add_unique_item RESUMO_APPS_VERSOES "Moodle:${MDL_V}"
                    add_unique_item RESUMO_SITES_DETECTADOS "Moodle (${MDL_V}): ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            *phpmyadmin*|*adminer*.php)
                log_warning "Gerenciador de Banco Web Exposto no Disco: ${FG_YELLOW}${special_marker}${NC}"
                add_alert "Ferramenta de banco web encontrada no disco (${special_marker}) — verificar restrição de acesso."
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
        esac
    done < <(find "$base_dir" -maxdepth 4 -type f \( -path "*/inc/define.php" -o -name "zabbix.php" -o -path "*/core/lib/Drupal.php" -o -name "version.php" -o -iname "adminer*.php" \) 2>/dev/null)
done

(( FOUND_APPS == 0 )) && echo -e "    • Nenhum CMS padrão (Joomla/WordPress/Laravel/GLPI/Moodle/Nextcloud/Drupal/Zabbix) detectado em /var/www, /srv, /opt ou /home."

if [[ -d /var/www ]]; then
    echo -e "\n    ${BOLD}Diretórios Existentes em /var/www:${NC}"
    for www_sub in /var/www/*; do
        [[ -d "$www_sub" ]] || continue
        OWNER_PERM=$(stat -c '%U:%G (%a)' "$www_sub" 2>/dev/null || echo "N/A")
        MOD_TIME=$(stat -c '%y' "$www_sub" 2>/dev/null | cut -d'.' -f1 || echo "N/A")
        echo -e "      • ${FG_CYAN}${www_sub}${NC} — Dono/Perm: ${OWNER_PERM} | Modificado: ${DIM}${MOD_TIME}${NC}"
    done
fi

# 4.5 - Contêineres (Docker / Podman) e Inspeção Interna de Cada Container
echo -e "\n  ${BOLD}4.5 Contêineres (Docker / Podman) e Sistemas Rodando Dentro Deles:${NC}"
CONTAINER_ENGINE=""
if command -v docker >/dev/null 2>&1 && [[ "$(get_service_status_plain docker)" == "Ativo" ]]; then
    CONTAINER_ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE="podman"
fi

if [[ -n "$CONTAINER_ENGINE" ]]; then
    ENGINE_VER=$($CONTAINER_ENGINE --version 2>/dev/null || echo "Instalado")
    log_success "Engine de Contêineres ativa (${CONTAINER_ENGINE}): ${BOLD}${ENGINE_VER}${NC}"
    add_unique_item RESUMO_APPS_VERSOES "${CONTAINER_ENGINE}:${ENGINE_VER}"

    echo -e "\n    ${BOLD}Contêineres em Execução (${CONTAINER_ENGINE} ps):${NC}"
    $CONTAINER_ENGINE ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | sed 's/^/      /' || true

    STOPPED_CT=$($CONTAINER_ENGINE ps -a --filter "status=exited" --format "{{.Names}} ({{.Image}})" 2>/dev/null | xargs || true)
    [[ -n "$STOPPED_CT" ]] && echo -e "\n      • ${BOLD}Contêineres Parados:${NC} ${DIM}${STOPPED_CT}${NC}"

    RUNNING_IDS=$($CONTAINER_ENGINE ps -q 2>/dev/null || true)
    if [[ -n "$RUNNING_IDS" ]]; then
        echo -e "\n    ${BOLD}${FG_CYAN}Inspeção Interna Passiva dos Contêineres Ativos (OS, PHP, Web, Bancos e CMSs):${NC}"
        while IFS= read -r cid; do
            [[ -z "$cid" ]] && continue
            CT_NAME=$($CONTAINER_ENGINE inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||' || echo "$cid")
            CT_IMAGE=$($CONTAINER_ENGINE inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null || echo "N/A")
            CT_COMPOSE_DIR=$($CONTAINER_ENGINE inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$cid" 2>/dev/null || true)
            CT_MOUNTS=$($CONTAINER_ENGINE inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$cid" 2>/dev/null | xargs || true)
            CT_PORTS=$($CONTAINER_ENGINE port "$cid" 2>/dev/null | tr '\n' '; ' | sed 's/; $//' || true)

            echo -e "      ${FG_CYAN}${BOLD}▸ Container: ${CT_NAME}${NC} (${DIM}ID: ${cid} | Imagem: ${CT_IMAGE}${NC})"
            [[ -n "$CT_COMPOSE_DIR" ]] && echo -e "        ├─ Projeto Compose: ${FG_GREEN}${CT_COMPOSE_DIR}${NC}"
            [[ -n "$CT_PORTS" ]]       && echo -e "        ├─ Portas Mapeadas: ${FG_YELLOW}${CT_PORTS}${NC}"
            [[ -n "$CT_MOUNTS" ]]      && echo -e "        ├─ Volumes / Bind:  ${DIM}${CT_MOUNTS}${NC}"

            # shellcheck disable=SC2016
            CT_PROBE=$(timeout 5 "$CONTAINER_ENGINE" exec "$cid" sh -c '
                os_str="Desconhecido"
                if [ -r /etc/os-release ]; then
                    os_str=$(sed -n "s/^PRETTY_NAME=//p" /etc/os-release | tr -d "\"'\''")
                elif [ -r /etc/alpine-release ]; then
                    os_str="Alpine Linux $(cat /etc/alpine-release)"
                fi
                echo "OS|${os_str}"

                if command -v php >/dev/null 2>&1; then
                    p_ver=$(php -r "echo PHP_VERSION;" 2>/dev/null || php -v 2>/dev/null | head -n 1)
                    p_sapi=""
                    command -v php-fpm >/dev/null 2>&1 && p_sapi="php-fpm"
                    command -v php-cgi >/dev/null 2>&1 && p_sapi="${p_sapi:+$p_sapi,}php-cgi"
                    echo "PHP|${p_ver}|${p_sapi:-cli}"
                fi

                for wb in nginx apache2 httpd caddy node python3 java; do
                    if command -v "$wb" >/dev/null 2>&1; then
                        case "$wb" in
                            nginx)   wv=$(nginx -v 2>&1 | head -n 1) ;;
                            apache2|httpd) wv=$($wb -v 2>/dev/null | head -n 1) ;;
                            node)    wv="Node.js $(node -v 2>/dev/null)" ;;
                            python3) wv=$(python3 --version 2>/dev/null) ;;
                            java)    wv=$(java -version 2>&1 | head -n 1) ;;
                            *)       wv="$wb" ;;
                        esac
                        echo "RUNTIME|${wb}|${wv}"
                    fi
                done

                for dbb in mariadb mysql psql redis-server mongod; do
                    if command -v "$dbb" >/dev/null 2>&1; then
                        dbv=$($dbb --version 2>/dev/null | head -n 1)
                        echo "DB|${dbb}|${dbv}"
                    fi
                done

                for wdir in /var/www/html /var/www /app /usr/share/nginx/html /srv; do
                    [ -d "$wdir" ] || continue
                    for jv in "$wdir"/libraries/src/Version.php "$wdir"/*/libraries/src/Version.php; do
                        [ -f "$jv" ] && echo "APP|Joomla|$(dirname "$(dirname "$(dirname "$jv")")")"
                    done
                    for wpv in "$wdir"/wp-includes/version.php "$wdir"/*/wp-includes/version.php; do
                        [ -f "$wpv" ] && echo "APP|WordPress|$(dirname "$(dirname "$wpv")")"
                    done
                    for art in "$wdir"/artisan "$wdir"/*/artisan; do
                        [ -f "$art" ] && echo "APP|Laravel|$(dirname "$art")"
                    done
                done
            ' </dev/null 2>/dev/null || true)

            if [[ -n "$CT_PROBE" ]]; then
                CT_ROLES_SUMMARY=""
                while IFS='|' read -r p_type p_k p_v; do
                    case "$p_type" in
                        OS)      echo -e "        ├─ SO Interno:      ${FG_GREEN}${p_k}${NC}" ;;
                        PHP)
                            echo -e "        ├─ ${FG_YELLOW}${BOLD}PHP no Container:${NC} ${BOLD}PHP ${p_k}${NC} (SAPI: ${p_v})"
                            add_unique_item RESUMO_PHP_VERSOES "Container(${CT_NAME}):PHP-${p_k}"
                            CT_ROLES_SUMMARY="${CT_ROLES_SUMMARY:+${CT_ROLES_SUMMARY}, }PHP ${p_k}"
                            [[ "$p_k" =~ ^(5\.|7\.|8\.0\.) ]] && add_alert "Container '${CT_NAME}' executa PHP ${p_k} em End-of-Life."
                            [[ "$p_v" == *php-cgi* ]] && add_alert "Container '${CT_NAME}' possui binário php-cgi instalado."
                            ;;
                        RUNTIME)
                            echo -e "        ├─ Runtime/Web:     ${FG_CYAN}${p_v}${NC}"
                            CT_ROLES_SUMMARY="${CT_ROLES_SUMMARY:+${CT_ROLES_SUMMARY}, }${p_k}"
                            ;;
                        DB)
                            echo -e "        ├─ Banco Interno:   ${FG_YELLOW}${p_v}${NC}"
                            add_unique_item RESUMO_BANCOS_ATIVOS "Container(${CT_NAME}):${p_k}"
                            CT_ROLES_SUMMARY="${CT_ROLES_SUMMARY:+${CT_ROLES_SUMMARY}, }DB:${p_k}"
                            ;;
                        APP)
                            echo -e "        ├─ Aplicação/CMS:   ${FG_GREEN}${BOLD}${p_k}${NC} em ${p_v}"
                            add_unique_item RESUMO_SITES_DETECTADOS "Container ${CT_NAME}: ${p_k} (${p_v})"
                            CT_ROLES_SUMMARY="${CT_ROLES_SUMMARY:+${CT_ROLES_SUMMARY}, }${p_k}"
                            ;;
                    esac
                done <<< "$CT_PROBE"
                add_unique_item RESUMO_CONTAINERS_ATIVOS "${CT_NAME} [${CT_IMAGE}] -> ${CT_ROLES_SUMMARY:-Ativo}"
                add_role "Docker (${CT_NAME}: ${CT_ROLES_SUMMARY:-${CT_IMAGE}})"
            else
                echo -e "        └─ Inspeção Interna: ${DIM}Container minimalista / distroless (sem shell /bin/sh)${NC}"
                add_unique_item RESUMO_CONTAINERS_ATIVOS "${CT_NAME} [${CT_IMAGE}]"
                add_role "Docker (${CT_NAME})"
            fi
        done <<< "$RUNNING_IDS"
    fi
elif command -v docker >/dev/null 2>&1; then
    echo -e "    • Docker instalado, porém inativo ou requer root."
else
    echo -e "    • Docker / Podman: Não instalado neste servidor."
fi

# 4.6 - Papéis de Infraestrutura e Todos os Daemons Ativos no Systemd
echo -e "\n  ${BOLD}4.6 Outros Serviços de Infraestrutura, Agentes e Daemons em Execução:${NC}"
INFRA_FOUND=0
check_infra_service() {
    local svc="$1" label="$2" role_tag="$3"
    if [[ "$(get_service_status_plain "$svc")" != "Não instalado" ]] || pgrep -x "$svc" >/dev/null 2>&1; then
        INFRA_FOUND=$((INFRA_FOUND + 1))
        local st
        st=$(get_service_status "$svc")
        echo -e "    • ${BOLD}${label}${NC} (${svc}): [${st}]"
        if [[ "$(get_service_status_plain "$svc")" == "Ativo" ]] || pgrep -x "$svc" >/dev/null 2>&1; then
            add_role "$role_tag"
            add_unique_item RESUMO_APPS_VERSOES "${svc}:Ativo"
        fi
    fi
}

check_infra_service "named"                "Servidor DNS BIND9 (named)"                 "Servidor DNS (BIND9)"
check_infra_service "bind9"                "Servidor DNS BIND9"                         "Servidor DNS (BIND9)"
check_infra_service "unbound"              "Servidor DNS Unbound"                       "Servidor DNS (Unbound)"
check_infra_service "dnsmasq"              "Servidor DNS/DHCP Dnsmasq"                  "DNS/DHCP (Dnsmasq)"
check_infra_service "isc-dhcp-server"      "Servidor DHCP (Debian/Ubuntu)"              "Servidor DHCP"
check_infra_service "dhcpd"                "Servidor DHCP (RHEL/CentOS)"                "Servidor DHCP"
check_infra_service "kea-dhcp4-server"     "Servidor DHCP ISC Kea"                      "Servidor DHCP (Kea)"
check_infra_service "freeradius"           "Servidor FreeRADIUS (Debian/Ubuntu)"        "Autenticação RADIUS"
check_infra_service "radiusd"              "Servidor FreeRADIUS (RHEL/CentOS)"          "Autenticação RADIUS"
check_infra_service "postfix"              "Servidor de E-mail / Relay SMTP (Postfix)"  "Servidor/Relay SMTP (Postfix)"
check_infra_service "exim4"                "Servidor de E-mail SMTP (Exim4)"            "Servidor SMTP (Exim4)"
check_infra_service "dovecot"              "Servidor IMAP/POP3 (Dovecot)"               "Servidor IMAP/POP3"
check_infra_service "zabbix-server"        "Zabbix Server (Central de Monitoramento)"   "Zabbix Server"
check_infra_service "zabbix-proxy"         "Zabbix Proxy (Coletor Remoto)"              "Zabbix Proxy"
check_infra_service "zabbix-agent2"        "Agente de Monitoramento Zabbix Agent 2"     "Monitorado (Zabbix Agent 2)"
check_infra_service "zabbix-agent"         "Agente de Monitoramento Zabbix Agent"       "Monitorado (Zabbix Agent)"
check_infra_service "snmpd"                "Agente SNMP (snmpd)"                        "Agente SNMP"
check_infra_service "prometheus"           "Servidor de Métricas Prometheus"            "Monitoramento (Prometheus)"
check_infra_service "grafana-server"       "Painel de Observabilidade Grafana"          "Dashboards (Grafana)"
check_infra_service "wazuh-agent"          "Agente SIEM/EDR Wazuh"                      "Monitorado (Wazuh Agent)"
check_infra_service "glpi-agent"           "Agente de Inventário GLPI Agent"            "Inventariado (GLPI Agent)"
check_infra_service "veeamservice"         "Agente de Backup Veeam (Linux Agent)"       "Backup Veeam Agent"
check_infra_service "bacula-fd"            "Agente de Backup Bacula File Daemon"        "Backup Bacula Client"
check_infra_service "nut-server"           "Servidor de Nobreak/UPS (NUT Server)"       "Gerência UPS (NUT)"
check_infra_service "nut-monitor"          "Monitor de Nobreak/UPS (NUT Client)"        "Cliente UPS (NUT)"
check_infra_service "PowerChute"           "APC PowerChute Serial Shutdown"             "Gerência UPS (APC PowerChute)"
check_infra_service "openvpn"              "Servidor/Cliente OpenVPN"                   "Concentrador VPN (OpenVPN)"
check_infra_service "tailscaled"           "Rede Mesh VPN Tailscale"                    "Mesh VPN (Tailscale)"
check_infra_service "vsftpd"               "Servidor FTP (vsftpd)"                      "Servidor FTP (vsftpd)"
check_infra_service "proftpd"              "Servidor FTP (ProFTPD)"                     "Servidor FTP (ProFTPD)"
check_infra_service "asterisk"             "Central PABX IP / VoIP (Asterisk)"          "PABX VoIP (Asterisk)"
check_infra_service "unifi"                "Controladora Wi-Fi Ubiquiti UniFi"          "Controladora UniFi"
check_infra_service "gitlab-runsvdir"      "Servidor DevOps GitLab Omnibus"             "Servidor GitLab"
check_infra_service "jenkins"              "Servidor CI/CD Jenkins"                     "Servidor CI/CD (Jenkins)"
check_infra_service "pve-cluster"          "Hypervisor Proxmox VE"                      "Hypervisor Proxmox VE"
check_infra_service "libvirtd"             "Virtualização KVM / Libvirt"                "Hypervisor KVM/Libvirt"
check_infra_service "cups"                 "Servidor de Impressão CUPS"                 "Print Server (CUPS)"

if command -v wg >/dev/null 2>&1 && [[ -n "$(wg show interfaces 2>/dev/null || true)" ]]; then
    INFRA_FOUND=$((INFRA_FOUND + 1))
    echo -e "    • ${BOLD}VPN WireGuard Ativa:${NC} Interfaces: ${FG_GREEN}$(wg show interfaces 2>/dev/null)${NC}"
    add_role "VPN WireGuard"
fi

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    echo -e "\n    ${BOLD}Todos os Serviços (Daemons) em Execução Agora no Systemd (Não-Nativos do SO):${NC}"
    while IFS= read -r svc_line; do
        [[ -z "$svc_line" ]] && continue
        SVC_UNIT=$(echo "$svc_line" | awk '{print $1}')
        SVC_DESC=$(echo "$svc_line" | cut -d' ' -f5-)
        echo -e "      • ${FG_GREEN}${SVC_UNIT}${NC} — ${DIM}${SVC_DESC}${NC}"
    done < <(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | grep -vE "^(systemd-|user@|user-runtime-dir@|getty@|serial-getty@|console-getty|dbus\.service|polkit\.service|rsyslog\.service|syslog\.service|cron\.service|crond\.service|udev|kmod|multipathd|accounts-daemon|udisks2|upower|networkd-dispatcher|ModemManager|wpa_supplicant|avahi-daemon|bluetooth|colord|rtkit-daemon|switcheroo-control|thermald|power-profiles-daemon|irqbalance|packagekit|unattended-upgrades|wsl-pro)" || true)
fi

# ==============================================================================
# SEÇÃO 5 - BANCOS DE DADOS (QUAIS, VERSÕES, CONFIGURAÇÕES E BASES EXISTENTES)
# ==============================================================================
print_header "5. BANCOS DE DADOS (QUAIS, VERSÕES, DATADIR, TAMANHO E BASES EXISTENTES)"

DB_ANY_FOUND=0

# 5.1 - MariaDB / MySQL
if command -v mariadb >/dev/null 2>&1 || command -v mysql >/dev/null 2>&1 || [[ -d /var/lib/mysql ]]; then
    DB_ANY_FOUND=1
    DB_BIN=$(command -v mariadb || command -v mysql || echo "")
    DB_VER="Instalado"
    [[ -n "$DB_BIN" ]] && DB_VER=$($DB_BIN --version 2>/dev/null || echo "Instalado")
    DB_SVC="mariadb"
    for cand_svc in mariadb mysql mysqld; do
        if [[ "$(get_service_status_plain "$cand_svc")" == "Ativo" ]]; then
            DB_SVC="$cand_svc"
            break
        elif [[ "$(get_service_status_plain "$cand_svc")" == "Inativo" ]]; then
            DB_SVC="$cand_svc"
        fi
    done

    MYSQL_DATADIR="/var/lib/mysql"
    MYSQL_SIZE="N/A"
    [[ -d "$MYSQL_DATADIR" ]] && MYSQL_SIZE=$(du -sh "$MYSQL_DATADIR" 2>/dev/null | awk '{print $1}' || echo "N/A")
    MYSQL_BIND=$(grep -RhE "^\s*bind-address\s*=" /etc/mysql/ /etc/my.cnf /etc/my.cnf.d/ 2>/dev/null | tail -n 1 | cut -d'=' -f2 | xargs || echo "Padrão (127.0.0.1)")

    log_success "MySQL / MariaDB (${DB_SVC}): ${BOLD}${DB_VER}${NC} [$(get_service_status "$DB_SVC")]"
    echo -e "    • ${BOLD}Configuração:${NC} Bind-Address: ${FG_CYAN}${MYSQL_BIND}${NC} | Datadir: ${MYSQL_DATADIR} (Tamanho em disco: ${FG_YELLOW}${MYSQL_SIZE}${NC})"
    add_unique_item RESUMO_APPS_VERSOES "${DB_SVC}:${DB_VER}"

    if [[ "$(get_service_status_plain "$DB_SVC")" == "Ativo" ]]; then
        add_role "Banco de Dados (${DB_SVC})"
        add_unique_item RESUMO_BANCOS_ATIVOS "Host-${DB_SVC} (${MYSQL_SIZE})"
    fi

    if (( IS_ROOT == 1 )) && [[ -n "$DB_BIN" ]] && [[ "$(get_service_status_plain "$DB_SVC")" == "Ativo" ]]; then
        MYSQL_DBS=$($DB_BIN --batch --skip-column-names -e "
            SELECT s.schema_name,
                   COUNT(t.table_name) AS total_tables,
                   ROUND(IFNULL(SUM(t.data_length + t.index_length) / 1024 / 1024, 0), 2) AS size_mb
            FROM information_schema.schemata s
            LEFT JOIN information_schema.tables t ON s.schema_name = t.table_schema
            WHERE s.schema_name NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
            GROUP BY s.schema_name
            ORDER BY size_mb DESC;" 2>/dev/null || true)

        if [[ -n "$MYSQL_DBS" ]]; then
            echo -e "    • ${BOLD}Bases de Dados (Schemas) Existentes no MariaDB/MySQL:${NC}"
            while IFS=$'\t' read -r db_name tbl_count db_size; do
                [[ -z "$db_name" ]] && continue
                echo -e "      ├─ Base: ${FG_CYAN}${BOLD}${db_name}${NC} | Tabelas: ${tbl_count} | Tamanho: ${FG_YELLOW}${db_size} MB${NC}"
            done <<< "$MYSQL_DBS"
        else
            log_info "Nenhuma base de usuário encontrada ou acesso via socket local requer senha SQL."
        fi

        MYSQL_USERS=$($DB_BIN --batch --skip-column-names -e "SELECT CONCAT(User, '@', Host) FROM mysql.user WHERE User NOT IN ('mariadb.sys','mysql.sys','mysql.session','mysql.infoschema') ORDER BY User;" 2>/dev/null | xargs || true)
        [[ -n "$MYSQL_USERS" ]] && echo -e "    • ${BOLD}Usuários SQL:${NC} ${DIM}${MYSQL_USERS}${NC}"
        if echo "$MYSQL_USERS" | grep -q "@%"; then
            add_alert "Existem usuários no MariaDB/MySQL com permissão de acesso remoto amplo ('@%')."
        fi
    fi
    echo -e ""
fi

# 5.2 - PostgreSQL
if command -v psql >/dev/null 2>&1 || [[ -d /etc/postgresql ]] || [[ -d /var/lib/pgsql ]] || [[ -d /var/lib/postgresql ]]; then
    DB_ANY_FOUND=1
    PG_VER=$(psql --version 2>/dev/null || echo "Instalado")
    PG_SVC="postgresql"
    if [[ "$(get_service_status_plain postgresql)" == "Não instalado" ]] && command -v systemctl >/dev/null 2>&1; then
        PG_UNIT_FOUND=$(systemctl list-unit-files 'postgresql*.service' 2>/dev/null | awk '/postgresql/ {sub(/\.service/,"",$1); print $1}' | head -n 1 || true)
        [[ -n "$PG_UNIT_FOUND" ]] && PG_SVC="$PG_UNIT_FOUND"
    fi
    PG_SIZE="N/A"
    for pg_dir in /var/lib/postgresql /var/lib/pgsql; do
        [[ -d "$pg_dir" ]] && PG_SIZE=$(du -sh "$pg_dir" 2>/dev/null | awk '{print $1}' || echo "N/A") && break
    done

    log_success "PostgreSQL (${PG_SVC}): ${BOLD}${PG_VER}${NC} [$(get_service_status "$PG_SVC")] (Tamanho em disco: ${FG_YELLOW}${PG_SIZE}${NC})"
    add_unique_item RESUMO_APPS_VERSOES "PostgreSQL:${PG_VER}"
    if [[ "$(get_service_status_plain "$PG_SVC")" == "Ativo" ]]; then
        add_role "Banco de Dados (PostgreSQL)"
        add_unique_item RESUMO_BANCOS_ATIVOS "Host-PostgreSQL (${PG_SIZE})"
    fi

    if command -v pg_lsclusters >/dev/null 2>&1; then
        echo -e "    • ${BOLD}Clusters PostgreSQL (pg_lsclusters):${NC}"
        pg_lsclusters 2>/dev/null | sed 's/^/      /' || true
    fi

    if (( IS_ROOT == 1 )) && [[ "$(get_service_status_plain "$PG_SVC")" == "Ativo" ]] && id postgres >/dev/null 2>&1; then
        PG_DBS=$(runuser -u postgres -- psql -Atc "SELECT datname || '|' || pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false AND datname != 'postgres' ORDER BY pg_database_size(datname) DESC;" 2>/dev/null || true)
        if [[ -n "$PG_DBS" ]]; then
            echo -e "    • ${BOLD}Bases de Dados Criadas no PostgreSQL:${NC}"
            while IFS='|' read -r pg_db pg_sz; do
                [[ -z "$pg_db" ]] && continue
                echo -e "      ├─ Base: ${FG_CYAN}${BOLD}${pg_db}${NC} | Tamanho: ${FG_YELLOW}${pg_sz}${NC}"
            done <<< "$PG_DBS"
        fi
    fi
    echo -e ""
fi

# 5.3 - Redis / Valkey, MongoDB, Firebird, SQL Server, Elasticsearch, RabbitMQ, Memcached
if command -v redis-server >/dev/null 2>&1 || command -v valkey-server >/dev/null 2>&1; then
    DB_ANY_FOUND=1
    REDIS_VER=$(redis-server --version 2>/dev/null | awk '{print $3}' || valkey-server --version 2>/dev/null | awk '{print $3}' || echo "Instalado")
    REDIS_SVC="redis-server"
    [[ "$(get_service_status_plain redis-server)" == "Não instalado" && "$(get_service_status_plain redis)" != "Não instalado" ]] && REDIS_SVC="redis"
    log_success "Redis / Valkey (${REDIS_SVC}): ${BOLD}${REDIS_VER}${NC} [$(get_service_status "$REDIS_SVC")]"
    add_unique_item RESUMO_APPS_VERSOES "Redis:${REDIS_VER}"
    [[ "$(get_service_status_plain "$REDIS_SVC")" == "Ativo" ]] && add_unique_item RESUMO_BANCOS_ATIVOS "Host-Redis:Ativo"
fi

for other_db in mongod mongodb firebird mssql-server elasticsearch rabbitmq-server memcached; do
    if command -v "$other_db" >/dev/null 2>&1 || [[ "$(get_service_status_plain "$other_db")" != "Não instalado" ]]; then
        DB_ANY_FOUND=1
        ODB_VER=$($other_db --version 2>/dev/null | head -n 1 || echo "Instalado")
        log_success "Banco/Mensageria/Cache adicional: ${BOLD}${other_db}${NC} (${ODB_VER}) [$(get_service_status "$other_db")]"
        add_unique_item RESUMO_APPS_VERSOES "${other_db}:${ODB_VER}"
        if [[ "$(get_service_status_plain "$other_db")" == "Ativo" ]]; then
            add_role "Dados/Mensageria (${other_db})"
            add_unique_item RESUMO_BANCOS_ATIVOS "Host-${other_db}:Ativo"
        fi
    fi
done

(( DB_ANY_FOUND == 0 )) && log_info "Nenhum SGBD instalado diretamente no host (verifique a subseção 4.5 de Contêineres)."

# ==============================================================================
# SEÇÃO 6 - FIREWALL (ATIVO OU INATIVO), REGRAS CONFIGURADAS E SEGURANÇA
# ==============================================================================
print_header "6. FIREWALL (ATIVO OU INATIVO), REGRAS CONFIGURADAS E SEGURANÇA"

# 6.1 - Status do Firewall e Listagem das Regras (UFW, Firewalld, NFTables, IPTables)
echo -e "  ${BOLD}Status dos Mecanismos de Firewall e Regras Ativas:${NC}"
FIREWALL_SUMMARY_STATE="INATIVO (Nenhum filtro ativo)"
FW_ACTIVE_ANY=0

# UFW
if command -v ufw >/dev/null 2>&1; then
    UFW_OUT=$(ufw status verbose 2>/dev/null || ufw status 2>/dev/null || true)
    UFW_FIRST=$(echo "$UFW_OUT" | head -n 1 || echo "Inativo")
    if echo "$UFW_FIRST" | grep -qiE "status:\s*(active|ativo)"; then
        FW_ACTIVE_ANY=1
        FIREWALL_SUMMARY_STATE="ATIVO (UFW)"
        echo -e "    • ${BOLD}Firewall UFW:${NC} ${FG_GREEN}${BOLD}ATIVO${NC}"
        echo -e "      ${BOLD}Regras Configuradas no UFW (ufw status numbered):${NC}"
        UFW_NUMBERED=$(ufw status numbered 2>/dev/null || echo "$UFW_OUT")
        while IFS= read -r ufw_l; do
            echo -e "        ${ufw_l}"
        done <<< "$UFW_NUMBERED"
    else
        echo -e "    • ${BOLD}Firewall UFW:${NC} ${FG_YELLOW}INATIVO${NC} ${DIM}(${UFW_FIRST:-desativado})${NC}"
    fi
fi

# Firewalld
if command -v firewall-cmd >/dev/null 2>&1; then
    if [[ "$(get_service_status_plain firewalld)" == "Ativo" ]]; then
        FW_ACTIVE_ANY=1
        FIREWALL_SUMMARY_STATE="ATIVO (Firewalld)"
        echo -e "    • ${BOLD}Firewalld (RHEL/SUSE):${NC} ${FG_GREEN}${BOLD}ATIVO${NC}"
        echo -e "      ${BOLD}Zonas, Serviços e Portas Liberadas no Firewalld:${NC}"
        firewall-cmd --list-all 2>/dev/null | sed 's/^/        /' || true
    else
        echo -e "    • ${BOLD}Firewalld:${NC} ${FG_YELLOW}INATIVO${NC}"
    fi
fi

# IPTables
if command -v iptables >/dev/null 2>&1 && (( IS_ROOT == 1 )); then
    IPT_POLICIES=$(iptables -S 2>/dev/null | grep "^-P " | tr '\n' ' ' || true)
    IPT_INPUT_RULES=$(iptables -S INPUT 2>/dev/null | grep -v "^-P INPUT" || true)
    IPT_DOCKER_USER=$(iptables -S DOCKER-USER 2>/dev/null | grep -vE "^-N |^-A DOCKER-USER -j RETURN" || true)
    if [[ -n "$IPT_INPUT_RULES" || "$IPT_POLICIES" == *"DROP"* || "$IPT_POLICIES" == *"REJECT"* ]]; then
        FW_ACTIVE_ANY=1
        [[ "$FIREWALL_SUMMARY_STATE" == "INATIVO"* ]] && FIREWALL_SUMMARY_STATE="ATIVO (IPTables)"
        echo -e "    • ${BOLD}IPTables (Netfilter):${NC} ${FG_GREEN}Regras Customizadas Detectadas${NC} — Políticas: ${FG_CYAN}${IPT_POLICIES}${NC}"
        if [[ -n "$IPT_INPUT_RULES" ]]; then
            echo -e "      ${BOLD}Regras na Chain INPUT (Top 20):${NC}"
            echo "$IPT_INPUT_RULES" | head -n 20 | sed 's/^/        /'
        fi
        if [[ -n "$IPT_DOCKER_USER" ]]; then
            echo -e "      ${BOLD}Regras na Chain DOCKER-USER:${NC}"
            echo "$IPT_DOCKER_USER" | head -n 10 | sed 's/^/        /'
        fi
    else
        echo -e "    • ${BOLD}IPTables (Chain INPUT):${NC} ${DIM}Sem regras de bloqueio na INPUT (Políticas: ${IPT_POLICIES:-ACCEPT})${NC}"
    fi
fi

# NFTables
if command -v nft >/dev/null 2>&1 && (( IS_ROOT == 1 )); then
    NFT_TABLES=$(nft list tables 2>/dev/null || true)
    if [[ -n "$NFT_TABLES" ]]; then
        NFT_COUNT=$(echo "$NFT_TABLES" | wc -l)
        echo -e "    • ${BOLD}NFTables:${NC} ${FG_CYAN}${NFT_COUNT} tabela(s) carregada(s) no kernel${NC} (${DIM}$(echo "$NFT_TABLES" | tr '\n' '; ' | sed 's/; $//')${NC})"
        if [[ "$(get_service_status_plain nftables)" == "Ativo" ]]; then
            FW_ACTIVE_ANY=1
            [[ "$FIREWALL_SUMMARY_STATE" == "INATIVO"* ]] && FIREWALL_SUMMARY_STATE="ATIVO (NFTables)"
        fi
    fi
fi

if (( FW_ACTIVE_ANY == 0 )); then
    log_warning "Status Geral do Firewall: ${FG_RED}${BOLD}INATIVO${NC} (Nenhum filtro de host bloqueando conexões de entrada)"
    add_alert "O servidor está com o Firewall de host INATIVO (UFW/Firewalld/IPTables sem regras de bloqueio na INPUT)."
else
    log_success "Status Geral do Firewall: ${FG_GREEN}${BOLD}${FIREWALL_SUMMARY_STATE}${NC}"
fi

# 6.2 - Segurança de Acesso Remoto (SSH), Fail2Ban, SELinux/AppArmor e Systemd Failed
echo -e "\n  ${BOLD}Segurança de Acesso SSH, IPS (Fail2Ban) e Controle Mandatório:${NC}"
if command -v sshd >/dev/null 2>&1 || [[ -r /etc/ssh/sshd_config ]]; then
    SSH_ROOT_LOGIN="Não verificado"
    SSH_PASS_AUTH="Não verificado"
    SSH_PORT_CFG="22"
    SSHD_T=""
    if (( IS_ROOT == 1 )) && command -v sshd >/dev/null 2>&1; then
        SSHD_T=$(sshd -T 2>/dev/null || true)
    fi
    if [[ -n "$SSHD_T" ]]; then
        SSH_ROOT_LOGIN=$(echo "$SSHD_T" | awk '/^permitrootlogin / {print $2}' | head -n 1)
        SSH_PASS_AUTH=$(echo "$SSHD_T" | awk '/^passwordauthentication / {print $2}' | head -n 1)
        SSH_PORT_CFG=$(echo "$SSHD_T" | awk '/^port / {print $2}' | xargs)
    elif [[ -r /etc/ssh/sshd_config ]]; then
        SSH_ROOT_LOGIN=$( grep -h -iE "^\s*PermitRootLogin\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -n 1 || true )
        SSH_PASS_AUTH=$( grep -h -iE "^\s*PasswordAuthentication\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -n 1 || true )
        SSH_PORT_CFG=$( grep -h -iE "^\s*Port\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | xargs || true )
    fi
    log_item "Serviço OpenSSH" "Porta(s): ${FG_CYAN}${SSH_PORT_CFG:-22}${NC} | PermitRootLogin: ${FG_YELLOW}${SSH_ROOT_LOGIN:-padrão}${NC} | PasswordAuth: ${SSH_PASS_AUTH:-padrão}"
    [[ "$SSH_ROOT_LOGIN" == "yes" ]] && add_alert "SSH está com PermitRootLogin habilitado ('yes')."
fi

if command -v fail2ban-client >/dev/null 2>&1; then
    F2B_STATUS=$(get_service_status fail2ban)
    log_item "Fail2Ban (IPS)" "${F2B_STATUS}"
    if [[ "$(get_service_status_plain fail2ban)" == "Ativo" ]] && (( IS_ROOT == 1 )); then
        JAILS=$(fail2ban-client status 2>/dev/null | awk -F':' '/Jail list/ {print $2}' | xargs || true)
        log_item "Jails Ativas" "${FG_GREEN}${JAILS:-Nenhuma}${NC}"
    fi
else
    log_item "Fail2Ban (IPS)" "Não instalado"
fi

if command -v getenforce >/dev/null 2>&1; then
    log_item "SELinux" "${FG_CYAN}$(getenforce 2>/dev/null || echo "Instalado")${NC}"
elif command -v aa-status >/dev/null 2>&1 && (( IS_ROOT == 1 )); then
    if aa-status --enabled 2>/dev/null; then
        AA_PROFILES=$(aa-status --profiled 2>/dev/null || echo "0")
        log_item "AppArmor" "${FG_GREEN}Ativo (${AA_PROFILES} perfis carregados)${NC}"
    else
        log_item "AppArmor" "${FG_YELLOW}Inativo${NC}"
    fi
fi

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    FAILED_UNITS=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | xargs || true)
    if [[ -n "$FAILED_UNITS" ]]; then
        log_warning "Serviços do Systemd em estado FAILED: ${FG_RED}${FAILED_UNITS}${NC}"
        add_alert "Unidades systemd com falha detectadas: ${FAILED_UNITS}"
    else
        log_item "Systemd Failed Units" "${FG_GREEN}Nenhuma (0 falhas)${NC}"
    fi
fi

# ==============================================================================
# SEÇÃO 7 - PORTAS ABERTAS (LISTEN), REDE, /ETC/HOSTS E CONEXÕES ATIVAS
# ==============================================================================
print_header "7. PORTAS ABERTAS (LISTEN), REDE, /ETC/HOSTS E CONEXÕES ATIVAS"

# 7.1 - Tabela de Portas Abertas (TCP/UDP) com PID, Serviço e CWD
echo -e "  ${BOLD}Portas Abertas em Escuta (LISTEN TCP/UDP) e Processos Responsáveis:${NC}\n"
printf "    ${BOLD}%-6s %-22s %-7s %-10s %-22s %s${NC}\n" "PROTO" "ENDEREÇO LOCAL" "PORTA" "ESCOPO" "PROCESSO (PID)" "SERVIÇO / DIRETÓRIO (CWD)"
draw_separator

if command -v ss >/dev/null 2>&1; then
    while IFS='|' read -r proto local_addr port proc_raw pid_num; do
        [[ -z "$proto" ]] && continue
        scope="LOCAL"
        if [[ "$local_addr" == "0.0.0.0" || "$local_addr" == "[::]" || "$local_addr" == "*" ]]; then
            scope="PÚBLICO"
        elif [[ "$local_addr" != 127.* && "$local_addr" != "[::1]" ]]; then
            scope="REDE/LAN"
        fi

        extra_context="-"
        if [[ -n "$pid_num" && "$pid_num" =~ ^[0-9]+$ ]]; then
            unit_name=""
            if [[ -r "/proc/${pid_num}/cgroup" ]]; then
                unit_name=$(grep -oE '[^/]+\.service' "/proc/${pid_num}/cgroup" 2>/dev/null | head -n 1 || true)
            fi
            cwd_path=""
            if [[ -L "/proc/${pid_num}/cwd" ]]; then
                cwd_path=$(readlink -f "/proc/${pid_num}/cwd" 2>/dev/null || true)
            fi
            if [[ -n "$unit_name" && -n "$cwd_path" && "$cwd_path" != "/" ]]; then
                extra_context="${unit_name} (${cwd_path})"
            elif [[ -n "$unit_name" ]]; then
                extra_context="${unit_name}"
            elif [[ -n "$cwd_path" ]]; then
                extra_context="cwd: ${cwd_path}"
            fi
        elif (( IS_ROOT == 0 )); then
            proc_raw="Requer root (sudo)"
        fi

        printf "    %-6s %-22s %-7s %-10s %-22s %s\n" \
            "$proto" "$local_addr" "$port" "$scope" "${proc_raw:-N/A}" "$extra_context"

        if [[ "$scope" == "PÚBLICO" ]] && [[ "$port" =~ ^(3306|5432|6379|27017|11211|9200)$ ]]; then
            add_alert "Porta sensível de banco/cache (${port}/${proto} - ${proc_raw}) está aberta em todas as interfaces (${local_addr})."
        fi
    done < <(ss -tulpn 2>/dev/null | awk '$1 !~ /^(Netid|State)$/ {
        proto = $1
        local_full = $5
        proc_col = ""
        for (i=7; i<=NF; i++) proc_col = proc_col $i " "

        n = split(local_full, parts, ":")
        port = parts[n]
        addr = substr(local_full, 1, length(local_full) - length(port) - 1)
        if (addr == "" || addr == "*") addr = "0.0.0.0"

        proc_name = "-"
        pid = ""
        if (match(proc_col, /\("[^"]+",pid=[0-9]+/)) {
            seg = substr(proc_col, RSTART, RLENGTH)
            sub(/^\("/, "", seg)
            split(seg, p, "\",pid=")
            proc_name = p[1]
            pid = p[2]
        }
        proc_display = (pid != "" ? proc_name " (" pid ")" : proc_name)
        print proto "|" addr "|" port "|" proc_display "|" pid
    }' | sort -t'|' -k3,3n -k1,1 -u)
else
    netstat -tulpn 2>/dev/null | awk 'NR>2 {printf "    %-6s %-25s %-30s\n", $1, $4, $7}' || true
fi

# 7.2 - Endereçamento IP, Rotas, DNS, /etc/hosts e Conexões Estabelecidas
echo -e "\n  ${BOLD}Configuração de Rede, Rotas e DNS:${NC}"
DEFAULT_GATEWAY=$(ip route 2>/dev/null | awk '/^default/ {print $3 " (via " $5 ")"}' | head -n 1 || true)
DNS_SERVERS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | xargs || true)
SEARCH_DOMAINS=$(awk '/^(search|domain)/ {$1=""; print $0}' /etc/resolv.conf 2>/dev/null | xargs || true)
if command -v resolvectl >/dev/null 2>&1; then
    RESOLVED_DNS=$(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1 && $2!="" {print $2}' | xargs || true)
    [[ -n "$RESOLVED_DNS" ]] && DNS_SERVERS="${DNS_SERVERS} (Upstream: ${RESOLVED_DNS})"
fi
PUBLIC_IP="Não detectado / Sem saída HTTPS"
if command -v curl >/dev/null 2>&1; then
    PUBLIC_IP=$(curl -4 -fsS --connect-timeout 2 --max-time 3 https://ifconfig.me 2>/dev/null || echo "Não detectado")
fi
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n 1 || echo "N/A")

log_item "IP Local Principal"  "${FG_GREEN}${PRIMARY_IP:-Nenhum}${NC}"
log_item "Gateway Padrão"      "${DEFAULT_GATEWAY:-Nenhum}"
log_item "Servidores DNS"      "${DNS_SERVERS:-Nenhum}${SEARCH_DOMAINS:+ (Domínio Busca: $SEARCH_DOMAINS)}"
log_item "IP Público de Saída" "${FG_CYAN}${PUBLIC_IP}${NC}"

if command -v ip >/dev/null 2>&1; then
    echo -e "\n  ${BOLD}Interfaces de Rede:${NC}"
    ip -br addr show 2>/dev/null | awk '{printf "    • %-16s %-10s %s\n", $1, $2, $3}' ||
    ip addr show 2>/dev/null | awk '/^[0-9]+:/ {iface=$2; sub(/:/,"",iface)} /inet / {printf "    • %-16s %s\n", iface, $2}' || true
fi

CUSTOM_HOSTS=$(grep -vE "^\s*#|^\s*$|^127\.0\.0\.1\s+localhost|^127\.0\.1\.1|^::1|^fe00:|^ff00:|^ff02:" /etc/hosts 2>/dev/null || true)
if [[ -n "$CUSTOM_HOSTS" ]]; then
    echo -e "\n  ${BOLD}Mapeamentos Customizados em /etc/hosts (Integrações Internas):${NC}"
    while IFS= read -r h_line; do
        echo -e "    • ${FG_YELLOW}${h_line}${NC}"
    done <<< "$CUSTOM_HOSTS"
fi

if command -v ss >/dev/null 2>&1; then
    ESTAB_CONNS=$(ss -tnp state established 2>/dev/null | awk 'NR>1 {
        local_addr=$3; peer_addr=$4; proc=$5
        gsub(/users:\(\(/, "", proc); gsub(/\)\)/, "", proc); gsub(/"/, "", proc)
        if (peer_addr !~ /^127\./ && peer_addr !~ /^\[::1\]/) {
            print local_addr " -> " peer_addr " [" (proc ? proc : "N/A") "]"
        }
    }' | sort -u | head -n 15 || true)
    if [[ -n "$ESTAB_CONNS" ]]; then
        echo -e "\n  ${BOLD}Conexões TCP Estabelecidas Neste Momento (Comunicação Externa/Interna):${NC}"
        while IFS= read -r ec; do
            echo -e "    • ${FG_CYAN}${ec}${NC}"
        done <<< "$ESTAB_CONNS"
    fi
fi

# ==============================================================================
# SEÇÃO 8 - AUTOMAÇÃO, AGENDAMENTOS (CRON/TIMERS), SCRIPTS E BACKUPS LOCAIS
# ==============================================================================
print_header "8. AUTOMAÇÃO, AGENDAMENTOS (CRON / TIMERS), SCRIPTS E BACKUPS LOCAIS"

# 8.1 - Crontabs e Systemd Timers
if (( IS_ROOT == 1 )); then
    for user_cron in /var/spool/cron/crontabs/* /var/spool/cron/*; do
        [[ -f "$user_cron" ]] || continue
        CRON_USER=$(basename "$user_cron")
        CRON_LINES=$(grep -vE "^\s*#|^\s*$" "$user_cron" 2>/dev/null || true)
        if [[ -n "$CRON_LINES" ]]; then
            echo -e "  ${BOLD}Crontab do Usuário [${FG_CYAN}${CRON_USER}${NC}${BOLD}]:${NC}"
            while IFS= read -r c_line; do
                echo -e "    • ${c_line}"
            done <<< "$CRON_LINES"
        fi
    done
else
    ROOT_CRON=$(crontab -l 2>/dev/null | grep -vE "^\s*#|^\s*$" || true)
    if [[ -n "$ROOT_CRON" ]]; then
        echo -e "  ${BOLD}Crontab do Usuário Atual:${NC}"
        while IFS= read -r c_line; do
            echo -e "    • ${c_line}"
        done <<< "$ROOT_CRON"
    fi
fi

if [[ -f /etc/crontab ]]; then
    SYS_CRON=$(grep -vE "^\s*#|^\s*$|^(SHELL|PATH|MAILTO|HOME)=" /etc/crontab 2>/dev/null || true)
    if [[ -n "$SYS_CRON" ]]; then
        echo -e "\n  ${BOLD}Entradas em /etc/crontab:${NC}"
        while IFS= read -r c_line; do
            echo -e "    • ${c_line}"
        done <<< "$SYS_CRON"
    fi
fi

echo -e "\n  ${BOLD}Scripts Agendados em /etc/cron.d/, cron.daily e cron.hourly:${NC}"
find /etc/cron.d /etc/cron.daily /etc/cron.hourly -maxdepth 1 -type f ! -name ".placeholder" ! -name "0anacron" 2>/dev/null | awk '{print "    • " $0}' || echo "    • Nenhum arquivo encontrado"

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    echo -e "\n  ${BOLD}Systemd Timers Ativos:${NC}"
    systemctl list-timers --no-legend --plain 2>/dev/null | awk '{printf "    • %-35s -> Aciona: %s\n", $(NF-1), $NF}' || true
fi

# 8.2 - Scripts Administrativos Locais e Arquivos de Backup/Dump
CUSTOM_SCRIPTS=$(find /root /usr/local/bin /usr/local/sbin /opt -maxdepth 2 -type f \( -name "*.sh" -o -name "*.py" \) ! -name "auditoria_servidor_inventario.sh" 2>/dev/null | head -n 20 || true)
if [[ -n "$CUSTOM_SCRIPTS" ]]; then
    echo -e "\n  ${BOLD}Scripts Administrativos / Automação Local (/root, /usr/local/bin, /opt):${NC}"
    while IFS= read -r cs; do
        echo -e "    • ${FG_YELLOW}${cs}${NC}"
    done <<< "$CUSTOM_SCRIPTS"
fi

BACKUP_ARCHIVES=$(find /var/backups /backup /backups /root /home -maxdepth 3 -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.dump" -o -name "*backup*.tar.gz" -o -name "*bkp*.tar.gz" \) 2>/dev/null | head -n 15 || true)
if [[ -n "$BACKUP_ARCHIVES" ]]; then
    echo -e "\n  ${BOLD}Arquivos de Dump / Backup Localizados no Disco:${NC}"
    while IFS= read -r ba; do
        BA_SIZE=$(du -sh "$ba" 2>/dev/null | awk '{print $1}' || echo "N/A")
        echo -e "    • ${FG_CYAN}${ba}${NC} (${BA_SIZE})"
    done <<< "$BACKUP_ARCHIVES"
fi

# ==============================================================================
# RESUMO EXECUTIVO DO INVENTÁRIO (PAINEL CONSOLIDADO NA ORDEM SOLICITADA)
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO E DIAGNÓSTICO DO SERVIDOR"

ROLES_STR="Servidor Linux Genérico / Sem Serviços de Rede Ativos"
if (( ${#PAPEIS_DETECTADOS[@]} > 0 )); then
    ROLES_STR=$(IFS=' + '; echo "${PAPEIS_DETECTADOS[*]}")
fi

APPS_SUMMARY_STR="Nenhuma aplicação principal detectada"
if (( ${#RESUMO_APPS_VERSOES[@]} > 0 )); then
    APPS_SUMMARY_STR=$(printf '%s, ' "${RESUMO_APPS_VERSOES[@]}" | sed 's/, $//')
fi

PHP_SUMMARY_STR="Não instalado (Host e Containers)"
PHP_SUMMARY_COLOR="$DIM"
if (( ${#RESUMO_PHP_VERSOES[@]} > 0 )); then
    PHP_SUMMARY_STR=$(printf '%s, ' "${RESUMO_PHP_VERSOES[@]}" | sed 's/, $//')
    PHP_SUMMARY_COLOR="$FG_GREEN"
fi

DB_SUMMARY_STR="Nenhum ativo"
if (( ${#RESUMO_BANCOS_ATIVOS[@]} > 0 )); then
    DB_SUMMARY_STR=$(printf '%s, ' "${RESUMO_BANCOS_ATIVOS[@]}" | sed 's/, $//')
fi

SUDO_USERS_STR="Nenhum identificado"
if (( ${#RESUMO_USUARIOS_SUDO[@]} > 0 )); then
    SUDO_USERS_STR=$(printf '%s, ' "${RESUMO_USUARIOS_SUDO[@]}" | sed 's/, $//')
fi

SUDO_GROUPS_STR="Nenhum identificado"
if (( ${#RESUMO_GRUPOS_SUDO[@]} > 0 )); then
    SUDO_GROUPS_STR=$(printf '%s, ' "${RESUMO_GRUPOS_SUDO[@]}" | sed 's/, $//')
fi

STORAGE_REDE_STR="Apenas discos locais (Sem NFS/Samba/LDAP ativo)"
if (( ${#RESUMO_STORAGE_REDE[@]} > 0 )); then
    STORAGE_REDE_STR=$(printf '%s, ' "${RESUMO_STORAGE_REDE[@]}" | sed 's/, $//')
fi

UPDATES_SUMMARY_COLOR="$FG_GREEN"
if (( PENDING_UPDATES_COUNT > 0 )); then
    UPDATES_SUMMARY_COLOR="$FG_YELLOW"
fi

REBOOT_SUMMARY_COLOR="$FG_GREEN"
if [[ "$REBOOT_NEEDED" == "Sim" ]]; then
    REBOOT_SUMMARY_COLOR="$FG_RED"
fi

FW_SUMMARY_COLOR="$FG_GREEN"
if [[ "$FIREWALL_SUMMARY_STATE" == "INATIVO"* ]]; then
    FW_SUMMARY_COLOR="$FG_RED"
fi

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]:-Nenhum (Modo 100% Passivo / Somente Leitura)}")

print_summary "1. Sistema Operacional:"     "${OS_NAME} (Kernel ${KERNEL_VER})" "$FG_CYAN"
print_summary "   Status de Atualização:"   "${OS_UPDATE_STATUS_STR}" "$UPDATES_SUMMARY_COLOR"
print_summary "   Aguardando Reboot?"       "${REBOOT_NEEDED}${REBOOT_REASON:+ ($REBOOT_REASON)}" "$REBOOT_SUMMARY_COLOR"
print_summary "2. Usuários com Sudo:"       "${SUDO_USERS_STR}" "$FG_YELLOW"
print_summary "   Grupos com Sudo:"         "${SUDO_GROUPS_STR}" "$FG_CYAN"
print_summary "3. NFS / Samba / LDAP:"      "${STORAGE_REDE_STR}" "$FG_CYAN"
print_summary "4. Papel do Servidor:"       "${ROLES_STR}" "$FG_YELLOW"
print_summary "   Aplicações e Versões:"    "${APPS_SUMMARY_STR}" "$FG_GREEN"
print_summary "   PHP (Host + Containers):" "${PHP_SUMMARY_STR}" "$PHP_SUMMARY_COLOR"
print_summary "   Containers em Execução:"  "${#RESUMO_CONTAINERS_ATIVOS[@]} ativo(s)" "$FG_CYAN"
print_summary "5. Bancos de Dados:"         "${DB_SUMMARY_STR}" "$FG_CYAN"
print_summary "6. Firewall de Host:"        "${FIREWALL_SUMMARY_STATE}" "$FW_SUMMARY_COLOR"
print_summary "7. Hostname / IP Principal:" "${HOSTNAME_SHORT} (${PRIMARY_IP:-N/A})" "$FG_GREEN"
print_summary "8. Pacotes Instalados:"      "${LISTA_PACOTES}" "$DIM"
print_summary "9. Relatório na Home:"       "${EXECUTOR_HOME}/${LOG_FILENAME}" "$FG_GREEN"
draw_separator

if (( ${#RESUMO_CONTAINERS_ATIVOS[@]} > 0 )); then
    echo -e "\n  ${BOLD}${FG_CYAN}Contêineres Ativos e Stack Interna Identificada:${NC}"
    for c_item in "${RESUMO_CONTAINERS_ATIVOS[@]}"; do
        echo -e "    • ${c_item}"
    done
fi

if (( ${#RESUMO_SITES_DETECTADOS[@]} > 0 )); then
    echo -e "\n  ${BOLD}${FG_CYAN}Sites, VirtualHosts e Aplicações Identificadas (Host + Containers):${NC}"
    for s_item in "${RESUMO_SITES_DETECTADOS[@]}"; do
        echo -e "    • ${s_item}"
    done
fi

if (( ${#ALERTAS_AUDITORIA[@]} > 0 )); then
    echo -e "\n  ${BOLD}${FG_YELLOW}⚠ PONTOS DE ATENÇÃO E RECOMENDAÇÕES (${#ALERTAS_AUDITORIA[@]}):${NC}"
    for alerta in "${ALERTAS_AUDITORIA[@]}"; do
        echo -e "    ${FG_YELLOW}[!]${NC} ${alerta}"
    done
else
    echo -e "\n  ${FG_GREEN}[+] Nenhum alerta crítico imediato detectado durante a varredura.${NC}"
fi

exit 0
