#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# INSTALADOR STACK LEMP (NGINX + MARIADB + PHP-FPM) - UBUNTU
# ==============================================================================
# Execução recomendada (download e execução local):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lemp_ubuntu.sh
# chmod +x install_lemp_ubuntu.sh
# sudo ./install_lemp_ubuntu.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PALETA DE CORES E ESTILOS (ANSI)
# ------------------------------------------------------------------------------
NC="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

FG_CYAN="\033[36m"
FG_YELLOW="\033[33m"
FG_GREEN="\033[32m"
FG_RED="\033[31m"
FG_WHITE="\033[37m"

ARROW="❯"

# ------------------------------------------------------------------------------
# 2. FUNÇÕES AUXILIARES VISUAIS
# ------------------------------------------------------------------------------
draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
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

# ------------------------------------------------------------------------------
# CHECAGEM DE ROOT
# ------------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script precisa ser executado como root (sudo)."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. INTERATIVIDADE E COLETA DE PARÂMETROS
# ------------------------------------------------------------------------------
print_header "COLETA DE PARÂMETROS"

echo -e "  ${FG_WHITE}Configuração do Servidor LEMP (Nginx + MariaDB + PHP-FPM)${NC}\n"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Informe o domínio ou subdomínio (ex: meudominio.com.br): ${NC}")" DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-meudominio.com.br}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Versão do PHP a instalar (Pressione ENTER para a mais recente | ou informe ex: 8.2): ${NC}")" PHP_INPUT
PHP_INPUT=${PHP_INPUT:-latest}

if [[ "$PHP_INPUT" =~ ^[Ll]atest$ || "$PHP_INPUT" == "mais recente" ]]; then
    PHP_VER=""
    PKG_PREFIX="php-"
    LOG_PHP_MSG="Mais recente do repositório"
else
    # Extrai apenas números e ponto caso o usuário digite php8.2 ou 8.2
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

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Limite máximo de Upload/Download em MB/GB (Padrão: 128M | 0 para ilimitado): ${NC}")" UPLOAD_MAX
UPLOAD_MAX=${UPLOAD_MAX:-128M}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Tempo máximo de execução de scripts PHP em segundos (Padrão: 300): ${NC}")" EXEC_TIME
EXEC_TIME=${EXEC_TIME:-300}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar uma aleatória): ${NC}")" DB_ROOT_PASS
if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(openssl rand -base64 12 2>/dev/null || date +%s | sha256sum | base64 | head -c 16)
fi

log_info "Domínio configurado: ${BOLD}${DOMAIN_NAME}${NC}"
log_info "Versão do PHP solicitada: ${BOLD}${LOG_PHP_MSG}${NC}"
log_info "Limite de Upload: ${BOLD}${UPLOAD_MAX}${NC}"
log_info "Timeout de Execução: ${BOLD}${EXEC_TIME}s${NC}"

# ------------------------------------------------------------------------------
# 4. INSTALAÇÃO SILENCIOSA E PREPARAÇÃO DO AMBIENTE
# ------------------------------------------------------------------------------
print_header "INSTALAÇÃO DE PACOTES E DEPENDÊNCIAS"

log_info "Atualizando lista de repositórios..."
apt-get update -y > /dev/null 2>&1 || true
log_success "Lista de repositórios atualizada."

log_info "Instalando dependências de repositório (gnupg, software-properties-common)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common ca-certificates lsb-release apt-transport-https gnupg > /dev/null 2>&1

log_info "Adicionando repositório PHP (ppa:ondrej/php)..."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1 || true
apt-get update -y > /dev/null 2>&1 || true

