#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO AUTOMÁTICO E SEGURO - UBUNTU SERVER
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo).
# 2. Atualiza os espelhos do APT e aplica patches de segurança do sistema.
# 3. Instala pacotes vitais (curl, QEMU Guest Agent, Open VM Tools, ncdu, fastfetch, htop, tmux, fail2ban, etc).
# 4. Ajusta o fuso horário (America/Sao_Paulo) e sincronização de horário via NTP (systemd-timesyncd).
# 5. Endurece o SSH (Hardening): Desabilita login de Root (opcional), senhas em branco e define timeout de sessão ociosa.
# 6. Configura a jaula do Fail2Ban para proteção contra ataques de força bruta no SSH.
# 7. Ativa atualizações automáticas de segurança (unattended-upgrades).
# 8. Oferece criação opcional de usuário 'administrador' (sudo) e 'geset'.
# 9. Permite criar grupos customizados (TI, DEV, etc.) parametrizando o Visudo dinamicamente.
# 10. Insere regras de borda nativas no Firewall UFW (SSH e Zabbix Agent).
# ==============================================================================
# visualizar o script antes de executar:
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh
#
# Executar via URL diretamente:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh | bash
# bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh)
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh | bash
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

log_info() {
    echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"
}

log_success() {
    echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"
}

log_warning() {
    echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"
}

log_error() {
    echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"
}

print_alert_box() {
    local msg="$1"
    echo -e ""
    echo -e "  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}"
    echo -e ""
}

# ==============================================================================
# INÍCIO DO SCRIPT
# ==============================================================================

clear

# Verificar se o script está rodando como root
if [ "$EUID" -ne 0 ]; then 
  log_error "Por favor, execute como root (sudo)"
  exit 1
fi

echo -e "\n${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "${FG_CYAN}${BOLD}       SYSTEM MANAGER - PÓS-INSTALAÇÃO DO UBUNTU SERVER         ${NC}"
echo -e "${FG_CYAN}${BOLD}================================================================${NC}"

# ==============================================================================
# BLOCO DE INTERATIVIDADE E COLETAS DE PARÂMETROS
# ==============================================================================
LOG_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILENAME="pos_install_server_${LOG_TIMESTAMP}.log"
LOG_TMP="/tmp/${LOG_FILENAME}"

# Redireciona a saída do script para o terminal e grava no log simultaneamente
exec > >(tee -a "$LOG_TMP") 2>&1

print_header "COLETA DE PARÂMETROS"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja atualizar o sistema (apt update e upgrade)? (s/N): ${NC}")" EXEC_UPDATE
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja permitir o login de ROOT via SSH? (s/N): ${NC}")" PERMITIR_ROOT_SSH
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'administrador' (sudo)? (s/N): ${NC}")" CRIAR_ADMIN
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'geset'? (s/N): ${NC}")" CRIAR_GESET
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar um grupo restrito (ex: TI, DEV) e um novo usuário vinculado a ele? (s/N): ${NC}")" CRIAR_USUARIO

if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do GRUPO que deseja criar (ex: TI, DEV, SUPORTE): ${NC}")" NOME_GRUPO
  while [ -z "$NOME_GRUPO" ]; do
    read -p "$(echo -e "  ${FG_RED}${ARROW} O nome do grupo não pode ser vazio. Digite novamente: ${NC}")" NOME_GRUPO
  done

  read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do novo usuário para o grupo ${BOLD}$NOME_GRUPO${NC}${FG_YELLOW}: ${NC}")" NOVO_USER
  while [ -z "$NOVO_USER" ]; do
    read -p "$(echo -e "  ${FG_RED}${ARROW} O nome do usuário não pode ser vazio. Digite novamente: ${NC}")" NOVO_USER
  done
fi

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja configurar regras de Firewall (UFW)? (s/N): ${NC}")" EXEC_UFW

draw_separator
log_info "Configurações coletadas. Iniciando os procedimentos..."

# ==============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# ==============================================================================
if [[ "$EXEC_UPDATE" =~ ^[Ss]$ ]]; then
  print_header "ATUALIZAÇÃO DO SISTEMA"
  print_alert_box "O sistema será atualizado antes de prosseguirmos com as configurações."

  log_info "Atualizando a lista de pacotes (apt update)..."
  apt update -y

  log_info "Aplicando atualizações de segurança e sistema (apt upgrade)..."
  apt upgrade -y
  log_success "Sistema atualizado."
else
  log_info "Atualização do sistema pulada."
fi

# ==============================================================================
# 2. INSTALAÇÃO DE PACOTES E UTILITÁRIOS
# ==============================================================================
print_header "INSTALAÇÃO DE UTILITÁRIOS"
print_alert_box "Pacotes do sistema (qemu-guest-agent, open-vm-tools, fail2ban, htop, tmux, etc) serão instalados agora."

