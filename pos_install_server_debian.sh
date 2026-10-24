#!/bin/bash
# ==============================================================================
# Script: pos_install_server_debian.sh
# Descrição: Pós-instalação, hardening e segurança automatizada para Debian Server
# Autor: Lucas Oliveira
# Repositório: https://github.com/Lucasolidev/Scripts
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/pos_install_server_debian.sh -O pos_install_server_debian.sh && sudo chmod +x pos_install_server_debian.sh && sudo ./pos_install_server_debian.sh
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (Root ou Sudo) e captura logs de auditoria em /root e na Home.
# 2. Atualiza os repositórios APT e aplica patches de segurança do sistema (opcional).
# 3. Instala utilitários vitais (curl, vim, ncdu, btop, htop, tmux, fail2ban, auditd, audispd-plugins, bind9-dnsutils, net-tools, unattended-upgrades, mtr, iperf3, nmap, tcpdump, iotop, jq, tree, rsync, unzip, 7zip, sysstat, lynis, acl, systemd-timesyncd).
# 4. Ajusta locales (en_US/pt_BR UTF-8), fuso horário (America/Sao_Paulo + NTP) e layout de teclado (ABNT2 + US-Intl).
# 5. Aplica e verifica flags noexec,nosuid,nodev em /dev/shm (redução da execução direta, não isolamento de root).
# 6. Configura aliases de produtividade e segurança no Shell (ll='ls -alFh', rm, cp, mv, df, free, ports, myip, update, clean, reload).
# 7. Endurece o SSH (Hardening): Desabilita login de Root (opcional), impede senhas em branco e verifica clientes sem resposta (keepalive).
# 8. Configura o Auditd com rotação de logs e regras ativas para monitorar identidades, sudoers, ssh, rede e persistência.
# 9. Configura a jaula do Fail2Ban (força bruta SSH) e ativa atualizações automáticas de segurança (unattended-upgrades).
# 10. Oferece criação opcional do usuário padrão 'administrador' (sudo) e de outra conta administrativa personalizada (sudo).
# 11. Gerencia somente o grupo operacional informado, preservando maiúsculas/minúsculas, e usuários com barreiras operacionais no sudoers, sem isolamento contra administradores.
# 12. Configura e ativa o Firewall UFW Dual-Stack (IPv4/IPv6) liberando portas SSH detectadas e Zabbix Agent (10050/tcp).
# 13. Opcionalmente personaliza o editor Vim com tema Sonokai, Airline e plugins fixados por commit com suporte multi-usuário (/root, /etc/skel, /home).
# 14. Instala o Banner dinâmico de Boas-Vindas no login (/usr/local/bin/motd_banner.sh integrado ao /etc/profile.d e /etc/bash.bashrc) com Hostname, Sistema, Kernel, Uptime, RAM, Discos, IPs e Status do Firewall UFW.
# 15. Exibe o Resumo da Instalação com auditoria completa de status, pacotes, serviços e grava os logs em /root e na Home.
# ==============================================================================

set -Eeuo pipefail
umask 077

VERSION="2.5"
export VERSION
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ==============================================================================
# 1. INICIALIZAÇÃO, VALIDAÇÕES E FUNÇÕES BASE
# ==============================================================================
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_CYAN='\033[36m'
FG_WHITE='\033[37m'
ARROW="❯"

draw_separator() { printf '%b\n' "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"; }
print_header() { printf '\n%b\n' "${FG_CYAN}${BOLD}❯ ${FG_WHITE}$1${NC}"; draw_separator; }
log_info() { printf '%b %s\n' "  ${FG_CYAN}[i]${NC} ${BOLD}INFO:${NC}" "$1"; }
log_success() { printf '%b %s\n' "  ${FG_GREEN}[+] SUCESSO:${NC}" "$1"; }
log_warning() { printf '%b %s\n' "  ${FG_YELLOW}[!] ATENÇÃO:${NC}" "$1"; }
log_error() { printf '%b %s\n' "  ${FG_RED}[x] ERRO:${NC}" "$1" >&2; }
log_skipped() { printf '%b %s\n' "  ${FG_YELLOW}[-] PULADO:${NC}" "$1"; }
print_alert_box() { printf '\n%b %s\n\n' "${FG_YELLOW}⚠${NC}" "$1"; }
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
PACOTES_INSTALADOS=()
CONTAS_RESULTADOS=()
pendencia() { PENDENCIAS+=("$1"); log_warning "$1"; }
is_wsl() { grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; }
get_service_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then printf 'Ativo'; else printf 'Inativo'; fi
}
# Invocada indiretamente pelo trap ERR.
# shellcheck disable=SC2317,SC2329
erro_execucao() {
    log_error "Falha na etapa '${ETAPA:-inicialização}', linha $1 (código $2). Consulte o relatório; dados de comandos não são expostos."
}

garantir_privsep_dir() {
    install -d -m 0755 -o root -g root /run/sshd
}
sshd() {
    local attempt rc=0
    for attempt in 1 2 3 4 5; do
        garantir_privsep_dir
        if command sshd "$@"; then
            return 0
        else
            rc=$?
        fi
        sleep 0.2
    done
    return "$rc"
}

# 1.1 - Escrita atômica em diretórios administrativos e backups por execução.
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
    tmp=$(mktemp "$(dirname "$dest")/.pos-install.XXXXXXXX") || return 1
    if ! install -o root -g root -m "$mode" -- "$src" "$tmp" || ! mv -fT -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        return 1
    fi
}
restore_config() {
    local dest="$1" mode="${2:-644}"
    if [[ -f "$BACKUP_DIR$dest" ]]; then
        mode=$(stat -c '%a' "$BACKUP_DIR$dest") || return 1
        install_config "$BACKUP_DIR$dest" "$dest" "$mode"
    else
        rm -f -- "$dest"
    fi
}

# Abre a origem como root e transmite pelo stdin. Toda a escrita na home ocorre
# depois de abandonar root, inclusive mktemp/rename. Não há chown recursivo.
# Chamada pelo finalizador; variáveis do bash filho expandem somente após runuser.
# shellcheck disable=SC2317,SC2329,SC2016
copy_to_home() {
    local user="$1" home_dir="$2" src="$3" name="$4"
    [[ "$home_dir" == /* && "$home_dir" != / && "$name" != */* ]] || return 1
    runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        umask 077
        cd -- "$1"
        tmp=$(mktemp .pos-install.XXXXXXXX)
        trap '\''rm -f -- "$tmp"'\'' EXIT
        cat > "$tmp"
        mv -fT -- "$tmp" "$2"
    ' bash "$home_dir" "$name" < "$src"
}

# 1.2 - Finalização única: fecha tee antes de copiar e preserva falhas/sinais.
# Invocada indiretamente pelo trap EXIT.
# shellcheck disable=SC2317,SC2329
finalizar() {
    local rc="$1" home_dir root_saved=0
    trap - EXIT ERR INT TERM HUP
    set +e
    if [[ "${SSH_TRANSACTION_ACTIVE:-N}" == S ]]; then
        log_warning "Interrupção durante a alteração SSH: restaurando a configuração anterior."
        rollback_ssh || { log_error "Restauração SSH incompleta; use os backups pelo console."; rc=1; }
    fi
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

# 1.3 - Pré-requisitos: nenhum pacote/configuração é alterado antes destas checagens.
[[ $EUID -eq 0 ]] || fatal "Execute como root ou utilize sudo."
[[ -t 0 ]] || fatal "Execute em terminal interativo; entrada redirecionada não é aceita."
[[ -r /etc/os-release ]] || fatal "/etc/os-release indisponível."
ID=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"'\''')
VERSION_ID=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"'\''')
VERSION_CODENAME=$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"'\''')
[[ "${ID:-}" == debian ]] || fatal "Este script é destinado ao Debian GNU/Linux Server."
case "${VERSION_ID:-}" in
    12*) DEBIAN_RELEASE="12" ;;
    13*) DEBIAN_RELEASE="13" ;;
    *)
        case "${VERSION_CODENAME:-}" in
            bookworm) DEBIAN_RELEASE="12" ;;
            trixie) DEBIAN_RELEASE="13" ;;
            *) fatal "Versão não prevista: ${VERSION_ID:-${VERSION_CODENAME:-desconhecida}}. Use Debian 12 (Bookworm) ou Debian 13 (Trixie)." ;;
        esac
        ;;
esac

[[ -d /run/systemd/system ]] || fatal "É necessário systemd em execução."

# Garantir utilitários básicos do host antes das checagens restritas
for cmd in apt-get systemctl flock runuser getent mktemp install tee awk findmnt; do
    command -v "$cmd" >/dev/null || fatal "Pré-requisito ausente: $cmd"
done

# Debian mínimo pode não vir com python3 pré-instalado em imagens enxutas
if ! command -v python3 >/dev/null; then
    apt-get -o DPkg::Lock::Timeout=120 update >/dev/null 2>&1 || true
    apt-get -o DPkg::Lock::Timeout=120 install -y python3 >/dev/null 2>&1 || fatal "Pré-requisito ausente: python3"
fi

exec 9>/run/lock/pos-install-server-debian.lock
flock -n 9 || fatal "Outra execução deste script está em andamento."
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_pos_install_server_debian_${LOG_TIMESTAMP}.log"
[[ ! -e "/root/$LOG_FILENAME" && ! -L "/root/$LOG_FILENAME" ]] || LOG_FILENAME="relatorio_pos_install_server_debian_${LOG_TIMESTAMP}_$$.log"
LOG_LATEST=relatorio_pos_install_server_debian_latest.log
LOG_DIR=$(mktemp -d -p /tmp pos_install_server_debian.XXXXXXXX)
BACKUP_DIR=$(mktemp -d "/root/backup_pos_install_server_debian_${LOG_TIMESTAMP}.XXXXXXXX")
LOG_FILE="$LOG_DIR/$LOG_FILENAME"
touch "$LOG_FILE"
exec 3>&1 4>&2
exec > >(tee -a "$LOG_FILE") 2>&1
TEE_PID=$!
trap 'erro_execucao "$LINENO" "$?"' ERR
trap 'finalizar "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
ETAPA="coleta de parâmetros"
print_header "PÓS-INSTALAÇÃO DO DEBIAN SERVER — $VERSION"
log_info "Debian $DEBIAN_RELEASE (${VERSION_CODENAME:-release}); backups: $BACKUP_DIR"

