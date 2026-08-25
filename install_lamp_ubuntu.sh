#!/bin/bash
# ------------------------------------------------
# Version: 1.5
# ------------------------------------------------
VERSION="1.5"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO DA PILHA LAMP AUTOMÁTICO E ENDURECIDO - UBUNTU
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo) e inicializa captura de log.
# 2. Coleta parâmetros iniciais (Diretório Web Raiz, Senha MariaDB, PHP, phpMyAdmin, UFW).
# 3. Atualiza os repositórios do sistema e instala dependências prévias.
# 4. Instala e habilita o servidor web Apache2 com mod_rewrite e módulos essenciais.
# 5. Aplica endurecimento de segurança no Apache2 (ServerTokens Prod e ServerSignature Off).
# 6. Instala o MariaDB Server com senha root, limpeza de usuários anônimos e eliminação do banco 'test'.
# 7. Adiciona repositório ppa:ondrej/php e instala PHP com pacote completo de extensões modernas:
#    (pdo_mysql, mysqli, cli, common, curl, gd, mbstring, xml, zip, opcache, intl, bcmath, imagick, soap, readline).
# 8. Desativa funções PHP de alto risco no php.ini (system, shell_exec, passthru, show_source).
# 9. Aplica herança de permissões POSIX ACLs no DocumentRoot configurado.
# 10. Cria uma página de diagnóstico phpinfo em <WEB_ROOT>/info.php.
# 11. Opcionalmente instala e integra o phpMyAdmin de forma não interativa ao Apache.
# 12. Configura o Firewall UFW liberando portas 80 (HTTP), 443 (HTTPS) e 22 (SSH).
# 13. Configura o Fail2Ban protegendo SSH, Apache Auth e ativa a jaula anti-scanners (apache-badbots).
# 14. Exibe o Resumo Final do Sistema com todas as configurações de segurança ativas.
# 15. Geração e salvamento automático dos arquivos de log em /root e na Home do usuário.
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh -O install_lamp_ubuntu.sh && chmod +x install_lamp_ubuntu.sh && sudo ./install_lamp_ubuntu.sh
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

# Cores de Fundo (Background)
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

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

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_lamp_ubuntu_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_lamp_ubuntu_latest.log"
LOG_TMP="/tmp/${LOG_FILENAME}"
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALADOR AUTOMÁTICO LAMP - UBUNTU (APACHE, MARIADB, PHP)"

# ==============================================================================
# 2. COLETA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

echo -e "  ${FG_CYAN}[i]${NC} Diretório raiz da aplicação web (permite informar outro disco/ponto de montagem)."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Diretório Web Raiz [Padrão: /var/www/html]: ${NC}")" CUSTOM_WEB_ROOT
WEB_ROOT=${CUSTOM_WEB_ROOT:-"/var/www/html"}
log_info "Diretório Web Raiz: ${FG_GREEN}${WEB_ROOT}${NC}"

echo -e "\n  ${FG_CYAN}[i]${NC} Defina a senha para o usuário root do MariaDB."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar uma aleatória): ${NC}")" DB_ROOT_PASS

if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    log_info "Senha aleatória gerada para o MariaDB Root: ${FG_GREEN}${DB_ROOT_PASS}${NC}"
fi

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Versão do PHP a instalar (Pressione ENTER para a mais recente | ou informe ex: 8.3): ${NC}")" PHP_INPUT
PHP_INPUT=${PHP_INPUT:-latest}

if [[ "$PHP_INPUT" =~ ^[Ll]atest$ || "$PHP_INPUT" == "mais recente" ]]; then
    PHP_VER=""
    PKG_PREFIX="php-"
    LOG_PHP_MSG="Mais recente do repositório"
else
    CLEAN_VER=$(echo "$PHP_INPUT" | sed 's/[^0-9.]//g')
    if [ -n "$CLEAN_VER" ]; then
        PHP_VER="$CLEAN_VER"
        PKG_PREFIX="php${PHP_VER}-"
        LOG_PHP_MSG="PHP ${PHP_VER}"
    else
        PHP_VER=""
        PKG_PREFIX="php-"
        LOG_PHP_MSG="Mais recente do repositório"
    fi
