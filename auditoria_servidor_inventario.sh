#!/bin/bash
# ------------------------------------------------
# Version: 3.2
# ------------------------------------------------
VERSION="3.2"
# ==============================================================================
# AUDITORIA, VARREDURA E INVENTÁRIO 360° DO SERVIDOR LINUX (MULTI-DISTRO)
# ==============================================================================
# Script: auditoria_servidor_inventario.sh
# Descrição: Raio-X completo e 100% passivo (somente leitura) organizado por:
#            1. Sistema Operacional (EOL, Data Instalação), Guest Agent (ESXi/Proxmox), Kernel/OOM e Reboot;
#            2. Usuários (Ativos, Bloqueados, Expirados, Shell Desativado), Sudos e LDAP/AD;
#            3. Armazenamento, Inodes, Partições RO, RAID/ZFS, SMART (bare-metal), FSTAB, NFS e SAMBA;
#            4. Aplicações, Web, SSL, PHP, Runtimes, CMSs/Wikis (MediaWiki, DokuWiki, Nextcloud, Joomla, WP, GLPI, Roundcube, Redmine) e Containers (com versões internas);
#            5. Bancos de Dados (MySQL/MariaDB, PostgreSQL, Redis, Mongo, SQLite);
#            6. Firewall (Ativo/Inativo, Docker Bypass), Regras, SSH, Fail2Ban e Segurança;
#            7. Portas Abertas (LISTEN), Rede, DNS, /etc/hosts e Conexões Ativas;
#            8. Crontabs, Systemd Timers, Scripts, Backups Locais (com data/idade) e Exportação JSON opcional.
#            Grava o relatório exclusivamente na Home do usuário executor.
# Autor: Lucas Oliveira
# Repositório: https://github.com/Lucasolidev/Scripts
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/auditoria_servidor_inventario.sh -O auditoria_servidor_inventario.sh && sudo chmod +x auditoria_servidor_inventario.sh && sudo ./auditoria_servidor_inventario.sh
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Sistema Operacional: Identifica distro, versão, kernel, hardware/VM, verifica se está atualizado, lista quais pacotes estão pendentes e se aguarda reinicialização (reboot required).
# 2. Usuários, Grupos, Sudo e LDAP/AD: Lista usuários ativos e todos os grupos a que pertencem, quem são os usuários/grupos sudo, histórico de acessos e integração LDAP/Active Directory/SSSD/Winbind.
# 3. Armazenamento, Inodes, RAID/ZFS, FSTAB, NFS e SAMBA: Mostra discos/partições, checa inodes (df -i), saúde de RAID (mdadm) e ZFS, valida /etc/fstab (com timeout em montagens remotas) e mapeia NFS/Samba.
# 4. Aplicações (Quais e Versões): Inventaria Servidores Web (Apache e Nginx bloco-a-bloco), Certbot/SSL, PHP (CLI, FPM, CGI, mod_php, extensões, php.ini, CVEs/EOL), Runtimes, Apps (Nextcloud, Joomla, WordPress, Vtiger, GLPI, Moodle, Node, Python) e Contêineres Docker/Podman (restarts, Compose e portas públicas).
# 5. Bancos de Dados (Quais, Versões e Relevantes): Detecta MariaDB/MySQL, PostgreSQL, Redis, MongoDB, Firebird, MSSQL, SQLite, mostrando versão, status, porta/bind, datadir, tamanho em disco e schemas/bases criadas.
# 6. Firewall e Segurança: Verifica Firewall (UFW, Firewalld, NFTables, IPTables), alerta sobre portas Docker que contornam UFW/Firewalld, audita SSH, Fail2Ban (com IPs banidos por jail), SELinux/AppArmor e unidades systemd com falha.
# 7. Portas Abertas e Rede: Lista portas TCP/UDP abertas com PID, serviço e CWD, alerta exposições sensíveis em 0.0.0.0, testa resolução DNS, exibe IPs, rotas, /etc/hosts e conexões estabelecidas.
# 8. Automação, Scripts, Backups e Resumo Executivo: Lista crontabs, timers, scripts locais (.sh/.py), dumps/backups e salva relatório (.log e opcionalmente .json) apenas na Home de quem executou.
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
# 1 - INICIALIZAÇÃO, ARGUMENTOS CLI E FUNÇÕES BASE (100% SOMENTE LEITURA)
# ==============================================================================

OPT_NO_COLOR=0
OPT_FAST=0
OPT_JSON=0
OPT_NO_NET=0
OPT_SECTIONS=""

while (( $# > 0 )); do
    case "$1" in
        --plain|--no-color)
            OPT_NO_COLOR=1
            shift
            ;;
        --fast|--no-du)
            OPT_FAST=1
            shift
            ;;
        --json)
            OPT_JSON=1
            shift
            ;;
        --no-net|--offline)
            OPT_NO_NET=1
            shift
            ;;
        --section|--sections)
            if (( $# < 2 )) || [[ -z "${2:-}" ]]; then
                echo "Erro: --section exige uma lista de números de 1 a 8 (ex: --section 1,2,6)" >&2
                exit 2
            fi
            OPT_SECTIONS="${2// /}"
            if [[ ! "$OPT_SECTIONS" =~ ^[1-8](,[1-8])*$ ]]; then
                echo "Erro: formato inválido em --section '$2' (use números de 1 a 8 separados por vírgula, ex: 1,4,6)" >&2
                exit 2
            fi
            shift 2
            ;;
        --section=*|--sections=*)
            OPT_SECTIONS="${1#*=}"
            OPT_SECTIONS="${OPT_SECTIONS// /}"
            if [[ ! "$OPT_SECTIONS" =~ ^[1-8](,[1-8])*$ ]]; then
                echo "Erro: formato inválido em --section '${OPT_SECTIONS}' (use números de 1 a 8 separados por vírgula, ex: 1,4,6)" >&2
                exit 2
            fi
            shift
            ;;
        -h|--help)
            cat <<EOF
Uso: sudo ./$(basename "$0") [OPÇÕES]

Opções disponíveis:
  --fast, --no-du          Pula cálculos de tamanho (du -sh) em diretórios grandes
  --json                   Exporta também resumo estruturado em JSON na Home
  --no-net, --offline      Pula consultas externas (IP público e teste DNS externo)
  --section 1,2,6          Executa somente as seções indicadas (1 a 8) + Resumo
  --plain, --no-color      Desativa cores ANSI na saída do terminal
  -h, --help               Exibe esta ajuda e sai
EOF
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1 (use --help para ver as opções disponíveis)" >&2
            exit 2
            ;;
    esac
done
[[ -n "${NO_COLOR:-}" ]] && OPT_NO_COLOR=1

section_enabled() {
    local sec="$1"
    [[ -z "${OPT_SECTIONS:-}" ]] && return 0
    [[ ",${OPT_SECTIONS}," == *",${sec},"* ]]
}

# 1.1 - PALETA DE CORES E ESTILOS (ANSI)
if (( OPT_NO_COLOR == 0 )); then
    NC='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    FG_RED='\033[31m'
    FG_GREEN='\033[32m'
    FG_YELLOW='\033[33m'
    FG_BLUE='\033[94m'
    FG_CYAN='\033[36m'
    # shellcheck disable=SC2034
    FG_WHITE='\033[37m'
else
    NC=''
    BOLD=''
    DIM=''
    FG_RED=''
    FG_GREEN=''
    FG_YELLOW=''
    FG_BLUE=''
    FG_CYAN=''
    # shellcheck disable=SC2034
    FG_WHITE=''
fi

ARROW="❯"

# 1.2 - FUNÇÕES AUXILIARES DE VISUAL, HIGIENIZAÇÃO E DETECÇÃO MULTI-DISTRO
# shellcheck disable=SC2120
trim_ws() {
    local s=""
    if (( $# > 0 )); then
        s="$1"
    else
        s=$(cat)
    fi
    printf '%s' "$s" | tr '\r\n' '  ' | sed -E 's/^[ \t]+|[ \t]+$//g; s/[ \t]{2,}/ /g'
}

safe_du() {
    local target="$1"
    if (( OPT_FAST == 1 )); then
        printf 'Pulado (--fast)'
        return 0
    fi
    local res=""
    res=$(timeout 5 du -sh "$target" 2>/dev/null | awk '{print $1}' || true)
    printf '%s' "${res:-N/A (>5s)}"
}

_get_file_epoch() {
    local target="$1" ts=""
    [[ -e "$target" ]] || return 1
    ts=$(stat -c '%W' -- "$target" 2>/dev/null || true)
    if ! [[ "$ts" =~ ^[0-9]+$ ]] || (( ts <= 0 )); then
        ts=$(stat -c '%Y' -- "$target" 2>/dev/null || true)
    fi
    if [[ "$ts" =~ ^[0-9]+$ ]] && (( ts >= 946684800 )); then
        printf '%s\n' "$ts"
        return 0
    fi
    return 1
}

_get_earliest_ssh_host_epoch() {
    local f="" ts="" min_ts=""
    for f in /etc/ssh/ssh_host_*_key.pub /etc/ssh/ssh_host_*_key; do
        [[ -e "$f" ]] || continue
        if ts=$(_get_file_epoch "$f"); then
            if [[ -z "$min_ts" ]] || (( ts < min_ts )); then
                min_ts="$ts"
            fi
        fi
    done
    [[ -n "$min_ts" ]] || return 1
    printf '%s\n' "$min_ts"
}

_get_fs_root_epoch() {
    local root_dev="" tune_raw="" ts=""
    root_dev=$(findmnt -no SOURCE / 2>/dev/null || true)
    if [[ -n "$root_dev" && -r "$root_dev" ]] && command -v tune2fs >/dev/null 2>&1; then
        tune_raw=$(LC_ALL=C tune2fs -l "$root_dev" 2>/dev/null | awk -F':[[:space:]]+' '/^Filesystem created:/ {print $2; exit}' || true)
        if [[ -n "$tune_raw" ]]; then
            ts=$(LC_ALL=C date -d "$tune_raw" +%s 2>/dev/null || true)
            if [[ "$ts" =~ ^[0-9]+$ ]] && (( ts >= 946684800 )); then
                printf '%s\n' "$ts"
                return 0
            fi
        fi
    fi
    _get_file_epoch /
}

get_os_install_info() {
    local virt_container="" is_wsl=0 is_container=0
    local fs_ts="" inst_ts="" mach_ts="" ssh_ts="" boot_ts="" chosen_ts="" origem=""
    local date_str="" today_epoch="" inst_day_epoch="" dias=0 dias_txt=""

    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        is_wsl=1
    elif virt_container=$(systemd-detect-virt --container 2>/dev/null) && [[ -n "$virt_container" && "$virt_container" != "none" ]]; then
        is_container=1
    fi

    fs_ts=$(_get_fs_root_epoch || true)
    inst_ts=$(_get_file_epoch /var/log/installer || true)
    if [[ -z "$inst_ts" && -e /root/anaconda-ks.cfg ]]; then
        inst_ts=$(_get_file_epoch /root/anaconda-ks.cfg || true)
    fi
    if [[ -z "$inst_ts" ]] && command -v rpm >/dev/null 2>&1; then
        local rpm_ts=""
        rpm_ts=$(rpm -q --qf '%{INSTALLTIME}\n' basesystem 2>/dev/null | head -n 1 || true)
        if [[ "$rpm_ts" =~ ^[0-9]+$ ]] && (( rpm_ts >= 946684800 )); then
            inst_ts="$rpm_ts"
        fi
    fi
    mach_ts=$(_get_file_epoch /etc/machine-id || true)
    ssh_ts=$(_get_earliest_ssh_host_epoch || true)
    boot_ts="${mach_ts:-$ssh_ts}"

    if (( is_wsl == 1 )); then
        chosen_ts="${boot_ts:-$fs_ts}"
        origem="Primeiro boot WSL"
    elif (( is_container == 1 )); then
        chosen_ts="${boot_ts:-$fs_ts}"
        if [[ "$virt_container" == "lxc" ]]; then
            origem="Primeiro boot LXC"
        else
            origem="Primeiro boot contêiner"
        fi
    elif [[ -n "$inst_ts" ]]; then
        if [[ -n "$boot_ts" ]] && (( boot_ts > inst_ts + 86400 )); then
            chosen_ts="$boot_ts"
            origem="Primeiro boot / Template"
        else
            chosen_ts="$inst_ts"
            origem="VM/Físico"
        fi
    elif [[ -n "$fs_ts" && -n "$boot_ts" ]]; then
        if (( boot_ts > fs_ts + 3600 )); then
            chosen_ts="$boot_ts"
            origem="Primeiro boot / Template"
        else
            chosen_ts="$fs_ts"
            origem="VM/Físico"
        fi
    elif [[ -n "$fs_ts" ]]; then
        chosen_ts="$fs_ts"
        origem="VM/Físico"
    elif [[ -n "$boot_ts" ]]; then
        chosen_ts="$boot_ts"
        origem="Primeiro boot"
    fi

    if [[ -z "$chosen_ts" ]]; then
        printf 'Não identificado'
        return 0
    fi

    date_str=$(date -d "@$chosen_ts" '+%d/%m/%Y' 2>/dev/null || true)
    today_epoch=$(date -d "$(date '+%Y-%m-%d' 2>/dev/null)" +%s 2>/dev/null || true)
    inst_day_epoch=$(date -d "$(date -d "@$chosen_ts" '+%Y-%m-%d' 2>/dev/null)" +%s 2>/dev/null || true)
    if [[ -n "$date_str" && "$today_epoch" =~ ^[0-9]+$ && "$inst_day_epoch" =~ ^[0-9]+$ ]]; then
        dias=$(( (today_epoch - inst_day_epoch) / 86400 ))
        (( dias < 0 )) && dias=0
        case "$dias" in
            0) dias_txt="hoje" ;;
            1) dias_txt="há 1 dia" ;;
            *) dias_txt="há ${dias} dias" ;;
        esac
        printf '%s (%s | %s)' "$date_str" "$dias_txt" "$origem"
    elif [[ -n "$date_str" ]]; then
        printf '%s (%s)' "$date_str" "$origem"
    else
        printf 'Não identificado'
    fi
}

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_BLUE}${BOLD}${ARROW} ${title}${NC}"
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

# Arrays acumuladoras e valores padrão para o Resumo Executivo, JSON e Descoberta
PAPEIS_DETECTADOS=()
ALERTAS_CRITICOS=()
ALERTAS_AUDITORIA=()
RESUMO_APPS_VERSOES=()
RESUMO_PHP_VERSOES=()
RESUMO_SITES_DETECTADOS=()
RESUMO_BANCOS_ATIVOS=()
RESUMO_CONTAINERS_ATIVOS=()
RESUMO_USUARIOS_SUDO=()
RESUMO_GRUPOS_SUDO=()
RESUMO_STORAGE_REDE=()
RESUMO_CERTBOT_STATUS="Não instalado / Sem certificados Let's Encrypt"
PACOTES_INSTALADOS=()
DISCOVERED_WEB_ROOTS=()
AUDITED_APP_DIRS=()
SCAN_DIRS=()
RENEW_MECHANISMS=()
DOCKER_PUBLIC_PORTS=()
SQLITE_DBS_FOUND=()
EXTRA_SSL_CERTS=()
DISABLED_USERS_SUMMARY=()
# shellcheck disable=SC2034
REPOS_TERCEIROS=()
# shellcheck disable=SC2034
CUSTOM_SYSTEMD_UNITS=()

OS_NAME="Não verificado (Seção 1 omitida)"
OS_FAMILY="generic"
OS_INSTALLED_AT="Não verificado (Seção 1 omitida)"
KERNEL_VER=$(uname -r 2>/dev/null || echo "N/A")
VIRT_TYPE="Não verificado"
DETECTED_VIRT="none"
OS_UPDATE_STATUS_STR="Não verificado (Seção 1 omitida)"
PENDING_UPDATES_COUNT=0
REBOOT_NEEDED="Não"
REBOOT_REASON=""
FIREWALL_SUMMARY_STATE="Não verificado (Seção 6 omitida)"
PRIMARY_IP=""
PUBLIC_IP="Não verificado"
APT_SIM=""
DNF_SIM=""
YUM_SIM=""

