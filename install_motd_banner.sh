#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
# ==============================================================================
# INSTALADOR E ATUALIZADOR DO BANNER DINÂMICO DE BOAS-VINDAS (MOTD)
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_motd_banner.sh -O install_motd_banner.sh && sudo chmod +x install_motd_banner.sh && sudo ./install_motd_banner.sh
# ==============================================================================
# O que este script faz:
# 1. Valida privilégios de execução (exige Root/Sudo) e inicializa captura de logs.
# 2. Verifica as ferramentas nativas necessárias sem alterar pacotes via APT.
# 3. Instala ou atualiza atomicamente /usr/local/bin/motd_banner.sh com detecção
#    automática de Hostname, Sistema, Kernel, Data de instalação/primeiro boot,
#    Uptime, barras de RAM/SWAP/Discos, IPs, UFW e status de Reboot Pendente.
# 4. Integra o disparo único em terminais interativos (/etc/profile.d/motd_banner.sh
#    e /etc/bash.bashrc), preservando scp/sftp/rsync e .hushlogin.
# 5. Disponibiliza o comando rápido 'motd' em /usr/local/bin/motd para qualquer shell.
# 6. Exibe o resumo da operação e salva relatório e backups em /root e na Home.
# ==============================================================================

set -Eeuo pipefail
umask 077

export VERSION
export LC_ALL=C.UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==============================================================================
# 1 - INICIALIZAÇÃO, VALIDAÇÕES E FUNÇÕES BASE
# ==============================================================================

# 1.1 - PALETA DE CORES E FUNÇÕES VISUAIS
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly FG_RED='\033[31m'
readonly FG_GREEN='\033[32m'
readonly FG_YELLOW='\033[33m'
readonly FG_CYAN='\033[36m'
readonly FG_WHITE='\033[37m'
readonly ARROW="❯"

draw_separator() { printf '%b\n' "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"; }
print_header() { printf '\n%b\n' "${FG_CYAN}${BOLD}${ARROW} ${FG_WHITE}$1${NC}"; draw_separator; }
log_info() { printf '%b %s\n' "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}     " "$1"; }
log_success() { printf '%b %s\n' "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}  " "$1"; }
log_warning() { printf '%b %s\n' "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}  " "$1"; }
log_error() { printf '%b %s\n' "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}     " "$1" >&2; }