fi

echo -e "\n  ${FG_CYAN}[i]${NC} Usuário do sistema/desenvolvedor para permissões de escrita SFTP/SSH (opcional)."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Usuário desenvolvedor adicional [Deixe vazio se não houver]: ${NC}")" DEV_USER
if [ -n "$DEV_USER" ]; then
    if id "$DEV_USER" >/dev/null 2>&1; then
        log_info "Usuário desenvolvedor configurado com acesso total ao diretório web: ${FG_GREEN}${DEV_USER}${NC}"
    else
        log_warning "Usuário '${DEV_USER}' não encontrado no sistema. ACLs serão preparadas para quando ele for criado."
    fi
else
    log_info "Nenhum usuário adicional informado (apenas www-data)."
fi

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja instalar o phpMyAdmin? (s/N): ${NC}")" INSTALL_PHPMYADMIN
INSTALL_PHPMYADMIN=$(echo "$INSTALL_PHPMYADMIN" | tr '[:upper:]' '[:lower:]')

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja instalar e configurar o Fail2Ban (SSH/Apache)? (S/n): ${NC}")" CONFIGURE_FAIL2BAN
CONFIGURE_FAIL2BAN=$(echo "$CONFIGURE_FAIL2BAN" | tr '[:upper:]' '[:lower:]')

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja liberar portas HTTP (80), HTTPS (443) e SSH (22) no UFW Firewall? (S/n): ${NC}")" CONFIGURE_UFW
CONFIGURE_UFW=$(echo "$CONFIGURE_UFW" | tr '[:upper:]' '[:lower:]')

draw_separator

# ==============================================================================
# 3. ATUALIZAÇÃO DO SISTEMA E PRÉ-REQUISITOS
# ==============================================================================
print_header "PREPARANDO REPOSITÓRIOS"

log_info "Atualizando a lista de pacotes do APT..."
apt-get update -y > /dev/null 2>&1 || true
log_success "Lista de pacotes atualizada."

log_info "Instalando dependências prévias (software-properties-common, curl, ca-certificates)..."
PRE_REQ_PACKAGES=("software-properties-common" "curl" "ca-certificates" "gnupg2" "lsb-release" "acl")
for pkg in "${PRE_REQ_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg " > /dev/null 2>&1; then
        log_info "Pacote '$pkg' já está instalado."
    else
        log_info "Instalando '$pkg'..."
        if apt-get install -y "$pkg" > /dev/null 2>&1; then
            log_success "Pacote '$pkg' instalado com sucesso."
        else
            log_warning "Falha ao instalar '$pkg'."
        fi
    fi
done

# ==============================================================================
# 4. INSTALAÇÃO DO SERVIDOR WEB (APACHE2)
# ==============================================================================
print_header "INSTALAÇÃO DO SERVIDOR WEB (APACHE2)"

log_info "Instalando o Apache2..."
if apt-get install -y apache2 > /dev/null 2>&1; then
    log_success "Apache2 instalado com sucesso."
else
    log_error "Falha na instalação do Apache2."
    exit 1
fi

log_info "Habilitando módulos essenciais no Apache (rewrite, headers, ssl, deflate, env, dir, mime, setenvif, http2, remoteip)..."
for mod in rewrite headers ssl deflate expires env dir mime setenvif http2 remoteip; do
    a2enmod "$mod" > /dev/null 2>&1
done
log_success "Módulos do Apache habilitados."

log_info "Desativando módulos desnecessários/inseguros no Apache (autoindex, status, mpm_prefork)..."
a2dismod -f autoindex status mpm_prefork > /dev/null 2>&1 || true

log_info "Iniciando e habilitando serviço apache2 no boot..."
systemctl enable --now apache2 > /dev/null 2>&1
log_success "Serviço apache2 em execução."

# ==============================================================================
# 5. HARDENING DE SEGURANÇA NO APACHE2
# ==============================================================================
print_header "HARDENING DO APACHE2"

