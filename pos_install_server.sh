#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO - UBUNTU SERVER
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo).
# 2. Atualiza os espelhos do APT e aplica patches de segurança do sistema.
# 3. Instala pacotes vitais (curl, QEMU Guest Agent, Open VM Tools, ncdu, fastfetch).
# 4. Endurece o SSH: Desabilita por padrão o Root Login (PermitRootLogin no).
# 5. Oferece criação opcional de usuário 'administrador' integrado ao grupo 'sudo'.
# 6. Audita a existência do usuário 'geset' antes de aplicar amarras no Sudoers.
# 7. Permite criar grupos customizados (TI, DEV, etc.) parametrizando o Visudo dinamicamente.
# 8. Insere regras de borda nativas no Firewall UFW (SSH e Zabbix Agent) sem ativá-lo.
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh
#
# Executar via URL
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh | bash
#
# ==============================================================================
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
print_header "COLETA DE PARÂMETROS"

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja atualizar o sistema (apt update e upgrade)? (s/n): ${NC}")" EXEC_UPDATE

# Sugestão de Melhoria 1: SSH por padrão desabilitado.
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja configurar o SSH? (s/n): ${NC}")" EXEC_SSH
if [[ "$EXEC_SSH" =~ ^[Ss]$ ]]; then
  read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja desabilitar o login de ROOT via SSH? (s/n): ${NC}")" DESABILITAR_ROOT
fi

# Pergunta sobre criação de usuários padrão
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'administrador' (sudo)? (s/n): ${NC}")" CRIAR_ADMIN
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'geset'? (s/n): ${NC}")" CRIAR_GESET

# Alteração: Escolha dinâmica de Grupo Customizado para restrição via Visudo
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar um grupo restrito (ex: TI, DEV) e um novo usuário vinculado a ele? (s/n): ${NC}")" CRIAR_USUARIO

if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  # Escolha do nome do grupo customizado
  read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do GRUPO que deseja criar (ex: TI, DEV, SUPORTE): ${NC}")" NOME_GRUPO
  while [ -z "$NOME_GRUPO" ]; do
    read -p "$(echo -e "  ${FG_RED}${ARROW} O nome do grupo não pode ser vazio. Digite novamente: ${NC}")" NOME_GRUPO
  done

  # Coleta do nome do usuário exclusivo deste grupo
  read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do novo usuário para o grupo ${BOLD}$NOME_GRUPO${NC}${FG_YELLOW}: ${NC}")" NOVO_USER
  while [ -z "$NOVO_USER" ]; do
    read -p "$(echo -e "  ${FG_RED}${ARROW} O nome do usuário não pode ser vazio. Digite novamente: ${NC}")" NOVO_USER
  done
fi

read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja configurar regras de Firewall (UFW)? (s/n): ${NC}")" EXEC_UFW

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
# 2. INSTALAÇÃO DE PACOTES E UTILLITÁRIOS
# ==============================================================================
print_header "INSTALAÇÃO DE UTILITÁRIOS"
print_alert_box "Pacotes obrigatórios (qemu-guest-agent, open-vm-tools, etc) serão instalados agora."

PACOTES=(curl qemu-guest-agent open-vm-tools ncdu fastfetch locales)
for pacote in "${PACOTES[@]}"; do
  log_info "Instalando o pacote: $pacote..."
  if apt install -y "$pacote" > /dev/null 2>&1; then
    log_success "Pacote $pacote instalado com sucesso."
    if [[ "$pacote" == "qemu-guest-agent" || "$pacote" == "open-vm-tools" ]]; then
      systemctl enable --now "$pacote" > /dev/null 2>&1
    fi
  else
    log_warning "Não foi possível instalar o pacote: $pacote (pode não estar disponível)."
  fi
done

# ==============================================================================
# CONFIGURAÇÃO DE LOCALES (UTF-8) E TECLADO (US-INTL + ABNT2)
# ==============================================================================
print_header "CONFIGURAÇÃO DE LOCALES (UTF-8) E TECLADO"

log_info "Configurando suporte completo a UTF-8 (en_US.UTF-8 e pt_BR.UTF-8)..."
sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8 > /dev/null 2>&1
log_success "Locales UTF-8 gerados com sucesso (Evita acentuação quebrada no Nano/Terminal)."

log_info "Configurando layouts de teclado (US-International com Acentos + ABNT2)..."
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,br"
XKBVARIANT="intl,"
XKBOPTIONS="grp:alt_space_toggle"
BACKSPACE="guess"
EOF

udevadm trigger --subsystem-match=input --action=change > /dev/null 2>&1 || true
setupcon --force > /dev/null 2>&1 || true
log_success "Teclado configurado: US-International (para acentos em teclado americano) + ABNT2 (Alterna com Alt+Space)."

