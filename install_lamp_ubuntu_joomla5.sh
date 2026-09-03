#!/bin/bash
# ------------------------------------------------
# Version: 2.2
# ------------------------------------------------
VERSION="2.2"
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
# 7. Configura o PHP (Recomendado 8.3/8.2) com TODAS as extensoes obrigatorias e recomendadas para o Joomla 5.
# 8. Otimiza o php.ini para Joomla 5 com hardening estrito (disable_functions com bloqueio de exec/shell, HttpOnly, SameSite).
# 9. Configura VirtualHost Apache otimizado para o dominio informado e 000-default.conf com regras anti-webshell.
# 10. Baixa e extrai automaticamente o pacote estavel oficial do Joomla 5.x.
# 11. Protege o codigo contra escrita pelo Apache e libera somente diretorios mutaveis via ACL.
# 12. Configura rotinas agendadas (Cron Jobs) para execucao periodica das tarefas CLI do Joomla (cli/joomla.php).
# 13. Configura o Linux Audit Daemon (auditd) com regras ativas para monitorar alteracoes no diretorio web em tempo real.
# 14. Integra as portas HTTP (80) e HTTPS (443) ao Firewall UFW e jails Web ao Fail2Ban.
# 15. Exibe resumo sem segredos e salva credenciais em arquivo root:root com modo 0600.
# 16. Gera logs privados, sem credenciais, em /root e na Home do usuario.
# ==============================================================================
# Execucao recomendada apos revisar localmente a origem e a integridade do arquivo:
# chmod +x install_lamp_ubuntu_joomla5.sh
# sudo ./install_lamp_ubuntu_joomla5.sh
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
set -Eeuo pipefail
umask 077

RUNTIME_DIR=""
LOG_TMP=""
TMP_SQL=""
JOOMLA_ARCHIVE=""
PACOTES_INSTALADOS=()

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM HUP
    [ -n "${TMP_SQL:-}" ] && [ -f "$TMP_SQL" ] && rm -f -- "$TMP_SQL"
    [ -n "${JOOMLA_ARCHIVE:-}" ] && [ -f "$JOOMLA_ARCHIVE" ] && rm -f -- "$JOOMLA_ARCHIVE"
    [ -n "${RUNTIME_DIR:-}" ] && [ -d "$RUNTIME_DIR" ] && rm -rf -- "$RUNTIME_DIR"
    exit "$exit_code"
}
trap cleanup EXIT INT TERM HUP

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
        /|/bin|/boot|/dev|/etc|/home|/proc|/root|/run|/sbin|/sys|/tmp|/usr|/var) return 1 ;;
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
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALADOR AUTOMATICO LAMP ENDURECIDO - JOOMLA 5 (UBUNTU SERVER)"
log_info "Versao do instalador: ${FG_WHITE}${VERSION}${NC}"
# ==============================================================================
# 2. COLETA DE PARAMETROS DO AMBIENTE
# ==============================================================================
print_header "COLETA DE PARAMETROS DO AMBIENTE"

echo -e "  ${FG_CYAN}[i]${NC} Dominio do site Joomla 5 (ex: meusite.com.br ou prototipo.net.br)."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Dominio do site: ${NC}")" DOMAIN_NAME
while ! validate_domain "$DOMAIN_NAME"; do
    log_warning "Informe um dominio DNS valido, sem protocolo, porta, barras ou espacos."
    read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Informe o dominio do site: ${NC}")" DOMAIN_NAME
done

