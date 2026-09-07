#!/bin/bash
# ------------------------------------------------
# Version: 2.3
# ------------------------------------------------
VERSION="2.3"
# ==============================================================================
# INSTALADOR AUTOMATICO DA PILHA LEMP - UBUNTU
# ==============================================================================
# RESUMO DO SCRIPT:
# - Instala Nginx, MariaDB e PHP-FPM com pool dedicado por site.
# - Aplica menor privilegio: www-data escreve somente nas pastas declaradas.
# - Configura UFW, Fail2Ban (SSH e protecao web), HTTPS opcional e logs privados.
# - Bloqueia scripts em uploads e arquivos sensiveis no Nginx.
# - Exige servidor dedicado e DocumentRoot vazio para evitar mistura de arquivos.
#
# COMPATIBILIDADE: Ubuntu 22.04 (PHP 8.3 via PPA), 24.04 (PHP 8.3 nativo)
# e 26.04 (PHP 8.5 nativo). Requer root/sudo e usuario de deploy existente.
#
# EXECUCAO REMOTA (revise a origem antes de executar):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/Scripts/install_lemp_ubuntu.sh -O install_lemp_ubuntu.sh && chmod +x install_lemp_ubuntu.sh && sudo ./install_lemp_ubuntu.sh
# ==============================================================================
set -Eeuo pipefail
umask 077
STACK="lemp"
NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
FG_CYAN='\033[36m'; FG_YELLOW='\033[33m'; FG_GREEN='\033[32m'; FG_RED='\033[31m'
ARROW="❯"
draw_separator() { printf '%b\n' "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"; }
print_header() { printf '\n%b\n' "${FG_CYAN}${BOLD}${ARROW} $1${NC}"; draw_separator; }
log_info() { printf '%b\n' "${FG_CYAN}[i]${NC} $1"; }
log_success() { printf '%b\n' "${FG_GREEN}[+]${NC} $1"; }
log_warning() { printf '%b\n' "${FG_YELLOW}[!]${NC} $1"; }
die() { printf '%b\n' "${FG_RED}[x]${NC} $1" >&2; exit 1; }
install_packages() {
    local pkg
    for pkg in "$@"; do
        apt-get install -y "$pkg" > /dev/null 2>&1 || die "Falha ao instalar $pkg."
        PACOTES_INSTALADOS+=("$pkg")
        log_success "Instalado: $pkg"
    done
}
validate_root() {
    [[ "$1" =~ ^/[A-Za-z0-9_./-]+$ ]] || return 1
    case "$1" in /var/www/*|/srv/www/*|/mnt/*/*|/arquivos/*/*) return 0 ;; *) return 1 ;; esac
}
sql_escape() { local v="$1"; v=${v//\\/\\\\}; v=${v//\'/\'\'}; printf '%s' "$v"; }

# 1. PRIVILEGIOS E LOGS PRIVADOS
[[ $(id -u) == 0 ]] || die "Execute como root ou via sudo."
export DEBIAN_FRONTEND=noninteractive
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_${STACK}_ubuntu_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_${STACK}_ubuntu_latest.log"
RUNTIME_DIR=$(mktemp -d -p /tmp "install_${STACK}.XXXXXXXX")
LOG_TMP="$RUNTIME_DIR/$LOG_FILENAME"
touch "$LOG_TMP"
finish() {
    local result=$? real_home
    trap - EXIT
    exec 1>&3 2>&4
    wait "$TEE_PID" || :
    install -m 600 "$LOG_TMP" "/root/$LOG_FILENAME" || :
    install -m 600 "$LOG_TMP" "/root/$LOG_LATEST" || :
    if [[ -n ${SUDO_USER:-} && ${SUDO_USER:-} != root ]]; then
        real_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -d "$real_home" ]]; then
            install -m 600 -o "$SUDO_USER" "$LOG_TMP" "$real_home/$LOG_FILENAME" || :
            install -m 600 -o "$SUDO_USER" "$LOG_TMP" "$real_home/$LOG_LATEST" || :
        fi
    fi
    rm -rf -- "$RUNTIME_DIR"
    exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
trap 'die "Falha na linha $LINENO; instalacao incompleta. Consulte o relatorio."' ERR
exec 3>&1 4>&2
exec > >(tee -a "$LOG_TMP") 2>&1
TEE_PID=$!
PACOTES_INSTALADOS=()

# 2. COLETA E VALIDACAO ANTES DA INSTALACAO
print_header "INSTALADOR ${STACK^^} $VERSION — PARAMETROS"
OS_ID=$(awk -F= '$1=="ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
OS_VERSION=$(awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2}' /etc/os-release)
[[ "$OS_ID" == ubuntu ]] || die "Este instalador exige Ubuntu."
case "$OS_VERSION" in 22.04|24.04) PHP_VER=8.3 ;; 26.04) PHP_VER=8.5 ;; *) die "Ubuntu nao suportado." ;; esac
echo "Informe o dominio sem http://, https://, porta ou caminho; exemplo: site.exemplo.com."
read -r -p "Dominio DNS do site: " DOMAIN_NAME
[[ "$DOMAIN_NAME" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] || die "Dominio invalido."
echo "Informe a pasta onde o site sera instalado. Ela deve estar vazia e em uma raiz permitida."
read -r -p "Diretorio web [/var/www/$DOMAIN_NAME]: " WEB_ROOT
WEB_ROOT=${WEB_ROOT:-/var/www/$DOMAIN_NAME}
validate_root "$WEB_ROOT" || die "Use diretorio dedicado em /var/www, /srv/www, /mnt ou /arquivos."
WEB_ROOT=$(realpath -m -- "$WEB_ROOT")
validate_root "$WEB_ROOT" || die "Destino resolvido fora das raizes permitidas."
if [[ -d "$WEB_ROOT" && -n $(find "$WEB_ROOT" -mindepth 1 -print -quit) ]]; then
    die "Destino nao vazio. Instalador para site novo; migre arquivos revisados depois."
fi
echo "Esse usuario sera dono do codigo para manutencao; sera criado se nao existir e nao recebera senha inicial."
read -r -p "Usuario de deploy [root; sera criado se nao existir]: " CODE_OWNER
CODE_OWNER=${CODE_OWNER:-root}
[[ "$CODE_OWNER" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$CODE_OWNER" != www-data ]] || die "Usuario invalido."
if ! id "$CODE_OWNER" >/dev/null 2>&1; then
    [[ "$CODE_OWNER" != root ]] || die "A conta root deve existir."
    useradd --create-home --shell /bin/bash --user-group "$CODE_OWNER" || die "Falha ao criar usuario de deploy."
    passwd --lock "$CODE_OWNER" > /dev/null 2>&1 || die "Falha ao bloquear senha inicial do usuario."
    log_success "Usuario de deploy '$CODE_OWNER' criado; senha bloqueada. Configure acesso SSH depois."
else
    log_info "Usuario de deploy '$CODE_OWNER' ja existe."
fi
echo "Informe somente pastas que precisam receber uploads/cache/temporarios. Elas nao poderao executar PHP por HTTP."
read -r -p "Pastas gravaveis separadas por espaco [uploads cache tmp]: " WRITABLE_INPUT
read -r -a WRITABLE_DIRS <<< "${WRITABLE_INPUT:-uploads cache tmp}"
WRITABLE_REGEX=""
for relative in "${WRITABLE_DIRS[@]}"; do
    [[ "$relative" =~ ^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$ ]] || die "Pasta gravavel invalida."
    case "$relative" in plugins|plugins/*|components|components/*|libraries|libraries/*|templates|templates/*|administrator|cli|api) die "Nao conceda escrita a diretorios de codigo." ;; esac
    WRITABLE_REGEX+="${WRITABLE_REGEX:+|}$relative"
done
echo "Use modulos opcionais apenas se sua aplicacao exigir: soap, imagick, bcmath, apcu, redis ou igbinary."
read -r -p "PHP opcionais [nenhum]: " EXTRA_INPUT
read -r -a EXTRA_MODULES <<< "$EXTRA_INPUT"
for module in "${EXTRA_MODULES[@]}"; do
    case "$module" in soap|imagick|bcmath|apcu|redis|igbinary) ;; *) die "Modulo opcional invalido." ;; esac
done
echo "Limite por arquivo enviado pelo site; escolha conforme suas midias e politica de armazenamento."
read -r -p "Upload maximo em MB [64]: " UPLOAD_MB
UPLOAD_MB=${UPLOAD_MB:-64}
[[ "$UPLOAD_MB" =~ ^[1-9][0-9]{0,3}$ ]] || die "Upload deve ser de 1 a 9999 MB."
echo "Tempo maximo de uma requisicao PHP; valores muito altos facilitam consumo de recursos."
read -r -p "Tempo maximo PHP em segundos [300]: " EXEC_TIME
EXEC_TIME=${EXEC_TIME:-300}
[[ "$EXEC_TIME" =~ ^[1-9][0-9]{0,3}$ ]] || die "Timeout invalido."
echo "Ativa certificado e redirecionamento HTTPS direto neste servidor; exige DNS apontado e portas 80/443 acessiveis."
read -r -p "Configurar HTTPS com Let's Encrypt? (s/N): " ENABLE_TLS
LE_EMAIL=""
if [[ "${ENABLE_TLS,,}" == s ]]; then
    read -r -p "Email para certificado: " LE_EMAIL
    [[ "$LE_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "Email invalido."
fi
INSTALL_PHPMYADMIN=n
if [[ "$STACK" == lamp ]]; then echo "Instala o phpMyAdmin, acessivel somente localmente por tunel SSH."; read -r -p "Instalar phpMyAdmin somente local? (s/N): " INSTALL_PHPMYADMIN; fi
echo "Aplica bloqueio de entrada e preserva as portas SSH detectadas; revise regras de rede antes de ativar."
read -r -p "Configurar UFW? (S/n): " CONFIGURE_UFW
echo "Ativa bloqueio automatico de IPs com tentativas suspeitas em SSH e no servidor web."
read -r -p "Configurar Fail2Ban SSH e protecao web? (S/n): " CONFIGURE_FAIL2BAN
echo "Senha administrativa local do MariaDB; sera ocultada e guardada somente em arquivo root 0600."
read -r -s -p "Senha MariaDB root [vazio: gerar]: " DB_ROOT_PASS
printf '\n'
if [[ -z "$DB_ROOT_PASS" ]]; then DB_ROOT_PASS=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n'); fi
[[ "$DB_ROOT_PASS" != *$'\r'* ]] || die "Senha contem caractere de controle."
log_info "Credencial recebida/gerada (oculta). Site: $DOMAIN_NAME; PHP $PHP_VER; deploy: $CODE_OWNER."
log_info "Diretorio: $WEB_ROOT; escrita web: ${WRITABLE_DIRS[*]}; opcionais: ${EXTRA_MODULES[*]:-nenhum}."

echo "Informe somente o IPv4 do proxy reverso ou balanceador que encaminha requisicoes para este servidor."
echo "Nao informe o IP do visitante. Com Cloudflare, deixe vazio e configure os intervalos oficiais separadamente."
echo "Se o dominio aponta diretamente para esta maquina, pressione ENTER."
read -r -p "IPv4 do proxy confiavel [vazio: acesso direto]: " TRUSTED_PROXY
if [[ -n "$TRUSTED_PROXY" ]]; then
    [[ "$TRUSTED_PROXY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "IPv4 de proxy invalido."
    IFS=. read -r -a OCTETS <<< "$TRUSTED_PROXY"
    for octet in "${OCTETS[@]}"; do ((10#$octet <= 255)) || die "IPv4 de proxy invalido."; done
fi
log_info "Proxy confiavel: ${TRUSTED_PROXY:-nenhum}; restrinja a origem no firewall de borda."
# Recusar servidores com sites ativos customizados: alteracoes globais exigem migracao planejada.
for enabled_site in /etc/apache2/sites-enabled/* /etc/nginx/sites-enabled/*; do
    [[ -e "$enabled_site" ]] || continue
    case "$(basename "$enabled_site")" in 000-default.conf|default-ssl.conf|default) ;; *) die "Servidor com site customizado ativo: $enabled_site. Use servidor limpo." ;; esac
 done

# 3. REPOSITORIOS E PACOTES
print_header "PACOTES"
apt-get update -y > /dev/null 2>&1
install_packages ca-certificates curl acl openssl
case "$OS_VERSION" in
    22.04)
        install_packages software-properties-common
        add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
        apt-get update -y > /dev/null 2>&1 ;;
    24.04|26.04) log_info "Pacotes nativos assinados do Ubuntu." ;;
esac
WEB_SERVICE=apache2
[[ "$STACK" != lemp ]] || WEB_SERVICE=nginx
install_packages "$WEB_SERVICE" mariadb-server mariadb-client "php${PHP_VER}-fpm" "php${PHP_VER}-cli" "php${PHP_VER}-mysql" "php${PHP_VER}-curl" "php${PHP_VER}-gd" "php${PHP_VER}-mbstring" "php${PHP_VER}-xml" "php${PHP_VER}-zip" "php${PHP_VER}-intl"
for module in "${EXTRA_MODULES[@]}"; do install_packages "php${PHP_VER}-$module"; done

# 4. BANCO LOCAL E SEGREDOS PRIVADOS
print_header "BANCO LOCAL"
printf '[mysqld]\nbind-address = 127.0.0.1\n' > /etc/mysql/mariadb.conf.d/60-web-local.cnf
systemctl enable --now mariadb > /dev/null
systemctl restart mariadb
SQL_PASS=$(sql_escape "$DB_ROOT_PASS")
cat > "$RUNTIME_DIR/database.sql" <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${SQL_PASS}');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
mariadb --protocol=socket < "$RUNTIME_DIR/database.sql" > /dev/null 2>&1 || die "Falha MariaDB pelo socket local."
CREDENTIALS_FILE="/root/credenciais_${STACK}_${DOMAIN_NAME}_${LOG_TIMESTAMP}.txt"
(set -o noclobber; printf 'MariaDB root: %s\n' "$DB_ROOT_PASS" > "$CREDENTIALS_FILE")
chmod 600 "$CREDENTIALS_FILE"
unset DB_ROOT_PASS SQL_PASS
rm -f "$RUNTIME_DIR/database.sql"

# 5. PERMISSOES E POOL FPM POR SITE
print_header "PERMISSOES E PHP-FPM"
install -d -m 750 -o "$CODE_OWNER" -g www-data "$WEB_ROOT"
PARENT_DIR=$(dirname "$WEB_ROOT")
while [[ "$PARENT_DIR" != / ]]; do
    setfacl -m u:www-data:--x "$PARENT_DIR"
    PARENT_DIR=$(dirname "$PARENT_DIR")
done
setfacl -b -k "$WEB_ROOT"
for relative in "${WRITABLE_DIRS[@]}"; do
    install -d -m 750 -o "$CODE_OWNER" -g www-data "$WEB_ROOT/$relative"
    setfacl -m u:www-data:rwx,d:u:www-data:rwx,d:m::rwx "$WEB_ROOT/$relative"
done
POOL_ID="${STACK}_$(printf '%s' "$DOMAIN_NAME" | sha256sum | cut -c1-16)"
FPM_SOCK="/run/php/${POOL_ID}.sock"
cat > "/etc/php/$PHP_VER/fpm/pool.d/$POOL_ID.conf" <<EOF
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
php_admin_value[session.use_strict_mode] = 1
php_admin_value[session.cookie_samesite] = Lax
php_admin_value[memory_limit] = 512M
php_admin_value[upload_max_filesize] = ${UPLOAD_MB}M
php_admin_value[post_max_size] = $((UPLOAD_MB + 8))M
php_admin_value[max_execution_time] = $EXEC_TIME
EOF
php-fpm"$PHP_VER" -t > /dev/null 2>&1
systemctl enable --now "php$PHP_VER-fpm" > /dev/null
systemctl reload "php$PHP_VER-fpm"

# 6. SERVIDOR WEB
print_header "VIRTUALHOST"
if [[ "$STACK" == lamp ]]; then
    for mod in dav_fs dav_lock dav cgi cgid include info status autoindex userdir; do
        if [[ -e /etc/apache2/mods-enabled/$mod.load ]]; then
            log_info "Desativando modulo Apache: $mod"
            a2dismod -f "$mod" > /dev/null
        fi
    done
    for conf in /etc/apache2/mods-enabled/php*.load; do
        [[ ! -e "$conf" ]] || a2dismod -f "$(basename "$conf" .load)" > /dev/null
    done
    a2dismod -f mpm_prefork > /dev/null
    a2enmod mpm_event proxy_fcgi rewrite headers setenvif > /dev/null
    printf 'ServerTokens Prod\nServerSignature Off\nTraceEnable Off\nProxyRequests Off\n' > /etc/apache2/conf-available/web-security.conf
    a2enconf web-security > /dev/null
    if [[ -n "$TRUSTED_PROXY" ]]; then
        a2enmod remoteip > /dev/null
        printf 'RemoteIPHeader X-Forwarded-For\nRemoteIPTrustedProxy %s\n' "$TRUSTED_PROXY" > /etc/apache2/conf-available/web-proxy.conf
        a2enconf web-proxy > /dev/null
    fi
    ROOT_REGEX=${WEB_ROOT//./\\.}
    cat > "/etc/apache2/sites-available/$DOMAIN_NAME.conf" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    DocumentRoot "$WEB_ROOT"
    <Directory "$WEB_ROOT">
        Options -Indexes -ExecCGI -Includes +FollowSymLinks
        AllowOverride None
        AllowOverrideList RewriteEngine RewriteOptions RewriteBase RewriteCond RewriteRule
        Require all granted
        DirectoryIndex index.php index.html
        <FilesMatch "\\.php$">
            SetHandler "proxy:unix:$FPM_SOCK|fcgi://localhost/"
        </FilesMatch>
    </Directory>
    <DirectoryMatch "^$ROOT_REGEX/($WRITABLE_REGEX)(/|$)">
        AllowOverride None
        AllowOverrideList None
        <FilesMatch "(?i)\\.(php[0-9]*|phtml|pht|phar|phps|inc)([./]|$)">
            Require all denied
        </FilesMatch>
    </DirectoryMatch>
    <FilesMatch "(?i)\.(phtml|pht|phar|phps|php[0-9]+|inc)$">
        Require all denied
    </FilesMatch>
    <LocationMatch "(^|/)\\.(?!well-known/)">
        Require all denied
    </LocationMatch>
    <FilesMatch "(?i)(^configuration\\.php$|\\.(sql|bak|old|orig|ini|log|sh|dist|tar)$)">
        Require all denied
    </FilesMatch>
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_access.log combined
</VirtualHost>
EOF
    cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    <Location "/">
        Require all denied
    </Location>
</VirtualHost>
EOF
    a2ensite 000-default "$DOMAIN_NAME" > /dev/null
    apache2ctl configtest > /dev/null 2>&1
else
    cat > "/etc/nginx/sites-available/$DOMAIN_NAME" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    root $WEB_ROOT;
    index index.php index.html;
    server_tokens off;
    autoindex off;
    client_max_body_size $((UPLOAD_MB + 8))M;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    location ~* ^/($WRITABLE_REGEX)/.*\\.(php[0-9]*|phtml|pht|phar|phps|inc)([./]|$) { deny all; }
    location ~* \.(phtml|pht|phar|phps|php[0-9]+|inc)$ { deny all; }
    location ~ (^|/)\\.(?!well-known/) { deny all; }
    location ~* (^/configuration\\.php$|\\.(sql|bak|old|orig|ini|log|sh|dist|tar)$) { deny all; }
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \\.php$ {
        try_files \$uri =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:$FPM_SOCK;
        fastcgi_read_timeout ${EXEC_TIME}s;
    }
    access_log /var/log/nginx/${DOMAIN_NAME}_access.log;
    error_log /var/log/nginx/${DOMAIN_NAME}_error.log;
}
EOF
    if [[ -n "$TRUSTED_PROXY" ]]; then
        printf 'set_real_ip_from %s;\nreal_ip_header X-Forwarded-For;\nreal_ip_recursive on;\n' "$TRUSTED_PROXY" > /etc/nginx/conf.d/web-proxy.conf
    fi
    ln -s "/etc/nginx/sites-available/$DOMAIN_NAME" "/etc/nginx/sites-enabled/$DOMAIN_NAME"
    cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 404;
}
EOF
    if [[ ! -e /etc/nginx/sites-enabled/default ]]; then
        ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    fi
    nginx -t > /dev/null 2>&1
fi
systemctl enable --now "$WEB_SERVICE" > /dev/null
systemctl restart "$WEB_SERVICE"

# 7. ADMINISTRACAO, FIREWALL E HTTPS
print_header "REDE E ADMINISTRACAO"
if [[ "${INSTALL_PHPMYADMIN,,}" == s ]]; then
    printf '%s\n' 'phpmyadmin phpmyadmin/dbconfig-install boolean false' 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect' | debconf-set-selections
    install_packages phpmyadmin
    cat > /etc/apache2/conf-available/web-phpmyadmin.conf <<EOF
Listen 127.0.0.1:8081
<VirtualHost 127.0.0.1:8081>
DocumentRoot /usr/share/phpmyadmin
<Directory /usr/share/phpmyadmin>
    AllowOverride None
    Require local
    DirectoryIndex index.php
    <FilesMatch "\\.php$">
        SetHandler "proxy:unix:$FPM_SOCK|fcgi://localhost/"
    </FilesMatch>
</Directory>
</VirtualHost>
EOF
    a2enconf web-phpmyadmin > /dev/null
    apache2ctl configtest > /dev/null 2>&1
    systemctl reload apache2
fi
if [[ "${CONFIGURE_UFW,,}" != n ]]; then
    install_packages ufw
    command -v sshd >/dev/null || die "SSH nao detectado; firewall exige revisao manual."
    SSH_PORTS=$(sshd -T | awk '$1=="port" {print $2}')
    [[ -n "$SSH_PORTS" ]] || die "Nenhuma porta SSH detectada."
    for port in $SSH_PORTS; do ufw allow "$port/tcp" > /dev/null; done
    ufw default deny incoming > /dev/null
    ufw allow 80/tcp > /dev/null
    if [[ "${ENABLE_TLS,,}" == s ]]; then ufw allow 443/tcp > /dev/null; fi
    ufw --force enable > /dev/null
fi
if [[ "${CONFIGURE_FAIL2BAN,,}" != n ]]; then
    install_packages fail2ban
    command -v sshd >/dev/null || die "SSH nao detectado para Fail2Ban."
    SSH_PORTS=$(sshd -T | awk '$1=="port" {printf "%s%s", sep, $2; sep=","}')
    printf '[sshd]\nenabled = true\nbackend = systemd\nport = %s\n' "$SSH_PORTS" > /etc/fail2ban/jail.d/web-sshd.local
    # SSH usa journal; protecao web acompanha os arquivos do VirtualHost.
    WEB_FILTER_PREFIX=apache
    WEB_LOG_DIR=/var/log/apache2
    [[ "$STACK" != lemp ]] || { WEB_FILTER_PREFIX=nginx; WEB_LOG_DIR=/var/log/nginx; }
    WEB_AUTH_FILTER="${WEB_FILTER_PREFIX}-auth"
    [[ "$STACK" != lemp ]] || WEB_AUTH_FILTER=nginx-http-auth
    WEB_BOT_FILTER="${WEB_FILTER_PREFIX}-botsearch"
    WEB_JAILS=("$WEB_AUTH_FILTER" "$WEB_BOT_FILTER")
    for web_filter in "${WEB_JAILS[@]}"; do
        [[ -f "/etc/fail2ban/filter.d/${web_filter}.conf" ]] || die "Filtro Fail2Ban ausente: $web_filter."
    done
    touch "$WEB_LOG_DIR/${DOMAIN_NAME}_error.log"
    cat > "/etc/fail2ban/jail.d/${STACK}-web.local" <<EOF
[$WEB_AUTH_FILTER]
enabled = true
filter = $WEB_AUTH_FILTER
backend = polling
port = http,https
logpath = $WEB_LOG_DIR/${DOMAIN_NAME}_error.log
usedns = no
ignoreip = 127.0.0.0/8 ::1 $TRUSTED_PROXY
maxretry = 5
findtime = 10m
bantime = 1h

[$WEB_BOT_FILTER]
enabled = true
filter = $WEB_BOT_FILTER
backend = polling
port = http,https
logpath = $WEB_LOG_DIR/${DOMAIN_NAME}_error.log
usedns = no
ignoreip = 127.0.0.0/8 ::1 $TRUSTED_PROXY
maxretry = 5
findtime = 10m
bantime = 1h
EOF
    fail2ban-client -t > /dev/null 2>&1
    systemctl enable --now fail2ban > /dev/null
    systemctl restart fail2ban
    for jail in sshd "${WEB_JAILS[@]}"; do
        fail2ban-client status "$jail" > /dev/null || die "Jaula Fail2Ban inativa: $jail."
    done
    log_success "Fail2Ban ativo: SSH e ${WEB_JAILS[*]}."
    if [[ -n "$TRUSTED_PROXY" ]]; then
        log_warning "Com proxy, bloqueios de clientes precisam ser aplicados tambem no proxy/borda; firewall local nao bloqueia o IP encaminhado."
    fi
fi
TLS_STATUS="Nao configurado: valide HTTPS no proxy antes de autenticar."
if [[ "${ENABLE_TLS,,}" == s ]]; then
    CERT_PLUGIN=apache
    [[ "$STACK" != lemp ]] || CERT_PLUGIN=nginx
    install_packages certbot "python3-certbot-$CERT_PLUGIN"
    certbot "--$CERT_PLUGIN" --non-interactive --agree-tos --redirect --email "$LE_EMAIL" -d "$DOMAIN_NAME"
    printf 'php_admin_value[session.cookie_secure] = 1\n' >> "/etc/php/$PHP_VER/fpm/pool.d/$POOL_ID.conf"
    php-fpm"$PHP_VER" -t > /dev/null 2>&1
    systemctl reload "php$PHP_VER-fpm"
    TLS_STATUS="Certificado instalado, redirecionamento HTTPS ativo."
fi

# 8. RESUMO E RELATORIOS
print_header "RESUMO DA INSTALACAO"
LISTA_PACOTES=$(IFS=,; echo "${PACOTES_INSTALADOS[*]}")
log_success "Pilha preparada. Publique somente arquivos revisados."
log_info "Pacotes instalados: $LISTA_PACOTES"
systemctl is-active --quiet "$WEB_SERVICE" "php${PHP_VER}-fpm" mariadb || die "Servico obrigatorio inativo."
log_info "TLS: $TLS_STATUS"
log_info "Deploy: $CODE_OWNER; escrita web: ${WRITABLE_DIRS[*]}."
log_warning "Atualizacoes pelo painel exigem manutencao controlada. Nunca mantenha escrita web em todo o codigo."
log_warning "Proxy: configure IP real somente de origens confiaveis e restrinja o acesso ao backend."
log_info "Nenhum phpinfo publico foi criado. Aplicacao deve usar usuario de banco proprio, nunca root."
print_header "ARQUIVOS DE LOG DA INSTALACAO"
log_info "Relatorio: /root/$LOG_FILENAME; credencial privada: $CREDENTIALS_FILE"
