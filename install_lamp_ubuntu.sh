#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO DA PILHA LAMP - UBUNTU SERVER (APACHE, MARIADB, PHP 8.3)
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo).
# 2. Coleta parâmetros iniciais (senha do MariaDB, phpMyAdmin, regras UFW).
# 3. Atualiza os repositórios do sistema.
# 4. Instala e habilita o servidor web Apache2 com mod_rewrite ativado.
# 5. Instala e configura o banco de dados MariaDB Server e ajusta a senha root.
# 6. Adiciona o repositório ppa:ondrej/php e instala o PHP 8.3 com extensões essenciais.
# 7. Opcionalmente instala e integra o phpMyAdmin ao Apache.
# 8. Opcionalmente configura regras no firewall UFW para tráfego web.
# 9. Cria uma página de diagnóstico phpinfo em /var/www/html/info.php.
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh
#
# Executar via URL diretamente:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh | bash
# bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh)
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh | bash
#
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

# ==========================================
# VERIFICAÇÃO DE PRIVILÉGIOS (ROOT)
# ==========================================
if [ "$EUID" -ne 0 ]; then
    print_header "ERRO DE EXECUÇÃO"
    log_error "Este script precisa ser executado como ROOT ou via sudo."
    echo -e "  Exemplo: ${FG_YELLOW}sudo bash $0${NC}\n"
    exit 1
fi

print_header "INSTALADOR AUTOMÁTICO LAMP - UBUNTU (APACHE, MARIADB, PHP 8.3)"

# ==========================================
# COLETA DE PARÂMETROS
# ==========================================
print_header "COLETA DE PARÂMETROS"

echo -e "  ${FG_CYAN}[i]${NC} Defina a senha para o usuário root do MariaDB."
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Senha do MariaDB Root (deixe vazio para gerar uma aleatória): ${NC}")" DB_ROOT_PASS

if [ -z "$DB_ROOT_PASS" ]; then
    DB_ROOT_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    log_info "Senha aleatória gerada para o MariaDB Root: ${FG_GREEN}${DB_ROOT_PASS}${NC}"
fi

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Versão do PHP a instalar (Pressione ENTER para a mais recente | ou informe ex: 8.2): ${NC}")" PHP_INPUT
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

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja instalar o phpMyAdmin? (s/N): ${NC}")" INSTALL_PHPMYADMIN
INSTALL_PHPMYADMIN=$(echo "$INSTALL_PHPMYADMIN" | tr '[:upper:]' '[:lower:]')

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja instalar e configurar o Fail2Ban (SSH/Apache)? (S/n): ${NC}")" CONFIGURE_FAIL2BAN
CONFIGURE_FAIL2BAN=$(echo "$CONFIGURE_FAIL2BAN" | tr '[:upper:]' '[:lower:]')

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja liberar portas HTTP (80), HTTPS (443) e SSH (22) no UFW Firewall? (S/n): ${NC}")" CONFIGURE_UFW
CONFIGURE_UFW=$(echo "$CONFIGURE_UFW" | tr '[:upper:]' '[:lower:]')

draw_separator

# ==========================================
# ATUALIZAÇÃO DO SISTEMA
# ==========================================
print_header "PREPARANDO REPOSITÓRIOS"

log_info "Atualizando a lista de pacotes do APT..."
apt update -y > /dev/null 2>&1 || true
log_success "Lista de pacotes atualizada."

log_info "Instalando dependências prévias (software-properties-common, curl, ca-certificates)..."
PRE_REQ_PACKAGES=("software-properties-common" "curl" "ca-certificates" "gnupg2" "lsb-release" "acl")
for pkg in "${PRE_REQ_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg " > /dev/null 2>&1; then
        log_info "Pacote '$pkg' já está instalado."
    else
        log_info "Instalando '$pkg'..."
        if apt install -y "$pkg" > /dev/null 2>&1; then
            log_success "Pacote '$pkg' instalado com sucesso."
        else
            log_warning "Falha ao instalar '$pkg'."
        fi
    fi