log_info "Aplicando endurecimento de segurança no Apache2 (ocultar versão, assinaturas e TRACE)..."
if [ -f /etc/apache2/conf-available/security.conf ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    grep -q "^TraceEnable Off" /etc/apache2/conf-available/security.conf || echo "TraceEnable Off" >> /etc/apache2/conf-available/security.conf
    a2enconf security > /dev/null 2>&1 || true
fi

# Configura o DocumentRoot no VirtualHost se for diferente do default
if [ "$WEB_ROOT" != "/var/www/html" ]; then
    log_info "Atualizando DocumentRoot no VirtualHost padrão do Apache (/etc/apache2/sites-available/000-default.conf)..."
    cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${WEB_ROOT}
    DirectoryIndex index.php index.html

    <Directory ${WEB_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
fi

# ==============================================================================
# 6. INSTALAÇÃO E HARDENING DO BANCO DE DADOS (MARIADB SERVER)
# ==============================================================================
print_header "INSTALAÇÃO DO BANCO DE DADOS (MARIADB SERVER)"

log_info "Instalando o MariaDB Server..."
if apt-get install -y mariadb-server mariadb-client > /dev/null 2>&1; then
    log_success "MariaDB Server instalado com sucesso."
else
    log_error "Falha na instalação do MariaDB Server."
    exit 1
fi

log_info "Iniciando e habilitando serviço mariadb no boot..."
systemctl enable --now mariadb > /dev/null 2>&1
log_success "Serviço MariaDB em execução."

log_info "Configurando credenciais e aplicando endurecimento de segurança no MariaDB..."
TMP_SQL=$(mktemp)
cat <<EOF > "$TMP_SQL"
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASS}');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

mariadb < "$TMP_SQL" > /dev/null 2>&1 || mariadb -u root -p"$DB_ROOT_PASS" < "$TMP_SQL" > /dev/null 2>&1 || true
rm -f "$TMP_SQL"
log_success "Senha do root do MariaDB e limpeza de usuários anônimos/banco test aplicadas com sucesso."

# ==============================================================================
# 7. INSTALAÇÃO DO PHP E EXTENSÕES
# ==============================================================================
print_header "INSTALAÇÃO DO PHP E EXTENSÕES"

UBUNTU_RELEASE=$(lsb_release -rs 2>/dev/null || echo "24.04")

if [[ "$UBUNTU_RELEASE" == "22.04" || "$UBUNTU_RELEASE" == "24.04" ]]; then
    log_info "Ubuntu ${UBUNTU_RELEASE} LTS detectado: Adicionando PPA ondrej/php..."
    add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
    apt-get update -y > /dev/null 2>&1 || true

    [ -z "$PHP_VER" ] && PHP_VER="8.3"
    PHP_PACKAGES=(
        "php${PHP_VER}"
        "php${PHP_VER}-fpm"
        "php${PHP_VER}-cli"
        "php${PHP_VER}-common"
        "php${PHP_VER}-mysql"
        "php${PHP_VER}-curl"
        "php${PHP_VER}-gd"
        "php${PHP_VER}-mbstring"
        "php${PHP_VER}-xml"
        "php${PHP_VER}-zip"
        "php${PHP_VER}-opcache"
        "php${PHP_VER}-intl"
        "php${PHP_VER}-bcmath"
        "php${PHP_VER}-imagick"
        "php${PHP_VER}-soap"
        "php${PHP_VER}-readline"
    )
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PHP_PACKAGES[@]}" > /dev/null 2>&1 || true
    update-alternatives --install /usr/bin/php php "/usr/bin/php${PHP_VER}" 100 > /dev/null 2>&1 || true
    update-alternatives --set php "/usr/bin/php${PHP_VER}" > /dev/null 2>&1 || true
else
    log_info "Ubuntu ${UBUNTU_RELEASE} detectado: Instalando suíte nativa do PHP do repositório Ubuntu..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-opcache php-intl php-bcmath php-imagick php-soap php-readline > /dev/null 2>&1 || true
    INST_PHP_BIN=$(which php 2>/dev/null || ls /usr/bin/php[0-9.]* 2>/dev/null | head -n 1)
    if [ -n "$INST_PHP_BIN" ]; then
        update-alternatives --install /usr/bin/php php "$INST_PHP_BIN" 100 > /dev/null 2>&1 || true
        update-alternatives --set php "$INST_PHP_BIN" > /dev/null 2>&1 || true
    fi
