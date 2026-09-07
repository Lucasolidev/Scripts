#!/bin/bash
# ------------------------------------------------
# Version: 3.0
# ------------------------------------------------
VERSION="3.0"
# ==============================================================================
# SCRIPT DE INSTALACAO DA PILHA LAMP AUTOMATICO E ENDURECIDO - JOOMLA 5.x
# COM AUDITORIA EM TEMPO REAL (AUDITD) E BLINDAGEM CONTRA WEBSHELLS
# UBUNTU SERVER (22.04 / 24.04 / 26.04 LTS)
# ==============================================================================
# O que este script faz (Descricao e Auditoria de Funcoes):
# 1. Valida privilegios de execucao (exige Root/Sudo) e inicializa captura de log.
# 2. Coleta parametros essenciais (Dominio, Diretorio Web Raiz, Banco MariaDB, Senhas).
# 3. Atualiza os repositorios do sistema e instala pre-requisitos essenciais (incluindo auditd).
# 4. Instala e configura o Apache 2.4.x com mod_rewrite, mod_ssl, mod_headers, mod_deflate, HTTP/2 e FastCGI.
# 5. Aplica blindagem no Apache (bloqueio de execucao PHP em pastas de midia/uploads/cache, ocultacao de banners, headers de seguranca).
# 6. Instala o MariaDB Server (11.4 LTS Recomendado) com hardening, cria banco e usuario dedicados para o Joomla 5 (utf8mb4).
# 7. Configura PHP 8.3/8.5 com extensoes essenciais e opcionais selecionadas.
# 8. Aplica hardening em pool PHP-FPM dedicado, preservando CLI e outros pools.
# 9. Configura VirtualHost Apache otimizado para o dominio informado e 000-default.conf com regras anti-webshell.
# 10. Baixa e extrai automaticamente o pacote estavel oficial do Joomla 5.x.
# 11. Protege o codigo contra escrita pelo Apache e libera somente diretorios mutaveis via ACL.
# 12. Configura rotinas agendadas (Cron Jobs) para execucao periodica das tarefas CLI do Joomla (cli/joomla.php).
# 13. Configura o Linux Audit Daemon (auditd) com regras ativas para monitorar alteracoes no diretorio web em tempo real.
# 14. Integra as portas HTTP (80) e HTTPS (443) ao Firewall UFW e jails Web ao Fail2Ban.
# 15. Exibe resumo sem segredos e salva credenciais em arquivo root:root com modo 0600.
# 16. Gera logs privados, sem credenciais, em /root e na Home do usuario.
#
# EXECUCAO REMOTA (revise a origem antes de executar):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/Scripts/install_lamp_ubuntu_joomla5.sh -O install_lamp_ubuntu_joomla5.sh && chmod +x install_lamp_ubuntu_joomla5.sh && sudo ./install_lamp_ubuntu_joomla5.sh
# ==============================================================================
# Execucao recomendada apos revisar localmente a origem e a integridade do arquivo:
# chmod +x install_lamp_ubuntu_joomla5.sh
# sudo ./install_lamp_ubuntu_joomla5.sh
# Reinstalacao destrutiva: sudo ./install_lamp_ubuntu_joomla5.sh --reinstall
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
set -Eeuo pipefail
umask 077

REINSTALL_MODE="n"
case "${1:-}" in
    --reinstall) REINSTALL_MODE="s" ;;
    "") ;;
    *) printf 'Uso: %s [--reinstall]\n' "$0" >&2; exit 2 ;;
esac

RUNTIME_DIR=""
LOG_TMP=""
TMP_SQL=""
JOOMLA_ARCHIVE=""
PACOTES_INSTALADOS=()

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM HUP
    if [ -n "${TEE_PID:-}" ]; then
        exec 1>&3 2>&4
        wait "$TEE_PID" || :
    fi
    if [ -f "${LOG_TMP:-}" ]; then
        install -m 600 "$LOG_TMP" "/root/$LOG_FILENAME" || :
        install -m 600 "$LOG_TMP" "/root/$LOG_LATEST" || :
        if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
            local real_home
            real_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
            if [ -d "$real_home" ]; then
                install -m 600 -o "$SUDO_USER" "$LOG_TMP" "$real_home/$LOG_FILENAME" || :
                install -m 600 -o "$SUDO_USER" "$LOG_TMP" "$real_home/$LOG_LATEST" || :
            fi
        fi
    fi
    [ -n "${TMP_SQL:-}" ] && [ -f "$TMP_SQL" ] && rm -f -- "$TMP_SQL"
    [ -n "${JOOMLA_ARCHIVE:-}" ] && [ -f "$JOOMLA_ARCHIVE" ] && rm -f -- "$JOOMLA_ARCHIVE"
    [ -n "${RUNTIME_DIR:-}" ] && [ -d "$RUNTIME_DIR" ] && rm -rf -- "$RUNTIME_DIR"
    exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# ========================================
# PALETA DE CORES (ANSI ESCAPE CODES)
# ========================================
NC='\033[0m'              # Reset (Sem Cor)
BOLD='\033[1m'
DIM='\033[2m'

FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_CYAN='\033[36m'
FG_WHITE='\033[37m'

ARROW="❯"

# ========================================
# FUNCOES DE HIGHLIGHT E LOGGING
# ========================================

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}▶ ${title}${NC}"
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
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENCAO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
log_skipped() { echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }

die() {
    log_error "$1"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Comando obrigatorio ausente: $1"
}