PACOTES=(curl qemu-guest-agent open-vm-tools ncdu fastfetch locales htop tmux fail2ban dnsutils net-tools unattended-upgrades)
PACOTES_INSTALADOS=()
for pacote in "${PACOTES[@]}"; do
  log_info "Instalando o pacote: $pacote..."
  if apt install -y "$pacote" > /dev/null 2>&1; then
    log_success "Pacote $pacote instalado com sucesso."
    PACOTES_INSTALADOS+=("$pacote")
    if [[ "$pacote" == "qemu-guest-agent" || "$pacote" == "open-vm-tools" || "$pacote" == "fail2ban" ]]; then
      systemctl enable --now "$pacote" > /dev/null 2>&1
    fi
  else
    log_warning "Não foi possível instalar o pacote: $pacote (pode não estar disponível)."
  fi
done

# ==============================================================================
# 3. CONFIGURAÇÃO DE LOCALES (UTF-8), TECLADO E FUSO HORÁRIO (NTP)
# ==============================================================================
print_header "LOCALES (UTF-8), TECLADO E FUSO HORÁRIO"

log_info "Configurando idioma padrão do sistema em Inglês (en_US.UTF-8) com suporte a pt_BR.UTF-8..."
sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 > /dev/null 2>&1
log_success "Idioma padrão do servidor configurado para en_US.UTF-8 (Inglês) com locales pt_BR gerados."

log_info "Configurando fuso horário (America/Sao_Paulo) e sincronização NTP..."
timedatectl set-timezone America/Sao_Paulo > /dev/null 2>&1 || true
systemctl enable --now systemd-timesyncd > /dev/null 2>&1 || true
log_success "Fuso horário ajustado para America/Sao_Paulo (NTP Ativo)."

log_info "Configurando layouts de teclado (ABNT2 Padrão + US-International com Acentos)..."
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="br,us"
XKBVARIANT=",intl"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

udevadm trigger --subsystem-match=input --action=change > /dev/null 2>&1 || true
setupcon --force > /dev/null 2>&1 || true
log_success "Teclado configurado: ABNT2 (Padrão Ativo) + US-International (Alterna com Alt+Shift)."

# ==============================================================================
# 4. CONFIGURAÇÃO DO SSH (HARDENING & SEGURANÇA)
# ==============================================================================
print_header "CONFIGURAÇÃO DO SSH (HARDENING)"

VALOR_SSH="no"
if [[ "$PERMITIR_ROOT_SSH" =~ ^[Ss]$ ]]; then
  VALOR_SSH="yes"
  log_warning "Alerta de Segurança: Configurando PermitRootLogin para 'yes' no SSH..."
else
  VALOR_SSH="no"
  log_success "Segurança Aplicada: Desabilitando o login de Root via SSH (PermitRootLogin no)."
fi

if grep -qE "^#?PermitRootLogin" /etc/ssh/sshd_config; then
  sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin $VALOR_SSH/" /etc/ssh/sshd_config
else
  echo "PermitRootLogin $VALOR_SSH" >> /etc/ssh/sshd_config
fi

# Hardening Adicional de SSH (Desabilita senhas vazias e aplica timeout de ociosidade)
sed -i '/^#\?PermitEmptyPasswords/d' /etc/ssh/sshd_config
echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config

sed -i '/^#\?ClientAliveInterval/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config

sed -i '/^#\?ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
log_success "Hardening no SSH concluído (Sem senhas em branco e timeout de ociosidade de 10 min)."

# ==============================================================================
# 5. SEGURANÇA ADICIONAL (FAIL2BAN & UNATTENDED-UPGRADES)
# ==============================================================================
print_header "PROTEÇÃO FAIL2BAN E ATUALIZAÇÕES AUTOMÁTICAS"

if command -v fail2ban-client >/dev/null 2>&1; then
  log_info "Configurando jaula do Fail2Ban para proteção do SSH..."
  cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
maxretry = 5
findtime = 600
bantime = 3600
EOF
  systemctl restart fail2ban > /dev/null 2>&1
  log_success "Fail2Ban ativado (Bloqueia IPs após 5 tentativas incorretas no SSH)."
fi

if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
  log_info "Garantindo atualizações automáticas de segurança ativas..."
  sed -i 's/APT::Periodic::Update-Package-Lists "0";/APT::Periodic::Update-Package-Lists "1";/' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || true
  sed -i 's/APT::Periodic::Unattended-Upgrade "0";/APT::Periodic::Unattended-Upgrade "1";/' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || true
  log_success "Atualizações de segurança automáticas (unattended-upgrades) validadas."
fi