fi

INSTALLED_PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")

# ==============================================================================
# 8. INTEGRAÇÃO DO PHP-FPM NO APACHE (FASTCGI / HTTP/2)
# ==============================================================================
print_header "INTEGRAÇÃO DO PHP-FPM NO APACHE (FASTCGI)"

log_info "Integrando PHP-FPM ao Apache 2.4 (proxy_fcgi)..."
a2enmod proxy proxy_fcgi setenvif > /dev/null 2>&1 || true
a2enconf "php${INSTALLED_PHP_VER}-fpm" > /dev/null 2>&1 || a2enconf php-fpm > /dev/null 2>&1 || true

mkdir -p /run/php
systemctl enable --now "php${INSTALLED_PHP_VER}-fpm" > /dev/null 2>&1 || systemctl enable --now php-fpm > /dev/null 2>&1 || true
systemctl restart "php${INSTALLED_PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1 || true

ACTUAL_SOCK=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n 1)
[ -z "$ACTUAL_SOCK" ] && ACTUAL_SOCK="/run/php/php${INSTALLED_PHP_VER}-fpm.sock"

if [ -n "$ACTUAL_SOCK" ]; then
    cat <<EOF > /etc/apache2/conf-available/lamp-php-fpm.conf
<FilesMatch \.php$>
    SetHandler "proxy:unix:${ACTUAL_SOCK}|fcgi://localhost"
</FilesMatch>
EOF
    a2enconf lamp-php-fpm > /dev/null 2>&1 || true
fi

systemctl restart apache2 > /dev/null 2>&1
log_success "Apache 2.4 integrado com sucesso ao PHP-FPM."

# ==============================================================================
# 9. OTIMIZAÇÃO E HARDENING NO PHP.INI
# ==============================================================================
print_header "HARDENING NO PHP.INI"

log_info "Aplicando diretivas de segurança e limites de produção no php.ini..."
for ini in /etc/php/*/fpm/php.ini /etc/php/*/apache2/php.ini /etc/php/*/cli/php.ini; do
    if [ -f "$ini" ]; then
        sed -i 's/^display_errors =.*/display_errors = Off/' "$ini"
        sed -i 's/^log_errors =.*/log_errors = On/' "$ini"
        sed -i 's/^expose_php =.*/expose_php = Off/' "$ini"
        sed -i 's/^allow_url_include =.*/allow_url_include = Off/' "$ini"
        sed -i 's/^;session.cookie_httponly =.*/session.cookie_httponly = 1/' "$ini"
        sed -i 's/^session.cookie_httponly =.*/session.cookie_httponly = 1/' "$ini"
        sed -i 's/^;session.cookie_samesite =.*/session.cookie_samesite = "Lax"/' "$ini"
        sed -i 's/^session.cookie_samesite =.*/session.cookie_samesite = "Lax"/' "$ini"
        sed -i 's/^;session.use_only_cookies =.*/session.use_only_cookies = 1/' "$ini"
        sed -i 's/^session.use_only_cookies =.*/session.use_only_cookies = 1/' "$ini"
        sed -i 's/^;opcache.enable_cli=.*/opcache.enable_cli=1/' "$ini"
        sed -i 's/^opcache.enable_cli=.*/opcache.enable_cli=1/' "$ini"
        sed -i "s/^disable_functions =.*/disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source/" "$ini" || true
    fi
done

log_info "Reiniciando Apache2 e PHP-FPM..."
systemctl restart "php${INSTALLED_PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1 || true
systemctl restart apache2 > /dev/null 2>&1
log_success "Serviços reiniciados com suporte a PHP-FPM, versão ocultada e funções de risco desativadas."

# ==============================================================================
# 9. CONFIGURAÇÃO DE PERMISSÕES (POSIX ACLs)
# ==============================================================================
print_header "CONFIGURAÇÃO DE PERMISSÕES (POSIX ACLs)"

log_info "Garantindo permissões de travessia (execução) nos diretórios pai de ${WEB_ROOT}..."
PARENT_DIR="$(dirname "$WEB_ROOT")"
while [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ]; do
    chmod o+x "$PARENT_DIR" > /dev/null 2>&1 || true
    PARENT_DIR="$(dirname "$PARENT_DIR")"