validate_domain() {
    [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

validate_db_identifier() {
    [[ "$1" =~ ^[A-Za-z0-9_]{1,32}$ ]]
}

validate_docroot() {
    local path="$1"
    [[ "$path" == /* ]] || return 1
    [[ "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || return 1
    case "$path" in
        /var/www/*|/srv/www/*|/mnt/*/*|/arquivos/*/*) return 0 ;;
        *) return 1 ;;
    esac
}

is_wsl() {
    grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

sql_escape_literal() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\'/\'\'}
    printf '%s' "$value"
}

generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 18
    else
        od -An -N18 -tx1 /dev/urandom | tr -d ' \n'
    fi
}

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠️  ATENCAO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# ==============================================================================
# 1. VERIFICACAO DE PRIVILEGIOS (ROOT) E INICIALIZACAO DE LOG
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    print_header "ERRO DE EXECUCAO"
    log_error "Este script precisa ser executado como ROOT ou via sudo."
    echo -e "  Exemplo: ${FG_YELLOW}sudo bash $0${NC}\n"
    exit 1
fi

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_lamp_ubuntu_joomla5_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_lamp_ubuntu_joomla5_latest.log"
RUNTIME_DIR=$(mktemp -d -p /tmp install_lamp_joomla5.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP"
chmod 600 "$LOG_TMP"
exec 3>&1 4>&2
exec > >(tee -a "$LOG_TMP") 2>&1
TEE_PID=$!

print_header "INSTALADOR AUTOMATICO LAMP ENDURECIDO - JOOMLA 5 (UBUNTU SERVER)"
log_info "Versao do instalador: ${FG_WHITE}${VERSION}${NC}"
# ==============================================================================
# 2. COLETA DE PARAMETROS DO AMBIENTE
# ==============================================================================
print_header "COLETA DE PARAMETROS DO AMBIENTE"
OS_ID=$(awk -F= '$1=="ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
OS_VERSION=$(awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
[[ "$OS_ID" == ubuntu && "$OS_VERSION" =~ ^(22|24|26)\.04$ ]] || die "Exige Ubuntu 22.04, 24.04 ou 26.04."

echo -e "  ${FG_CYAN}[i]${NC} Dominio do site Joomla 5 (ex: meusite.com.br ou prototipo.net.br)."
echo -e "  ${FG_CYAN}[i]${NC} Informe o dominio sem protocolo, porta ou caminho; exemplo: site.exemplo.com."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Dominio do site: ${NC}")" DOMAIN_NAME
while ! validate_domain "$DOMAIN_NAME"; do
    log_warning "Informe um dominio DNS valido, sem protocolo, porta, barras ou espacos."
    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Informe o dominio do site: ${NC}")" DOMAIN_NAME
done

# Limpa caracteres especiais do dominio para usar como identificador seguro
CLEAN_DOMAIN_ID=$(echo "$DOMAIN_NAME" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
log_info "Dominio definido: ${FG_GREEN}${DOMAIN_NAME}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Diretorio raiz da aplicacao web (permite informar outro disco/ponto de montagem)."
echo -e "  ${FG_CYAN}[i]${NC} A pasta deve estar vazia; nela sera instalado somente o Joomla revisado."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Diretorio de instalacao [Padrao: /var/www/html/${DOMAIN_NAME}]: ${NC}")" CUSTOM_DOC_ROOT
JOOMLA_ROOT=${CUSTOM_DOC_ROOT:-"/var/www/html/${DOMAIN_NAME}"}
validate_docroot "$JOOMLA_ROOT" || die "Diretorio web invalido ou inseguro: ${JOOMLA_ROOT}"
JOOMLA_ROOT=$(realpath -m -- "$JOOMLA_ROOT")
validate_docroot "$JOOMLA_ROOT" || die "Destino resolvido fora das raizes web permitidas."
if [ -d "$JOOMLA_ROOT" ] && [ -n "$(find "$JOOMLA_ROOT" -mindepth 1 -print -quit)" ] && [ "$REINSTALL_MODE" != s ]; then
    die "Diretorio nao vazio. Para reinstalacao destrutiva, execute novamente com --reinstall."
fi
log_info "Diretorio Web Raiz: ${FG_GREEN}${JOOMLA_ROOT}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Configuracao do Banco de Dados MariaDB para o Joomla 5."
echo -e "  ${FG_CYAN}[i]${NC} Senha administrativa local do MariaDB; sera ocultada e guardada em arquivo root 0600."
read -r -s -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar aleatoria): ${NC}")" DB_ROOT_PASS
echo
if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(generate_password)
    log_info "Senha forte gerada para o MariaDB Root (valor oculto)."
else
    [ "${#DB_ROOT_PASS}" -ge 16 ] || die "A senha do MariaDB Root deve ter pelo menos 16 caracteres."
    log_info "Senha do MariaDB Root recebida com entrada oculta."
fi

DEFAULT_DB_NAME="joomla_${CLEAN_DOMAIN_ID:0:15}_db"
echo -e "  ${FG_CYAN}[i]${NC} Nome logico da base; use somente letras, numeros e sublinhado."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do Banco de Dados [Padrao: ${DEFAULT_DB_NAME}]: ${NC}")" JOOMLA_DB_NAME
JOOMLA_DB_NAME=${JOOMLA_DB_NAME:-$DEFAULT_DB_NAME}
validate_db_identifier "$JOOMLA_DB_NAME" || die "Nome de banco invalido. Use somente letras, numeros e sublinhado (maximo 32)."
log_info "Nome do Banco definido: ${FG_GREEN}${JOOMLA_DB_NAME}${NC}"

DEFAULT_DB_USER="joomla_${CLEAN_DOMAIN_ID:0:15}_usr"
echo -e "  ${FG_CYAN}[i]${NC} Usuario exclusivo do Joomla, sem acesso remoto e sem permissao de administrador."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuario do Banco [Padrao: ${DEFAULT_DB_USER}]: ${NC}")" JOOMLA_DB_USER
JOOMLA_DB_USER=${JOOMLA_DB_USER:-$DEFAULT_DB_USER}
validate_db_identifier "$JOOMLA_DB_USER" || die "Usuario de banco invalido. Use somente letras, numeros e sublinhado (maximo 32)."
log_info "Usuario do Banco definido: ${FG_GREEN}${JOOMLA_DB_USER}${NC}"

echo -e "  ${FG_CYAN}[i]${NC} Senha exclusiva do usuario do Joomla; sera gravada somente no arquivo de credenciais root 0600."
read -r -s -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do Usuario do Joomla DB (deixe vazio para gerar aleatoria): ${NC}")" JOOMLA_DB_PASS
echo
if [ -z "$JOOMLA_DB_PASS" ]; then
    JOOMLA_DB_PASS=$(generate_password)
    log_info "Senha forte gerada para o Usuario Joomla DB (valor oculto)."
else
    [ "${#JOOMLA_DB_PASS}" -ge 16 ] || die "A senha do Usuario Joomla DB deve ter pelo menos 16 caracteres."
    log_info "Senha do Usuario Joomla DB recebida com entrada oculta."
fi

# Validar os sites ativos antes de qualquer limpeza destrutiva. Em uma
# reinstalacao, somente o vhost Apache do dominio informado pode existir;
# sites de outros dominios continuam sendo um bloqueio operacional.
for enabled_site in /etc/apache2/sites-enabled/* /etc/nginx/sites-enabled/*; do
    [[ -e "$enabled_site" ]] || continue
    enabled_name=$(basename -- "$enabled_site")
    case "$enabled_name" in
        000-default.conf|default-ssl.conf|default) continue ;;
    esac
    if [ "$REINSTALL_MODE" = s ] && [[ "$enabled_site" == /etc/apache2/sites-enabled/* ]] \
        && grep -Eiq "(ServerName|ServerAlias)[[:space:]]+${DOMAIN_NAME}([[:space:]]|$)|server_name[[:space:]]+[^;]*\\b${DOMAIN_NAME}\\b" "$enabled_site" 2>/dev/null; then
        log_warning "Vhost Apache existente para ${DOMAIN_NAME} sera reutilizado e reconfigurado."
        continue
    fi
    die "Servidor com site customizado ativo: $enabled_site. Em reinstalacao, desative sites de outros dominios antes de continuar."
done

if [ "$REINSTALL_MODE" = s ]; then
    print_alert_box "MODO REINSTALACAO DESTRUTIVA: os arquivos de ${JOOMLA_ROOT} e o banco ${JOOMLA_DB_NAME} serao removidos permanentemente apos backup."
    read -r -p "Digite APAGAR ${CLEAN_DOMAIN_ID} para continuar: " DELETE_CONFIRM
    [ "$DELETE_CONFIRM" = "APAGAR ${CLEAN_DOMAIN_ID}" ] || die "Confirmacao incorreta; nada foi removido."
    read -r -p "Digite novamente CONFIRMO para autorizar a remocao permanente: " DELETE_CONFIRM_2
    [ "$DELETE_CONFIRM_2" = "CONFIRMO" ] || die "Confirmacao incorreta; nada foi removido."
    command -v mysqldump >/dev/null 2>&1 || die "mysqldump ausente; backup do banco obrigatorio."
    BACKUP_DIR="/root/backup_reinstall_joomla_${CLEAN_DOMAIN_ID}_${LOG_TIMESTAMP}"
    install -d -m 700 "$BACKUP_DIR"
    tar --one-file-system --ignore-failed-read -czf "$BACKUP_DIR/site.tar.gz" -C "$(dirname "$JOOMLA_ROOT")" "$(basename "$JOOMLA_ROOT")" || die "Falha no backup dos arquivos; nada removido."
    [ -s "$BACKUP_DIR/site.tar.gz" ] || die "Backup de arquivos vazio; nada removido."
    if ! DB_EXISTS=$(MYSQL_PWD="$DB_ROOT_PASS" mariadb --protocol=socket --batch --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${JOOMLA_DB_NAME}';" 2>/dev/null); then
        die "Falha ao verificar a existencia do banco; nada removido."
    fi
    if [ "$DB_EXISTS" = "$JOOMLA_DB_NAME" ]; then
        MYSQL_PWD="$DB_ROOT_PASS" mysqldump --protocol=socket --single-transaction --routines --triggers "$JOOMLA_DB_NAME" > "$BACKUP_DIR/database.sql" || die "Falha no dump do banco; nada removido."
        [ -s "$BACKUP_DIR/database.sql" ] || die "Dump do banco vazio; nada removido."
        chmod 600 "$BACKUP_DIR/database.sql"
        log_success "Backup de arquivos e banco validado em $BACKUP_DIR. A remocao sera limitada ao diretorio e banco informados."
    else
        log_warning "Banco '${JOOMLA_DB_NAME}' nao existe; nenhum dump foi necessario. O backup dos arquivos permanece em $BACKUP_DIR."
    fi
    rm -rf -- "${JOOMLA_ROOT:?}"/* "${JOOMLA_ROOT:?}"/.[!.]* "${JOOMLA_ROOT:?}"/..?* 2>/dev/null || die "Falha ao limpar o diretorio; backup preservado."
    MYSQL_PWD="$DB_ROOT_PASS" mariadb --protocol=socket -e "DROP DATABASE IF EXISTS \`$JOOMLA_DB_NAME\`;" || die "Falha ao remover o banco; arquivos ja foram limpos, restaure pelo backup se necessario."
    unset MYSQL_PWD
    log_warning "Reinstalacao destrutiva autorizada e executada; backup permanece em $BACKUP_DIR."
fi

echo -e "\n  ${FG_CYAN}[i]${NC} Usuario do sistema/desenvolvedor para permissoes de escrita SFTP/SSH (opcional)."
echo -e "  ${FG_CYAN}[i]${NC} Usuario que sera dono do codigo para SFTP/SSH; se nao existir, sera criado com senha bloqueada."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuario desenvolvedor adicional [Deixe vazio se nao houver]: ${NC}")" DEV_USER
if [ -n "$DEV_USER" ]; then
    [[ "$DEV_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Nome de usuario do sistema invalido."
    [ "$DEV_USER" != www-data ] || die "O usuario de deploy deve ser diferente do servico web."
    if id "$DEV_USER" >/dev/null 2>&1; then
        log_info "Usuario desenvolvedor configurado com acesso total ao diretorio web: ${FG_GREEN}${DEV_USER}${NC}"
    else
        useradd --create-home --shell /bin/bash --user-group "$DEV_USER" || die "Falha ao criar usuario desenvolvedor."
        passwd --lock "$DEV_USER" > /dev/null 2>&1 || die "Falha ao bloquear senha inicial do usuario."
        log_success "Usuario desenvolvedor '${DEV_USER}' criado; senha bloqueada. Configure acesso SSH por chave antes do deploy."
    fi
else
    log_info "Nenhum usuario adicional informado (apenas www-data)."
fi

echo -e "  ${FG_CYAN}[i]${NC} Ativa HTTPS diretamente; exige DNS apontado e portas 80/443 acessiveis."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Configurar HTTPS com Let's Encrypt agora? (s/N): ${NC}")" ENABLE_TLS
ENABLE_TLS=${ENABLE_TLS,,}
LE_EMAIL=""
if [[ "$ENABLE_TLS" == "s" || "$ENABLE_TLS" == "sim" ]]; then
    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} E-mail para avisos do certificado: ${NC}")" LE_EMAIL
    [[ "$LE_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "E-mail invalido para o Let's Encrypt."
    ENABLE_TLS="s"
    log_info "HTTPS sera configurado apos a validacao do VirtualHost."
else
    ENABLE_TLS="n"
    log_warning "HTTPS nao sera configurado; nao conclua o Joomla nem autentique administradores via HTTP em producao."
fi

UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "24.04")
if [[ "$UBUNTU_VER" == "26.04" ]]; then
    PHP_VER="8.5"
    log_info "Ubuntu 26.04 detectado: Versao do PHP configurada automaticamente: ${FG_GREEN}PHP 8.5${NC}"
else
    PHP_VER="8.3"
    log_info "Ubuntu ${UBUNTU_VER} LTS detectado: Versao do PHP configurada automaticamente: ${FG_GREEN}PHP 8.3 (Recomendado Joomla 5)${NC}"
fi

DOWNLOAD_JOOMLA="s"
echo -e "  ${FG_CYAN}[i]${NC} Instale somente modulos exigidos por extensoes Joomla; deixe vazio se nao souber."
read -r -p "Extensoes opcionais PHP (soap imagick bcmath apcu redis igbinary), separadas por espaco [nenhuma]: " PHP_EXTRA_INPUT
read -r -a PHP_EXTRA_MODULES <<< "$PHP_EXTRA_INPUT"
for module in "${PHP_EXTRA_MODULES[@]}"; do
    case "$module" in soap|imagick|bcmath|apcu|redis|igbinary) ;; *) die "Extensao opcional invalida: $module" ;; esac
done
echo -e "  ${FG_CYAN}[i]${NC} Informe somente pastas que recebem uploads; scripts PHP serao bloqueados nelas."
read -r -p "Pastas adicionais de upload, separadas por espaco [phocadownloadpap]: " EXTRA_UPLOAD_INPUT
read -r -a EXTRA_UPLOAD_DIRS <<< "${EXTRA_UPLOAD_INPUT:-phocadownloadpap}"
UPLOAD_REGEX="assets|images|cache|tmp|logs|media|administrator/cache|administrator/logs"
for relative_dir in "${EXTRA_UPLOAD_DIRS[@]}"; do
    [[ "$relative_dir" =~ ^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$ ]] || die "Diretorio adicional invalido."
    case "$relative_dir" in administrator|administrator/*|components|components/*|plugins|plugins/*|modules|modules/*|libraries|libraries/*|templates|templates/*|includes|includes/*|cli|cli/*|api|api/*|installation|installation/*) die "Nao conceda escrita a diretorios de codigo." ;; esac
    UPLOAD_REGEX+="|${relative_dir}"
done
echo -e "  ${FG_CYAN}[i]${NC} Informe somente o IPv4 do proxy reverso ou balanceador que encaminha requisicoes para este servidor."
echo -e "  ${FG_CYAN}[i]${NC} Nao informe o IP do visitante. Com Cloudflare, deixe vazio e configure os intervalos oficiais separadamente."
echo -e "  ${FG_CYAN}[i]${NC} Se o dominio aponta diretamente para esta maquina, pressione ENTER."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} IPv4 do proxy confiavel [vazio: acesso direto]: ${NC}")" TRUSTED_PROXY
if [[ -n "$TRUSTED_PROXY" ]]; then
    [[ "$TRUSTED_PROXY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "IPv4 de proxy invalido."
    IFS=. read -r -a OCTETS <<< "$TRUSTED_PROXY"
    for octet in "${OCTETS[@]}"; do ((10#$octet <= 255)) || die "IPv4 de proxy invalido."; done
fi
log_info "Proxy confiavel: ${TRUSTED_PROXY:-nenhum}; restrinja a origem no firewall de borda."
log_info "Extensoes opcionais: ${PHP_EXTRA_MODULES[*]:-nenhuma}; uploads adicionais: ${EXTRA_UPLOAD_DIRS[*]}."

draw_separator

# ==============================================================================
# 3. ATUALIZACAO DO SISTEMA E PRE-REQUISITOS
# ==============================================================================
print_header "PREPARANDO SISTEMA, DEPENDENCIAS E AUDITD"

log_info "Atualizando a lista de pacotes do APT..."
apt-get update -y > /dev/null 2>&1 || die "Falha ao atualizar os indices APT."
log_success "Lista de pacotes atualizada."

log_info "Instalando dependencias essenciais de infraestrutura e auditoria..."
PRE_REQ_PACKAGES=(
    "software-properties-common"
    "curl"
    "wget"
    "ca-certificates"
    "gnupg2"
    "openssl"
    "jq"
    "lsb-release"
    "acl"
    "unzip"
    "tar"
    "cron"
    "logrotate"
    "auditd"
    "audispd-plugins"
    "ufw"
    "fail2ban"
    "openssh-server"
)

if [ "$ENABLE_TLS" = "s" ]; then
    PRE_REQ_PACKAGES+=("certbot" "python3-certbot-apache")
fi

for pkg in "${PRE_REQ_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg " > /dev/null 2>&1; then
        log_info "Pacote '$pkg' ja esta instalado."
    else
        log_info "Instalando '$pkg'..."
        if apt-get install -y "$pkg" > /dev/null 2>&1; then
            PACOTES_INSTALADOS+=("$pkg")
            log_success "Pacote '$pkg' instalado com sucesso."
        else
            die "Falha na instalacao do pacote obrigatorio '$pkg'."
        fi
    fi
done
# ==============================================================================
# 4. INSTALACAO E HARDENING DO APACHE 2.4.x
# ==============================================================================
print_header "INSTALACAO E HARDENING DO APACHE 2.4.x"

log_info "Instalando o Apache2..."
if apt-get install -y apache2 > /dev/null 2>&1; then
    PACOTES_INSTALADOS+=("apache2")
    log_success "Apache2 instalado com sucesso."
else
    log_error "Falha na instalacao do Apache2."
    exit 1
fi

log_info "Habilitando modulos obrigatorios e recomendados para Joomla 5 no Apache..."
APACHE_MODULES=("rewrite" "headers" "deflate" "expires" "http2" "env" "dir" "mime" "setenvif" "filter" "proxy_fcgi")
if [ "$ENABLE_TLS" = s ]; then APACHE_MODULES+=("ssl"); fi
for mod in "${APACHE_MODULES[@]}"; do
    a2enmod "$mod" > /dev/null 2>&1 || die "Falha ao habilitar o modulo Apache '$mod'."
    log_success "Modulo Apache '$mod' habilitado."
done

log_info "Desativando modulos desnecessarios/inseguros no Apache (autoindex, status, mpm_prefork)..."
for mod in dav_fs dav_lock dav cgi cgid include info status autoindex userdir; do
    if [ -e "/etc/apache2/mods-enabled/${mod}.load" ]; then
        log_info "Desativando modulo Apache: $mod"
        a2dismod -f "$mod" > /dev/null 2>&1 || die "Falha ao desativar $mod; verifique dependencias."
    fi
done

log_info "Aplicando endurecimento de seguranca no Apache (ocultacao de banners, headers e desativacao de TRACE)..."
if [ -f /etc/apache2/conf-available/security.conf ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    grep -q "^TraceEnable Off" /etc/apache2/conf-available/security.conf || echo "TraceEnable Off" >> /etc/apache2/conf-available/security.conf
    
    grep -q "X-Content-Type-Options" /etc/apache2/conf-available/security.conf || echo 'Header always set X-Content-Type-Options "nosniff"' >> /etc/apache2/conf-available/security.conf
    grep -q "X-Frame-Options" /etc/apache2/conf-available/security.conf || echo 'Header always set X-Frame-Options "SAMEORIGIN"' >> /etc/apache2/conf-available/security.conf
    grep -q "X-XSS-Protection" /etc/apache2/conf-available/security.conf || echo 'Header always set X-XSS-Protection "1; mode=block"' >> /etc/apache2/conf-available/security.conf
    grep -q "Referrer-Policy" /etc/apache2/conf-available/security.conf || echo 'Header always set Referrer-Policy "strict-origin-when-cross-origin"' >> /etc/apache2/conf-available/security.conf
    
    a2enconf security > /dev/null 2>&1 || die "Falha ao habilitar configuracao de seguranca Apache."
fi

# ==============================================================================
# 5. INSTALACAO E HARDENING DO MARIADB SERVER (PACOTE ASSINADO DA DISTRIBUICAO)
# ==============================================================================
print_header "INSTALACAO E HARDENING DO MARIADB SERVER"

log_info "Usando o pacote MariaDB assinado pelo repositorio da distribuicao..."

log_info "Instalando o MariaDB Server..."
if apt-get install -y mariadb-server mariadb-client > /dev/null 2>&1; then
    PACOTES_INSTALADOS+=("mariadb-server" "mariadb-client")
    log_success "MariaDB Server instalado com sucesso."
else
    die "Falha na instalacao do MariaDB Server."
fi

log_info "Iniciando e habilitando o servico MariaDB..."
systemctl enable --now mariadb > /dev/null 2>&1 || die "Falha ao iniciar o MariaDB."
log_success "Servico MariaDB em execucao ($(mariadb --version 2>/dev/null | awk '{print $5}' | tr -d ','))."

log_info "Otimizando charset MariaDB para UTF8MB4 (Obrigatorio Joomla 5)..."
cat <<'EOF' > /etc/mysql/mariadb.conf.d/60-joomla5.cnf
[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[mysqld]
bind-address           = 127.0.0.1
character-set-server   = utf8mb4
collation-server       = utf8mb4_unicode_ci
innodb_file_per_table  = 1
innodb_buffer_pool_size = 256M
max_allowed_packet     = 64M
sql_mode               = "STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
EOF

systemctl restart mariadb > /dev/null 2>&1 || die "Falha ao reiniciar o MariaDB com a configuracao segura."

log_info "Aplicando endurecimento de seguranca no MariaDB e criando banco de dados do Joomla 5..."

SQL_DB_ROOT_PASS=$(sql_escape_literal "$DB_ROOT_PASS")
SQL_JOOMLA_DB_PASS=$(sql_escape_literal "$JOOMLA_DB_PASS")
TMP_SQL="${RUNTIME_DIR}/mariadb_setup.sql"
install -m 600 /dev/null "$TMP_SQL"
cat <<EOF > "$TMP_SQL"
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${SQL_DB_ROOT_PASS}');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
CREATE DATABASE IF NOT EXISTS \`${JOOMLA_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${JOOMLA_DB_USER}'@'localhost' IDENTIFIED BY '${SQL_JOOMLA_DB_PASS}';
ALTER USER '${JOOMLA_DB_USER}'@'localhost' IDENTIFIED BY '${SQL_JOOMLA_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${JOOMLA_DB_NAME}\`.* TO '${JOOMLA_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

mariadb --protocol=socket < "$TMP_SQL" > /dev/null 2>&1 || die "Falha ao aplicar o hardening e criar o banco pelo socket local."
rm -f "$TMP_SQL"
TMP_SQL=""

CREDENTIALS_FILE="/root/credenciais_joomla_${CLEAN_DOMAIN_ID}_${LOG_TIMESTAMP}.txt"
[ ! -e "$CREDENTIALS_FILE" ] || die "Arquivo de credenciais ja existe; nao sera sobrescrito."
install -m 600 /dev/null "$CREDENTIALS_FILE"
{
    printf 'Dominio: %s\n' "$DOMAIN_NAME"
    printf 'Banco: %s\n' "$JOOMLA_DB_NAME"
    printf 'Usuario: %s\n' "$JOOMLA_DB_USER"
    printf 'Senha Joomla DB: %s\n' "$JOOMLA_DB_PASS"
    printf 'Senha MariaDB Root: %s\n' "$DB_ROOT_PASS"
} > "$CREDENTIALS_FILE"
chmod 600 "$CREDENTIALS_FILE"
unset SQL_DB_ROOT_PASS SQL_JOOMLA_DB_PASS

log_success "Banco '${JOOMLA_DB_NAME}' e usuario '${JOOMLA_DB_USER}' criados com permissoes completas em UTF8MB4."
# ==============================================================================
# 6. INSTALACAO DO PHP (RECOMENDADO JOOMLA 5)
# ==============================================================================
print_header "INSTALACAO DO PHP (RECOMENDADO JOOMLA 5)"

UBUNTU_RELEASE=$(awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
case "$UBUNTU_RELEASE" in
    22.04)
        PHP_VER=8.3
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1 || die "Falha no PPA PHP."
        apt-get update -y > /dev/null 2>&1 || die "Falha APT."
        ;;
    24.04) PHP_VER=8.3 ;;
    26.04) PHP_VER=8.5 ;;
    *) die "Ubuntu nao suportado." ;;
esac
JOOMLA_PHP_PACKAGES=()
for module in fpm cli common mysql curl gd mbstring xml zip intl "${PHP_EXTRA_MODULES[@]}"; do
    pkg="php${PHP_VER}-${module}"
    apt-get install -y "$pkg" > /dev/null 2>&1 || die "Falha ao instalar $pkg."
    JOOMLA_PHP_PACKAGES+=("$pkg")
    PACOTES_INSTALADOS+=("$pkg")
    log_success "Pacote PHP instalado: $pkg"
done

# 7. HARDENING POR POOL: PRESERVA CLI E OUTRAS APLICACOES
print_header "PHP-FPM DEDICADO AO JOOMLA"
POOL_ID="joomla_$(printf '%s' "$DOMAIN_NAME" | sha256sum | cut -c1-16)"
FPM_SOCK="/run/php/${POOL_ID}.sock"
cat > "/etc/php/${PHP_VER}/fpm/pool.d/${POOL_ID}.conf" <<EOF
[$POOL_ID]
user = www-data
group = www-data
listen = $FPM_SOCK
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 10s
pm.max_requests = 500
clear_env = yes
security.limit_extensions = .php
php_admin_flag[display_errors] = off
php_admin_flag[display_startup_errors] = off
php_admin_flag[log_errors] = on
php_admin_flag[expose_php] = off
php_admin_flag[allow_url_include] = off
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec
php_admin_value[user_ini.filename] =
php_admin_value[auto_prepend_file] =
php_admin_value[auto_append_file] =
php_admin_value[cgi.fix_pathinfo] = 0
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.use_only_cookies] = 1
php_admin_value[session.use_strict_mode] = 1
php_admin_value[session.cookie_samesite] = Lax
php_admin_value[memory_limit] = 512M
php_admin_value[upload_max_filesize] = 64M
php_admin_value[post_max_size] = 72M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300
php_admin_value[max_input_vars] = 5000
php_admin_value[date.timezone] = America/Sao_Paulo
EOF
php-fpm"${PHP_VER}" -t > /dev/null 2>&1 || die "Configuracao PHP-FPM invalida."
systemctl enable --now "php${PHP_VER}-fpm" > /dev/null 2>&1 || die "Falha ao ativar PHP-FPM."
systemctl reload "php${PHP_VER}-fpm" || die "Falha ao recarregar PHP-FPM."
for php_mod in /etc/apache2/mods-enabled/php*.load; do
    [ ! -e "$php_mod" ] || a2dismod -f "$(basename "$php_mod" .load)" > /dev/null
 done
a2dismod -f mpm_prefork > /dev/null || die "Falha ao desativar prefork."
a2enmod mpm_event proxy_fcgi setenvif > /dev/null || die "Falha ao ativar Event/FPM."
log_success "PHP-FPM dedicado pronto; CLI preservado, cURL disponivel."
# ==============================================================================
# 8. CONFIGURACAO DE VIRTUALHOST APACHE COM BLINDAGEM ANTI-WEBSHELL
# ==============================================================================
print_header "CONFIGURACAO DO VIRTUALHOST APACHE COM BLINDAGEM DE EXECUCAO"

mkdir -p "$JOOMLA_ROOT"
chown root:www-data "$JOOMLA_ROOT"
chmod 750 "$JOOMLA_ROOT"
PARENT_DIR="$(dirname "$JOOMLA_ROOT")"
while [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ]; do
    setfacl -m u:www-data:--x "$PARENT_DIR" > /dev/null 2>&1 || die "Falha ao conceder travessia segura em $PARENT_DIR."
    PARENT_DIR="$(dirname "$PARENT_DIR")"
done
    if [[ -n "$TRUSTED_PROXY" ]]; then
        a2enmod remoteip > /dev/null
        printf 'RemoteIPHeader X-Forwarded-For\nRemoteIPTrustedProxy %s\n' "$TRUSTED_PROXY" > /etc/apache2/conf-available/web-proxy.conf
        a2enconf web-proxy > /dev/null
    fi
APACHE_ROOT_REGEX=$(printf '%s' "$JOOMLA_ROOT" | sed 's/[][\\.^$*+?{}|()]/\\&/g')
install -d -m 755 /etc/apache2/joomla-rules

cat <<EOF > "/etc/apache2/sites-available/${DOMAIN_NAME}.conf"
<VirtualHost *:80>
    ServerName ${DOMAIN_NAME}
    ServerAlias www.${DOMAIN_NAME}
    ServerAdmin webmaster@${DOMAIN_NAME}
    DocumentRoot "${JOOMLA_ROOT}"
    DirectoryIndex index.php index.html

    <Directory "${JOOMLA_ROOT}">
        Options -Indexes -ExecCGI -Includes +FollowSymLinks
        # Regras oficiais copiadas para configuracao administrada por root.
        AllowOverride None
        AllowOverrideList None
        IncludeOptional /etc/apache2/joomla-rules/${CLEAN_DOMAIN_ID}.conf
        <FilesMatch "\.php$">
            SetHandler "proxy:unix:${FPM_SOCK}|fcgi://localhost/"
        </FilesMatch>
        Require all granted
    </Directory>

    # Bloqueio Critico: Proibe execucao de qualquer interpretador PHP em pastas de upload/estaticos
    <DirectoryMatch "^${APACHE_ROOT_REGEX}/(${UPLOAD_REGEX})(/|$)">
        AllowOverride None
        AllowOverrideList None
        <FilesMatch "(?i)\.(php|phtml|php[0-9]*|phps|pht|phar|inc)([./]|$)">
            Require all denied
        </FilesMatch>
    </DirectoryMatch>

    # Bloqueio de Seguranca: Arquivos Ocultos especificos (.git, .env, etc.)
    <LocationMatch "(^|/)\.(?!well-known/)">
        Require all denied
    </LocationMatch>

    # Bloqueio de Seguranca: Impedir visualizacao direta de backups, logs, dumps e scripts.
    # A excecao e limitada a css.gz e js.gz, recursos compactados nativos do Joomla.
    <FilesMatch "(?i)^(?!.*\.(css|js)\.gz$).*\.(log|sql|bak|old|orig|ini|sh|dist|tar|gz|zip)$">
        Require all denied
    </FilesMatch>

    <FilesMatch "(?i)^configuration\.php$">
        Require all denied
    </FilesMatch>

    # Headers de Seguranca recomendados (Hardening de Producao)
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "0"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "frame-ancestors 'self'; object-src 'none'; base-uri 'self'"
    Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"

    # Logs customizados
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_access.log combined
</VirtualHost>
EOF

cat <<'EOF' > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    <Directory "/var/www/html">
        AllowOverride None
        Require all denied
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/default_error.log
    CustomLog ${APACHE_LOG_DIR}/default_access.log combined
</VirtualHost>
EOF

a2ensite 000-default.conf > /dev/null 2>&1 || true
a2ensite "${DOMAIN_NAME}.conf" > /dev/null 2>&1 || die "Falha ao habilitar o VirtualHost do Joomla."
apache2ctl configtest > /dev/null 2>&1 || die "Configuracao Apache invalida; o servico nao sera reiniciado."
log_success "VirtualHost ${DOMAIN_NAME}.conf e 000-default.conf ativados com bloqueio de execucao PHP em pastas estaticas."
systemctl reload apache2 > /dev/null 2>&1 || systemctl restart apache2 > /dev/null 2>&1 || die "Falha ao ativar o Apache com a configuracao validada."

TLS_STATUS="Nao configurado"
if [ "$ENABLE_TLS" = "s" ]; then
    log_info "Solicitando certificado TLS ao Let's Encrypt..."
    ufw allow 80/tcp > /dev/null 2>&1 || die "Falha ao liberar HTTP para certificado."
    ufw allow 443/tcp > /dev/null 2>&1 || die "Falha ao liberar HTTPS."
    certbot --apache --non-interactive --agree-tos --redirect \
        --email "$LE_EMAIL" -d "$DOMAIN_NAME" -d "www.${DOMAIN_NAME}" \
        || die "Falha ao emitir o certificado. Verifique DNS e acesso externo a porta 80."
    cat <<'EOF' > /etc/apache2/conf-available/joomla-tls-security.conf
Header always set Strict-Transport-Security "max-age=31536000" "expr=%{HTTPS} == 'on'"
EOF
    a2enconf joomla-tls-security > /dev/null 2>&1 || die "Falha ao habilitar HSTS."
    echo 'php_admin_value[session.cookie_secure] = 1' >> "/etc/php/${PHP_VER}/fpm/pool.d/${POOL_ID}.conf"
    php-fpm"${PHP_VER}" -t > /dev/null 2>&1 || die "PHP-FPM TLS invalido."
    apache2ctl configtest > /dev/null 2>&1 || die "Configuracao TLS do Apache invalida."
    systemctl restart "php${PHP_VER}-fpm" > /dev/null 2>&1 || die "Falha ao reiniciar PHP-FPM apos habilitar cookies seguros."
    systemctl reload apache2 > /dev/null 2>&1 || systemctl restart apache2 > /dev/null 2>&1 || die "Falha ao ativar o VirtualHost HTTPS."
    TLS_STATUS="Ativo com Let's Encrypt, redirecionamento e HSTS"
    log_success "HTTPS ativado com redirecionamento obrigatorio e cookies seguros."
fi

# ==============================================================================
# 9. DOWNLOAD E EXTRACAO DO JOOMLA 5.x
# ==============================================================================
if [[ "$DOWNLOAD_JOOMLA" != "n" && "$DOWNLOAD_JOOMLA" != "nao" ]]; then
    print_header "DOWNLOAD DO PACOTE OFICIAL DO JOOMLA 5"
    log_info "Consultando a versao Joomla 5 mais recente e seu digest oficial no GitHub..."

    RELEASES_JSON="${RUNTIME_DIR}/joomla_releases.json"
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        -o "$RELEASES_JSON" "https://api.github.com/repos/joomla/joomla-cms/releases?per_page=100" \
        || die "Falha ao consultar os releases oficiais do Joomla."

    JOOMLA_ASSET=$(jq -c '([.[] | select(.draft == false and .prerelease == false) | select(.tag_name | startswith("5."))] | .[0].assets? // []) | map(select(.name | test("^Joomla_5.*Stable-Full_Package\\.zip$"))) | .[0] // empty' "$RELEASES_JSON")
    [ -n "$JOOMLA_ASSET" ] || die "Nenhum pacote Joomla 5 completo foi localizado no repositorio oficial."
    LATEST_JOOMLA_ZIP=$(jq -r '.browser_download_url' <<< "$JOOMLA_ASSET")
    [[ "$LATEST_JOOMLA_ZIP" == https://github.com/joomla/joomla-cms/releases/download/* ]] || die "Origem inesperada do pacote Joomla."
    JOOMLA_DIGEST=$(jq -r '.digest // empty' <<< "$JOOMLA_ASSET")
    [[ "$JOOMLA_DIGEST" == sha256:* ]] || die "O release nao publicou digest SHA-256; download recusado por seguranca."
    EXPECTED_SHA256=${JOOMLA_DIGEST#sha256:}

    JOOMLA_ARCHIVE="${RUNTIME_DIR}/joomla_pkg.zip"
    log_info "Baixando pacote oficial por HTTPS..."
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        -o "$JOOMLA_ARCHIVE" "$LATEST_JOOMLA_ZIP" || die "Falha no download do Joomla."
    ACTUAL_SHA256=$(sha256sum "$JOOMLA_ARCHIVE" | awk '{print $1}')
    [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || die "Checksum SHA-256 do Joomla divergente; arquivo descartado."
    unzip -tq "$JOOMLA_ARCHIVE" > /dev/null 2>&1 || die "Pacote Joomla corrompido ou invalido."
    zipinfo -1 "$JOOMLA_ARCHIVE" > "$RUNTIME_DIR/archive_paths.txt"
    if grep -Eq '(^/|(^|/)\.\.(/|$)|\\)' "$RUNTIME_DIR/archive_paths.txt"; then
        die "Pacote Joomla contem caminho inseguro e nao sera extraido."
    fi
    zipinfo -l "$JOOMLA_ARCHIVE" > "$RUNTIME_DIR/archive_entries.txt"
    if grep -q '^l' "$RUNTIME_DIR/archive_entries.txt"; then
        die "Pacote contem links simbolicos e nao sera extraido."
    fi

    log_info "Checksum validado. Extraindo Joomla 5 em ${JOOMLA_ROOT}..."
    unzip -q -o "$JOOMLA_ARCHIVE" -d "$JOOMLA_ROOT" || die "Falha ao extrair o Joomla."
    rm -f "$JOOMLA_ARCHIVE"
    JOOMLA_ARCHIVE=""

    if [ -f "${JOOMLA_ROOT}/htaccess.txt" ]; then
        install -o root -g root -m 644 "${JOOMLA_ROOT}/htaccess.txt" "/etc/apache2/joomla-rules/${CLEAN_DOMAIN_ID}.conf"
        log_success "Regras oficiais Joomla instaladas fora do DocumentRoot; .htaccess nao e interpretado."
    fi
    if [ -f "${JOOMLA_ROOT}/configuration.php" ]; then
        log_warning "configuration.php existente foi preservado; credenciais nao foram alteradas automaticamente."
    fi
    log_success "Joomla 5 verificado e extraido com sucesso em ${JOOMLA_ROOT}."
fi
if [ -n "$(find "$JOOMLA_ROOT" -type l -print -quit)" ]; then
    die "Links simbolicos no pacote: revise antes de aplicar permissoes."
fi
# ==============================================================================
# 10. PERMISSOES E POSIX ACLs
# ==============================================================================
print_header "PERMISSOES E SEGURANCA NO DIRETORIO WEB"

log_info "Concedendo travessia somente ao usuario do Apache nos diretorios pai..."
PARENT_DIR="$(dirname "$JOOMLA_ROOT")"
while [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ]; do
    setfacl -m u:www-data:--x "$PARENT_DIR" > /dev/null 2>&1 || die "Falha ao aplicar ACL de travessia em $PARENT_DIR."
    PARENT_DIR="$(dirname "$PARENT_DIR")"
done

CODE_OWNER="root"
if [ -n "$DEV_USER" ] && id "$DEV_USER" >/dev/null 2>&1; then
    CODE_OWNER="$DEV_USER"
fi

log_info "Definindo proprietario ${CODE_OWNER} e permissoes do diretorio Joomla."
setfacl -R -b "$JOOMLA_ROOT"
find "$JOOMLA_ROOT" -type d -exec setfacl -k {} +
chown -R "${CODE_OWNER}:www-data" "$JOOMLA_ROOT"
find "$JOOMLA_ROOT" -type d -exec chmod 750 {} +
find "$JOOMLA_ROOT" -type f -exec chmod 640 {} +

# O instalador web do Joomla precisa criar/atualizar este arquivo uma vez.
# Ele continua bloqueado para acesso HTTP pelo VirtualHost e deve ser travado
# novamente pelo administrador depois que a instalacao terminar.
if [ ! -f "${JOOMLA_ROOT}/configuration.php" ]; then
    install -o www-data -g www-data -m 660 /dev/null "${JOOMLA_ROOT}/configuration.php"
    log_warning "configuration.php temporariamente gravavel pelo Apache para concluir a instalacao web."
else
    log_info "configuration.php existente preservado; permissao nao foi alterada automaticamente."
fi

JOOMLA_WRITABLE_DIRS=(
    "cache" "tmp" "logs" "images" "media"
    "administrator/cache" "administrator/logs" "${EXTRA_UPLOAD_DIRS[@]}"
)
for relative_dir in "${JOOMLA_WRITABLE_DIRS[@]}"; do
    writable_dir="${JOOMLA_ROOT}/${relative_dir}"
    mkdir -p "$writable_dir"
    chown -R www-data:www-data "$writable_dir"
    find "$writable_dir" -type d -exec chmod 750 {} +
    find "$writable_dir" -type f -exec chmod 640 {} +
    setfacl -R -m u:www-data:rwX "$writable_dir"
    setfacl -R -d -m u:www-data:rwx,m::rwx "$writable_dir"
done

log_success "Codigo somente legivel pelo Apache; escrita limitada a uploads, cache, logs e temporarios."
log_warning "Apos concluir a instalacao web, trave configuration.php: chown root:www-data e chmod 640."
log_warning "Atualizacoes pelo painel exigem janela de manutencao; veja a ajuda antes de liberar escrita temporaria."
# ==============================================================================
# 11. CONFIGURACAO DE ROTINAS AGENDADAS (CRON JOBS DO JOOMLA)
# ==============================================================================
print_header "CONFIGURACAO DE ROTINAS AGENDADAS DO JOOMLA (CRON JOBS)"

log_info "Criando agendamento oficial das rotinas CLI do Joomla 5 no Crontab..."
JOOMLA_CRON_FILE="/etc/cron.d/joomla5_${CLEAN_DOMAIN_ID}_scheduler"
cat <<EOF > "$JOOMLA_CRON_FILE"
# Rotina agendada do Joomla 5 para ${DOMAIN_NAME} (Executa a cada 5 minutos como www-data)
*/5 * * * * www-data test -s ${JOOMLA_ROOT}/configuration.php && test ! -d ${JOOMLA_ROOT}/installation && /usr/bin/php${PHP_VER} ${JOOMLA_ROOT}/cli/joomla.php scheduler:run --quiet > /dev/null 2>&1
EOF
chmod 644 "$JOOMLA_CRON_FILE"
log_success "Cron Job configurado: '${JOOMLA_ROOT}/cli/joomla.php scheduler:run' a cada 5 minutos."

# ==============================================================================
# 12. CONFIGURACAO DO LINUX AUDIT DAEMON (AUDITD) PARA AUDITORIA WEB
# ==============================================================================
print_header "CONFIGURACAO DO LINUX AUDIT DAEMON (AUDITD)"

log_info "Configurando retencao e rotacao de logs em /etc/audit/auditd.conf..."
if [ -f /etc/audit/auditd.conf ]; then
    sed -i 's/^max_log_file =.*/max_log_file = 50/' /etc/audit/auditd.conf
    sed -i 's/^num_logs =.*/num_logs = 10/' /etc/audit/auditd.conf
    sed -i 's/^max_log_file_action =.*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf
    sed -i 's/^space_left =.*/space_left = 100/' /etc/audit/auditd.conf
    sed -i 's/^space_left_action =.*/space_left_action = SYSLOG/' /etc/audit/auditd.conf
    sed -i 's/^admin_space_left_action =.*/admin_space_left_action = SUSPEND/' /etc/audit/auditd.conf
    log_success "Parametros de rotacao e protecao de disco configurados no auditd.conf."
fi

log_info "Criando regras de auditoria em tempo real em /etc/audit/rules.d/web_security.rules..."
mkdir -p /etc/audit/rules.d
cat <<EOF > /etc/audit/rules.d/web_security.rules
# ==============================================================================
# REGRAS DE AUDITORIA DE SEGURANCA WEB (AUDITD)
# Monitoramento de alteracoes em arquivos, configuracoes e servicos
# ==============================================================================

# 1. Monitora criacao, escrita (w) e alteracao de atributos/permissoes (a) no diretorio do site
-w ${JOOMLA_ROOT} -p wa -k web_modificacoes

# 2. Monitora alteracoes nos arquivos de configuracao do Apache
-w /etc/apache2/ -p wa -k config_apache

# 3. Monitora alteracoes nos arquivos de configuracao do PHP
-w /etc/php/ -p wa -k config_php

# 4. Monitora alteracoes nos arquivos de configuracao do MariaDB / MySQL
-w /etc/mysql/ -p wa -k config_mysql
EOF

log_info "Carregando regras de auditoria no kernel..."
if is_wsl; then
    AUDIT_STATUS="Indisponivel no WSL (kernel sem suporte a regras auditd)"
    log_warning "WSL detectado: o kernel nao permite regras auditd; auditoria em tempo real foi pulada somente neste ambiente."
else
    augenrules --load > /dev/null 2>&1 || die "Falha ao carregar as regras do auditd."
    systemctl enable --now auditd > /dev/null 2>&1 || die "Falha ao ativar o auditd."
    service auditd restart > /dev/null 2>&1 || die "Falha ao reiniciar o auditd."
    AUDIT_STATUS="Ativo (monitorando modificacoes web e configs)"
    log_success "Auditd ativo e monitorando modificacoes no diretorio '${JOOMLA_ROOT}' (tag: web_modificacoes)."
fi

# ==============================================================================
# 13. INTEGRACAO DE FIREWALL (UFW) E FAIL2BAN
# ==============================================================================
print_header "INTEGRACAO DE SEGURANCA DE BORDA (UFW & FAIL2BAN)"

log_info "Aplicando politica UFW de menor exposicao sem bloquear o SSH..."
systemctl enable --now ssh > /dev/null 2>&1 || systemctl enable --now sshd > /dev/null 2>&1 || die "Nao foi possivel iniciar o servico SSH."
SSH_PORTS=$(sshd -T | awk '$1 == "port" { print $2 }')
[ -n "$SSH_PORTS" ] || die "Nao foi possivel detectar portas SSH."
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
for SSH_PORT in $SSH_PORTS; do
    [[ "$SSH_PORT" =~ ^[0-9]{1,5}$ ]] || die "Porta SSH detectada invalida."
    ufw allow "${SSH_PORT}/tcp" > /dev/null
done
ufw allow 80/tcp > /dev/null
if [ "$ENABLE_TLS" = "s" ]; then
    ufw allow 443/tcp > /dev/null
fi
ufw --force enable > /dev/null || die "Falha ao habilitar o UFW."
log_success "UFW ativo: portas SSH detectadas, HTTP e HTTPS quando configurado."

if [ -d /etc/fail2ban/jail.d ]; then
    log_info "Configurando jaula modular do Fail2Ban para protecao Web..."
    cat <<'EOF' > /etc/fail2ban/jail.d/apache-joomla.local
[apache-auth]
enabled = true
port    = http,https
logpath = %(apache_error_log)s
maxretry = 5
findtime = 600
bantime  = 3600

[apache-badbots]
enabled  = true
port     = http,https
logpath  = %(apache_access_log)s
maxretry = 2
bantime  = 86400

EOF
    fail2ban-client -t > /dev/null 2>&1 || die "Configuracao do Fail2Ban invalida."
    systemctl enable --now fail2ban > /dev/null 2>&1 || die "Falha ao ativar o Fail2Ban."
    systemctl restart fail2ban > /dev/null 2>&1 || die "Falha ao reiniciar o Fail2Ban."
    log_success "Jaulas 'apache-auth' e 'apache-badbots' ativadas no Fail2Ban."
fi

php-fpm"${PHP_VER}" -t > /dev/null 2>&1 || die "PHP-FPM invalido na validacao final."
systemctl reload "php${PHP_VER}-fpm" > /dev/null 2>&1 || die "Falha ao recarregar PHP-FPM."
apache2ctl configtest > /dev/null 2>&1 || die "Configuracao Apache invalida na validacao final."
systemctl restart apache2 > /dev/null 2>&1 || die "Falha ao reiniciar o Apache na validacao final."
# ==============================================================================
# 14. PAINEL DE RESUMO FINAL E AUDITORIA
# ==============================================================================
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
SERVER_IP=${SERVER_IP:-"nao detectado"}
LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")

print_header "RESUMO DA INSTALACAO E BLINDAGEM - JOOMLA 5"

echo -e "  ${FG_GREEN}${BOLD}✔ AMBIENTE LAMP JOOMLA 5 ENDURECIDO E OPERACIONAL!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Dominio Configurado:${NC}     ${FG_CYAN}${DOMAIN_NAME}${NC}"
echo -e "  ${BOLD}Diretorio Web Raiz:${NC}      ${FG_CYAN}${JOOMLA_ROOT}${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}            Apache 2.4.x [Rewrite, HTTP/2, FastCGI, Headers e Anti-Webshell]"
echo -e "  ${BOLD}Banco de Dados:${NC}          MariaDB Server [UTF8MB4 / Collation Unicode CI]"
echo -e "  ${BOLD}Versao do PHP:${NC}           PHP ${PHP_VER} (FPM dedicado; opcionais: ${PHP_EXTRA_MODULES[*]:-nenhum})"
echo -e "  ${BOLD}Pacotes instalados:${NC}       ${FG_CYAN}${LISTA_PACOTES:-Nenhum pacote novo}${NC}"
echo -e "  ${BOLD}Permissoes POSIX ACL:${NC}    ${FG_GREEN}Escrita isolada nas pastas mutaveis (${JOOMLA_ROOT})${NC}"
echo -e "  ${BOLD}Tarefas Agendadas (Cron):${NC} ${FG_GREEN}Ativo (cli/joomla.php a cada 5min)${NC}"
echo -e "  ${BOLD}Auditoria em Tempo Real:${NC}  ${FG_CYAN}${AUDIT_STATUS}${NC}"
echo -e "  ${BOLD}HTTPS:${NC}                  ${FG_CYAN}${TLS_STATUS}${NC}"
echo -e "  ${BOLD}Firewall UFW & Fail2Ban:${NC}  ${FG_GREEN}Ativos com politica de entrada restritiva${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais do Banco de Dados:${NC}"
echo -e "    ▶ Servidor (Host):       ${FG_CYAN}localhost${NC}"
echo -e "    ▶ Nome do Banco:        ${FG_CYAN}${JOOMLA_DB_NAME}${NC}"
echo -e "    ▶ Usuario do Banco:      ${FG_CYAN}${JOOMLA_DB_USER}${NC}"
echo -e "    ▶ Senhas:                ${FG_YELLOW}Ocultas do console e do log${NC}"
echo -e "    ▶ Arquivo protegido:     ${FG_CYAN}${CREDENTIALS_FILE} (root:root / 600)${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}URLs de Acesso para Finalizar a Instalacao e Administracao:${NC}"
if [ "$ENABLE_TLS" = "s" ]; then
    echo -e "    ▶ Portal Principal: ${FG_CYAN}https://${DOMAIN_NAME}/${NC}"
    echo -e "    ▶ Painel Admin:     ${FG_CYAN}https://${DOMAIN_NAME}/administrator${NC}"
else
    echo -e "    ▶ Portal temporario: ${FG_YELLOW}http://${DOMAIN_NAME}/${NC} (configure HTTPS antes de autenticar)"
fi
echo -e "    ▶ Acesso direto por IP: ${FG_YELLOW}Bloqueado pelo VirtualHost padrao${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}斡️ MEDIDAS DE SEGURANCA E HARDENING APLICADAS:${NC}"
echo -e "  ${FG_YELLOW}1. Bloqueio de Execucao PHP em Pastas Estaticas (Apache):${NC}"
echo -e "    ▶ Proibe terminantemente execucao de .php/.phtml em assets, images, cache, tmp e media"
echo -e "    ▶ Bloqueio de acesso a arquivos de backup e logs (.sql, .bak, .log, .sh, .env, .git)"
echo -e "    ▶ Headers: nosniff, frame-ancestors, CSP basica, Referrer e Permissions-Policy"
echo -e "  ${FG_YELLOW}2. Protecao contra Injecao e Hardening do PHP:${NC}"
echo -e "    ▶ ${BOLD}disable_functions:${NC} Bloqueia exec, shell_exec, system, proc_open, popen, pcntl_exec"
echo -e "    ▶ ${BOLD}session.cookie_httponly = 1 / session.cookie_samesite = 'Lax'${NC} (Protecao CSRF/XSS)"
echo -e "    ▶ ${BOLD}allow_url_include = Off / expose_php = Off / display_errors = Off${NC}"
echo -e "  ${FG_YELLOW}3. Auditoria do Sistema em Tempo Real com Auditd:${NC}"
echo -e "    ▶ Rastreia qualquer arquivo criado, modificado ou excluido dentro de ${JOOMLA_ROOT}"
echo -e "    ▶ Consultar alteracoes web:  ${FG_CYAN}sudo ausearch -k web_modificacoes -i${NC}"
echo -e "    ▶ Consultar eventos recentes: ${FG_CYAN}sudo ausearch -k web_modificacoes -ts recent -i${NC}"
echo -e "    ▶ Relatorio consolidado:      ${FG_CYAN}sudo aureport -f -i --summary${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}⏱️ O QUE FAZ O AGENDADOR DE TAREFAS (CRON JOOMLA 5):${NC}"
echo -e "  O comando ${FG_CYAN}cli/joomla.php scheduler:run${NC} executa a cada 5min em segundo plano:"
echo -e "    ▶ Executa somente tarefas habilitadas e vencidas no Agendador Joomla; configure-as no painel."
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}网 APONTAMENTO DE DNS RECOMENDADO:${NC}"
echo -e "  Crie no painel DNS do seu dominio (${DOMAIN_NAME}):"
echo -e "    ▶ IP local detectado: ${FG_GREEN}${SERVER_IP}${NC} (confirme o IP publico/NAT antes de publicar)"
echo -e "    ▶ Tipo ${FG_CYAN}A${NC}  | Nome: ${FG_YELLOW}@${NC} e ${FG_YELLOW}www${NC} | Destino: ${FG_GREEN}<IP_PUBLICO_CONFIRMADO>${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 15. GERACAO E SALVAMENTO DOS ARQUIVOS DE LOG DA INSTALACAO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALACAO"

cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do ultimo log: /root/${LOG_LATEST}"

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

# O trap salva o relatorio completo, inclusive em falhas, e remove os temporarios.

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}✔ Instalacao do ambiente Joomla 5 finalizada com sucesso!${NC}\n"