# ==============================================================================
# 6. VERIFICAÇÃO E CRIAÇÃO DOS USUÁRIOS 'ADMINISTRADOR' E 'GESET'
# ==============================================================================
print_header "GERENCIAMENTO DE USUÁRIOS PADRÃO"
log_info "Verificando usuários padrão (administrador e geset)..."

if [[ "$CRIAR_ADMIN" =~ ^[Ss]$ ]]; then
  if ! id "administrador" &>/dev/null; then
    log_warning "Usuário 'administrador' não encontrado. Criando com acesso Sudo..."
    useradd -m -s /bin/bash -G sudo administrador
    echo -e "  ${FG_YELLOW}${ARROW} Defina a senha para o usuário 'administrador':${NC}"
    passwd administrador
  else
    log_success "Usuário 'administrador' já existe."
  fi
else
  log_info "Criação do usuário 'administrador' pulada."
fi

if [[ "$CRIAR_GESET" =~ ^[Ss]$ ]]; then
  if ! id "geset" &>/dev/null; then
    log_warning "Usuário 'geset' não encontrado. Criando..."
    useradd -m -s /bin/bash geset
    echo -e "  ${FG_YELLOW}${ARROW} Defina a senha para o usuário 'geset':${NC}"
    passwd geset
  else
    log_success "Usuário 'geset' já existe."
  fi
else
  log_info "Criação do usuário 'geset' pulada."
fi

# ==============================================================================
# 7. CRIAÇÃO DO GRUPO PARAMETRIZADO, USUÁRIO EXCLUSIVO E REGRAS DO VISUDO
# ==============================================================================
if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  print_header "GRUPO CUSTOMIZADO E VISUDO"
  
  NOME_GRUPO=$(echo "$NOME_GRUPO" | tr '[:lower:]' '[:upper:]')

  log_info "Criando/Verificando o grupo customizado '$NOME_GRUPO'..."
  getent group "$NOME_GRUPO" > /dev/null || groupadd "$NOME_GRUPO"

  log_info "Criando o usuário '$NOVO_USER'..."
  if id "$NOVO_USER" &>/dev/null; then
    log_warning "O usuário '$NOVO_USER' já existe. Vinculando ao grupo $NOME_GRUPO..."
  else
    useradd -m -s /bin/bash "$NOVO_USER"
    echo -e "  ${FG_YELLOW}${ARROW} Defina a senha para o usuário '$NOVO_USER':${NC}"
    passwd "$NOVO_USER"
  fi

  usermod -aG "$NOME_GRUPO" "$NOVO_USER"
  log_success "Usuário '$NOVO_USER' configurado e adicionado ao grupo $NOME_GRUPO."

  log_info "Auditando existência do usuário 'geset' para regras do Sudoers..."
  if id "geset" &>/dev/null; then
    REGRA_GESET=", !/usr/bin/passwd geset"
    log_success "Usuário geset localizado. Amarra de proteção adicionada ao Visudo."
  else
    REGRA_GESET=""
    log_warning "Usuário geset não existe neste servidor. Removendo amarra pendente para evitar falha no Visudo."
  fi

  log_info "Aplicando restrições de segurança dinâmicas para o grupo $NOME_GRUPO no visudo..."
  SUDOERS_TMP=$(mktemp)
  
  cat << EOF > "$SUDOERS_TMP"
# Grupo $NOME_GRUPO com restricao de alterar senha do root e geset (se aplicavel) e leitura de shadow
%$NOME_GRUPO ALL=(ALL:ALL) ALL, !/usr/bin/passwd root${REGRA_GESET}, !/usr/bin/passwd "", !/usr/sbin/visudo, !/usr/sbin/usermod, !/usr/bin/gpasswd, !/usr/bin/su, !/usr/bin/sudo -i, !/usr/bin/sudo -s, !/usr/bin/sudo /bin/bash, !/usr/bin/sudo /bin/sh, !/usr/bin/sudoedit /etc/sudoers*, !/usr/bin/sudoedit /etc/shadow, !/usr/bin/nano /etc/shadow, !/usr/bin/vi /etc/shadow, !/usr/bin/nano /etc/sudoers*, !/usr/bin/vi /etc/sudoers*, !/usr/bin/cat /etc/shadow, !/usr/bin/head /etc/shadow, !/usr/bin/tail /etc/shadow, !/usr/bin/grep * /etc/shadow, !/usr/bin/less /etc/shadow, !/usr/bin/awk * /etc/shadow, !/usr/bin/cp /etc/shadow *, !/usr/bin/chmod * *shadow*, !/usr/bin/chown * *shadow*, !/usr/bin/cat *shadow*
EOF

  ARQUIVO_FINAL_SUDO=$(echo "grupo_${NOME_GRUPO}" | tr '[:upper:]' '[:lower:]')

  if visudo -cf "$SUDOERS_TMP" > /dev/null 2>&1; then
    mv "$SUDOERS_TMP" "/etc/sudoers.d/$ARQUIVO_FINAL_SUDO"
    chmod 0440 "/etc/sudoers.d/$ARQUIVO_FINAL_SUDO"
    log_success "Regras do visudo para o grupo $NOME_GRUPO aplicadas com sucesso!"
  else
    log_error "Erro crítico: Sintaxe das regras do visudo inválida. As restrições NÃO foram aplicadas."
    rm -f "$SUDOERS_TMP"
  fi
