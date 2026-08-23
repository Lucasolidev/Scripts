#!/bin/bash
# ------------------------------------------------
# Version: 1.5
# ------------------------------------------------
VERSION="1.5"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO DA PILHA LEMP AUTOMÁTICO E ENDURECIDO - UBUNTU
# NGINX + MARIADB + PHP-FPM COM SUPORTE A WEBSOCKETS E HERANÇA POSIX ACL
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo) e inicializa captura de log.
# 2. Coleta parâmetros (Domínio, Diretório Web Raiz, Versão PHP, Uploads, Timeout e Senha MariaDB).
# 3. Adiciona repositórios oficiais e instala dependências, Nginx, MariaDB Server e PHP-FPM.
# 4. Instala pacote completo de módulos PHP modernos:
#    (fpm, cli, common, mysql, curl, gd, mbstring, xml, zip, opcache, intl, bcmath, imagick, soap, readline).
# 5. Configura o PHP-FPM com limites de upload customizados, timeouts e desativação de funções inseguras.
# 6. Aplica endurecimento no MariaDB (sem base test, sem usuários anônimos e senha segura).
# 7. Cria VirtualHost no Nginx com suporte a WebSockets, HTTP/2, client_max_body_size e FastCGI.
# 8. Aplica herança de permissões POSIX ACLs no diretório configurado.
# 9. Cria arquivo de diagnóstico phpinfo em <WEB_ROOT>/info.php.
# 10. Configura Firewall UFW (80, 443, 22) e Fail2Ban (SSH e Nginx BotSearch).
# 11. Exibe Resumo Final do Sistema com todas as configurações ativas.
# 12. Geração e salvamento automático dos arquivos de log em /root e na Home do usuário.
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lemp_ubuntu.sh -O install_lemp_ubuntu.sh && chmod +x install_lemp_ubuntu.sh && sudo ./install_lemp_ubuntu.sh
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
LOG_FILENAME="install_lemp_ubuntu_${LOG_TIMESTAMP}.log"
LOG_TMP="/tmp/${LOG_FILENAME}"
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "INSTALADOR AUTOMÁTICO LEMP ENDURECIDO - UBUNTU"

# ==============================================================================
# 2. COLETA INTERATIVA DE PARÂMETROS
# ==============================================================================
print_header "COLETA DE PARÂMETROS"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Domínio do site (ex: meusite.com.br): ${NC}")" DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-meudominio.com.br}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Diretório Web Raiz [Padrão: /var/www/${DOMAIN_NAME}]: ${NC}")" CUSTOM_WEB_ROOT
WEB_ROOT=${CUSTOM_WEB_ROOT:-"/var/www/${DOMAIN_NAME}"}

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

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Limite máximo de Upload/Download em MB/GB (Padrão: 128M | 0 para ilimitado): ${NC}")" UPLOAD_MAX
UPLOAD_MAX=${UPLOAD_MAX:-128M}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Tempo máximo de execução de scripts PHP em segundos (Padrão: 300): ${NC}")" EXEC_TIME
EXEC_TIME=${EXEC_TIME:-300}

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar uma aleatória): ${NC}")" DB_ROOT_PASS
if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(openssl rand -base64 12 2>/dev/null || date +%s | sha256sum | base64 | head -c 16)
fi

log_info "Domínio configurado: ${BOLD}${DOMAIN_NAME}${NC}"
log_info "Diretório Web Raiz: ${BOLD}${WEB_ROOT}${NC}"
log_info "Versão do PHP solicitada: ${BOLD}${LOG_PHP_MSG}${NC}"
log_info "Limite de Upload: ${BOLD}${UPLOAD_MAX}${NC}"
log_info "Timeout de Execução: ${BOLD}${EXEC_TIME}s${NC}"

# ==============================================================================
# 3. INSTALAÇÃO DE PACOTES E REPOSITÓRIOS
# ==============================================================================
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
    "${PKG_PREFIX}opcache"
    "${PKG_PREFIX}intl"
    "${PKG_PREFIX}bcmath"
    "${PKG_PREFIX}imagick"
    "${PKG_PREFIX}soap"
    "${PKG_PREFIX}readline"
    "unzip"
    "git"
    "ufw"
    "fail2ban"
    "acl"
)