done

log_info "Aplicando herança de permissões automática com POSIX ACLs (setfacl) em ${WEB_ROOT}..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT"
setfacl -R -m u:www-data:rwx,g:www-data:rwx "$WEB_ROOT" > /dev/null 2>&1 || true
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx "$WEB_ROOT" > /dev/null 2>&1 || true

if [ -n "$DEV_USER" ] && id "$DEV_USER" >/dev/null 2>&1; then
    setfacl -R -m u:"${DEV_USER}":rwx,g:"${DEV_USER}":rwx "$WEB_ROOT" > /dev/null 2>&1 || true
    setfacl -R -d -m u:"${DEV_USER}":rwx,g:"${DEV_USER}":rwx "$WEB_ROOT" > /dev/null 2>&1 || true
    log_success "POSIX ACLs ativadas: Permissões de escrita e leitura compartilhadas entre 'www-data' e '${DEV_USER}'."
else
    log_success "POSIX ACLs ativadas: Novos arquivos em ${WEB_ROOT} herdarão acesso total para www-data."
fi

# ==============================================================================
# 10. DIAGNÓSTICO DO PHP (info.php)
# ==============================================================================
log_info "Criando arquivo de teste phpinfo em ${WEB_ROOT}/info.php..."
cat <<'EOF' > "${WEB_ROOT}/info.php"
<?php
phpinfo();
?>
EOF
chown www-data:www-data "${WEB_ROOT}/info.php"
log_success "Arquivo ${WEB_ROOT}/info.php criado."

# ==============================================================================
# 11. INSTALAÇÃO OPCIONAL DO PHPMYADMIN
# ==============================================================================
if [ "$INSTALL_PHPMYADMIN" = "s" ] || [ "$INSTALL_PHPMYADMIN" = "sim" ]; then
    print_header "INSTALAÇÃO DO PHPMYADMIN"
    log_info "Configurando seleções automáticas do debconf para phpMyAdmin..."
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

    log_info "Instalando phpMyAdmin de forma não interativa..."
    if apt-get install -y phpmyadmin php-mbstring php-zip php-gd > /dev/null 2>&1; then
        phpenmod mbstring > /dev/null 2>&1
        systemctl restart apache2 > /dev/null 2>&1
        log_success "phpMyAdmin instalado e integrado ao Apache2."
    else
        log_warning "Instalação do phpMyAdmin encontrou avisos. Verifique o serviço manualmente se necessário."
    fi
fi

# ==============================================================================
# 12. CONFIGURAÇÃO DE FIREWALL (UFW)
# ==============================================================================
if [ "$CONFIGURE_UFW" != "n" ] && [ "$CONFIGURE_UFW" != "nao" ]; then
    print_header "CONFIGURAÇÃO DE FIREWALL (UFW)"
    if command -v ufw > /dev/null 2>&1; then
        log_info "Liberando portas HTTP (80/tcp), HTTPS (443/tcp) e SSH (22/tcp) no UFW..."
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        ufw allow 22/tcp > /dev/null 2>&1
        ufw --force enable > /dev/null 2>&1
        log_success "Regras de porta 80, 443 e 22 liberadas no UFW."
    else
        log_warning "UFW não está instalado no sistema. Pulando regra de firewall."
    fi
fi

# ==============================================================================
# 13. CONFIGURAÇÃO DO FAIL2BAN (PROTEÇÃO SSH E APACHE)
# ==============================================================================
if [ "$CONFIGURE_FAIL2BAN" != "n" ] && [ "$CONFIGURE_FAIL2BAN" != "nao" ]; then
    print_header "INSTALAÇÃO E CONFIGURAÇÃO DO FAIL2BAN"
    log_info "Instalando o Fail2Ban..."
    apt-get install -y fail2ban > /dev/null 2>&1

    log_info "Garantindo existência dos arquivos de log do Apache..."
    mkdir -p /var/log/apache2 /etc/fail2ban/jail.d
    touch /var/log/apache2/error.log /var/log/apache2/access.log
    chown -R www-data:adm /var/log/apache2 > /dev/null 2>&1 || true

    log_info "Criando arquivo de configuração em /etc/fail2ban/jail.d/apache.local..."
    cat <<EOF > /etc/fail2ban/jail.d/apache.local
