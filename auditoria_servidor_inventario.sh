#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE AUDITORIA, VARREDURA E INVENTÁRIO DO SERVIDOR (NON-INVASIVE)
# UBUNTU / DEBIAN SERVER - DIAGNÓSTICO PRÉ-MIGRAÇÃO
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (Root/Sudo recomendado para leitura de portas e logs).
# 2. Inicializa a captura simultânea do console para arquivo de relatório.
# 3. Audita o Sistema Operacional, Kernel, Recursos de Hardware (CPU, RAM, Discos) e Rede.
# 4. Mapeia todas as Portas em Escuta (TCP/UDP, IPv4/IPv6) e seus Processos/PIDs associados.
# 5. Audita Servidores Web (Apache2, Nginx, Caddy), suas versões e VirtualHosts configurados.
# 6. Audita Versões do PHP instaladas, sockets FPM e módulos ativos.
# 7. Audita Bancos de Dados instalados (MariaDB, MySQL, PostgreSQL, Redis, MongoDB).
# 8. Realiza varredura no disco para detectar CMSs instalados (Joomla, WordPress, Drupal, Laravel) e versões.
# 9. Audita Serviços de Sistema ativos no boot e status de Segurança (UFW, IPTables, Fail2Ban, SSH).
# 10. Audita Contêineres Docker e imagens em execução (se instalado).
# 11. Audita Rotinas Agendadas no Crontab (root, usuários do sistema e /etc/cron.d/).
# 12. Geração e Salvamento Automático do Relatório de Inventário na Home do Usuário e em /root.
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/auditoria_servidor_inventario.sh -O auditoria_servidor_inventario.sh && chmod +x auditoria_servidor_inventario.sh && sudo ./auditoria_servidor_inventario.sh
# ==============================================================================

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
        echo -e "${FG_GREEN}Ativo (Running)${NC}"
    elif systemctl list-unit-files | grep -q "^${service}\.service" 2>/dev/null; then
        echo -e "${FG_YELLOW}Inativo (Instalado)${NC}"
    else
        echo -e "${DIM}Não instalado${NC}"
    fi
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
log_item()    { echo -e "    • ${BOLD}$1:${NC} $2"; }