add_role() {
    local role="$1"
    local r
    if (( ${#PAPEIS_DETECTADOS[@]} > 0 )); then
        for r in "${PAPEIS_DETECTADOS[@]}"; do
            [[ "$r" == "$role" ]] && return 0
        done
    fi
    PAPEIS_DETECTADOS+=("$role")
}

add_critical_alert() {
    local msg="$1" a
    if (( ${#ALERTAS_CRITICOS[@]} > 0 )); then
        for a in "${ALERTAS_CRITICOS[@]}"; do
            [[ "$a" == "$msg" ]] && return 0
        done
    fi
    ALERTAS_CRITICOS+=("$msg")
}

add_alert() {
    local msg="$1" a
    if (( ${#ALERTAS_AUDITORIA[@]} > 0 )); then
        for a in "${ALERTAS_AUDITORIA[@]}"; do
            [[ "$a" == "$msg" ]] && return 0
        done
    fi
    ALERTAS_AUDITORIA+=("$msg")
}

add_unique_item() {
    local arr_name="$1" val="$2"
    [[ -z "$val" ]] && return 0
    local count=0
    eval "count=\${#${arr_name}[@]}"
    if (( count > 0 )); then
        local -a existing=()
        # shellcheck disable=SC2154
        eval "existing=(\"\${${arr_name}[@]}\")"
        local item
        for item in "${existing[@]}"; do
            [[ "$item" == "$val" ]] && return 0
        done
    fi
    eval "${arr_name}+=(\"\$val\")"
}

# shellcheck disable=SC2317,SC2329
_json_escape() {
    printf '%s' "${1:-}" | awk '
        BEGIN { ORS=""; first=1 }
        {
            if (!first) printf "\\n"
            first=0
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "")
            printf "%s", $0
        }
    '
}

# shellcheck disable=SC2317,SC2329
_json_array() {
    local arr_name="$1"
    local count=0 i=0
    eval "count=\${#${arr_name}[@]}"
    printf '['
    if (( count > 0 )); then
        local -a items=()
        # shellcheck disable=SC2154
        eval "items=(\"\${${arr_name}[@]}\")"
        local item
        for item in "${items[@]}"; do
            (( i > 0 )) && printf ', '
            printf '"%s"' "$(_json_escape "$item")"
            i=$((i + 1))
        done
    fi
    printf ']'
}

# shellcheck disable=SC2317,SC2329
write_json_summary() {
    local out_file="$1"
    local fqdn_val
    local -a all_alerts=()
    if (( ${#ALERTAS_CRITICOS[@]} > 0 )); then
        local ac
        for ac in "${ALERTAS_CRITICOS[@]}"; do
            all_alerts+=("[CRITICO] ${ac}")
        done
    fi
    if (( ${#ALERTAS_AUDITORIA[@]} > 0 )); then
        local aw
        for aw in "${ALERTAS_AUDITORIA[@]}"; do
            all_alerts+=("${aw}")
        done
    fi
    fqdn_val=$(hostname -f 2>/dev/null || hostname 2>/dev/null || uname -n 2>/dev/null || echo "")
    cat > "$out_file" <<EOF
{
  "script_version": "$(_json_escape "${VERSION:-}")",
  "scanned_at": "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
  "hostname": "$(_json_escape "${HOSTNAME_SHORT:-}")",
  "fqdn": "$(_json_escape "$fqdn_val")",
  "primary_ip": "$(_json_escape "${PRIMARY_IP:-}")",
  "public_ip": "$(_json_escape "${PUBLIC_IP:-}")",
  "os": "$(_json_escape "${OS_NAME:-}")",
  "os_family": "$(_json_escape "${OS_FAMILY:-}")",
  "os_installed_at": "$(_json_escape "${OS_INSTALLED_AT:-}")",
  "kernel": "$(_json_escape "${KERNEL_VER:-}")",
  "virtualization": "$(_json_escape "${VIRT_TYPE:-}")",
  "updates_pending": ${PENDING_UPDATES_COUNT:-0},
  "reboot_required": "$(_json_escape "${REBOOT_NEEDED:-Não}")",
  "firewall_state": "$(_json_escape "${FIREWALL_SUMMARY_STATE:-INATIVO}")",
  "certbot": "$(_json_escape "${RESUMO_CERTBOT_STATUS:-}")",
  "roles": $(_json_array PAPEIS_DETECTADOS),
  "apps": $(_json_array RESUMO_APPS_VERSOES),
  "php": $(_json_array RESUMO_PHP_VERSOES),
  "databases": $(_json_array RESUMO_BANCOS_ATIVOS),
  "sqlite_dbs": $(_json_array SQLITE_DBS_FOUND),
  "containers": $(_json_array RESUMO_CONTAINERS_ATIVOS),
  "docker_public_ports": $(_json_array DOCKER_PUBLIC_PORTS),
  "sites": $(_json_array RESUMO_SITES_DETECTADOS),
  "sudo_users": $(_json_array RESUMO_USUARIOS_SUDO),
  "sudo_groups": $(_json_array RESUMO_GRUPOS_SUDO),
  "disabled_users": $(_json_array DISABLED_USERS_SUMMARY),
  "third_party_repos": $(_json_array REPOS_TERCEIROS),
  "custom_systemd_units": $(_json_array CUSTOM_SYSTEMD_UNITS),
  "storage_net": $(_json_array RESUMO_STORAGE_REDE),
  "alerts_critical": $(_json_array ALERTAS_CRITICOS),
  "alerts_warning": $(_json_array ALERTAS_AUDITORIA),
  "alerts": $(_json_array all_alerts)
}
EOF
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

        if (( OPT_JSON == 1 )) && [[ -n "${JSON_FILE:-}" ]]; then
            write_json_summary "$JSON_FILE" 2>/dev/null || true
        fi

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
                if (( OPT_JSON == 1 )) && [[ -s "${JSON_FILE:-}" ]]; then
                    if copy_to_home "$EXECUTOR_USER" "$EXECUTOR_HOME" "$JSON_FILE" "$JSON_FILENAME" &&
                       copy_to_home "$EXECUTOR_USER" "$EXECUTOR_HOME" "$JSON_FILE" "$JSON_LATEST"; then
                        log_success "Inventário JSON salvo na Home: ${FG_CYAN}${EXECUTOR_HOME}/${JSON_FILENAME}${NC}"
                    else
                        log_warning "Não foi possível gravar o JSON na Home (${EXECUTOR_HOME})."
                    fi
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
                if (( OPT_JSON == 1 )) && [[ -s "${JSON_FILE:-}" ]]; then
                    if save_direct_report "$JSON_FILE" "${EXECUTOR_HOME}/${JSON_FILENAME}" 600 &&
                       save_direct_report "$JSON_FILE" "${EXECUTOR_HOME}/${JSON_LATEST}" 600; then
                        log_success "Inventário JSON salvo na Home: ${FG_CYAN}${EXECUTOR_HOME}/${JSON_FILENAME}${NC}"
                    else
                        log_warning "Não foi possível gravar o JSON na Home (${EXECUTOR_HOME})."
                    fi
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
JSON_FILENAME="${LOG_FILENAME%.log}.json"
JSON_LATEST="relatorio_inventario_latest.json"
LOG_DIR=$(mktemp -d -p /tmp auditoria_inventario.XXXXXXXX)
LOG_FILE="${LOG_DIR}/${LOG_FILENAME}.raw"
CLEAN_LOG_FILE="${LOG_DIR}/${LOG_FILENAME}"
JSON_FILE="${LOG_DIR}/${JSON_FILENAME}"
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
secao_1_sistema() {
print_header "1. SISTEMA OPERACIONAL, ATUALIZAÇÕES PENDENTES E REINICIALIZAÇÃO"

# 1.1 - Identificação da Distribuição (Ubuntu, Debian, RHEL, CentOS, Rocky, Alma, SUSE, Alpine)
OS_NAME="Desconhecido"
OS_FAMILY="generic"
OS_ID_RAW=""
OS_VER_ID=""
if [[ -r /etc/os-release ]]; then
    OS_NAME=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"'\''')
    OS_ID_RAW=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"'\''' | tr '[:upper:]' '[:lower:]')
    OS_VER_ID=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"'\''')
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

# Verificação de End-of-Life (EOL) do Sistema Operacional
OS_EOL_FLAG=0
case "$OS_ID_RAW" in
    ubuntu)
        if [[ "$OS_VER_ID" =~ ^(12\.|14\.|16\.|18\.|19\.|20\.|21\.|22\.10|23\.|24\.10|25\.) ]]; then
            OS_EOL_FLAG=1
        fi
        ;;
    debian)
        if [[ "$OS_VER_ID" =~ ^([1-9]|10|11)(\.|$) ]]; then
            OS_EOL_FLAG=1
        fi
        ;;
    centos)
        if [[ "$OS_VER_ID" =~ ^(6|7|8)(\.|$) ]]; then
            OS_EOL_FLAG=1
        fi
        ;;
    rhel|rocky|almalinux|ol)
        if [[ "$OS_VER_ID" =~ ^(6|7)(\.|$) ]]; then
            OS_EOL_FLAG=1
        fi
        ;;
esac

KERNEL_VER=$(uname -r)
ARCH=$(uname -m)
UPTIME_STR=$(uptime -p 2>/dev/null || uptime)
LAST_BOOT=$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || echo "N/A")
LOAD_AVG=$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg 2>/dev/null || echo "N/A")

# 1.2 - Identidade Física / Hypervisor / Fabricante / UUID
VIRT_TYPE="Físico / Bare-Metal"
DETECTED_VIRT="none"
if grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
    VIRT_TYPE="WSL (Windows Subsystem for Linux)"
    DETECTED_VIRT="wsl"
elif command -v systemd-detect-virt >/dev/null 2>&1; then
    DETECTED_VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
    [[ -z "$DETECTED_VIRT" ]] && DETECTED_VIRT="none"
    [[ "$DETECTED_VIRT" != "none" ]] && VIRT_TYPE="Virtualizado / Container (${DETECTED_VIRT})"
fi

SYS_VENDOR=""
PRODUCT_NAME=""
PRODUCT_UUID=""
PRODUCT_SERIAL=""
[[ -r /sys/class/dmi/id/sys_vendor ]] && SYS_VENDOR=$(trim_ws < /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_name ]] && PRODUCT_NAME=$(trim_ws < /sys/class/dmi/id/product_name 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_uuid ]] && PRODUCT_UUID=$(trim_ws < /sys/class/dmi/id/product_uuid 2>/dev/null || true)
[[ -r /sys/class/dmi/id/product_serial ]] && PRODUCT_SERIAL=$(trim_ws < /sys/class/dmi/id/product_serial 2>/dev/null || true)
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
CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | trim_ws || lscpu 2>/dev/null | awk -F: '/Model name/ {print $2}' | trim_ws || echo "Desconhecido")
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")

MEM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')
SWAP_TOTAL=$(free -h 2>/dev/null | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -h 2>/dev/null | awk '/^Swap:/ {print $3}')

OS_INSTALLED_AT=$(get_os_install_info)
log_item "Sistema Operacional" "${FG_GREEN}${BOLD}${OS_NAME}${NC} (${ARCH} | Família: ${OS_FAMILY^^})"
log_item "Instalado em (SO)"   "${FG_CYAN}${OS_INSTALLED_AT}${NC}"
if (( OS_EOL_FLAG == 1 )); then
    log_warning "Atenção: ${OS_NAME} atingiu End-of-Life (EOL — sem suporte oficial padrão de segurança)!"
    add_critical_alert "Sistema Operacional (${OS_NAME}) está em End-of-Life (EOL — sem atualizações oficiais de segurança)."
fi
log_item "Ambiente / Host"     "${FG_CYAN}${VIRT_TYPE}${NC} — Hardware/VM: ${BOLD}${HW_IDENTITY}${NC}"
if [[ "$DETECTED_VIRT" == "vmware" ]]; then
    if [[ "$(get_service_status_plain open-vm-tools)" == "Ativo" || "$(get_service_status_plain vmtoolsd)" == "Ativo" ]] || pgrep -x vmtoolsd >/dev/null 2>&1; then
        log_item "Guest Agent (ESXi)" "${FG_GREEN}Ativo (open-vm-tools / vmtoolsd)${NC}"
    else
        log_warning "VM VMware/ESXi sem Guest Agent (open-vm-tools) ativo!"
        add_alert "VM VMware/ESXi sem Guest Agent (open-vm-tools) ativo — recomendado para snapshots consistentes e shutdown limpo."
    fi
elif [[ "$DETECTED_VIRT" =~ ^(kvm|qemu)$ ]]; then
    if [[ "$(get_service_status_plain qemu-guest-agent)" == "Ativo" ]] || pgrep -x qemu-ga >/dev/null 2>&1; then
        log_item "Guest Agent (Proxmox/KVM)" "${FG_GREEN}Ativo (qemu-guest-agent)${NC}"
    else
        log_warning "VM KVM/Proxmox sem Guest Agent (qemu-guest-agent) ativo!"
        add_alert "VM KVM/Proxmox sem Guest Agent (qemu-guest-agent) ativo — recomendado para backups consistentes e exibição de IP."
    fi
fi
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
    PENDING_UPDATES_COUNT=$(echo "$APT_SIM" | awk '/^Inst / {c++} END {print c+0}')
    PENDING_LIST_DETAILS=$(echo "$APT_SIM" | awk '/^Inst / {print $2 " " $3 " -> " $4}' || true)
    CRITICAL_PKGS_PENDING=$( (echo "$APT_SIM" | awk '/^Inst / {print $2}' | grep -E '^(php|libapache2-mod-php|apache2|nginx|mariadb|mysql|postgresql|openssh|openssl|linux-image|docker|samba|bind9|sudo|cloudflared)' || true) | trim_ws || true )
elif command -v dnf >/dev/null 2>&1; then
    DNF_SIM=$(dnf check-update -q --cacheonly 2>/dev/null || true)
    PENDING_UPDATES_COUNT=$(echo "$DNF_SIM" | awk 'NF>=3 && $1 !~ /^(Last|Obsoleting|Security:)/ {count++} END {print count+0}')
    PENDING_LIST_DETAILS=$(echo "$DNF_SIM" | awk 'NF>=3 && $1 !~ /^(Last|Obsoleting|Security:)/ {print $1 " -> " $2 " (" $3 ")"}' || true)
    CRITICAL_PKGS_PENDING=$(echo "$DNF_SIM" | awk 'NF>=3 {print $1}' | grep -E '^(php|httpd|nginx|mariadb|mysql|postgresql|openssh|openssl|kernel|docker|samba|bind|sudo)' | trim_ws || true)
elif command -v yum >/dev/null 2>&1; then
    YUM_SIM=$(yum check-update -q -C 2>/dev/null || true)
    PENDING_UPDATES_COUNT=$(echo "$YUM_SIM" | awk 'NF>=3 && $1 !~ /^(Loaded|Obsoleting|Security:)/ {count++} END {print count+0}')
    PENDING_LIST_DETAILS=$(echo "$YUM_SIM" | awk 'NF>=3 && $1 !~ /^(Loaded|Obsoleting|Security:)/ {print $1 " -> " $2 " (" $3 ")"}' || true)
    CRITICAL_PKGS_PENDING=$(echo "$YUM_SIM" | awk 'NF>=3 {print $1}' | grep -E '^(php|httpd|nginx|mariadb|mysql|postgresql|openssh|openssl|kernel|docker|samba|bind|sudo)' | trim_ws || true)
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

# 1.6 - Saúde do Kernel (OOM Killer e Erros Críticos de Storage/Filesystem nas últimas 24h)
echo -e "\n  ${BOLD}Saúde do Kernel (OOM Killer e Erros de I/O / Filesystem — últimas 24h):${NC}"
KERN_LOG_SRC=""
if command -v journalctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    KERN_LOG_SRC=$(timeout 4 journalctl -k --since "24 hours ago" --no-pager 2>/dev/null || true)
fi
if [[ -z "$KERN_LOG_SRC" ]] && command -v dmesg >/dev/null 2>&1; then
    KERN_LOG_SRC=$(timeout 3 dmesg -T 2>/dev/null || timeout 3 dmesg 2>/dev/null || true)
fi

if [[ -n "$KERN_LOG_SRC" ]]; then
    OOM_HITS=$(echo "$KERN_LOG_SRC" | grep -iE "Out of memory:|Killed process [0-9]+|oom-killer" | tail -n 5 || true)
    FS_ERR_HITS=$(echo "$KERN_LOG_SRC" | grep -iE "EXT4-fs error|XFS.*(error|Corruption)|I/O error|Remounting filesystem read-only|blk_update_request" | tail -n 5 || true)

    if [[ -n "$OOM_HITS" ]]; then
        log_warning "Eventos de OOM Killer (falta de memória) detectados nos logs do kernel!"
        while IFS= read -r oom_l; do
            [[ -n "$oom_l" ]] && echo -e "      ├─ ${FG_RED}${oom_l:0:120}${NC}"
        done <<< "$OOM_HITS"
        add_critical_alert "Kernel OOM Killer encerrou processo(s) por falta de memória recentemente (verifique RAM/Swap)."
    else
        log_success "OOM Killer: Nenhum processo encerrado por falta de memória."
    fi

    if [[ -n "$FS_ERR_HITS" ]]; then
        log_warning "Erros críticos de disco/storage/filesystem detectados nos logs do kernel!"
        while IFS= read -r fse_l; do
            [[ -n "$fse_l" ]] && echo -e "      ├─ ${FG_RED}${fse_l:0:120}${NC}"
        done <<< "$FS_ERR_HITS"
        add_critical_alert "Erros críticos de I/O ou filesystem detectados nos logs do kernel (verificar storage/datastore)."
    else
        log_success "Erros de I/O / Filesystem (Kernel): Nenhum erro crítico recente."
    fi
else
    log_info "Logs do kernel (journalctl -k / dmesg) indisponíveis ou restritos neste ambiente/container."
fi
return 0
}

# ==============================================================================
# SEÇÃO 2 - USUÁRIOS (ATIVOS, BLOQUEADOS E DESATIVADOS), GRUPOS, SUDOERS E LDAP/AD
# ==============================================================================
secao_2_usuarios() {
print_header "2. USUÁRIOS (ATIVOS, BLOQUEADOS E DESATIVADOS), GRUPOS, SUDOERS E AUTENTICAÇÃO"

get_user_auth_status() {
    local u_name="$1"
    local p_state="Não verificado (requer root)"
    if (( IS_ROOT == 1 )); then
        local p_raw=""
        if command -v passwd >/dev/null 2>&1; then
            p_raw=$(passwd -S "$u_name" 2>/dev/null | awk '{print $2}' || true)
            case "$p_raw" in
                P|PS) p_state="${FG_GREEN}Conta Ativa (Com Senha)${NC}" ;;
                L|LK) p_state="${FG_RED}Conta Bloqueada (Locked)${NC}" ;;
                NP)   p_state="${FG_YELLOW}Sem Senha Definida${NC}" ;;
                *)    p_state="${p_raw:-Ativa}" ;;
            esac
        fi
        local exp_days="" today_days="" exp_fmt=""
        exp_days=$(getent shadow "$u_name" 2>/dev/null | cut -d: -f8 || true)
        if [[ -z "$exp_days" && -r /etc/shadow ]]; then
            exp_days=$(awk -F: -v u="$u_name" '$1==u {print $8; exit}' /etc/shadow 2>/dev/null || true)
        fi
        if [[ "$exp_days" =~ ^[0-9]+$ ]]; then
            today_days=$(( $(date +%s) / 86400 ))
            if (( exp_days > 0 )); then
                exp_fmt=$(date -u -d "1970-01-01 +${exp_days} days" +%d/%m/%Y 2>/dev/null || printf 'dia %s' "$exp_days")
            else
                exp_fmt="início epoch"
            fi
            if (( exp_days <= today_days )); then
                p_state="${p_state} | ${FG_RED}${BOLD}EXPIRADA (${exp_fmt})${NC}"
            else
                p_state="${p_state} | ${FG_YELLOW}Expira: ${exp_fmt}${NC}"
            fi
        fi
    fi
    printf '%s' "$p_state"
}

get_user_ssh_keys_info() {
    local u_home="$1"
    local ssh_info="Nenhuma"
    if [[ -r "${u_home}/.ssh/authorized_keys" ]]; then
        local k_count
        k_count=$(awk '/^(ssh-|ecdsa-|sk-)/ {c++} END {print c+0}' "${u_home}/.ssh/authorized_keys" 2>/dev/null || echo 0)
        k_count="${k_count%%[^0-9]*}"
        (( ${k_count:-0} > 0 )) && ssh_info="${FG_GREEN}${k_count} chave(s) SSH autorizada(s)${NC}"
    fi
    printf '%s' "$ssh_info"
}

# 2.1 - Usuários Ativos (com Shell de Login) e Usuários Humanos Desativados/Bloqueados
echo -e "  ${BOLD}Usuários com Shell de Login (Ativos e Bloqueados por Senha/Expiração):${NC}"
ACTIVE_USERS_COUNT=0
DISABLED_SHELL_USERS=()
while IFS=: read -r u_name _ u_uid _ _ u_home u_shell; do
    [[ -z "$u_name" ]] && continue
    if (( u_uid == 0 )) && [[ "$u_name" != "root" ]]; then
        add_critical_alert "Conta adicional com UID 0 (equivalente a root) detectada em /etc/passwd: '${u_name}'."
    fi
    if (( u_uid == 0 || (u_uid >= 1000 && u_uid < 65534) )) && [[ -n "$u_shell" ]] && [[ ! "$u_shell" =~ (nologin|false|sync|halt|shutdown)$ ]]; then
        ACTIVE_USERS_COUNT=$((ACTIVE_USERS_COUNT + 1))
        U_GROUPS=$(id -Gn "$u_name" 2>/dev/null | tr ' ' ', ' || echo "N/A")
        PASS_STATE=$(get_user_auth_status "$u_name")
        SSH_KEYS_INFO=$(get_user_ssh_keys_info "$u_home")
        echo -e "    • Usuário: ${FG_CYAN}${BOLD}${u_name}${NC} (UID: ${u_uid}) | Status: ${PASS_STATE} | Home: ${u_home} | Shell: ${DIM}${u_shell}${NC}"
        echo -e "      ├─ ${BOLD}Grupos a que pertence:${NC} ${FG_YELLOW}${U_GROUPS}${NC}"
        echo -e "      └─ ${BOLD}Chaves SSH:${NC}            ${SSH_KEYS_INFO}"
        if [[ "$PASS_STATE" == *"Sem Senha Definida"* ]]; then
            add_critical_alert "Usuário '${u_name}' com shell de login ativo (${u_shell}) está SEM SENHA definida (NP)."
        fi
        if [[ "$PASS_STATE" == *"Conta Bloqueada"* || "$PASS_STATE" == *"EXPIRADA"* ]]; then
            if [[ "$u_name" != "root" || "$PASS_STATE" == *"EXPIRADA"* ]]; then
                add_unique_item DISABLED_USERS_SUMMARY "${u_name} (UID:${u_uid}, Locked/Expirada)"
            fi
            if [[ "$u_name" != "root" && "$SSH_KEYS_INFO" != "Nenhuma" ]]; then
                add_alert "Conta bloqueada/expirada '${u_name}' ainda possui chave(s) SSH autorizada(s) em ${u_home}/.ssh/authorized_keys."
            fi
            if [[ "$u_name" != "root" && "$U_GROUPS" =~ (^|[[:space:],])(sudo|wheel|admin|docker|lxd)([[:space:],]|$) ]]; then
                add_alert "Conta bloqueada/expirada '${u_name}' ainda pertence a grupo privilegiado (${U_GROUPS})."
            fi
        fi
    elif (( u_uid >= 1000 && u_uid < 65534 )); then
        DISABLED_SHELL_USERS+=("${u_name}|${u_uid}|${u_home}|${u_shell:-sem-shell}")
    fi
done < /etc/passwd

echo -e "\n  ${BOLD}Usuários Não-Sistema (UID >= 1000) com Shell Desativado (nologin/false):${NC}"
if (( ${#DISABLED_SHELL_USERS[@]} > 0 )); then
    for du_entry in "${DISABLED_SHELL_USERS[@]}"; do
        IFS='|' read -r du_name du_uid du_home du_shell <<< "$du_entry"
        DU_GROUPS=$(id -Gn "$du_name" 2>/dev/null | tr ' ' ', ' || echo "N/A")
        DU_PASS_STATE=$(get_user_auth_status "$du_name")
        DU_SSH_KEYS=$(get_user_ssh_keys_info "$du_home")
        add_unique_item DISABLED_USERS_SUMMARY "${du_name} (UID:${du_uid}, Shell:${du_shell})"
        echo -e "    • Usuário: ${FG_YELLOW}${BOLD}${du_name}${NC} (UID: ${du_uid}) | ${FG_RED}Shell Desativado${NC} (${DIM}${du_shell}${NC}) | Status Senha/Conta: ${DU_PASS_STATE}"
        echo -e "      ├─ ${BOLD}Home / Grupos:${NC} ${du_home} | Grupos: ${FG_YELLOW}${DU_GROUPS}${NC}"
        echo -e "      └─ ${BOLD}Chaves SSH:${NC}    ${DU_SSH_KEYS}"
        if [[ "$DU_SSH_KEYS" != "Nenhuma" ]]; then
            add_alert "Usuário com shell desativado '${du_name}' ainda mantém chave(s) SSH em ${du_home}/.ssh/authorized_keys."
        fi
        if [[ "$DU_GROUPS" =~ (^|[[:space:],])(sudo|wheel|admin|docker|lxd)([[:space:],]|$) ]]; then
            add_alert "Usuário com shell desativado '${du_name}' ainda pertence a grupo privilegiado (${DU_GROUPS})."
        fi
    done
else
    echo -e "    • Nenhum usuário não-sistema (UID >= 1000) com shell desativado encontrado."
fi

# 2.2 - Quem são os Sudos? (Grupos Administrativos e Regras em /etc/sudoers)
echo -e "\n  ${BOLD}Quem são os Sudos? (Grupos de Administração: sudo, wheel, admin, adm, docker, lxd):${NC}"
for priv_grp in sudo wheel admin adm docker lxd; do
    GRP_ENTRY=$(getent group "$priv_grp" 2>/dev/null || true)
    [[ -z "$GRP_ENTRY" ]] && continue
    GRP_GID=$(echo "$GRP_ENTRY" | cut -d: -f3)
    GRP_USERS=$(echo "$GRP_ENTRY" | cut -d: -f4 | tr ',' ' ' | trim_ws || true)
    PRI_USERS=$(awk -F: -v gid="$GRP_GID" '$4 == gid {print $1}' /etc/passwd 2>/dev/null | trim_ws || true)
    ALL_GRP_MEMBERS=$(printf '%s\n' "${GRP_USERS}" "${PRI_USERS}" | tr ' ' '\n' | grep -v '^$' | sort -u | trim_ws || true)

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
            if echo "$s_line" | grep -qE "NOPASSWD:[[:space:]]*ALL"; then
                add_alert "Regra sudo sem senha (NOPASSWD: ALL) ativa para '${ENTITY}' em $(basename "$s_file")."
            fi
            if [[ "$ENTITY" == %* ]]; then
                GRP_CLEAN="${ENTITY#%}"
                GRP_MEM=$(getent group "$GRP_CLEAN" 2>/dev/null | cut -d: -f4 | tr ',' ' ' | trim_ws || true)
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
    LDAP_URI=$(grep -iE "^\s*URI\s+" "$ldap_cfg" 2>/dev/null | awk '{$1=""; print $0}' | trim_ws || true)
    LDAP_BASE=$(grep -iE "^\s*BASE\s+" "$ldap_cfg" 2>/dev/null | awk '{$1=""; print $0}' | trim_ws || true)
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
    REALM_INFO=$(realm list --name-only 2>/dev/null | trim_ws || true)
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

if (( DIR_AUTH_FOUND == 0 )); then
    echo -e "    • Autenticação exclusivamente local (/etc/passwd e /etc/shadow) — Nenhuma integração LDAP/AD ativa detectada."
fi
return 0
}

# ==============================================================================
# SEÇÃO 3 - ARMAZENAMENTO, UNIDADES NO FSTAB, NFS E SAMBA (CLIENTE E SERVIDOR)
# ==============================================================================
secao_3_armazenamento() {
print_header "3. ARMAZENAMENTO, UNIDADES NO FSTAB, NFS E SAMBA (CLIENTE E SERVIDOR)"

# 3.1 - Partições Montadas, Uso de Espaço, Inodes e RAID/ZFS
echo -e "  ${BOLD}Unidades de Armazenamento Montadas Agora (df -hT):${NC}"
DF_HT_OUT=$(timeout 5 df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null || timeout 5 df -hT 2>/dev/null || true)
if [[ -n "$DF_HT_OUT" ]]; then
    echo "$DF_HT_OUT" | awk '
        NR==1 {printf "    %-24s %-10s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6, $7}
        NR>1  {printf "    %-24s %-10s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6, $7}
    ' || echo "$DF_HT_OUT" | awk '{print "    " $0}'
else
    log_warning "Timeout ou falha ao consultar sistemas de arquivos montados (df -hT)."
fi

while IFS= read -r disk_line; do
    [[ -z "$disk_line" ]] && continue
    USE_PCT=$(echo "$disk_line" | awk '{gsub(/%/,"",$5); print $5}')
    MNT_PT=$(echo "$disk_line" | awk '{print $6}')
    if [[ "$USE_PCT" =~ ^[0-9]+$ ]] && (( USE_PCT >= 85 )); then
        log_warning "Partição ${MNT_PT} está com uso elevado: ${USE_PCT}%"
        add_alert "Disco com uso crítico (${USE_PCT}%) na partição ${MNT_PT}."
    fi
done < <(timeout 5 df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1' || true)

INODE_HIGH_FOUND=0
while IFS= read -r inode_line; do
    [[ -z "$inode_line" ]] && continue
    IUSE_PCT=$(echo "$inode_line" | awk '{gsub(/%/,"",$5); print $5}')
    IMNT_PT=$(echo "$inode_line" | awk '{print $6}')
    if [[ "$IUSE_PCT" =~ ^[0-9]+$ ]] && (( IUSE_PCT >= 85 )); then
        INODE_HIGH_FOUND=1
        log_warning "Inodes elevados na partição ${IMNT_PT}: ${IUSE_PCT}% em uso"
        add_alert "Uso crítico de inodes (${IUSE_PCT}%) na partição ${IMNT_PT}."
    fi
done < <(timeout 5 df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1' || true)
if (( INODE_HIGH_FOUND == 0 )); then
    log_success "Uso de Inodes (df -Pi): Normal (todas as partições abaixo de 85%)"
fi

# Verificação de partições locais montadas inesperadamente em somente leitura (ro)
RO_MOUNTS_FOUND=0
if [[ -r /proc/mounts ]]; then
    while IFS=' ' read -r m_dev m_pt m_fs m_opts _ _; do
        [[ "$m_fs" =~ ^(ext2|ext3|ext4|xfs|btrfs|zfs)$ ]] || continue
        [[ "$m_pt" == /snap/* || "$m_pt" == /boot/efi || "$m_pt" == /cdrom* || "$m_pt" == /media/* || "$m_pt" == /mnt/wsl* || "$m_pt" == /usr/lib/wsl* ]] && continue
        if [[ ",${m_opts}," == *",ro,"* ]]; then
            RO_MOUNTS_FOUND=1
            log_warning "Partição ${m_pt} (${m_dev} | ${m_fs}) está montada em modo SOMENTE LEITURA (ro)!"
            add_critical_alert "Partição ${m_pt} (${m_fs}) montada em SOMENTE LEITURA (ro) — possível falha de disco/datastore."
        fi
    done < /proc/mounts
fi
if (( RO_MOUNTS_FOUND == 0 )); then
    log_success "Integridade de Montagem (RW/RO): Todas as partições locais graváveis estão em modo RW"
fi

if [[ -r /proc/mdstat ]] && grep -qE "^md[0-9]+" /proc/mdstat 2>/dev/null; then
    echo -e "\n  ${BOLD}Status de Software RAID (/proc/mdstat):${NC}"
    grep -E "^(Personalities|md[0-9]+|.*\[[U_]+\])" /proc/mdstat 2>/dev/null | sed 's/^/    /' || true
    if grep -qE "\[[U_]*_[U_]*\]" /proc/mdstat 2>/dev/null; then
        log_warning "Software RAID (mdadm) DEGRADADO detectado em /proc/mdstat!"
        add_critical_alert "Software RAID (mdadm) com disco falho/degradado em /proc/mdstat."
    else
        log_success "Software RAID (mdadm): Saudável (todos os arrays sincronizados)"
    fi
fi

if command -v zpool >/dev/null 2>&1; then
    ZFS_HEALTH=$(timeout 5 zpool status -x 2>/dev/null || true)
    if [[ -n "$ZFS_HEALTH" ]]; then
        echo -e "\n  ${BOLD}Saúde dos Pools ZFS (zpool status -x):${NC}"
        echo "$ZFS_HEALTH" | awk '{print "    " $0}'
        if ! echo "$ZFS_HEALTH" | grep -qiE "all pools are healthy|no pools available"; then
            log_warning "Atenção: Pool ZFS reportou estado degradado/com erros!"
            add_critical_alert "Pool ZFS reportando estado degradado ou erros (verifique zpool status)."
        fi
    fi
fi

# S.M.A.R.T. apenas em servidores físicos / bare-metal (ignorado em VMs ESXi/Proxmox e containers)
if [[ "$DETECTED_VIRT" == "none" ]] && (( IS_ROOT == 1 )) && command -v smartctl >/dev/null 2>&1; then
    SMART_DEVS=$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk" {print "/dev/" $1}' || true)
    if [[ -n "$SMART_DEVS" ]]; then
        echo -e "\n  ${BOLD}Saúde Física S.M.A.R.T. dos Discos (Bare-Metal):${NC}"
        while IFS= read -r s_dev; do
            [[ -b "$s_dev" ]] || continue
            SMART_OUT=$(timeout 4 smartctl -H "$s_dev" 2>/dev/null || true)
            SMART_STATUS=$(echo "$SMART_OUT" | awk -F':' '/overall-health|SMART Health Status/ {gsub(/^[ \t]+|[ \t\r]+$/,"",$2); print $2; exit}' || true)
            if [[ -n "$SMART_STATUS" ]]; then
                if echo "$SMART_STATUS" | grep -qiE "PASSED|OK"; then
                    echo -e "    • ${FG_CYAN}${s_dev}${NC}: ${FG_GREEN}${SMART_STATUS}${NC}"
                else
                    echo -e "    • ${FG_CYAN}${s_dev}${NC}: ${FG_RED}${BOLD}${SMART_STATUS}${NC}"
                    add_critical_alert "Disco físico ${s_dev} reportou falha S.M.A.R.T.: ${SMART_STATUS}!"
                fi
            fi
        done <<< "$SMART_DEVS"
    fi
fi

if command -v lsblk >/dev/null 2>&1; then
    echo -e "\n  ${BOLD}Topologia de Discos Físicos, Partições e LVM (lsblk):${NC}"
    timeout 5 lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | grep -v "^loop" | sed 's/^/    /' || true
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
if (( SMB_FOUND == 0 )); then
    echo -e "    • Nenhum compartilhamento Samba/CIFS (cliente ou servidor) ativo neste host."
fi
return 0
}

# ==============================================================================
# SEÇÃO 4 - APLICAÇÕES, WEB, PHP, RUNTIMES, CMSS E CONTAINERS (QUAIS E VERSÕES)
# ==============================================================================
secao_4_aplicacoes() {
print_header "4. APLICAÇÕES, SERVIDORES WEB, PHP, RUNTIMES E CONTAINERS (QUAIS E VERSÕES)"

# 4.1 - Servidores Web, Proxies Reversos e Balanceadores (Quais e Versões)
echo -e "  ${BOLD}4.1 Servidores Web, Proxies Reversos e Balanceadores (Quais e Versões):${NC}"
WEB_FOUND=0
DISCOVERED_WEB_ROOTS=()

add_web_root() {
    local raw_dir="${1:-}"
    [[ -z "$raw_dir" ]] && return 0
    raw_dir="${raw_dir%\"}"
    raw_dir="${raw_dir#\"}"
    raw_dir="${raw_dir%\'}"
    raw_dir="${raw_dir#\'}"
    raw_dir="${raw_dir%/}"
    [[ -z "$raw_dir" || "$raw_dir" == "/" ]] && return 0
    if [[ -d "$raw_dir" ]]; then
        add_unique_item DISCOVERED_WEB_ROOTS "$raw_dir"
        local parent_dir
        parent_dir=$(dirname "$raw_dir")
        if [[ -n "$parent_dir" && "$parent_dir" != "/" && "$parent_dir" != "/usr" && "$parent_dir" != "/usr/share" && -d "$parent_dir" ]]; then
            add_unique_item DISCOVERED_WEB_ROOTS "$parent_dir"
        fi
    fi
}

if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
    WEB_FOUND=1
    APACHE_BIN=$(command -v apache2 || command -v httpd)
    APACHE_SVC="apache2"
    if [[ "$(get_service_status_plain apache2)" == "Não instalado" && "$(get_service_status_plain httpd)" != "Não instalado" ]]; then
        APACHE_SVC="httpd"
    fi
    APACHE_VER=$($APACHE_BIN -v 2>/dev/null | head -n 1 | cut -d':' -f2 | trim_ws || echo "Instalado")
    log_success "Apache (${APACHE_SVC}): ${BOLD}${APACHE_VER}${NC} [$(get_service_status "$APACHE_SVC")]"
    add_unique_item RESUMO_APPS_VERSOES "Apache:${APACHE_VER}"
    if [[ "$(get_service_status_plain "$APACHE_SVC")" == "Ativo" ]]; then
        add_role "Web Server Apache (${APACHE_VER})"
    fi

    APACHE_CTL=$(command -v apache2ctl || command -v apachectl || echo "$APACHE_BIN")
    APACHE_MPM=$($APACHE_CTL -V 2>/dev/null | awk -F': ' '/Server MPM/ {print $2}' | trim_ws || true)
    [[ -n "$APACHE_MPM" ]] && log_item "Modo MPM" "${FG_CYAN}${APACHE_MPM}${NC}"

    APACHE_MODS=$($APACHE_CTL -M 2>/dev/null | awk '/_module/ {sub(/_module/,"",$1); print $1}' | sort -u | trim_ws || true)
    echo -e "    • ${BOLD}Módulos Ativos:${NC} ${DIM}${APACHE_MODS:-Não foi possível listar}${NC}"

    echo -e "\n    ${BOLD}VirtualHosts e Sites Habilitados no Apache:${NC}"
    APACHE_SITES_COUNT=0
    for vhost_file in /etc/apache2/sites-enabled/* /etc/httpd/conf.d/*.conf /etc/apache2/vhosts.d/*.conf; do
        [[ -f "$vhost_file" ]] || continue
        VH_BLOCKS=$(awk '
            BEGIN { IGNORECASE=1; in_vh=0 }
            /^[ \t]*#/ { next }
            /<VirtualHost[^>]*>/ {
                in_vh=1
                vh_hdr=$0
                sub(/.*<VirtualHost[ \t]+/, "", vh_hdr)
                sub(/>.*/, "", vh_hdr)
                gsub(/[ \t\r]+/, " ", vh_hdr)
                sname=""; salias=""; docroot=""; proxy=""; sslcert=""
                next
            }
            /<\/VirtualHost>/ {
                if (in_vh) {
                    print vh_hdr "|" sname "|" salias "|" docroot "|" proxy "|" sslcert
                    in_vh=0
                }
                next
            }
            in_vh {
                line=$0
                sub(/^[ \t]+/, "", line)
                sub(/[ \t\r]+$/, "", line)
                if (tolower(line) ~ /^servername[ \t]+/) {
                    sub(/^[Ss][Ee][Rr][Vv][Ee][Rr][Nn][Aa][Mm][Ee][ \t]+/, "", line)
                    gsub(/[";]/, "", line)
                    sname=line
                } else if (tolower(line) ~ /^serveralias[ \t]+/) {
                    sub(/^[Ss][Ee][Rr][Vv][Ee][Rr][Aa][Ll][Ii][Aa][Ss][ \t]+/, "", line)
                    gsub(/[";]/, "", line)
                    salias=(salias ? salias " " line : line)
                } else if (tolower(line) ~ /^documentroot[ \t]+/) {
                    sub(/^[Dd][Oo][Cc][Uu][Mm][Ee][Nn][Tt][Rr][Oo][Oo][Tt][ \t]+/, "", line)
                    gsub(/[";]/, "", line)
                    docroot=line
                } else if (tolower(line) ~ /^proxypass[ \t]+/ && line !~ /!/) {
                    sub(/^[Pp][Rr][Oo][Xx][Yy][Pp][Aa][Ss][Ss][ \t]+/, "", line)
                    proxy=(proxy ? proxy "; " line : line)
                } else if (tolower(line) ~ /^sslcertificatefile[ \t]+/) {
                    sub(/^[Ss][Ss][Ll][Cc][Ee][Rr][Tt][Ii][Ff][Ii][Cc][Aa][Tt][Ee][Ff][Ii][Ll][Ee][ \t]+/, "", line)
                    gsub(/[";]/, "", line)
                    sslcert=line
                }
            }
        ' "$vhost_file" 2>/dev/null || true)

        VH_PHP_FPM=$(grep -iE "SetHandler\s+.*proxy:(unix|fcgi):" "$vhost_file" 2>/dev/null | grep -oE "php[0-9.]*-?fpm|unix:[^|\"']+|fcgi://[^\"']+" | head -n 1 || true)

        if [[ -n "$VH_BLOCKS" ]]; then
            while IFS='|' read -r vh_hdr vh_name vh_alias vh_root vh_proxy vh_ssl; do
                [[ -z "$vh_hdr" && -z "$vh_name" && -z "$vh_root" ]] && continue
                APACHE_SITES_COUNT=$((APACHE_SITES_COUNT + 1))
                echo -e "      • Arquivo: ${FG_CYAN}$(basename "$vhost_file")${NC} [${DIM}${vh_hdr:-*}${NC}] | ServerName: ${FG_YELLOW}${vh_name:-Padrão/Sem ServerName}${NC}${vh_alias:+ (Alias: $vh_alias)}"
                if [[ -n "$vh_root" ]]; then
                    echo -e "        ├─ DocumentRoot: ${FG_GREEN}${vh_root}${NC}"
                    add_web_root "$vh_root"
                fi
                [[ -n "$vh_proxy" ]]   && echo -e "        ├─ ProxyPass:    ${FG_CYAN}${vh_proxy}${NC}"
                if [[ -n "$vh_ssl" ]]; then
                    echo -e "        ├─ Cert SSL:     ${DIM}${vh_ssl}${NC}"
                    [[ -f "$vh_ssl" && "$vh_ssl" != /etc/letsencrypt/* ]] && add_unique_item EXTRA_SSL_CERTS "${vh_ssl}|Apache:${vh_name:-$(basename "$vhost_file")}"
                fi
                [[ -n "$VH_PHP_FPM" ]] && echo -e "        └─ Handler PHP:  ${FG_YELLOW}${VH_PHP_FPM}${NC}"
                add_unique_item RESUMO_SITES_DETECTADOS "Apache: ${vh_name:-$(basename "$vhost_file")} (${vh_root:-${vh_proxy:-N/A}})"
            done <<< "$VH_BLOCKS"
        else
            VH_NAME=$(grep -iE "^\s*ServerName\s+" "$vhost_file" 2>/dev/null | awk '{print $2}' | tr -d ';' | trim_ws || true)
            VH_ROOT=$(grep -iE "^\s*DocumentRoot\s+" "$vhost_file" 2>/dev/null | awk '{print $2}' | tr -d '"' | head -n 1 || true)
            if [[ -n "$VH_NAME" || -n "$VH_ROOT" ]]; then
                APACHE_SITES_COUNT=$((APACHE_SITES_COUNT + 1))
                echo -e "      • Arquivo: ${FG_CYAN}$(basename "$vhost_file")${NC} | ServerName: ${FG_YELLOW}${VH_NAME:-Padrão}${NC}"
                if [[ -n "$VH_ROOT" ]]; then
                    echo -e "        └─ DocumentRoot: ${FG_GREEN}${VH_ROOT}${NC}"
                    add_web_root "$VH_ROOT"
                fi
                add_unique_item RESUMO_SITES_DETECTADOS "Apache: ${VH_NAME:-$(basename "$vhost_file")} (${VH_ROOT:-N/A})"
            fi
        fi

        # Captura também diretivas Alias em arquivos do Apache (ex: Alias /nextcloud /arquivos/sistema/nextcloud)
        while IFS= read -r alias_dir; do
            [[ -n "$alias_dir" ]] && add_web_root "$alias_dir"
        done < <(awk 'IGNORECASE=1; /^[ \t]*Alias[ \t]+/ {gsub(/["'\'';\r]/, "", $3); print $3}' "$vhost_file" 2>/dev/null || true)
    done
    for conf_en in /etc/apache2/conf-enabled/*.conf /etc/httpd/conf.d/*.conf; do
        [[ -f "$conf_en" ]] || continue
        while IFS= read -r alias_dir; do
            [[ -n "$alias_dir" ]] && add_web_root "$alias_dir"
        done < <(awk 'IGNORECASE=1; /^[ \t]*Alias[ \t]+/ {gsub(/["'\'';\r]/, "", $3); print $3}' "$conf_en" 2>/dev/null || true)
    done
    (( APACHE_SITES_COUNT == 0 )) && echo -e "      • Nenhum arquivo de VirtualHost dedicado encontrado."
    echo -e ""
fi

if command -v nginx >/dev/null 2>&1; then
    WEB_FOUND=1
    NGINX_VER=$(nginx -v 2>&1 | cut -d':' -f2 | trim_ws || echo "Instalado")
    log_success "Nginx: ${BOLD}${NGINX_VER}${NC} [$(get_service_status nginx)]"
    add_unique_item RESUMO_APPS_VERSOES "Nginx:${NGINX_VER}"
    if [[ "$(get_service_status_plain nginx)" == "Ativo" ]]; then
        add_role "Web Server / Proxy Nginx (${NGINX_VER})"
    fi

    echo -e "\n    ${BOLD}Server Blocks / Domínios Configurados no Nginx:${NC}"
    NGINX_SITES_COUNT=0
    NGINX_CONF_FILES=()
    for conf in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
        [[ -f "$conf" ]] && NGINX_CONF_FILES+=("$conf")
    done
    if (( ${#NGINX_CONF_FILES[@]} == 0 )) && [[ -f /etc/nginx/nginx.conf ]]; then
        NGINX_CONF_FILES+=("/etc/nginx/nginx.conf")
    fi

    if (( ${#NGINX_CONF_FILES[@]} > 0 )); then
        for conf in "${NGINX_CONF_FILES[@]}"; do
            [[ -r "$conf" ]] || continue
            NGINX_BLOCKS=$(awk '
                BEGIN { depth=0; srv_depth=0; in_srv=0; sname=""; listen=""; docroot=""; proxy=""; fastcgi=""; sslcert="" }
                /^[ \t]*#/ { next }
                {
                    line=$0
                    sub(/#.*$/, "", line)
                    gsub(/\r/, "", line)
                    clean=line
                    gsub(/^[ \t]+|[ \t]+$/, "", clean)

                    # Detecta inicio de bloco server {
                    if (!in_srv && clean ~ /^server[ \t]*\{/) {
                        in_srv=1
                        srv_depth=depth + 1
                        sname=""; listen=""; docroot=""; proxy=""; fastcgi=""; sslcert=""
                    }

                    # Atualiza contagem de chaves considerando multiplas na mesma linha
                    tmp=line
                    opens=gsub(/\{/, "{", tmp)
                    tmp=line
                    closes=gsub(/\}/, "}", tmp)
                    depth = depth + opens - closes

                    if (in_srv) {
                        if (clean ~ /^server_name[ \t]+/) {
                            val=clean; sub(/^server_name[ \t]+/, "", val); sub(/;.*/, "", val)
                            sname=(sname ? sname " " val : val)
                        } else if (clean ~ /^listen[ \t]+/) {
                            val=clean; sub(/^listen[ \t]+/, "", val); sub(/;.*/, "", val)
                            listen=(listen ? listen ", " val : val)
                        } else if (clean ~ /^root[ \t]+/) {
                            val=clean; sub(/^root[ \t]+/, "", val); sub(/;.*/, "", val)
                            gsub(/["'\'']/, "", val)
                            if (docroot == "") docroot=val
                        } else if (clean ~ /^proxy_pass[ \t]+/) {
                            val=clean; sub(/^proxy_pass[ \t]+/, "", val); sub(/;.*/, "", val)
                            if (index(proxy, val) == 0) proxy=(proxy ? proxy "; " val : val)
                        } else if (clean ~ /^fastcgi_pass[ \t]+/) {
                            val=clean; sub(/^fastcgi_pass[ \t]+/, "", val); sub(/;.*/, "", val)
                            if (fastcgi == "") fastcgi=val
                        } else if (clean ~ /^ssl_certificate[ \t]+/) {
                            val=clean; sub(/^ssl_certificate[ \t]+/, "", val); sub(/;.*/, "", val)
                            if (sslcert == "") sslcert=val
                        }

                        if (depth < srv_depth) {
                            print sname "|" listen "|" docroot "|" proxy "|" fastcgi "|" sslcert
                            in_srv=0
                        }
                    }
                }
            ' "$conf" 2>/dev/null || true)

            if [[ -n "$NGINX_BLOCKS" ]]; then
                while IFS='|' read -r ng_dom ng_listen ng_root ng_proxy ng_fcgi ng_ssl; do
                    [[ -z "$ng_dom" && -z "$ng_root" && -z "$ng_proxy" && -z "$ng_listen" ]] && continue
                    NGINX_SITES_COUNT=$((NGINX_SITES_COUNT + 1))
                    ng_dom=$(echo "$ng_dom" | trim_ws)
                    ng_root=$(echo "$ng_root" | trim_ws)
                    ng_proxy=$(echo "$ng_proxy" | trim_ws)
                    ng_fcgi=$(echo "$ng_fcgi" | trim_ws)
                    [[ -n "$ng_root" ]] && add_web_root "$ng_root"

                    echo -e "      • Arquivo: ${FG_CYAN}$(basename "$conf")${NC}${ng_listen:+ [${DIM}${ng_listen}${NC}]} | Domínios: ${FG_YELLOW}${ng_dom:-_}${NC}"
                    [[ -n "$ng_root" ]]  && echo -e "        ├─ Root:         ${FG_GREEN}${ng_root}${NC}"
                    [[ -n "$ng_proxy" ]] && echo -e "        ├─ Proxy Reverso:${FG_CYAN} ${ng_proxy}${NC}"
                    if [[ -n "$ng_ssl" ]]; then
                        echo -e "        ├─ Cert SSL:     ${DIM}${ng_ssl}${NC}"
                        [[ -f "$ng_ssl" && "$ng_ssl" != /etc/letsencrypt/* ]] && add_unique_item EXTRA_SSL_CERTS "${ng_ssl}|Nginx:${ng_dom:-$(basename "$conf")}"
                    fi
                    [[ -n "$ng_fcgi" ]]  && echo -e "        └─ PHP FastCGI:  ${FG_YELLOW}${ng_fcgi}${NC}"
                    add_unique_item RESUMO_SITES_DETECTADOS "Nginx: ${ng_dom:-$(basename "$conf")} (${ng_root:-${ng_proxy:-N/A}})"
                done <<< "$NGINX_BLOCKS"
            elif [[ "$conf" != "/etc/nginx/nginx.conf" ]]; then
                NGINX_SITES_COUNT=$((NGINX_SITES_COUNT + 1))
                DOMAINS=$(grep -E "^\s*server_name\s+" "$conf" 2>/dev/null | sed -E 's/^\s*server_name\s+//; s/;//g' | trim_ws || true)
                DOC_ROOT=$(grep -E "^\s*root\s+" "$conf" 2>/dev/null | sed -E 's/^\s*root\s+//; s/;//g' | head -n 1 | trim_ws || true)
                PROXY_PASS=$(grep -E "^\s*proxy_pass\s+" "$conf" 2>/dev/null | sed -E 's/^\s*proxy_pass\s+//; s/;//g' | head -n 2 | trim_ws || true)
                FASTCGI_PASS=$(grep -E "^\s*fastcgi_pass\s+" "$conf" 2>/dev/null | sed -E 's/^\s*fastcgi_pass\s+//; s/;//g' | head -n 1 | trim_ws || true)
                [[ -n "$DOC_ROOT" ]] && add_web_root "$DOC_ROOT"
                echo -e "      • Arquivo: ${FG_CYAN}$(basename "$conf")${NC} | Domínios: ${FG_YELLOW}${DOMAINS:-_}${NC}"
                [[ -n "$DOC_ROOT" ]]     && echo -e "        ├─ Root:         ${FG_GREEN}${DOC_ROOT}${NC}"
                [[ -n "$PROXY_PASS" ]]   && echo -e "        ├─ Proxy Reverso:${FG_CYAN} ${PROXY_PASS}${NC}"
                [[ -n "$FASTCGI_PASS" ]] && echo -e "        └─ PHP FastCGI:  ${FG_YELLOW}${FASTCGI_PASS}${NC}"
                add_unique_item RESUMO_SITES_DETECTADOS "Nginx: ${DOMAINS:-$(basename "$conf")} (${DOC_ROOT:-${PROXY_PASS:-N/A}})"
            fi
        done
    fi
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

# 4.1.1 - Auditoria Completa do Certbot, Renovação Automática e Certificados SSL/TLS
echo -e "\n  ${BOLD}4.1.1 Auditoria do Certbot, Renovação Automática e Certificados SSL/TLS:${NC}"
CERTBOT_BIN=""
for cb_cand in "$(command -v certbot 2>/dev/null || true)" /snap/bin/certbot /usr/bin/certbot /usr/local/bin/certbot /opt/certbot/bin/certbot; do
    if [[ -n "$cb_cand" && -x "$cb_cand" ]]; then
        CERTBOT_BIN="$cb_cand"
        break
    fi
done

CERTBOT_VER=""
CERTBOT_ORIGIN=""
if [[ -n "$CERTBOT_BIN" ]]; then
    CERTBOT_REAL=$(readlink -f "$CERTBOT_BIN" 2>/dev/null || echo "$CERTBOT_BIN")
    CERTBOT_VER=$("$CERTBOT_BIN" --version 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1 || "$CERTBOT_BIN" --version 2>&1 | head -n 1 || echo "Instalado")
    if [[ "$CERTBOT_BIN" == /snap/* || "$CERTBOT_REAL" == *snap* ]]; then
        CERTBOT_ORIGIN="Pacote Snap (${CERTBOT_BIN})"
    elif [[ "$CERTBOT_BIN" == /opt/* ]]; then
        CERTBOT_ORIGIN="Virtualenv / PIP (${CERTBOT_BIN})"
    else
        CERTBOT_ORIGIN="Pacote do Sistema (${CERTBOT_BIN})"
    fi
    log_success "Certbot Detectado: ${BOLD}v${CERTBOT_VER}${NC} — Origem: ${FG_CYAN}${CERTBOT_ORIGIN}${NC}"
    add_unique_item RESUMO_APPS_VERSOES "Certbot:${CERTBOT_VER}"
else
    echo -e "    • ${BOLD}Aplicação Certbot:${NC} ${DIM}Não instalado no host${NC}"
fi

# Verificação de Renovação Automática do Certbot (Systemd Timers + Cron)
RENEW_ACTIVE=0
RENEW_MECHANISMS=()

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    for cb_timer in certbot.timer snap.certbot.renew.timer certbot-renew.timer; do
        if systemctl is-active --quiet "$cb_timer" 2>/dev/null; then
            RENEW_ACTIVE=1
            T_NEXT=$(systemctl show "$cb_timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)
            T_LAST=$(systemctl show "$cb_timer" -p LastTriggerUSec --value 2>/dev/null || true)
            RENEW_MECHANISMS+=("Systemd Timer ATIVO: ${cb_timer} (Última: ${T_LAST:-N/A} | Próxima: ${T_NEXT:-N/A})")
        elif systemctl is-enabled --quiet "$cb_timer" 2>/dev/null; then
            RENEW_MECHANISMS+=("Systemd Timer HABILITADO (porém inativo agora): ${cb_timer}")
        fi
    done
fi

if [[ -f /etc/cron.d/certbot ]]; then
    CRON_CB_LINE=$(grep -vE "^\s*#|^\s*$|^(SHELL|PATH|MAILTO)=" /etc/cron.d/certbot 2>/dev/null | head -n 1 || true)
    if [[ -n "$CRON_CB_LINE" ]]; then
        if [[ -d /run/systemd/system ]] && echo "$CRON_CB_LINE" | grep -q "test -d /run/systemd/system"; then
            RENEW_MECHANISMS+=("Cron (/etc/cron.d/certbot): Presente (delega ao systemd timer quando systemd está ativo)")
        else
            RENEW_ACTIVE=1
            RENEW_MECHANISMS+=("Cron Ativo (/etc/cron.d/certbot): ${CRON_CB_LINE}")
        fi
    fi
fi

for cron_cb_script in /etc/cron.daily/certbot /etc/cron.weekly/certbot; do
    if [[ -x "$cron_cb_script" ]]; then
        RENEW_ACTIVE=1
        RENEW_MECHANISMS+=("Script Cron Periódico: ${cron_cb_script}")
    fi
done

USER_CRON_CB=$(grep -RhsE "certbot\s+renew|letsencrypt\s+renew|acme\.sh\s+--cron" /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* /var/spool/cron/* 2>/dev/null | grep -vE "^\s*#" | grep -v "test -d /run/systemd/system" | head -n 3 || true)
if [[ -n "$USER_CRON_CB" ]]; then
    RENEW_ACTIVE=1
    while IFS= read -r ucb; do
        [[ -n "$ucb" ]] && RENEW_MECHANISMS+=("Crontab Customizado: ${ucb}")
    done <<< "$USER_CRON_CB"
fi

if [[ -n "$CERTBOT_BIN" || -d /etc/letsencrypt/live ]]; then
    if (( RENEW_ACTIVE == 1 )); then
        echo -e "    • ${BOLD}Renovação Automática:${NC} ${FG_GREEN}${BOLD}ATIVA${NC}"
        if (( ${#RENEW_MECHANISMS[@]} > 0 )); then
            for rm_item in "${RENEW_MECHANISMS[@]}"; do
                echo -e "      ├─ ${FG_CYAN}${rm_item}${NC}"
            done
        fi
    else
        echo -e "    • ${BOLD}Renovação Automática:${NC} ${FG_RED}${BOLD}INATIVA / NÃO CONFIGURADA${NC}"
        if (( ${#RENEW_MECHANISMS[@]} > 0 )); then
            for rm_item in "${RENEW_MECHANISMS[@]}"; do
                [[ -n "$rm_item" ]] && echo -e "      ├─ ${FG_YELLOW}${rm_item}${NC}"
            done
        fi
        if [[ -d /etc/letsencrypt/live ]]; then
            add_alert "Certbot possui diretório /etc/letsencrypt/live, mas a renovação automática (Timer/Cron) está INATIVA!"
        fi
    fi

    # Hooks globais de renovação
    if [[ -d /etc/letsencrypt/renewal-hooks ]]; then
        HOOK_FILES=$(find /etc/letsencrypt/renewal-hooks -type f 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || true)
        [[ -n "$HOOK_FILES" ]] && echo -e "    • ${BOLD}Hooks Globais (/etc/letsencrypt/renewal-hooks):${NC} ${DIM}${HOOK_FILES}${NC}"
    fi
fi

# Inventário detalhado de todos os certificados em /etc/letsencrypt/live
CERT_COUNT=0
if [[ -d /etc/letsencrypt/live ]] && command -v openssl >/dev/null 2>&1; then
    for cert_pem in /etc/letsencrypt/live/*/cert.pem; do
        [[ -f "$cert_pem" ]] || continue
        CERT_COUNT=$((CERT_COUNT + 1))
        (( CERT_COUNT == 1 )) && echo -e "\n    ${BOLD}Certificados Gerenciados em /etc/letsencrypt/live (Local, Validade e Renovação):${NC}"

        CERT_DIR=$(dirname "$cert_pem")
        CERT_DOMAIN=$(basename "$CERT_DIR")
        FULLCHAIN_PATH="${CERT_DIR}/fullchain.pem"
        PRIVKEY_PATH="${CERT_DIR}/privkey.pem"
        REAL_ARCHIVE=$(readlink -f "$FULLCHAIN_PATH" 2>/dev/null || echo "$FULLCHAIN_PATH")
        RENEWAL_CONF="/etc/letsencrypt/renewal/${CERT_DOMAIN}.conf"

        START_DATE=$(openssl x509 -startdate -noout -in "$cert_pem" 2>/dev/null | cut -d'=' -f2 || true)
        END_DATE=$(openssl x509 -enddate -noout -in "$cert_pem" 2>/dev/null | cut -d'=' -f2 || true)
        ISSUER_STR=$(openssl x509 -issuer -noout -in "$cert_pem" 2>/dev/null | sed -E 's/^issuer=[ \t]*//; s/[ \t]+$//' || true)
        SAN_DOMAINS=$(openssl x509 -noout -ext subjectAltName -in "$cert_pem" 2>/dev/null | grep -oE 'DNS:[^, ]+' | sed 's/DNS://g' | tr '\n' ' ' | sed -E 's/^[ \t]+|[ \t]+$//g' || true)

        END_EPOCH=$(date -d "$END_DATE" +%s 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))

        VAL_STATUS_STR=""
        if (( DAYS_LEFT < 0 )); then
            VAL_STATUS_STR="${FG_RED}${BOLD}EXPIRADO há $(( -DAYS_LEFT )) dia(s)${NC} (Expirou em: ${END_DATE})"
            add_critical_alert "Certificado SSL '${CERT_DOMAIN}' está EXPIRADO desde ${END_DATE}!"
        elif (( DAYS_LEFT < 15 )); then
            VAL_STATUS_STR="${FG_YELLOW}${BOLD}EXPIRA EM BREVE (${DAYS_LEFT} dia(s) restantes)${NC} (Expira em: ${END_DATE})"
            add_alert "Certificado SSL '${CERT_DOMAIN}' expira em ${DAYS_LEFT} dias (${END_DATE})."
        else
            VAL_STATUS_STR="${FG_GREEN}${BOLD}VÁLIDO (${DAYS_LEFT} dias restantes)${NC} — Emissão: ${START_DATE} | Expira: ${END_DATE}"
        fi

        echo -e "      • ${FG_CYAN}${BOLD}Certificado [${CERT_DOMAIN}]${NC} — Status: ${VAL_STATUS_STR}"
        echo -e "        ├─ ${BOLD}Domínios Cobertos (SAN):${NC} ${FG_YELLOW}${SAN_DOMAINS:-$CERT_DOMAIN}${NC}"
        echo -e "        ├─ ${BOLD}Emissor (Autoridade):${NC}    ${DIM}${ISSUER_STR:-Lets Encrypt}${NC}"
        echo -e "        ├─ ${BOLD}Local do Certificado:${NC}    ${FG_GREEN}${FULLCHAIN_PATH}${NC} ${DIM}(-> ${REAL_ARCHIVE})${NC}"
        echo -e "        ├─ ${BOLD}Local da Chave Privada:${NC}  ${FG_CYAN}${PRIVKEY_PATH}${NC}"

        if [[ -r "$RENEWAL_CONF" ]]; then
            CB_AUTH=$(awk -F'=' '/^\s*authenticator\s*=/ {gsub(/[ \t]/,"",$2); print $2}' "$RENEWAL_CONF" 2>/dev/null | head -n 1 || true)
            CB_INST=$(awk -F'=' '/^\s*installer\s*=/ {gsub(/[ \t]/,"",$2); print $2}' "$RENEWAL_CONF" 2>/dev/null | head -n 1 || true)
            CB_WEBROOT=$(awk -F'=' '/^\s*webroot_path\s*=/ {gsub(/[ \t,]/,"",$2); print $2}' "$RENEWAL_CONF" 2>/dev/null | head -n 1 || true)
            CB_HOOK=$(awk -F'=' '/^\s*(renew_hook|post_hook|deploy_hook)\s*=/ {sub(/^[^=]+=\s*/,""); print $0}' "$RENEWAL_CONF" 2>/dev/null | head -n 1 || true)
            echo -e "        └─ ${BOLD}Config de Renovação:${NC}     ${RENEWAL_CONF} (Plugin Auth: ${FG_YELLOW}${CB_AUTH:-N/A}${NC} | Installer: ${CB_INST:-None}${CB_WEBROOT:+ | Webroot: $CB_WEBROOT}${CB_HOOK:+ | Hook: $CB_HOOK})"
        else
            echo -e "        └─ ${BOLD}Config de Renovação:${NC}     ${FG_YELLOW}Arquivo ${RENEWAL_CONF} não encontrado${NC}"
        fi
    done
fi

# Auditoria de Certificados SSL/TLS Externos (fora do Certbot, referenciados em VirtualHosts Apache/Nginx)
if (( ${#EXTRA_SSL_CERTS[@]} > 0 )) && command -v openssl >/dev/null 2>&1; then
    echo -e "\n    ${BOLD}Certificados SSL/TLS Externos (Fora do Certbot — Apache/Nginx):${NC}"
    for xcert_entry in "${EXTRA_SSL_CERTS[@]}"; do
        xcert_path="${xcert_entry%%|*}"
        xcert_src="${xcert_entry#*|}"
        [[ -r "$xcert_path" ]] || continue
        X_END=$(openssl x509 -enddate -noout -in "$xcert_path" 2>/dev/null | cut -d'=' -f2 || true)
        [[ -z "$X_END" ]] && continue
        X_SUBJ=$(openssl x509 -subject -noout -in "$xcert_path" 2>/dev/null | sed -E 's/^subject=[ \t]*//; s/[ \t]+$//' || true)
        X_ISSUER=$(openssl x509 -issuer -noout -in "$xcert_path" 2>/dev/null | sed -E 's/^issuer=[ \t]*//; s/[ \t]+$//' || true)
        X_END_EP=$(date -d "$X_END" +%s 2>/dev/null || echo 0)
        X_NOW_EP=$(date +%s)
        X_DAYS=$(( (X_END_EP - X_NOW_EP) / 86400 ))
        if (( X_DAYS < 0 )); then
            X_STAT="${FG_RED}${BOLD}EXPIRADO há $(( -X_DAYS )) dia(s)${NC} (Expirou em: ${X_END})"
            add_critical_alert "Certificado SSL externo (${xcert_src} -> ${xcert_path}) está EXPIRADO desde ${X_END}!"
        elif (( X_DAYS < 15 )); then
            X_STAT="${FG_YELLOW}${BOLD}EXPIRA EM BREVE (${X_DAYS} dia(s) restantes)${NC} (Expira em: ${X_END})"
            add_alert "Certificado SSL externo (${xcert_src} -> ${xcert_path}) expira em ${X_DAYS} dias (${X_END})."
        else
            X_STAT="${FG_GREEN}${BOLD}VÁLIDO (${X_DAYS} dias restantes)${NC} — Expira: ${X_END}"
        fi
        echo -e "      • ${FG_CYAN}${BOLD}[${xcert_src}]${NC} ${xcert_path} — Status: ${X_STAT}"
        echo -e "        ├─ ${BOLD}Titular (Subject):${NC} ${FG_YELLOW}${X_SUBJ:-N/A}${NC}"
        echo -e "        └─ ${BOLD}Emissor:${NC}           ${DIM}${X_ISSUER:-N/A}${NC}"
    done
fi

if [[ -n "$CERTBOT_BIN" || "$CERT_COUNT" -gt 0 ]]; then
    RENEW_TAG="INATIVA"
    (( RENEW_ACTIVE == 1 )) && RENEW_TAG="ATIVA"
    RESUMO_CERTBOT_STATUS="Certbot v${CERTBOT_VER:-N/A} | ${CERT_COUNT} certificado(s) em /etc/letsencrypt/live | Auto-Renew: ${RENEW_TAG}"
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
                POOL_LISTEN=$(grep -E "^\s*listen\s*=" "$pool_conf" 2>/dev/null | cut -d'=' -f2 | trim_ws || true)
                POOL_USER=$(grep -E "^\s*user\s*=" "$pool_conf" 2>/dev/null | cut -d'=' -f2 | trim_ws || true)
                echo -e "         ├─ Pool FPM [${FG_CYAN}${POOL_NAME:-www}${NC}]: Usuário=${POOL_USER:-www-data} | Listen=${FG_YELLOW}${POOL_LISTEN:-N/A}${NC}"
            done
        fi
        for sapi in fpm apache2 cli; do
            INI_FILE="${php_dir}/${sapi}/php.ini"
            [[ -f "$INI_FILE" ]] || continue
            EXPOSE_PHP=$(awk -F'=' '/^\s*expose_php\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            MEM_LIMIT=$(awk -F'=' '/^\s*memory_limit\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            UPLOAD_MAX=$(awk -F'=' '/^\s*upload_max_filesize\s*=/ {gsub(/[ \t\r]/,"",$2); print $2}' "$INI_FILE" | tail -n 1)
            DISABLE_FN=$(awk -F'=' '/^\s*disable_functions\s*=/ {print $2}' "$INI_FILE" | tail -n 1 | sed -E 's/^[ \t]+|[ \t\r]+$//g' || true)
            DF_STR="Vazio"
            if [[ -n "$DISABLE_FN" ]]; then
                DF_STR="Configurado (${DISABLE_FN:0:45}...)"
            fi
            echo -e "         └─ php.ini (${sapi}): expose_php=${EXPOSE_PHP:-On} | memory_limit=${MEM_LIMIT:-128M} | upload_max=${UPLOAD_MAX:-2M} | disable_functions=${DF_STR}"
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
    if command -v php >/dev/null 2>&1; then
        PHP_EXTS_ALL=$(php -m 2>/dev/null | grep -vE '^\[|^$' | sort -u || true)
        if [[ -n "$PHP_EXTS_ALL" ]]; then
            PHP_EXTS_CRIT=$(echo "$PHP_EXTS_ALL" | grep -iE '^(apcu|curl|dom|exif|fileinfo|gd|imagick|imap|intl|json|ldap|mbstring|mcrypt|mysqli|mysqlnd|opcache|openssl|pdo|pdo_mysql|pdo_pgsql|pdo_sqlite|pgsql|redis|simplexml|soap|sodium|sqlite3|xml|xmlwriter|xsl|zip|zlib|Zend OPcache)$' | tr '\n' ' ' | trim_ws || true)
            PHP_EXTS_COUNT=$(echo "$PHP_EXTS_ALL" | wc -l | trim_ws)
            echo -e "    • ${BOLD}Extensões PHP CLI Ativas (${PHP_EXTS_COUNT} total):${NC} ${DIM}${PHP_EXTS_CRIT:-$(echo "$PHP_EXTS_ALL" | head -n 15 | tr '\n' ' ' | trim_ws)}${NC}"
        fi
    fi
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
    elif [[ -n "${DNF_SIM:-}" || -n "${YUM_SIM:-}" ]]; then
        RHEL_SIM="${DNF_SIM:-${YUM_SIM:-}}"
        PHP_UPGRADABLE=$(echo "$RHEL_SIM" | awk 'NF>=3 && $1 ~ /^php/ {print $1 " -> " $2 " (" $3 ")"}' || true)
        if [[ -n "$PHP_UPGRADABLE" ]]; then
            print_alert_box "Há atualizações de pacotes PHP pendentes no DNF/YUM!"
            while IFS= read -r upg_line; do
                echo -e "      • ${FG_YELLOW}${upg_line}${NC}"
            done <<< "$PHP_UPGRADABLE"
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
SCAN_DIRS=()
if (( ${#DISCOVERED_WEB_ROOTS[@]} > 0 )); then
    for d_root in "${DISCOVERED_WEB_ROOTS[@]}"; do
        [[ -d "$d_root" ]] && add_unique_item SCAN_DIRS "$d_root"
    done
fi
for std_dir in "/var/www" "/srv" "/home" "/opt" "/var/lib/mediawiki" "/usr/share/mediawiki" "/usr/share/dokuwiki" "/usr/share/nextcloud" "/usr/share/zabbix" "/usr/share/glpi" "/usr/share/roundcube" "/usr/share/redmine" "/usr/share/phpmyadmin"; do
    [[ -d "$std_dir" ]] && add_unique_item SCAN_DIRS "$std_dir"
done
# Inclui diretórios customizados na raiz / (ex: /arquivos, /sistemas, /dados, /www, /app)
for top_dir in /*; do
    [[ -d "$top_dir" && ! -L "$top_dir" ]] || continue
    top_base=$(basename "$top_dir")
    case "$top_base" in
        bin|boot|cdrom|dev|etc|home|lib|lib32|lib64|libx32|lost+found|media|mnt|opt|proc|root|run|sbin|snap|srv|sys|tmp|usr|var)
            continue
            ;;
        *)
            add_unique_item SCAN_DIRS "$top_dir"
            ;;
    esac
done

FOUND_APPS=0
AUDITED_APP_DIRS=()

mark_app_audited() {
    local target_dir="$1" real_d item
    real_d=$(readlink -f "$target_dir" 2>/dev/null || echo "${target_dir%/}")
    if (( ${#AUDITED_APP_DIRS[@]} > 0 )); then
        for item in "${AUDITED_APP_DIRS[@]}"; do
            [[ "$item" == "$real_d" ]] && return 1
        done
    fi
    AUDITED_APP_DIRS+=("$real_d")
    return 0
}

audit_nextcloud_dir() {
    local app_dir="$1" ver_file="$2" cfg_file="$3" install_type="${4:-Diretório Web Host}"
    mark_app_audited "$app_dir" || return 0

    local nc_ver nc_build_ver nc_installed nc_inst_id nc_chan nc_datadir nc_dbtype nc_dbname nc_dbhost nc_dbuser nc_url nc_maint nc_mem_local nc_mem_lock nc_domains nc_proxies

    nc_ver=$(grep "\$OC_VersionString" "$ver_file" 2>/dev/null | cut -d"'" -f2 || echo "Detectado")
    nc_chan=$(grep "\$OC_Channel" "$ver_file" 2>/dev/null | cut -d"'" -f2 || true)

    nc_build_ver=""
    nc_installed=""
    nc_inst_id=""
    nc_datadir=""
    nc_dbtype=""
    nc_dbname=""
    nc_dbhost=""
    nc_dbuser=""
    nc_url=""
    nc_maint="false"
    nc_mem_local=""
    nc_mem_lock=""
    nc_domains=""
    nc_proxies=""

    if [[ -r "$cfg_file" ]]; then
        nc_build_ver=$(awk -F"=>" '/['"'"'"]version['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_installed=$(awk -F"=>" '/['"'"'"]installed['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print tolower(val); exit}' "$cfg_file" 2>/dev/null || true)
        nc_inst_id=$(awk -F"=>" '/['"'"'"]instanceid['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_datadir=$(awk -F"=>" '/['"'"'"]datadirectory['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_dbtype=$(awk -F"=>" '/['"'"'"]dbtype['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_dbname=$(awk -F"=>" '/['"'"'"]dbname['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_dbhost=$(awk -F"=>" '/['"'"'"]dbhost['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_dbuser=$(awk -F"=>" '/['"'"'"]dbuser['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_url=$(awk -F"=>" '/['"'"'"]overwrite\.cli\.url['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_maint=$(awk -F"=>" '/['"'"'"]maintenance['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); print tolower(val); exit}' "$cfg_file" 2>/dev/null || true)
        nc_mem_local=$(awk -F"=>" '/['"'"'"]memcache\.local['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); gsub(/\\\\/, "\\", val); print val; exit}' "$cfg_file" 2>/dev/null || true)
        nc_mem_lock=$(awk -F"=>" '/['"'"'"]memcache\.locking['"'"'"]\s*=>/ {val=$2; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", val); gsub(/\\\\/, "\\", val); print val; exit}' "$cfg_file" 2>/dev/null || true)

        nc_domains=$(awk '
            /['"'"'"]trusted_domains['"'"'"]\s*=>/ { in_td=1; next }
            in_td && /\)/ { in_td=0 }
            in_td && /=>/ {
                split($0, a, "=>")
                v=a[2]; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", v)
                if (v != "") printf "%s, ", v
            }
        ' "$cfg_file" 2>/dev/null | sed 's/, $//' || true)

        nc_proxies=$(awk '
            /['"'"'"]trusted_proxies['"'"'"]\s*=>/ { in_tp=1; next }
            in_tp && /\)/ { in_tp=0 }
            in_tp && /=>/ {
                split($0, a, "=>")
                v=a[2]; gsub(/^[ \t'"'"'"]+|[ \t'"'"'",\r]+$/, "", v)
                if (v != "") printf "%s, ", v
            }
        ' "$cfg_file" 2>/dev/null | sed 's/, $//' || true)
    fi

    echo -e "    • ${FG_GREEN}${BOLD}Nextcloud v${nc_ver}${NC}${nc_build_ver:+ (version: ${nc_build_ver})}${nc_chan:+ [Canal: ${nc_chan}]} — Tipo: ${FG_CYAN}${install_type}${NC}"
    echo -e "      ├─ ${BOLD}Caminho da Aplicação:${NC}  ${FG_CYAN}${app_dir}${NC} (Config: ${cfg_file}${nc_inst_id:+ | InstanceID: ${nc_inst_id}})"
    if [[ -f "${app_dir}/occ" ]]; then
        echo -e "      ├─ ${BOLD}Console CLI (occ):${NC}     ${FG_GREEN}${app_dir}/occ${NC} (installed: ${nc_installed:-true})"
    fi

    if [[ "$nc_maint" == "true" || "$nc_maint" == "1" ]]; then
        echo -e "      ├─ ${BOLD}Modo de Manutenção:${NC}    ${FG_RED}${BOLD}ATIVO (maintenance => true — Sistema bloqueado para usuários!)${NC}"
        add_alert "Nextcloud em ${app_dir} está com Modo de Manutenção ATIVO (maintenance => true)."
    else
        echo -e "      ├─ ${BOLD}Modo de Manutenção:${NC}    ${FG_GREEN}Desativado (Operacional)${NC}"
    fi

    if [[ -n "$nc_datadir" ]]; then
        local dd_info=""
        if [[ -d "$nc_datadir" ]]; then
            local dd_size dd_df
            dd_size=$(safe_du "$nc_datadir")
            dd_df=$(timeout 5 df -h "$nc_datadir" 2>/dev/null | awk 'NR==2 {print "Partição " $6 ": " $3 " usados de " $2 " (" $5 " cheio, Livre: " $4 ")"}' || true)
            dd_info="${dd_size:+ — Tamanho Dados: ${FG_YELLOW}${dd_size}${NC}}${dd_df:+ | ${DIM}${dd_df}${NC}}"
            if [[ "$nc_dbtype" == *"sqlite"* ]]; then
                local nc_sqlite_file
                nc_sqlite_file=$(find "$nc_datadir" -maxdepth 2 -type f \( -name "*.db" -o -name "*.sqlite" \) 2>/dev/null | head -n 1 || true)
                [[ -n "$nc_sqlite_file" ]] && add_unique_item SQLITE_DBS_FOUND "${nc_sqlite_file} (Nextcloud)"
            fi
        else
            dd_info=" ${FG_RED}(Diretório não encontrado ou desmontado!)${NC}"
            add_alert "Diretório de dados do Nextcloud (${nc_datadir}) não foi encontrado ou está desmontado!"
        fi
        echo -e "      ├─ ${BOLD}Diretório de Dados:${NC}    ${FG_GREEN}${nc_datadir}${NC}${dd_info}"
    fi

    [[ -n "$nc_domains" || -n "$nc_url" ]] && echo -e "      ├─ ${BOLD}Domínios Confiáveis:${NC}   ${FG_YELLOW}${nc_domains:-N/A}${NC}${nc_url:+ (URL CLI: ${FG_CYAN}${nc_url}${NC})}"
    [[ -n "$nc_proxies" ]] && echo -e "      ├─ ${BOLD}Trusted Proxies:${NC}       ${FG_CYAN}${nc_proxies}${NC}"
    [[ -n "$nc_dbtype" || -n "$nc_dbname" ]] && echo -e "      ├─ ${BOLD}Banco Configurado:${NC}     Tipo: ${FG_YELLOW}${nc_dbtype:-N/A}${NC} | Base: ${FG_CYAN}${nc_dbname:-N/A}${NC} | Host: ${nc_dbhost:-localhost} | Usuário: ${nc_dbuser:-N/A}"
    [[ -n "$nc_mem_local" || -n "$nc_mem_lock" ]] && echo -e "      ├─ ${BOLD}Cache / Memcache:${NC}      Local: ${FG_CYAN}${nc_mem_local:-Não configurado}${NC} | Locking: ${FG_CYAN}${nc_mem_lock:-Não configurado}${NC}"

    # Verifica Cron / Background Job do Nextcloud
    local nc_cron_status="${FG_YELLOW}Não identificado em crontabs/timers (pode estar em modo AJAX)${NC}"
    if grep -Rqs "cron\.php" /var/spool/cron/crontabs/ /var/spool/cron/ /etc/crontab /etc/cron.d/ 2>/dev/null; then
        nc_cron_status="${FG_GREEN}Ativo via Crontab (cron.php)${NC}"
    elif command -v systemctl >/dev/null 2>&1 && systemctl list-timers --all 2>/dev/null | grep -qiE "nextcloud"; then
        nc_cron_status="${FG_GREEN}Ativo via Systemd Timer${NC}"
    fi
    echo -e "      └─ ${BOLD}Background Jobs (Cron):${NC} ${nc_cron_status}"

    local nc_major="${nc_ver%%.*}"
    if [[ "$nc_major" =~ ^[0-9]+$ ]] && (( nc_major < 28 )); then
        add_alert "Nextcloud v${nc_ver} em ${app_dir} está em versão antiga/End-of-Life (Recomendado: >= 28)."
    fi

    add_role "Storage Nuvem (Nextcloud ${nc_ver})"
    add_unique_item RESUMO_APPS_VERSOES "Nextcloud:${nc_ver}"
    add_unique_item RESUMO_SITES_DETECTADOS "Nextcloud v${nc_ver}: ${app_dir}${nc_domains:+ (Domínios: $nc_domains)}${nc_datadir:+ [Dados: $nc_datadir]}"
    FOUND_APPS=$((FOUND_APPS + 1))
}

audit_mediawiki_dir() {
    local app_dir="$1"
    if [[ "$app_dir" == "/usr/share/mediawiki" && -L /var/lib/mediawiki/includes ]]; then
        return 0
    fi
    mark_app_audited "$app_dir" || return 0

    local mw_ver="" mw_cfg="" mw_site="" mw_url="" mw_dbtype="" mw_dbname="" mw_sqdir="" mw_minor=""
    if [[ -r "${app_dir}/includes/Defines.php" ]]; then
        mw_ver=$(grep -E "define\([[:space:]]*['\"]MW_VERSION['\"]" "${app_dir}/includes/Defines.php" 2>/dev/null | sed -E "s/.*['\"]MW_VERSION['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
    fi
    if [[ -z "$mw_ver" && -r "${app_dir}/includes/DefaultSettings.php" ]]; then
        mw_ver=$(grep -E "^[[:space:]]*\\\$wgVersion[[:space:]]*=" "${app_dir}/includes/DefaultSettings.php" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
    fi
    if [[ -z "$mw_ver" && -r "${app_dir}/composer.json" ]]; then
        mw_ver=$(grep -m 1 -E '"version"[[:space:]]*:' "${app_dir}/composer.json" 2>/dev/null | cut -d'"' -f4 || true)
    fi
    if [[ -z "$mw_ver" && "$app_dir" == *mediawiki* ]]; then
        mw_ver=$(_get_pkg_ver "mediawiki")
    fi

    if [[ -r "${app_dir}/LocalSettings.php" ]]; then
        mw_cfg="${app_dir}/LocalSettings.php"
    elif [[ -r /etc/mediawiki/LocalSettings.php && "$app_dir" == *mediawiki* ]]; then
        mw_cfg="/etc/mediawiki/LocalSettings.php"
    fi

    if [[ -n "$mw_cfg" ]]; then
        mw_site=$(grep -E "^[[:space:]]*\\\$wgSitename[[:space:]]*=" "$mw_cfg" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
        mw_url=$(grep -E "^[[:space:]]*\\\$wgServer[[:space:]]*=" "$mw_cfg" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
        mw_dbtype=$(grep -E "^[[:space:]]*\\\$wgDBtype[[:space:]]*=" "$mw_cfg" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
        mw_dbname=$(grep -E "^[[:space:]]*\\\$wgDBname[[:space:]]*=" "$mw_cfg" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
        mw_sqdir=$(grep -E "^[[:space:]]*\\\$wgSQLiteDataDir[[:space:]]*=" "$mw_cfg" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
        if [[ "$mw_dbtype" == *"sqlite"* && -n "$mw_sqdir" && -d "$mw_sqdir" ]]; then
            local mw_sqfile=""
            mw_sqfile=$(find "$mw_sqdir" -maxdepth 2 -type f \( -name "*.sqlite" -o -name "*.db" \) 2>/dev/null | head -n 1 || true)
            [[ -n "$mw_sqfile" ]] && add_unique_item SQLITE_DBS_FOUND "${mw_sqfile} (MediaWiki)"
        fi
    fi

    echo -e "    • ${FG_GREEN}${BOLD}MediaWiki v${mw_ver:-Detectado}${NC}${mw_site:+ (${mw_site})} -> Caminho: ${FG_CYAN}${app_dir}${NC}${mw_dbname:+ (Banco${mw_dbtype:+/$mw_dbtype}: ${FG_YELLOW}${mw_dbname}${NC})}${mw_url:+ [URL: ${mw_url}]}"
    if [[ "$mw_ver" =~ ^1\.([0-9]+)(\.|$) ]]; then
        mw_minor="${BASH_REMATCH[1]}"
        if (( mw_minor < 39 || mw_minor == 40 || mw_minor == 41 )); then
            add_alert "MediaWiki v${mw_ver} em ${app_dir} está em versão End-of-Life / sem suporte de segurança (LTS recomendadas: 1.39 / 1.43+)."
        fi
    elif [[ "$mw_ver" =~ ^0\. ]]; then
        add_alert "MediaWiki v${mw_ver} em ${app_dir} está em versão obsoleta/End-of-Life."
    fi

    add_role "Wiki / Conhecimento (MediaWiki ${mw_ver:-Wiki})"
    add_unique_item RESUMO_APPS_VERSOES "MediaWiki:${mw_ver:-Wiki}"
    add_unique_item RESUMO_SITES_DETECTADOS "MediaWiki v${mw_ver:-Detectado}: ${app_dir}${mw_site:+ (${mw_site})}${mw_url:+ [${mw_url}]}"
    FOUND_APPS=$((FOUND_APPS + 1))
}

# Verifica instalação do Nextcloud via Pacote SNAP (/var/snap/nextcloud)
if [[ -d /var/snap/nextcloud/current ]] || [[ -f /snap/nextcloud/current/htdocs/version.php ]]; then
    SNAP_NC_VER_FILE="/snap/nextcloud/current/htdocs/version.php"
    SNAP_NC_CFG_FILE="/var/snap/nextcloud/current/nextcloud/config/config.php"
    if [[ -f "$SNAP_NC_VER_FILE" ]]; then
        audit_nextcloud_dir "/snap/nextcloud/current/htdocs" "$SNAP_NC_VER_FILE" "$SNAP_NC_CFG_FILE" "Pacote Snap (nextcloud)"
    fi
fi

if (( ${#SCAN_DIRS[@]} > 0 )); then
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
        mark_app_audited "$APP_DIR" || continue
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
        if [[ "$J_VER_EXACT" =~ ^([1-4])\. ]]; then
            add_alert "Joomla v${J_VER_EXACT} em ${APP_DIR} está em ramo legado/End-of-Life (Recomendado: Joomla 5.x+)."
        fi
        add_role "Hospedagem Joomla (${J_VER_EXACT:-CMS})"
        add_unique_item RESUMO_APPS_VERSOES "Joomla:${J_VER_EXACT:-CMS}"
        add_unique_item RESUMO_SITES_DETECTADOS "Joomla ${J_VER_EXACT:-CMS}: ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 6 -type f \( -path "*/libraries/src/Version.php" -o -path "*/includes/version.php" \) 2>/dev/null)

    # WordPress
    while IFS= read -r wp_ver_file; do
        [[ -f "$wp_ver_file" ]] || continue
        APP_DIR=$(dirname "$(dirname "$wp_ver_file")")
        mark_app_audited "$APP_DIR" || continue
        WP_VER=$(grep "^\$wp_version\s*=" "$wp_ver_file" 2>/dev/null | cut -d"'" -f2 || true)
        WP_DB=""
        [[ -f "${APP_DIR}/wp-config.php" ]] && WP_DB=$(grep -E "define\(\s*'DB_NAME'" "${APP_DIR}/wp-config.php" 2>/dev/null | cut -d"'" -f4 || true)
        echo -e "    • ${FG_GREEN}${BOLD}WordPress v${WP_VER:-Detectado}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${WP_DB:+ (Banco: ${FG_YELLOW}${WP_DB}${NC})}"
        if [[ "$WP_VER" =~ ^([1-5])\. ]]; then
            add_alert "WordPress v${WP_VER} em ${APP_DIR} está em ramo legado (< 6.x) — verificar atualizações de segurança."
        fi
        add_role "Hospedagem WordPress (${WP_VER:-CMS})"
        add_unique_item RESUMO_APPS_VERSOES "WordPress:${WP_VER:-CMS}"
        add_unique_item RESUMO_SITES_DETECTADOS "WordPress ${WP_VER:-CMS}: ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 5 -type f -path "*/wp-includes/version.php" 2>/dev/null)

    # Laravel
    while IFS= read -r artisan_file; do
        [[ -f "$artisan_file" ]] || continue
        APP_DIR=$(dirname "$artisan_file")
        mark_app_audited "$APP_DIR" || continue
        APP_NAME_ENV=""
        DB_NAME_ENV=""
        LARAVEL_VER=""
        if [[ -f "${APP_DIR}/.env" ]]; then
            APP_NAME_ENV=$(awk -F'=' '/^APP_NAME=/ {gsub(/["'\'']/,"",$2); print $2}' "${APP_DIR}/.env" 2>/dev/null | head -n 1 || true)
            DB_NAME_ENV=$(awk -F'=' '/^DB_DATABASE=/ {gsub(/["'\'']/,"",$2); print $2}' "${APP_DIR}/.env" 2>/dev/null | head -n 1 || true)
        fi
        if [[ -r "${APP_DIR}/composer.lock" ]]; then
            LARAVEL_VER=$(awk '/"name"[ \t]*:[ \t]*"laravel\/framework"/ {f=1} f && /"version"[ \t]*:/ {gsub(/.*"version"[ \t]*:[ \t]*"|".*/, ""); print; exit}' "${APP_DIR}/composer.lock" 2>/dev/null || true)
            LARAVEL_VER="${LARAVEL_VER#[vV]}"
        fi
        echo -e "    • ${FG_GREEN}${BOLD}Laravel${LARAVEL_VER:+ v${LARAVEL_VER}} (${APP_NAME_ENV:-App PHP})${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${DB_NAME_ENV:+ (Banco: ${FG_YELLOW}${DB_NAME_ENV}${NC})}"
        add_role "App Laravel${LARAVEL_VER:+ ${LARAVEL_VER}} (${APP_NAME_ENV:-PHP})"
        add_unique_item RESUMO_APPS_VERSOES "Laravel:${LARAVEL_VER:-${APP_NAME_ENV:-App}}"
        add_unique_item RESUMO_SITES_DETECTADOS "Laravel${LARAVEL_VER:+ v${LARAVEL_VER}} (${APP_NAME_ENV:-App}): ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 5 -type f -name "artisan" 2>/dev/null)

    # GLPI, Zabbix, Drupal, MediaWiki, DokuWiki, Roundcube, Redmine, Nextcloud, Moodle, Vtiger CRM, osTicket, Ampache, phpMyAdmin/Adminer
    while IFS= read -r special_marker; do
        [[ -f "$special_marker" ]] || continue
        case "$special_marker" in
            */LocalSettings.php)
                if grep -qE "\\\$wg(Sitename|DBname|Server|ScriptPath)" "$special_marker" 2>/dev/null || [[ -f "$(dirname "$special_marker")/includes/Defines.php" || -f "$(dirname "$special_marker")/includes/DefaultSettings.php" ]]; then
                    APP_DIR=$(dirname "$special_marker")
                    audit_mediawiki_dir "$APP_DIR"
                fi
                ;;
            */includes/Defines.php)
                if grep -qE "define\([[:space:]]*['\"]MW_VERSION['\"]" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$(dirname "$special_marker")")
                    audit_mediawiki_dir "$APP_DIR"
                fi
                ;;
            */doku.php)
                APP_DIR=$(dirname "$special_marker")
                if [[ -f "${APP_DIR}/VERSION" || -d "${APP_DIR}/conf" ]]; then
                    mark_app_audited "$APP_DIR" || continue
                    DOKU_VER=""
                    [[ -r "${APP_DIR}/VERSION" ]] && DOKU_VER=$(head -n 1 "${APP_DIR}/VERSION" 2>/dev/null | trim_ws || true)
                    DOKU_TITLE=""
                    [[ -r "${APP_DIR}/conf/local.php" ]] && DOKU_TITLE=$(grep -E "^[[:space:]]*\\\$conf\['title'\]" "${APP_DIR}/conf/local.php" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | tail -n 1 || true)
                    echo -e "    • ${FG_GREEN}${BOLD}DokuWiki ${DOKU_VER:-Detectado}${NC}${DOKU_TITLE:+ (${DOKU_TITLE})} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    add_role "Wiki / Conhecimento (DokuWiki${DOKU_VER:+ ${DOKU_VER%% *}})"
                    add_unique_item RESUMO_APPS_VERSOES "DokuWiki:${DOKU_VER:-Wiki}"
                    add_unique_item RESUMO_SITES_DETECTADOS "DokuWiki (${DOKU_VER:-Wiki}): ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            */program/include/iniset.php)
                if grep -q "RCUBE_VERSION" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$(dirname "$(dirname "$special_marker")")")
                    mark_app_audited "$APP_DIR" || continue
                    RC_VER=$(grep -E "define\([[:space:]]*['\"]RCUBE_VERSION['\"]" "$special_marker" 2>/dev/null | sed -E "s/.*['\"]RCUBE_VERSION['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
                    echo -e "    • ${FG_GREEN}${BOLD}Roundcube Webmail v${RC_VER:-Detectado}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    add_role "Webmail (Roundcube${RC_VER:+ ${RC_VER}})"
                    add_unique_item RESUMO_APPS_VERSOES "Roundcube:${RC_VER:-Webmail}"
                    add_unique_item RESUMO_SITES_DETECTADOS "Roundcube v${RC_VER:-Webmail}: ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            */lib/redmine/version.rb)
                APP_DIR=$(dirname "$(dirname "$(dirname "$special_marker")")")
                mark_app_audited "$APP_DIR" || continue
                RM_MAJ=$(awk -F'=' '/^[ \t]*MAJOR[ \t]*=/ {gsub(/[^0-9]/,"",$2); print $2; exit}' "$special_marker" 2>/dev/null || true)
                RM_MIN=$(awk -F'=' '/^[ \t]*MINOR[ \t]*=/ {gsub(/[^0-9]/,"",$2); print $2; exit}' "$special_marker" 2>/dev/null || true)
                RM_TIN=$(awk -F'=' '/^[ \t]*TINY[ \t]*=/ {gsub(/[^0-9]/,"",$2); print $2; exit}' "$special_marker" 2>/dev/null || true)
                RM_VER=""
                [[ -n "$RM_MAJ" ]] && RM_VER="${RM_MAJ}.${RM_MIN:-0}.${RM_TIN:-0}"
                echo -e "    • ${FG_GREEN}${BOLD}Redmine${RM_VER:+ v${RM_VER}}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                add_role "Gestão de Projetos (Redmine${RM_VER:+ ${RM_VER}})"
                add_unique_item RESUMO_APPS_VERSOES "Redmine:${RM_VER:-Ativo}"
                add_unique_item RESUMO_SITES_DETECTADOS "Redmine${RM_VER:+ v${RM_VER}}: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */inc/define.php)
                if grep -q "GLPI_VERSION" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$(dirname "$special_marker")")
                    mark_app_audited "$APP_DIR" || continue
                    GLPI_V=$(grep -E "define\('GLPI_VERSION'" "$special_marker" 2>/dev/null | cut -d"'" -f4 || echo "Detectado")
                    echo -e "    • ${FG_GREEN}${BOLD}GLPI v${GLPI_V}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                    if [[ "$GLPI_V" =~ ^([0-9])\. ]]; then
                        add_alert "GLPI v${GLPI_V} em ${APP_DIR} está em versão End-of-Life (Recomendado: GLPI 10.x+)."
                    fi
                    add_role "Sistema GLPI (${GLPI_V})"
                    add_unique_item RESUMO_APPS_VERSOES "GLPI:${GLPI_V}"
                    add_unique_item RESUMO_SITES_DETECTADOS "GLPI ${GLPI_V}: ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            */zabbix.php)
                APP_DIR=$(dirname "$special_marker")
                mark_app_audited "$APP_DIR" || continue
                ZBX_WEB_VER=""
                if [[ -r "${APP_DIR}/include/defines.inc.php" ]]; then
                    ZBX_WEB_VER=$(grep -E "define\(['\"]ZABBIX_VERSION['\"]" "${APP_DIR}/include/defines.inc.php" 2>/dev/null | sed -E "s/.*['\"]ZABBIX_VERSION['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
                fi
                echo -e "    • ${FG_GREEN}${BOLD}Zabbix Web Frontend${ZBX_WEB_VER:+ v${ZBX_WEB_VER}}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                add_role "Zabbix Frontend Web${ZBX_WEB_VER:+ (${ZBX_WEB_VER})}"
                add_unique_item RESUMO_APPS_VERSOES "Zabbix-Web:${ZBX_WEB_VER:-Frontend}"
                add_unique_item RESUMO_SITES_DETECTADOS "Zabbix Frontend${ZBX_WEB_VER:+ v${ZBX_WEB_VER}}: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */core/lib/Drupal.php)
                APP_DIR=$(dirname "$(dirname "$(dirname "$special_marker")")")
                mark_app_audited "$APP_DIR" || continue
                DRUPAL_VER=$(grep -E "const[[:space:]]+VERSION[[:space:]]*=" "$special_marker" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
                echo -e "    • ${FG_GREEN}${BOLD}CMS Drupal${DRUPAL_VER:+ v${DRUPAL_VER}}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
                if [[ "$DRUPAL_VER" =~ ^([6-9])\. ]]; then
                    add_alert "Drupal v${DRUPAL_VER} em ${APP_DIR} está em versão End-of-Life (Recomendado: Drupal 10.x/11.x)."
                fi
                add_role "Hospedagem Drupal${DRUPAL_VER:+ (${DRUPAL_VER})}"
                add_unique_item RESUMO_APPS_VERSOES "Drupal:${DRUPAL_VER:-CMS}"
                add_unique_item RESUMO_SITES_DETECTADOS "Drupal${DRUPAL_VER:+ v${DRUPAL_VER}}: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */vtigerversion.php)
                APP_DIR=$(dirname "$special_marker")
                mark_app_audited "$APP_DIR" || continue
                VT_VER=$(grep -E "\\\$vtiger_current_version\s*=" "$special_marker" 2>/dev/null | cut -d"'" -f2 | tr -d ' ";' || echo "Detectado")
                VT_DB=""
                VT_URL=""
                if [[ -r "${APP_DIR}/config.inc.php" ]]; then
                    VT_DB=$(grep -E "\\\$dbconfig\['db_name'\]" "${APP_DIR}/config.inc.php" 2>/dev/null | cut -d"'" -f4 || true)
                    VT_URL=$(grep -E "\\\$site_URL\s*=" "${APP_DIR}/config.inc.php" 2>/dev/null | cut -d"'" -f2 || true)
                fi
                echo -e "    • ${FG_GREEN}${BOLD}Vtiger CRM v${VT_VER:-Detectado}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${VT_DB:+ (Banco: ${FG_YELLOW}${VT_DB}${NC})}${VT_URL:+ [URL: ${VT_URL}]}"
                add_role "Sistema CRM (Vtiger ${VT_VER:-CRM})"
                add_unique_item RESUMO_APPS_VERSOES "VtigerCRM:${VT_VER:-Ativo}"
                add_unique_item RESUMO_SITES_DETECTADOS "Vtiger CRM v${VT_VER:-Detectado}: ${APP_DIR}${VT_DB:+ (Banco: $VT_DB)}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */include/ost-config.php)
                APP_DIR=$(dirname "$(dirname "$special_marker")")
                mark_app_audited "$APP_DIR" || continue
                OST_DB=$(grep -E "define\('DBNAME'" "$special_marker" 2>/dev/null | cut -d"'" -f4 || true)
                OST_VER=""
                for ost_vf in "${APP_DIR}/bootstrap.php" "${APP_DIR}/main.inc.php"; do
                    if [[ -r "$ost_vf" ]]; then
                        OST_VER=$(grep -E "define\([[:space:]]*['\"]THIS_VERSION['\"]" "$ost_vf" 2>/dev/null | sed -E "s/.*['\"]THIS_VERSION['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
                        [[ -n "$OST_VER" ]] && break
                    fi
                done
                OST_VER="${OST_VER#[vV]}"
                echo -e "    • ${FG_GREEN}${BOLD}osTicket Helpdesk${OST_VER:+ v${OST_VER}}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${OST_DB:+ (Banco: ${FG_YELLOW}${OST_DB}${NC})}"
                add_role "Helpdesk (osTicket${OST_VER:+ ${OST_VER}})"
                add_unique_item RESUMO_APPS_VERSOES "osTicket:${OST_VER:-Ativo}"
                add_unique_item RESUMO_SITES_DETECTADOS "osTicket Helpdesk${OST_VER:+ v${OST_VER}}: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            */version.php)
                if grep -q "\$OC_VersionString" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$special_marker")
                    audit_nextcloud_dir "$APP_DIR" "$special_marker" "${APP_DIR}/config/config.php" "Diretório Web Host"
                elif grep -q "MOODLE_INTERNAL" "$special_marker" 2>/dev/null && [[ -f "$(dirname "$special_marker")/config.php" || -f "$(dirname "$special_marker")/config-dist.php" ]]; then
                    APP_DIR=$(dirname "$special_marker")
                    mark_app_audited "$APP_DIR" || continue
                    MDL_V=$(grep "^\$release\s*=" "$special_marker" 2>/dev/null | cut -d"'" -f2 || echo "Detectado")
                    MDL_DB=""
                    [[ -r "${APP_DIR}/config.php" ]] && MDL_DB=$(grep -E "^\s*\\\$CFG->dbname\s*=" "${APP_DIR}/config.php" 2>/dev/null | cut -d"'" -f2 || true)
                    echo -e "    • ${FG_GREEN}${BOLD}Moodle v${MDL_V}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${MDL_DB:+ (Banco: ${FG_YELLOW}${MDL_DB}${NC})}"
                    if [[ "$MDL_V" =~ ^([1-3]\.|4\.0) ]]; then
                        add_alert "Moodle (${MDL_V}) em ${APP_DIR} está em versão End-of-Life (Recomendado: >= 4.1 LTS / 4.4+)."
                    fi
                    add_role "Plataforma EAD (Moodle)"
                    add_unique_item RESUMO_APPS_VERSOES "Moodle:${MDL_V}"
                    add_unique_item RESUMO_SITES_DETECTADOS "Moodle (${MDL_V}): ${APP_DIR}"
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            */libraries/classes/Version.php)
                if grep -q "PhpMyAdmin" "$special_marker" 2>/dev/null; then
                    APP_DIR=$(dirname "$(dirname "$(dirname "$special_marker")")")
                    mark_app_audited "$APP_DIR" || continue
                    PMA_VER=$(grep -E "const[[:space:]]+VERSION[[:space:]]*=" "$special_marker" 2>/dev/null | sed -E "s/.*=[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" | head -n 1 || true)
                    [[ -z "$PMA_VER" ]] && PMA_VER=$(_get_pkg_ver "phpmyadmin")
                    log_warning "phpMyAdmin${PMA_VER:+ v${PMA_VER}} Exposto no Disco: ${FG_YELLOW}${APP_DIR}${NC}"
                    add_unique_item RESUMO_APPS_VERSOES "phpMyAdmin:${PMA_VER:-Instalado}"
                    add_alert "Ferramenta de banco web (phpMyAdmin${PMA_VER:+ v${PMA_VER}}) encontrada em ${APP_DIR} — verificar restrição de acesso."
                    FOUND_APPS=$((FOUND_APPS + 1))
                fi
                ;;
            *phpmyadmin*|*adminer*.php)
                mark_app_audited "$special_marker" || continue
                log_warning "Gerenciador de Banco Web Exposto no Disco: ${FG_YELLOW}${special_marker}${NC}"
                add_alert "Ferramenta de banco web encontrada no disco (${special_marker}) — verificar restrição de acesso."
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
            *ampache.cfg.php*)
                APP_DIR=$(dirname "$(dirname "$special_marker")")
                mark_app_audited "$APP_DIR" || continue
                AMP_VER=""
                if [[ -f "${APP_DIR}/composer.json" ]]; then
                    AMP_VER=$(grep -E '"version"\s*:' "${APP_DIR}/composer.json" 2>/dev/null | head -n 1 | cut -d'"' -f4 || true)
                fi
                if [[ -z "$AMP_VER" && -f "${APP_DIR}/src/Config/Init/InitializationHandler.php" ]]; then
                    AMP_VER=$(grep -oE "BUILD_VERSION\s*=\s*'[^']+'" "${APP_DIR}/src/Config/Init/InitializationHandler.php" 2>/dev/null | cut -d"'" -f2 || true)
                fi
                AMP_DB=$(awk -F'=' '/^\s*database_name\s*=/ {gsub(/["'\'' \t\r]/,"",$2); print $2}' "$special_marker" 2>/dev/null | head -n 1 || true)
                echo -e "    • ${FG_GREEN}${BOLD}Ampache Music Streaming ${AMP_VER:+v${AMP_VER}}${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}${AMP_DB:+ (Banco: ${FG_YELLOW}${AMP_DB}${NC})}"
                add_role "Servidor Streaming (Ampache${AMP_VER:+ v$AMP_VER})"
                add_unique_item RESUMO_APPS_VERSOES "Ampache:${AMP_VER:-Instalado}"
                add_unique_item RESUMO_SITES_DETECTADOS "Ampache ${AMP_VER:-Web}: ${APP_DIR}"
                FOUND_APPS=$((FOUND_APPS + 1))
                ;;
        esac
    done < <(find "$base_dir" -maxdepth 5 -type f \( -name "LocalSettings.php" -o -path "*/includes/Defines.php" -o -name "doku.php" -o -path "*/program/include/iniset.php" -o -path "*/lib/redmine/version.rb" -o -path "*/inc/define.php" -o -name "zabbix.php" -o -path "*/core/lib/Drupal.php" -o -name "vtigerversion.php" -o -path "*/include/ost-config.php" -o -name "version.php" -o -path "*/libraries/classes/Version.php" -o -iname "adminer*.php" -o -path "*/config/ampache.cfg.php*" \) 2>/dev/null | sort -u)

    # Descoberta universal de projetos PHP (composer.json) em diretórios web
    while IFS= read -r comp_file; do
        [[ -f "$comp_file" ]] || continue
        APP_DIR=$(dirname "$comp_file")
        [[ -f "${APP_DIR}/artisan" || -f "${APP_DIR}/wp-config.php" || -f "${APP_DIR}/configuration.php" || -f "${APP_DIR}/LocalSettings.php" || -f "${APP_DIR}/includes/Defines.php" || -f "${APP_DIR}/doku.php" || -f "${APP_DIR}/vtigerversion.php" || -f "${APP_DIR}/version.php" || -f "${APP_DIR}/config/ampache.cfg.php" || -f "${APP_DIR}/config/ampache.cfg.php.dist" ]] && continue
        mark_app_audited "$APP_DIR" || continue
        PKG_NAME=$(grep -m 1 -E '"name"\s*:' "$comp_file" 2>/dev/null | cut -d'"' -f4 || true)
        PKG_VER=$(grep -m 1 -E '"version"\s*:' "$comp_file" 2>/dev/null | cut -d'"' -f4 || true)
        if [[ -n "$PKG_NAME" ]]; then
            echo -e "    • ${FG_GREEN}${BOLD}Aplicação PHP/Composer (${PKG_NAME}${PKG_VER:+ v$PKG_VER})${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
            add_role "Aplicação Web (${PKG_NAME}${PKG_VER:+ v$PKG_VER})"
            add_unique_item RESUMO_APPS_VERSOES "${PKG_NAME}:${PKG_VER:-Composer}"
            add_unique_item RESUMO_SITES_DETECTADOS "${PKG_NAME}${PKG_VER:+ v$PKG_VER}: ${APP_DIR}"
            FOUND_APPS=$((FOUND_APPS + 1))
        fi
    done < <(find "$base_dir" -maxdepth 3 -type f -name "composer.json" ! -path "*/vendor/*" ! -path "*/3rdparty/*" ! -path "*/apps/*" 2>/dev/null || true)

    # Descoberta de projetos Node.js (package.json) em diretórios de aplicação
    while IFS= read -r pkg_json; do
        [[ -f "$pkg_json" ]] || continue
        APP_DIR=$(dirname "$pkg_json")
        mark_app_audited "$APP_DIR" || continue
        NODE_APP_NAME=$(grep -m 1 -E '"name"\s*:' "$pkg_json" 2>/dev/null | cut -d'"' -f4 || true)
        NODE_APP_VER=$(grep -m 1 -E '"version"\s*:' "$pkg_json" 2>/dev/null | cut -d'"' -f4 || true)
        if [[ -n "$NODE_APP_NAME" ]]; then
            echo -e "    • ${FG_GREEN}${BOLD}Aplicação Node.js (${NODE_APP_NAME}${NODE_APP_VER:+ v$NODE_APP_VER})${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
            add_role "App Node.js (${NODE_APP_NAME}${NODE_APP_VER:+ v$NODE_APP_VER})"
            add_unique_item RESUMO_APPS_VERSOES "${NODE_APP_NAME}:${NODE_APP_VER:-Node}"
            add_unique_item RESUMO_SITES_DETECTADOS "Node.js ${NODE_APP_NAME}${NODE_APP_VER:+ v$NODE_APP_VER}: ${APP_DIR}"
            FOUND_APPS=$((FOUND_APPS + 1))
        fi
    done < <(find "$base_dir" -maxdepth 3 -type f -name "package.json" ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/.git/*" 2>/dev/null || true)

    # Descoberta de projetos Python (pyproject.toml / requirements.txt / manage.py)
    while IFS= read -r py_marker; do
        [[ -f "$py_marker" ]] || continue
        APP_DIR=$(dirname "$py_marker")
        mark_app_audited "$APP_DIR" || continue
        PY_APP_NAME=$(basename "$APP_DIR")
        PY_APP_VER=""
        if [[ "$(basename "$py_marker")" == "pyproject.toml" ]]; then
            P_NAME=$(awk -F'=' '/^[ \t]*name[ \t]*=/ {gsub(/^[ \t"'\'']+|[ \t"'\''\r]+$/,"",$2); print $2; exit}' "$py_marker" 2>/dev/null || true)
            P_VER=$(awk -F'=' '/^[ \t]*version[ \t]*=/ {gsub(/^[ \t"'\'']+|[ \t"'\''\r]+$/,"",$2); print $2; exit}' "$py_marker" 2>/dev/null || true)
            [[ -n "$P_NAME" ]] && PY_APP_NAME="$P_NAME"
            [[ -n "$P_VER" ]] && PY_APP_VER="$P_VER"
        fi
        PY_KIND="Python"
        [[ -f "${APP_DIR}/manage.py" ]] && PY_KIND="Python/Django"
        echo -e "    • ${FG_GREEN}${BOLD}Aplicação ${PY_KIND} (${PY_APP_NAME}${PY_APP_VER:+ v$PY_APP_VER})${NC} -> Caminho: ${FG_CYAN}${APP_DIR}${NC}"
        add_role "App ${PY_KIND} (${PY_APP_NAME})"
        add_unique_item RESUMO_APPS_VERSOES "${PY_APP_NAME}:${PY_APP_VER:-Python}"
        add_unique_item RESUMO_SITES_DETECTADOS "${PY_KIND} (${PY_APP_NAME}): ${APP_DIR}"
        FOUND_APPS=$((FOUND_APPS + 1))
    done < <(find "$base_dir" -maxdepth 3 -type f \( -name "pyproject.toml" -o -name "requirements.txt" -o -name "manage.py" \) ! -path "*/venv/*" ! -path "*/.venv/*" ! -path "*/site-packages/*" ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null || true)
    done
fi

(( FOUND_APPS == 0 )) && echo -e "    • Nenhum CMS/Aplicação web conhecida detectada em /var/www, /srv, /opt ou /home."

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

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        COMPOSE_STACKS=$(timeout 4 docker compose ls 2>/dev/null || true)
        if [[ -n "$COMPOSE_STACKS" ]] && (( $(echo "$COMPOSE_STACKS" | wc -l) > 1 )); then
            echo -e "\n    ${BOLD}Stacks Docker Compose Detectadas:${NC}"
            echo "$COMPOSE_STACKS" | awk '{print "      " $0}'
        fi
    fi

    STOPPED_CT=$($CONTAINER_ENGINE ps -a --filter "status=exited" --format "{{.Names}} ({{.Image}})" 2>/dev/null | trim_ws || true)
    [[ -n "$STOPPED_CT" ]] && echo -e "\n      • ${BOLD}Contêineres Parados:${NC} ${DIM}${STOPPED_CT}${NC}"

    RUNNING_IDS=$($CONTAINER_ENGINE ps -q 2>/dev/null || true)
    if [[ -n "$RUNNING_IDS" ]]; then
        echo -e "\n    ${BOLD}${FG_CYAN}Inspeção Interna Passiva dos Contêineres Ativos (OS, PHP, Web, Bancos e CMSs):${NC}"
        while IFS= read -r cid; do
            [[ -z "$cid" ]] && continue
            CT_NAME=$($CONTAINER_ENGINE inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||' || echo "$cid")
            CT_IMAGE=$($CONTAINER_ENGINE inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null || echo "N/A")
            CT_STATUS=$($CONTAINER_ENGINE inspect --format '{{.State.Status}}' "$cid" 2>/dev/null || echo "running")
            CT_RESTARTS=$($CONTAINER_ENGINE inspect --format '{{.RestartCount}}' "$cid" 2>/dev/null || echo "0")
            CT_COMPOSE_DIR=$($CONTAINER_ENGINE inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$cid" 2>/dev/null || true)
            CT_MOUNTS=$($CONTAINER_ENGINE inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$cid" 2>/dev/null | trim_ws || true)
            CT_PORTS_RAW=$($CONTAINER_ENGINE port "$cid" 2>/dev/null || true)
            CT_PORTS=$(echo "$CT_PORTS_RAW" | tr '\n' '; ' | sed 's/; $//' || true)

            if [[ -n "$CT_PORTS_RAW" ]]; then
                while IFS= read -r cp_line; do
                    if [[ "$cp_line" == *"0.0.0.0:"* || "$cp_line" == *"[::]:"* ]]; then
                        add_unique_item DOCKER_PUBLIC_PORTS "${CT_NAME}: ${cp_line}"
                    fi
                done <<< "$CT_PORTS_RAW"
            fi

            if [[ "$CT_STATUS" == "restarting" ]] || { [[ "$CT_RESTARTS" =~ ^[0-9]+$ ]] && (( CT_RESTARTS > 3 )); }; then
                add_alert "Container '${CT_NAME}' com instabilidade detectada (Estado: ${CT_STATUS} | Reinicializações: ${CT_RESTARTS})."
            fi

            CT_HEALTH_TAG="Estado: ${CT_STATUS} | Restarts: ${CT_RESTARTS}"
            if [[ "$CT_RESTARTS" =~ ^[0-9]+$ ]] && (( CT_RESTARTS > 3 )); then
                CT_HEALTH_TAG="Estado: ${CT_STATUS} | ${FG_RED}${BOLD}Restarts: ${CT_RESTARTS}${NC}"
            fi

            echo -e "      ${FG_CYAN}${BOLD}▸ Container: ${CT_NAME}${NC} (${DIM}ID: ${cid} | Imagem: ${CT_IMAGE}${NC} | ${CT_HEALTH_TAG})"
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

                for wdir in /var/www/html /var/www /app /usr/share/nginx/html /srv /bitnami/mediawiki /opt/bitnami/mediawiki; do
                    [ -d "$wdir" ] || continue
                    for jv in "$wdir"/libraries/src/Version.php "$wdir"/*/libraries/src/Version.php; do
                        if [ -f "$jv" ]; then
                            j_d=$(dirname "$(dirname "$(dirname "$jv")")")
                            j_maj=$(grep -E "const[[:space:]]+MAJOR_VERSION|public[[:space:]]+\\\$RELEASE" "$jv" 2>/dev/null | head -n 1 | awk "{print \$NF}" | tr -d ";\"\047")
                            j_min=$(grep -E "const[[:space:]]+MINOR_VERSION|public[[:space:]]+\\\$DEV_LEVEL" "$jv" 2>/dev/null | head -n 1 | awk "{print \$NF}" | tr -d ";\"\047")
                            j_pat=$(grep -E "const[[:space:]]+PATCH_VERSION|public[[:space:]]+\\\$BUILD" "$jv" 2>/dev/null | head -n 1 | awk "{print \$NF}" | tr -d ";\"\047")
                            j_vs=""
                            [ -n "$j_maj" ] && j_vs="${j_maj}.${j_min:-0}${j_pat:+.${j_pat}}"
                            echo "APP|Joomla${j_vs:+ v$j_vs}|${j_d}"
                        fi
                    done
                    for wpv in "$wdir"/wp-includes/version.php "$wdir"/*/wp-includes/version.php; do
                        if [ -f "$wpv" ]; then
                            wp_d=$(dirname "$(dirname "$wpv")")
                            wp_vs=$(grep "^\$wp_version[[:space:]]*=" "$wpv" 2>/dev/null | awk -F"=" "{print \$2}" | tr -d " ;\"\047")
                            echo "APP|WordPress${wp_vs:+ v$wp_vs}|${wp_d}"
                        fi
                    done
                    for art in "$wdir"/artisan "$wdir"/*/artisan; do
                        if [ -f "$art" ]; then
                            lv_d=$(dirname "$art")
                            lv_vs=""
                            if [ -r "${lv_d}/composer.lock" ]; then
                                lv_vs=$(awk "/\"name\"[ \t]*:[ \t]*\"laravel\/framework\"/ {f=1} f && /\"version\"[ \t]*:/ {gsub(/.*\"version\"[ \t]*:[ \t]*\"|\".*/, \"\"); sub(/^[vV]/, \"\"); print; exit}" "${lv_d}/composer.lock" 2>/dev/null)
                            fi
                            echo "APP|Laravel${lv_vs:+ v$lv_vs}|${lv_d}"
                        fi
                    done
                    for mwd in "$wdir"/includes/Defines.php "$wdir"/*/includes/Defines.php; do
                        if [ -f "$mwd" ] && grep -q "MW_VERSION" "$mwd" 2>/dev/null; then
                            mw_d=$(dirname "$(dirname "$mwd")")
                            mw_vs=$(grep "MW_VERSION" "$mwd" 2>/dev/null | head -n 1 | sed -E "s/.*MW_VERSION[^,]*,[[:space:]]*[\"\047]([^\"\047]+)[\"\047].*/\1/")
                            echo "APP|MediaWiki${mw_vs:+ v$mw_vs}|${mw_d}"
                        fi
                    done
                    for glp in "$wdir"/inc/define.php "$wdir"/*/inc/define.php; do
                        if [ -f "$glp" ] && grep -q "GLPI_VERSION" "$glp" 2>/dev/null; then
                            gl_d=$(dirname "$(dirname "$glp")")
                            gl_vs=$(grep "GLPI_VERSION" "$glp" 2>/dev/null | head -n 1 | awk -F"," "{print \$2}" | tr -d " );\"\047")
                            echo "APP|GLPI${gl_vs:+ v$gl_vs}|${gl_d}"
                        fi
                    done
                    for dkw in "$wdir"/doku.php "$wdir"/*/doku.php; do
                        if [ -f "$dkw" ]; then
                            dk_d=$(dirname "$dkw")
                            dk_vs=""
                            [ -r "${dk_d}/VERSION" ] && dk_vs=$(head -n 1 "${dk_d}/VERSION" 2>/dev/null)
                            echo "APP|DokuWiki${dk_vs:+ $dk_vs}|${dk_d}"
                        fi
                    done
                    for ncv in "$wdir"/version.php "$wdir"/*/version.php; do
                        if [ -f "$ncv" ] && grep -q "\$OC_VersionString" "$ncv" 2>/dev/null; then
                            nc_d=$(dirname "$ncv")
                            nc_ver_s=$(grep "\$OC_VersionString" "$ncv" 2>/dev/null | awk -F"=" "{print \$2}" | tr -d " ;\"\047")
                            nc_dd=""
                            if [ -r "${nc_d}/config/config.php" ]; then
                                nc_dd=$(grep "datadirectory" "${nc_d}/config/config.php" 2>/dev/null | awk -F"=>" "{print \$2}" | tr -d " ,;\"\047")
                            fi
                            echo "APP|Nextcloud v${nc_ver_s:-Detectado}|${nc_d}${nc_dd:+ (Dados: $nc_dd)}"
                        elif [ -f "$ncv" ] && grep -q "MOODLE_INTERNAL" "$ncv" 2>/dev/null; then
                            md_d=$(dirname "$ncv")
                            md_vs=$(grep "^\$release[[:space:]]*=" "$ncv" 2>/dev/null | awk -F"=" "{print \$2}" | tr -d " ;\"\047")
                            echo "APP|Moodle${md_vs:+ v$md_vs}|${md_d}"
                        fi
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
                            add_unique_item RESUMO_APPS_VERSOES "Container(${CT_NAME}):${p_k}"
                            CT_ROLES_SUMMARY="${CT_ROLES_SUMMARY:+${CT_ROLES_SUMMARY}, }${p_k}"
                            if [[ "$p_k" =~ ^MediaWiki[[:space:]]+v1\.([0-9]+) ]]; then
                                ct_mw_min="${BASH_REMATCH[1]}"
                                (( ct_mw_min < 39 || ct_mw_min == 40 || ct_mw_min == 41 )) && add_alert "Container '${CT_NAME}' executa ${p_k} em versão End-of-Life."
                            elif [[ "$p_k" =~ ^Joomla[[:space:]]+v[1-4]\. ]]; then
                                add_alert "Container '${CT_NAME}' executa ${p_k} em ramo legado/End-of-Life."
                            elif [[ "$p_k" =~ ^WordPress[[:space:]]+v[1-5]\. ]]; then
                                add_alert "Container '${CT_NAME}' executa ${p_k} em ramo legado (< 6.x)."
                            elif [[ "$p_k" =~ ^GLPI[[:space:]]+v[0-9]\. ]]; then
                                add_alert "Container '${CT_NAME}' executa ${p_k} em versão End-of-Life (< 10.x)."
                            fi
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

_get_pkg_ver() {
    local pkg="$1" v=""
    if command -v dpkg-query >/dev/null 2>&1; then
        v=$(dpkg-query -W -f='${Version}\n' "$pkg" 2>/dev/null | head -n 1 | sed 's/^[0-9]*://; s/-.*//' || true)
    fi
    if [[ -z "$v" ]] && command -v rpm >/dev/null 2>&1; then
        v=$(rpm -q --qf '%{VERSION}\n' "$pkg" 2>/dev/null | grep -v "not installed" | head -n 1 || true)
    fi
    printf '%s' "$v"
}

get_daemon_version() {
    local svc="$1" ver="" cand_bin="" cand_pkg="" exec_bin="" real_exec="" owner_pkg=""
    case "$svc" in
        cloudflared)
            ver=$(cloudflared --version 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="version") {print $(i+1); exit}}' || true)
            ;;
        postfix)
            ver=$(postconf -h mail_version 2>/dev/null || true)
            ;;
        fail2ban|fail2ban-server)
            ver=$(fail2ban-client --version 2>/dev/null | head -n 1 | awk '{print $NF}' || true)
            ;;
        named|bind9)
            ver=$(named -v 2>/dev/null | awk '{print $2}' || true)
            ;;
        dnsmasq)
            ver=$(dnsmasq -v 2>/dev/null | head -n 1 | awk '{print $3}' || true)
            ;;
        dovecot)
            ver=$(dovecot --version 2>/dev/null | awk '{print $1}' || true)
            ;;
        tailscaled)
            ver=$(tailscale --version 2>/dev/null | head -n 1 || true)
            ;;
        openvpn)
            ver=$(openvpn --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)
            ;;
        ssh|sshd)
            cand_bin=$(command -v sshd 2>/dev/null || echo "/usr/sbin/sshd")
            if [[ -x "$cand_bin" ]]; then
                ver=$(timeout 2 "$cand_bin" -V 2>&1 | grep -oE 'OpenSSH_[0-9]+\.[0-9]+([a-zA-Z0-9.]+)?' | head -n 1 | sed 's/^OpenSSH_//' || true)
            fi
            [[ -z "$ver" ]] && ver=$(_get_pkg_ver "openssh-server")
            ;;
        zabbix-proxy)
            for cand_bin in "$(command -v zabbix_proxy 2>/dev/null || true)" /usr/sbin/zabbix_proxy /usr/local/sbin/zabbix_proxy; do
                if [[ -n "$cand_bin" && -x "$cand_bin" ]]; then
                    ver=$(timeout 2 "$cand_bin" -V </dev/null 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9a-zA-Z_.-]+)?' | head -n 1 || true)
                    [[ -n "$ver" ]] && break
                fi
            done
            if [[ -z "$ver" ]]; then
                for cand_pkg in zabbix-proxy-sqlite3 zabbix-proxy-mysql zabbix-proxy-pgsql zabbix-proxy; do
                    ver=$(_get_pkg_ver "$cand_pkg")
                    [[ -n "$ver" ]] && break
                done
            fi
            ;;
        zabbix-server)
            for cand_bin in "$(command -v zabbix_server 2>/dev/null || true)" /usr/sbin/zabbix_server /usr/local/sbin/zabbix_server; do
                if [[ -n "$cand_bin" && -x "$cand_bin" ]]; then
                    ver=$(timeout 2 "$cand_bin" -V </dev/null 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9a-zA-Z_.-]+)?' | head -n 1 || true)
                    [[ -n "$ver" ]] && break
                fi
            done
            if [[ -z "$ver" ]]; then
                for cand_pkg in zabbix-server-mysql zabbix-server-pgsql zabbix-server; do
                    ver=$(_get_pkg_ver "$cand_pkg")
                    [[ -n "$ver" ]] && break
                done
            fi
            ;;
        zabbix-agent)
            for cand_bin in "$(command -v zabbix_agentd 2>/dev/null || true)" /usr/sbin/zabbix_agentd /usr/local/sbin/zabbix_agentd; do
                if [[ -n "$cand_bin" && -x "$cand_bin" ]]; then
                    ver=$(timeout 2 "$cand_bin" -V </dev/null 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9a-zA-Z_.-]+)?' | head -n 1 || true)
                    [[ -n "$ver" ]] && break
                fi
            done
            ;;
        zabbix-agent2)
            for cand_bin in "$(command -v zabbix_agent2 2>/dev/null || true)" /usr/sbin/zabbix_agent2 /usr/local/sbin/zabbix_agent2; do
                if [[ -n "$cand_bin" && -x "$cand_bin" ]]; then
                    ver=$(timeout 2 "$cand_bin" -V </dev/null 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9a-zA-Z_.-]+)?' | head -n 1 || true)
                    [[ -n "$ver" ]] && break
                fi
            done
            ;;
        zabbix-java-gateway)
            ver=$(_get_pkg_ver "zabbix-java-gateway")
            ;;
    esac
    [[ -z "$ver" ]] && ver=$(_get_pkg_ver "$svc")
    if [[ -z "$ver" ]] && command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        exec_bin=$(systemctl show "${svc}.service" -p ExecStart --value 2>/dev/null | sed -n 's/.*path=\([^ ;]*\).*/\1/p' | head -n 1 || true)
        if [[ -z "$exec_bin" ]]; then
            exec_bin=$(systemctl show "${svc}.service" -p ExecStart --value 2>/dev/null | awk '{print $1}' | sed 's/^[-@!+]*//' || true)
        fi
        if [[ -n "$exec_bin" && -e "$exec_bin" ]]; then
            if command -v dpkg-query >/dev/null 2>&1; then
                owner_pkg=$(dpkg-query -S "$exec_bin" 2>/dev/null | grep -v '^diversion ' | head -n 1 | sed 's/:[[:space:]].*//; s/,.*//' || true)
                if [[ -z "$owner_pkg" ]]; then
                    real_exec=$(readlink -f "$exec_bin" 2>/dev/null || true)
                    [[ -n "$real_exec" ]] && owner_pkg=$(dpkg-query -S "$real_exec" 2>/dev/null | grep -v '^diversion ' | head -n 1 | sed 's/:[[:space:]].*//; s/,.*//' || true)
                fi
                [[ -n "$owner_pkg" ]] && ver=$(_get_pkg_ver "$owner_pkg")
            fi
            if [[ -z "$ver" ]] && command -v rpm >/dev/null 2>&1; then
                ver=$(rpm -qf --qf '%{VERSION}\n' "$exec_bin" 2>/dev/null | grep -v "not installed" | head -n 1 || true)
            fi
        fi
    fi
    if [[ -z "$ver" ]] && command -v "$svc" >/dev/null 2>&1; then
        ver=$(timeout 2 "$svc" --version </dev/null 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9a-zA-Z_-]+)?' | head -n 1 || true)
    fi
    ver="${ver#[vV]}"
    printf '%s' "${ver:-}"
}

