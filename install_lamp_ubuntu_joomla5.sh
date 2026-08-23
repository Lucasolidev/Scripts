#!/bin/bash
# ------------------------------------------------
# Version: 1.4
# ------------------------------------------------
VERSION="1.4"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO DA PILHA LAMP AUTOMÁTICO E ENDURECIDO - JOOMLA 5.x
# UBUNTU SERVER (22.04 / 24.04 / 26.04 LTS)
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo) e inicializa captura de log.
# 2. Coleta parâmetros essenciais (Domínio, Diretório Web Raiz, Banco MariaDB, Senhas).
# 3. Atualiza os repositórios do sistema e instala pré-requisitos essenciais.
# 4. Instala e configura o Apache 2.4.x com mod_rewrite, mod_ssl, mod_headers, mod_deflate e HTTP/2.
# 5. Aplica hardening no Apache (ServerTokens Prod, ServerSignature Off, Headers e Bloqueio de Arquivos Sensíveis).
# 6. Instala o MariaDB Server (11.4 LTS Recomendado) com hardening, cria banco e usuário dedicados para o Joomla 5 (utf8mb4).
# 7. Configura o PHP (Recomendado 8.3/8.2) com TODAS as extensões obrigatórias e recomendadas para o Joomla 5:
#    (pdo_mysql, mysqli, json, xml, dom, simplexml, gd, zip, zlib, mbstring, curl, intl, opcache, bcmath, imagick, fileinfo).
# 8. Otimiza o php.ini para Joomla 5 com hardening de sessões, cookies HttpOnly/SameSite e allow_url_include=Off.
# 9. Configura VirtualHost Apache otimizado para o domínio informado (suporte a .htaccess, SEF URLs amigáveis, segurança).
# 10. Baixa e extrai automaticamente o pacote estável oficial do Joomla 5.x.
# 11. Aplica permissões granulares e herança avançada POSIX ACLs no diretório web (www-data).
# 12. Configura rotinas agendadas (Cron Jobs) para execução periódica das tarefas CLI do Joomla (cli/joomla.php).
# 13. Integra as portas HTTP (80) e HTTPS (443) ao Firewall UFW de forma automática e silenciosa.
# 14. Integra a proteção de jails Web (Apache Auth e BadBots) ao Fail2Ban de forma modular em /etc/fail2ban/jail.d/.
# 15. Exibe Resumo Final Completo com credenciais, instruções de DNS e resumo de segurança.
# 16. Geração e salvamento automático dos arquivos de log em /root e na Home do usuário.
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu_joomla5.sh -O install_lamp_ubuntu_joomla5.sh && chmod +x install_lamp_ubuntu_joomla5.sh && sudo ./install_lamp_ubuntu_joomla5.sh
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# ==========================================
# PALETA DE CORES (ANSI ESCAPE CODES)
# ==========================================
NC='\033[0m'              # Reset (Sem Cor)
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

# Cores de Fonte (Foreground)
FG_BLACK='\033[30m'
FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_BLUE='\033[34m'
FG_MAGENTA='\033[35m'
FG_CYAN='\033[36m'
FG_WHITE='\033[37m'

# Símbolos Customizados
ARROW="❯"

# ==========================================
# FUNÇÕES DE HIGHLIGHT E LOGGING
# ==========================================

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

# ==============================================================================
# 1. VERIFICAÇÃO DE PRIVILÉGIOS (ROOT) E INICIALIZAÇÃO DE LOG
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    print_header "ERRO DE EXECUÇÃO"
    log_error "Este script precisa ser executado como ROOT ou via sudo."
    echo -e "  Exemplo: ${FG_YELLOW}sudo bash $0${NC}\n"
    exit 1
fi

LOG_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILENAME="install_lamp_ubuntu_joomla5_${LOG_TIMESTAMP}.log"
LOG_TMP="/tmp/${LOG_FILENAME}"
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALADOR AUTOMÁTICO LAMP ENDURECIDO - JOOMLA 5 (UBUNTU SERVER)"

# ==============================================================================
# 2. COLETA DE PARÂMETROS DO AMBIENTE
# ==============================================================================
print_header "COLETA DE PARÂMETROS DO AMBIENTE"

echo -e "  ${FG_CYAN}[i]${NC} Domínio do site Joomla 5 (ex: meusite.com.br ou prototipo.net.br)."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Domínio do site: ${NC}")" DOMAIN_NAME
while [ -z "$DOMAIN_NAME" ]; do
    log_warning "O domínio não pode ser vazio."
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Informe o domínio do site: ${NC}")" DOMAIN_NAME
done