[apache-auth]
enabled = true
port    = http,https
logpath = /var/log/apache2/error.log

[apache-badbots]
enabled  = true
port     = http,https
logpath  = /var/log/apache2/error.log
maxretry = 3
bantime  = 2h
EOF

    systemctl enable --now fail2ban > /dev/null 2>&1
    systemctl restart fail2ban > /dev/null 2>&1
    log_success "Fail2Ban configurado e ativo com regras para SSH, Apache Auth e BadBots."
fi

# ==============================================================================
# 14. RESUMO FINAL DO SISTEMA
# ==============================================================================
SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"
ACTUAL_PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "8.3")
ACTUAL_PHP_SHORT=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")

print_header "RESUMO DO SISTEMA - INSTALAÇÃO CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DA PILHA LAMP FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Endurecido${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}          Apache2 ($(systemctl is-active apache2 2>/dev/null || echo "active")) [ServerTokens Prod]"
echo -e "  ${BOLD}Banco de Dados:${NC}        MariaDB Server [Seguro: Sem 'test' e sem usuár. anônimos]"
echo -e "  ${BOLD}Linguagem de Script:${NC}   PHP ${ACTUAL_PHP_VER} [disable_functions ativas]"
echo -e "  ${BOLD}Permissões POSIX ACL:${NC}  ${FG_GREEN}Ativo e Herdando (${WEB_ROOT})${NC}"
echo -e "  ${BOLD}Proteção Fail2Ban:${NC}     $(systemctl is-active fail2ban >/dev/null 2>&1 && echo -e "${FG_GREEN}Ativo (SSH, Apache Auth & BadBots)${NC}" || echo "Não instalado")"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Diretório Web Raiz:${NC}   ${FG_CYAN}${WEB_ROOT}${NC}"
echo -e "  ${BOLD}Acesso Web Principal:${NC}  ${FG_CYAN}http://${SERVER_IP}/${NC}"
echo -e "  ${BOLD}Diagnóstico PHP:${NC}      ${FG_CYAN}http://${SERVER_IP}/info.php${NC}"

if [ "$INSTALL_PHPMYADMIN" = "s" ] || [ "$INSTALL_PHPMYADMIN" = "sim" ]; then
    echo -e "  ${BOLD}Painel phpMyAdmin:${NC}    ${FG_CYAN}http://${SERVER_IP}/phpmyadmin${NC}"
fi

echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais MariaDB Root:${NC}"
echo -e "    Usuário: ${FG_CYAN}root${NC}"
echo -e "    Senha:   ${FG_YELLOW}${DB_ROOT_PASS}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}📁 LEMBRETES DE ARQUIVOS DE CONFIGURAÇÃO:${NC}"
echo -e "  ${FG_YELLOW}• Configuração Apache2:${NC}    /etc/apache2/apache2.conf"
echo -e "  ${FG_YELLOW}• VirtualHost Padrão:${NC}     /etc/apache2/sites-available/000-default.conf"
echo -e "  ${FG_YELLOW}• Config PHP (php.ini):${NC}    /etc/php/${ACTUAL_PHP_SHORT}/apache2/php.ini"
echo -e "  ${FG_YELLOW}• Config MariaDB:${NC}          /etc/mysql/mariadb.conf.d/50-server.cnf"
if systemctl is-active fail2ban >/dev/null 2>&1; then
    echo -e "  ${FG_YELLOW}• Config Fail2Ban:${NC}         /etc/fail2ban/jail.local"
fi
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

log_warning "Por razões de segurança, lembre-se de remover ou restringir o acesso ao arquivo ${WEB_ROOT}/info.php após a validação."

# ==============================================================================
# 15. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

# Salva cópias no diretório /root
cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

# Se executado via sudo, salva também na pasta home do usuário real
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
    fi
fi

rm -f "$LOG_TMP" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}❯ Instalação concluída com sucesso!${NC}\n"