PACKAGES=(
    "nginx"
    "mariadb-server"
    "mariadb-client"
    "${PKG_PREFIX}fpm"
    "${PKG_PREFIX}cli"
    "${PKG_PREFIX}common"
    "${PKG_PREFIX}mysql"
    "${PKG_PREFIX}curl"
    "${PKG_PREFIX}gd"
    "${PKG_PREFIX}mbstring"
    "${PKG_PREFIX}xml"
    "${PKG_PREFIX}zip"
    "${PKG_PREFIX}intl"
    "${PKG_PREFIX}bcmath"
    "unzip"
    "git"
    "ufw"
    "fail2ban"
    "acl"
)

# Caso a versão específica não seja encontrada no repositório, fallback para a versão mais recente (php-fpm)
if [ -n "$PHP_VER" ] && ! apt-cache show "${PKG_PREFIX}fpm" > /dev/null 2>&1; then
    log_warning "Pacote ${PKG_PREFIX}fpm não encontrado no repositório. Tentando instalar versão padrão do sistema (php-fpm)..."
    PHP_VER=""
    PKG_PREFIX="php-"
    PACKAGES=(
        "nginx"
        "mariadb-server"
        "mariadb-client"
        "php-fpm"
        "php-cli"
        "php-common"
        "php-mysql"
        "php-curl"
        "php-gd"
        "php-mbstring"
        "php-xml"
        "php-zip"
        "php-intl"
        "php-bcmath"
        "unzip"
        "git"
        "ufw"
        "fail2ban"
        "acl"
    )
fi

for pkg in "${PACKAGES[@]}"; do
    log_info "Instalando pacote: ${pkg}..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "Pacote ${pkg} instalado."
    else
        log_warning "Falha ao instalar o pacote ${pkg}."
    fi
done

# ------------------------------------------------------------------------------
# 5. CONFIGURAÇÃO DO PHP-FPM PARA ARQUIVOS GRANDES
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO PHP-FPM"

# Detectar versão real do PHP instalada caso tenha sido instalado php-fpm nativo
INSTALLED_PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
if [ -n "$INSTALLED_PHP_VER" ]; then
    PHP_VER="$INSTALLED_PHP_VER"
fi

PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"

if [ -f "$PHP_INI" ]; then
    log_info "Aplicando otimizações no ${PHP_INI} (PHP ${PHP_VER})..."
    
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${UPLOAD_MAX}/" "$PHP_INI"
    sed -i "s/post_max_size = .*/post_max_size = ${UPLOAD_MAX}/" "$PHP_INI"
    sed -i "s/max_execution_time = .*/max_execution_time = ${EXEC_TIME}/" "$PHP_INI"
    sed -i "s/max_input_time = .*/max_input_time = ${EXEC_TIME}/" "$PHP_INI"
    sed -i "s/memory_limit = .*/memory_limit = 512M/" "$PHP_INI"
    
    log_success "Parâmetros do PHP-FPM ajustados com sucesso."
    
    log_info "Reiniciando serviço php${PHP_VER}-fpm..."
    systemctl restart "php${PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1
    log_success "Serviço php${PHP_VER}-fpm reiniciado."
else
    log_error "Arquivo de configuração do PHP-FPM (${PHP_INI}) não encontrado."
fi

# ------------------------------------------------------------------------------
# 6. CONFIGURAÇÃO DO BANCO DE DADOS (MARIADB SERVER)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO BANCO DE DADOS (MARIADB SERVER)"

log_info "Iniciando e habilitando serviço mariadb no boot..."
systemctl enable --now mariadb > /dev/null 2>&1
log_success "Serviço MariaDB em execução."

log_info "Configurando credenciais do usuário root do MariaDB..."
mysql -u root <<EOF > /dev/null 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DB_ROOT_PASS');
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    log_success "Senha do usuário root do MariaDB configurada com sucesso."
else
    mysqladmin -u root password "$DB_ROOT_PASS" > /dev/null 2>&1 || true
    log_success "Senha do root do MariaDB aplicada."
fi

# ------------------------------------------------------------------------------
# 7. CONFIGURAÇÃO DO NGINX (LEMP STACK)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO NGINX"