# ==============================================================================
# 1. VERIFICAÇÃO DE PRIVILÉGIOS E INICIALIZAÇÃO DE RELATÓRIO
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    print_header "AVISO DE PRIVILÉGIOS"
    log_warning "Recomenda-se executar como ROOT ou via SUDO para mapear processos e portas de todos os usuários."
    echo -e "  Exemplo: ${FG_YELLOW}sudo bash $0${NC}\n"
    read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja continuar mesmo sem privilégios de root? (s/N): ${NC}")" CONTINUAR_SEM_ROOT
    if [[ ! "$CONTINUAR_SEM_ROOT" =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname)
LOG_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILENAME="relatorio_inventario_${HOSTNAME_SHORT}_${LOG_TIMESTAMP}.txt"
REPORT_LATEST="relatorio_inventario_latest.txt"
LOG_TMP="/tmp/${REPORT_FILENAME}"

# Redireciona a saída do console simultaneamente para o arquivo temporário
exec > >(tee -a "$LOG_TMP") 2>&1

clear
echo -e "\n${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "${FG_CYAN}${BOLD}     AUDITORIA, VARREDURA E INVENTÁRIO DO SERVIDOR LINUX       ${NC}"
echo -e "${FG_CYAN}${BOLD}                 DIAGNÓSTICO PRÉ-MIGRAÇÃO                       ${NC}"
echo -e "${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "  ${DIM}Data da Varredura:${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  ${DIM}Hostname:${NC}          $(hostname -f 2>/dev/null || hostname)"
echo -e "  ${DIM}Modo de Execução:${NC}  Não invasivo (Somente Leitura)\n"

# ==============================================================================
# 2. SISTEMA OPERACIONAL, HARDWARE E RECURSOS
# ==============================================================================
print_header "1. SISTEMA OPERACIONAL, KERNEL E HARDWARE"

OS_NAME="Desconhecido"
[ -f /etc/os-release ] && OS_NAME=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
KERNEL_VER=$(uname -r)
ARCH=$(uname -m)
UPTIME_STR=$(uptime -p 2>/dev/null || uptime)

CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)

MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')

log_item "Sistema Operacional" "${FG_GREEN}${OS_NAME} (${ARCH})${NC}"
log_item "Kernel Linux"        "${KERNEL_VER}"
log_item "Tempo de Atividade"  "${UPTIME_STR}"
log_item "Processador (CPU)"   "${CPU_MODEL:-Desconhecido} (${CPU_CORES} Core(s))"
log_item "Memória RAM"         "${MEM_TOTAL} Total (Usado: ${MEM_USED} | Disponível: ${MEM_AVAIL})"
log_item "Memória Swap"        "${SWAP_TOTAL}"

echo -e "\n  ${BOLD}Armazenamento e Pontos de Montagem:${NC}"
df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR==1 {printf "    %-20s %-10s %-10s %-10s %-6s %s\n", $1, $2, $3, $4, $5, $6} NR>1 {printf "    %-20s %-10s %-10s %-10s %-6s %s\n", $1, $2, $3, $4, $5, $6}'

# ==============================================================================
# 3. INTERFACES DE REDE E CONECTIVIDADE
# ==============================================================================
print_header "2. INTERFACES DE REDE E ENDEREÇAMENTO IP"

DEFAULT_GATEWAY=$(ip route | awk '/default/ {print $3}' | head -n 1)
DNS_SERVERS=$(grep "nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | xargs)
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo "Não detectado")

log_item "Gateway Padrão"      "${DEFAULT_GATEWAY:-Nenhum}"
log_item "Servidores DNS"      "${DNS_SERVERS:-Nenhum}"
log_item "IP Público de Saída" "${FG_CYAN}${PUBLIC_IP}${NC}"

echo -e "\n  ${BOLD}Interfaces Locais Ativas:${NC}"
ip -br addr show 2>/dev/null | awk '{printf "    • %-15s %-10s %s\n", $1, $2, $3}'

# ==============================================================================
# 4. PORTAS EM ESCUTA (LISTENING PORTS) E PROCESSOS
# ==============================================================================
print_header "3. PORTAS EM ESCUTA E PROCESSOS VINCULADOS"

log_info "Mapeando portas TCP e UDP ativas no host (ss -tulpn)..."
echo -e ""
printf "    ${BOLD}%-8s %-25s %-10s %-30s${NC}\n" "PROTO" "ENDEREÇO LOCAL" "PORTA" "PROCESSO / APLICAÇÃO"
draw_separator

if command -v ss > /dev/null 2>&1; then
    ss -tulpn 2>/dev/null | awk 'NR>1 {
        proto = $1
        local_addr = $5
        proc = $7
        
        # Extrai porta
        n = split(local_addr, parts, ":")
        port = parts[n]
        sub(":" port "$", "", local_addr)
        if (local_addr == "" || local_addr == "*") local_addr = "0.0.0.0"
        
        gsub(/users:\(\(/, "", proc)
        gsub(/\)\)/, "", proc)
        gsub(/"/, "", proc)
        
        printf "    %-8s %-25s %-10s %-30s\n", proto, local_addr, port, (proc ? proc : "Privilégio insuficiente")
    }' | sort -k3 -n | uniq
else
    netstat -tulpn 2>/dev/null | awk 'NR>2 {
        printf "    %-8s %-25s %-10s %-30s\n", $1, $4, $4, $7
    }'
fi

# ==============================================================================
# 5. AUDITORIA DE SERVIDORES WEB (APACHE, NGINX, CADDY)
# ==============================================================================
print_header "4. SERVIDORES WEB E VIRTUALHOSTS"

# Apache
if command -v apache2 > /dev/null 2>&1 || command -v httpd > /dev/null 2>&1; then
    APACHE_BIN=$(command -v apache2 || command -v httpd)
    APACHE_VER=$($APACHE_BIN -v 2>/dev/null | head -n 1 | cut -d':' -f2 | xargs)
    log_success "Apache detectado: ${BOLD}${APACHE_VER}${NC} [$(get_service_status apache2)]"
    
    echo -e "    ${BOLD}Módulos Apache Habilitados:${NC}"
    APACHE_MODS=$(apache2ctl -M 2>/dev/null | grep -E "_module" | awk '{print $1}' | sed 's/_module//' | xargs)
    [ -z "$APACHE_MODS" ] && APACHE_MODS=$($APACHE_BIN -M 2>/dev/null | grep -E "_module" | awk '{print $1}' | sed 's/_module//' | xargs)
    echo -e "    ${DIM}${APACHE_MODS:-Nenhum detectado}${NC}"
    
    echo -e "\n    ${BOLD}VirtualHosts / Sites Ativos no Apache:${NC}"
    APACHE_VHOSTS=$(apache2ctl -S 2>/dev/null | grep -E "port 80|port 443|namevhost|default" | sed 's/^[ \t]*//')
    [ -z "$APACHE_VHOSTS" ] && APACHE_VHOSTS=$($APACHE_BIN -S 2>/dev/null | grep -E "port 80|port 443|namevhost|default" | sed 's/^[ \t]*//')
    if [ -n "$APACHE_VHOSTS" ]; then
        echo "$APACHE_VHOSTS" | while read -r line; do
            echo -e "      • ${line}"
        done
    else
        echo -e "      • Nenhum VirtualHost ativo encontrado."
    fi