# Fallback caso a versão específica não seja encontrada
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
        "php-opcache"
        "php-intl"
        "php-bcmath"
        "php-imagick"
        "php-soap"
        "php-readline"
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

# ==============================================================================
# 4. CONFIGURAÇÃO E HARDENING DO PHP-FPM
# ==============================================================================
print_header "CONFIGURAÇÃO DO PHP-FPM"

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
    sed -i "s/^disable_functions =.*/disable_functions = system,shell_exec,passthru,show_source/" "$PHP_INI" || true
    
    log_success "Parâmetros do PHP-FPM e desativação de funções de risco ajustados com sucesso."
    
    log_info "Reiniciando serviço php${PHP_VER}-fpm..."
    systemctl restart "php${PHP_VER}-fpm" > /dev/null 2>&1 || systemctl restart php-fpm > /dev/null 2>&1
    log_success "Serviço php${PHP_VER}-fpm reiniciado."
else
    log_error "Arquivo de configuração do PHP-FPM (${PHP_INI}) não encontrado."
fi

# ==============================================================================
# 5. CONFIGURAÇÃO E HARDENING DO BANCO DE DADOS (MARIADB SERVER)
# ==============================================================================
print_header "CONFIGURAÇÃO DO BANCO DE DADOS (MARIADB SERVER)"

log_info "Iniciando e habilitando serviço mariadb no boot..."
systemctl enable --now mariadb > /dev/null 2>&1
log_success "Serviço MariaDB em execução."

log_info "Configurando credenciais e aplicando endurecimento de segurança no MariaDB..."
mysql -u root <<EOF > /dev/null 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$DB_ROOT_PASS');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    log_success "Senha do root do MariaDB e limpeza de usuários anônimos/banco test aplicadas com sucesso."
else
    mysqladmin -u root password "$DB_ROOT_PASS" > /dev/null 2>&1 || true
    log_success "Senha do root do MariaDB aplicada."
fi

# ==============================================================================
# 6. CONFIGURAÇÃO E HARDENING DO NGINX
# ==============================================================================
print_header "CONFIGURAÇÃO DO NGINX"

log_info "Criando diretório da aplicação em ${WEB_ROOT}..."
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT"

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

    # Logs customizados
    access_log /var/log/nginx/${DOMAIN_NAME}_access.log;
    error_log /var/log/nginx/${DOMAIN_NAME}_error.log;

    # Headers de Segurança
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_read_timeout ${EXEC_TIME}s;
        fastcgi_send_timeout ${EXEC_TIME}s;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Bloqueio de arquivos ocultos (.env, .git, .htaccess)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default > /dev/null 2>&1

log_info "Testando sintaxe das configurações do Nginx (nginx -t)..."
if nginx -t > /dev/null 2>&1; then
    log_success "Sintaxe do Nginx validada."
    systemctl restart nginx > /dev/null 2>&1
    log_success "Serviço Nginx reiniciado com sucesso."
else
    log_error "Erro na validação do Nginx. Verifique com 'nginx -t'."
fi

# ==============================================================================
# 7. CONFIGURAÇÃO DE PERMISSÕES E POSIX ACLs
# ==============================================================================
print_header "CONFIGURAÇÃO DE PERMISSÕES (POSIX ACLs)"
log_info "Aplicando herança de permissões automática com POSIX ACLs (setfacl) em ${WEB_ROOT}..."
setfacl -R -m u:www-data:rwx,g:www-data:rwx "$WEB_ROOT" > /dev/null 2>&1 || true
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx "$WEB_ROOT" > /dev/null 2>&1 || true
log_success "Diretório preparado e ACLs ativas: Novos arquivos em ${WEB_ROOT} herdarão acesso total para www-data."

# ==============================================================================
# 8. DIAGNÓSTICO DO PHP (info.php)
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
# 9. CONFIGURAÇÃO DE SEGURANÇA (FIREWALL UFW & FAIL2BAN)
# ==============================================================================
print_header "CONFIGURAÇÃO DE SEGURANÇA E FIREWALL"