print_summary() {
    local padding=$((24 - ${#1}))
    if (( padding < 1 )); then padding=1; fi
    printf '  %b%s%*s%b%b%s%b\n' "$BOLD" "$1" "$padding" '' "$NC" "${3:-$FG_CYAN}" "$2" "$NC"
}
print_summary_section() {
    printf '\n  %b%s%b\n' "${BOLD}${FG_CYAN}" "$1" "$NC"
    draw_separator
}

fatal() { log_error "$1"; exit 1; }
PENDENCIAS=()
pendencia() { PENDENCIAS+=("$1"); log_warning "$1"; }

# Invocada indiretamente pelo trap ERR.
# shellcheck disable=SC2317,SC2329
erro_execucao() {
    log_error "Falha na etapa '${ETAPA:-inicialização}', linha $1 (código $2). Consulte o relatório."
}

# 1.2 - BACKUPS E ESCRITA ATÔMICA
backup_file() {
    local path="$1"
    [[ ! -L "$path" ]] || { log_error "Destino administrativo é um link simbólico: $path"; return 1; }
    if [[ -e "$path" && ! -e "$BACKUP_DIR$path" ]]; then
        [[ -f "$path" ]] || { log_error "Destino não é arquivo regular: $path"; return 1; }
        mkdir -p -- "$BACKUP_DIR$(dirname "$path")" || return 1
        cp -a -- "$path" "$BACKUP_DIR$path" || return 1
    fi
}

install_config() {
    local src="$1" dest="$2" mode="${3:-644}" tmp
    backup_file "$dest" || return 1
    tmp=$(mktemp "$(dirname "$dest")/.install-motd-banner.XXXXXXXX") || return 1
    if ! install -o root -g root -m "$mode" -- "$src" "$tmp" || ! mv -fT -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# Grava na home abandonando privilégios de root antes da criação do arquivo.
# shellcheck disable=SC2317,SC2329,SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 1
    runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        umask 077
        cd -- "$1"
        tmp=$(mktemp .install-motd-banner.XXXXXXXX)
        trap '\''rm -f -- "$tmp"'\'' EXIT
        cat > "$tmp"
        mv -fT -- "$tmp" "$2"
    ' bash "$home_dir" "$name" < "$src"
}

# 1.3 - FINALIZADOR ÚNICO
# Invocada indiretamente pelo trap EXIT.
# shellcheck disable=SC2317,SC2329
finalizar() {
    local rc="$1" home_dir root_saved=0
    trap - EXIT ERR INT TERM HUP
    set +e
    if (( rc == 0 && ${#PENDENCIAS[@]} > 0 )); then rc=3; fi
    printf '\nResultado: código %s. Finalizado em: %s\n' "$rc" "$(date '+%d/%m/%Y %H:%M:%S')"
    printf 'Relatório previsto: /root/%s\nBackups: %s\n' "$LOG_FILENAME" "$BACKUP_DIR"
    exec 1>&3 2>&4
    wait "$TEE_PID" || { log_error "Falha na captura do relatório."; rc=1; }
    if install_config "$LOG_FILE" "/root/$LOG_FILENAME" 600; then
        root_saved=1
        log_success "Relatório salvo: /root/$LOG_FILENAME"
        install_config "$LOG_FILE" "/root/$LOG_LATEST" 600 || rc=1
    else
        log_error "Não foi possível salvar em /root; relatório preservado em $LOG_FILE"
        rc=1
    fi
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] && id "$SUDO_USER" >/dev/null 2>&1; then
        home_dir=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -d "$home_dir" ]]; then
            if copy_to_home "$SUDO_USER" "$home_dir" "$LOG_FILE" "$LOG_FILENAME" &&
               copy_to_home "$SUDO_USER" "$home_dir" "$LOG_FILE" "$LOG_LATEST"; then
                log_success "Cópia do relatório salva na home de $SUDO_USER."
            else
                log_warning "Cópia para a home falhou; consulte o relatório em /root."
                (( rc != 0 )) || rc=3
            fi
        fi
    fi
    if (( root_saved )); then rm -rf -- "$LOG_DIR"; fi
    exit "$rc"
}

# 1.4 - VALIDAÇÃO DE PRIVILÉGIOS, LOCK E LOGS
[[ $EUID -eq 0 ]] || fatal "Execute como root (sudo)."
for cmd in flock mktemp install tee awk stat date df free ip hostname findmnt cmp getent runuser; do
    command -v "$cmd" >/dev/null || fatal "Pré-requisito ausente: $cmd"
done

mkdir -p /run/lock
exec 9>/run/lock/install-motd-banner.lock
flock -n 9 || fatal "Outra execução deste script está em andamento."

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_motd_banner_${LOG_TIMESTAMP}.log"
[[ ! -e "/root/$LOG_FILENAME" && ! -L "/root/$LOG_FILENAME" ]] || LOG_FILENAME="relatorio_install_motd_banner_${LOG_TIMESTAMP}_$$.log"
LOG_LATEST=relatorio_install_motd_banner_latest.log
LOG_DIR=$(mktemp -d -p /tmp install_motd_banner.XXXXXXXX)
BACKUP_DIR=$(mktemp -d "/root/backup_install_motd_banner_${LOG_TIMESTAMP}.XXXXXXXX")
LOG_FILE="$LOG_DIR/$LOG_FILENAME"
touch "$LOG_FILE"
exec 3>&1 4>&2
exec > >(tee -a "$LOG_FILE") 2>&1
TEE_PID=$!
trap 'erro_execucao "$LINENO" "$?"' ERR
trap 'finalizar "$?"' EXIT
trap 'exit 130' INT

# ==============================================================================
# 2 - VALIDAÇÃO DO AMBIENTE E FERRAMENTAS DO SISTEMA
# ==============================================================================
ETAPA="ambiente"
print_header "VALIDAÇÃO DO AMBIENTE (v${VERSION})"

SISTEMA_ATUAL=$(grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || printf 'Linux')
log_info "Sistema detectado: $SISTEMA_ATUAL"
if grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
    log_info "Ambiente identificado: WSL (Windows Subsystem for Linux)"
elif VIRT_CONTAINER=$(systemd-detect-virt --container 2>/dev/null); then
    log_info "Ambiente identificado: Contêiner ($VIRT_CONTAINER)"
else
    VIRT_INFO=$(systemd-detect-virt 2>/dev/null || printf 'none')
    log_info "Ambiente identificado: Servidor físico / VM ($VIRT_INFO)"
fi
log_success "Ferramentas nativas do sistema validadas (nenhum pacote APT alterado)."

# ==============================================================================
# 3 - INSTALAÇÃO / ATUALIZAÇÃO DO BANNER DINÂMICO
# ==============================================================================
ETAPA="banner"
print_header "INSTALAÇÃO / ATUALIZAÇÃO DO BANNER DINÂMICO"

cat > "$LOG_DIR/motd_banner.sh" <<'EOF'
#!/bin/bash
# ==============================================================================
# Banner Dinâmico de Boas-Vindas e Diagnóstico do Servidor
# Exibido automaticamente em sessões interativas de shell (SSH / Console)
# ==============================================================================

# Executa apenas se a saída padrão for um terminal interativo (evita quebrar scp/sftp/rsync)
[ "${1:-}" = "--force" ] || [ -t 1 ] || exit 0

export LC_ALL=C.UTF-8
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

print_row_color() {
  local label="$1" color="$2" val="$3" extra_dim="${4:-}"
  local pad=$((19 - ${#label}))
  [ "$pad" -lt 1 ] && pad=1
  if [ -n "$extra_dim" ]; then
    printf "     \033[1m%s%*s\033[0m %b%s\033[0m \033[2m%s\033[0m\n" "$label" "$pad" "" "$color" "$val" "$extra_dim"
  else
    printf "     \033[1m%s%*s\033[0m %b%s\033[0m\n" "$label" "$pad" "" "$color" "$val"
  fi
}

print_row_bar() {
  local label="$1" pct="$2" detail="$3"
  local filled=0 empty=0 bar="" i=0 bar_color="\033[32m"
  local pad=$((19 - ${#label}))
  [ "$pad" -lt 1 ] && pad=1
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  filled=$(( (pct + 5) / 10 ))
  [ "$pct" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
  [ "$filled" -gt 10 ] && filled=10
  empty=$((10 - filled))
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  if [ "$pct" -ge 90 ]; then
    bar_color="\033[1;31m"
  elif [ "$pct" -ge 75 ]; then
    bar_color="\033[1;33m"
  fi
  printf "     \033[1m%s%*s\033[0m %b[%s] %2d%%\033[0m \033[36m(%s)\033[0m\n" \
    "$label" "$pad" "" "$bar_color" "$bar" "$pct" "$detail"
}

HOSTNAME=$(hostname 2>/dev/null || uname -n)
SISTEMA=$(lsb_release -ds 2>/dev/null || grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || echo "Linux")
KERNEL=$(uname -r)

get_file_epoch() {
  local target="$1" ts=""
  [ -e "$target" ] || return 1
  ts=$(stat -c '%W' -- "$target" 2>/dev/null)
  if ! [[ "$ts" =~ ^[0-9]+$ ]] || [ "$ts" -le 0 ]; then
    ts=$(stat -c '%Y' -- "$target" 2>/dev/null)
  fi
  if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -ge 946684800 ]; then
    printf '%s\n' "$ts"
    return 0
  fi
  return 1
}

get_earliest_ssh_host_epoch() {
  local f="" ts="" min_ts=""
  for f in /etc/ssh/ssh_host_*_key.pub /etc/ssh/ssh_host_*_key; do
    [ -e "$f" ] || continue
    if ts=$(get_file_epoch "$f"); then
      if [ -z "$min_ts" ] || [ "$ts" -lt "$min_ts" ]; then
        min_ts="$ts"
      fi
    fi
  done
  [ -n "$min_ts" ] || return 1
  printf '%s\n' "$min_ts"
}

get_fs_root_epoch() {
  local root_dev="" tune_raw="" ts=""
  root_dev=$(findmnt -no SOURCE / 2>/dev/null)
  if [ -n "$root_dev" ] && [ -r "$root_dev" ] && command -v tune2fs >/dev/null 2>&1; then
    tune_raw=$(LC_ALL=C tune2fs -l "$root_dev" 2>/dev/null | awk -F':[[:space:]]+' '/^Filesystem created:/ {print $2; exit}')
    if [ -n "$tune_raw" ]; then
      ts=$(LC_ALL=C date -d "$tune_raw" +%s 2>/dev/null)
      if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -ge 946684800 ]; then
        printf '%s\n' "$ts"
        return 0
      fi
    fi
  fi
  get_file_epoch /
}

get_install_info() {
  local virt_container="" is_wsl=0 is_container=0
  local fs_ts="" inst_ts="" mach_ts="" ssh_ts="" boot_ts="" chosen_ts="" origem=""
  local date_str="" today_epoch="" inst_day_epoch="" dias=0 dias_txt=""

  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    is_wsl=1
  elif virt_container=$(systemd-detect-virt --container 2>/dev/null); then
    is_container=1
  fi

  fs_ts=$(get_fs_root_epoch || true)
  inst_ts=$(get_file_epoch /var/log/installer || true)
  mach_ts=$(get_file_epoch /etc/machine-id || true)
  ssh_ts=$(get_earliest_ssh_host_epoch || true)
  boot_ts="${mach_ts:-$ssh_ts}"

  if [ "$is_wsl" -eq 1 ]; then
    chosen_ts="${boot_ts:-$fs_ts}"
    origem="Primeiro boot WSL"
  elif [ "$is_container" -eq 1 ]; then
    chosen_ts="${boot_ts:-$fs_ts}"
    if [ "$virt_container" = "lxc" ]; then
      origem="Primeiro boot LXC"
    else
      origem="Primeiro boot contêiner"
    fi
  elif [ -n "$inst_ts" ]; then
    if [ -n "$boot_ts" ] && [ "$boot_ts" -gt $((inst_ts + 86400)) ]; then
      chosen_ts="$boot_ts"
      origem="Primeiro boot / Template"
    else
      chosen_ts="$inst_ts"
      origem="VM/Físico"
    fi
  elif [ -n "$fs_ts" ] && [ -n "$boot_ts" ]; then
    if [ "$boot_ts" -gt $((fs_ts + 3600)) ]; then
      chosen_ts="$boot_ts"
      origem="Primeiro boot / Template"
    else
      chosen_ts="$fs_ts"
      origem="VM/Físico"
    fi
  elif [ -n "$fs_ts" ]; then
    chosen_ts="$fs_ts"
    origem="VM/Físico"
  elif [ -n "$boot_ts" ]; then
    chosen_ts="$boot_ts"
    origem="Primeiro boot"
  fi

  if [ -z "$chosen_ts" ]; then
    printf 'Não identificado\n'
    return 0
  fi

  date_str=$(date -d "@$chosen_ts" '+%d/%m/%Y' 2>/dev/null || printf '')
  today_epoch=$(date -d "$(date '+%Y-%m-%d' 2>/dev/null)" +%s 2>/dev/null || printf '')
  inst_day_epoch=$(date -d "$(date -d "@$chosen_ts" '+%Y-%m-%d' 2>/dev/null)" +%s 2>/dev/null || printf '')
  if [ -n "$date_str" ] && [[ "$today_epoch" =~ ^[0-9]+$ ]] && [[ "$inst_day_epoch" =~ ^[0-9]+$ ]]; then
    dias=$(( (today_epoch - inst_day_epoch) / 86400 ))
    [ "$dias" -lt 0 ] && dias=0
    case "$dias" in
      0) dias_txt="hoje" ;;
      1) dias_txt="há 1 dia" ;;
      *) dias_txt="há ${dias} dias" ;;
    esac
    printf '%s (%s | %s)\n' "$date_str" "$dias_txt" "$origem"
  elif [ -n "$date_str" ]; then
    printf '%s (%s)\n' "$date_str" "$origem"
  else
    printf 'Não identificado\n'
  fi
}

INSTALADO_EM=$(get_install_info)
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")

read -r MEM_USED MEM_TOTAL MEM_AVAIL <<< "$(free -h 2>/dev/null | awk '/^Mem:/ {print $3, $2, $7}')"
read -r MEM_B_TOTAL MEM_B_USED <<< "$(free -b 2>/dev/null | awk '/^Mem:/ {print $2, $3}')"
MEM_PCT=0
if [[ "${MEM_B_TOTAL:-}" =~ ^[0-9]+$ ]] && [[ "${MEM_B_USED:-}" =~ ^[0-9]+$ ]] && [ "$MEM_B_TOTAL" -gt 0 ]; then
  MEM_PCT=$(( (MEM_B_USED * 100) / MEM_B_TOTAL ))
fi

read -r SWAP_USED SWAP_TOTAL SWAP_FREE <<< "$(free -h 2>/dev/null | awk '/^Swap:/ {print $3, $2, $4}')"
read -r SWAP_B_TOTAL SWAP_B_USED <<< "$(free -b 2>/dev/null | awk '/^Swap:/ {print $2, $3}')"

echo -e "\033[1;36m================================================================\033[0m"
echo -e "  \033[1;32m📌 VOCÊ CONECTOU EM:\033[0m"
print_row_color "Hostname:" "\033[36m" "${HOSTNAME}"
print_row_color "Sistema:" "\033[36m" "${SISTEMA}" "(Kernel ${KERNEL})"
print_row_color "Instalado em:" "\033[36m" "${INSTALADO_EM}"
print_row_color "Uptime:" "\033[36m" "${UPTIME}"
if [ -n "${MEM_TOTAL:-}" ]; then
  print_row_bar "Memória RAM:" "$MEM_PCT" "${MEM_USED} / ${MEM_TOTAL} | Livre: ${MEM_AVAIL:-N/A}"
else
  print_row_color "Memória RAM:" "\033[36m" "N/A"
fi
if [[ "${SWAP_B_TOTAL:-}" =~ ^[0-9]+$ ]] && [ "$SWAP_B_TOTAL" -gt 0 ]; then
  SWAP_PCT=$(( (${SWAP_B_USED:-0} * 100) / SWAP_B_TOTAL ))
  print_row_bar "Memória SWAP:" "$SWAP_PCT" "${SWAP_USED:-0B} / ${SWAP_TOTAL:-0B} | Livre: ${SWAP_FREE:-0B}"
else
  print_row_color "Memória SWAP:" "\033[36m" "Desativada (0B)"
fi

# Partições / Discos Físicos Montados
DISCOS_ENCONTRADOS=0
DISCOS_RAW=$(df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 -x rootfs 2>/dev/null | awk 'NR>1 && ($1 ~ /^\/dev/ || $1 ~ /:/) && $6 !~ /^\/boot/ {print $6, $3, $2, $4, $5}')
if [ -n "$DISCOS_RAW" ]; then
  while read -r mountpoint used total free perc; do
    if [ -n "$mountpoint" ]; then
      DISCOS_ENCONTRADOS=1
      lbl="Disco (${mountpoint}):"
      pct_num="${perc%%%}"
      if [[ "$pct_num" =~ ^[0-9]+$ ]]; then
        print_row_bar "$lbl" "$pct_num" "${used} / ${total} | Livre: ${free}"
      else
        print_row_color "$lbl" "\033[36m" "Usado: ${used} / Total: ${total} (Livre: ${free} | ${perc})"
      fi
    fi
  done <<< "$DISCOS_RAW"
fi

if [ "$DISCOS_ENCONTRADOS" -eq 0 ]; then
  read -r r_used r_total r_free r_perc <<< "$(df -hP / 2>/dev/null | awk 'NR==2 {print $3, $2, $4, $5}')"
  r_pct_num="${r_perc%%%}"
  if [[ "${r_pct_num:-}" =~ ^[0-9]+$ ]]; then
    print_row_bar "Disco (/):" "$r_pct_num" "${r_used} / ${r_total} | Livre: ${r_free}"
  else
    print_row_color "Disco (/):" "\033[36m" "Usado: ${r_used:-N/A} / Total: ${r_total:-N/A} (Livre: ${r_free:-N/A})"
  fi
fi

# Interfaces de Rede e Endereços IPv4
IPS_ENCONTRADOS=0
IPS_RAW=$(ip -4 -o addr show scope global 2>/dev/null | awk '$2 != "lo" {split($4, a, "/"); print $2, a[1]}')
if [ -n "$IPS_RAW" ]; then
  while read -r iface ip_addr; do
    if [ -n "$iface" ] && [ -n "$ip_addr" ]; then
      IPS_ENCONTRADOS=1
      print_row_color "IP (${iface}):" "\033[36m" "$ip_addr"
    fi
  done <<< "$IPS_RAW"
fi

if [ "$IPS_ENCONTRADOS" -eq 0 ]; then
  IP_FALLBACK=$(hostname -I 2>/dev/null | awk '{print $1}')
  print_row_color "IP Local:" "\033[36m" "${IP_FALLBACK:-N/A}"
fi

# Status do Firewall UFW
if (grep -qs -i "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null && systemctl is-active --quiet ufw 2>/dev/null) || (ufw status 2>/dev/null | grep -qi "^Status:[[:space:]]*active"); then
  UFW_COLOR="\033[1;32m"
  UFW_TXT="Ativo"
elif command -v ufw >/dev/null 2>&1 || [ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ] || [ -f /etc/default/ufw ] || [ -f /etc/ufw/ufw.conf ]; then
  UFW_COLOR="\033[1;33m"
  UFW_TXT="Inativo"
else
  UFW_COLOR="\033[1;33m"
  UFW_TXT="Não Instalado"
fi
print_row_color "Firewall UFW:" "$UFW_COLOR" "$UFW_TXT"

# Status de Reboot Pendente
if [ -e /var/run/reboot-required ]; then
  if [ -r /var/run/reboot-required.pkgs ] && grep -q 'linux-image' /var/run/reboot-required.pkgs 2>/dev/null; then
    REBOOT_TXT="Sim (atualização de kernel aguardando reinício)"
  else
    REBOOT_TXT="Sim (atualização pendente aguardando reinício)"
  fi
  print_row_color "Reboot Pendente:" "\033[1;33m" "$REBOOT_TXT"
else
  print_row_color "Reboot Pendente:" "\033[32m" "Não"
fi

echo -e "\033[1;36m================================================================\033[0m\n"
EOF

bash -n "$LOG_DIR/motd_banner.sh" || fatal "Falha na validação de sintaxe do script gerado de banner."

BANNER_STATE="Instalado"
if [[ -e /usr/local/bin/motd_banner.sh ]]; then
    [[ -f /usr/local/bin/motd_banner.sh && ! -L /usr/local/bin/motd_banner.sh ]] || fatal "Destino /usr/local/bin/motd_banner.sh não é um arquivo regular."
    if cmp -s -- "$LOG_DIR/motd_banner.sh" /usr/local/bin/motd_banner.sh; then
        BANNER_STATE="Já estava atualizado"
        log_info "Script /usr/local/bin/motd_banner.sh já possui a versão mais recente."
    else
        BANNER_STATE="Atualizado (backup da versão anterior salvo)"
        install_config "$LOG_DIR/motd_banner.sh" /usr/local/bin/motd_banner.sh 755
        log_success "Banner atualizado em /usr/local/bin/motd_banner.sh."
    fi
else
    install_config "$LOG_DIR/motd_banner.sh" /usr/local/bin/motd_banner.sh 755
    log_success "Banner instalado em /usr/local/bin/motd_banner.sh."
fi

# ==============================================================================
# 4 - INTEGRAÇÃO NO LOGIN INTERATIVO E COMANDO RÁPIDO
# ==============================================================================
ETAPA="integracao"
print_header "INTEGRAÇÃO NO LOGIN E COMANDO RÁPIDO"

cat > "$LOG_DIR/motd-profile" <<'EOF'
#!/bin/sh
# Exibe o banner apenas em terminais interativos, uma vez por sessão.
if [ -t 1 ] && [ -z "${__MOTD_SHOWN:-}" ] && [ -x /usr/local/bin/motd_banner.sh ]; then
    export __MOTD_SHOWN=1
    /usr/local/bin/motd_banner.sh
fi
EOF

PROFILE_STATE="Configurado"
if [[ -d /etc/profile.d ]]; then
    if [[ -f /etc/profile.d/motd_banner.sh && ! -L /etc/profile.d/motd_banner.sh ]] && cmp -s -- "$LOG_DIR/motd-profile" /etc/profile.d/motd_banner.sh; then
        log_info "Gatilho /etc/profile.d/motd_banner.sh já está atualizado."
    else
        install_config "$LOG_DIR/motd-profile" /etc/profile.d/motd_banner.sh 755
        log_success "Gatilho configurado em /etc/profile.d/motd_banner.sh."
    fi
else
    PROFILE_STATE="Diretório /etc/profile.d ausente"
    pendencia "Diretório /etc/profile.d não encontrado; disparo no login de perfil POSIX ignorado."
fi

BASHRC_STATE="Já integrado"
if [[ -f /etc/bash.bashrc ]]; then
    if ! grep -q 'motd_banner\.sh' /etc/bash.bashrc; then
        BASHRC_MODE=$(stat -c '%a' /etc/bash.bashrc 2>/dev/null || printf '644')
        { cat /etc/bash.bashrc; printf '\n'; cat "$LOG_DIR/motd-profile"; } > "$LOG_DIR/bash.bashrc"
        install_config "$LOG_DIR/bash.bashrc" /etc/bash.bashrc "$BASHRC_MODE"
        BASHRC_STATE="Integrado em /etc/bash.bashrc"
        log_success "Chamada adicionada ao /etc/bash.bashrc (shells interativos não-login)."
    else
        log_info "Chamada do banner já presente em /etc/bash.bashrc; preservado."
    fi
else
    BASHRC_STATE="/etc/bash.bashrc não presente"
    log_info "/etc/bash.bashrc não encontrado; disparo depende de /etc/profile.d."
fi

cat > "$LOG_DIR/motd-cmd" <<'EOF'
#!/bin/sh
exec /usr/local/bin/motd_banner.sh "$@"
EOF

if [[ -f /usr/local/bin/motd && ! -L /usr/local/bin/motd ]] && cmp -s -- "$LOG_DIR/motd-cmd" /usr/local/bin/motd; then
    log_info "Comando rápido /usr/local/bin/motd já está atualizado."
else
    install_config "$LOG_DIR/motd-cmd" /usr/local/bin/motd 755
    log_success "Comando rápido 'motd' disponibilizado em /usr/local/bin/motd."
fi

# ==============================================================================
# 5 - VERIFICAÇÃO FUNCIONAL E PRÉVIA DO BANNER
# ==============================================================================
ETAPA="verificacao"
print_header "VERIFICAÇÃO E PRÉVIA DO BANNER"

bash -n /usr/local/bin/motd_banner.sh || fatal "Script instalado falhou na validação bash -n."
PREVIEW_OUT=$(/usr/local/bin/motd_banner.sh --force) || fatal "Falha ao executar /usr/local/bin/motd_banner.sh --force."
printf '%s\n' "$PREVIEW_OUT"
DATA_DETECTADA=$(printf '%s\n' "$PREVIEW_OUT" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' | awk -F'Instalado em:[[:space:]]+' '/Instalado em:/ {print $2; exit}')
log_success "Prévia executada com sucesso."

# ==============================================================================
# 6 - RESUMO DA INSTALAÇÃO
# ==============================================================================
ETAPA="resumo"
print_header "RESUMO DA INSTALAÇÃO"
if (( ${#PENDENCIAS[@]} )); then
    log_warning "Processo concluído com pendências (código 3)."
else
    log_success "Banner dinâmico instalado/atualizado e validado com sucesso."
fi
draw_separator
print_summary "Versão do instalador:" "$VERSION"
print_summary "Sistema:" "$SISTEMA_ATUAL"
print_summary_section "BANNER DINÂMICO (MOTD)"
RESULT_COLOR=$FG_GREEN
print_summary "Estado do banner:" "$BANNER_STATE" "$RESULT_COLOR"
print_summary "Script principal:" "/usr/local/bin/motd_banner.sh"
print_summary "Comando rápido:" "motd (/usr/local/bin/motd)"
print_summary "Login profile.d:" "$PROFILE_STATE (/etc/profile.d/motd_banner.sh)"
print_summary "Bash interativo:" "$BASHRC_STATE"
print_summary "Data detectada (SO):" "${DATA_DETECTADA:-Não identificada}"
print_summary_section "AUDITORIA E PACOTES"
print_summary "Pacotes Instalados:" "Nenhum (script autônomo; usa ferramentas nativas)"
print_summary "Backups salvos:" "$BACKUP_DIR"
print_summary "Relatório:" "/root/$LOG_FILENAME"
draw_separator

if (( ${#PENDENCIAS[@]} )); then
    printf '\n%bPendências:%b\n' "${FG_YELLOW}${BOLD}" "$NC"
    for item in "${PENDENCIAS[@]}"; do printf '  %b- %s%b\n' "$FG_YELLOW" "$item" "$NC"; done
fi

# ==============================================================================
# 7 - GERAÇÃO E SALVAMENTO DOS LOGS (FINALIZADOR EXIT)
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"
log_info "O finalizador fechará a captura e salvará o relatório completo em /root e, quando aplicável, na home do usuário sudo."
exit 0