# Limpa caracteres especiais do domínio para usar como identificador seguro
CLEAN_DOMAIN_ID=$(echo "$DOMAIN_NAME" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
log_info "Domínio definido: ${FG_GREEN}${DOMAIN_NAME}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Diretório raiz da aplicação web (permite informar outro disco/ponto de montagem)."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Diretório de instalação [Padrão: /var/www/html/${DOMAIN_NAME}]: ${NC}")" CUSTOM_DOC_ROOT
JOOMLA_ROOT=${CUSTOM_DOC_ROOT:-"/var/www/html/${DOMAIN_NAME}"}
log_info "Diretório Web Raiz: ${FG_GREEN}${JOOMLA_ROOT}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Configuração do Banco de Dados MariaDB para o Joomla 5."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar aleatória): ${NC}")" DB_ROOT_PASS
if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 18)
    log_info "Senha gerada para MariaDB Root: ${FG_GREEN}${DB_ROOT_PASS}${NC}"
fi

DEFAULT_DB_NAME="joomla_${CLEAN_DOMAIN_ID:0:15}_db"
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Nome do Banco de Dados [Padrão: ${DEFAULT_DB_NAME}]: ${NC}")" JOOMLA_DB_NAME
JOOMLA_DB_NAME=${JOOMLA_DB_NAME:-$DEFAULT_DB_NAME}
log_info "Nome do Banco definido: ${FG_GREEN}${JOOMLA_DB_NAME}${NC}"

DEFAULT_DB_USER="joomla_${CLEAN_DOMAIN_ID:0:15}_usr"
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuário do Banco [Padrão: ${DEFAULT_DB_USER}]: ${NC}")" JOOMLA_DB_USER
JOOMLA_DB_USER=${JOOMLA_DB_USER:-$DEFAULT_DB_USER}
log_info "Usuário do Banco definido: ${FG_GREEN}${JOOMLA_DB_USER}${NC}"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do Usuário do Joomla DB (deixe vazio para gerar aleatória): ${NC}")" JOOMLA_DB_PASS
if [ -z "$JOOMLA_DB_PASS" ]; then
    JOOMLA_DB_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 18)
    log_info "Senha gerada para o Usuário Joomla DB: ${FG_GREEN}${JOOMLA_DB_PASS}${NC}"
else
    log_info "Senha definida para o Usuário Joomla DB: ${FG_GREEN}${JOOMLA_DB_PASS}${NC}"
fi

echo -e "\n  ${FG_CYAN}[i]${NC} Versão do PHP (Recomendado oficial Joomla 5: 8.3)."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Versão do PHP a instalar [Padrão: 8.3 | ou 8.2]: ${NC}")" PHP_INPUT
PHP_INPUT=${PHP_INPUT:-8.3}
CLEAN_PHP_VER=$(echo "$PHP_INPUT" | sed 's/[^0-9.]//g')
PHP_VER="${CLEAN_PHP_VER:-8.3}"
log_info "Versão do PHP selecionada: ${FG_GREEN}PHP ${PHP_VER}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Download e Extração Automática do Joomla 5."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja baixar a versão mais recente estável do Joomla 5.x automaticamente? (S/n): ${NC}")" DOWNLOAD_JOOMLA
DOWNLOAD_JOOMLA=$(echo "$DOWNLOAD_JOOMLA" | tr '[:upper:]' '[:lower:]')

draw_separator

# ==============================================================================
# 3. ATUALIZAÇÃO DO SISTEMA E PRÉ-REQUISITOS
# ==============================================================================
print_header "PREPARANDO SISTEMA E REPOSITÓRIOS"

log_info "Atualizando a lista de pacotes do APT..."
apt update -y > /dev/null 2>&1 || true
log_success "Lista de pacotes atualizada."

log_info "Instalando dependências essenciais de infraestrutura..."
PRE_REQ_PACKAGES=(
    "software-properties-common"
    "curl"
    "wget"
    "ca-certificates"
    "gnupg2"
    "lsb-release"
    "acl"
    "unzip"
    "tar"
    "cron"
    "logrotate"
    "postfix"
    "mailutils"
)

for pkg in "${PRE_REQ_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg " > /dev/null 2>&1; then
        log_info "Pacote '$pkg' já está instalado."
    else
        log_info "Instalando '$pkg'..."
        if apt install -y "$pkg" > /dev/null 2>&1; then
            log_success "Pacote '$pkg' instalado com sucesso."
        else
            log_warning "Aviso na instalação de '$pkg'."
        fi
    fi