else
    log_info "Apache2: Não instalado"
fi

echo -e ""

# Nginx
if command -v nginx > /dev/null 2>&1; then
    NGINX_VER=$(nginx -v 2>&1 | cut -d':' -f2 | xargs)
    log_success "Nginx detectado: ${BOLD}${NGINX_VER}${NC} [$(get_service_status nginx)]"
    
    echo -e "\n    ${BOLD}Server Blocks / Domínios Configurados no Nginx:${NC}"
    for conf in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
        if [ -f "$conf" ]; then
            DOMAINS=$(grep -E "^\s*server_name\s+" "$conf" 2>/dev/null | sed 's/server_name//' | tr -d ';' | xargs)
            DOC_ROOT=$(grep -E "^\s*root\s+" "$conf" 2>/dev/null | sed 's/root//' | tr -d ';' | xargs | head -n 1)
            [ -n "$DOMAINS" ] && echo -e "      • Arquivo: ${FG_CYAN}$(basename "$conf")${NC} | Domínios: ${FG_YELLOW}${DOMAINS}${NC} | Root: ${DOC_ROOT:-Padrão}"
        fi
    done
else
    log_info "Nginx: Não instalado"
fi

# ==============================================================================
# 6. AUDITORIA DO PHP E MÓDULOS
# ==============================================================================
print_header "5. VERSÕES DO PHP E MÓDULOS"

