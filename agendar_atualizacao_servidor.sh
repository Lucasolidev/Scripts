#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
readonly SCRIPT_VERSION="$VERSION"
# ==============================================================================
# SCRIPT DE AGENDAMENTO DE ATUALIZAÇÃO DO SERVIDOR (DEBIAN / UBUNTU)
# ==============================================================================
# Descrição: Agenda uma janela única (one-shot) via systemd timer para atualizar
#            pacotes via apt-get de forma não-interativa, com pré-checagem de
#            riscos (sintaxe de daemons, serviços disabled no boot, dpkg, Docker,
#            PM2, crons da madrugada), opção de hold temporário de containers e
#            bancos de dados, reboot condicional e auditoria pré-update x pós-boot.
# Autor: Lucas Oliveira
# Repositório: https://github.com/Lucasolidev/Scripts
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/agendar_atualizacao_servidor.sh -O agendar_atualizacao_servidor.sh && sudo chmod +x agendar_atualizacao_servidor.sh && sudo ./agendar_atualizacao_servidor.sh
# ==============================================================================
# Códigos de saída:
#   0 = Ação solicitada concluída e verificada
#   1 = Erro de execução ou pré-requisito ausente
#   2 = Operação cancelada pelo operador
#   3 = Concluído com pendências/alertas de prontidão
# ==============================================================================

set -Eeuo pipefail
umask 077

export VERSION
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export LC_ALL=C.UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==============================================================================
# 1 - INICIALIZAÇÃO, VALIDAÇÕES E FUNÇÕES BASE
# ==============================================================================

# 1.1 - PALETA DE CORES, ESTILOS ANSI E FUNÇÕES VISUAIS
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

readonly FG_BLUE='\033[94m'
readonly FG_CYAN='\033[36m'
readonly FG_YELLOW='\033[33m'
readonly FG_GREEN='\033[32m'
readonly FG_RED='\033[31m'
readonly FG_WHITE='\033[37m'

readonly ARROW="❯"

draw_separator() {
    printf '%b\n' "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    printf '\n%b\n' "${FG_BLUE}${BOLD}${ARROW} ${title}${NC}"
    draw_separator
}

get_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        printf '%b' "${FG_GREEN}Ativo${NC}"
    else
        printf '%b' "${FG_YELLOW}Inativo${NC}"
    fi
}

log_info()    { printf '%b %s\n' "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}     " "$1"; }
log_success() { printf '%b %s\n' "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}  " "$1"; }
log_warning() { printf '%b %s\n' "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}  " "$1"; }
log_error()   { printf '%b %s\n' "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}     " "$1" >&2; }
log_skipped() { printf '%b %s\n' "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}   " "$1"; }

print_alert_box() {
    local msg="$1"
    printf '\n  %b %b%s%b\n\n' "${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC}" "${FG_YELLOW}" "$msg" "${NC}"
}

print_summary() {
    local label="$1" value="$2" color="${3:-$FG_CYAN}"
    local padding=$((26 - ${#label}))
    if (( padding < 1 )); then padding=1; fi
    printf '  %b%s%*s%b%b%s%b\n' "$BOLD" "$label" "$padding" '' "$NC" "$color" "$value" "$NC"
}

format_systemd_br() {
    local raw="${1:-}"
    if [[ -z "$raw" || "$raw" == "n/a" || "$raw" == "Desconhecido" ]]; then
        printf '%s' "${raw:-Desconhecido}"
        return 0
    fi
    date -d "$raw" '+%d-%m-%Y %H:%M:%S (%Z)' 2>/dev/null || printf '%s' "$raw"
}

# 1.2 - CONSTANTES DE UNIDADES E ARTEFATOS ADMINISTRATIVOS
readonly BASE_DIR="/usr/local/lib/agendar-atualizacao-servidor"
readonly STATE_DIR="${BASE_DIR}/estado"
readonly RUNNER_SCRIPT="${BASE_DIR}/executar_atualizacao.sh"
readonly POSTBOOT_SCRIPT="${BASE_DIR}/verificar_posboot.sh"
readonly CONFIG_FILE="${BASE_DIR}/config.env"

readonly UNIT_NAME="agendar-atualizacao-servidor"
readonly SERVICE_FILE="/etc/systemd/system/${UNIT_NAME}.service"
readonly TIMER_FILE="/etc/systemd/system/${UNIT_NAME}.timer"
readonly POSTBOOT_UNIT="agendar-atualizacao-posboot"
readonly POSTBOOT_SERVICE_FILE="/etc/systemd/system/${POSTBOOT_UNIT}.service"

ETAPA="inicialização"
PENDENCIAS=()
PACOTES_INSTALADOS=()
ACAO_REALIZADA="Nenhuma"
DATA_HORA_AGENDADA="Não agendado"
PROXIMA_EXECUCAO="Não agendado"
MODO_UPGRADE_DESC="N/A"
HOLD_DOCKER_DESC="N/A"
HOLD_DB_DESC="N/A"
POLITICA_REBOOT_DESC="N/A"
POSBOOT_DESC="N/A"

pendencia() {
    PENDENCIAS+=("$1")
    log_warning "$1"
}

# Invocada indiretamente pelo trap ERR.
# shellcheck disable=SC2317,SC2329
erro_execucao() {
    log_error "Falha na etapa '${ETAPA}', linha $1 (código $2). Consulte o relatório."
}

# 1.3 - VALIDAÇÃO DE PRIVILÉGIOS, SISTEMA OPERACIONAL E PRÉ-REQUISITOS
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script precisa ser executado como root (use sudo)."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    log_error "Arquivo /etc/os-release não encontrado. Não foi possível identificar o SO."
    exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
OS_ID="${ID:-desconhecido}"
OS_ID_LIKE="${ID_LIKE:-}"
OS_PRETTY="${PRETTY_NAME:-Linux}"

case "$OS_ID" in
    debian|ubuntu) ;;
    *)
        if [[ "$OS_ID_LIKE" != *debian* && "$OS_ID_LIKE" != *ubuntu* ]]; then
            log_error "Sistema não suportado (${OS_PRETTY}). Este script suporta apenas Debian e Ubuntu (APT)."
            exit 1
        fi
        ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
    log_error "Comando 'apt-get' não encontrado."
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
    log_error "Systemd não está ativo neste ambiente. O agendamento one-shot exige systemd em execução."
    exit 1
fi

# 1.4 - FUNÇÕES DE ESCRITA ATÔMICA, CÓPIA SEGURA PARA HOME E LOGGING PADRONIZADO
install_config() {
    local src="$1" dest="$2" mode="${3:-644}" tmp
    [[ ! -L "$dest" ]] || { log_error "Destino administrativo é link simbólico: $dest"; return 1; }
    tmp=$(mktemp "$(dirname "$dest")/.agendar-upd.XXXXXXXX") || return 1
    if ! install -o root -g root -m "$mode" -- "$src" "$tmp" || ! mv -fT -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# Abre a origem como root e transmite pelo stdin; toda escrita na home ocorre sem root.
# shellcheck disable=SC2317,SC2329,SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 1
    runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        umask 077
        cd -- "$1"
        tmp=$(mktemp .agendar-upd.XXXXXXXX)
        trap '\''rm -f -- "$tmp"'\'' EXIT
        cat > "$tmp"
        mv -fT -- "$tmp" "$2"
    ' bash "$home_dir" "$name" < "$src"
}

LOG_TIMESTAMP="$(date '+%d%m%Y_%H%M')"
LOG_SUFFIX=""
if [[ -e "/root/relatorio_agendar_atualizacao_${LOG_TIMESTAMP}.log" ]]; then
    LOG_SUFFIX="_$(date '+%S')"
fi
LOG_FILENAME="relatorio_agendar_atualizacao_${LOG_TIMESTAMP}${LOG_SUFFIX}.log"
LOG_LATEST="relatorio_agendar_atualizacao_latest.log"

RUNTIME_DIR="$(mktemp -d -p /tmp agendar_atualizacao.XXXXXXXX)"
chmod 700 "$RUNTIME_DIR"
LOG_FILE="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"

REAL_USER="${SUDO_USER:-}"
REAL_USER_HOME=""
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
    REAL_USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 || true)"