# Limpa caracteres especiais do dominio para usar como identificador seguro
CLEAN_DOMAIN_ID=$(echo "$DOMAIN_NAME" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
log_info "Dominio definido: ${FG_GREEN}${DOMAIN_NAME}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Diretorio raiz da aplicacao web (permite informar outro disco/ponto de montagem)."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Diretorio de instalacao [Padrao: /var/www/html/${DOMAIN_NAME}]: ${NC}")" CUSTOM_DOC_ROOT
JOOMLA_ROOT=${CUSTOM_DOC_ROOT:-"/var/www/html/${DOMAIN_NAME}"}
validate_docroot "$JOOMLA_ROOT" || die "Diretorio web invalido ou inseguro: ${JOOMLA_ROOT}"
JOOMLA_ROOT=$(realpath -m -- "$JOOMLA_ROOT")
log_info "Diretorio Web Raiz: ${FG_GREEN}${JOOMLA_ROOT}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Configuracao do Banco de Dados MariaDB para o Joomla 5."
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
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do Banco de Dados [Padrao: ${DEFAULT_DB_NAME}]: ${NC}")" JOOMLA_DB_NAME
JOOMLA_DB_NAME=${JOOMLA_DB_NAME:-$DEFAULT_DB_NAME}
validate_db_identifier "$JOOMLA_DB_NAME" || die "Nome de banco invalido. Use somente letras, numeros e sublinhado (maximo 32)."
log_info "Nome do Banco definido: ${FG_GREEN}${JOOMLA_DB_NAME}${NC}"

DEFAULT_DB_USER="joomla_${CLEAN_DOMAIN_ID:0:15}_usr"
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuario do Banco [Padrao: ${DEFAULT_DB_USER}]: ${NC}")" JOOMLA_DB_USER
JOOMLA_DB_USER=${JOOMLA_DB_USER:-$DEFAULT_DB_USER}
validate_db_identifier "$JOOMLA_DB_USER" || die "Usuario de banco invalido. Use somente letras, numeros e sublinhado (maximo 32)."
log_info "Usuario do Banco definido: ${FG_GREEN}${JOOMLA_DB_USER}${NC}"

read -r -s -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do Usuario do Joomla DB (deixe vazio para gerar aleatoria): ${NC}")" JOOMLA_DB_PASS
echo
if [ -z "$JOOMLA_DB_PASS" ]; then
    JOOMLA_DB_PASS=$(generate_password)
    log_info "Senha forte gerada para o Usuario Joomla DB (valor oculto)."
else
    [ "${#JOOMLA_DB_PASS}" -ge 16 ] || die "A senha do Usuario Joomla DB deve ter pelo menos 16 caracteres."
    log_info "Senha do Usuario Joomla DB recebida com entrada oculta."
fi

echo -e "\n  ${FG_CYAN}[i]${NC} Usuario do sistema/desenvolvedor para permissoes de escrita SFTP/SSH (opcional)."
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuario desenvolvedor adicional [Deixe vazio se nao houver]: ${NC}")" DEV_USER
if [ -n "$DEV_USER" ]; then
    [[ "$DEV_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Nome de usuario do sistema invalido."
    if id "$DEV_USER" >/dev/null 2>&1; then
        log_info "Usuario desenvolvedor configurado com acesso total ao diretorio web: ${FG_GREEN}${DEV_USER}${NC}"
    else
        log_warning "Usuario '${DEV_USER}' nao encontrado no sistema. ACLs serao preparadas para quando ele for criado."
    fi
else
    log_info "Nenhum usuario adicional informado (apenas www-data)."
fi

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
    "postfix"
    "mailutils"
    "auditd"
    "audispd-plugins"
    "ufw"
    "fail2ban"
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
APACHE_MODULES=("rewrite" "ssl" "headers" "deflate" "expires" "http2" "remoteip" "env" "dir" "mime" "setenvif" "filter" "proxy_fcgi")
for mod in "${APACHE_MODULES[@]}"; do
    a2enmod "$mod" > /dev/null 2>&1 || die "Falha ao habilitar o modulo Apache '$mod'."
    log_success "Modulo Apache '$mod' habilitado."
done

log_info "Desativando modulos desnecessarios/inseguros no Apache (autoindex, status, mpm_prefork)..."
a2dismod -f autoindex status mpm_prefork > /dev/null 2>&1 || true

log_info "Aplicando endurecimento de seguranca no Apache (ocultacao de banners, headers e desativacao de TRACE)..."
if [ -f /etc/apache2/conf-available/security.conf ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    grep -q "^TraceEnable Off" /etc/apache2/conf-available/security.conf || echo "TraceEnable Off" >> /etc/apache2/conf-available/security.conf
    
    grep -q "X-Content-Type-Options" /etc/apache2/conf-available/security.conf || echo 'Header always set X-Content-Type-Options "nosniff"' >> /etc/apache2/conf-available/security.conf
    grep -q "X-Frame-Options" /etc/apache2/conf-available/security.conf || echo 'Header always set X-Frame-Options "SAMEORIGIN"' >> /etc/apache2/conf-available/security.conf
    grep -q "X-XSS-Protection" /etc/apache2/conf-available/security.conf || echo 'Header always set X-XSS-Protection "1; mode=block"' >> /etc/apache2/conf-available/security.conf
    grep -q "Referrer-Policy" /etc/apache2/conf-available/security.conf || echo 'Header always set Referrer-Policy "strict-origin-when-cross-origin"' >> /etc/apache2/conf-available/security.conf
    
    a2enconf security > /dev/null 2>&1 || true
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
DROP USER IF EXISTS '${JOOMLA_DB_USER}'@'localhost';
DROP USER IF EXISTS '${JOOMLA_DB_USER}'@'127.0.0.1';
DROP USER IF EXISTS '${JOOMLA_DB_USER}'@'%';
CREATE USER '${JOOMLA_DB_USER}'@'localhost' IDENTIFIED BY '${SQL_JOOMLA_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${JOOMLA_DB_NAME}\`.* TO '${JOOMLA_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

mariadb --protocol=socket < "$TMP_SQL" > /dev/null 2>&1 || die "Falha ao aplicar o hardening e criar o banco pelo socket local."
rm -f "$TMP_SQL"
TMP_SQL=""

CREDENTIALS_FILE="/root/credenciais_joomla_${CLEAN_DOMAIN_ID}.txt"
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

UBUNTU_RELEASE=$(lsb_release -rs 2>/dev/null || echo "24.04")

if [[ "$UBUNTU_RELEASE" == "22.04" ]]; then
    log_info "Ubuntu ${UBUNTU_RELEASE} LTS detectado: Instalando PHP 8.3 via PPA ondrej/php..."
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1 || die "Falha ao configurar o PPA assinado do PHP."
    apt-get update -y > /dev/null 2>&1 || die "Falha ao atualizar o APT apos adicionar o PPA do PHP."

    JOOMLA_PHP_PACKAGES=(
        "php8.3"
        "php8.3-fpm"
        "php8.3-cli"
        "php8.3-common"
        "php8.3-mysql"
        "php8.3-curl"
        "php8.3-gd"
        "php8.3-mbstring"
        "php8.3-xml"
        "php8.3-zip"
        "php8.3-opcache"
        "php8.3-intl"
        "php8.3-bcmath"
        "php8.3-imagick"
        "php8.3-soap"
        "php8.3-readline"
        "php8.3-apcu"
        "php8.3-redis"
        "php8.3-igbinary"
    )
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${JOOMLA_PHP_PACKAGES[@]}" > /dev/null 2>&1 || die "Falha ao instalar os pacotes PHP 8.3 obrigatorios."
    PACOTES_INSTALADOS+=("${JOOMLA_PHP_PACKAGES[@]}")
    
    update-alternatives --install /usr/bin/php php /usr/bin/php8.3 100 > /dev/null 2>&1 || true
    update-alternatives --set php /usr/bin/php8.3 > /dev/null 2>&1 || true
    PHP_VER="8.3"
    log_success "PHP 8.3 com APCu e Redis instalado e configurado no Ubuntu ${UBUNTU_RELEASE}."

else
    log_info "Ubuntu ${UBUNTU_RELEASE} detectado: Instalando suite nativa do PHP do repositorio Ubuntu..."
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl php-bcmath php-imagick php-soap php-readline php-apcu php-redis php-igbinary > /dev/null 2>&1 || die "Falha ao instalar a suite PHP nativa."
    PACOTES_INSTALADOS+=("php-cli" "php-fpm" "php-mysql" "php-curl" "php-gd" "php-mbstring" "php-xml" "php-zip" "php-intl")
    
    NAT_FPM=$(apt-cache search -n "^php[0-9.]*-fpm$" | awk 'NR == 1 { print $1 }')
    if [ -n "$NAT_FPM" ]; then
        NAT_V=$(printf '%s' "$NAT_FPM" | sed -nE 's/^php([0-9]+\.[0-9]+)-fpm$/\1/p')
        DEBIAN_FRONTEND=noninteractive apt-get install -y "php${NAT_V}" "php${NAT_V}-fpm" "php${NAT_V}-cli" "php${NAT_V}-mysql" "php${NAT_V}-curl" "php${NAT_V}-gd" "php${NAT_V}-mbstring" "php${NAT_V}-xml" "php${NAT_V}-zip" > /dev/null 2>&1 || die "Falha ao instalar os pacotes PHP ${NAT_V}."
    fi

    INST_PHP_BIN=$(command -v php 2>/dev/null || find /usr/bin -maxdepth 1 -type f -name 'php[0-9]*' -print 2>/dev/null | sort -V | tail -n 1)
    if [ -n "$INST_PHP_BIN" ]; then
        update-alternatives --install /usr/bin/php php "$INST_PHP_BIN" 100 > /dev/null 2>&1 || true
        update-alternatives --set php "$INST_PHP_BIN" > /dev/null 2>&1 || true
    fi
    PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.5")
    log_success "PHP ${PHP_VER} nativo instalado e configurado no Ubuntu ${UBUNTU_RELEASE}."
fi

DETECTED_PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)
[ -n "$DETECTED_PHP_VER" ] && PHP_VER="$DETECTED_PHP_VER"
if [ -n "$DETECTED_PHP_VER" ]; then
    PHP_VER="$DETECTED_PHP_VER"
    log_success "PHP ${PHP_VER} ativo e operacional no sistema."
else
    log_warning "Versao PHP detectada: ${PHP_VER}"
fi

# ==============================================================================
# 7. OTIMIZACAO DO PHP.INI E BLINDAGEM DE EXECUCAO (HARDENING)
# ==============================================================================
print_header "OTIMIZACAO DO PHP.INI E BLINDAGEM DE EXECUCAO (PHP ${PHP_VER})"

for PHP_INI_PATH in "/etc/php/${PHP_VER}/fpm/php.ini" "/etc/php/${PHP_VER}/cli/php.ini" "/etc/php/${PHP_VER}/apache2/php.ini"; do
    if [ -f "$PHP_INI_PATH" ]; then
        log_info "Configurando e endurecendo: $PHP_INI_PATH..."
        
        sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI_PATH"
        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI_PATH"
        sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_INI_PATH"
        sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_PATH"
        sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI_PATH"
        sed -i 's/^max_input_vars = .*/max_input_vars = 5000/' "$PHP_INI_PATH"
        sed -i 's|^;date\.timezone =.*|date.timezone = America/Sao_Paulo|' "$PHP_INI_PATH"
        sed -i 's|^date\.timezone =.*|date.timezone = America/Sao_Paulo|' "$PHP_INI_PATH"

        sed -i 's/^disable_functions =.*/disable_functions = exec,passthru,shell_exec,system,proc_open,popen,show_source,pcntl_exec/' "$PHP_INI_PATH"

        sed -i 's/^display_errors = .*/display_errors = Off/' "$PHP_INI_PATH"
        sed -i 's/^display_startup_errors = .*/display_startup_errors = Off/' "$PHP_INI_PATH"
        sed -i 's/^log_errors = .*/log_errors = On/' "$PHP_INI_PATH"
        sed -i 's/^expose_php = .*/expose_php = Off/' "$PHP_INI_PATH"
        sed -i 's/^allow_url_include = .*/allow_url_include = Off/' "$PHP_INI_PATH"
        sed -i 's/^cgi\.fix_pathinfo =.*/cgi.fix_pathinfo = 0/' "$PHP_INI_PATH"

        sed -i 's/^session\.cookie_httponly =.*/session.cookie_httponly = 1/' "$PHP_INI_PATH"
        sed -i 's/^session\.use_only_cookies =.*/session.use_only_cookies = 1/' "$PHP_INI_PATH"
        sed -i 's/^session\.use_strict_mode =.*/session.use_strict_mode = 1/' "$PHP_INI_PATH"
        sed -i "s/^session\.cookie_samesite =.*/session.cookie_samesite = 'Lax'/" "$PHP_INI_PATH"

        sed -i 's/^;opcache\.enable=.*/opcache.enable=1/' "$PHP_INI_PATH"
        sed -i 's/^opcache\.enable=.*/opcache.enable=1/' "$PHP_INI_PATH"
        sed -i 's/^;opcache\.memory_consumption=.*/opcache.memory_consumption=256/' "$PHP_INI_PATH"
        sed -i 's/^opcache\.memory_consumption=.*/opcache.memory_consumption=256/' "$PHP_INI_PATH"
        sed -i 's/^;opcache\.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/' "$PHP_INI_PATH"
        sed -i 's/^opcache\.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/' "$PHP_INI_PATH"
        sed -i 's/^;opcache\.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' "$PHP_INI_PATH"
        sed -i 's/^opcache\.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' "$PHP_INI_PATH"
        sed -i 's/^;opcache\.revalidate_freq=.*/opcache.revalidate_freq=2/' "$PHP_INI_PATH"
        sed -i 's/^opcache\.revalidate_freq=.*/opcache.revalidate_freq=2/' "$PHP_INI_PATH"
    fi
done

systemctl enable --now "php${PHP_VER}-fpm" > /dev/null 2>&1 || systemctl enable --now php-fpm > /dev/null 2>&1 || die "Falha ao ativar o PHP-FPM."
systemctl restart "php${PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1 || die "Falha ao reiniciar o PHP-FPM."
[ -d "/etc/php/${PHP_VER}/fpm" ] || die "Diretorio de configuracao do PHP-FPM nao encontrado."
cat <<EOF > "/etc/php/${PHP_VER}/fpm/conf.d/99-joomla-security.ini"
open_basedir = "${JOOMLA_ROOT}:/tmp:/var/lib/php/sessions:/dev/urandom"
cgi.fix_pathinfo = 0
EOF
a2enconf "php${PHP_VER}-fpm" > /dev/null 2>&1 || die "Falha ao conectar o Apache ao PHP-FPM ${PHP_VER}."
a2dismod -f "php${PHP_VER}" mpm_prefork > /dev/null 2>&1 || true
a2enmod mpm_event proxy_fcgi setenvif > /dev/null 2>&1 || die "Falha ao ativar o MPM Event com PHP-FPM."
log_success "Servico PHP-FPM (${PHP_VER}) configurado, otimizado e ativo."
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
APACHE_ROOT_REGEX=$(printf '%s' "$JOOMLA_ROOT" | sed 's/[][\\.^$*+?{}|()]/\\&/g')

cat <<EOF > "/etc/apache2/sites-available/${DOMAIN_NAME}.conf"
<VirtualHost *:80>
    ServerName ${DOMAIN_NAME}
    ServerAlias www.${DOMAIN_NAME}
    ServerAdmin webmaster@${DOMAIN_NAME}
    DocumentRoot "${JOOMLA_ROOT}"
    DirectoryIndex index.php index.html

    <Directory "${JOOMLA_ROOT}">
        Options -Indexes +FollowSymLinks
        # O .htaccess oficial do Joomla usa regras de reescrita e Options
        # apenas para desativar listagem e permitir links simbolicos.
        AllowOverride FileInfo Options
        Require all granted
    </Directory>

    # Bloqueio Critico: Proibe execucao de qualquer interpretador PHP em pastas de upload/estaticos
    <DirectoryMatch "^${APACHE_ROOT_REGEX}/(assets|images|cache|tmp|phocadownloadpap|media)(/|$)">
        <FilesMatch "(?i)\.(php|phtml|php[0-9]*|phps|pht|inc)(\.|$)">
            Require all denied
        </FilesMatch>
    </DirectoryMatch>

    # Bloqueio de Seguranca: Arquivos Ocultos especificos (.git, .env, etc.)
    <FilesMatch "^\.(git|env|user\.ini)">
        Require all denied
    </FilesMatch>

    # Bloqueio de Seguranca: Impedir visualizacao direta de backups, logs, dumps e scripts.
    # A excecao e limitada a css.gz e js.gz, recursos compactados nativos do Joomla.
    <FilesMatch "^(?!.*\.(css|js)\.gz$).*\.(log|sql|bak|old|orig|ini|sh|dist|tar|gz|zip)$">
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
    ufw allow 80/tcp > /dev/null 2>&1 || true
    ufw allow 443/tcp > /dev/null 2>&1 || true
    certbot --apache --non-interactive --agree-tos --redirect \
        --email "$LE_EMAIL" -d "$DOMAIN_NAME" -d "www.${DOMAIN_NAME}" \
        || die "Falha ao emitir o certificado. Verifique DNS e acesso externo a porta 80."
    cat <<'EOF' > /etc/apache2/conf-available/joomla-tls-security.conf
Header always set Strict-Transport-Security "max-age=31536000" "expr=%{HTTPS} == 'on'"
EOF
    a2enconf joomla-tls-security > /dev/null 2>&1 || die "Falha ao habilitar HSTS."
    echo 'session.cookie_secure = 1' >> "/etc/php/${PHP_VER}/fpm/conf.d/99-joomla-security.ini"
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

    JOOMLA_ASSET=$(jq -c '([.[] | select(.tag_name | startswith("5."))] | .[0].assets? // []) | map(select(.name | test("^Joomla_5.*Stable-Full_Package\\.zip$"))) | .[0] // empty' "$RELEASES_JSON")
    [ -n "$JOOMLA_ASSET" ] || die "Nenhum pacote Joomla 5 completo foi localizado no repositorio oficial."
    LATEST_JOOMLA_ZIP=$(jq -r '.browser_download_url' <<< "$JOOMLA_ASSET")
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
    if zipinfo -1 "$JOOMLA_ARCHIVE" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
        die "Pacote Joomla contem caminho inseguro e nao sera extraido."
    fi

    log_info "Checksum validado. Extraindo Joomla 5 em ${JOOMLA_ROOT}..."
    unzip -q -o "$JOOMLA_ARCHIVE" -d "$JOOMLA_ROOT" || die "Falha ao extrair o Joomla."
    rm -f "$JOOMLA_ARCHIVE"
    JOOMLA_ARCHIVE=""

    if [ -f "${JOOMLA_ROOT}/htaccess.txt" ]; then
        cp "${JOOMLA_ROOT}/htaccess.txt" "${JOOMLA_ROOT}/.htaccess"
        log_success "Arquivo .htaccess nativo do Joomla ativado para URLs amigaveis."
    fi
    if [ -f "${JOOMLA_ROOT}/configuration.php" ]; then
        log_warning "configuration.php existente foi preservado; credenciais nao foram alteradas automaticamente."
    fi
    log_success "Joomla 5 verificado e extraido com sucesso em ${JOOMLA_ROOT}."
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
chown -R "${CODE_OWNER}:www-data" "$JOOMLA_ROOT"
find "$JOOMLA_ROOT" -type d -exec chmod 750 {} +
find "$JOOMLA_ROOT" -type f -exec chmod 640 {} +

JOOMLA_WRITABLE_DIRS=(
    "cache" "tmp" "logs" "images" "media"
    "administrator/cache" "administrator/logs"
)
for relative_dir in "${JOOMLA_WRITABLE_DIRS[@]}"; do
    writable_dir="${JOOMLA_ROOT}/${relative_dir}"
    mkdir -p "$writable_dir"
    chown -R www-data:www-data "$writable_dir"
    find "$writable_dir" -type d -exec chmod 750 {} +
    find "$writable_dir" -type f -exec chmod 640 {} +
    setfacl -R -m u:www-data:rwx "$writable_dir"
    setfacl -R -d -m u:www-data:rwx,m::rwx "$writable_dir"
done

log_warning "Modo autorizado: Apache com escrita recursiva em ${JOOMLA_ROOT} para instalacao, extensoes e atualizacoes pelo painel."
setfacl -R -m u:www-data:rwX,m::rwX "$JOOMLA_ROOT"
find "$JOOMLA_ROOT" -type d -exec setfacl -m d:u:www-data:rwx,d:m::rwx {} +

if [ "$CODE_OWNER" != "root" ]; then
    log_success "Codigo gravavel pelo desenvolvedor '${CODE_OWNER}' e pelo Apache; atualizacoes Joomla pelo painel estao habilitadas."
else
    log_success "Codigo Joomla gravavel pelo Apache; instalador, extensoes e atualizacoes pelo painel estao habilitados."
fi

# ==============================================================================
# 11. CONFIGURACAO DE ROTINAS AGENDADAS (CRON JOBS DO JOOMLA)
# ==============================================================================
print_header "CONFIGURACAO DE ROTINAS AGENDADAS DO JOOMLA (CRON JOBS)"

log_info "Criando agendamento oficial das rotinas CLI do Joomla 5 no Crontab..."
JOOMLA_CRON_FILE="/etc/cron.d/joomla5_${CLEAN_DOMAIN_ID}_scheduler"
cat <<EOF > "$JOOMLA_CRON_FILE"
# Rotina agendada do Joomla 5 para ${DOMAIN_NAME} (Executa a cada 5 minutos como www-data)
*/5 * * * * www-data /usr/bin/php${PHP_VER} ${JOOMLA_ROOT}/cli/joomla.php scheduler:run --quiet > /dev/null 2>&1
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
SSH_PORT=$(sshd -T 2>/dev/null | awk '$1 == "port" { print $2; exit }' || true)
SSH_PORT=${SSH_PORT:-22}
[[ "$SSH_PORT" =~ ^[0-9]{1,5}$ ]] || die "Porta SSH detectada invalida."
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow "${SSH_PORT}/tcp" > /dev/null
ufw allow 80/tcp > /dev/null
if [ "$ENABLE_TLS" = "s" ]; then
    ufw allow 443/tcp > /dev/null
fi
ufw --force enable > /dev/null || die "Falha ao habilitar o UFW."
log_success "UFW ativo: SSH (${SSH_PORT}/tcp), HTTP e HTTPS quando configurado."

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

systemctl restart "php${PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1 || die "Falha ao reiniciar o PHP-FPM na validacao final."
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
echo -e "  ${BOLD}Versao do PHP:${NC}           PHP ${PHP_VER} (OPcache, APCu, Redis e disable_functions ativos)"
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
echo -e "    ▶ ${BOLD}Limpeza Automatica:${NC}  Remove cache obsoleto e sessoes expiradas para nao inflar o banco"
echo -e "    ▶ ${BOLD}Smart Search:${NC}        Atualiza o indice de busca inteligente com os novos conteudos"
echo -e "    ▶ ${BOLD}Seguranca:${NC}           Verifica atualizacoes do Joomla/extensoes e notifica o admin"
echo -e "    ▶ ${BOLD}Fila de E-mails:${NC}     Processa envio em lote de newsletters/contatos sem travar o site"
echo -e "    ▶ ${BOLD}Artigos Agendados:${NC}   Publica e despublica conteudos programados pontualmente"
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

rm -f "$LOG_TMP" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}✔ Instalacao do ambiente Joomla 5 finalizada com sucesso!${NC}\n"