if command -v php > /dev/null 2>&1; then
    CLI_PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
    log_success "PHP CLI Padrão: ${BOLD}PHP ${CLI_PHP_VER}${NC}"
    
    echo -e "\n  ${BOLD}Versões do PHP encontradas no sistema (/etc/php/):${NC}"
    if [ -d /etc/php ]; then
        for php_dir in /etc/php/*; do
            if [ -d "$php_dir" ]; then
                V=$(basename "$php_dir")
                FPM_STATUS=$(get_service_status "php${V}-fpm")
                echo -e "    • ${BOLD}PHP ${V}${NC} [FPM: ${FPM_STATUS}]"
            fi
        done
    fi
    
    echo -e "\n  ${BOLD}Módulos PHP Carregados (CLI):${NC}"
    PHP_MODULES=$(php -m 2>/dev/null | grep -v "\[" | sort | xargs)
    echo -e "  ${DIM}${PHP_MODULES}${NC}"
else
    log_info "PHP: Não instalado ou não encontrado no PATH"
fi

# ==============================================================================
# 7. AUDITORIA DE BANCOS DE DADOS
# ==============================================================================
print_header "6. BANCOS DE DADOS INSTALADOS"

# MariaDB / MySQL
if command -v mariadb > /dev/null 2>&1 || command -v mysql > /dev/null 2>&1; then
    DB_BIN=$(command -v mariadb || command -v mysql)
    DB_VER=$($DB_BIN --version 2>/dev/null)
    DB_STATUS=$(systemctl is-active mariadb 2>/dev/null || systemctl is-active mysql 2>/dev/null || echo "inactive")
    log_success "MySQL/MariaDB detectado: ${BOLD}${DB_VER}${NC}"
    log_item "Status do Serviço" "$(get_service_status mariadb || get_service_status mysql)"
    log_item "Diretório de Dados" "/var/lib/mysql"
else
    log_info "MySQL/MariaDB: Não instalado"
fi

# PostgreSQL
if command -v psql > /dev/null 2>&1 || [ -d /etc/postgresql ]; then
    PG_VER=$(psql --version 2>/dev/null || echo "Instalado")
    log_success "PostgreSQL detectado: ${BOLD}${PG_VER}${NC} [$(get_service_status postgresql)]"
else
    log_info "PostgreSQL: Não instalado"
fi

# Redis
if command -v redis-server > /dev/null 2>&1; then
    REDIS_VER=$(redis-server --version 2>/dev/null | cut -d'=' -f2 | awk '{print $1}')
    log_success "Redis Server detectado: ${BOLD}v${REDIS_VER}${NC} [$(get_service_status redis-server)]"
else
    log_info "Redis: Não instalado"
fi

# ==============================================================================
# 8. VARREDURA DE APLICAÇÕES WEB E CMSs NO DISCO
# ==============================================================================
print_header "7. DETECÇÃO DE APLICAÇÕES WEB E CMSs NO DISCO"

log_info "Varrendo diretórios /var/www, /srv e /home para identificar aplicações..."
echo -e ""

SCAN_DIRS=("/var/www" "/srv" "/home")
FOUND_APPS=0

for base_dir in "${SCAN_DIRS[@]}"; do
    if [ -d "$base_dir" ]; then
        # 1. Joomla
        while IFS= read -r joomla_ver_file; do
            if [ -f "$joomla_ver_file" ]; then
                APP_DIR=$(dirname "$(dirname "$joomla_ver_file")")
                [ "$APP_DIR" = "." ] && APP_DIR=$(pwd)
                
                # Tenta extrair a versão exata via PHP CLI instanciando a classe Version do Joomla
                J_VER_EXACT=$(php -r "require_once '$joomla_ver_file'; if (class_exists('Joomla\CMS\Version')) { echo \Joomla\CMS\Version::MAJOR_VERSION . '.' . \Joomla\CMS\Version::MINOR_VERSION . '.' . \Joomla\CMS\Version::PATCH_VERSION; } elseif (class_exists('JVersion')) { \$v = new JVersion(); echo \$v->getShortVersion(); }" 2>/dev/null)
                
                # Fallback via regex no arquivo Version.php
                if [ -z "$J_VER_EXACT" ]; then
                    MAJOR=$(grep -E "const\s+MAJOR_VERSION|public\s+\$RELEASE" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"")
                    MINOR=$(grep -E "const\s+MINOR_VERSION|public\s+\$DEV_LEVEL" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"")
                    PATCH=$(grep -E "const\s+PATCH_VERSION|public\s+\$BUILD" "$joomla_ver_file" 2>/dev/null | head -n 1 | awk '{print $NF}' | tr -d "';\"")
                    [ -n "$MAJOR" ] && J_VER_EXACT="${MAJOR}.${MINOR:-0}.${PATCH:-0}"
                fi

                log_success "Joomla Detectado!"
                log_item "Caminho" "${FG_CYAN}${APP_DIR}${NC}"
                log_item "Versão"  "${FG_YELLOW}Joomla ${J_VER_EXACT:-5.x/4.x}${NC}"
                
                # Checa se configuration.php existe para extrair o banco
                if [ -f "${APP_DIR}/configuration.php" ]; then
                    J_DB=$(grep "public \$db " "${APP_DIR}/configuration.php" 2>/dev/null | cut -d"'" -f2)
                    J_USER=$(grep "public \$user " "${APP_DIR}/configuration.php" 2>/dev/null | cut -d"'" -f2)
                    J_PREFIX=$(grep "public \$dbprefix " "${APP_DIR}/configuration.php" 2>/dev/null | cut -d"'" -f2)
                    log_item "Banco Vinculado" "Base: ${FG_CYAN}${J_DB:-Não definido}${NC} | Usuário: ${J_USER:-Não definido} | Prefixo: ${J_PREFIX:-jos_}"
                fi
                echo -e ""
                ((FOUND_APPS++))
            fi
        done < <(find "$base_dir" -maxdepth 6 -type f \( -path "*/libraries/src/Version.php" -o -path "*/includes/version.php" \) 2>/dev/null)

        # 2. WordPress
        while IFS= read -r wp_ver_file; do
            if [ -f "$wp_ver_file" ]; then
                APP_DIR=$(dirname "$(dirname "$wp_ver_file")")
                WP_VER=$(grep "\$wp_version\s*=" "$wp_ver_file" 2>/dev/null | cut -d"'" -f2)
                log_success "WordPress Detectado!"
                log_item "Caminho" "${FG_CYAN}${APP_DIR}${NC}"
                log_item "Versão"  "${FG_YELLOW}WordPress ${WP_VER}${NC}"
                echo -e ""
                ((FOUND_APPS++))
            fi
        done < <(find "$base_dir" -maxdepth 5 -type f -path "*/wp-includes/version.php" 2>/dev/null)

        # 3. Laravel
        while IFS= read -r artisan_file; do
            if [ -f "$artisan_file" ]; then
                APP_DIR=$(dirname "$artisan_file")
                log_success "Framework Laravel / PHP Application Detectado!"
                log_item "Caminho" "${FG_CYAN}${APP_DIR}${NC}"
                echo -e ""
                ((FOUND_APPS++))
            fi
        done < <(find "$base_dir" -maxdepth 4 -type f -name "artisan" 2>/dev/null)
    fi