# ==============================================================================
# 2. COLETA DE PARÂMETROS
# ==============================================================================
ask_yes_no() {
    local var="$1" question="$2" default="$3" answer hint
    if [[ "$default" == S ]]; then hint='S/n'; else hint='s/N'; fi
    while :; do
        read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} $question ($hint): ${NC}")" answer || exit 2
        answer=${answer:-$default}
        case "$answer" in
            s|S) printf -v "$var" '%s' S; log_info "$question: Sim"; return ;;
            n|N) printf -v "$var" '%s' N; log_info "$question: Não"; return ;;
            *) log_warning "Responda s ou n." ;;
        esac
    done
}
print_header "COLETA DE PARÂMETROS"
ask_yes_no EXEC_UPDATE "Atualizar os pacotes do sistema" N
ask_yes_no PERMITIR_ROOT_SSH "Permitir login de root via SSH" N
ask_yes_no HABILITAR_UFW "Habilitar o firewall UFW" S
ask_yes_no CRIAR_ADMIN "Criar/garantir administrador no grupo sudo" N
ask_yes_no CRIAR_ADMIN_EXTRA "Criar/garantir outra conta administrativa no grupo sudo" N
ask_yes_no CRIAR_GRUPO_OPERACIONAL "Criar/garantir um grupo operacional e aplicar sua regra sudo" N
ask_yes_no CONFIGURAR_VIM "Instalar personalização opcional do Vim (Sonokai/Airline)" N
ADMIN_EXTRA_USER=""
if [[ "$CRIAR_ADMIN_EXTRA" == S ]]; then
    read -r -p "Nome de login da conta administrativa adicional (sudo): " ADMIN_EXTRA_USER || exit 2
    [[ "$ADMIN_EXTRA_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || fatal "Nome de usuário inválido: use até 32 letras minúsculas, números, hífen ou sublinhado, começando por letra minúscula ou sublinhado."
    case "$ADMIN_EXTRA_USER" in root|administrador) fatal "Use um nome diferente de '$ADMIN_EXTRA_USER' para a conta administrativa adicional." ;; esac
    if id "$ADMIN_EXTRA_USER" >/dev/null 2>&1; then
        [[ $(id -u "$ADMIN_EXTRA_USER") -ge 1000 ]] || fatal "Não é permitido usar uma conta de sistema: $ADMIN_EXTRA_USER"
    fi
    log_info "Conta administrativa adicional definida: $ADMIN_EXTRA_USER"
fi
NOME_GRUPO=""
NOVO_USER=""
CRIAR_USUARIO=N
if [[ "$CRIAR_GRUPO_OPERACIONAL" == S ]]; then
    read -r -p "Nome exato do grupo operacional (ex.: dev, DEV, SUPORTE, TI): " NOME_GRUPO || exit 2
    [[ "$NOME_GRUPO" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]] || fatal "Nome de grupo inválido: use até 32 letras, números, hífen ou sublinhado, começando por letra ou sublinhado."
    if [[ "$NOME_GRUPO" == administrador ]] || { [[ -n "$ADMIN_EXTRA_USER" ]] && [[ "$NOME_GRUPO" == "$ADMIN_EXTRA_USER" ]]; }; then
        fatal "Grupo de conta administrativa protegida não pode receber a política operacional."
    fi
    if GRUPO_EXISTENTE=$(getent group "$NOME_GRUPO"); then
        IFS=: read -r _ _ GRUPO_GID _ <<< "$GRUPO_EXISTENTE"
        [[ "$GRUPO_GID" =~ ^[0-9]+$ && "$GRUPO_GID" -ge 1000 && "$GRUPO_GID" -ne 65534 ]] ||
            fatal "Grupo de sistema não pode ser usado como grupo operacional: $NOME_GRUPO"
    fi
    log_info "Somente o grupo '$NOME_GRUPO' terá sua regra sudo aplicada; maiúsculas e minúsculas preservadas."
    ask_yes_no CRIAR_USUARIO "Criar/vincular um usuário ao grupo $NOME_GRUPO" N
fi
if [[ "$CRIAR_USUARIO" == S ]]; then
    read -r -p "Nome de login do usuário para o grupo $NOME_GRUPO: " NOVO_USER || exit 2
    [[ "$NOVO_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || fatal "Nome de usuário inválido."
    if [[ "$NOVO_USER" == root || "$NOVO_USER" == administrador ]] || { [[ -n "$ADMIN_EXTRA_USER" ]] && [[ "$NOVO_USER" == "$ADMIN_EXTRA_USER" ]]; }; then
        fatal "Contas protegidas não devem integrar os grupos operacionais."
    fi
    if id "$NOVO_USER" >/dev/null 2>&1; then
        [[ $(id -u "$NOVO_USER") -ge 1000 ]] || fatal "Não é permitido vincular uma conta de sistema."
    fi
    log_info "Usuário definido: $NOVO_USER"
fi
ADMIN_SSH_VALIDADO=""
ADMIN_SSH_PREEXISTENTE=N
if [[ "$PERMITIR_ROOT_SSH" == N ]]; then
    print_alert_box "Para desabilitar o root no SSH é OBRIGATÓRIO informar uma conta sudo PREEXISTENTE com acesso SSH funcional já testado por chave ou senha."
    read -r -p "Conta com acesso SSH testado (ENTER preserva a política atual de root): " ADMIN_SSH_VALIDADO || exit 2
    [[ -z "$ADMIN_SSH_VALIDADO" || "$ADMIN_SSH_VALIDADO" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || fatal "Conta inválida."
    [[ "$ADMIN_SSH_VALIDADO" != root ]] || fatal "Informe uma conta de usuário comum com privilégios sudo, não o root."
    if [[ -n "$ADMIN_SSH_VALIDADO" ]]; then
        if id "$ADMIN_SSH_VALIDADO" >/dev/null 2>&1; then
            [[ $(id -u "$ADMIN_SSH_VALIDADO") -ge 1000 ]] || fatal "Conta administrativa alternativa não pode ser de sistema: $ADMIN_SSH_VALIDADO"
            ADMIN_SSH_PREEXISTENTE=S
            log_info "Conta sudo alternativa informada: $ADMIN_SSH_VALIDADO"
        elif [[ "$ADMIN_SSH_VALIDADO" == administrador && "$CRIAR_ADMIN" == S ]] ||
             { [[ -n "$ADMIN_EXTRA_USER" ]] && [[ "$ADMIN_SSH_VALIDADO" == "$ADMIN_EXTRA_USER" && "$CRIAR_ADMIN_EXTRA" == S ]]; }; then
            log_warning "A conta $ADMIN_SSH_VALIDADO será criada nesta execução; o acesso SSH remoto dela ainda não pode ter sido testado. A política atual de root será preservada."
            ADMIN_SSH_VALIDADO=""
        else
            fatal "Conta não existe no sistema: $ADMIN_SSH_VALIDADO"
        fi
    else
        log_info "Nenhuma conta informada; política atual de root no SSH será preservada."
    fi
fi
printf '%b\n' "  ${DIM}${FG_CYAN}Exemplos de formato para exceções do Fail2Ban:${NC}"
printf '%b\n' "  ${DIM}${FG_CYAN}  • IP individual:     192.168.1.2${NC}"
printf '%b\n' "  ${DIM}${FG_CYAN}  • Sub-rede inteira:  192.168.1.0/24 (ou 10.0.0.0/8)${NC}"
printf '%b\n' "  ${DIM}${FG_CYAN}  • Múltiplos:         192.168.1.2 192.168.1.0/24 10.0.0.0/8${NC}"
read -r -p "$(printf '%b' "  ${FG_YELLOW}${ARROW} Fail2Ban: IPs/redes confiáveis adicionais (ENTER: somente loopback): ${NC}")" F2B_REDES || exit 2
if ! python3 - "$F2B_REDES" <<'PY'
import ipaddress, sys
try:
    for value in sys.argv[1].split():
        ipaddress.ip_network(value, strict=False)
except ValueError:
    sys.exit(1)
PY
then fatal "Informe apenas endereços IP ou redes CIDR válidos."; fi
F2B_IGNORE="127.0.0.1/8 ::1 ${F2B_REDES}"
log_info "Exceções do Fail2Ban: $F2B_IGNORE"
print_alert_box "Grupos operacionais mantêm administração ampla. Bloqueios diretos de senha/SSH são barreiras contra erros, contornáveis por administradores."

# ==============================================================================
# 3. ATUALIZAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS
# ==============================================================================
ETAPA="pacotes"
print_header "ATUALIZAÇÃO E UTILITÁRIOS"
apt-get -o DPkg::Lock::Timeout=120 update
if [[ "$EXEC_UPDATE" == S ]]; then
    apt-get -o DPkg::Lock::Timeout=120 upgrade -y
else
    log_skipped "Upgrade do sistema não solicitado."
fi

# Pacotes essenciais para Debian Server (sudo deve ser garantido pois instalações base podem não trazê-lo)
PACOTES_ESSENCIAIS=(locales openssh-server sudo fail2ban python3-systemd unattended-upgrades ufw systemd-timesyncd)
if ! is_wsl && ! systemd-detect-virt --container --quiet; then
    PACOTES_ESSENCIAIS+=(auditd audispd-plugins)
fi
PACOTE_7ZIP=7zip
PACOTES=("${PACOTES_ESSENCIAIS[@]}" curl ncdu btop htop tmux bind9-dnsutils net-tools vim mtr-tiny iperf3 nmap tcpdump iotop jq tree rsync unzip "$PACOTE_7ZIP" sysstat lynis acl)
[[ "$CONFIGURAR_VIM" != S ]] || PACOTES+=(git ca-certificates)

if ! VIRT_TYPE=$(systemd-detect-virt 2>/dev/null); then VIRT_TYPE=none; fi
case "$VIRT_TYPE" in kvm|qemu|bochs) PACOTES+=(qemu-guest-agent) ;; vmware) PACOTES+=(open-vm-tools) ;; esac

for pacote in "${PACOTES[@]}"; do
    log_info "Instalando/verificando: $pacote"
    if apt-get -o DPkg::Lock::Timeout=120 install -y "$pacote" > "$LOG_DIR/apt.log" 2>&1; then
        PACOTES_INSTALADOS+=("$pacote")
        log_success "Pacote disponível: $pacote"
    else
        case " ${PACOTES_ESSENCIAIS[*]} " in
            *" $pacote "*) fatal "Dependência essencial indisponível: $pacote. Verifique /var/log/apt e os repositórios." ;;
            *) pendencia "Utilitário opcional não instalado: $pacote" ;;
        esac
    fi
done

# 3.1 - Verificação e garantia de conta de serviço sshd
if ! getent passwd sshd >/dev/null; then
    if [[ -x /usr/bin/systemd-sysusers && -r /usr/lib/sysusers.d/openssh-server.conf ]]; then
        /usr/bin/systemd-sysusers /usr/lib/sysusers.d/openssh-server.conf || true
    fi
    if ! getent passwd sshd >/dev/null; then
        useradd -r -c 'sshd privsep' -d /run/sshd -g nogroup -s /usr/sbin/nologin sshd 2>/dev/null ||
            fatal "Conta de serviço sshd ausente; repare o pacote openssh-server antes de continuar."
    fi
    log_info "Conta de serviço sshd verificada com sucesso."
fi

case "$VIRT_TYPE" in
    kvm|qemu|bochs)
        if [[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]]; then
            systemctl start qemu-guest-agent || pendencia "QEMU Guest Agent não iniciou."
        else pendencia "Canal do QEMU Guest Agent ausente; habilite-o no hipervisor."; fi ;;
    vmware) systemctl enable --now open-vm-tools || pendencia "Open VM Tools não iniciou." ;;