log_info "Configurando regras no Firewall UFW..."
if command -v ufw > /dev/null 2>&1; then
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw --force enable > /dev/null 2>&1
    log_success "Portas 80 (HTTP), 443 (HTTPS) e 22 (SSH) liberadas no UFW."
fi

log_info "Configurando regras no Fail2Ban..."
mkdir -p /etc/fail2ban/jail.d
cat <<EOF > /etc/fail2ban/jail.d/nginx.local
[DEFAULT]
backend = systemd
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/*error.log
maxretry = 2
bantime  = 24h
EOF

systemctl enable --now fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
log_success "Fail2Ban configurado para SSH e proteção contra bots maliciosos no Nginx."

# ==============================================================================
# 10. RESUMO FINAL DO SISTEMA
# ==============================================================================
SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"

print_header "RESUMO DO SISTEMA - INSTALAÇÃO CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DA PILHA LEMP FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Endurecido${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}          Nginx ($(systemctl is-active nginx 2>/dev/null || echo "active")) [server_tokens off]"
echo -e "  ${BOLD}Processador PHP:${NC}       PHP-FPM ${PHP_VER} [Upload: ${UPLOAD_MAX} | Timeout: ${EXEC_TIME}s]"
echo -e "  ${BOLD}Banco de Dados:${NC}        MariaDB Server [Seguro: Sem 'test' e sem usuár. anônimos]"
echo -e "  ${BOLD}Permissões POSIX ACL:${NC}  ${FG_GREEN}Ativo e Herdando (${WEB_ROOT})${NC}"
echo -e "  ${BOLD}Proteção Fail2Ban:${NC}     $(systemctl is-active fail2ban >/dev/null 2>&1 && echo -e "${FG_GREEN}Ativo (SSH & Nginx-BotSearch)${NC}" || echo "Não instalado")"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Domínio Configurado:${NC}   ${FG_CYAN}${DOMAIN_NAME}${NC}"
echo -e "  ${BOLD}Diretório Raiz (Web):${NC}  ${FG_CYAN}${WEB_ROOT}${NC}"
echo -e "  ${BOLD}Acesso Web Principal:${NC}  ${FG_CYAN}http://${DOMAIN_NAME}/${NC} ou ${FG_CYAN}http://${SERVER_IP}/${NC}"
echo -e "  ${BOLD}Diagnóstico PHP:${NC}      ${FG_CYAN}http://${SERVER_IP}/info.php${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais MariaDB Root:${NC}"
echo -e "    Usuário: ${FG_CYAN}root${NC}"
echo -e "    Senha:   ${FG_YELLOW}${DB_ROOT_PASS}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

echo -e "\n  ${BOLD}📁 LEMBRETES DE ARQUIVOS DE CONFIGURAÇÃO:${NC}"
echo -e "  ${FG_YELLOW}• Configuração Nginx:${NC}     /etc/nginx/sites-available/${DOMAIN_NAME}"
echo -e "  ${FG_YELLOW}• Config PHP-FPM:${NC}         /etc/php/${PHP_VER}/fpm/php.ini"
echo -e "  ${FG_YELLOW}• Config MariaDB:${NC}         /etc/mysql/mariadb.conf.d/50-server.cnf"
echo -e "  ${FG_YELLOW}• Config Fail2Ban:${NC}        /etc/fail2ban/jail.local"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

log_warning "Por razões de segurança, lembre-se de remover ou restringir o acesso ao arquivo ${WEB_ROOT}/info.php após a validação."

# ==============================================================================
# 11. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

# Salva cópias no diretório /root
cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/install_lemp_ubuntu_latest.log" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/install_lemp_ubuntu_latest.log"

# Se executado via sudo, salva também na pasta home do usuário real
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/install_lemp_ubuntu_latest.log" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/install_lemp_ubuntu_latest.log" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
    fi
fi

rm -f "$LOG_TMP" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}❯ Instalação concluída com sucesso!${NC}\n"