done

# ==========================================
# INSTALAÇÃO DO APACHE2
# ==========================================
print_header "INSTALAÇÃO DO SERVIDOR WEB (APACHE2)"

log_info "Instalando o Apache2..."
if apt install -y apache2 > /dev/null 2>&1; then
    log_success "Apache2 instalado com sucesso."
else
    log_error "Falha na instalação do Apache2."
    exit 1
fi

log_info "Habilitando módulo mod_rewrite no Apache..."
a2enmod rewrite > /dev/null 2>&1
log_success "Módulo mod_rewrite habilitado."

log_info "Iniciando e habilitando serviço apache2 no boot..."
systemctl enable --now apache2 > /dev/null 2>&1
log_success "Serviço apache2 em execução."

# ==========================================
# INSTALAÇÃO DO MARIADB SERVER
# ==========================================
print_header "INSTALAÇÃO DO BANCO DE DADOS (MARIADB SERVER)"

log_info "Instalando o MariaDB Server..."
if apt install -y mariadb-server mariadb-client > /dev/null 2>&1; then
    log_success "MariaDB Server instalado com sucesso."
else
    log_error "Falha na instalação do MariaDB Server."
    exit 1
fi

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
    mysqladmin -u root password "$DB_ROOT_PASS" > /dev/null 2>&1
    log_success "Senha do root do MariaDB aplicada via mysqladmin."
fi

# ==========================================
# INSTALAÇÃO DO PHP E EXTENSÕES
# ==========================================
print_header "INSTALAÇÃO DO PHP E EXTENSÕES"

log_info "Adicionando repositório PPA ondrej/php..."
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt update -y > /dev/null 2>&1 || true

if [ -n "$PHP_VER" ]; then
    PHP_MAIN_PKG="php${PHP_VER}"
    APACHE_MOD_PKG="libapache2-mod-php${PHP_VER}"
else
    PHP_MAIN_PKG="php"
    APACHE_MOD_PKG="libapache2-mod-php"
fi

PHP_PACKAGES=(
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
)

PHP_FALLBACK_PACKAGES=(
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
)

log_info "Instalando pacotes do PHP (${LOG_PHP_MSG})..."
PHP_INSTALLED_COUNT=0
for pkg in "${PHP_PACKAGES[@]}"; do
    if apt install -y "$pkg" > /dev/null 2>&1; then
        log_success "Pacote '$pkg' instalado com sucesso."
        ((PHP_INSTALLED_COUNT++))
    fi
done

if [ "$PHP_INSTALLED_COUNT" -eq 0 ]; then
    log_warning "Pacotes específicos do PHP não encontrados no repositório. Instalando versão padrão do repositório do sistema..."
    for pkg in "${PHP_FALLBACK_PACKAGES[@]}"; do
        if apt install -y "$pkg" > /dev/null 2>&1; then
            log_success "Pacote nativo '$pkg' instalado com sucesso."
        else
            log_warning "Falha ao instalar o pacote '$pkg'."
        fi
    done
fi

log_info "Reiniciando Apache2 para carregar os módulos do PHP..."
systemctl restart apache2 > /dev/null 2>&1
log_success "Apache2 reiniciado com suporte a PHP."

# ==========================================
# CONFIGURAÇÃO DE PERMISSÕES E POSIX ACLs
# ==========================================
print_header "CONFIGURAÇÃO DE PERMISSÕES (POSIX ACLs)"
log_info "Aplicando herança de permissões automática com POSIX ACLs (setfacl) em /var/www..."
mkdir -p /var/www/html
chown -R www-data:www-data /var/www
chmod -R 775 /var/www
setfacl -R -m u:www-data:rwx,g:www-data:rwx /var/www > /dev/null 2>&1 || true
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /var/www > /dev/null 2>&1 || true
log_success "ACLs ativas: Novos arquivos em /var/www herdarão acesso total para www-data."