esac

if [[ -f /etc/default/sysstat ]]; then
    backup_file /etc/default/sysstat
    sed 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat > "$LOG_DIR/sysstat"
    install_config "$LOG_DIR/sysstat" /etc/default/sysstat
    systemctl enable --now sysstat || pendencia "Coleta sysstat não iniciou."
fi

# ==============================================================================
# 4. CONTAS ADMINISTRATIVAS E GRUPOS OPERACIONAIS
# ==============================================================================
ETAPA="contas e sudoers"
print_header "CONTAS E REGRAS DO SUDO"
garantir_home() {
    local user="$1" home_dir
    home_dir=$(getent passwd "$user" | cut -d: -f6)
    [[ "$home_dir" == /home/* && ! -L "$home_dir" ]] || fatal "Home não convencional para $user; revise manualmente."
    if [[ ! -d "$home_dir" ]]; then
        if command -v mkhomedir_helper >/dev/null; then
            mkhomedir_helper "$user" || fatal "Não foi possível criar a home de $user."
        else
            if ! { mkdir -p "$home_dir" && cp -rT /etc/skel "$home_dir" && chown -R "$user:$user" "$home_dir" && chmod 750 "$home_dir"; }; then
                fatal "Não foi possível criar a home de $user."
            fi
        fi
    fi
}
definir_senha_inicial() {
    local user="$1" tentar_novamente passwd_rc
    log_info "Definição da senha inicial da conta: $user"
    while :; do
        printf '\nDefina a NOVA senha do usuário "%s".\nDigite a senha e depois repita para confirmar; os caracteres não aparecerão.\n' "$user" > /dev/tty
        if passwd "$user"; then
            log_success "Senha de $user definida; conteúdo não exibido nem registrado."
            return 0
        else passwd_rc=$?; fi
        case "$passwd_rc" in 129|130|143) exit "$passwd_rc" ;; esac
        log_warning "Não foi possível definir a senha de $user; confira a mensagem do passwd acima."
        ask_yes_no tentar_novamente "Tentar definir novamente a senha de $user" S
        if [[ "$tentar_novamente" != S ]]; then
            log_warning "Definição de senha cancelada para $user; conta preservada. Reexecute para retomar a configuração inicial."
            exit 2
        fi
    done
}
garantir_senha_conta_existente() {
    local user="$1" estado definir_agora
    estado=$(getent shadow "$user" | awk -F: -v conta="$user" '
        $1 == conta {
            if ($2 == "" || $2 == "!" || $2 == "!!") print "pendente"
            else print "existente"
        }
    ') || fatal "Não foi possível conferir o estado inicial da senha de $user."
    case "$estado" in
        pendente)
            log_warning "Conta $user já existe: criação pulada, mas a senha inicial ainda não foi configurada."
            ask_yes_no definir_agora "Definir a senha inicial de $user agora" N
            if [[ "$definir_agora" == S ]]; then
                definir_senha_inicial "$user"
                SENHA_CONTA_RESULTADO="criação pulada; senha inicial definida nesta execução"
            else
                pendencia "Conta $user sem senha inicial; definição não solicitada."
                SENHA_CONTA_RESULTADO="criação pulada; senha inicial pendente"
            fi
            ;;
        existente)
            log_info "Conta $user já existe: criação e definição de senha puladas; senha atual preservada."
            SENHA_CONTA_RESULTADO="criação/senha puladas; senha preservada"
            ;;
        *) fatal "Estado de senha não reconhecido para $user; revise a conta pelo console." ;;
    esac
}
criar_admin() {
    local user="$1" resultado
    if ! id "$user" >/dev/null 2>&1; then
        log_info "Criando a conta administrativa: $user"
        useradd -m -s /bin/bash -G sudo "$user"
        definir_senha_inicial "$user"
        resultado="criada nesta execução; senha inicial definida; grupo sudo"
    else
        [[ $(id -u "$user") -ge 1000 ]] || fatal "Conta administrativa conflita com UID de sistema."
        usermod -aG sudo "$user"
        garantir_senha_conta_existente "$user"
        resultado="já existia; $SENHA_CONTA_RESULTADO; grupo sudo"
    fi
    garantir_home "$user"
    log_success "$user pertence ao grupo sudo."
    CONTAS_RESULTADOS+=("$user: $resultado")
}
[[ "$CRIAR_ADMIN" != S ]] || criar_admin administrador
[[ "$CRIAR_ADMIN_EXTRA" != S ]] || criar_admin "$ADMIN_EXTRA_USER"
GRUPOS_AUDITADOS=()
if [[ "$CRIAR_GRUPO_OPERACIONAL" == S ]]; then
    GRUPOS_AUDITADOS=("$NOME_GRUPO")
    if getent group "$NOME_GRUPO" >/dev/null; then
        log_info "Grupo $NOME_GRUPO já existente; sua regra sudo será verificada/aplicada."
    else
        groupadd "$NOME_GRUPO"
        log_success "Grupo operacional criado: $NOME_GRUPO"
    fi
else log_skipped "Gestão de grupos operacionais não solicitada; grupos e regras existentes preservados."; fi
if [[ "$CRIAR_USUARIO" == S ]]; then
    if ! id "$NOVO_USER" >/dev/null 2>&1; then
        log_info "Criando a conta operacional: $NOVO_USER"
        useradd -m -s /bin/bash "$NOVO_USER"
        definir_senha_inicial "$NOVO_USER"
        CONTA_OPERACIONAL_RESULTADO="criada nesta execução; senha inicial definida"
    else
        garantir_senha_conta_existente "$NOVO_USER"
        CONTA_OPERACIONAL_RESULTADO="já existia; $SENHA_CONTA_RESULTADO"
    fi
    usermod -aG "$NOME_GRUPO" "$NOVO_USER"
    garantir_home "$NOVO_USER"
    log_success "$NOVO_USER vinculado ao grupo $NOME_GRUPO."
    CONTAS_RESULTADOS+=("$NOVO_USER: $CONTA_OPERACIONAL_RESULTADO; grupo $NOME_GRUPO")
fi
visudo -c >/dev/null || fatal "Sudoers atual inválido; corrija antes de continuar."
if (( ${#GRUPOS_AUDITADOS[@]} )); then
    ALVOS_EDITORES=(/etc/shadow /etc/sudoers /etc/ssh/sshd_config /etc/ssh/pos-install-server.conf)
    for ssh_dropin in /etc/ssh/sshd_config.d/*.conf; do
        [[ -e "$ssh_dropin" ]] || continue
        if [[ "$ssh_dropin" =~ ^/etc/ssh/sshd_config\.d/[a-zA-Z0-9_.-]+\.conf$ ]]; then
            ALVOS_EDITORES+=("$ssh_dropin")
        else
            pendencia "Nome de drop-in SSH não representável na política simples; revisar regras manualmente."
        fi
    done
    mapfile -t GRUPOS_PROCESSAR < <(printf '%s\n' "${GRUPOS_AUDITADOS[@]}" | sort -u)
    for grp in "${GRUPOS_PROCESSAR[@]}"; do
        getent group "$grp" >/dev/null || groupadd "$grp"
        ARQ_SUDO="/etc/sudoers.d/grupo_${grp}"
        ARQ_SUDO_LEGADO="/etc/sudoers.d/grupo_${grp,,}"
        if [[ ! -e "$ARQ_SUDO" && ! -L "$ARQ_SUDO" && "$ARQ_SUDO_LEGADO" != "$ARQ_SUDO" && -f "$ARQ_SUDO_LEGADO" && ! -L "$ARQ_SUDO_LEGADO" ]] &&
           grep -q '^# Gerenciado por pos_install_server ' "$ARQ_SUDO_LEGADO" &&
           grep -q "^%${grp} ALL=(ALL:ALL) ALL" "$ARQ_SUDO_LEGADO"; then
            ARQ_SUDO="$ARQ_SUDO_LEGADO"
            log_info "Regra existente do grupo $grp será reutilizada em $ARQ_SUDO, sem criar duplicata."
        fi
        if [[ -f "$ARQ_SUDO" && ! -L "$ARQ_SUDO" ]] &&
           ! grep -q "^%${grp} ALL=(ALL:ALL) ALL" "$ARQ_SUDO"; then
            fatal "Arquivo $ARQ_SUDO não corresponde ao grupo exato '$grp'; revise a regra anterior antes de continuar."
        fi
        SUDOERS_TMP="$LOG_DIR/sudoers"
        {
            printf '# Gerenciado por pos_install_server %s.\n' "$VERSION"
            printf '# Administracao ampla: negacoes sao barreiras operacionais, NAO isolamento.\n'
            printf '# passwd sem sudo continua disponivel para alterar a propria senha.\n'
            printf '%%%s ALL=(ALL:ALL) ALL' "$grp"
            printf ', !/usr/bin/passwd root, !/usr/bin/passwd administrador, !/usr/bin/passwd ""'
            if [[ -n "$ADMIN_EXTRA_USER" ]]; then
                printf ', !/usr/bin/passwd %s' "$ADMIN_EXTRA_USER"
            fi
            printf ', !/usr/sbin/visudo, !/usr/sbin/usermod, !/usr/bin/gpasswd, !/usr/bin/su, !/usr/bin/sudo'
            for editor in /usr/bin/nano /usr/bin/vi /usr/bin/vim /usr/bin/vim.tiny /usr/bin/editor; do
                for alvo in "${ALVOS_EDITORES[@]}"; do
                    printf ', !%s %s' "$editor" "$alvo"
                done
            done
            printf ', !sudoedit'
            for leitor in cat head tail less more; do printf ', !/usr/bin/%s /etc/shadow' "$leitor"; done
            printf '\n'
        } > "$SUDOERS_TMP"
        visudo -cf "$SUDOERS_TMP" >/dev/null || fatal "Política não aceita pelo visudo instalado ($grp); nenhuma regra nova aplicada para este grupo."
        install_config "$SUDOERS_TMP" "$ARQ_SUDO" 440
        if ! visudo -c >/dev/null; then
            restore_config "$ARQ_SUDO" 440
            fatal "Validação global do sudoers falhou; arquivo do grupo restaurado."
        fi
        log_success "Política operacional aplicada somente ao grupo $grp: $ARQ_SUDO"
    done
fi

# ==============================================================================
# 5. SSH: CONFIGURAÇÃO VALIDADA E PRESERVAÇÃO DO ACESSO
# ==============================================================================
ETAPA="SSH"
print_header "CONFIGURAÇÃO DO SSH"
garantir_privsep_dir
if [[ -d /etc/tmpfiles.d ]]; then
    printf 'd /run/sshd 0755 root root -\n' > "$LOG_DIR/sshd-tmpfiles.conf"
    install_config "$LOG_DIR/sshd-tmpfiles.conf" /etc/tmpfiles.d/sshd.conf 644
    systemd-tmpfiles --create /etc/tmpfiles.d/sshd.conf >/dev/null 2>&1 || true
fi
install -d -m 0755 -o root -g root /etc/systemd/system/ssh.service.d
cat > "$LOG_DIR/ssh-privsep.conf" <<'EOF'
[Service]
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755
RuntimeDirectoryPreserve=yes
EOF
install_config "$LOG_DIR/ssh-privsep.conf" /etc/systemd/system/ssh.service.d/privsep.conf 644
systemctl daemon-reload >/dev/null 2>&1 || true
garantir_privsep_dir
sshd -t || fatal "Configuração SSH existente inválida; nenhuma alteração aplicada ao SSH."
SSH_CONFIG_LEGADO=/etc/ssh/pos-install-server.conf
SSH_CONTEXT_ARGS=()
if [[ -n "${SSH_CONNECTION:-}" ]]; then
    read -r SSH_CLIENT_IP _ SSH_SERVER_IP SSH_CURRENT_PORT <<< "$SSH_CONNECTION"
    [[ "$SSH_CURRENT_PORT" =~ ^[0-9]+$ ]] || fatal "Porta da conexão SSH inválida."
    SSH_CONTEXT_ARGS=(-C "addr=$SSH_CLIENT_IP,host=$SSH_CLIENT_IP,laddr=$SSH_SERVER_IP,lport=$SSH_CURRENT_PORT")
fi
ROOT_POLICY_BEFORE=$(sshd -T "${SSH_CONTEXT_ARGS[@]}" -C user=root | awk '$1=="permitrootlogin" {print $2}')
ROOT_POLICY=$(sshd -T | awk '$1=="permitrootlogin" {print $2}')
ROOT_EXPECTED="$ROOT_POLICY_BEFORE"
CHANGE_ROOT=N
if [[ "$PERMITIR_ROOT_SSH" == S ]]; then
    ROOT_POLICY=yes
    CHANGE_ROOT=S
elif [[ "$ADMIN_SSH_PREEXISTENTE" == S ]] && id "$ADMIN_SSH_VALIDADO" >/dev/null 2>&1 &&
     id -nG "$ADMIN_SSH_VALIDADO" | tr ' ' '\n' | grep -qx sudo; then
    ADMIN_SHELL=$(getent passwd "$ADMIN_SSH_VALIDADO" | cut -d: -f7)
    ADMIN_STATE=$(passwd -S "$ADMIN_SSH_VALIDADO" | awk '{print $2}')
    if [[ "$ADMIN_SHELL" == /bin/bash && "$ADMIN_STATE" == P ]] &&
       sudo -l -U "$ADMIN_SSH_VALIDADO" >/dev/null 2>&1; then
        ROOT_POLICY=no
        CHANGE_ROOT=S
    else
        pendencia "Não foi possível verificar a conta alternativa; política anterior de root preservada."
    fi
else
    pendencia "Sem conta sudo com SSH testado: política anterior de root preservada. Após testar outro login, execute novamente."
fi
if [[ "$CHANGE_ROOT" == S ]]; then ROOT_EXPECTED="$ROOT_POLICY"; fi

backup_file /etc/ssh/sshd_config
backup_file "$SSH_CONFIG_LEGADO"

preparar_sshd_config() {
    python3 - "$1" "$2" "$3" "$4" <<'PY_SSH_CONFIG'
import pathlib
import re
import shlex
import sys

source, output, legacy_name, root_policy = sys.argv[1:]
legacy = pathlib.Path(legacy_name)
targets = {
    'permitrootlogin': ('PermitRootLogin', root_policy),
    'permitemptypasswords': ('PermitEmptyPasswords', 'no'),
    'clientaliveinterval': ('ClientAliveInterval', '300'),
    'clientalivecountmax': ('ClientAliveCountMax', '2'),
}
directive = re.compile(r'^([ \t]*)(#?[ \t]*)([a-zA-Z][a-zA-Z0-9]*)(?:[ \t]*=[ \t]*|[ \t]+)(.*)$')

def refuse(message):
    raise SystemExit('SSH: ' + message)

if legacy.exists():
    if legacy.is_symlink() or not legacy.is_file():
        refuse('arquivo legado não é regular; revise antes de migrar.')
    content = legacy.read_text()
    if not re.search(r'^# Gerenciado por pos_install_server [0-9.]+\.', content, re.M):
        refuse('arquivo legado sem identificação do script; nenhuma migração aplicada.')

lines = pathlib.Path(source).read_text().splitlines(keepends=True)
updated_lines = []
seen = set()
match_active = False

for line in lines:
    stripped = line.strip()
    tokens = shlex.split(stripped, comments=True)
    if tokens and tokens[0].lower() == 'match':
        match_active = True
    match = directive.match(line)
    if match and not match_active:
        indent, comment, name, raw_value = match.groups()
        canonical = name.lower()
        if canonical in targets and canonical not in seen:
            proper, target_value = targets[canonical]
            sep = ' '
            if '=' in line and not comment:
                sep = ' = '
            trailing = '\n' if line.endswith('\n') else ''
            updated_lines.append(f'{indent}{proper}{sep}{target_value}{trailing}')
            seen.add(canonical)
            continue
    updated_lines.append(line)

missing = [targets[name] for name in targets if name not in seen]
if missing:
    header = []
    if updated_lines and not updated_lines[-1].endswith('\n'):
        updated_lines[-1] += '\n'
    header.append('\n# Diretivas gerenciadas por pos_install_server (fora de blocos Match)\n')
    for proper, target_value in missing:
        header.append(f'{proper} {target_value}\n')
    insert_at = len(updated_lines)
    for idx, line in enumerate(updated_lines):
        tokens = shlex.split(line.strip(), comments=True)
        if tokens and tokens[0].lower() == 'match':
            insert_at = idx
            break
    updated_lines[insert_at:insert_at] = header

pathlib.Path(output).write_text(''.join(updated_lines))
PY_SSH_CONFIG
}
preparar_sshd_config /etc/ssh/sshd_config "$LOG_DIR/sshd_config" "$SSH_CONFIG_LEGADO" "$ROOT_POLICY"
rollback_ssh() {
    restore_config /etc/ssh/sshd_config
    if [[ -f "$BACKUP_DIR$SSH_CONFIG_LEGADO" ]]; then
        restore_config "$SSH_CONFIG_LEGADO"
    fi
    garantir_privsep_dir
    if systemctl is-active --quiet ssh; then
        systemctl reload ssh || { log_error "Recarregue o SSH pelo console; configuração anterior restaurada."; return 1; }
    fi
    return 0
}
SSH_TRANSACTION_ACTIVE=S
SSH_POLICY_APPLIED=S
if ! install_config "$LOG_DIR/sshd_config" /etc/ssh/sshd_config ||
   ! rm -f -- "$SSH_CONFIG_LEGADO"; then
    rollback_ssh
    fatal "Falha na gravação SSH; restauração solicitada."
fi
garantir_privsep_dir
if ! sshd -t; then
    rollback_ssh
    fatal "Configuração SSH rejeitada; arquivos anteriores restaurados."
fi
sshd -T "${SSH_CONTEXT_ARGS[@]}" -C user=root > "$LOG_DIR/ssh-effective"
if ! awk -v expected="$ROOT_EXPECTED" '
    $1=="permitrootlogin" {root=($2==expected)}
    $1=="permitemptypasswords" {empty=($2=="no")}
    $1=="clientaliveinterval" {interval=($2==300)}
    $1=="clientalivecountmax" {count=($2==2)}
    END {exit !(root && empty && interval && count)}' "$LOG_DIR/ssh-effective"; then
    rollback_ssh
    fatal "Include/Match conflita com a política solicitada. SSH restaurado; revise a configuração personalizada."
fi
if [[ "$CHANGE_ROOT" == S && "$ROOT_POLICY" == no ]]; then
    sshd -T "${SSH_CONTEXT_ARGS[@]}" -C "user=$ADMIN_SSH_VALIDADO" > "$LOG_DIR/ssh-admin"
    if grep -qE '^(allowusers|denyusers|allowgroups|denygroups) ' "$LOG_DIR/ssh-admin" ||
       ! grep -qx 'authenticationmethods any' "$LOG_DIR/ssh-admin" ||
       ! grep -qx 'forcecommand none' "$LOG_DIR/ssh-admin" ||
       ! grep -qx 'passwordauthentication yes' "$LOG_DIR/ssh-admin"; then
        rollback_ssh
        SSH_POLICY_APPLIED=N
        pendencia "SSH anterior restaurado: conta alternativa exige validação manual de autenticação/restrições."
    fi
fi
SSH_ROOT_STATUS=$(sshd -T "${SSH_CONTEXT_ARGS[@]}" -C user=root | awk '$1=="permitrootlogin" {print $2}')
sshd -T > "$LOG_DIR/ssh-global"
if systemctl is-active --quiet ssh; then
    if ! systemctl reload ssh || ! systemctl is-active --quiet ssh; then
        rollback_ssh
        fatal "Falha ao recarregar SSH; configuração anterior restaurada."
    fi
elif ! systemctl is-active --quiet ssh.socket; then
    if ! systemctl enable --now ssh; then
        rollback_ssh
        fatal "SSH não iniciou; configuração anterior restaurada."
    fi
fi
garantir_privsep_dir
SSH_TRANSACTION_ACTIVE=N
log_success "SSH validado. PermitRootLogin=$SSH_ROOT_STATUS no contexto consultado."
if [[ "$SSH_POLICY_APPLIED" == S ]]; then
    log_info "Política gravada diretamente em /etc/ssh/sshd_config; arquivo separado legado removido quando presente."
    log_info "Keepalive: 300 segundos, até 2 respostas ausentes."
fi
log_info "Teste nova conexão antes de encerrar a sessão atual."

# 5.1 - Portas declaradas, conexão atual e listeners
awk '$1=="port" {print $2}' "$LOG_DIR/ssh-global" > "$LOG_DIR/ssh-ports"
if [[ -n "${SSH_CURRENT_PORT:-}" ]]; then printf '%s\n' "$SSH_CURRENT_PORT" >> "$LOG_DIR/ssh-ports"; fi
ss -H -ltnp | awk '/"sshd"/ {n=split($4,a,":"); print a[n]}' >> "$LOG_DIR/ssh-ports"
if systemctl is-active --quiet ssh.socket; then
    systemctl show ssh.socket -p Listen --value | python3 -c '
import re, sys
for address in re.findall(r"(\S+) \(Stream\)", sys.stdin.read()):
    port = address.rsplit(":", 1)[-1]
    if port.isdigit(): print(port)
' >> "$LOG_DIR/ssh-ports"
fi
mapfile -t SSH_PORTS < <(sort -nu "$LOG_DIR/ssh-ports")
(( ${#SSH_PORTS[@]} > 0 )) || fatal "Nenhuma porta SSH identificada; firewall não será ativado."
for port in "${SSH_PORTS[@]}"; do
    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then fatal "Porta SSH inválida."; fi
done
SSH_PORTS_CSV=$(IFS=,; printf '%s' "${SSH_PORTS[*]}")
log_info "Portas SSH preservadas: $SSH_PORTS_CSV"

# ==============================================================================
# 6. FAIL2BAN E ATUALIZAÇÕES AUTOMÁTICAS
# ==============================================================================
ETAPA="Fail2Ban e atualizações automáticas"
print_header "FAIL2BAN E ATUALIZAÇÕES AUTOMÁTICAS"
F2B_FILE=/etc/fail2ban/jail.d/99-pos-install-server.local
cat > "$LOG_DIR/fail2ban" <<EOF
# Gerenciado por pos_install_server $VERSION; não substitui jail.local.
[sshd]
enabled = true
backend = systemd
port = $SSH_PORTS_CSV
ignoreip = $F2B_IGNORE
maxretry = 5
findtime = 600
bantime = 3600
EOF
install_config "$LOG_DIR/fail2ban" "$F2B_FILE" 600
if ! fail2ban-client -t > "$LOG_DIR/fail2ban-test" 2>&1; then
    restore_config "$F2B_FILE" 600
    fatal "Configuração Fail2Ban inválida; arquivo anterior restaurado. Revise as jaulas existentes."
fi
wait_fail2ban() {
    local attempt
    for ((attempt=0; attempt<10; attempt++)); do
        if fail2ban-client status sshd >/dev/null 2>&1; then return 0; fi
        sleep 1
    done
    return 1
}
if ! systemctl enable --now fail2ban || ! systemctl restart fail2ban || ! wait_fail2ban; then
    restore_config "$F2B_FILE" 600
    systemctl restart fail2ban || log_error "Falha ao restaurar o serviço Fail2Ban."
    fatal "Jaula SSH indisponível; configuração anterior restaurada."
fi
log_success "Fail2Ban ativo; jaula SSH responde. Outras jaulas e jail.local preservados."

cat > "$LOG_DIR/auto-upgrades" <<'EOF'
// Gerenciado por pos_install_server. Origens permitidas permanecem na política da distribuição.
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
install_config "$LOG_DIR/auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
AUTO_STATUS="Pendente"
AUTO_READY=N
APT_TIMERS_READY=S
declare -A APT_TIMER_STATUS
for APT_TIMER in apt-daily.timer apt-daily-upgrade.timer; do
    APT_NEXT=$(systemctl show "$APT_TIMER" --property=NextElapseUSecRealtime --value) || APT_NEXT=""
    if systemctl is-active --quiet "$APT_TIMER" && systemctl is-enabled --quiet "$APT_TIMER"; then
        APT_TIMER_STATUS[$APT_TIMER]="Ativo e habilitado; próxima execução: ${APT_NEXT:-não informada}"
        if [[ -z "$APT_NEXT" || "$APT_NEXT" == n/a ]]; then APT_TIMERS_READY=N; fi
    else
        APT_TIMER_STATUS[$APT_TIMER]="Agendamento não confirmado; próxima execução: ${APT_NEXT:-não informada}"
        APT_TIMERS_READY=N
    fi
    log_info "$APT_TIMER: ${APT_TIMER_STATUS[$APT_TIMER]}"
done
UNATTENDED_STATUS=$(get_service_status unattended-upgrades)
log_info "Unattended-upgrades: $UNATTENDED_STATUS (serviço auxiliar de encerramento)."
if [[ "$APT_TIMERS_READY" == S ]] &&
   apt-config shell valor APT::Periodic::Update-Package-Lists | grep -qx "valor='1'" &&
   apt-config shell valor APT::Periodic::Unattended-Upgrade | grep -qx "valor='1'"; then
    AUTO_READY=S
    AUTO_STATUS="Ativo (agendamentos APT confirmados)"
    log_success "Atualizações automáticas ativas no Debian."
else
    pendencia "Agendamento automático do APT não confirmado; verifique os timers do systemd."
fi

# ==============================================================================
# 7. AUDITD: RETENÇÃO E REGRAS EFETIVAMENTE CARREGADAS
# ==============================================================================
ETAPA="auditoria"
print_header "AUDITORIA DO SISTEMA"
AUDIT_STATUS="Não validado"
if is_wsl || systemd-detect-virt --container --quiet; then
    systemctl disable --now auditd.service audit-rules.service >/dev/null 2>&1 || true
    systemctl reset-failed auditd.service audit-rules.service >/dev/null 2>&1 || true
    AUDIT_STATUS="Ignorado (ambiente LXC/WSL sem suporte de kernel para auditd)"
    log_skipped "$AUDIT_STATUS"
else
    backup_file /etc/audit/auditd.conf
    awk '
        /^[[:space:]]*(max_log_file|num_logs|max_log_file_action|space_left|space_left_action|admin_space_left_action)[[:space:]]*=/ {next}
        {print}
        END {
            print "max_log_file = 50\nnum_logs = 10\nmax_log_file_action = ROTATE"
            print "space_left = 100\nspace_left_action = SYSLOG\nadmin_space_left_action = SUSPEND"
        }' /etc/audit/auditd.conf > "$LOG_DIR/auditd.conf"
    install_config "$LOG_DIR/auditd.conf" /etc/audit/auditd.conf 640
    cat > "$LOG_DIR/audit-targets" <<'EOF'
/etc/passwd wa auth_mod
/etc/shadow wa auth_mod
/etc/group wa auth_mod
/etc/gshadow wa auth_mod
/etc/security wa auth_mod
/etc/sudoers wa sudo_mod
/etc/sudoers.d wa sudo_mod
/etc/ssh wa ssh_mod
/etc/hosts wa net_mod
/etc/resolv.conf wa net_mod
/etc/network wa net_mod
/etc/ufw wa net_mod
/etc/crontab wa cron_mod
/etc/cron.d wa cron_mod
/etc/cron.daily wa cron_mod
/etc/cron.hourly wa cron_mod
/etc/cron.monthly wa cron_mod
/etc/cron.weekly wa cron_mod
/etc/systemd/system wa systemd_mod
/usr/bin/sudo x priv_escalation
/usr/bin/su x priv_escalation
/usr/bin/passwd x priv_escalation
EOF
    printf '# Gerenciado por pos_install_server; inclui somente caminhos existentes.\n' > "$LOG_DIR/audit.rules"
    while read -r path perms key; do
        if [[ -e "$path" ]]; then
            printf -- '-w %s -p %s -k %s\n' "$path" "$perms" "$key" >> "$LOG_DIR/audit.rules"
        else log_info "Caminho de auditoria não presente nesta instalação: $path"; fi
    done < "$LOG_DIR/audit-targets"
    install_config "$LOG_DIR/audit.rules" /etc/audit/rules.d/server_security.rules 600
    systemctl enable --now auditd
    service auditd restart
    augenrules --load > "$LOG_DIR/audit-load" 2>&1 || fatal "Falha ao carregar regras auditd; consulte journalctl -u auditd e auditctl -s."
    systemctl is-active --quiet auditd || fatal "Auditd não está ativo."
    auditctl -s > "$LOG_DIR/audit-status"
    grep -qE '^enabled[[:space:]]+[12]$' "$LOG_DIR/audit-status" || fatal "Auditoria do kernel desabilitada."
    auditctl -l > "$LOG_DIR/audit-loaded"
    while read -r flag path _ perms _ key; do
        [[ "$flag" == -w ]] || continue
        resolved=$(readlink -f -- "$path")
        if ! awk -v p="$path" -v r="$resolved" -v perm="$perms" -v k="$key" '
            $1=="-w" && ($2==p || $2==r) && $3=="-p" && $4==perm && $5=="-k" && $6==k {found=1}
            END {exit !found}' "$LOG_DIR/audit-loaded"; then
            fatal "Regra de auditoria não confirmada: $path ($key)."
        fi
    done < "$LOG_DIR/audit.rules"
    AUDIT_STATUS="Ativo; regras verificadas no kernel"
    log_success "$AUDIT_STATUS"
fi

# ==============================================================================
# 8. FIREWALL UFW (PORTAS SSH DETECTADAS E ZABBIX PRESERVADO)
# ==============================================================================
ETAPA="firewall"
print_header "FIREWALL UFW"
if [[ "$HABILITAR_UFW" == S ]]; then
    for port in "${SSH_PORTS[@]}"; do
        ufw allow "$port/tcp" comment 'Acesso SSH Remoto' >/dev/null
    done
    ufw allow 10050/tcp comment 'Zabbix Agent Port' >/dev/null
    awk '!/^IPV6=/ {print} END {print "IPV6=yes"}' /etc/default/ufw > "$LOG_DIR/ufw-default"
    install_config "$LOG_DIR/ufw-default" /etc/default/ufw
    ufw --force enable
    ufw reload
    ufw status | grep -q '^Status: active' || fatal "Firewall não confirmou estado ativo."
    log_success "UFW ativo; SSH $SSH_PORTS_CSV e Zabbix 10050/tcp liberados."
else log_skipped "Configuração UFW não solicitada."; fi

# ==============================================================================
# 9. LOCALES, TECLADO, NTP E MEMÓRIA COMPARTILHADA
# ==============================================================================
ETAPA="locales e sistema"
print_header "LOCALES, TECLADO E FUSO HORÁRIO"
backup_file /etc/locale.gen
sed -e 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' \
    -e 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen > "$LOG_DIR/locale.gen"
install_config "$LOG_DIR/locale.gen" /etc/locale.gen
locale-gen en_US.UTF-8 pt_BR.UTF-8 >/dev/null

if [[ -L /etc/default/locale ]]; then
    LOCALE_FILE=$(readlink -f -- /etc/default/locale)
else
    LOCALE_FILE=/etc/default/locale
fi
backup_file "$LOCALE_FILE"
if [[ -f "$LOCALE_FILE" ]]; then cp -- "$LOCALE_FILE" "$LOG_DIR/locale"; fi
update-locale --locale-file "$LOG_DIR/locale" LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
install_config "$LOG_DIR/locale" "$LOCALE_FILE"
log_success "Locales configurados em $LOCALE_FILE (en_US.UTF-8 / pt_BR.UTF-8)."

timedatectl set-timezone America/Sao_Paulo
NTP_STATUS="Não sincronizado"
if systemctl is-active --quiet chrony || systemctl is-active --quiet systemd-timesyncd; then
    log_info "Serviço de sincronização existente preservado."
elif systemctl cat systemd-timesyncd.service >/dev/null 2>&1; then
    systemctl enable --now systemd-timesyncd || pendencia "Não foi possível iniciar timesyncd."
else
    pendencia "Nenhum serviço NTP ativo detectado; configure o cliente de horário da sua preferência."
fi
if [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == yes ]]; then
    NTP_STATUS="Sincronizado"
else pendencia "NTP ainda não confirmou sincronização; conferir após acesso à rede."; fi

cat > "$LOG_DIR/keyboard" <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="br,us"
XKBVARIANT=",intl"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF
backup_file /etc/default/keyboard
install_config "$LOG_DIR/keyboard" /etc/default/keyboard
setupcon_ok=1
setupcon --force >/dev/null 2>&1 || setupcon_ok=0
udevadm trigger --subsystem-match=input --action=change >/dev/null 2>&1 || true
KEYBOARD_STATUS="br (ABNT2) + us (intl)"
if (( setupcon_ok )); then
    log_success "Teclado configurado: $KEYBOARD_STATUS."
else
    log_info "Layout persistido; sessão SSH usa o teclado do cliente. Confira no próximo login de console."
fi

# 9.1 - Atualiza somente a entrada /dev/shm e valida a montagem efetiva.
SHM_STATUS="Não ajustado"
if is_wsl || systemd-detect-virt --container --quiet; then
    SHM_STATUS="Ambiente virtualizado/contêiner: ajuste de /dev/shm ignorado"
    log_info "$SHM_STATUS"
else
    backup_file /etc/fstab
    awk '
        $2 == "/dev/shm" {
            seen=1
            n=split($4, opts, ",")
            newopts=""
            for(i=1;i<=n;i++) if(opts[i]!~/^(exec|suid|dev|noexec|nosuid|nodev)$/)
                newopts=(newopts==""?"":newopts ",") opts[i]
            $4=(newopts==""?"":newopts ",") "noexec,nosuid,nodev"
        }
        {print}
        END {if(!seen) print "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0"}
    ' /etc/fstab > "$LOG_DIR/fstab"
    install_config "$LOG_DIR/fstab" /etc/fstab
    if ! findmnt --verify --fstab /etc/fstab > "$LOG_DIR/fstab-verify" 2>&1; then
        restore_config /etc/fstab
        fatal "Validação do fstab falhou; original restaurado."
    fi
    if ! mount -o remount,noexec,nosuid,nodev /dev/shm; then
        restore_config /etc/fstab
        mount -o remount /dev/shm || true
        pendencia "Não foi possível aplicar remount em /dev/shm com as flags solicitadas; fstab restaurado."
        SHM_STATUS="Falha ao aplicar remount"
    else
        for option in noexec nosuid nodev; do
            findmnt -kno OPTIONS /dev/shm | grep -qw "$option" ||
                fatal "Opção de montagem $option não confirmada em /dev/shm."
        done
        SHM_STATUS="noexec,nosuid,nodev verificados na montagem"
        log_success "/dev/shm: $SHM_STATUS."
    fi
fi

# ==============================================================================
# 10. ALIASES DO SHELL SEM ESCRITA ROOT EM HOMES DE USUÁRIOS
# ==============================================================================
ETAPA="aliases"
print_header "ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)"
install -d -m 755 -o root -g root /etc/pos-install-server
chmod 0755 /etc/pos-install-server
cat > "$LOG_DIR/bash_aliases" <<'EOF'
# Gerenciado por pos_install_server. Somente shells interativos.
case $- in *i*) ;; *) return ;; esac
alias ll='ls -alFh'
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias free='free -h'
alias ports='sudo ss -tulanp'
alias myip='curl -fsS https://ifconfig.me; echo'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get autoclean'
alias reload='source ~/.bashrc'
alias motd='/usr/local/bin/motd_banner.sh'
EOF
ALIASES_STATUS="Arquivo compartilhado instalado"
if [[ -f /etc/pos-install-server/bash_aliases && ! -L /etc/pos-install-server/bash_aliases ]]; then
    if cmp -s -- "$LOG_DIR/bash_aliases" /etc/pos-install-server/bash_aliases; then
        ALIASES_STATUS="Arquivo compartilhado já atualizado"
    else
        ALIASES_STATUS="Arquivo compartilhado atualizado"
    fi
fi
install_config "$LOG_DIR/bash_aliases" /etc/pos-install-server/bash_aliases
chmod 0644 /etc/pos-install-server/bash_aliases 2>/dev/null || true
log_success "$ALIASES_STATUS em /etc/pos-install-server/bash_aliases; permissões administrativas garantidas."
ALIAS_LINE='[ ! -r /etc/pos-install-server/bash_aliases ] || . /etc/pos-install-server/bash_aliases'
for bashrc in /root/.bashrc /etc/skel/.bashrc; do
    backup_file "$bashrc"
    if ! grep -qF "$ALIAS_LINE" "$bashrc" 2>/dev/null; then
        { if [[ -f "$bashrc" ]]; then cat "$bashrc"; fi; printf '\n%s\n' "$ALIAS_LINE"; } > "$LOG_DIR/bashrc"
        install_config "$LOG_DIR/bashrc" "$bashrc"
        log_success "Aliases: chamada adicionada em $bashrc; conteúdo anterior preservado."
    else
        log_info "Aliases: chamada já existente em $bashrc; perfil preservado."
    fi
done

while IFS=: read -r user _ uid _ _ home_dir shell; do
    [[ "$uid" -ge 1000 && "$uid" -ne 65534 && "$shell" == /bin/bash && "$home_dir" == /* && "$home_dir" != / && -d "$home_dir" ]] || continue
    # shellcheck disable=SC2016
    if ! ALIAS_PROFILE_RESULT=$(runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
        set -eu
        cd -- "$1"
        if ! grep -qF "$2" .bashrc 2>/dev/null; then
            if [ -e .bashrc ] || [ -L .bashrc ]; then
                [ -f .bashrc ] && [ ! -L .bashrc ] || exit 1
                cp -p -- .bashrc ".bashrc.pos-install.$3"
            fi
            printf "\n%s\n" "$2" >> .bashrc
            printf "adicionada"
        else
            printf "existente"
        fi
    ' bash "$home_dir" "$ALIAS_LINE" "${LOG_TIMESTAMP}_$$"); then
        pendencia "Aliases não aplicados para $user; perfil preservado para revisão."
    else
        case "$ALIAS_PROFILE_RESULT" in
            adicionada) log_success "Aliases: chamada adicionada em $home_dir/.bashrc ($user); conteúdo anterior preservado." ;;
            existente) log_info "Aliases: chamada já existente em $home_dir/.bashrc ($user); perfil preservado." ;;
            *) pendencia "Aliases: resultado não reconhecido para $user; conferir o perfil." ;;
        esac
    fi
done < <(getent passwd)
log_info "Aliases disponíveis no próximo shell Bash interativo; para carregar nesta sessão, execute: source ~/.bashrc"

# ==============================================================================
# 11. VIM OPCIONAL: PLUGINS FIXADOS, PERFIS EXISTENTES PRESERVADOS
# ==============================================================================
ETAPA="Vim opcional"
print_header "EDITOR VIM"
VIM_STATUS="Personalização não solicitada"
if [[ "$CONFIGURAR_VIM" == S ]]; then
    VIM_PLUGINS=(
        'sainnhe/sonokai b023c5280b16fe2366f5e779d8d2756b3e5ee9c3'
        'vim-airline/vim-airline ae24f4aca06731d5d7224df1fc5415975331b214'
        'vim-airline/vim-airline-themes 77aab8c6cf7179ddb8a05741da7e358a86b2c3ab'
        'ryanoasis/vim-devicons 71f239af28b7214eebb60d4ea5bd040291fb7e33'
        'sheerun/vim-polyglot f061eddb7cdcc614c8406847b2bfb53099832a4e'
    )
    VIM_BUNDLE=/usr/local/share/pos-install-server/vim/2.5
    VIM_BUNDLE_STATUS="Pacote compartilhado já existente"
    VIM_READY=S
    if ! command -v git >/dev/null || ! command -v vim >/dev/null; then
        VIM_READY=N
        pendencia "Vim opcional: git ou vim indisponível."
    elif [[ ! -d "$VIM_BUNDLE" ]]; then
        mkdir -p "$LOG_DIR/vim/pack/vendor/start"
        for spec in "${VIM_PLUGINS[@]}"; do
            read -r repo commit <<< "$spec"
            plugin_dir="$LOG_DIR/vim/pack/vendor/start/${repo##*/}"
            mkdir -p "$plugin_dir"
            log_info "Vim: obtendo/verificando plugin ${repo##*/}..."
            if git -C "$plugin_dir" init -q &&
               git -C "$plugin_dir" -c core.hooksPath=/dev/null fetch -q --depth 1 "https://github.com/$repo.git" "$commit" &&
               [[ $(git -C "$plugin_dir" rev-parse FETCH_HEAD) == "$commit" ]] &&
               git -C "$plugin_dir" -c core.hooksPath=/dev/null checkout -q --detach "$commit"; then
                rm -rf -- "$plugin_dir/.git"
                log_success "Vim: plugin ${repo##*/} obtido; commit fixado conferido."
            else
                VIM_READY=N
                pendencia "Plugin $repo não foi obtido/verificado; personalização não será aplicada."
                break
            fi
        done
        if [[ "$VIM_READY" == S ]]; then
            install -d -m 755 /usr/local/share/pos-install-server /usr/local/share/pos-install-server/vim
            chmod -R a+rX "$LOG_DIR/vim"
            mv -T -- "$LOG_DIR/vim" "$VIM_BUNDLE"
            chmod -R a+rX /usr/local/share/pos-install-server 2>/dev/null || true
            VIM_BUNDLE_STATUS="Pacote compartilhado instalado nesta execução"
        fi
    fi
    if [[ "$VIM_READY" == S ]]; then
        for spec in "${VIM_PLUGINS[@]}"; do
            read -r repo commit <<< "$spec"
            if [[ ! -d "$VIM_BUNDLE/pack/vendor/start/${repo##*/}" ]]; then
                VIM_READY=N
                pendencia "Vim: diretório do plugin ${repo##*/} ausente; revise o pacote compartilhado."
            fi
        done
    fi
    if [[ "$VIM_READY" == S ]]; then
        VIM_PERFIS_NOVOS=0
        VIM_PERFIS_EXISTENTES=0
        VIM_PERFIS_PERSONALIZADOS=0
        VIM_PERFIS_FALHAS=0
        cat > "$LOG_DIR/vimrc" <<'EOF'
" Gerenciado por pos_install_server 2.5; plugins nativos, fixados por commit.
set packpath^=/usr/local/share/pos-install-server/vim/2.5
packloadall
" Global Sets """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax on            " Enable syntax highlight
set nu               " Enable line numbers
set tabstop=4        " Show existing tab with 4 spaces width
set softtabstop=4    " Show existing tab with 4 spaces width
set shiftwidth=4     " When indenting with '>', use 4 spaces width
set expandtab        " On pressing tab, insert 4 spaces
set smarttab         " insert tabs on the start of a line according to shiftwidth
set smartindent      " Automatically inserts one extra level of indentation in some cases
set hidden           " Hides the current buffer when a new file is openned
set incsearch        " Incremental search
set ignorecase       " Ingore case in search
set smartcase        " Consider case if there is a upper case character
set scrolloff=8      " Minimum number of lines to keep above and below the cursor
set colorcolumn=100  " Draws a line at the given line to keep aware of the line size
set signcolumn=yes   " Add a column on the left. Useful for linting
set cmdheight=2      " Give more space for displaying messages
set updatetime=100   " Time in miliseconds to consider the changes
set encoding=utf-8   " The encoding should be utf-8 to activate the font icons
set nobackup         " No backup files
set nowritebackup    " No backup files
set splitright       " Create the vertical splits to the right
set splitbelow       " Create the horizontal splits below
set autoread         " Update vim after file update from outside
set mouse=a          " Enable mouse support
filetype on          " Detect and set the filetype option and trigger the FileType Event
filetype plugin on   " Load the plugin file for the file type, if any
filetype indent on   " Load the indent file for the file type, if any

" Themes """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

let g:sonokai_style = 'andromeda'
let g:sonokai_enable_italic = 1
let g:sonokai_disable_italic_comment = 0
let g:sonokai_diagnostic_line_highlight = 1
let g:sonokai_current_word = 'bold'
colorscheme sonokai

if (has("nvim"))
    highlight Normal guibg=NONE ctermbg=NONE
    highlight EndOfBuffer guibg=NONE ctermbg=NONE
endif

" AirLine """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline_theme = 'sonokai'
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
EOF
        install_config "$LOG_DIR/vimrc" /etc/pos-install-server/vimrc
        chmod 0755 /etc/pos-install-server
        chmod 0644 /etc/pos-install-server/vimrc 2>/dev/null || true
        chmod -R a+rX /usr/local/share/pos-install-server 2>/dev/null || true
        log_success "Vim: perfil compartilhado configurado em /etc/pos-install-server/vimrc."
        for profile in /root/.vimrc /etc/skel/.vimrc; do
            if [[ ! -e "$profile" && ! -L "$profile" ]]; then
                printf 'source /etc/pos-install-server/vimrc\n' > "$LOG_DIR/vim-source"
                install_config "$LOG_DIR/vim-source" "$profile"
                VIM_PERFIS_NOVOS=$((VIM_PERFIS_NOVOS + 1))
                log_success "Vim: chamada para o perfil compartilhado adicionada em $profile."
            elif [[ -f "$profile" && ! -L "$profile" ]] && grep -qxF 'source /etc/pos-install-server/vimrc' "$profile"; then
                VIM_PERFIS_EXISTENTES=$((VIM_PERFIS_EXISTENTES + 1))
                log_info "Vim: chamada para o perfil compartilhado já existente em $profile; arquivo preservado."
            else
                VIM_PERFIS_PERSONALIZADOS=$((VIM_PERFIS_PERSONALIZADOS + 1))
                log_info "Vim: configuração existente preservada em $profile; perfil compartilhado não adicionado."
            fi
        done
        while IFS=: read -r user _ uid _ _ home_dir shell; do
            [[ "$uid" -ge 1000 && "$uid" -ne 65534 && "$shell" == /bin/bash && "$home_dir" == /* && "$home_dir" != / && -d "$home_dir" ]] || continue
            # shellcheck disable=SC2016
            if ! VIM_PROFILE_RESULT=$(runuser -u "$user" -- env -u BASH_ENV bash --noprofile --norc -c '
                set -eu
                cd -- "$1"
                if [ ! -e .vimrc ] && [ ! -L .vimrc ]; then
                    set -C
                    printf "source /etc/pos-install-server/vimrc\n" > .vimrc
                    printf "adicionado"
                elif grep -qxF "source /etc/pos-install-server/vimrc" .vimrc 2>/dev/null; then
                    printf "existente"
                else
                    printf "personalizado"
                fi
            ' bash "$home_dir"); then
                VIM_PERFIS_FALHAS=$((VIM_PERFIS_FALHAS + 1))
                pendencia "Perfil Vim de $user não foi aplicado."
            else
                case "$VIM_PROFILE_RESULT" in
                    adicionado)
                        VIM_PERFIS_NOVOS=$((VIM_PERFIS_NOVOS + 1))
                        log_success "Vim: chamada para o perfil compartilhado adicionada em $home_dir/.vimrc ($user)."
                        ;;
                    existente)
                        VIM_PERFIS_EXISTENTES=$((VIM_PERFIS_EXISTENTES + 1))
                        log_info "Vim: chamada para o perfil compartilhado já existente em $home_dir/.vimrc ($user); arquivo preservado."
                        ;;
                    personalizado)
                        VIM_PERFIS_PERSONALIZADOS=$((VIM_PERFIS_PERSONALIZADOS + 1))
                        log_info "Vim: configuração existente preservada em $home_dir/.vimrc ($user); perfil compartilhado não adicionado."
                        ;;
                    *)
                        VIM_PERFIS_FALHAS=$((VIM_PERFIS_FALHAS + 1))
                        pendencia "Vim: resultado do perfil de $user não reconhecido; conferir manualmente."
                        ;;
                esac
            fi
        done < <(getent passwd)
        VIM_STATUS="Plugins fixados instalados; perfis preexistentes preservados"
        log_success "Vim: $VIM_BUNDLE_STATUS em $VIM_BUNDLE."
        print_summary "Plugins disponíveis:" "Sonokai, vim-airline, vim-airline-themes, vim-devicons e vim-polyglot" "$FG_GREEN"
        print_summary "Tema configurado:" "Sonokai Andromeda; TrueColor quando suportado"
        print_summary "Interface:" "Airline com barra de abas; ícones Devicons"
    fi
else
    log_skipped "Vim: personalização não solicitada; configurações existentes preservadas."
fi

# ==============================================================================
# 12. BANNER DINÂMICO DE BOAS-VINDAS
# ==============================================================================
ETAPA="banner"
print_header "BANNER DE BOAS-VINDAS"
cat > "$LOG_DIR/motd_banner.sh" <<'EOF'
#!/bin/bash
# ==============================================================================
# Banner Dinâmico de Boas-Vindas e Diagnóstico do Servidor (Debian Server)
# Exibido automaticamente em sessões interativas de shell (SSH / Console)
# ==============================================================================

# Executa apenas se a saída padrão for um terminal interativo (evita quebrar scp/sftp/rsync)
[ -t 1 ] || exit 0

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

HOSTNAME=$(hostname 2>/dev/null || uname -n)
SISTEMA=$(lsb_release -ds 2>/dev/null || grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || echo "Debian GNU/Linux")
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")
RAM_USO=$(free -h 2>/dev/null | awk '/^Mem:/ {print "Usado: " $3 " / Total: " $2 " (Livre: " $7 ")"}')
SWAP_USO=$(free -h 2>/dev/null | awk '/^Swap:/ { if ($2 == "0B" || $2 == "0" || $2 == "") print "Desativada (0B)"; else print "Usado: " $3 " / Total: " $2 " (Livre: " $4 ")" }')

echo -e "\033[1;36m================================================================\033[0m"
echo -e "  \033[1;32m📌 VOCÊ CONECTOU EM:\033[0m"
printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Hostname:" "${HOSTNAME}"
printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m \033[2m(Kernel %s)\033[0m\n" "Sistema:" "${SISTEMA}" "${KERNEL}"
printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Uptime:" "${UPTIME}"
printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Memória RAM:" "${RAM_USO}"
printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Memória SWAP:" "${SWAP_USO:-Desativada (0B)}"

# Partições / Discos Físicos Montados
DISCOS_ENCONTRADOS=0
DISCOS_RAW=$(df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 -x rootfs 2>/dev/null | awk 'NR>1 && ($1 ~ /^\/dev/ || $1 ~ /:/) && $6 !~ /^\/boot/ {print $6, $3, $2, $4, $5}')
if [ -n "$DISCOS_RAW" ]; then
  while read -r mountpoint used total free perc; do
    if [ -n "$mountpoint" ]; then
      DISCOS_ENCONTRADOS=1
      lbl="Disco (${mountpoint}):"
      printf "     \033[1m%-18s\033[0m \033[36mUsado: %s / Total: %s (Livre: %s | %s)\033[0m\n" "$lbl" "$used" "$total" "$free" "$perc"
    fi
  done <<< "$DISCOS_RAW"
fi

if [ "$DISCOS_ENCONTRADOS" -eq 0 ]; then
  ROOT_DF=$(df -h / 2>/dev/null | awk 'NR==2 {print "Usado: " $3 " / Total: " $2 " (Livre: " $4 " | " $5 ")"}')
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Disco (/):" "${ROOT_DF}"
fi

# Interfaces de Rede e Endereços IPv4
IPS_ENCONTRADOS=0
IPS_RAW=$(ip -4 -o addr show scope global 2>/dev/null | awk '$2 != "lo" {split($4, a, "/"); print $2, a[1]}')
if [ -n "$IPS_RAW" ]; then
  while read -r iface ip_addr; do
    if [ -n "$iface" ] && [ -n "$ip_addr" ]; then
      IPS_ENCONTRADOS=1
      lbl="IP (${iface}):"
      printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "$lbl" "$ip_addr"
    fi
  done <<< "$IPS_RAW"
fi

if [ "$IPS_ENCONTRADOS" -eq 0 ]; then
  IP_FALLBACK=$(hostname -I 2>/dev/null | awk '{print $1}')
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "IP Local:" "${IP_FALLBACK:-N/A}"
fi

# Status do Firewall UFW
if (grep -qs -i "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null && systemctl is-active --quiet ufw 2>/dev/null) || (ufw status 2>/dev/null | grep -qi "^Status:[[:space:]]*active"); then
  UFW_STATUS_TXT="\033[1;32mAtivo\033[0m"
elif command -v ufw >/dev/null 2>&1 || [ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ] || [ -f /etc/default/ufw ] || [ -f /etc/ufw/ufw.conf ]; then
  UFW_STATUS_TXT="\033[1;33mInativo\033[0m"
else
  UFW_STATUS_TXT="\033[1;33mNão Instalado\033[0m"
fi
printf "     \033[1m%-18s\033[0m %b\n" "Firewall UFW:" "${UFW_STATUS_TXT}"

echo -e "\033[1;36m================================================================\033[0m\n"
EOF
install_config "$LOG_DIR/motd_banner.sh" /usr/local/bin/motd_banner.sh 755
cat > "$LOG_DIR/motd-profile" <<'EOF'
#!/bin/sh
# Exibe o banner apenas em terminais interativos, uma vez por sessão.
if [ -t 1 ] && [ -z "${__MOTD_SHOWN:-}" ] && [ -x /usr/local/bin/motd_banner.sh ]; then
    export __MOTD_SHOWN=1
    /usr/local/bin/motd_banner.sh
fi
EOF
install_config "$LOG_DIR/motd-profile" /etc/profile.d/motd_banner.sh 755
if ! grep -q 'motd_banner.sh' /etc/bash.bashrc; then
    { cat /etc/bash.bashrc; printf '\n'; cat "$LOG_DIR/motd-profile"; } > "$LOG_DIR/bash.bashrc"
    install_config "$LOG_DIR/bash.bashrc" /etc/bash.bashrc
fi
log_success "Banner instalado; .hushlogin e demais personalizações de login preservados."

# ==============================================================================
# 13. RESUMO DA INSTALAÇÃO E RESULTADOS VERIFICADOS
# ==============================================================================
ETAPA="resumo"
print_header "RESUMO DA INSTALAÇÃO"
if (( ${#PENDENCIAS[@]} )); then
    log_warning "Processo concluído com pendências (código 3)."
else log_success "Etapas solicitadas concluídas; valide o funcionamento na máquina."; fi
LISTA_PACOTES=$(printf '%s, ' "${PACOTES_INSTALADOS[@]}")
draw_separator
print_summary "Versão:" "$VERSION"
print_summary_section "SISTEMA E VIRTUALIZAÇÃO"
print_summary "Locales:" "en_US.UTF-8 / pt_BR.UTF-8" "$FG_GREEN"
print_summary "Teclado:" "$KEYBOARD_STATUS"
print_summary "Fuso horário:" "$(timedatectl show -p Timezone --value)" "$FG_GREEN"
RESULT_COLOR=$FG_YELLOW
if [[ "$NTP_STATUS" == Sincronizado ]]; then RESULT_COLOR=$FG_GREEN; fi
print_summary "NTP:" "$NTP_STATUS" "$RESULT_COLOR"
case "$VIRT_TYPE" in
    kvm|qemu|bochs|vmware)
        if [[ "$VIRT_TYPE" == vmware ]]; then
            SERVICE_LABEL="Open VM Tools:"; SERVICE_STATUS=$(get_service_status open-vm-tools)
        else
            SERVICE_LABEL="QEMU Guest Agent:"; SERVICE_STATUS=$(get_service_status qemu-guest-agent)
        fi
        RESULT_COLOR=$FG_YELLOW
        if [[ "$SERVICE_STATUS" == Ativo ]]; then RESULT_COLOR=$FG_GREEN; fi
        print_summary "$SERVICE_LABEL" "$SERVICE_STATUS" "$RESULT_COLOR"
        ;;
    *) print_summary "Agente de VM:" "Não aplicável ($VIRT_TYPE)" ;;
esac
print_summary_section "CONTAS, SUDO E SSH"
for item in "${CONTAS_RESULTADOS[@]}"; do print_summary "Conta gerenciada:" "$item"; done
print_summary "Grupos operacionais:" "Administração ampla com barreiras diretas; não são isolamento contra root" "$FG_YELLOW"
print_summary "Regras sudo:" "/etc/sudoers.d/; configuração validada com visudo"
RESULT_COLOR=$FG_CYAN
case "$SSH_ROOT_STATUS" in no) RESULT_COLOR=$FG_GREEN ;; yes) RESULT_COLOR=$FG_YELLOW ;; esac
print_summary "SSH PermitRootLogin:" "$SSH_ROOT_STATUS (contexto consultado)" "$RESULT_COLOR"
print_summary "Portas SSH preservadas:" "$SSH_PORTS_CSV"
print_summary "Configuração SSH:" "/etc/ssh/sshd_config"
print_summary_section "FAIL2BAN — PROTEÇÃO DO SSH"
SERVICE_STATUS=$(get_service_status fail2ban)
RESULT_COLOR=$FG_YELLOW
if [[ "$SERVICE_STATUS" == Ativo ]]; then RESULT_COLOR=$FG_GREEN; fi
print_summary "Fail2Ban:" "$SERVICE_STATUS; jaula sshd verificada" "$RESULT_COLOR"
print_summary "Configuração:" "$F2B_FILE"
print_summary "IPs/redes ignorados:" "$F2B_IGNORE"
print_summary_section "UFW — FIREWALL E REGRAS ATUAIS"
if UFW_SUMMARY=$(ufw status 2>/dev/null); then
    RESULT_COLOR=$FG_YELLOW
    UFW_SUMMARY_STATUS="Inativo"
    if grep -q '^Status: active' <<< "$UFW_SUMMARY"; then
        RESULT_COLOR=$FG_GREEN
        UFW_SUMMARY_STATUS="Ativo"
    fi
    print_summary "Firewall UFW:" "$UFW_SUMMARY_STATUS" "$RESULT_COLOR"
    printf '\n'
    while IFS= read -r item; do printf '  %b%s%b\n' "$FG_CYAN" "$item" "$NC"; done <<< "$UFW_SUMMARY"
else
    pendencia "Não foi possível consultar as regras atuais do UFW no resumo."
fi
print_summary_section "AUDITD — AUDITORIA E CONTROLES DO SISTEMA"
RESULT_COLOR=$FG_YELLOW
case "$AUDIT_STATUS" in
    "Ativo; regras verificadas no kernel") RESULT_COLOR=$FG_GREEN ;;
    "Ignorado (ambiente LXC/WSL sem suporte de kernel para auditd)") RESULT_COLOR=$FG_CYAN ;;
esac
print_summary "Auditd:" "$AUDIT_STATUS" "$RESULT_COLOR"
if ! is_wsl && ! systemd-detect-virt --container --quiet; then
    print_summary "Regras gerenciadas:" "/etc/audit/rules.d/server_security.rules"
    print_summary "Logs de auditoria:" "/var/log/audit/"
fi
RESULT_COLOR=$FG_YELLOW
if [[ "$SHM_STATUS" == "noexec,nosuid,nodev verificados na montagem" ]]; then RESULT_COLOR=$FG_GREEN; fi
print_summary "/dev/shm:" "$SHM_STATUS" "$RESULT_COLOR"
print_summary_section "UNATTENDED-UPGRADES — ATUALIZAÇÕES AUTOMÁTICAS"
RESULT_COLOR=$FG_YELLOW
if [[ "$AUTO_READY" == S ]]; then RESULT_COLOR=$FG_GREEN; fi
print_summary "Atualizações APT:" "$AUTO_STATUS" "$RESULT_COLOR"
print_summary "Índices APT:" "${APT_TIMER_STATUS[apt-daily.timer]}" "$RESULT_COLOR"
print_summary "Instalação automática:" "${APT_TIMER_STATUS[apt-daily-upgrade.timer]}" "$RESULT_COLOR"
RESULT_COLOR=$FG_YELLOW
if [[ "$UNATTENDED_STATUS" == Ativo ]]; then RESULT_COLOR=$FG_GREEN; fi
print_summary "Unattended-upgrades:" "$UNATTENDED_STATUS (serviço auxiliar de encerramento)" "$RESULT_COLOR"
print_summary "Política periódica:" "/etc/apt/apt.conf.d/20auto-upgrades"
print_summary "Histórico:" "/var/log/unattended-upgrades/"
print_summary_section "ACL — PERMISSÕES ADICIONAIS DE ARQUIVOS"
if command -v getfacl >/dev/null && command -v setfacl >/dev/null; then
    print_summary "Ferramentas ACL:" "getfacl e setfacl disponíveis" "$FG_GREEN"
else
    print_summary "Ferramentas ACL:" "Disponibilidade não confirmada; consulte pendências de pacotes" "$FG_YELLOW"
fi
print_summary "Finalidade:" "Consultar/definir permissões adicionais por usuário e grupo"
print_summary "Aplicação:" "Uso manual; o instalador não aplica ACLs a diretórios"
print_summary_section "SHELL E EDITOR VIM"
print_summary "Aliases:" "$ALIASES_STATUS; conferir resultados por perfil na etapa de aliases"
RESULT_COLOR=$FG_CYAN
case "$VIM_STATUS" in
    "Plugins fixados instalados; perfis preexistentes preservados") RESULT_COLOR=$FG_GREEN ;;
    "Personalização não aplicada; consulte pendências") RESULT_COLOR=$FG_YELLOW ;;
esac
print_summary "Vim:" "$VIM_STATUS" "$RESULT_COLOR"
print_summary_section "PACOTES DISPONÍVEIS"
printf '%s\n' "${LISTA_PACOTES%, }" | fold -s -w 88 | while IFS= read -r item; do
    printf '  %b%s%b\n' "$FG_CYAN" "$item" "$NC"
done
printf '\n'
draw_separator
if [[ -e /var/run/reboot-required ]]; then log_warning "O sistema solicita reinicialização; agende após validar o acesso."; fi
if (( ${#PENDENCIAS[@]} )); then
    printf '\n%bPendências:%b\n' "${FG_YELLOW}${BOLD}" "$NC"
    for item in "${PENDENCIAS[@]}"; do printf '  %b- %s%b\n' "$FG_YELLOW" "$item" "$NC"; done
fi

# ==============================================================================
# 14. GERAÇÃO E SALVAMENTO DOS LOGS (FINALIZADOR EXIT)
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"
log_info "O finalizador fechará a captura e salvará o relatório completo em /root e, quando aplicável, na home do usuário sudo."
exit 0