check_infra_service() {
    local svc="$1" label="$2" role_tag="$3"
    if [[ "$(get_service_status_plain "$svc")" != "Não instalado" ]] || pgrep -x "$svc" >/dev/null 2>&1; then
        INFRA_FOUND=$((INFRA_FOUND + 1))
        local st d_ver
        st=$(get_service_status "$svc")
        d_ver=$(get_daemon_version "$svc")
        echo -e "    • ${BOLD}${label}${NC} (${svc}${d_ver:+ v${d_ver}}): [${st}]"
        if [[ "$(get_service_status_plain "$svc")" == "Ativo" ]] || pgrep -x "$svc" >/dev/null 2>&1; then
            add_role "${role_tag}${d_ver:+ (${d_ver})}"
            add_unique_item RESUMO_APPS_VERSOES "${svc}:${d_ver:-Ativo}"
        fi
    fi
}

check_infra_service "cloudflared"          "Conector Cloudflare Tunnel (cloudflared)"   "Conector Cloudflare Tunnel"
for cf_cfg in /etc/cloudflared/config.yml /etc/cloudflared/config.yaml; do
    [[ -r "$cf_cfg" ]] || continue
    CF_INGRESS=$(awk '
        /^[ \t]*-?[ \t]*hostname:/ {
            h=$0; sub(/.*hostname:[ \t]*/, "", h); gsub(/["'\''\r ]/, "", h)
        }
        /^[ \t]*service:/ {
            s=$0; sub(/.*service:[ \t]*/, "", s); gsub(/["'\''\r ]/, "", s)
            if (h != "") { print h " -> " s; h="" } else if (s ~ /^http_status:/) { print "(fallback) -> " s }
        }
    ' "$cf_cfg" 2>/dev/null || true)
    if [[ -n "$CF_INGRESS" ]]; then
        echo -e "      └─ ${BOLD}Rotas Cloudflare Tunnel (${cf_cfg}):${NC}"
        while IFS= read -r cf_route; do
            [[ -n "$cf_route" ]] && echo -e "         ├─ ${FG_CYAN}${cf_route}${NC}"
        done <<< "$CF_INGRESS"
    fi
done
check_infra_service "ngrok"                "Túnel Reverso Ngrok"                        "Túnel Ngrok"
check_infra_service "frpc"                 "Cliente Proxy Reverso FRP (frpc)"           "Túnel FRP Client"
check_infra_service "frps"                 "Servidor Proxy Reverso FRP (frps)"          "Servidor FRP"
check_infra_service "zerotier-one"         "Rede SD-WAN ZeroTier"                       "VPN ZeroTier"
check_infra_service "netbird"              "Rede Mesh VPN NetBird"                      "VPN NetBird"
check_infra_service "named"                "Servidor DNS BIND9 (named)"                 "Servidor DNS (BIND9)"
check_infra_service "bind9"                "Servidor DNS BIND9"                         "Servidor DNS (BIND9)"
check_infra_service "unbound"              "Servidor DNS Unbound"                       "Servidor DNS (Unbound)"
check_infra_service "dnsmasq"              "Servidor DNS/DHCP Dnsmasq"                  "DNS/DHCP (Dnsmasq)"
check_infra_service "pihole-FTL"           "Servidor DNS / Bloqueador Pi-hole"          "Servidor DNS (Pi-hole)"
check_infra_service "AdGuardHome"          "Servidor DNS / Filtro AdGuard Home"         "Servidor DNS (AdGuardHome)"
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
if [[ -r /etc/zabbix/zabbix_proxy.conf ]] && { [[ "$(get_service_status_plain zabbix-proxy)" != "Não instalado" ]] || pgrep -x zabbix_proxy >/dev/null 2>&1; }; then
    ZP_MODE_RAW=$(awk -F'=' '/^[ \t]*ProxyMode[ \t]*=/ {gsub(/[ \t\r]/,"",$2); print $2}' /etc/zabbix/zabbix_proxy.conf 2>/dev/null | tail -n 1 || true)
    ZP_MODE_TXT="Ativo (0 - Padrão)"
    [[ "$ZP_MODE_RAW" == "1" ]] && ZP_MODE_TXT="Passivo (1)"
    ZP_SERVER=$(awk -F'=' '/^[ \t]*Server[ \t]*=/ {gsub(/[ \t\r]/,"",$2); print $2}' /etc/zabbix/zabbix_proxy.conf 2>/dev/null | tail -n 1 || true)
    ZP_HOSTNAME=$(awk -F'=' '/^[ \t]*Hostname[ \t]*=/ {gsub(/^[ \t]+|[ \t\r]+$/,"",$2); print $2}' /etc/zabbix/zabbix_proxy.conf 2>/dev/null | tail -n 1 || true)
    ZP_DBNAME=$(awk -F'=' '/^[ \t]*DBName[ \t]*=/ {gsub(/^[ \t]+|[ \t\r]+$/,"",$2); print $2}' /etc/zabbix/zabbix_proxy.conf 2>/dev/null | tail -n 1 || true)
    echo -e "      └─ ${BOLD}Config Zabbix Proxy:${NC} Modo: ${FG_CYAN}${ZP_MODE_TXT}${NC}${ZP_HOSTNAME:+ | Hostname: ${FG_YELLOW}${ZP_HOSTNAME}${NC}}${ZP_SERVER:+ | Server: ${FG_GREEN}${ZP_SERVER}${NC}}${ZP_DBNAME:+ | DB: ${DIM}${ZP_DBNAME}${NC}}"
    if [[ -n "$ZP_DBNAME" && "$ZP_DBNAME" == /* && -f "$ZP_DBNAME" ]]; then
        add_unique_item SQLITE_DBS_FOUND "${ZP_DBNAME} (Zabbix Proxy)"
    fi
fi
check_infra_service "zabbix-agent2"        "Agente de Monitoramento Zabbix Agent 2"     "Monitorado (Zabbix Agent 2)"
check_infra_service "zabbix-agent"         "Agente de Monitoramento Zabbix Agent"       "Monitorado (Zabbix Agent)"
check_infra_service "snmpd"                "Agente SNMP (snmpd)"                        "Agente SNMP"
check_infra_service "prometheus"           "Servidor de Métricas Prometheus"            "Monitoramento (Prometheus)"
check_infra_service "grafana-server"       "Painel de Observabilidade Grafana"          "Dashboards (Grafana)"
check_infra_service "wazuh-agent"          "Agente SIEM/EDR Wazuh"                      "Monitorado (Wazuh Agent)"
check_infra_service "crowdsec"             "Motor IPS Colaborativo CrowdSec"            "IPS CrowdSec"
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
check_infra_service "gitea"                "Servidor Git Gitea"                         "Servidor Git (Gitea)"
check_infra_service "jenkins"              "Servidor CI/CD Jenkins"                     "Servidor CI/CD (Jenkins)"
check_infra_service "syncthing"            "Sincronização de Arquivos Syncthing"        "Sincronização (Syncthing)"
check_infra_service "minio"                "Object Storage S3 MinIO"                    "Storage S3 (MinIO)"
check_infra_service "plexmediaserver"      "Servidor de Mídia Plex"                     "Media Server (Plex)"
check_infra_service "jellyfin"             "Servidor de Mídia Jellyfin"                 "Media Server (Jellyfin)"
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
    while IFS='|' read -r svc_unit svc_desc; do
        [[ -z "$svc_unit" ]] && continue
        svc_base="${svc_unit%.service}"
        svc_ver=$(get_daemon_version "$svc_base")
        echo -e "      • ${FG_GREEN}${BOLD}${svc_unit}${NC}${svc_ver:+ (${FG_YELLOW}v${svc_ver}${NC})} — ${DIM}${svc_desc}${NC}"
        if [[ ! "$svc_base" =~ ^(ssh|sshd|apache2|httpd|nginx|mariadb|mysql|mysqld|postgresql|redis|redis-server|docker|containerd|ufw|firewalld|nftables|php[0-9.]*-fpm|open-vm-tools|vmtoolsd|vgauth|VGAuthService|qemu-guest-agent)$ ]]; then
            add_unique_item RESUMO_APPS_VERSOES "${svc_base}:${svc_ver:-Ativo}"
        fi
    done < <(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | grep -vE "^(systemd-|user@|user-runtime-dir@|getty@|serial-getty@|container-getty@|console-getty|dbus\.service|polkit\.service|polkitd\.service|rsyslog\.service|syslog\.service|cron\.service|crond\.service|atd\.service|acpid\.service|iscsid\.service|lvm2-|lxcfs\.service|mdadm\.service|rc-local\.service|snapd\.service|apparmor\.service|auditd\.service|blk-availability\.service|ondemand\.service|cgmanager\.service|udev|kmod|multipathd|accounts-daemon|udisks2|upower|networkd-dispatcher|ModemManager|wpa_supplicant|avahi-daemon|bluetooth|colord|rtkit-daemon|switcheroo-control|thermald|power-profiles-daemon|irqbalance|packagekit|unattended-upgrades|wsl-pro|networking\.service|ifup@)" | awk '{
        unit=$1; $1=""; $2=""; $3=""; $4="";
        sub(/^[ \t]+/, "", $0);
        print unit "|" $0
    }' || true)

    # Unidades Systemd customizadas criadas localmente em /etc/systemd/system/*.service (mesmo se paradas/oneshot)
    CUSTOM_UNIT_COUNT=0
    for cu_file in /etc/systemd/system/*.service; do
        [[ -f "$cu_file" && ! -L "$cu_file" ]] || continue
        cu_name=$(basename "$cu_file")
        cu_state=$(get_service_status "${cu_name%.service}")
        cu_enabled=$(systemctl is-enabled "$cu_name" 2>/dev/null || echo "static")
        cu_exec=$(awk -F'=' '/^[ \t]*ExecStart[ \t]*=/ {sub(/^[^=]+=/,""); print; exit}' "$cu_file" 2>/dev/null | trim_ws || true)
        CUSTOM_UNIT_COUNT=$((CUSTOM_UNIT_COUNT + 1))
        (( CUSTOM_UNIT_COUNT == 1 )) && echo -e "\n    ${BOLD}Serviços Systemd Customizados (/etc/systemd/system/*.service — Inclui Parados/Oneshot):${NC}"
        echo -e "      • ${FG_CYAN}${BOLD}${cu_name}${NC} [${cu_state} | Boot: ${FG_YELLOW}${cu_enabled}${NC}]${cu_exec:+ -> ${DIM}${cu_exec:0:95}${NC}}"
        add_unique_item CUSTOM_SYSTEMD_UNITS "${cu_name} (${cu_enabled}${cu_exec:+: ${cu_exec:0:80}})"
    done
fi

# Gerenciadores de processos fora do Systemd (Supervisor e PM2 — leitura 100% passiva)
if [[ -d /etc/supervisor/conf.d || -d /etc/supervisord.d ]] || pgrep -x supervisord >/dev/null 2>&1; then
    echo -e "\n    ${BOLD}Supervisor (Programas Gerenciados):${NC}"
    if pgrep -x supervisord >/dev/null 2>&1 && command -v supervisorctl >/dev/null 2>&1; then
        timeout 3 supervisorctl status 2>/dev/null | awk '{print "      • " $0}' || true
    fi
    for sup_f in /etc/supervisor/conf.d/*.conf /etc/supervisord.d/*.ini /etc/supervisord.d/*.conf; do
        [[ -r "$sup_f" ]] || continue
        SUP_PROGS=$(awk '
            /^\[program:/ { sub(/^\[program:/,""); sub(/\].*/,""); prog=$0; cmd=""; dir="" }
            /^[ \t]*command[ \t]*=/ { sub(/^[^=]+=[ \t]*/,""); cmd=$0 }
            /^[ \t]*directory[ \t]*=/ { sub(/^[^=]+=[ \t]*/,""); dir=$0 }
            prog != "" && cmd != "" { print prog " -> " cmd (dir ? " (dir: " dir ")" : ""); prog=""; cmd=""; dir="" }
        ' "$sup_f" 2>/dev/null || true)
        if [[ -n "$SUP_PROGS" ]]; then
            while IFS= read -r sp_l; do
                [[ -n "$sp_l" ]] && echo -e "      ├─ [${FG_CYAN}$(basename "$sup_f")${NC}] ${FG_YELLOW}${sp_l}${NC}"
            done <<< "$SUP_PROGS"
        fi
    done
fi

PM2_PROCS=$(pgrep -fa "PM2" 2>/dev/null | grep -v "grep" || true)
PM2_DUMPS=()
for pm2_d in /root/.pm2/dump.pm2 /home/*/.pm2/dump.pm2; do
    [[ -r "$pm2_d" ]] && PM2_DUMPS+=("$pm2_d")
done
if [[ -n "$PM2_PROCS" ]] || (( ${#PM2_DUMPS[@]} > 0 )); then
    echo -e "\n    ${BOLD}PM2 (Gerenciador de Processos Node.js — Inspeção Passiva):${NC}"
    [[ -n "$PM2_PROCS" ]] && echo -e "      • ${FG_GREEN}Daemon PM2 em execução${NC}"
    if (( ${#PM2_DUMPS[@]} > 0 )); then
        for pd_file in "${PM2_DUMPS[@]}"; do
            PM2_APPS=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"|"pm_exec_path"[[:space:]]*:[[:space:]]*"[^"]+"' "$pd_file" 2>/dev/null | paste - - 2>/dev/null | sed -E 's/"name"[[:space:]]*:[[:space:]]*"([^"]+)"[[:space:]]*"pm_exec_path"[[:space:]]*:[[:space:]]*"([^"]+)"/\1 -> \2/' || true)
            if [[ -n "$PM2_APPS" ]]; then
                while IFS= read -r pma; do
                    [[ -n "$pma" ]] && echo -e "      ├─ [${DIM}${pd_file}${NC}] ${FG_CYAN}${pma}${NC}"
                done <<< "$PM2_APPS"
            else
                echo -e "      ├─ Dump localizado: ${DIM}${pd_file}${NC}"
            fi
        done
    fi
fi

# 4.7 - Inventário de Migração (Repositórios de Terceiros, Snaps/Flatpaks, Pacotes Manuais e Binários Locais)
echo -e "\n  ${BOLD}4.7 Inventário de Migração (Repositórios Externos, Snaps, Pacotes Manuais e Binários Locais):${NC}"

# 4.7.1 - Repositórios de Terceiros (APT / DNF / YUM)
REPO_3P_COUNT=0
if [[ -d /etc/apt/sources.list.d ]]; then
    for rf in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -r "$rf" ]] || continue
        rf_base=$(basename "$rf")
        [[ "$rf_base" == "ubuntu.sources" || "$rf_base" == "debian.sources" ]] && continue
        rf_uris=$(grep -vE '^[ \t]*#|^[ \t]*$' "$rf" 2>/dev/null | grep -oE 'https?://[^[:space:]]+' | sort -u | head -n 2 | tr '\n' ' ' | trim_ws || true)
        if [[ -n "$rf_uris" ]]; then
            REPO_3P_COUNT=$((REPO_3P_COUNT + 1))
            (( REPO_3P_COUNT == 1 )) && echo -e "    • ${BOLD}Repositórios APT de Terceiros (/etc/apt/sources.list.d):${NC}"
            echo -e "      ├─ ${FG_CYAN}${rf_base}${NC}: ${DIM}${rf_uris}${NC}"
            add_unique_item REPOS_TERCEIROS "${rf_base}: ${rf_uris}"
        fi
    done
elif [[ -d /etc/yum.repos.d ]]; then
    for rf in /etc/yum.repos.d/*.repo; do
        [[ -r "$rf" ]] || continue
        rf_base=$(basename "$rf")
        if grep -qiE '^[ \t]*enabled[ \t]*=[ \t]*1' "$rf" 2>/dev/null; then
            rf_uris=$(grep -iE '^[ \t]*(baseurl|mirrorlist|metalink)[ \t]*=' "$rf" 2>/dev/null | head -n 2 | cut -d'=' -f2- | tr '\n' ' ' | trim_ws || true)
            REPO_3P_COUNT=$((REPO_3P_COUNT + 1))
            (( REPO_3P_COUNT == 1 )) && echo -e "    • ${BOLD}Repositórios YUM/DNF Ativos (/etc/yum.repos.d):${NC}"
            echo -e "      ├─ ${FG_CYAN}${rf_base}${NC}: ${DIM}${rf_uris:-Ativo}${NC}"
            add_unique_item REPOS_TERCEIROS "${rf_base}: ${rf_uris:-Ativo}"
        fi
    done
fi
(( REPO_3P_COUNT == 0 )) && echo -e "    • Repositórios de Terceiros: Nenhum repositório externo adicional detectado."

# 4.7.2 - Pacotes Snap e Flatpak
if command -v snap >/dev/null 2>&1; then
    SNAP_LIST=$(timeout 4 snap list 2>/dev/null | awk 'NR>1 {print $1 "|" $2 "|" $4}' || true)
    if [[ -n "$SNAP_LIST" ]]; then
        echo -e "    • ${BOLD}Pacotes Snap Instalados:${NC}"
        while IFS='|' read -r sn_name sn_ver sn_track; do
            [[ -z "$sn_name" ]] && continue
            echo -e "      ├─ ${FG_CYAN}${sn_name}${NC} (${FG_YELLOW}v${sn_ver}${NC} | Canal: ${DIM}${sn_track}${NC})"
            if [[ ! "$sn_name" =~ ^(bare|core|core[0-9]+|snapd|lxd)$ ]]; then
                add_unique_item RESUMO_APPS_VERSOES "Snap-${sn_name}:${sn_ver}"
            fi
        done <<< "$SNAP_LIST"
    fi
fi

if command -v flatpak >/dev/null 2>&1; then
    FP_LIST=$(timeout 4 flatpak list --app --columns=name,application,version 2>/dev/null || true)
    if [[ -n "$FP_LIST" ]]; then
        echo -e "    • ${BOLD}Aplicações Flatpak Instaladas:${NC}"
        while IFS= read -r fp_l; do
            [[ -n "$fp_l" ]] && echo -e "      ├─ ${FG_CYAN}${fp_l}${NC}"
        done <<< "$FP_LIST"
    fi
fi

# 4.7.3 - Utilitários / Pacotes Instalados Manualmente (Visão de Migração)
if command -v apt-mark >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1; then
    MANUAL_ALL=$(apt-mark showmanual 2>/dev/null | sort -u || true)
    if [[ -n "$MANUAL_ALL" ]]; then
        MANUAL_TOTAL=$(echo "$MANUAL_ALL" | wc -l | trim_ws)
        MANUAL_FILTERED=$(echo "$MANUAL_ALL" | grep -vE '^(lib|linux-|ubuntu-|debian-|base-|bsd|coreutils|dash|bash|diffutils|dpkg|e2fs|findutils|gcc-|g\+\+|grep|gzip|hostname|init|iproute|iputils|kbd|kmod|locales|login|lsb-|mawk|mount|ncurses|netbase|passwd|perl|procps|sed|sensible-|systemd|sysv|tar|tzdata|udev|util-linux|vim-tiny|whiptail|zlib|fonts-|language-pack-|man-db|manpages|adduser|apt|ca-certificates|console-setup|cron|dbus|dmidecode|eject|fdisk|gnupg|gpg|grub-|hdparm|info|install-info|isc-dhcp-client|less|logrotate|lshw|lsof|nano|netplan|networkd-dispatcher|ntfs-3g|openssh-client|os-prober|parted|pciutils|plymouth|polkitd|psmisc|python3-minimal|readline-common|rsyslog|shim-signed|snapd|sudo|ufw|unattended-upgrades|usbutils|uuid-runtime|xdg-user-dirs|xkb-data|xxd)' | head -n 40 || true)
        if [[ -n "$MANUAL_FILTERED" ]]; then
            MANUAL_WITH_VER=""
            while IFS= read -r mp; do
                [[ -z "$mp" ]] && continue
                mp_v=$(_get_pkg_ver "$mp")
                MANUAL_WITH_VER="${MANUAL_WITH_VER:+${MANUAL_WITH_VER}, }${mp}${mp_v:+ (${mp_v})}"
            done <<< "$MANUAL_FILTERED"
            echo -e "    • ${BOLD}Pacotes Manuais Relevantes (APT — ${MANUAL_TOTAL} manuais no total, Top 40 utilitários/apps):${NC}"
            echo -e "      └─ ${DIM}${MANUAL_WITH_VER}${NC}"
        fi
    fi
elif command -v dnf >/dev/null 2>&1; then
    DNF_USER_PKGS=$(timeout 6 dnf repoquery --userinstalled --qf '%{name} (%{version})' 2>/dev/null | grep -vE '^(kernel|glibc|systemd|basesystem|filesystem|coreutils|bash|dnf|rpm|selinux|grub2|dracut|NetworkManager|openssh-clients|sudo|chrony|firewalld)' | head -n 40 | paste -sd ', ' - || true)
    if [[ -n "$DNF_USER_PKGS" ]]; then
        echo -e "    • ${BOLD}Pacotes Instalados pelo Usuário (DNF — Top 40):${NC}"
        echo -e "      └─ ${DIM}${DNF_USER_PKGS}${NC}"
    fi
fi

# 4.7.4 - Binários Executáveis Locais e JARs Instalados Manualmente (/usr/local/bin, /usr/local/sbin, /opt)
LOCAL_BINS=$(find /usr/local/bin /usr/local/sbin -maxdepth 2 -type f -executable ! -name "*.sh" ! -name "*.py" 2>/dev/null | sort -u | head -n 25 || true)
OPT_BINS=$(find /opt -maxdepth 2 -type f \( -executable -o -name "*.jar" \) ! -name "*.sh" ! -name "*.py" ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/venv/*" 2>/dev/null | sort -u | head -n 20 || true)
if [[ -n "$LOCAL_BINS" || -n "$OPT_BINS" ]]; then
    echo -e "    • ${BOLD}Binários Executáveis / JARs Instalados Manualmente (/usr/local/bin, /usr/local/sbin, /opt):${NC}"
    if [[ -n "$LOCAL_BINS" ]]; then
        while IFS= read -r lb; do
            [[ -z "$lb" ]] && continue
            lb_sz=$(du -h "$lb" 2>/dev/null | awk '{print $1}' || echo "N/A")
            echo -e "      ├─ ${FG_CYAN}${lb}${NC} (${DIM}${lb_sz}${NC})"
        done <<< "$LOCAL_BINS"
    fi
    if [[ -n "$OPT_BINS" ]]; then
        while IFS= read -r ob; do
            [[ -z "$ob" ]] && continue
            ob_sz=$(du -h "$ob" 2>/dev/null | awk '{print $1}' || echo "N/A")
            echo -e "      ├─ ${FG_YELLOW}${ob}${NC} (${DIM}${ob_sz}${NC})"
        done <<< "$OPT_BINS"
    fi
fi
return 0
}

# ==============================================================================
# SEÇÃO 5 - BANCOS DE DADOS (QUAIS, VERSÕES, CONFIGURAÇÕES E BASES EXISTENTES)
# ==============================================================================
secao_5_bancos() {
print_header "5. BANCOS DE DADOS (QUAIS, VERSÕES, DATADIR, TAMANHO E BASES EXISTENTES)"

DB_ANY_FOUND=0

# 5.1 - MariaDB / MySQL
if command -v mariadb >/dev/null 2>&1 || command -v mysql >/dev/null 2>&1 || [[ -d /var/lib/mysql ]]; then
    DB_ANY_FOUND=1
    DB_BIN=$(command -v mariadb || command -v mysql || echo "")
    DB_VER="Instalado"
    DB_SHORT_VER="Instalado"
    if [[ -n "$DB_BIN" ]]; then
        DB_VER=$($DB_BIN --version 2>/dev/null || echo "Instalado")
        DB_SHORT_VER=$(echo "$DB_VER" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-MariaDB)?' | head -n 1 || echo "$DB_VER")
    fi
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
    if [[ -d "$MYSQL_DATADIR" ]]; then
        MYSQL_SIZE=$(safe_du "$MYSQL_DATADIR")
        [[ -z "$MYSQL_SIZE" ]] && MYSQL_SIZE="Omitido (--fast)"
    fi
    MYSQL_BIND=$( (grep -RhE "^\s*bind-address\s*=" /etc/mysql/ /etc/my.cnf /etc/my.cnf.d/ 2>/dev/null || true) | tail -n 1 | cut -d'=' -f2 | trim_ws || true )
    [[ -z "$MYSQL_BIND" ]] && MYSQL_BIND="Padrão (127.0.0.1)"

    log_success "MySQL / MariaDB (${DB_SVC}): ${BOLD}${DB_SHORT_VER}${NC} ${DIM}(${DB_VER})${NC} [$(get_service_status "$DB_SVC")]"
    echo -e "    • ${BOLD}Configuração:${NC} Bind-Address: ${FG_CYAN}${MYSQL_BIND}${NC} | Datadir: ${MYSQL_DATADIR} (Tamanho em disco: ${FG_YELLOW}${MYSQL_SIZE}${NC})"
    add_unique_item RESUMO_APPS_VERSOES "${DB_SVC}:${DB_SHORT_VER}"

    if [[ "$(get_service_status_plain "$DB_SVC")" == "Ativo" ]]; then
        add_role "Banco de Dados (${DB_SVC} ${DB_SHORT_VER})"
        add_unique_item RESUMO_BANCOS_ATIVOS "Host-${DB_SVC} ${DB_SHORT_VER} (${MYSQL_SIZE})"
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

        MYSQL_USERS=$($DB_BIN --batch --skip-column-names -e "SELECT CONCAT(User, '@', Host) FROM mysql.user WHERE User NOT IN ('mariadb.sys','mysql.sys','mysql.session','mysql.infoschema') ORDER BY User;" 2>/dev/null | trim_ws || true)
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
        if [[ -d "$pg_dir" ]]; then
            PG_SIZE=$(safe_du "$pg_dir")
            [[ -z "$PG_SIZE" ]] && PG_SIZE="Omitido (--fast)"
            break
        fi
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

# 5.4 - Bancos de Dados SQLite Detectados (Infraestrutura e Aplicações)
for sqlite_cand in /var/lib/zabbix/*.db /var/lib/zabbix/*.sqlite /var/lib/grafana/grafana.db /etc/pihole/pihole-FTL.db; do
    [[ -f "$sqlite_cand" ]] && add_unique_item SQLITE_DBS_FOUND "${sqlite_cand} (Sistema/Daemon)"
done

if (( ${#SQLITE_DBS_FOUND[@]} > 0 )); then
    DB_ANY_FOUND=1
    echo -e "\n  ${BOLD}5.4 Bancos de Dados SQLite Identificados:${NC}"
    for sq_entry in "${SQLITE_DBS_FOUND[@]}"; do
        sq_path="${sq_entry%% (*}"
        sq_origin=""
        [[ "$sq_entry" == *" ("* ]] && sq_origin=" (${sq_entry#* (}"
        sq_size="N/A"
        [[ -f "$sq_path" ]] && sq_size=$(du -h "$sq_path" 2>/dev/null | awk '{print $1}' || echo "N/A")
        echo -e "    • ${FG_CYAN}${sq_path}${NC}${sq_origin} — Tamanho: ${FG_YELLOW}${sq_size}${NC}"
    done
    add_unique_item RESUMO_BANCOS_ATIVOS "SQLite(${#SQLITE_DBS_FOUND[@]} arquivo(s))"
fi

if (( DB_ANY_FOUND == 0 )); then
    log_info "Nenhum SGBD instalado diretamente no host (verifique a subseção 4.5 de Contêineres)."
fi
return 0
}

# ==============================================================================
# SEÇÃO 6 - FIREWALL (ATIVO OU INATIVO), REGRAS CONFIGURADAS E SEGURANÇA
# ==============================================================================
secao_6_firewall() {
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
        NFT_RULESET=$(nft list ruleset 2>/dev/null | grep -vE "^\s*$" || true)
        if [[ -n "$NFT_RULESET" ]]; then
            echo -e "      ${BOLD}Regras Configuradas no NFTables (Top 25 linhas):${NC}"
            echo "$NFT_RULESET" | head -n 25 | sed 's/^/        /'
        fi
        if [[ "$(get_service_status_plain nftables)" == "Ativo" ]] || echo "$NFT_RULESET" | grep -qiE "policy drop|drop|reject"; then
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
    if (( ${#DOCKER_PUBLIC_PORTS[@]} > 0 )); then
        log_warning "Docker expõe portas diretamente em 0.0.0.0/[::] via NAT (contorna regras padrão de UFW/INPUT):"
        for dp_item in "${DOCKER_PUBLIC_PORTS[@]}"; do
            echo -e "      ├─ ${FG_YELLOW}${dp_item}${NC}"
        done
        add_alert "Docker publica ${#DOCKER_PUBLIC_PORTS[@]} porta(s) diretamente em 0.0.0.0/[::] (contornando filtros padrão da chain INPUT do ${FIREWALL_SUMMARY_STATE})."
    fi
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
        SSH_PORT_CFG=$(echo "$SSHD_T" | awk '/^port / {print $2}' | trim_ws)
    elif [[ -r /etc/ssh/sshd_config ]]; then
        SSH_ROOT_LOGIN=$( grep -h -iE "^\s*PermitRootLogin\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -n 1 || true )
        SSH_PASS_AUTH=$( grep -h -iE "^\s*PasswordAuthentication\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -n 1 || true )
        SSH_PORT_CFG=$( grep -h -iE "^\s*Port\s+" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | trim_ws || true )
    fi
    log_item "Serviço OpenSSH" "Porta(s): ${FG_CYAN}${SSH_PORT_CFG:-22}${NC} | PermitRootLogin: ${FG_YELLOW}${SSH_ROOT_LOGIN:-padrão}${NC} | PasswordAuth: ${SSH_PASS_AUTH:-padrão}"
    [[ "$SSH_ROOT_LOGIN" == "yes" ]] && add_alert "SSH está com PermitRootLogin habilitado ('yes')."
fi

if command -v fail2ban-client >/dev/null 2>&1; then
    F2B_STATUS=$(get_service_status fail2ban)
    log_item "Fail2Ban (IPS)" "${F2B_STATUS}"
    if [[ "$(get_service_status_plain fail2ban)" == "Ativo" ]] && (( IS_ROOT == 1 )); then
        JAILS=$(fail2ban-client status 2>/dev/null | awk -F':' '/Jail list/ {print $2}' | trim_ws || true)
        log_item "Jails Ativas" "${FG_GREEN}${JAILS:-Nenhuma}${NC}"
        if [[ -n "$JAILS" ]]; then
            IFS=',' read -ra JAIL_ARR <<< "$JAILS"
            for j_raw in "${JAIL_ARR[@]}"; do
                j_name=$(echo "$j_raw" | trim_ws)
                [[ -z "$j_name" ]] && continue
                j_st=$(fail2ban-client status "$j_name" 2>/dev/null || true)
                j_cur=$(echo "$j_st" | awk -F':' '/Currently banned/ {gsub(/[^0-9]/,"",$2); print $2}' | head -n 1 || echo "0")
                j_tot=$(echo "$j_st" | awk -F':' '/Total banned/ {gsub(/[^0-9]/,"",$2); print $2}' | head -n 1 || echo "0")
                echo -e "      ├─ Jail [${FG_CYAN}${j_name}${NC}]: Banidos agora: ${FG_YELLOW}${j_cur:-0}${NC} | Total histórico: ${DIM}${j_tot:-0}${NC}"
            done
        fi
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
    FAILED_UNITS=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | trim_ws || true)
    if [[ -n "$FAILED_UNITS" ]]; then
        log_warning "Serviços do Systemd em estado FAILED: ${FG_RED}${FAILED_UNITS}${NC}"
        add_alert "Unidades systemd com falha detectadas: ${FAILED_UNITS}"
    else
        log_item "Systemd Failed Units" "${FG_GREEN}Nenhuma (0 falhas)${NC}"
    fi
fi
return 0
}

# ==============================================================================
# SEÇÃO 7 - PORTAS ABERTAS (LISTEN), REDE, /ETC/HOSTS E CONEXÕES ATIVAS
# ==============================================================================
secao_7_rede() {
print_header "7. PORTAS ABERTAS (LISTEN), REDE, /ETC/HOSTS E CONEXÕES ATIVAS"

# 7.1 - Tabela de Portas Abertas (TCP/UDP) com PID, Serviço e CWD
echo -e "  ${BOLD}Portas Abertas em Escuta (LISTEN TCP/UDP) e Processos Responsáveis:${NC}\n"
printf "    ${BOLD}%-6s %-22s %-7s %-10s %-22s %s${NC}\n" "PROTO" "ENDEREÇO LOCAL" "PORTA" "ESCOPO" "PROCESSO (PID)" "SERVIÇO / DIRETÓRIO (CWD)"
draw_separator

if command -v ss >/dev/null 2>&1; then
    while IFS='|' read -r proto local_addr port proc_raw pid_num; do
        [[ -z "$proto" ]] && continue
        scope="LOCAL"
        if [[ "$local_addr" == "0.0.0.0" || "$local_addr" == "[::]" || "$local_addr" == "::" || "$local_addr" == "*" || "$local_addr" == "[::ffff:0.0.0.0]" ]]; then
            scope="PÚBLICO"
        elif [[ "$local_addr" != 127.* && "$local_addr" != "[::1]" && "$local_addr" != "::1" && "$local_addr" != 127.0.0.* ]]; then
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

        if [[ "$scope" == "PÚBLICO" ]] && [[ "$port" =~ ^(111|161|2049|2375|3306|3389|5432|5900|6379|9100|9200|10050|10051|11211|27017)$ ]]; then
            if [[ "$port" == "2375" ]]; then
                add_critical_alert "Porta Docker API sem TLS (${port}/${proto} - ${proc_raw}) aberta publicamente em ${local_addr}!"
            else
                add_alert "Porta sensível de banco/gerência (${port}/${proto} - ${proc_raw}) está aberta em todas as interfaces (${local_addr})."
            fi
        fi
    done < <(ss -tulpn 2>/dev/null | awk '$1 !~ /^(Netid|State)$/ {
        proto = $1
        local_full = $5
        proc_col = ""
        for (i=7; i<=NF; i++) proc_col = proc_col $i " "

        # Extrai porta e endereço suportando IPv4, [::]:port, :::port e interface%zone:port
        if (match(local_full, /:[0-9]+$/)) {
            port = substr(local_full, RSTART + 1)
            addr = substr(local_full, 1, RSTART - 1)
        } else {
            port = "-"
            addr = local_full
        }
        if (addr == "" || addr == "*" || addr == "0.0.0.0") addr = "0.0.0.0"
        if (addr == "::" || addr == "[::]") addr = "[::]"

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
DNS_SERVERS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | trim_ws || true)
SEARCH_DOMAINS=$(awk '/^(search|domain)/ {$1=""; print $0}' /etc/resolv.conf 2>/dev/null | trim_ws || true)
if command -v resolvectl >/dev/null 2>&1; then
    RESOLVED_DNS=$(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1 && $2!="" {print $2}' | trim_ws || true)
    [[ -n "$RESOLVED_DNS" ]] && DNS_SERVERS="${DNS_SERVERS} (Upstream: ${RESOLVED_DNS})"
fi
DNS_TEST_STR="Não testado"
if (( OPT_NO_NET == 1 )); then
    DNS_TEST_STR="${DIM}Pulado (--no-net)${NC}"
elif command -v getent >/dev/null 2>&1; then
    DNS_TEST_IP=$(timeout 2 getent hosts deb.debian.org 2>/dev/null | awk '{print $1}' | head -n 1 || true)
    if [[ -n "$DNS_TEST_IP" ]]; then
        DNS_TEST_STR="${FG_GREEN}OK (deb.debian.org -> ${DNS_TEST_IP})${NC}"
    else
        DNS_TEST_STR="${FG_RED}FALHA ao resolver deb.debian.org (timeout 2s)${NC}"
        add_alert "Resolução DNS externa falhou no teste rápido (getent hosts deb.debian.org)."
    fi
fi
PUBLIC_IP="Não detectado / Sem saída HTTPS"
if (( OPT_NO_NET == 1 )); then
    PUBLIC_IP="Pulado (--no-net)"
elif command -v curl >/dev/null 2>&1; then
    PUBLIC_IP=$(curl -4 -fsS --connect-timeout 2 --max-time 3 https://ifconfig.me 2>/dev/null || echo "Não detectado")
fi
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n 1 || echo "N/A")

log_item "IP Local Principal"  "${FG_GREEN}${PRIMARY_IP:-Nenhum}${NC}"
log_item "Gateway Padrão"      "${DEFAULT_GATEWAY:-Nenhum}"
log_item "Servidores DNS"      "${DNS_SERVERS:-Nenhum}${SEARCH_DOMAINS:+ (Domínio Busca: $SEARCH_DOMAINS)}"
log_item "Teste Resolução DNS" "${DNS_TEST_STR}"
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
return 0
}

# ==============================================================================
# SEÇÃO 8 - AUTOMAÇÃO, AGENDAMENTOS (CRON/TIMERS), SCRIPTS E BACKUPS LOCAIS
# ==============================================================================
secao_8_automacao() {
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
    systemctl list-timers --no-legend --plain 2>/dev/null | awk '{
        timer=""; acts="";
        for(i=1; i<=NF; i++) {
            if ($i ~ /\.timer$/) { timer=$i; if (i<NF) acts=$NF; break }
        }
        if (timer != "") printf "    • %-35s -> Aciona: %s\n", timer, (acts ? acts : "N/A")
    }' || true
fi

# 8.2 - Scripts Administrativos Locais e Arquivos de Backup/Dump
CUSTOM_SCRIPTS=$(find /root /usr/local/bin /usr/local/sbin /opt -maxdepth 2 -type f \( -name "*.sh" -o -name "*.py" \) ! -name "auditoria_servidor_inventario.sh" 2>/dev/null | head -n 20 || true)
if [[ -n "$CUSTOM_SCRIPTS" ]]; then
    echo -e "\n  ${BOLD}Scripts Administrativos / Automação Local (/root, /usr/local/bin, /opt):${NC}"
    while IFS= read -r cs; do
        echo -e "    • ${FG_YELLOW}${cs}${NC}"
    done <<< "$CUSTOM_SCRIPTS"
fi

BACKUP_ARCHIVES=$(find /var/backups /backup /backups /root /home -maxdepth 3 -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.dump" -o -name "*backup*.tar.gz" -o -name "*bkp*.tar.gz" \) -printf '%T@|%p\n' 2>/dev/null | sort -t'|' -k1,1rn | head -n 15 || true)
if [[ -z "$BACKUP_ARCHIVES" ]]; then
    while IFS= read -r fb_path; do
        [[ -f "$fb_path" ]] || continue
        fb_ts=$(stat -c '%Y' "$fb_path" 2>/dev/null || echo 0)
        BACKUP_ARCHIVES+="${fb_ts}|${fb_path}"$'\n'
    done < <(find /var/backups /backup /backups /root /home -maxdepth 3 -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.dump" -o -name "*backup*.tar.gz" -o -name "*bkp*.tar.gz" \) 2>/dev/null | head -n 15 || true)
    BACKUP_ARCHIVES=$(printf '%s' "$BACKUP_ARCHIVES" | sort -t'|' -k1,1rn || true)
fi
if [[ -n "$BACKUP_ARCHIVES" ]]; then
    echo -e "\n  ${BOLD}Arquivos de Dump / Backup Localizados no Disco (Mais Recentes Primeiro):${NC}"
    NOW_BKP_EPOCH=$(date +%s)
    NEWEST_BKP_DAYS=""
    NEWEST_BKP_FILE=""
    while IFS='|' read -r ba_ts_raw ba; do
        [[ -z "$ba" ]] && continue
        BA_SIZE=$(safe_du "$ba")
        [[ -z "$BA_SIZE" ]] && BA_SIZE="N/A"
        ba_epoch="${ba_ts_raw%%.*}"
        BA_DATE_STR="Data N/A"
        if [[ "$ba_epoch" =~ ^[0-9]+$ ]] && (( ba_epoch > 0 )); then
            ba_dt=$(date -d "@$ba_epoch" '+%d/%m/%Y %H:%M' 2>/dev/null || echo "N/A")
            ba_days=$(( (NOW_BKP_EPOCH - ba_epoch) / 86400 ))
            (( ba_days < 0 )) && ba_days=0
            if [[ -z "$NEWEST_BKP_DAYS" ]]; then
                NEWEST_BKP_DAYS="$ba_days"
                NEWEST_BKP_FILE="$ba"
            fi
            if (( ba_days == 0 )); then
                BA_DATE_STR="${FG_GREEN}${ba_dt} (hoje)${NC}"
            elif (( ba_days <= 7 )); then
                BA_DATE_STR="${FG_GREEN}${ba_dt} (há ${ba_days} dia(s))${NC}"
            elif (( ba_days <= 30 )); then
                BA_DATE_STR="${FG_YELLOW}${ba_dt} (há ${ba_days} dias)${NC}"
            else
                BA_DATE_STR="${FG_RED}${ba_dt} (há ${ba_days} dias)${NC}"
            fi
        fi
        echo -e "    • ${FG_CYAN}${ba}${NC} — Tamanho: ${FG_YELLOW}${BA_SIZE}${NC} | Modificado: ${BA_DATE_STR}"
    done <<< "$BACKUP_ARCHIVES"
    if [[ "$NEWEST_BKP_DAYS" =~ ^[0-9]+$ ]] && (( NEWEST_BKP_DAYS > 14 )); then
        add_alert "O arquivo de backup/dump mais recente encontrado no disco tem ${NEWEST_BKP_DAYS} dias (${NEWEST_BKP_FILE}) — verificar rotina de backup."
    fi
fi
return 0
}

# ==============================================================================
# RESUMO EXECUTIVO DO INVENTÁRIO (PAINEL CONSOLIDADO NA ORDEM SOLICITADA)
# ==============================================================================
resumo_executivo() {
print_header "RESUMO DA INSTALAÇÃO E DIAGNÓSTICO DO SERVIDOR"

ROLES_STR="Servidor Linux Genérico / Sem Serviços de Rede Ativos"
if (( ${#PAPEIS_DETECTADOS[@]} > 0 )); then
    ROLES_STR=$(printf '%s + ' "${PAPEIS_DETECTADOS[@]}" | sed 's/ + $//')
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

LISTA_PACOTES="Nenhum (Modo 100% Passivo / Somente Leitura)"
if (( ${#PACOTES_INSTALADOS[@]} > 0 )); then
    LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")
fi

print_summary "1. Sistema Operacional:"     "${OS_NAME} (Kernel ${KERNEL_VER})" "$FG_CYAN"
print_summary "   Instalado em (SO):"       "${OS_INSTALLED_AT}" "$FG_CYAN"
print_summary "   Status de Atualização:"   "${OS_UPDATE_STATUS_STR}" "$UPDATES_SUMMARY_COLOR"
print_summary "   Aguardando Reboot?"       "${REBOOT_NEEDED}${REBOOT_REASON:+ ($REBOOT_REASON)}" "$REBOOT_SUMMARY_COLOR"
print_summary "2. Usuários com Sudo:"       "${SUDO_USERS_STR}" "$FG_YELLOW"
print_summary "   Grupos com Sudo:"         "${SUDO_GROUPS_STR}" "$FG_CYAN"
if (( ${#DISABLED_USERS_SUMMARY[@]} > 0 )); then
    DISABLED_USERS_STR=$(printf '%s, ' "${DISABLED_USERS_SUMMARY[@]}" | sed 's/, $//')
    print_summary "   Contas Desativadas:"      "${DISABLED_USERS_STR}" "$FG_YELLOW"
fi
print_summary "3. NFS / Samba / LDAP:"      "${STORAGE_REDE_STR}" "$FG_CYAN"
print_summary "4. Papel do Servidor:"       "${ROLES_STR}" "$FG_YELLOW"
print_summary "   Aplicações e Versões:"    "${APPS_SUMMARY_STR}" "$FG_GREEN"
print_summary "   Certbot / SSL:"           "${RESUMO_CERTBOT_STATUS}" "$FG_CYAN"
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

TOTAL_ALERTS=$(( ${#ALERTAS_CRITICOS[@]} + ${#ALERTAS_AUDITORIA[@]} ))
if (( TOTAL_ALERTS > 0 )); then
    echo -e "\n  ${BOLD}${FG_YELLOW}⚠ PONTOS DE ATENÇÃO E RECOMENDAÇÕES (${TOTAL_ALERTS} — Críticos: ${#ALERTAS_CRITICOS[@]} | Atenção: ${#ALERTAS_AUDITORIA[@]}):${NC}"
    if (( ${#ALERTAS_CRITICOS[@]} > 0 )); then
        for crit_a in "${ALERTAS_CRITICOS[@]}"; do
            echo -e "    ${FG_RED}${BOLD}[CRÍTICO]${NC} ${FG_RED}${crit_a}${NC}"
        done
    fi
    if (( ${#ALERTAS_AUDITORIA[@]} > 0 )); then
        for alerta in "${ALERTAS_AUDITORIA[@]}"; do
            echo -e "    ${FG_YELLOW}[ATENÇÃO]${NC} ${alerta}"
        done
    fi
else
    echo -e "\n  ${FG_GREEN}[+] Nenhum alerta crítico ou ponto de atenção imediato detectado durante a varredura.${NC}"
fi
}

# ==============================================================================
# ORQUESTRADOR PRINCIPAL (EXECUÇÃO MODULAR POR SEÇÃO)
# ==============================================================================
main() {
    if section_enabled 1; then secao_1_sistema; fi
    if section_enabled 2; then secao_2_usuarios; fi
    if section_enabled 3; then secao_3_armazenamento; fi
    if section_enabled 4; then secao_4_aplicacoes; fi
    if section_enabled 5; then secao_5_bancos; fi
    if section_enabled 6; then secao_6_firewall; fi
    if section_enabled 7; then secao_7_rede; fi
    if section_enabled 8; then secao_8_automacao; fi
    resumo_executivo
}

main
exit 0