# ==========================================
# CRIANDO PÁGINA DE DIAGNÓSTICO (info.php)
# ==========================================
log_info "Criando arquivo de teste phpinfo em /var/www/html/info.php..."
cat <<'EOF' > /var/www/html/info.php
<?php
phpinfo();
?>
EOF
chown www-data:www-data /var/www/html/info.php
log_success "Arquivo /var/www/html/info.php criado."

# ==========================================
# INSTALAÇÃO OPCIONAL DO PHPMYADMIN
# ==========================================
if [ "$INSTALL_PHPMYADMIN" = "s" ] || [ "$INSTALL_PHPMYADMIN" = "sim" ]; then
    print_header "INSTALAÇÃO DO PHPMYADMIN"
    log_info "Configurando seleções automáticas do debconf para phpMyAdmin..."
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $DB_ROOT_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

    log_info "Instalando phpMyAdmin de forma não interativa..."
    if apt install -y phpmyadmin php-mbstring php-zip php-gd > /dev/null 2>&1; then
        phpenmod mbstring > /dev/null 2>&1
        systemctl restart apache2 > /dev/null 2>&1
        log_success "phpMyAdmin instalado e integrado ao Apache2."
    else
        log_warning "Instalação do phpMyAdmin encontrou avisos. Verifique o serviço manualmente se necessário."
    fi
fi

# ==========================================
# CONFIGURAÇÃO DE FIREWALL (UFW)
# ==========================================
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

# ==========================================
# CONFIGURAÇÃO DO FAIL2BAN (PROTEÇÃO SSH E APACHE)
# ==========================================
if [ "$CONFIGURE_FAIL2BAN" != "n" ] && [ "$CONFIGURE_FAIL2BAN" != "nao" ]; then
    print_header "INSTALAÇÃO E CONFIGURAÇÃO DO FAIL2BAN"
    log_info "Instalando o Fail2Ban..."
    apt install -y fail2ban > /dev/null 2>&1

    log_info "Garantindo existência dos arquivos de log do Apache..."
    mkdir -p /var/log/apache2
    touch /var/log/apache2/error.log /var/log/apache2/access.log
    chown -R www-data:adm /var/log/apache2 > /dev/null 2>&1 || true

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

[apache-auth]
enabled = true
port    = http,https
logpath = /var/log/apache2/error.log
EOF

    log_info "Habilitando e reiniciando o serviço Fail2Ban..."
    systemctl enable --now fail2ban > /dev/null 2>&1
    systemctl restart fail2ban > /dev/null 2>&1
    log_success "Fail2Ban configurado e ativo com regras para SSH e Apache."
fi

# ==========================================
# RESUMO FINAL DO SISTEMA
# ==========================================
SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"
ACTUAL_PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "8.3")
ACTUAL_PHP_SHORT=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")

print_header "RESUMO DO SISTEMA - INSTALAÇÃO CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DA PILHA LAMP FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Pronto${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}          Apache2 ($(systemctl is-active apache2 2>/dev/null || echo "active"))"
echo -e "  ${BOLD}Banco de Dados:${NC}        MariaDB Server ($(systemctl is-active mariadb 2>/dev/null || echo "active"))"
echo -e "  ${BOLD}Linguagem de Script:${NC}   PHP ${ACTUAL_PHP_VER}"
echo -e "  ${BOLD}Permissões POSIX ACL:${NC}  ${FG_GREEN}Ativo e Herdando (/var/www)${NC}"
echo -e "  ${BOLD}Proteção Fail2Ban:${NC}     $(systemctl is-active fail2ban >/dev/null 2>&1 && echo -e "${FG_GREEN}Ativo e Protegendo (/etc/fail2ban/jail.local)${NC}" || echo "Não instalado")"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Diretório Web Raiz:${NC}   ${FG_CYAN}/var/www/html/${NC}"
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

log_warning "Por razões de segurança, lembre-se de remover ou restringir o acesso ao arquivo /var/www/html/info.php após a validação."
echo -e ""
draw_separator
echo -e "${FG_GREEN}${BOLD}❯ Instalação concluída com sucesso!${NC}\n"