fi

# ==============================================================================
# 8. CONFIGURAR REGRAS DE FIREWALL (UFW)
# ==============================================================================
if [[ "$EXEC_UFW" =~ ^[Ss]$ ]]; then
  print_header "CONFIGURAÇÃO DE FIREWALL (UFW)"
  if command -v ufw >/dev/null 2>&1; then
    log_info "Configurando regras de firewall no UFW..."
    log_info "Liberando porta 22/tcp (SSH)..."
    ufw allow 22/tcp comment 'Acesso SSH Remoto' > /dev/null 2>&1
    log_info "Liberando porta 10050/tcp (Zabbix Agent)..."
    ufw allow 10050/tcp comment 'Zabbix Agent Port' > /dev/null 2>&1
    log_success "Regras do UFW configuradas com sucesso (Portas liberadas: 22/tcp [SSH] e 10050/tcp [Zabbix Agent])."
  else
    log_warning "UFW não encontrado. Instalação e parametrização pulada."
  fi
else
  log_info "Configuração de Firewall (UFW) pulada."
fi

# ==============================================================================
# 9. RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

KEYBOARD_STATUS="Não configurado"
if [ -f /etc/default/keyboard ]; then
  if grep -q 'XKBLAYOUT="br,us"' /etc/default/keyboard 2>/dev/null; then
    KEYBOARD_STATUS="ABNT2 + US-International (Alterna com Alt+Shift)"
  else
    LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    KEYBOARD_STATUS="${LAYOUT:-Padrao}"
  fi
fi

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")

echo -e "  ${FG_GREEN}${BOLD}✔ PÓS-INSTALAÇÃO DO UBUNTU SERVER FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Endurecido${NC}"
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-curl, qemu-guest-agent, open-vm-tools, ncdu, fastfetch, locales, htop, tmux, fail2ban, dnsutils, net-tools, unattended-upgrades}${NC}"
echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}en_US.UTF-8 (Padrão Inglês) / pt_BR.UTF-8${NC}"
echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
echo -e "  ${BOLD}Layout Ativo:${NC}          ${FG_GREEN}ABNT2 (br)${NC}"
echo -e "  ${BOLD}Fuso Horário:${NC}          ${FG_GREEN}America/Sao_Paulo (NTP Ativo)${NC}"
echo -e "  ${BOLD}QEMU Guest Agent:${NC}      $(get_service_status qemu-guest-agent)"
echo -e "  ${BOLD}Open VM Tools:${NC}         $(get_service_status open-vm-tools)"
echo -e "  ${BOLD}Fail2Ban (Brute-Force):${NC}$(get_service_status fail2ban)"
echo -e "  ${BOLD}Segurança SSH:${NC}         $(grep -qs -i "^PermitRootLogin[[:space:]]\+yes" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null && echo -e "${FG_YELLOW}Root Login Permitido${NC}" || echo -e "${FG_GREEN}Root Login Desabilitado (Hardened)${NC}")"
if command -v ufw >/dev/null 2>&1; then
  echo -e "  ${BOLD}Firewall UFW:${NC}          $(ufw status 2>/dev/null | grep -q "active" && echo -e "${FG_GREEN}Ativo${NC}" || echo -e "${FG_YELLOW}Regras prontas (Inativo)${NC}")"
fi
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

if [[ "$CRIAR_ADMIN" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Administrador:${NC}  ${FG_CYAN}administrador${NC} (Sudo Ativo)"
fi
if [[ "$CRIAR_GESET" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Geset:${NC}          ${FG_CYAN}geset${NC}"
fi
if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Customizado:${NC}    ${FG_CYAN}${NOVO_USER}${NC} (Grupo: ${NOME_GRUPO})"
  echo -e "  ${BOLD}Regras no Visudo:${NC}       /etc/sudoers.d/${ARQUIVO_FINAL_SUDO}"
fi
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 10. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

# Salva cópias no diretório /root
cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/pos_install_server_latest.log" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/pos_install_server_latest.log"

# Se executado via sudo, salva também na pasta home do usuário real
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
  REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  if [ -d "$REAL_USER_HOME" ]; then
    cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
    cp "$LOG_TMP" "${REAL_USER_HOME}/pos_install_server_latest.log" 2>/dev/null || true
    chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/pos_install_server_latest.log" 2>/dev/null || true
    log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
  fi
fi

rm -f "$LOG_TMP" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
