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
# Executar via URL
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh
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

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja instalar o phpMyAdmin? (s/N): ${NC}")" INSTALL_PHPMYADMIN
INSTALL_PHPMYADMIN=$(echo "$INSTALL_PHPMYADMIN" | tr '[:upper:]' '[:lower:]')

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja liberar portas HTTP (80) e HTTPS (443) no UFW Firewall? (s/N): ${NC}")" CONFIGURE_UFW
CONFIGURE_UFW=$(echo "$CONFIGURE_UFW" | tr '[:upper:]' '[:lower:]')

draw_separator

# ==========================================
# ATUALIZAÇÃO DO SISTEMA
# ==========================================
print_header "PREPARANDO REPOSITÓRIOS"

log_info "Atualizando a lista de pacotes do APT..."
if apt update -y > /dev/null 2>&1; then
    log_success "Lista de pacotes atualizada com sucesso."
else
    log_error "Falha ao atualizar repositórios do APT."
    exit 1
fi

log_info "Instalando dependências prévias (software-properties-common, curl, ca-certificates)..."
PRE_REQ_PACKAGES=("software-properties-common" "curl" "ca-certificates" "gnupg2" "lsb-release")
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
apt update -y > /dev/null 2>&1

PHP_PACKAGES=(
    "php8.3"
    "libapache2-mod-php8.3"
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

log_info "Instalando pacotes do PHP 8.3..."
PHP_INSTALLED_COUNT=0
for pkg in "${PHP_PACKAGES[@]}"; do
    if apt install -y "$pkg" > /dev/null 2>&1; then
        log_success "Pacote '$pkg' instalado com sucesso."
        ((PHP_INSTALLED_COUNT++))
    fi
done

if [ "$PHP_INSTALLED_COUNT" -eq 0 ]; then
    log_warning "Pacotes 'php8.3-*' não encontrados no repositório. Instalando versão padrão do repositório do sistema..."
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
if [ "$CONFIGURE_UFW" = "s" ] || [ "$CONFIGURE_UFW" = "sim" ]; then
    print_header "CONFIGURAÇÃO DE FIREWALL (UFW)"
    if command -v ufw > /dev/null 2>&1; then
        log_info "Adicionando regra 'Apache Full' (portas 80 e 443) no UFW..."
        ufw allow 'Apache Full' > /dev/null 2>&1
        log_success "Regras de porta HTTP/HTTPS liberadas no UFW."
    else
        log_warning "UFW não está instalado no sistema. Pulando regra de firewall."
    fi
fi

# ==========================================
# RESUMO FINAL DO SISTEMA
# ==========================================
SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_IP" ] && SERVER_IP="localhost"

print_header "RESUMO DO SISTEMA - INSTALAÇÃO CONCLUÍDA"

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DA PILHA LAMP FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Servidor Web:${NC}         Apache2 ($(systemctl is-active apache2))"
echo -e "  ${BOLD}Banco de Dados:${NC}       MariaDB Server ($(systemctl is-active mariadb))"
echo -e "  ${BOLD}Linguagem de Script:${NC}  PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "8.3")"
echo -e "  ${BOLD}Diretório Web Raiz:${NC}   /var/www/html/"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Acesso Web Principal:${NC}  http://${SERVER_IP}/"
echo -e "  ${BOLD}Diagnóstico PHP:${NC}      http://${SERVER_IP}/info.php"

if [ "$INSTALL_PHPMYADMIN" = "s" ] || [ "$INSTALL_PHPMYADMIN" = "sim" ]; then
    echo -e "  ${BOLD}Painel phpMyAdmin:${NC}    http://${SERVER_IP}/phpmyadmin"
fi

echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Credenciais MariaDB Root:${NC}"
echo -e "    Usuário: ${FG_CYAN}root${NC}"
echo -e "    Senha:   ${FG_YELLOW}${DB_ROOT_PASS}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

log_warning "Por razões de segurança, lembre-se de remover ou restringir o acesso ao arquivo /var/www/html/info.php após a validação."
echo -e ""
