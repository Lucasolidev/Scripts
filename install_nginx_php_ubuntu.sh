#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# INSTALADOR NGINX + PHP-FPM (OTIMIZADO PARA CLOUDFLARE TUNNEL & DOWNLOADS)
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_nginx_php_ubuntu.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh
#
# Executar via URL
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh | bash
#
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
    echo -e "${FG_CYAN}${BOLD}=== SYSTEM MANAGER ===${NC}"
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# ------------------------------------------------------------------------------
# CHECAGEM DE ROOT
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    log_error "Este script precisa ser executado como root (sudo)."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. INTERATIVIDADE E COLETA DE PARÂMETROS
# ------------------------------------------------------------------------------
print_header "COLETA DE PARÂMETROS"

echo -e "  ${FG_WHITE}Configuração do Servidor Nginx + PHP-FPM para o Gerenciador de Downloads${NC}\n"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Informe o domínio ou subdomínio (ex: downloads.nuvemativa.com.br): ${NC}")" DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-downloads.nuvemativa.com.br}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Versão do PHP a instalar (Padrão: mais recente / latest): ${NC}")" PHP_INPUT
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

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Limite máximo de Upload/Download em MB/GB (Padrão: 2G): ${NC}")" UPLOAD_MAX
UPLOAD_MAX=${UPLOAD_MAX:-2G}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Tempo máximo de execução de scripts PHP em segundos (Padrão: 3600): ${NC}")" EXEC_TIME
EXEC_TIME=${EXEC_TIME:-3600}

log_info "Domínio configurado: ${BOLD}${DOMAIN_NAME}${NC}"
log_info "Versão do PHP solicitada: ${BOLD}${LOG_PHP_MSG}${NC}"
log_info "Limite de Upload: ${BOLD}${UPLOAD_MAX}${NC}"
log_info "Timeout de Execução: ${BOLD}${EXEC_TIME}s${NC}"

# ------------------------------------------------------------------------------
# 4. INSTALAÇÃO SILENCIOSA E PREPARAÇÃO DO AMBIENTE
# ------------------------------------------------------------------------------
print_header "INSTALAÇÃO DE PACOTES E DEPENDÊNCIAS"

log_info "Atualizando lista de repositórios..."
apt-get update -y > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "Repositórios atualizados com sucesso."
else
    log_error "Falha ao atualizar repositórios."
    exit 1
fi

log_info "Instalando dependências de repositório (gnupg, software-properties-common)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common ca-certificates lsb-release apt-transport-https gnupg > /dev/null 2>&1

log_info "Adicionando repositório PHP (ppa:ondrej/php)..."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get update -y > /dev/null 2>&1

PACKAGES=(
    "nginx"
    "${PKG_PREFIX}fpm"
    "${PKG_PREFIX}cli"
    "${PKG_PREFIX}common"
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
)

# Caso a versão específica não seja encontrada no repositório, fallback para a versão mais recente (php-fpm)
if [ -n "$PHP_VER" ] && ! apt-cache show "${PKG_PREFIX}fpm" > /dev/null 2>&1; then
    log_warning "Pacote ${PKG_PREFIX}fpm não encontrado no repositório. Tentando instalar versão padrão do sistema (php-fpm)..."
    PHP_VER=""
    PKG_PREFIX="php-"
    PACKAGES=(
        "nginx"
        "php-fpm"
        "php-cli"
        "php-common"
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
# 6. CONFIGURAÇÃO DO NGINX (OTIMIZADO PARA CLOUDFLARE TUNNEL)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO NGINX"

WEB_ROOT="/var/www/gerenciador"
log_info "Criando diretório da aplicação em ${WEB_ROOT}..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
log_success "Diretório criado com permissões adequadas."

NGINX_CONF="/etc/nginx/sites-available/${DOMAIN_NAME}"

log_info "Criando arquivo de VirtualHost no Nginx..."
cat <<EOF > "$NGINX_CONF"
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN_NAME};
    root ${WEB_ROOT};
    index index.php index.html index.htm;

    # Otimização de uploads/downloads para Cloudflare Tunnel
    client_max_body_size ${UPLOAD_MAX};
    client_body_timeout ${EXEC_TIME}s;
    fastcgi_read_timeout ${EXEC_TIME}s;
    fastcgi_send_timeout ${EXEC_TIME}s;

    # Otimizações de desempenho de arquivos estáticos
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Bloquear visualização de diretórios e arquivos ocultos
    location ~ /\. {
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
if [ ! -f "${WEB_ROOT}/index.php" ]; then
    cat <<EOF > "${WEB_ROOT}/index.php"
<?php
// Teste de ambiente preparado para o Gerenciador de Downloads
echo "<h1>Servidor Otimizado - " . htmlspecialchars("\$_SERVER['HTTP_HOST']") . "</h1>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Upload Max Filesize: " . ini_get('upload_max_filesize') . "</p>";
echo "<p>Post Max Size: " . ini_get('post_max_size') . "</p>";
EOF
    chown www-data:www-data "${WEB_ROOT}/index.php"
fi

# ------------------------------------------------------------------------------
# 8. AJUSTE DE FIREWALL LOCAL (UFW)
# ------------------------------------------------------------------------------
print_header "CONFIGURAÇÃO DO FIREWALL LOCAL (UFW)"
log_info "Garantindo acesso apenas via HTTP/SSH..."
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
log_success "Firewall UFW configurado e ativado."

# ------------------------------------------------------------------------------
# 9. RESUMO DO SISTEMA
# ------------------------------------------------------------------------------
print_header "RESUMO DO SISTEMA"

echo -e "  ${BOLD}Status do Servidor:${NC}       ${FG_GREEN}Operacional e Pronto${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Domínio Configurado:${NC}     ${FG_CYAN}${DOMAIN_NAME}${NC}"
echo -e "  ${BOLD}Diretório Web (Root):${NC}    ${FG_CYAN}${WEB_ROOT}${NC}"
echo -e "  ${BOLD}Versão do PHP:${NC}           ${FG_CYAN}PHP ${PHP_VER} (FPM)${NC}"
echo -e "  ${BOLD}Limite Upload/Download:${NC}  ${FG_CYAN}${UPLOAD_MAX}${NC}"
echo -e "  ${BOLD}Timeout de Execução:${NC}     ${FG_CYAN}${EXEC_TIME} segundos${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"

print_alert_box "PRÓXIMOS PASSOS NO PAINEL DA CLOUDFLARE:"
echo -e "  1. No Cloudflare Zero Trust -> Networks -> Tunnels:"
echo -e "     - Adicione a rota HTTP apontando para o IP desta VM na porta 80."
echo -e "     - Exemplo: Service: ${FG_CYAN}HTTP${NC} | URL: ${FG_CYAN}IP_DA_SUA_VM:80${NC}"
echo -e "  2. No Cloudflare Zero Trust -> Access -> Applications:"
echo -e "     - Crie uma aplicação para proteger ${FG_CYAN}${DOMAIN_NAME}${NC} exigindo autenticação por e-mail (One-Time PIN)."
echo -e "  3. Copie o seu projeto de Gerenciador de Downloads para: ${FG_CYAN}${WEB_ROOT}${NC}\n"

draw_separator
echo -e "${FG_GREEN}${BOLD}❯ Instalação concluída com sucesso!${NC}\n"