fi

exec 3>&1 4>&2
exec > >(tee -a "$LOG_FILE") 2>&1
TEE_PID=$!

# Invocada indiretamente pelo trap EXIT.
# shellcheck disable=SC2317,SC2329
finalizar() {
    local rc="$1"
    local root_saved=0
    trap - EXIT ERR INT TERM HUP
    set +e

    if (( rc == 0 && ${#PENDENCIAS[@]} > 0 )); then
        rc=3
    fi

    printf '\n'
    draw_separator
    printf '  %bFinalizado em: %s (Código de saída: %s)%b\n\n' "$DIM" "$(date '+%d-%m-%Y %H:%M:%S')" "$rc" "$NC"

    exec 1>&3 2>&4
    wait "$TEE_PID" 2>/dev/null || true

    if install_config "$LOG_FILE" "/root/${LOG_FILENAME}" 600; then
        root_saved=1
        install_config "$LOG_FILE" "/root/${LOG_LATEST}" 600 || true
        log_success "Relatório salvo em: /root/${LOG_FILENAME}"
        log_info "Atalho atualizado: /root/${LOG_LATEST}"
    else
        log_error "Não foi possível salvar relatório em /root; preservado em: ${LOG_FILE}"
        rc=1
    fi

    if [[ -n "$REAL_USER" && -n "$REAL_USER_HOME" && -d "$REAL_USER_HOME" && "$root_saved" -eq 1 ]]; then
        if copy_to_home "$REAL_USER" "$REAL_USER_HOME" "/root/${LOG_FILENAME}" "$LOG_FILENAME" && \
           copy_to_home "$REAL_USER" "$REAL_USER_HOME" "/root/${LOG_FILENAME}" "$LOG_LATEST"; then
            log_success "Relatório salvo na Home (${REAL_USER}): ${REAL_USER_HOME}/${LOG_FILENAME}"
        else
            log_warning "Não foi possível copiar o relatório para a Home de ${REAL_USER}."
        fi
    fi

    if [[ "$root_saved" -eq 1 ]]; then
        rm -rf -- "$RUNTIME_DIR"
    fi

    exit "$rc"
}

trap 'erro_execucao "$LINENO" "$?"' ERR
trap 'finalizar $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ==============================================================================
# 2 - DIAGNÓSTICO E PRÉ-CHECAGEM DO SERVIDOR (PRE-FLIGHT CHECK)
# ==============================================================================
ETAPA="pré-checagem do servidor"

echo -e "${FG_CYAN}${BOLD}"
echo "================================================================"
echo "   AGENDADOR DE ATUALIZAÇÃO CONTROLADA (DISPARO ÚNICO)"
echo "   DEBIAN / UBUNTU — SYSTEMD TIMER + AUDITORIA PRÉ/PÓS-BOOT"
echo "================================================================"
echo -e "${NC}"
log_info "Versão do Script: v${SCRIPT_VERSION} | Host: $(hostname) | SO: ${OS_PRETTY}"
FUSO_ATUAL="$(timedatectl show -p Timezone --value 2>/dev/null || echo 'N/A')"
log_info "Data/Hora Atual: $(date '+%d-%m-%Y %H:%M:%S') (Fuso: ${FUSO_ATUAL})"
if [[ "$FUSO_ATUAL" == "UTC" || "$FUSO_ATUAL" == "Etc/UTC" ]]; then
    log_warning "Fuso horário do servidor está em ${FUSO_ATUAL}. O horário informado no agendamento seguirá o relógio local do servidor (não o horário de Brasília)."
fi

print_header "1. PRÉ-CHECAGEM DO SERVIDOR E PRONTIDÃO PARA ATUALIZAÇÃO"

# 2.1 - Kernel, reboot pendente e disco
KERNEL_ATUAL="$(uname -r)"
log_info "Kernel em execução: ${KERNEL_ATUAL}"

if [[ -f /var/run/reboot-required ]]; then
    REBOOT_PKGS=""
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        REBOOT_PKGS="$(tr '\n' ' ' < /var/run/reboot-required.pkgs | sed 's/ $//')"
    fi
    log_warning "Servidor JÁ possui reinicialização pendente (/var/run/reboot-required): ${REBOOT_PKGS:-motivo não listado}"
else
    log_success "Nenhuma reinicialização pendente no momento."
fi

USO_RAIZ="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
LIVRE_RAIZ="$(df -hP / | awk 'NR==2 {print $4}')"
if (( USO_RAIZ >= 90 )); then
    pendencia "Partição raiz (/) com ${USO_RAIZ}% de uso (Livre: ${LIVRE_RAIZ}). Libere espaço antes de atualizar."
else
    log_success "Espaço em disco (/): ${USO_RAIZ}% em uso (Livre: ${LIVRE_RAIZ})."
fi

if mountpoint -q /boot 2>/dev/null; then
    USO_BOOT="$(df -P /boot | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
    LIVRE_BOOT="$(df -hP /boot | awk 'NR==2 {print $4}')"
    if (( USO_BOOT >= 85 )); then
        pendencia "Partição /boot com ${USO_BOOT}% de uso (Livre: ${LIVRE_BOOT}). Atualizações de kernel podem falhar."
    else
        log_success "Espaço em disco (/boot): ${USO_BOOT}% em uso (Livre: ${LIVRE_BOOT})."
    fi
fi

# 2.2 - Integridade do dpkg e pacotes pendentes no APT
DPKG_AUDIT="$(dpkg --audit 2>&1 || true)"
if [[ -n "$DPKG_AUDIT" ]]; then
    pendencia "Banco de pacotes dpkg possui inconsistências ('dpkg --audit'). Execute 'sudo dpkg --configure -a' antes da janela."
else
    log_success "Integridade do banco dpkg ('dpkg --audit'): OK."
fi

log_info "Verificando pacotes pendentes no APT (simulação somente leitura)..."
PACOTES_PENDENTES_LISTA="$(apt-get -s upgrade 2>/dev/null | awk '/^Inst / {print $2}' || true)"
TOTAL_PENDENTES=0
if [[ -n "$PACOTES_PENDENTES_LISTA" ]]; then
    TOTAL_PENDENTES="$(printf '%s\n' "$PACOTES_PENDENTES_LISTA" | wc -l | tr -d ' ')"
fi

if (( TOTAL_PENDENTES > 0 )); then
    log_warning "Existem ${TOTAL_PENDENTES} pacote(s) pendente(s) no cache local do APT."
    CRITICOS_DETECTADOS="$(printf '%s\n' "$PACOTES_PENDENTES_LISTA" | grep -E '^(docker-ce|containerd|linux-image|systemd|libc6|openssh|postgresql|mysql|mariadb|percona|mongodb|redis|valkey|nginx|apache2|haproxy)' | tr '\n' ' ' | sed 's/ $//' || true)"
    if [[ -n "$CRITICOS_DETECTADOS" ]]; then
        log_warning "Pacotes críticos/sensíveis pendentes: ${CRITICOS_DETECTADOS}"
    fi
else
    log_info "Nenhum pacote pendente no cache local atual (o runner executará 'apt-get update' na hora agendada)."
fi

# 2.3 - Validação passiva de sintaxe de daemons ativos e persistência no boot
if (systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null) && command -v sshd >/dev/null 2>&1; then
    install -d -m 0755 -o root -g root /run/sshd 2>/dev/null || true
    if sshd -t >/dev/null 2>&1; then
        log_success "Sintaxe de configuração do OpenSSH ('sshd -t'): OK."
    else
        pendencia "Configuração atual do OpenSSH ('sshd -t') contém erro de sintaxe! Corrija antes de atualizar/reiniciar."
    fi
fi

if systemctl is-active --quiet apache2 2>/dev/null && command -v apache2ctl >/dev/null 2>&1; then
    if apache2ctl -t >/dev/null 2>&1; then
        log_success "Sintaxe de configuração do Apache ('apache2ctl -t'): OK."
    else
        pendencia "Configuração atual do Apache ('apache2ctl -t') contém erro de sintaxe! O serviço pode falhar ao reiniciar."
    fi
fi

if systemctl is-active --quiet nginx 2>/dev/null && command -v nginx >/dev/null 2>&1; then
    if nginx -t >/dev/null 2>&1; then
        log_success "Sintaxe de configuração do Nginx ('nginx -t'): OK."
    else
        pendencia "Configuração atual do Nginx ('nginx -t') contém erro de sintaxe! O serviço pode falhar ao reiniciar."
    fi
fi

if systemctl is-active --quiet haproxy 2>/dev/null && command -v haproxy >/dev/null 2>&1 && [[ -f /etc/haproxy/haproxy.cfg ]]; then
    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        log_success "Sintaxe de configuração do HAProxy ('haproxy -c'): OK."
    else
        pendencia "Configuração atual do HAProxy ('haproxy -c') contém erro de sintaxe! O serviço pode falhar ao reiniciar."
    fi
fi

SERVICOS_DISABLED_BOOT=()
while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    case "$svc" in
        user@*|session-*|getty@*|serial-getty@*|agendar-atualizacao-*|wpa_supplicant.service|ModemManager.service|bluetooth.service|cups-browsed.service)
            continue
            ;;
    esac
    SVC_ENABLED_STATE="$(systemctl is-enabled "$svc" 2>/dev/null || true)"
    if [[ "$SVC_ENABLED_STATE" == "disabled" ]]; then
        SVC_SOCKET="${svc%.service}.socket"
        if ! systemctl is-enabled --quiet "$SVC_SOCKET" 2>/dev/null && ! systemctl is-active --quiet "$SVC_SOCKET" 2>/dev/null; then
            SERVICOS_DISABLED_BOOT+=("$svc")
        fi
    fi
done < <(systemctl list-units --type=service --state=running --plain --no-legend --no-pager 2>/dev/null | awk '{print $1}')

if (( ${#SERVICOS_DISABLED_BOOT[@]} > 0 )); then
    pendencia "Serviço(s) em execução agora, mas DESABILITADO(S) no boot ('disabled' — não subirão após reboot): ${SERVICOS_DISABLED_BOOT[*]}"
else
    log_success "Persistência de boot dos serviços em execução: OK (nenhum daemon ativo marcado como 'disabled')."
fi

FAILED_PRE_EXISTENTES="$(systemctl list-units --state=failed --plain --no-legend --no-pager 2>/dev/null | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//' || true)"
if [[ -n "$FAILED_PRE_EXISTENTES" ]]; then
    log_warning "Unidade(s) systemd JÁ em estado FAILED antes da janela (serão tratadas como pré-existentes no pós-boot): ${FAILED_PRE_EXISTENTES}"
fi

# 2.4 - Detecção de Bancos de Dados no Host e Prontidão Docker (RestartPolicy)
BANCO_ATIVO="N"
BANCOS_HOST_DETECTADOS="$(dpkg-query -W -f='${Package}|${Status}\n' 'mariadb-server*' 'mysql-server*' 'percona-server*' 'postgresql*' 'mongodb-org-server*' 'redis-server*' 'valkey-server*' 2>/dev/null | awk -F'|' '$2 == "install ok installed" {print $1}' | tr '\n' ' ' | sed 's/ $//' || true)"
if [[ -n "$BANCOS_HOST_DETECTADOS" ]]; then
    BANCO_ATIVO="S"
    log_info "Servidor(es) de Banco de Dados instalado(s) no host: ${BANCOS_HOST_DETECTADOS}"
fi

DOCKER_ATIVO="N"
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
    DOCKER_ATIVO="S"
    CONTAINERS_ATIVOS="$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"
    log_info "Docker ativo com ${CONTAINERS_ATIVOS} container(s) em execução."

    SEM_RESTART=()
    while IFS='|' read -r cname cpolicy; do
        [[ -z "$cname" ]] && continue
        if [[ "$cpolicy" == "no" || -z "$cpolicy" ]]; then
            SEM_RESTART+=("$cname")
        fi
    done < <(docker ps -q 2>/dev/null | xargs -r docker inspect --format '{{.Name}}|{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null | sed 's|^/||')

    if (( ${#SEM_RESTART[@]} > 0 )); then
        pendencia "Containers SEM RestartPolicy (não voltarão sozinhos após reboot): ${SEM_RESTART[*]}"
    elif (( CONTAINERS_ATIVOS > 0 )); then
        log_success "Todos os ${CONTAINERS_ATIVOS} container(s) ativos possuem RestartPolicy configurada."
    fi
fi

# 2.5 - Prontidão PM2 e agendamentos da madrugada
if pgrep -f "PM2 v" >/dev/null 2>&1; then
    log_warning "PM2 detectado em execução. Antes de reiniciar, confirme se o desenvolvedor executou 'pm2 save' para atualizar o dump.pm2."
fi

CRONS_MADRUGADA=0
for u_cron in /var/spool/cron/crontabs/*; do
    [[ -f "$u_cron" ]] || continue
    if grep -Eq '^[0-9*,/-]+[[:space:]]+([0-5]|0[0-5])([,-][0-9]+)?[[:space:]]' "$u_cron" 2>/dev/null; then
        CRONS_MADRUGADA=$((CRONS_MADRUGADA + 1))
    fi
done
if (( CRONS_MADRUGADA > 0 )); then
    log_info "Foram detectados agendamentos de cron de usuário durante a madrugada (00h-05h). Escolha um horário fora do pico de backup/jobs (ex.: 01:00)."
fi

# 2.6 - Status de agendamento já existente
AGENDAMENTO_EXISTE="N"
if systemctl is-active --quiet "${UNIT_NAME}.timer" 2>/dev/null || [[ -f "$TIMER_FILE" ]]; then
    AGENDAMENTO_EXISTE="S"
    RAW_PROX_EXISTENTE="$(systemctl show -p NextElapseUSecRealtime --value "${UNIT_NAME}.timer" 2>/dev/null || echo 'Desconhecido')"
    PROX_EXISTENTE="$(format_systemd_br "$RAW_PROX_EXISTENTE")"
    log_warning "Já existe um agendamento de atualização configurado. Próximo disparo: ${PROX_EXISTENTE}"
else
    log_info "Nenhum agendamento de atualização pendente no momento."
fi

# ==============================================================================
# 3 - COLETA DE PARÂMETROS
# ==============================================================================
ETAPA="coleta de parâmetros"
print_header "2. COLETA DE PARÂMETROS"

printf '  %bEscolha a ação desejada:%b\n' "$BOLD" "$NC"
printf '    %b[1]%b Agendar atualização em disparo único (one-shot)\n' "$FG_CYAN" "$NC"
printf '    %b[2]%b Consultar status do agendamento e último relatório\n' "$FG_CYAN" "$NC"
printf '    %b[3]%b Cancelar agendamento pendente\n' "$FG_CYAN" "$NC"
printf '    %b[0]%b Sair sem alterações\n\n' "$FG_CYAN" "$NC"

OPCAO_MENU=""
while [[ -z "$OPCAO_MENU" ]]; do
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Selecione uma opção [1]: ${NC}")" ENTRADA_MENU
    ENTRADA_MENU="${ENTRADA_MENU:-1}"
    case "$ENTRADA_MENU" in
        0|1|2|3) OPCAO_MENU="$ENTRADA_MENU" ;;
        *) log_warning "Opção inválida. Digite 1, 2, 3 ou 0." ;;
    esac
done
log_info "Opção selecionada: ${OPCAO_MENU}"

if [[ "$OPCAO_MENU" == "0" ]]; then
    ACAO_REALIZADA="Cancelado pelo operador"
    log_skipped "Operação encerrada sem alterações."
    exit 2
fi

# ==============================================================================
# 3.1 - AÇÃO: CONSULTAR STATUS (OPÇÃO 2)
# ==============================================================================
if [[ "$OPCAO_MENU" == "2" ]]; then
    ETAPA="consulta de status"
    ACAO_REALIZADA="Consulta de status"
    print_header "3. STATUS DO AGENDAMENTO E ÚLTIMA EXECUÇÃO"

    if [[ -f "$TIMER_FILE" ]]; then
        log_info "Status do Timer (${UNIT_NAME}.timer): $(get_service_status "${UNIT_NAME}.timer")"
        systemctl list-timers --all "${UNIT_NAME}.timer" --no-pager 2>/dev/null || true
        if [[ -f "$CONFIG_FILE" ]]; then
            printf '\n'
            log_info "Parâmetros gravados em ${CONFIG_FILE}:"
            sed 's/^/      /' "$CONFIG_FILE"
        fi
    else
        log_info "Não há timer de atualização agendado no sistema."
    fi

    if [[ -f "$POSTBOOT_SERVICE_FILE" ]]; then
        log_warning "Verificador pós-boot ainda presente (${POSTBOOT_UNIT}.service)."
    fi

    if [[ -f "/root/relatorio_execucao_atualizacao_latest.log" ]]; then
        printf '\n'
        log_success "Último relatório de execução encontrado: /root/relatorio_execucao_atualizacao_latest.log"
        log_info "Últimas 20 linhas do relatório:"
        tail -n 20 "/root/relatorio_execucao_atualizacao_latest.log" | sed 's/^/      /'
    else
        log_info "Nenhum relatório de execução anterior encontrado em /root/."
    fi

    print_header "RESUMO DA INSTALAÇÃO"
    print_summary "Ação Executada:" "$ACAO_REALIZADA" "$FG_GREEN"
    print_summary "Pacotes Instalados:" "Nenhum" "$FG_CYAN"
    print_summary "Timer Ativo:" "$(if systemctl is-active --quiet "${UNIT_NAME}.timer" 2>/dev/null; then echo 'Sim'; else echo 'Não'; fi)" "$FG_CYAN"
    print_summary "Relatório:" "/root/${LOG_FILENAME}" "$FG_CYAN"
    exit 0
fi

# ==============================================================================
# 3.2 - AÇÃO: CANCELAR AGENDAMENTO (OPÇÃO 3)
# ==============================================================================
if [[ "$OPCAO_MENU" == "3" ]]; then
    ETAPA="cancelamento de agendamento"
    ACAO_REALIZADA="Cancelamento de agendamento"
    print_header "3. CANCELAMENTO DE AGENDAMENTO"

    if [[ "$AGENDAMENTO_EXISTE" == "N" && ! -f "$POSTBOOT_SERVICE_FILE" ]]; then
        log_info "Não existe nenhum agendamento ativo para cancelar."
    else
        read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Confirma o cancelamento do agendamento pendente? (s/N): ${NC}")" CONF_CANCEL
        log_info "Confirmação de cancelamento: ${CONF_CANCEL:-N}"
        if [[ "${CONF_CANCEL,,}" != "s" ]]; then
            log_skipped "Cancelamento abortado pelo operador."
            exit 2
        fi

        systemctl stop "${UNIT_NAME}.timer" 2>/dev/null || true
        systemctl disable "${UNIT_NAME}.timer" 2>/dev/null || true
        systemctl disable "${POSTBOOT_UNIT}.service" 2>/dev/null || true
        rm -f -- "$TIMER_FILE" "$SERVICE_FILE" "$POSTBOOT_SERVICE_FILE" "$CONFIG_FILE"
        systemctl daemon-reload
        systemctl reset-failed "${UNIT_NAME}.timer" "${UNIT_NAME}.service" "${POSTBOOT_UNIT}.service" 2>/dev/null || true
        log_success "Agendamento removido com sucesso."
    fi

    print_header "RESUMO DA INSTALAÇÃO"
    print_summary "Ação Executada:" "$ACAO_REALIZADA" "$FG_GREEN"
    print_summary "Pacotes Instalados:" "Nenhum" "$FG_CYAN"
    print_summary "Timer Ativo:" "Não" "$FG_GREEN"
    print_summary "Relatório:" "/root/${LOG_FILENAME}" "$FG_CYAN"
    exit 0
fi

# ==============================================================================
# 3.3 - COLETA DE PARÂMETROS PARA NOVO AGENDAMENTO (OPÇÃO 1)
# ==============================================================================
if [[ "$AGENDAMENTO_EXISTE" == "S" ]]; then
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Já existe um agendamento ativo. Deseja substituí-lo? (s/N): ${NC}")" CONF_SUB
    log_info "Substituir agendamento existente: ${CONF_SUB:-N}"
    if [[ "${CONF_SUB,,}" != "s" ]]; then
        log_skipped "Agendamento anterior preservado."
        exit 2
    fi
fi

# 3.3.1 - Data e hora do disparo único (formato BR DD-MM-YYYY)
CALENDAR_SPEC=""
while [[ -z "$CALENDAR_SPEC" ]]; do
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Informe o horário (HH:MM) ou data+hora (DD-MM-YYYY HH:MM) [01:00]: ${NC}")" ENTRADA_DATA
    ENTRADA_DATA="$(printf '%s' "${ENTRADA_DATA:-01:00}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    EPOCH_AGORA="$(date +%s)"
    CANDIDATO=""

    if [[ "$ENTRADA_DATA" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        HOJE="$(date '+%Y-%m-%d')"
        CANDIDATO="${HOJE} ${ENTRADA_DATA}:00"
        EPOCH_CAND="$(date -d "$CANDIDATO" +%s 2>/dev/null || echo 0)"
        if (( EPOCH_CAND <= EPOCH_AGORA + 60 )); then
            AMANHA="$(date -d 'tomorrow' '+%Y-%m-%d')"
            CANDIDATO="${AMANHA} ${ENTRADA_DATA}:00"
            EPOCH_CAND="$(date -d "$CANDIDATO" +%s 2>/dev/null || echo 0)"
        fi
    elif [[ "$ENTRADA_DATA" =~ ^([0-9]{2})[-/]([0-9]{2})[-/]([0-9]{4})[[:space:]]+([01][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        DIA_IN="${BASH_REMATCH[1]}"
        MES_IN="${BASH_REMATCH[2]}"
        ANO_IN="${BASH_REMATCH[3]}"
        HORA_IN="${BASH_REMATCH[4]}"
        MIN_IN="${BASH_REMATCH[5]}"
        CANDIDATO="${ANO_IN}-${MES_IN}-${DIA_IN} ${HORA_IN}:${MIN_IN}:00"
        VALIDA_ISO="$(date -d "$CANDIDATO" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
        if [[ "$VALIDA_ISO" != "$CANDIDATO" ]]; then
            log_warning "Data inexistente no calendário (${DIA_IN}-${MES_IN}-${ANO_IN}). Verifique o dia e o mês informados."
            continue
        fi
        EPOCH_CAND="$(date -d "$CANDIDATO" +%s 2>/dev/null || echo 0)"
    else
        log_warning "Formato inválido. Use HH:MM (ex: 01:00) ou DD-MM-YYYY HH:MM (ex: $(date -d 'tomorrow' '+%d-%m-%Y') 01:00)."
        continue
    fi

    CANDIDATO_BR="$(date -d "$CANDIDATO" '+%d-%m-%Y %H:%M:%S' 2>/dev/null || echo "$CANDIDATO")"

    if (( EPOCH_CAND <= EPOCH_AGORA + 60 )); then
        log_warning "A data/hora informada (${CANDIDATO_BR}) deve ser pelo menos 1 minuto no futuro."
        continue
    fi

    if command -v systemd-analyze >/dev/null 2>&1; then
        if ! systemd-analyze calendar "$CANDIDATO" >/dev/null 2>&1; then
            log_warning "Expressão de calendário rejeitada pelo systemd: ${CANDIDATO_BR}"
            continue
        fi
    fi

    CALENDAR_SPEC="$CANDIDATO"
    DATA_HORA_AGENDADA="$CANDIDATO_BR"
    log_info "Disparo único agendado para: ${DATA_HORA_AGENDADA}"
done

# 3.3.2 - Modo de atualização APT
printf '\n  %bEscopo da atualização via apt-get:%b\n' "$BOLD" "$NC"
printf '    %b[1]%b upgrade (Recomendado — conservador, não remove pacotes)\n' "$FG_CYAN" "$NC"
printf '    %b[2]%b dist-upgrade (Inclui novos kernels/dependências adicionais)\n\n' "$FG_CYAN" "$NC"

MODO_UPGRADE=""
while [[ -z "$MODO_UPGRADE" ]]; do
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Escolha o modo de atualização [1]: ${NC}")" ENTRADA_MODO
    ENTRADA_MODO="${ENTRADA_MODO:-1}"
    case "$ENTRADA_MODO" in
        1)
            MODO_UPGRADE="upgrade"
            MODO_UPGRADE_DESC="apt-get upgrade (conservador)"
            ;;
        2)
            MODO_UPGRADE="dist-upgrade"
            MODO_UPGRADE_DESC="apt-get dist-upgrade (completo)"
            ;;
        *) log_warning "Opção inválida. Digite 1 ou 2." ;;
    esac
done
log_info "Modo de atualização definido: ${MODO_UPGRADE_DESC}"

# 3.3.3 - Opção de pular atualização de Containers (Docker) ou Bancos de Dados nesta janela
HOLD_DOCKER="N"
if [[ "$DOCKER_ATIVO" == "S" ]]; then
    printf '\n  %bPacotes de Containers (Docker / containerd):%b\n' "$BOLD" "$NC"
    printf '    %b• ENTER / N = Atualiza o Docker junto com o Linux (padrão)%b\n' "$DIM" "$NC"
    printf '    %b• s         = Pula o Docker nesta janela (atualiza apenas o Linux)%b\n\n' "$DIM" "$NC"
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Pular a atualização do Docker/containerd nesta janela? (s/N): ${NC}")" ENTRADA_HOLD
    if [[ "${ENTRADA_HOLD,,}" == "s" ]]; then
        HOLD_DOCKER="S"
        HOLD_DOCKER_DESC="Pular Docker (atualizar apenas o SO)"
    else
        HOLD_DOCKER="N"
        HOLD_DOCKER_DESC="Atualizar Docker junto com o SO"
    fi
else
    HOLD_DOCKER_DESC="Não aplicável (Docker inativo)"
fi
log_info "Containers (Docker) nesta janela: ${HOLD_DOCKER_DESC}"

HOLD_DB="N"
if [[ "$BANCO_ATIVO" == "S" ]]; then
    printf '\n  %bPacotes de Banco de Dados (%s):%b\n' "$BOLD" "$BANCOS_HOST_DETECTADOS" "$NC"
    printf '    %b• ENTER / N = Atualiza o Banco junto com o Linux (padrão)%b\n' "$DIM" "$NC"
    printf '    %b• s         = Pula o Banco nesta janela (atualiza apenas o Linux)%b\n\n' "$DIM" "$NC"
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Pular a atualização do Banco de Dados nesta janela? (s/N): ${NC}")" ENTRADA_HOLD_DB
    if [[ "${ENTRADA_HOLD_DB,,}" == "s" ]]; then
        HOLD_DB="S"
        HOLD_DB_DESC="Pular Banco de Dados (atualizar apenas o SO)"
    else
        HOLD_DB="N"
        HOLD_DB_DESC="Atualizar Banco de Dados junto com o SO"
    fi
else
    HOLD_DB_DESC="Não aplicável (nenhum SGBD detectado no host)"
fi
log_info "Banco de Dados nesta janela: ${HOLD_DB_DESC}"

# 3.3.4 - Política de reinicialização
printf '\n  %bPolítica de reinicialização após a atualização:%b\n' "$BOLD" "$NC"
printf '    %b[1]%b Reiniciar APENAS se /var/run/reboot-required existir (Recomendado)\n' "$FG_CYAN" "$NC"
printf '    %b[2]%b Sempre reiniciar após atualização bem-sucedida\n' "$FG_CYAN" "$NC"
printf '    %b[3]%b NÃO reiniciar (apenas aplicar pacotes e registrar status)\n\n' "$FG_CYAN" "$NC"

POLITICA_REBOOT=""
while [[ -z "$POLITICA_REBOOT" ]]; do
    read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Escolha a política de reboot [1]: ${NC}")" ENTRADA_REBOOT
    ENTRADA_REBOOT="${ENTRADA_REBOOT:-1}"
    case "$ENTRADA_REBOOT" in
        1)
            POLITICA_REBOOT="if-required"
            POLITICA_REBOOT_DESC="Condicional (se /var/run/reboot-required)"
            POSBOOT_DESC="Ativada automaticamente se houver reboot (aguarda 90s)"
            ;;
        2)
            POLITICA_REBOOT="always"
            POLITICA_REBOOT_DESC="Sempre reiniciar após sucesso"
            POSBOOT_DESC="Ativada automaticamente (aguarda 90s após boot)"
            ;;
        3)
            POLITICA_REBOOT="never"
            POLITICA_REBOOT_DESC="Não reiniciar automaticamente"
            POSBOOT_DESC="Desativada (sem reboot)"
            ;;
        *) log_warning "Opção inválida. Digite 1, 2 ou 3." ;;
    esac
done
log_info "Política de reinicialização definida: ${POLITICA_REBOOT_DESC}"

# 3.3.5 - Confirmação final antes de gravar o agendamento
print_alert_box "Confirme os dados antes de ativar o disparo único:
    • Horário:       ${DATA_HORA_AGENDADA}
    • Atualização:   ${MODO_UPGRADE_DESC}
    • Containers:    ${HOLD_DOCKER_DESC}
    • Banco Dados:   ${HOLD_DB_DESC}
    • Reboot:        ${POLITICA_REBOOT_DESC}
    • Pós-Boot:      ${POSBOOT_DESC}
    • Garantia:      Disparo único (o timer se auto-remove após executar)"

read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Confirma a criação deste agendamento? (s/N): ${NC}")" CONF_FINAL
log_info "Confirmação final: ${CONF_FINAL:-N}"
if [[ "${CONF_FINAL,,}" != "s" ]]; then
    ACAO_REALIZADA="Cancelado pelo operador"
    log_skipped "Agendamento cancelado pelo operador. Nenhuma alteração foi feita."
    exit 2
fi

# ==============================================================================
# 4 - INSTALAÇÃO DOS SCRIPTS RUNNER E VERIFICADOR PÓS-BOOT
# ==============================================================================
ETAPA="instalação dos scripts internos"
print_header "3. INSTALAÇÃO DO RUNNER E VERIFICADOR PÓS-BOOT"

install -d -m 0700 -o root -g root "$BASE_DIR" "$STATE_DIR"

# 4.1 - Arquivo de configuração da janela agendada
cat > "${RUNTIME_DIR}/config.env" <<EOF
# Configuração gerada por agendar_atualizacao_servidor.sh v${SCRIPT_VERSION}
DATA_HORA_BR="${DATA_HORA_AGENDADA}"
CALENDAR_SPEC="${CALENDAR_SPEC}"
MODO_UPGRADE="${MODO_UPGRADE}"
HOLD_DOCKER="${HOLD_DOCKER}"
HOLD_DB="${HOLD_DB}"
POLITICA_REBOOT="${POLITICA_REBOOT}"
REAL_USER="${REAL_USER}"
REAL_USER_HOME="${REAL_USER_HOME}"
EOF
install_config "${RUNTIME_DIR}/config.env" "$CONFIG_FILE" 600
log_success "Configuração salva em ${CONFIG_FILE}"

# 4.2 - Script executor principal (executar_atualizacao.sh)
cat > "${RUNTIME_DIR}/executar_atualizacao.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
umask 077

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export LC_ALL=C.UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

readonly BASE_DIR="/usr/local/lib/agendar-atualizacao-servidor"
readonly STATE_DIR="${BASE_DIR}/estado"
readonly CONFIG_FILE="${BASE_DIR}/config.env"
readonly LOCK_FILE="/run/agendar-atualizacao-servidor.lock"

readonly UNIT_NAME="agendar-atualizacao-servidor"
readonly SERVICE_FILE="/etc/systemd/system/${UNIT_NAME}.service"
readonly TIMER_FILE="/etc/systemd/system/${UNIT_NAME}.timer"
readonly POSTBOOT_UNIT="agendar-atualizacao-posboot"
readonly POSTBOOT_SERVICE_FILE="/etc/systemd/system/${POSTBOOT_UNIT}.service"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "[ERRO] Outra instância de atualização agendada já está em execução." >&2
    exit 1
fi

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "[ERRO] Arquivo de configuração ausente: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

TS="$(date '+%d%m%Y_%H%M')"
REPORT_NAME="relatorio_execucao_atualizacao_${TS}.log"
REPORT_LATEST="relatorio_execucao_atualizacao_latest.log"
REPORT_PATH="/root/${REPORT_NAME}"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
touch "$REPORT_PATH"
chmod 600 "$REPORT_PATH"

# shellcheck disable=SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ -n "$user" && "$user" != "root" && "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 0
    [[ -d "$home_dir" ]] || return 0
    runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        umask 077
        cd -- "$1"
        tmp=$(mktemp .upd-report.XXXXXXXX)
        trap '\''rm -f -- "$tmp"'\'' EXIT
        cat > "$tmp"
        mv -fT -- "$tmp" "$2"
    ' bash "$home_dir" "$name" < "$src" || true
}

HELD_BY_US=()
restaurar_holds() {
    if (( ${#HELD_BY_US[@]} > 0 )); then
        echo "[INFO] Restaurando unhold temporário: ${HELD_BY_US[*]}"
        apt-mark unhold "${HELD_BY_US[@]}" >/dev/null 2>&1 || true
    fi
}

remover_agendamento_unico() {
    systemctl disable "${UNIT_NAME}.timer" >/dev/null 2>&1 || true
    rm -f -- "$TIMER_FILE" "$SERVICE_FILE"
    systemctl daemon-reload >/dev/null 2>&1 || true
}

publicar_relatorio() {
    cp -f -- "$REPORT_PATH" "/root/${REPORT_LATEST}" 2>/dev/null || true
    chmod 600 "/root/${REPORT_LATEST}" 2>/dev/null || true
    copy_to_home "${REAL_USER:-}" "${REAL_USER_HOME:-}" "$REPORT_PATH" "$REPORT_NAME"
    copy_to_home "${REAL_USER:-}" "${REAL_USER_HOME:-}" "$REPORT_PATH" "$REPORT_LATEST"
}

trap 'restaurar_holds; remover_agendamento_unico; publicar_relatorio' EXIT

{
    echo "================================================================"
    echo "   RELATÓRIO DE EXECUÇÃO — ATUALIZAÇÃO AGENDADA (DISPARO ÚNICO)"
    echo "================================================================"
    echo "  Host:              $(hostname)"
    echo "  Início:            $(date '+%d-%m-%Y %H:%M:%S')"
    echo "  Kernel Pré-Update: $(uname -r)"
    echo "  Modo APT:          ${MODO_UPGRADE}"
    echo "  Hold Docker:       ${HOLD_DOCKER:-N}"
    echo "  Hold Banco Dados:  ${HOLD_DB:-N}"
    echo "  Política Reboot:   ${POLITICA_REBOOT}"
    echo "================================================================"
    echo ""

    # 1. Snapshot Pré-Update
    echo ">>> [1/5] Capturando snapshot PRÉ-UPDATE..."
    uname -r > "${STATE_DIR}/pre_kernel.txt"
    echo "$REPORT_PATH" > "${STATE_DIR}/last_report_path.txt"
    echo "$REPORT_NAME" > "${STATE_DIR}/last_report_name.txt"

    systemctl list-units --type=service --state=running --plain --no-legend --no-pager \
        | awk '{print $1}' | sort -u > "${STATE_DIR}/pre_services.txt"

    systemctl list-units --state=failed --plain --no-legend --no-pager \
        | awk '{print $1}' | sort -u > "${STATE_DIR}/pre_failed.txt" || true

    ss -tlnH 2>/dev/null | awk '{print $4}' | sed -E 's/.*:([0-9]+)$/\1/' | sort -nu > "${STATE_DIR}/pre_ports.txt" || true

    if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
        docker ps --format '{{.Names}}' 2>/dev/null | sort -u > "${STATE_DIR}/pre_containers.txt"
    else
        : > "${STATE_DIR}/pre_containers.txt"
    fi

    echo "  - Serviços systemd ativos: $(wc -l < "${STATE_DIR}/pre_services.txt")"
    echo "  - Unidades systemd em falha prévia: $(wc -l < "${STATE_DIR}/pre_failed.txt")"
    echo "  - Containers Docker ativos: $(wc -l < "${STATE_DIR}/pre_containers.txt")"
    echo "  - Portas TCP em LISTEN: $(wc -l < "${STATE_DIR}/pre_ports.txt")"
    echo ""

    # 2. Hold temporário opcional de Docker/containerd e Bancos de Dados
    JA_EM_HOLD="$(apt-mark showhold 2>/dev/null || true)"
    if [[ "${HOLD_DOCKER:-N}" == "S" || "${HOLD_DB:-N}" == "S" ]]; then
        echo ">>> [2/5] Aplicando hold temporário configurado para esta janela..."
        CANDIDATOS_HOLD=()

        if [[ "${HOLD_DOCKER:-N}" == "S" ]]; then
            for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras; do
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    CANDIDATOS_HOLD+=("$pkg")
                fi
            done
        fi

        if [[ "${HOLD_DB:-N}" == "S" ]]; then
            while IFS= read -r db_pkg; do
                [[ -n "$db_pkg" ]] && CANDIDATOS_HOLD+=("$db_pkg")
            done < <(dpkg-query -W -f='${Package}|${Status}\n' 2>/dev/null \
                | awk -F'|' '$2 == "install ok installed" && $1 ~ /^(mariadb-|mysql-|libmysqlclient|libmariadb|percona-server|postgresql|mongodb-org|redis-|valkey-)/ {print $1}')
        fi

        if (( ${#CANDIDATOS_HOLD[@]} > 0 )); then
            for pkg in "${CANDIDATOS_HOLD[@]}"; do
                if ! printf '%s\n' "$JA_EM_HOLD" | grep -qx "$pkg"; then
                    if apt-mark hold "$pkg" >/dev/null 2>&1; then
                        HELD_BY_US+=("$pkg")
                    fi
                fi
            done
        fi

        if (( ${#HELD_BY_US[@]} > 0 )); then
            echo "  - Pacotes mantidos em hold temporário: ${HELD_BY_US[*]}"
        else
            echo "  - Nenhum pacote adicional precisou de hold."
        fi
        echo ""
    else
        echo ">>> [2/5] Hold temporário desativado (todos os pacotes elegíveis serão atualizados)."
        echo ""
    fi

    # 3. Atualização APT não-interativa
    echo ">>> [3/5] Executando apt-get update e apt-get ${MODO_UPGRADE}..."
    APT_OK=0
    if apt-get -o DPkg::Lock::Timeout=180 update && \
       apt-get -o DPkg::Lock::Timeout=180 \
               -o Dpkg::Options::="--force-confdef" \
               -o Dpkg::Options::="--force-confold" \
               -y "${MODO_UPGRADE}"; then
        APT_OK=1
        echo ""
        echo "[SUCESSO] Atualização APT concluída sem erros."
    else
        echo ""
        echo "[ERRO] Falha durante a atualização APT. O reinício automático foi ABORTADO por segurança."
    fi
    echo ""

    # 4. Restaurar holds e remover o timer one-shot
    echo ">>> [4/5] Limpando agendamento one-shot e restaurando holds temporários..."
    restaurar_holds
    HELD_BY_US=()
    remover_agendamento_unico
    echo "  - Timer one-shot removido (não haverá reexecução automática)."
    echo ""

    # 5. Decisão de reboot
    echo ">>> [5/5] Avaliando política de reinicialização (${POLITICA_REBOOT})..."
    DEVE_REINICIAR=0
    if [[ "$APT_OK" -eq 1 ]]; then
        case "$POLITICA_REBOOT" in
            always)
                DEVE_REINICIAR=1
                echo "  - Política 'always': reinicialização autorizada."
                ;;
            if-required)
                if [[ -f /var/run/reboot-required ]]; then
                    DEVE_REINICIAR=1
                    echo "  - Arquivo /var/run/reboot-required detectado: reinicialização necessária e autorizada."
                else
                    echo "  - Nenhum reboot necessário (/var/run/reboot-required ausente)."
                fi
                ;;
            never)
                if [[ -f /var/run/reboot-required ]]; then
                    echo "  - [ATENÇÃO] Reboot pendente (/var/run/reboot-required), mas política definida como 'never'."
                else
                    echo "  - Política 'never': sem reinicialização."
                fi
                ;;
        esac
    fi

    if [[ "$DEVE_REINICIAR" -eq 1 ]]; then
        echo "  - Habilitando verificador pós-boot (${POSTBOOT_UNIT}.service)..."
        if [[ -f "$POSTBOOT_SERVICE_FILE" ]]; then
            systemctl enable "${POSTBOOT_UNIT}.service" >/dev/null 2>&1 || true
        fi
        echo "  - Encerramento gracioso e reinicialização em 5 segundos ($(date '+%d-%m-%Y %H:%M:%S'))..."
        publicar_relatorio
        sync
        sleep 5
        systemctl reboot
    else
        echo "  - Execução concluída sem reboot em: $(date '+%d-%m-%Y %H:%M:%S')"
    fi
} >> "$REPORT_PATH" 2>&1
EOF
install_config "${RUNTIME_DIR}/executar_atualizacao.sh" "$RUNNER_SCRIPT" 700
log_success "Runner instalado em ${RUNNER_SCRIPT}"

# 4.3 - Script verificador pós-boot (verificar_posboot.sh)
cat > "${RUNTIME_DIR}/verificar_posboot.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
umask 077

export LC_ALL=C.UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

readonly BASE_DIR="/usr/local/lib/agendar-atualizacao-servidor"
readonly STATE_DIR="${BASE_DIR}/estado"
readonly CONFIG_FILE="${BASE_DIR}/config.env"
readonly POSTBOOT_UNIT="agendar-atualizacao-posboot"
readonly POSTBOOT_SERVICE_FILE="/etc/systemd/system/${POSTBOOT_UNIT}.service"

if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

REPORT_PATH="$(cat "${STATE_DIR}/last_report_path.txt" 2>/dev/null || echo "/root/relatorio_execucao_atualizacao_latest.log")"
REPORT_NAME="$(cat "${STATE_DIR}/last_report_name.txt" 2>/dev/null || basename "$REPORT_PATH")"
REPORT_LATEST="relatorio_execucao_atualizacao_latest.log"

# Aguarda estabilização de containers Docker, PM2 e serviços após boot
sleep 90

# shellcheck disable=SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ -n "$user" && "$user" != "root" && "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 0
    [[ -d "$home_dir" ]] || return 0
    runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        umask 077
        cd -- "$1"
        tmp=$(mktemp .upd-report.XXXXXXXX)
        trap '\''rm -f -- "$tmp"'\'' EXIT
        cat > "$tmp"
        mv -fT -- "$tmp" "$2"
    ' bash "$home_dir" "$name" < "$src" || true
}

{
    echo ""
    echo "================================================================"
    echo "   VERIFICAÇÃO AUTOMÁTICA PÓS-BOOT (ANTES x DEPOIS)"
    echo "================================================================"
    echo "  Verificado em:     $(date '+%d-%m-%Y %H:%M:%S')"
    echo "  Kernel Pré-Update: $(cat "${STATE_DIR}/pre_kernel.txt" 2>/dev/null || echo 'N/A')"
    echo "  Kernel Pós-Boot:   $(uname -r)"
    echo "  Uptime Atual:      $(uptime -p 2>/dev/null || uptime)"
    echo ""

    ALERTAS=0

    # Comparar Containers Docker
    if [[ -f "${STATE_DIR}/pre_containers.txt" ]]; then
        if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
            docker ps --format '{{.Names}}' 2>/dev/null | sort -u > "${STATE_DIR}/post_containers.txt"
        else
            : > "${STATE_DIR}/post_containers.txt"
        fi

        FALTANDO_CONTAINERS="$(comm -23 "${STATE_DIR}/pre_containers.txt" "${STATE_DIR}/post_containers.txt" || true)"
        if [[ -n "$FALTANDO_CONTAINERS" ]]; then
            ALERTAS=$((ALERTAS + 1))
            echo "  [ATENÇÃO] Containers que estavam rodando ANTES e NÃO voltaram:"
            printf '%s\n' "$FALTANDO_CONTAINERS" | sed 's/^/      - /'
        else
            echo "  [OK] Todos os containers Docker ativos antes do reboot voltaram normalmente ($(wc -l < "${STATE_DIR}/post_containers.txt") ativo(s))."
        fi
    fi

    # Comparar Serviços Systemd
    if [[ -f "${STATE_DIR}/pre_services.txt" ]]; then
        systemctl list-units --type=service --state=running --plain --no-legend --no-pager \
            | awk '{print $1}' | sort -u > "${STATE_DIR}/post_services.txt"

        FALTANDO_SERVICES="$(comm -23 "${STATE_DIR}/pre_services.txt" "${STATE_DIR}/post_services.txt" \
            | grep -Ev '^(agendar-atualizacao-|systemd-fsck|user@|session-)' || true)"
        if [[ -n "$FALTANDO_SERVICES" ]]; then
            ALERTAS=$((ALERTAS + 1))
            echo "  [ATENÇÃO] Serviços systemd que estavam ativos ANTES e NÃO voltaram:"
            printf '%s\n' "$FALTANDO_SERVICES" | sed 's/^/      - /'
        else
            echo "  [OK] Todos os serviços systemd monitorados voltaram normalmente."
        fi
    fi

    # Comparar Portas TCP LISTEN
    if [[ -f "${STATE_DIR}/pre_ports.txt" ]]; then
        ss -tlnH 2>/dev/null | awk '{print $4}' | sed -E 's/.*:([0-9]+)$/\1/' | sort -nu > "${STATE_DIR}/post_ports.txt" || true
        FALTANDO_PORTS="$(comm -23 "${STATE_DIR}/pre_ports.txt" "${STATE_DIR}/post_ports.txt" || true)"
        if [[ -n "$FALTANDO_PORTS" ]]; then
            ALERTAS=$((ALERTAS + 1))
            echo "  [ATENÇÃO] Portas TCP em LISTEN antes do reboot que NÃO estão escutando agora:"
            printf '%s\n' "$FALTANDO_PORTS" | sed 's/^/      - porta /'
        else
            echo "  [OK] Todas as portas TCP em LISTEN voltaram normalmente."
        fi
    fi

    # Unidades com falha (diferenciando falhas novas x pré-existentes)
    systemctl list-units --state=failed --plain --no-legend --no-pager 2>/dev/null \
        | awk '{print $1}' | sort -u > "${STATE_DIR}/post_failed.txt" || true
    if [[ ! -f "${STATE_DIR}/pre_failed.txt" ]]; then
        : > "${STATE_DIR}/pre_failed.txt"
    fi

    NOVAS_FALHAS="$(comm -13 "${STATE_DIR}/pre_failed.txt" "${STATE_DIR}/post_failed.txt" || true)"
    FALHAS_PREVIAS="$(comm -12 "${STATE_DIR}/pre_failed.txt" "${STATE_DIR}/post_failed.txt" || true)"

    if [[ -n "$NOVAS_FALHAS" ]]; then
        ALERTAS=$((ALERTAS + 1))
        echo "  [ATENÇÃO] NOVAS unidades systemd em estado FAILED após a atualização/boot:"
        printf '%s\n' "$NOVAS_FALHAS" | sed 's/^/      - /'
    else
        echo "  [OK] Nenhuma nova unidade systemd entrou em estado FAILED após o boot."
    fi

    if [[ -n "$FALHAS_PREVIAS" ]]; then
        echo "  [INFO] Unidades que JÁ estavam em estado FAILED antes da janela (pré-existentes):"
        printf '%s\n' "$FALHAS_PREVIAS" | sed 's/^/      - /'
    fi

    echo ""
    if (( ALERTAS == 0 )); then
        echo "  VEREDITO PÓS-BOOT: SUCESSO — Todos os serviços, containers e portas validados."
    else
        echo "  VEREDITO PÓS-BOOT: ATENÇÃO (${ALERTAS} alerta(s)) — Revise os itens acima (se crítico, avalie rollback Veeam)."
    fi
    echo "================================================================"
} >> "$REPORT_PATH" 2>&1

cp -f -- "$REPORT_PATH" "/root/${REPORT_LATEST}" 2>/dev/null || true
chmod 600 "/root/${REPORT_LATEST}" 2>/dev/null || true
copy_to_home "${REAL_USER:-}" "${REAL_USER_HOME:-}" "$REPORT_PATH" "$REPORT_NAME"
copy_to_home "${REAL_USER:-}" "${REAL_USER_HOME:-}" "$REPORT_PATH" "$REPORT_LATEST"

# Auto-limpeza do verificador pós-boot (disparo único)
systemctl disable "${POSTBOOT_UNIT}.service" >/dev/null 2>&1 || true
rm -f -- "$POSTBOOT_SERVICE_FILE"
systemctl daemon-reload >/dev/null 2>&1 || true
EOF
install_config "${RUNTIME_DIR}/verificar_posboot.sh" "$POSTBOOT_SCRIPT" 700
log_success "Verificador pós-boot instalado em ${POSTBOOT_SCRIPT}"

# ==============================================================================
# 5 - CRIAÇÃO E ATIVAÇÃO DAS UNIDADES SYSTEMD (DISPARO ÚNICO)
# ==============================================================================
ETAPA="criação e ativação das unidades systemd"
print_header "4. CRIAÇÃO E ATIVAÇÃO DO TIMER ONE-SHOT (SYSTEMD)"

# 5.1 - Unidade de serviço da atualização
cat > "${RUNTIME_DIR}/${UNIT_NAME}.service" <<EOF
[Unit]
Description=Atualização Agendada do Servidor (Disparo Único)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${RUNNER_SCRIPT}
StandardOutput=journal
StandardError=journal
EOF
install_config "${RUNTIME_DIR}/${UNIT_NAME}.service" "$SERVICE_FILE" 644

# 5.2 - Unidade de timer one-shot
cat > "${RUNTIME_DIR}/${UNIT_NAME}.timer" <<EOF
[Unit]
Description=Timer One-Shot para Atualização Agendada do Servidor

[Timer]
OnCalendar=${CALENDAR_SPEC}
Persistent=false
AccuracySec=1s
Unit=${UNIT_NAME}.service

[Install]
WantedBy=timers.target
EOF
install_config "${RUNTIME_DIR}/${UNIT_NAME}.timer" "$TIMER_FILE" 644

# 5.3 - Unidade de serviço pós-boot (fica criada, mas só é habilitada pelo runner se houver reboot)
cat > "${RUNTIME_DIR}/${POSTBOOT_UNIT}.service" <<EOF
[Unit]
Description=Verificação Pós-Boot da Atualização Agendada (Disparo Único)
After=network-online.target multi-user.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${POSTBOOT_SCRIPT}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
install_config "${RUNTIME_DIR}/${POSTBOOT_UNIT}.service" "$POSTBOOT_SERVICE_FILE" 644
systemctl disable "${POSTBOOT_UNIT}.service" >/dev/null 2>&1 || true

# 5.4 - Recarregar systemd e ativar timer
systemctl daemon-reload
systemctl enable --now "${UNIT_NAME}.timer" >/dev/null

if systemctl is-active --quiet "${UNIT_NAME}.timer"; then
    RAW_PROXIMA="$(systemctl show -p NextElapseUSecRealtime --value "${UNIT_NAME}.timer" 2>/dev/null || echo "$DATA_HORA_AGENDADA")"
    PROXIMA_EXECUCAO="$(format_systemd_br "$RAW_PROXIMA")"
    ACAO_REALIZADA="Agendamento criado e ativado"
    log_success "Timer ${UNIT_NAME}.timer ativado com sucesso!"
    log_info "Próximo disparo confirmado pelo systemd: ${PROXIMA_EXECUCAO}"
else
    log_error "O timer ${UNIT_NAME}.timer não ficou ativo após habilitação."
    exit 1
fi

# ==============================================================================
# 6 - RESUMO DA INSTALAÇÃO E ENCERRAMENTO
# ==============================================================================
ETAPA="resumo final"
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES="$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")"

print_summary "Ação Executada:" "$ACAO_REALIZADA" "$FG_GREEN"
print_summary "Versão do Script:" "v${SCRIPT_VERSION}" "$FG_WHITE"
print_summary "Sistema Operacional:" "$OS_PRETTY" "$FG_CYAN"
print_summary "Pacotes Instalados:" "${LISTA_PACOTES:-Nenhum}" "$FG_CYAN"
print_summary "Timer Systemd:" "${UNIT_NAME}.timer ($(if systemctl is-active --quiet "${UNIT_NAME}.timer"; then echo 'Ativo'; else echo 'Inativo'; fi))" "$FG_GREEN"
print_summary "Horário Programado:" "$DATA_HORA_AGENDADA" "$FG_CYAN"
print_summary "Próximo Disparo:" "$PROXIMA_EXECUCAO" "$FG_GREEN"
print_summary "Modo APT:" "$MODO_UPGRADE_DESC" "$FG_CYAN"
print_summary "Containers (Docker):" "$HOLD_DOCKER_DESC" "$FG_CYAN"
print_summary "Banco de Dados:" "$HOLD_DB_DESC" "$FG_CYAN"
print_summary "Política de Reboot:" "$POLITICA_REBOOT_DESC" "$FG_CYAN"
print_summary "Verificação Pós-Boot:" "$POSBOOT_DESC" "$FG_CYAN"
print_summary "Relatório Agendamento:" "/root/${LOG_FILENAME}" "$FG_CYAN"
print_summary "Relatório da Execução:" "/root/relatorio_execucao_atualizacao_latest.log (após disparo)" "$FG_CYAN"

if (( ${#PENDENCIAS[@]} > 0 )); then
    printf '\n'
    log_warning "Foram identificados ${#PENDENCIAS[@]} ponto(s) de atenção na pré-checagem (revise antes da janela):"
    for item in "${PENDENCIAS[@]}"; do
        printf '    %b•%b %s\n' "$FG_YELLOW" "$NC" "$item"
    done
fi

print_alert_box "Para CONSULTAR ou CANCELAR antes do horário agendado, execute novamente: sudo ./agendar_atualizacao_servidor.sh"

# ==============================================================================
# 7 - SALVAMENTO DO RELATÓRIO (FINALIZADOR AUTOMÁTICO)
# ==============================================================================
print_header "5. SALVAMENTO DO RELATÓRIO"
log_info "O relatório completo desta sessão será gravado automaticamente em /root e na Home ao encerrar."