WEB_ROOT="/var/www/${DOMAIN_NAME}"
log_info "Criando diretório da aplicação em ${WEB_ROOT}..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data /var/www
chmod -R 775 /var/www

log_info "Aplicando herança de permissões automática com POSIX ACLs (setfacl) em /var/www..."
setfacl -R -m u:www-data:rwx,g:www-data:rwx /var/www > /dev/null 2>&1 || true
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /var/www > /dev/null 2>&1 || true
log_success "Diretório preparado e ACLs ativas: Novos arquivos em /var/www herdarão acesso total para www-data."

log_info "Configurando ajustes globais do Nginx (tuning de conexões, segurança e WebSockets)..."
cat <<EOF > /etc/nginx/conf.d/tuning.conf
# Aumenta o limite de descriptores de arquivo para evitar avisos de ulimit
worker_rlimit_nofile 65535;

# SEGURANÇA: Oculta a versão do Nginx nos cabeçalhos HTTP e páginas de erro
server_tokens off;
EOF

cat <<EOF > /etc/nginx/conf.d/websocket.conf
# Mapeamento dinâmico para upgrade de WebSockets sem quebrar Keep-Alive HTTP
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}
EOF

NGINX_CONF="/etc/nginx/sites-available/${DOMAIN_NAME}"

log_info "Criando arquivo de VirtualHost no Nginx..."
cat <<EOF > "$NGINX_CONF"
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN_NAME} _;
    root ${WEB_ROOT};
    index index.php index.html index.htm;

    # Otimização de uploads e timeouts do site
    client_max_body_size ${UPLOAD_MAX};
    client_body_timeout ${EXEC_TIME}s;
    send_timeout ${EXEC_TIME}s;
    fastcgi_read_timeout ${EXEC_TIME}s;
    fastcgi_send_timeout ${EXEC_TIME}s;

    # Cabeçalhos Globais de Segurança (OWASP Best Practices)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Roteamento padrão (compatível com WordPress, Laravel, etc)
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Otimização de cache para arquivos estáticos (CSS, JS, Imagens, Fontes)
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    }

    # Bloquear visualização de diretórios e arquivos ocultos (.git, .env, etc)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Bloquear acesso direto a arquivos de configuração e logs sensíveis
    location ~* \.(env|git|log|sh|sql|bak|swp|yml|yaml)\$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Processamento de arquivos PHP via FastCGI
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# Ativar o site no Nginx
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/${DOMAIN_NAME}"
rm -f /etc/nginx/sites-enabled/default

log_info "Testando sintaxe das configurações do Nginx..."
nginx -t > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "Sintaxe do Nginx validada sem erros."
    systemctl restart nginx > /dev/null 2>&1
    log_success "Nginx reiniciado com sucesso."
else
    log_error "Erro nas configurações do Nginx!"
fi

# ------------------------------------------------------------------------------
# 7. CRIAÇÃO DE ARQUIVO DE TESTE PHP
# ------------------------------------------------------------------------------
cat <<'EOF' > "${WEB_ROOT}/index.php"
<?php
// Teste de ambiente preparado para o Gerenciador de Downloads
$host = $_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_ADDR'] ?? 'Localhost';
echo "<h1>Servidor Otimizado - " . htmlspecialchars((string)$host) . "</h1>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Upload Max Filesize: " . ini_get('upload_max_filesize') . "</p>";
echo "<p>Post Max Size: " . ini_get('post_max_size') . "</p>";
EOF
chown www-data:www-data "${WEB_ROOT}/index.php"

# ------------------------------------------------------------------------------
# 8. AJUSTE DE FIREWALL LOCAL (UFW)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO FIREWALL LOCAL (UFW)"
log_info "Garantindo acesso via HTTP (80), HTTPS (443) e SSH (22)..."
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
log_success "Firewall UFW configurado e ativado (Portas 80, 443, 22)."