# ==============================================================================
# 3. CONFIGURAÇÃO DO SSH (Aumento de segurança padrão)
# ==============================================================================
if [[ "$EXEC_SSH" =~ ^[Ss]$ ]]; then
  print_header "CONFIGURAÇÃO DO SSH"
  # Modificado: Se o usuário não disser Explicitamente "Sim", o script blinda a config para "no"
  if [[ "$DESABILITAR_ROOT" =~ ^[Nn]$ ]]; then
    log_warning "Alerta de Segurança: Configurando PermitRootLogin para 'yes' no SSH..."
    sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  else
    log_success "Segurança Aplicada: Desabilitando explicitamente o login de Root via SSH (Padrão)."
    sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  fi
  systemctl restart sshd
  log_info "Serviço SSH reiniciado."
else
  log_info "Configuração do SSH pulada."
fi

# ==============================================================================
# VERIFICAÇÃO E CRIAÇÃO DOS USUÁRIOS 'ADMINISTRADOR' E 'GESET'
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
# 4. CRIAÇÃO DO GRUPO PARAMETRIZADO, USUÁRIO EXCLUSIVO E REGRAS DO VISUDO
# ==============================================================================
if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  print_header "GRUPO CUSTOMIZADO E VISUDO"
  
  # Higieniza a string transformando o nome do grupo em letras maiúsculas para o padrão Unix
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

  # Garante que o usuário pertença ao grupo customizado
  usermod -aG "$NOME_GRUPO" "$NOVO_USER"
  log_success "Usuário '$NOVO_USER' configurado e adicionado ao grupo $NOME_GRUPO."

  # Sugestão de Melhoria 2: Validação se o usuário 'geset' existe para evitar erros de sintaxe no Sudoers
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
  
  # Criação do payload customizado baseado na string capturada no início do script
  cat << EOF > "$SUDOERS_TMP"
# Grupo $NOME_GRUPO com restricao de alterar senha do root e geset (se aplicavel) e leitura de shadow
%$NOME_GRUPO ALL=(ALL:ALL) ALL, !/usr/bin/passwd root${REGRA_GESET}, !/usr/bin/passwd "", !/usr/sbin/visudo, !/usr/sbin/usermod, !/usr/bin/gpasswd, !/usr/bin/su, !/usr/bin/sudo -i, !/usr/bin/sudo -s, !/usr/bin/sudo /bin/bash, !/usr/bin/sudo /bin/sh, !/usr/bin/sudoedit /etc/sudoers*, !/usr/bin/sudoedit /etc/shadow, !/usr/bin/nano /etc/shadow, !/usr/bin/vi /etc/shadow, !/usr/bin/nano /etc/sudoers*, !/usr/bin/vi /etc/sudoers*, !/usr/bin/cat /etc/shadow, !/usr/bin/head /etc/shadow, !/usr/bin/tail /etc/shadow, !/usr/bin/grep * /etc/shadow, !/usr/bin/less /etc/shadow, !/usr/bin/awk * /etc/shadow, !/usr/bin/cp /etc/shadow *, !/usr/bin/chmod * *shadow*, !/usr/bin/chown * *shadow*, !/usr/bin/cat *shadow*
EOF

  # Nome do arquivo de saída baseado no grupo gerado (ex: /etc/sudoers.d/grupo_ti)
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
# 5. CONFIGURAR REGRAS DE FIREWALL (UFW)
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
# 6. RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

KEYBOARD_STATUS="Não configurado"
if [ -f /etc/default/keyboard ]; then
  if grep -q 'XKBLAYOUT="us,br"' /etc/default/keyboard 2>/dev/null; then
    KEYBOARD_STATUS="US-International (Acentos) + ABNT2 (Alt+Space)"
  else
    LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    KEYBOARD_STATUS="${LAYOUT:-Padrao}"
  fi
fi

echo -e "  ${FG_GREEN}${BOLD}✔ PÓS-INSTALAÇÃO DO UBUNTU SERVER FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Servidor:${NC}    ${FG_GREEN}Operacional e Endurecido${NC}"
echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}pt_BR.UTF-8 / en_US.UTF-8 (Gerados)${NC}"
echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
echo -e "  ${BOLD}QEMU Guest Agent:${NC}      $(get_service_status qemu-guest-agent)"
echo -e "  ${BOLD}Open VM Tools:${NC}         $(get_service_status open-vm-tools)"
echo -e "  ${BOLD}Segurança SSH:${NC}         $(grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null && echo -e "${FG_GREEN}Root Login Desabilitado${NC}" || echo -e "${FG_YELLOW}Root Login Permitido${NC}")"
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
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"