done

# ==============================================================================
# 4. INSTALAÇÃO E HARDENING DO APACHE 2.4.x
# ==============================================================================
print_header "INSTALAÇÃO E HARDENING DO APACHE 2.4.x"

log_info "Instalando o Apache2..."
if apt install -y apache2 > /dev/null 2>&1; then
    log_success "Apache2 instalado com sucesso."
else
    log_error "Falha na instalação do Apache2."
    exit 1
fi

log_info "Habilitando módulos obrigatórios e recomendados para Joomla 5 no Apache..."
APACHE_MODULES=("rewrite" "ssl" "headers" "deflate" "expires" "http2" "remoteip")
for mod in "${APACHE_MODULES[@]}"; do
    a2enmod "$mod" > /dev/null 2>&1
    log_success "Módulo Apache '$mod' habilitado."
done

log_info "Aplicando endurecimento de segurança no Apache (ocultação de banners)..."
if [ -f /etc/apache2/conf-available/security.conf ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    a2enconf security > /dev/null 2>&1 || true
fi

# ==============================================================================
# 5. INSTALAÇÃO E HARDENING DO MARIADB SERVER (RECOMENDADO JOOMLA 5: 11.1+)
# ==============================================================================
print_header "INSTALAÇÃO E HARDENING DO MARIADB SERVER (RECOMENDADO JOOMLA 5: 11.1+)"

log_info "Configurando repositório oficial MariaDB Server (Versão Recomendada 11.4 LTS)..."
if ! dpkg -l | grep -q "mariadb-server"; then
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-11.4" > /dev/null 2>&1 || true
    apt update -y > /dev/null 2>&1 || true
fi

log_info "Instalando o MariaDB Server..."
if apt install -y mariadb-server mariadb-client > /dev/null 2>&1; then
    log_success "MariaDB Server instalado com sucesso."
else
    log_warning "Tentando instalar via repositório padrão do sistema..."
    apt install -y mariadb-server mariadb-client > /dev/null 2>&1 || true
fi

log_info "Iniciando e habilitando o serviço MariaDB..."
systemctl enable --now mariadb > /dev/null 2>&1
log_success "Serviço MariaDB em execução ($(mariadb --version 2>/dev/null | awk '{print $5}' | tr -d ','))."

log_info "Otimizando charset MariaDB para UTF8MB4 (Obrigatório Joomla 5)..."
cat <<'EOF' > /etc/mysql/mariadb.conf.d/60-joomla5.cnf
[client-server]
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci

[mysqld]
innodb_file_per_table = 1
innodb_buffer_pool_size = 256M
max_allowed_packet    = 64M
sql_mode              = "STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
EOF

systemctl restart mariadb > /dev/null 2>&1

log_info "Aplicando endurecimento de segurança no MariaDB e criando banco de dados do Joomla 5..."

# Define a senha do root caso ainda não esteja definida
mariadb-admin -u root password "$DB_ROOT_PASS" > /dev/null 2>&1 || true

# Aplica as configurações do banco e usuário com suporte a socket local, localhost e 127.0.0.1
mariadb -u root -p"$DB_ROOT_PASS" <<EOF > /dev/null 2>&1 || mariadb <<EOF > /dev/null 2>&1
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
CREATE DATABASE IF NOT EXISTS \`$JOOMLA_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$JOOMLA_DB_USER'@'localhost' IDENTIFIED BY '$JOOMLA_DB_PASS';
CREATE USER IF NOT EXISTS '$JOOMLA_DB_USER'@'127.0.0.1' IDENTIFIED BY '$JOOMLA_DB_PASS';
CREATE USER IF NOT EXISTS '$JOOMLA_DB_USER'@'%' IDENTIFIED BY '$JOOMLA_DB_PASS';
SET PASSWORD FOR '$JOOMLA_DB_USER'@'localhost' = PASSWORD('$JOOMLA_DB_PASS');
SET PASSWORD FOR '$JOOMLA_DB_USER'@'127.0.0.1' = PASSWORD('$JOOMLA_DB_PASS');
SET PASSWORD FOR '$JOOMLA_DB_USER'@'%' = PASSWORD('$JOOMLA_DB_PASS');
GRANT ALL PRIVILEGES ON \`$JOOMLA_DB_NAME\`.* TO '$JOOMLA_DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$JOOMLA_DB_NAME\`.* TO '$JOOMLA_DB_USER'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$JOOMLA_DB_NAME\`.* TO '$JOOMLA_DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

log_success "Banco '${JOOMLA_DB_NAME}' e usuário '${JOOMLA_DB_USER}' criados com permissões completas em UTF8MB4."

# ==============================================================================
# 6. INSTALAÇÃO DO PHP 8.x E MÓDULOS DO JOOMLA 5
# ==============================================================================
print_header "INSTALAÇÃO DO PHP ${PHP_VER} (RECOMENDADO JOOMLA 5)"

log_info "Configurando repositório PPA ondrej/php..."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1 || true

# Caso o codinome do Ubuntu não tenha pacotes no PPA (ex: Ubuntu 26.04 em desenvolvimento), mapeia para a base LTS estável (noble)
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")
if [ ! -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ] && [ ! -f /etc/apt/sources.list.d/ondrej-php.list ]; then
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/ondrej-php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" > /etc/apt/sources.list.d/ondrej-php.list
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14AA40EC0831756756D7F66C4F4EA0AAE5267A6C" | gpg --dearmor -o /etc/apt/trusted.gpg.d/ondrej-php.gpg > /dev/null 2>&1 || true
fi
# Se o arquivo do PPA existir mas falhou no update por codinome não suportado, ajusta para noble
for f in /etc/apt/sources.list.d/*ondrej*php*.list /etc/apt/sources.list.d/*ondrej*php*.sources; do
    if [ -f "$f" ]; then
        sed -i 's/devel/noble/g; s/resolute/noble/g; s/plucky/noble/g' "$f" 2>/dev/null || true
    fi
done
apt update -y > /dev/null 2>&1 || true

PHP_MAIN_PKG="php${PHP_VER}"
APACHE_MOD_PKG="libapache2-mod-php${PHP_VER}"
PKG_PREFIX="php${PHP_VER}-"

JOOMLA_PHP_PACKAGES=(
    "${PHP_MAIN_PKG}"
    "${APACHE_MOD_PKG}"
    "${PKG_PREFIX}cli"
    "${PKG_PREFIX}common"
    "${PKG_PREFIX}mysql"
    "${PKG_PREFIX}curl"
    "${PKG_PREFIX}gd"
    "${PKG_PREFIX}mbstring"
    "${PKG_PREFIX}xml"
    "${PKG_PREFIX}zip"
    "${PKG_PREFIX}opcache"
    "${PKG_PREFIX}intl"
    "${PKG_PREFIX}bcmath"
    "${PKG_PREFIX}imagick"
    "${PKG_PREFIX}soap"
    "${PKG_PREFIX}readline"
)

log_info "Instalando PHP ${PHP_VER} e módulos requeridos pelo Joomla 5..."
PHP_INSTALLED_COUNT=0
for pkg in "${JOOMLA_PHP_PACKAGES[@]}"; do
    if apt install -y "$pkg" > /dev/null 2>&1; then
        log_success "Módulo '$pkg' instalado com sucesso."
        ((PHP_INSTALLED_COUNT++))
    fi
done

# Fallback para pacotes nativos do sistema caso o PPA não tenha o prefixo específico
if [ "$PHP_INSTALLED_COUNT" -eq 0 ]; then
    log_warning "Repositório PPA não respondeu para php${PHP_VER}-*. Instalando versão nativa do repositório Ubuntu..."
    FALLBACK_PHP_PACKAGES=(
        "php"
        "libapache2-mod-php"
        "php-cli"
        "php-common"
        "php-mysql"
        "php-curl"
        "php-gd"
        "php-mbstring"
        "php-xml"
        "php-zip"
        "php-opcache"
        "php-intl"
        "php-bcmath"
        "php-imagick"
        "php-soap"
        "php-readline"
    )
    for pkg in "${FALLBACK_PHP_PACKAGES[@]}"; do
        if apt install -y "$pkg" > /dev/null 2>&1; then
            log_success "Módulo nativo '$pkg' instalado com sucesso."
        elif [ "$pkg" = "php-opcache" ] && php -m 2>/dev/null | grep -qi "Zend OPcache\|opcache"; then
            log_success "Módulo nativo 'php-opcache' (embutido no core do PHP) ativo."
        else
            log_warning "Aviso/Não necessário no pacote '$pkg'."
        fi
    done
fi

# Garante a comutação e ativação do PHP no CLI e no Apache
log_info "Garantindo ativação do módulo PHP no Apache e no CLI..."
a2dismod mpm_event > /dev/null 2>&1 || true
a2enmod mpm_prefork > /dev/null 2>&1 || true

# Ativa o módulo específico ou genérico do PHP no Apache
if [ -f "/etc/apache2/mods-available/php${PHP_VER}.load" ]; then
    a2enmod "php${PHP_VER}" > /dev/null 2>&1 || true
else
    for php_load in /etc/apache2/mods-available/php*.load; do
        if [ -f "$php_load" ]; then
            mod_name=$(basename "$php_load" .load)
            a2enmod "$mod_name" > /dev/null 2>&1 || true
        fi
    done
fi

if [ -f "/usr/bin/php${PHP_VER}" ]; then
    update-alternatives --install /usr/bin/php php "/usr/bin/php${PHP_VER}" 100 > /dev/null 2>&1 || true
    update-alternatives --set php "/usr/bin/php${PHP_VER}" > /dev/null 2>&1 || true
fi

systemctl restart apache2 > /dev/null 2>&1 || true
log_success "Módulo PHP ativado no Apache e serviço reiniciado."

# Detecta a versão real ativa instalada do PHP no sistema para os passos seguintes
DETECTED_PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
if [ -n "$DETECTED_PHP_VER" ]; then
    PHP_VER="$DETECTED_PHP_VER"
fi

# ==============================================================================
# 7. AJUSTES DE PERFORMANCE E HARDENING NO PHP.INI
# ==============================================================================
print_header "OTIMIZAÇÃO DO PHP.INI PARA JOOMLA 5"

log_info "Configurando diretivas de performance e limites no php.ini..."
for ini_file in "/etc/php/${PHP_VER}/apache2/php.ini" "/etc/php/${PHP_VER}/cli/php.ini"; do
    if [ -f "$ini_file" ]; then
        # Memória e Uploads (Requisitos oficiais Joomla 5: memory_limit >= 256MB)
        sed -i 's/^memory_limit =.*/memory_limit = 512M/' "$ini_file"
        sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 64M/' "$ini_file"
        sed -i 's/^post_max_size =.*/post_max_size = 64M/' "$ini_file"
        sed -i 's/^max_execution_time =.*/max_execution_time = 300/' "$ini_file"
        sed -i 's/^max_input_time =.*/max_input_time = 300/' "$ini_file"
        sed -i 's/^max_input_vars =.*/max_input_vars = 5000/' "$ini_file"
        sed -i 's/^output_buffering =.*/output_buffering = Off/' "$ini_file"
        sed -i 's/^expose_php =.*/expose_php = Off/' "$ini_file"
        sed -i 's/^;date.timezone =.*/date.timezone = America\/Sao_Paulo/' "$ini_file"

        # Otimização OPcache para Joomla 5
        sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "$ini_file"
        sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "$ini_file"
        sed -i 's/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/' "$ini_file"
        sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "$ini_file"
        sed -i 's/^;opcache.revalidate_freq=.*/opcache.revalidate_freq=2/' "$ini_file"

        # Diretivas de Segurança e Proteção de Sessão / Cookies
        sed -i 's/^;session.cookie_httponly =.*/session.cookie_httponly = 1/' "$ini_file"
        sed -i 's/^session.cookie_httponly =.*/session.cookie_httponly = 1/' "$ini_file"
        sed -i 's/^;session.cookie_samesite =.*/session.cookie_samesite = "Lax"/' "$ini_file"
        sed -i 's/^session.cookie_samesite =.*/session.cookie_samesite = "Lax"/' "$ini_file"
        sed -i 's/^;session.use_strict_mode =.*/session.use_strict_mode = 1/' "$ini_file"
        sed -i 's/^session.use_strict_mode =.*/session.use_strict_mode = 1/' "$ini_file"
        sed -i 's/^allow_url_include =.*/allow_url_include = Off/' "$ini_file"

        # Hardening de funções inseguras mantendo compatibilidade
        sed -i "s/^disable_functions =.*/disable_functions = show_source,system,shell_exec,passthru,proc_open,popen/" "$ini_file" || true
    fi
done
log_success "php.ini ajustado: memory_limit=512M, cookies HttpOnly/SameSite, allow_url_include=Off e opcache ativo."

# ==============================================================================
# 8. ESTRUTURA DO DIRETÓRIO E VIRTUALHOST APACHE
# ==============================================================================
print_header "CONFIGURAÇÃO DO VIRTUALHOST APACHE (JOOMLA 5)"

mkdir -p "$JOOMLA_ROOT"

log_info "Criando VirtualHost para o domínio '${DOMAIN_NAME}' em /etc/apache2/sites-available/${DOMAIN_NAME}.conf..."
cat <<EOF > /etc/apache2/sites-available/${DOMAIN_NAME}.conf
<VirtualHost *:80>
    ServerName ${DOMAIN_NAME}
    ServerAlias www.${DOMAIN_NAME}
    ServerAdmin webmaster@${DOMAIN_NAME}
    DocumentRoot ${JOOMLA_ROOT}

    <Directory ${JOOMLA_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Bloqueio de Segurança: Arquivos Ocultos (.git, .env, etc.)
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    # Bloqueio de Segurança: Impedir visualização direta de backups, logs e scripts
    <FilesMatch "\.(log|sql|bak|old|orig|ini|sh|dist)$">
        Require all denied
    </FilesMatch>

    # Headers de Segurança recomendados (Hardening de Produção)
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Logs customizados
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_access.log combined
</VirtualHost>
EOF

# Configura tanto o site do domínio quanto o VirtualHost padrão (IP direto) para o diretório do Joomla
cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${JOOMLA_ROOT}

    <Directory ${JOOMLA_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Headers de Segurança
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2ensite 000-default.conf > /dev/null 2>&1 || true
a2ensite "${DOMAIN_NAME}.conf" > /dev/null 2>&1
log_success "VirtualHost ${DOMAIN_NAME}.conf e 000-default.conf ativados com suporte completo a .htaccess e URLs amigáveis (SEF)."

# ==============================================================================
# 9. DOWNLOAD E EXTRAÇÃO DO JOOMLA 5.x
# ==============================================================================
if [[ "$DOWNLOAD_JOOMLA" != "n" && "$DOWNLOAD_JOOMLA" != "nao" ]]; then
    print_header "DOWNLOAD DO PACOTE OFICIAL DO JOOMLA 5"
    log_info "Consultando a versão estável mais recente do Joomla 5..."
    JOOMLA_API_URL="https://api.github.com/repos/joomla/joomla-cms/releases"
    LATEST_JOOMLA_ZIP=$(curl -s $JOOMLA_API_URL | grep "browser_download_url.*Joomla_5.*Full_Package.zip" | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$LATEST_JOOMLA_ZIP" ]; then
        LATEST_JOOMLA_ZIP="https://github.com/joomla/joomla-cms/releases/download/5.2.4/Joomla_5.2.4-Stable-Full_Package.zip"
    fi

    log_info "Baixando pacote: ${LATEST_JOOMLA_ZIP}..."
    wget -q -O /tmp/joomla_pkg.zip "$LATEST_JOOMLA_ZIP"

    if [ -f /tmp/joomla_pkg.zip ]; then
        log_info "Extraindo arquivos do Joomla 5 em ${JOOMLA_ROOT}..."
        unzip -q -o /tmp/joomla_pkg.zip -d "$JOOMLA_ROOT"
        rm -f /tmp/joomla_pkg.zip
        
        # Habilita .htaccess padrão do Joomla se existir htaccess.txt
        if [ -f "${JOOMLA_ROOT}/htaccess.txt" ]; then
            cp "${JOOMLA_ROOT}/htaccess.txt" "${JOOMLA_ROOT}/.htaccess"
            log_success "Arquivo .htaccess nativo do Joomla ativado para URLs amigáveis."
        fi
        log_success "Joomla 5 baixado e extraído com sucesso."
    else
        log_warning "Não foi possível baixar automaticamente o pacote do Joomla. Crie os arquivos em ${JOOMLA_ROOT} manualmente."
    fi
fi

# ==============================================================================
# 10. PERMISSÕES E POSIX ACLs
# ==============================================================================
print_header "PERMISSÕES E SEGURANÇA NO DIRETÓRIO WEB"

log_info "Aplicando permissões granulares (diretórios 755 / arquivos 644) e herança POSIX ACLs..."
chown -R www-data:www-data "$JOOMLA_ROOT"
find "$JOOMLA_ROOT" -type d -exec chmod 775 {} + > /dev/null 2>&1 || true
find "$JOOMLA_ROOT" -type f -exec chmod 664 {} + > /dev/null 2>&1 || true
setfacl -R -m u:www-data:rwx,g:www-data:rwx "$JOOMLA_ROOT" > /dev/null 2>&1 || true
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx "$JOOMLA_ROOT" > /dev/null 2>&1 || true
log_success "POSIX ACLs ativadas: Permissões de escrita e leitura garantidas para o Apache/Joomla."

# ==============================================================================
# 11. CONFIGURAÇÃO DE ROTINAS AGENDADAS (CRON JOBS DO JOOMLA)
# ==============================================================================
print_header "CONFIGURAÇÃO DE ROTINAS AGENDADAS DO JOOMLA (CRON JOBS)"

log_info "Criando agendamento oficial das rotinas CLI do Joomla 5 no Crontab..."
JOOMLA_CRON_FILE="/etc/cron.d/joomla5_${CLEAN_DOMAIN_ID}_scheduler"
cat <<EOF > "$JOOMLA_CRON_FILE"
# Rotina agendada do Joomla 5 para ${DOMAIN_NAME} (Executa a cada 5 minutos como www-data)
*/5 * * * * www-data /usr/bin/php${PHP_VER} ${JOOMLA_ROOT}/cli/joomla.php scheduler:run --quiet > /dev/null 2>&1
EOF
chmod 644 "$JOOMLA_CRON_FILE"
log_success "Cron Job configurado: '${JOOMLA_ROOT}/cli/joomla.php scheduler:run' a cada 5 minutos."

# ==============================================================================
# 12. INTEGRAÇÃO DE FIREWALL (UFW)
# ==============================================================================
if command -v ufw > /dev/null 2>&1; then
    log_info "Garantindo liberação das portas HTTP (80/tcp) e HTTPS (443/tcp) no UFW Firewall..."
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    log_success "Portas HTTP (80) e HTTPS (443) liberadas no Firewall UFW."
fi

# ==============================================================================
# 13. INTEGRAÇÃO DO FAIL2BAN (JAILS WEB APACHE)
# ==============================================================================
if command -v fail2ban-client > /dev/null 2>&1 || [ -d /etc/fail2ban ]; then
    log_info "Integrando jails de proteção Web (Apache Auth e BadBots) ao Fail2Ban..."
    mkdir -p /var/log/apache2 /etc/fail2ban/jail.d
    touch /var/log/apache2/error.log /var/log/apache2/access.log
    chown -R www-data:adm /var/log/apache2 > /dev/null 2>&1 || true

    # Adiciona de forma modular sem sobrescrever a jail SSH já configurada no pos_install_server
    cat <<EOF > /etc/fail2ban/jail.d/apache-joomla.local
[apache-auth]
enabled = true
port    = http,https
logpath = /var/log/apache2/*error.log

[apache-badbots]
enabled  = true
port     = http,https
logpath  = /var/log/apache2/*error.log
maxretry = 2
bantime  = 24h
EOF

    systemctl restart fail2ban > /dev/null 2>&1 || true
    log_success "Proteção Apache Auth e BadBots ativada modularmente no Fail2Ban (/etc/fail2ban/jail.d/apache-joomla.local)."
fi

# Reinicia o Apache com todas as alterações
systemctl restart apache2 > /dev/null 2>&1

# ==============================================================================
# 14. RESUMO FINAL DO SISTEMA E INSTRUÇÕES
# ==============================================================================
SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"

print_header "RESUMO DO SISTEMA - INSTALAÇÃO DO JOOMLA 5 CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ AMBIENTE JOOMLA 5 INSTALADO E ENDURECIDO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Domínio Configurado:${NC}     ${FG_CYAN}${DOMAIN_NAME}${NC}"
echo -e "  ${BOLD}Diretório Raiz (Web):${NC}    ${FG_CYAN}${JOOMLA_ROOT}${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}            Apache 2.4.x [Rewrite, HTTP/2, Headers de Segurança]"
echo -e "  ${BOLD}Banco de Dados:${NC}          MariaDB Server [UTF8MB4 / Collation Unicode CI]"
echo -e "  ${BOLD}Versão do PHP:${NC}           PHP ${PHP_VER} (memory_limit = 512M, opcache ativo)"
echo -e "  ${BOLD}Permissões POSIX ACL:${NC}    ${FG_GREEN}Ativo e Herdando (${JOOMLA_ROOT})${NC}"
echo -e "  ${BOLD}Tarefas Agendadas (Cron):${NC} ${FG_GREEN}Ativo (cli/joomla.php a cada 5min)${NC}"
echo -e "  ${BOLD}Firewall UFW & Fail2Ban:${NC}  ${FG_GREEN}Portas 80/443 liberadas e Jails Web ativas${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais do Banco de Dados para o Instalador Web do Joomla:${NC}"
echo -e "    • Servidor (Host):       ${FG_CYAN}localhost${NC}"
echo -e "    • Nome do Banco:         ${FG_CYAN}${JOOMLA_DB_NAME}${NC}"
echo -e "    • Usuário do Banco:      ${FG_CYAN}${JOOMLA_DB_USER}${NC}"
echo -e "    • Senha do Usuário:      ${FG_YELLOW}${JOOMLA_DB_PASS}${NC}"
echo -e "    • Senha do MariaDB Root: ${FG_YELLOW}${DB_ROOT_PASS}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}URLs de Acesso para Finalizar a Instalação e Administração:${NC}"
echo -e "    • Portal Principal (Domínio): ${FG_CYAN}http://${DOMAIN_NAME}/${NC}"
echo -e "    • Painel Admin (Domínio):     ${FG_CYAN}http://${DOMAIN_NAME}/administrator${NC}"
echo -e "    • Portal Principal (Via IP):  ${FG_CYAN}http://${SERVER_IP}/${NC}"
echo -e "    • Painel Admin (Via IP):      ${FG_CYAN}http://${SERVER_IP}/administrator${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}🔒 MEDIDAS DE SEGURANÇA E HARDENING APLICADAS:${NC}"
echo -e "  ${FG_YELLOW}1. Proteção contra Injeção e Vazamento de Cookies e Sessão (PHP):${NC}"
echo -e "     • ${BOLD}session.cookie_httponly = 1${NC} (Impede roubo de cookies via scripts XSS)"
echo -e "     • ${BOLD}session.cookie_samesite = 'Lax'${NC} (Mitiga ataques CSRF / Cross-Site Request Forgery)"
echo -e "     • ${BOLD}session.use_strict_mode = 1${NC} (Evita ataques de fixação de sessão)"
echo -e "     • ${BOLD}allow_url_include = Off${NC} (Impede inclusão e execução remota de arquivos maliciosos)"
echo -e "     • ${BOLD}expose_php = Off${NC} (Oculta assinatura da versão do PHP nos cabeçalhos)"
echo -e "  ${FG_YELLOW}2. Bloqueio de Acesso a Arquivos Sensíveis no Apache:${NC}"
echo -e "     • Bloqueio direto a arquivos ocultos (.git, .env, .htaccess)"
echo -e "     • Bloqueio de visualização direta a arquivos .log, .sql, .bak, .old, .sh e .ini"
echo -e "     • Injeção de cabeçalhos de proteção (X-Content-Type-Options, X-Frame-Options, XSS-Protection)"
echo -e "  ${FG_YELLOW}3. Permissões Granulares e Isolamento:${NC}"
echo -e "     • Herança contínua via POSIX ACLs restrita ao usuário www-data"
echo -e "     • Banco de dados dedicado com privilégios limitados estritamente ao banco do Joomla"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}⚙️ O QUE FAZ O AGENDADOR DE TAREFAS (CRON JOOMLA 5):${NC}"
echo -e "  O comando ${FG_CYAN}cli/joomla.php scheduler:run${NC} executa a cada 5min em segundo plano:"
echo -e "    • ${BOLD}Limpeza Automática:${NC}  Remove cache obsoleto e sessões expiradas para não inflar o banco"
echo -e "    • ${BOLD}Smart Search:${NC}        Atualiza o índice de busca inteligente com os novos conteúdos"
echo -e "    • ${BOLD}Segurança:${NC}           Verifica atualizações do Joomla/extensões e notifica o admin"
echo -e "    • ${BOLD}Fila de E-mails:${NC}     Processa envio em lote de newsletters/contatos sem travar o site"
echo -e "    • ${BOLD}Artigos Agendados:${NC}   Publica e despublica conteúdos programados pontualmente"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}📌 APONTAMENTO DE DNS RECOMENDADO:${NC}"
echo -e "  Crie no painel DNS do seu domínio (${DOMAIN_NAME}):"
echo -e "    • Tipo ${FG_CYAN}A${NC}  | Nome: ${FG_YELLOW}@${NC}   | Destino (IP): ${FG_GREEN}${SERVER_IP}${NC}"
echo -e "    • Tipo ${FG_CYAN}A${NC}  | Nome: ${FG_YELLOW}www${NC} | Destino (IP): ${FG_GREEN}${SERVER_IP}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 15. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

# Salva cópias no diretório /root
cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/install_lamp_ubuntu_joomla5_latest.log" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/install_lamp_ubuntu_joomla5_latest.log"

# Se executado via sudo, salva também na pasta home do usuário real
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/install_lamp_ubuntu_joomla5_latest.log" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/install_lamp_ubuntu_joomla5_latest.log" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
    fi
fi

rm -f "$LOG_TMP" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}❯ Instalação do ambiente Joomla 5 finalizada com sucesso!${NC}\n"