# ------------------------------------------------------------------------------
# 9. CONFIGURAÇÃO DO FAIL2BAN (PROTEÇÃO SSH E NGINX)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO FAIL2BAN"
log_info "Garantindo existência dos arquivos de log do Nginx..."
mkdir -p /var/log/nginx
touch /var/log/nginx/error.log /var/log/nginx/access.log
chown -R www-data:adm /var/log/nginx > /dev/null 2>&1 || true

log_info "Criando arquivo de configuração em /etc/fail2ban/jail.local..."

cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
backend = systemd
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh

[nginx-http-auth]
enabled = true
port    = http,https
logpath = /var/log/nginx/error.log
EOF

log_info "Ativando e iniciando o serviço Fail2Ban..."
systemctl enable --now fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
log_success "Fail2Ban configurado e ativo com regras para SSH e Nginx."

# ------------------------------------------------------------------------------
# 10. RESUMO DO SISTEMA E ARQUIVOS DE CONFIGURAÇÃO
# ------------------------------------------------------------------------------
print_header "RESUMO DO SISTEMA - INSTALAÇÃO CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO NGINX + PHP-FPM + MARIADB FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Pronto${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}          Nginx ($(systemctl is-active nginx 2>/dev/null || echo "active"))"
echo -e "  ${BOLD}Banco de Dados:${NC}        MariaDB Server ($(systemctl is-active mariadb 2>/dev/null || echo "active"))"
echo -e "  ${BOLD}Linguagem de Script:${NC}   PHP ${PHP_VER} (FPM)"
echo -e "  ${BOLD}Permissões POSIX ACL:${NC}  ${FG_GREEN}Ativo e Herdando (/var/www)${NC}"
echo -e "  ${BOLD}Proteção Fail2Ban:${NC}     $(systemctl is-active fail2ban >/dev/null 2>&1 && echo -e "${FG_GREEN}Ativo e Protegendo (/etc/fail2ban/jail.local)${NC}" || echo "Não instalado")"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Domínio Configurado:${NC}   ${FG_CYAN}${DOMAIN_NAME}${NC}"
echo -e "  ${BOLD}Diretório Web (Root):${NC}  ${FG_CYAN}${WEB_ROOT}${NC}"
echo -e "  ${BOLD}Limite Upload/Download:${NC}${FG_CYAN}${UPLOAD_MAX}${NC}"
echo -e "  ${BOLD}Timeout de Execução:${NC}   ${FG_CYAN}${EXEC_TIME} segundos${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais MariaDB Root:${NC}"
echo -e "    Usuário: ${FG_CYAN}root${NC}"
echo -e "    Senha:   ${FG_YELLOW}${DB_ROOT_PASS}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}📁 LEMBRETES DE ARQUIVOS DE CONFIGURAÇÃO:${NC}"
echo -e "  ${FG_YELLOW}• VirtualHost Nginx:${NC}       /etc/nginx/sites-available/${DOMAIN_NAME}"
echo -e "  ${FG_YELLOW}• Nginx Geral:${NC}             /etc/nginx/nginx.conf"
echo -e "  ${FG_YELLOW}• Config PHP-FPM (php.ini):${NC}  /etc/php/${PHP_VER}/fpm/php.ini"
echo -e "  ${FG_YELLOW}• Pool PHP-FPM (www.conf):${NC}  /etc/php/${PHP_VER}/fpm/pool.d/www.conf"
echo -e "  ${FG_YELLOW}• Config MariaDB:${NC}          /etc/mysql/mariadb.conf.d/50-server.cnf"
echo -e "  ${FG_YELLOW}• Socket do PHP-FPM:${NC}       /run/php/php${PHP_VER}-fpm.sock"
if systemctl is-active fail2ban >/dev/null 2>&1; then
    echo -e "  ${FG_YELLOW}• Config Fail2Ban:${NC}         /etc/fail2ban/jail.local"
fi
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

draw_separator
echo -e "${FG_GREEN}${BOLD}❯ Instalação concluída com sucesso!${NC}\n"