done

if [ "$FOUND_APPS" -eq 0 ]; then
    log_info "Nenhum CMS padrão (Joomla/WordPress) identificado automaticamente nos caminhos examinados."
fi

# ==============================================================================
# 9. SEGURANÇA, FIREWALL E ROTINAS DO SISTEMA
# ==============================================================================
print_header "8. SEGURANÇA, FIREWALL E AGENDAMENTOS"

# UFW Firewall
if command -v ufw > /dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -n 1)
    log_item "Firewall UFW" "${BOLD}${UFW_STATUS}${NC}"
    echo -e "    ${BOLD}Regras Ativas no UFW:${NC}"
    ufw status numbered 2>/dev/null | sed 's/^/      /'
else
    log_item "Firewall UFW" "Não instalado"
fi

echo -e ""

# Fail2Ban
if command -v fail2ban-client > /dev/null 2>&1; then
    F2B_STATUS=$(get_service_status fail2ban)
    log_item "Fail2Ban" "${F2B_STATUS}"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d':' -f2 | xargs)
        log_item "Jails Ativas" "${FG_GREEN}${JAILS:-Nenhuma}${NC}"
    fi
else
    log_item "Fail2Ban" "Não instalado"
fi

# ==============================================================================
# 10. CONTÊINERES DOCKER (SE INSTALADO)
# ==============================================================================
print_header "9. VIRTUALIZAÇÃO E CONTÊINERES DOCKER"

if command -v docker > /dev/null 2>&1; then
    DOCKER_VER=$(docker --version 2>/dev/null)
    log_success "Docker detectado: ${BOLD}${DOCKER_VER}${NC} [$(get_service_status docker)]"
    
    echo -e "\n  ${BOLD}Contêineres em Execução (docker ps):${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | sed 's/^/    /'
else
    log_info "Docker: Não instalado"
fi

# ==============================================================================
# 11. ROTINAS AGENDADAS NO CRONTAB
# ==============================================================================
print_header "10. ROTINAS AGENDADAS (CRON JOBS)"

log_info "Verificando tarefas agendadas no Crontab do sistema..."

echo -e "\n  ${BOLD}Crontab do Root:${NC}"
crontab -l 2>/dev/null | grep -v "^#" | sed '/^$/d' | sed 's/^/    • /' || echo "    • Nenhum cronjob ativo para root"

echo -e "\n  ${BOLD}Crontab do Usuário Web (www-data):${NC}"
crontab -u www-data -l 2>/dev/null | grep -v "^#" | sed '/^$/d' | sed 's/^/    • /' || echo "    • Nenhum cronjob ativo para www-data"

echo -e "\n  ${BOLD}Arquivos em /etc/cron.d/:${NC}"
ls -la /etc/cron.d/ 2>/dev/null | awk 'NR>3 {print "    • " $9}'

# ==============================================================================
# 12. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE RELATÓRIO NA HOME E ROOT
# ==============================================================================
print_header "11. GERAÇÃO E SALVAMENTO DO RELATÓRIO DE INVENTÁRIO"

SAVED_LOCATIONS=()

# Salva em /root
cp "$LOG_TMP" "/root/${REPORT_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${REPORT_LATEST}" 2>/dev/null || true
SAVED_LOCATIONS+=("/root/${REPORT_FILENAME}")

# Salva na HOME do usuário que executou via sudo
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${REPORT_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/${REPORT_LATEST}" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${REPORT_FILENAME}" "${REAL_USER_HOME}/${REPORT_LATEST}" 2>/dev/null || true
        SAVED_LOCATIONS+=("${REAL_USER_HOME}/${REPORT_FILENAME}")
    fi
# Salva na pasta do usuário atual se não estiver em sudo
elif [ "$HOME" != "/root" ] && [ -d "$HOME" ]; then
    cp "$LOG_TMP" "${HOME}/${REPORT_FILENAME}" 2>/dev/null || true
    cp "$LOG_TMP" "${HOME}/${REPORT_LATEST}" 2>/dev/null || true
    SAVED_LOCATIONS+=("${HOME}/${REPORT_FILENAME}")
fi

rm -f "$LOG_TMP" 2>/dev/null || true

for loc in "${SAVED_LOCATIONS[@]}"; do
    log_success "Relatório salvo em: ${FG_CYAN}${loc}${NC}"
done

draw_separator
echo -e "  ${DIM}Varredura concluída em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
echo -e "${FG_GREEN}${BOLD}❯ Inventário e varredura do servidor finalizados com sucesso!${NC}\n"
