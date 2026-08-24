#!/bin/bash
# ------------------------------------------------
# Version: 1.9
# ------------------------------------------------
VERSION="1.9"
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO AUTOMÁTICO E SEGURO - UBUNTU SERVER
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo) e captura logs de auditoria em /root e na Home.
# 2. Atualiza os espelhos do APT e aplica patches de segurança do sistema (opcional).
# 3. Instala utilitários vitais (curl, vim, qemu-guest-agent, open-vm-tools, ncdu, btop, htop, tmux, fail2ban, dnsutils, net-tools, unattended-upgrades).
# 4. Ajusta locales (en_US/pt_BR UTF-8), fuso horário (America/Sao_Paulo + NTP) e layout de teclado (ABNT2 + US-Intl).
# 5. Aplica proteção de memória compartilhada em RAM (/dev/shm) montada com 'noexec,nosuid,nodev' no /etc/fstab contra botnets/webshells.
# 6. Configura aliases de produtividade e segurança no Shell (ll='ls -alFh', rm, cp, mv, df, free, ports, myip, update, clean, reload).
# 7. Endurece o SSH (Hardening): Desabilita login de Root (opcional), impede senhas em branco e aplica timeout de ociosidade de 10 min.
# 8. Configura a jaula do Fail2Ban (força bruta SSH) e ativa atualizações automáticas de segurança (unattended-upgrades).
# 9. Oferece criação opcional dos usuários padrão 'administrador' (sudo) e 'geset' (sudo).
# 10. Permite criar grupo customizado (TI, DEV) e novo usuário com restrições dinâmicas no Visudo (bloqueio de senha root/geset e shadow).
# 11. Configura e ativa o Firewall UFW Dual-Stack (IPv4/IPv6) liberando portas SSH (22/tcp) e Zabbix Agent (10050/tcp).
# 12. Configura e personaliza o editor Vim com tema Sonokai, Airline e plugins com suporte multi-usuário (/root, /etc/skel, /home).
# 13. Instala o Banner dinâmico de Boas-Vindas no login (/etc/profile.d/motd_banner.sh) com Hostname, Sistema, Kernel, IP, Uptime, RAM e Disco.
# 14. Exibe o Resumo da Instalação com auditoria completa de status, pacotes, serviços e grava os logs em /root e na Home.
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh -O pos_install_server.sh && chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
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

log_skipped() {
    echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"
}

print_alert_box() {
    local msg="$1"
    echo -e ""
    echo -e "  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}"
    echo -e ""
}

garantir_home() {
    local usuario="$1"
    if id "$usuario" &>/dev/null; then
        local home_dir
        home_dir=$(getent passwd "$usuario" | cut -d: -f6)
        if [ -n "$home_dir" ] && [ ! -d "$home_dir" ]; then
            log_warning "Diretório home '$home_dir' do usuário '$usuario' não existia. Criando..."
            mkhomedir_helper "$usuario" 2>/dev/null || {
                mkdir -p "$home_dir"
                cp -r /etc/skel/. "$home_dir/" 2>/dev/null || true
                chown -R "$usuario:$usuario" "$home_dir"
            }
            log_success "Diretório home '$home_dir' criado com sucesso para '$usuario'."
        fi
    fi
}

# ==============================================================================
# INÍCIO DO SCRIPT
# ==============================================================================

clear

# Verificar se o script está rodando como root
if [ "$(id -u)" -ne 0 ]; then 
  log_error "Por favor, execute como root (sudo)"
  exit 1
fi

echo -e "\n${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "${FG_CYAN}${BOLD}           PÓS-INSTALAÇÃO DO UBUNTU SERVER                      ${NC}"
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
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja habilitar o Firewall UFW? (S/n): ${NC}")" HABILITAR_UFW
HABILITAR_UFW=${HABILITAR_UFW:-S}
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'administrador' (sudo)? (s/N): ${NC}")" CRIAR_ADMIN
read -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'geset' (sudo)? (s/N): ${NC}")" CRIAR_GESET
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

draw_separator
log_info "Configurações coletadas. Iniciando os procedimentos..."

# ==============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# ==============================================================================
if [[ "$EXEC_UPDATE" =~ ^[Ss]$ ]]; then
  print_header "ATUALIZAÇÃO DO SISTEMA"
  print_alert_box "O sistema será atualizado antes de prosseguirmos com as configurações."

  log_info "Atualizando a lista de pacotes (apt-get update)..."
  apt-get update -y

  log_info "Aplicando atualizações de segurança e sistema (apt-get upgrade)..."
  apt-get upgrade -y
  log_success "Sistema atualizado."
else
  log_skipped "Atualização do sistema pulada."
fi

# ==============================================================================
# 2. INSTALAÇÃO DE PACOTES E UTILITÁRIOS
# ==============================================================================
print_header "INSTALAÇÃO DE UTILITÁRIOS"
print_alert_box "Pacotes do sistema (qemu-guest-agent, open-vm-tools, fail2ban, htop, tmux, etc) serão instalados agora."

log_info "Garantindo repositório 'universe' habilitado e atualizando lista do APT..."
apt-get install -y software-properties-common > /dev/null 2>&1 || true
add-apt-repository -y universe > /dev/null 2>&1 || true
apt-get update -y > /dev/null 2>&1

# Detecta a plataforma de virtualização (KVM/Proxmox, VMware, WSL, Físico)
VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "none")

# Lista base de utilitários
PACOTES=(curl ncdu btop locales htop tmux fail2ban dnsutils net-tools unattended-upgrades ufw vim)

# Instala apenas o agente de VM compatível com o hipervisor em execução
if [[ "$VIRT_TYPE" =~ ^(kvm|qemu|bochs)$ ]]; then
  PACOTES+=(qemu-guest-agent)
elif [[ "$VIRT_TYPE" == "vmware" ]]; then
  PACOTES+=(open-vm-tools)
fi

PACOTES_INSTALADOS=()
for pacote in "${PACOTES[@]}"; do
  log_info "Instalando o pacote: $pacote..."
  if apt-get install -y "$pacote" > /dev/null 2>&1; then
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

log_info "Configurando proteção de memória compartilhada em RAM (/dev/shm noexec,nosuid,nodev)..."
if ! grep -qs "/dev/shm" /etc/fstab; then
  echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
  mount -o remount /dev/shm > /dev/null 2>&1 || true
  log_success "Proteção de memória RAM /dev/shm (noexec) aplicada com sucesso no /etc/fstab."
else
  log_success "Proteção de memória RAM /dev/shm (noexec) já ativa no /etc/fstab."
fi

# ==============================================================================
# 4. CONFIGURAÇÃO DE ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)
# ==============================================================================
print_header "ALIASES DO SHELL (PRODUTIVIDADE E SEGURANÇA)"

log_info "Configurando aliases de produtividade e segurança no Shell (ll, rm, cp, mv, df, free, ports, myip, update, clean)..."
for bashrc in /root/.bashrc /etc/skel/.bashrc /home/*/.bashrc; do
  if [ -f "$bashrc" ]; then
    if grep -q "alias ll=" "$bashrc"; then
      sed -i "s/alias ll=.*/alias ll='ls -alFh'/" "$bashrc"
    elif grep -q "#alias ll=" "$bashrc"; then
      sed -i "s/#alias ll=.*/alias ll='ls -alFh'/" "$bashrc"
    else
      echo "alias ll='ls -alFh'" >> "$bashrc"
    fi
    if grep -q "alias rm=" "$bashrc"; then
      sed -i "s/alias rm=.*/alias rm='rm -I'/" "$bashrc"
    else
      echo "alias rm='rm -I'" >> "$bashrc"
    fi
    grep -q "alias cp=" "$bashrc" || echo "alias cp='cp -i'" >> "$bashrc"
    grep -q "alias mv=" "$bashrc" || echo "alias mv='mv -i'" >> "$bashrc"
    grep -q "alias df=" "$bashrc" || echo "alias df='df -h'" >> "$bashrc"
    grep -q "alias free=" "$bashrc" || echo "alias free='free -h'" >> "$bashrc"
    grep -q "alias ports=" "$bashrc" || echo "alias ports='sudo ss -tulanp'" >> "$bashrc"
    grep -q "alias myip=" "$bashrc" || echo "alias myip='curl -s ifconfig.me; echo'" >> "$bashrc"
    grep -q "alias \.\.=" "$bashrc" || echo "alias ..='cd ..'" >> "$bashrc"
    grep -q "alias \.\.\.=" "$bashrc" || echo "alias ...='cd ../..'" >> "$bashrc"
    grep -q "alias update=" "$bashrc" || echo "alias update='sudo apt-get update && sudo apt-get upgrade -y'" >> "$bashrc"
    grep -q "alias clean=" "$bashrc" || echo "alias clean='sudo apt-get autoremove -y && sudo apt-get autoclean'" >> "$bashrc"
    grep -q "alias reload=" "$bashrc" || echo "alias reload='source ~/.bashrc'" >> "$bashrc"
  fi
done
log_success "Aliases de produtividade e segurança configurados em todos os perfis .bashrc."

# ==============================================================================
# 5. CONFIGURAÇÃO DO SSH (HARDENING & SEGURANÇA)
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
# 6. SEGURANÇA ADICIONAL (FAIL2BAN & UNATTENDED-UPGRADES)
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
# 7. VERIFICAÇÃO E CRIAÇÃO DOS USUÁRIOS 'ADMINISTRADOR' E 'GESET'
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
  garantir_home "administrador"
else
  log_skipped "Criação do usuário 'administrador' pulada."
fi

if [[ "$CRIAR_GESET" =~ ^[Ss]$ ]]; then
  if ! id "geset" &>/dev/null; then
    log_warning "Usuário 'geset' não encontrado. Criando com acesso Sudo..."
    useradd -m -s /bin/bash -G sudo geset
    echo -e "  ${FG_YELLOW}${ARROW} Defina a senha para o usuário 'geset':${NC}"
    passwd geset
  else
    log_success "Usuário 'geset' já existe."
  fi
  garantir_home "geset"
else
  log_skipped "Criação do usuário 'geset' pulada."
fi

# ==============================================================================
# 8. CRIAÇÃO DO GRUPO PARAMETRIZADO, USUÁRIO EXCLUSIVO E REGRAS DO VISUDO
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
  garantir_home "$NOVO_USER"
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
    log_error "Erro crítico: Sintaxe das regras do visudo inválida. As restrições NÃO foram applied."
    rm -f "$SUDOERS_TMP"
  fi
fi

# ==============================================================================
# 9. CONFIGURAÇÃO DE FIREWALL (UFW)
# ==============================================================================
print_header "CONFIGURAÇÃO DE FIREWALL (UFW)"
if [[ "$HABILITAR_UFW" =~ ^[Ss]$ ]]; then
  if command -v ufw >/dev/null 2>&1; then
    log_info "Configurando regras de firewall no UFW..."
    log_info "Liberando porta 22/tcp (SSH)..."
    ufw allow 22/tcp comment 'Acesso SSH Remoto' > /dev/null 2>&1
    log_info "Liberando porta 10050/tcp (Zabbix Agent)..."
    ufw allow 10050/tcp comment 'Zabbix Agent Port' > /dev/null 2>&1
    log_info "Garantindo suporte a IPv6 no Firewall UFW..."
    sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw 2>/dev/null || true
    log_info "Ativando o Firewall UFW..."
    ufw --force enable > /dev/null 2>&1
    log_success "Firewall UFW ativado e configurado (Dual-Stack IPv4/IPv6, Portas liberadas: 22/tcp [SSH] e 10050/tcp [Zabbix Agent])."
  else
    log_warning "UFW não encontrado no sistema."
  fi
else
  log_skipped "Configuração do Firewall UFW pulada pelo usuário."
fi

# ==============================================================================
# 10. CONFIGURAÇÃO DO EDITOR VIM E PLUGINS
# ==============================================================================
print_header "CONFIGURAÇÃO DO EDITOR VIM (PLUGINS & TEMA SONOKAI)"

log_info "Configurando o editor Vim com tema Sonokai e Airline..."
mkdir -p /root/.vim/autoload /root/.vim/plugged /etc/skel/.vim/autoload /etc/skel/.vim/plugged

if [ ! -f /root/.vim/autoload/plug.vim ]; then
  log_info "Baixando o gerenciador de plugins 'vim-plug'..."
  curl -fLo /root/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim > /dev/null 2>&1 || true
fi

cat << 'EOF' > /root/.vimrc
" Seção de Plugins (vim-plug) """""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

Plug 'sainnhe/sonokai'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'
Plug 'sheerun/vim-polyglot'

call plug#end()

" Global Sets """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax on            " Enable syntax highlight
set nu               " Enable line numbers
set tabstop=4        " Show existing tab with 4 spaces width
set softtabstop=4    " Show existing tab with 4 spaces width
set shiftwidth=4     " When indenting with '>', use 4 spaces width
set expandtab        " On pressing tab, insert 4 spaces
set smarttab         " insert tabs on the start of a line according to shiftwidth
set smartindent      " Automatically inserts one extra level of indentation in some cases
set hidden           " Hides the current buffer when a new file is openned
set incsearch        " Incremental search
set ignorecase       " Ingore case in search
set smartcase        " Consider case if there is a upper case character
set scrolloff=8      " Minimum number of lines to keep above and below the cursor
set colorcolumn=100  " Draws a line at the given line to keep aware of the line size
set signcolumn=yes   " Add a column on the left. Useful for linting
set cmdheight=2      " Give more space for displaying messages
set updatetime=100   " Time in miliseconds to consider the changes
set encoding=utf-8   " The encoding should be utf-8 to activate the font icons
set nobackup         " No backup files
set nowritebackup    " No backup files
set splitright       " Create the vertical splits to the right
set splitbelow       " Create the horizontal splits below
set autoread         " Update vim after file update from outside
set mouse=a          " Enable mouse support
filetype on          " Detect and set the filetype option and trigger the FileType Event
filetype plugin on   " Load the plugin file for the file type, if any
filetype indent on   " Load the indent file for the file type, if any

" Themes """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

let g:sonokai_style = 'andromeda'
let g:sonokai_enable_italic = 1
let g:sonokai_disable_italic_comment = 0
let g:sonokai_diagnostic_line_highlight = 1
let g:sonokai_current_word = 'bold'
colorscheme sonokai

if (has("nvim"))
    highlight Normal guibg=NONE ctermbg=NONE
    highlight EndOfBuffer guibg=NONE ctermbg=NONE
endif

" AirLine """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline_theme = 'sonokai'
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
EOF

if command -v vim >/dev/null 2>&1 && [ -f /root/.vim/autoload/plug.vim ]; then
  log_info "Instalando plugins do Vim via vim-plug..."
  vim -u NONE -N -e -s -c "source /root/.vimrc" -c "PlugInstall" -c "qa!" > /dev/null 2>&1 || true
fi

# Replica a configuração do Vim para o /etc/skel e para todos os usuários em /home
cp /root/.vimrc /etc/skel/.vimrc 2>/dev/null || true
cp -r /root/.vim /etc/skel/ 2>/dev/null || true

for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    user_name=$(basename "$user_home")
    cp /root/.vimrc "$user_home/.vimrc" 2>/dev/null || true
    cp -r /root/.vim "$user_home/" 2>/dev/null || true
    chown -R "$user_name:$user_name" "$user_home/.vimrc" "$user_home/.vim" 2>/dev/null || true
  fi
done

log_success "Editor Vim configurado com plugins (Sonokai/Airline) em /root, /etc/skel e /home."

# ==============================================================================
# 11. BANNER DINÂMICO DE BOAS-VINDAS NO LOGIN (/etc/profile.d/motd_banner.sh)
# ==============================================================================
print_header "BANNER DE BOAS-VINDAS NO LOGIN"
log_info "Configurando banner de boas-vindas dinâmico em /etc/profile.d/motd_banner.sh..."

cat << 'EOF' > /etc/profile.d/motd_banner.sh
#!/bin/bash
# ==============================================================================
# Banner Dinâmico de Boas-Vindas e Diagnóstico do Servidor
# Exibido automaticamente em sessões interativas de shell (SSH / Console)
# ==============================================================================
if [ -n "$PS1" ]; then
  HOSTNAME=$(hostname 2>/dev/null || uname -n)
  SISTEMA=$(lsb_release -ds 2>/dev/null || grep -oP 'PRETTY_NAME="\K[^"]+' /etc/os-release 2>/dev/null || echo "Linux")
  KERNEL=$(uname -r)
  UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "N/A")
  RAM_USO=$(free -h 2>/dev/null | awk '/^Mem:/ {print "Usado: " $3 " / Total: " $2 " (Livre: " $7 ")"}')
  SWAP_USO=$(free -h 2>/dev/null | awk '/^Swap:/ { if ($2 == "0B" || $2 == "0" || $2 == "") print "Desativada (0B)"; else print "Usado: " $3 " / Total: " $2 " (Livre: " $4 ")" }')

  echo -e "\033[1;36m================================================================\033[0m"
  echo -e "  \033[1;32m📌 VOCÊ CONECTOU EM:\033[0m"
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Hostname:" "${HOSTNAME}"
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m \033[2m(Kernel %s)\033[0m\n" "Sistema:" "${SISTEMA}" "${KERNEL}"
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Uptime:" "${UPTIME}"
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Memória RAM:" "${RAM_USO}"
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Memória SWAP:" "${SWAP_USO:-Desativada (0B)}"

  # Partições / Discos Físicos Montados
  DISCOS_ENCONTRADOS=0
  while read -r mountpoint used total free perc; do
    if [ -n "$mountpoint" ]; then
      DISCOS_ENCONTRADOS=1
      lbl="Disco (${mountpoint}):"
      printf "     \033[1m%-18s\033[0m \033[36mUsado: %s / Total: %s (Livre: %s | %s)\033[0m\n" "$lbl" "$used" "$total" "$free" "$perc"
    fi
  done < <(df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 -x rootfs 2>/dev/null | awk 'NR>1 && ($1 ~ /^\/dev/ || $1 ~ /:/) && $6 !~ /^\/boot/ {print $6, $3, $2, $4, $5}')

  if [ "$DISCOS_ENCONTRADOS" -eq 0 ]; then
    ROOT_DF=$(df -h / 2>/dev/null | awk 'NR==2 {print "Usado: " $3 " / Total: " $2 " (Livre: " $4 " | " $5 ")"}')
    printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Disco (/):" "${ROOT_DF}"
  fi

  # Interfaces de Rede e Endereços IPv4 (por último, abaixo dos discos)
  IPS_ENCONTRADOS=0
  while read -r iface ip_addr; do
    if [ -n "$iface" ] && [ -n "$ip_addr" ]; then
      IPS_ENCONTRADOS=1
      lbl="IP (${iface}):"
      printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "$lbl" "$ip_addr"
    fi
  done < <(ip -4 -o addr show scope global 2>/dev/null | awk '$2 != "lo" {split($4, a, "/"); print $2, a[1]}')

  if [ "$IPS_ENCONTRADOS" -eq 0 ]; then
    IP_FALLBACK=$(hostname -I 2>/dev/null | awk '{print $1}')
    printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "IP Local:" "${IP_FALLBACK:-N/A}"
  fi

  echo -e "\033[1;36m================================================================\033[0m\n"
fi
EOF

chmod +x /etc/profile.d/motd_banner.sh
log_success "Banner dinâmico configurado com sucesso em /etc/profile.d/motd_banner.sh."

# ==============================================================================
# 12. RESUMO DA INSTALAÇÃO
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
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-curl, qemu-guest-agent, open-vm-tools, ncdu, btop, locales, htop, tmux, fail2ban, dnsutils, net-tools, unattended-upgrades, ufw, vim}${NC}"
echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}en_US.UTF-8 (Padrão Inglês) / pt_BR.UTF-8${NC}"
echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
echo -e "  ${BOLD}Layout Ativo:${NC}          ${FG_GREEN}ABNT2 (br)${NC}"
echo -e "  ${BOLD}Fuso Horário:${NC}          ${FG_GREEN}America/Sao_Paulo (NTP Ativo)${NC}"
echo -e "  ${BOLD}Proteção /dev/shm (RAM):${NC}$(grep -qs "/dev/shm" /etc/fstab && echo -e "${FG_GREEN}Ativo (noexec,nosuid,nodev)${NC}" || echo -e "${FG_YELLOW}Padrão${NC}")"
if [[ "$VIRT_TYPE" =~ ^(kvm|qemu|bochs)$ ]]; then
  echo -e "  ${BOLD}QEMU Guest Agent:${NC}      $(get_service_status qemu-guest-agent)"
elif [[ "$VIRT_TYPE" == "vmware" ]]; then
  echo -e "  ${BOLD}Open VM Tools:${NC}         $(get_service_status open-vm-tools)"
else
  echo -e "  ${BOLD}Agente de VM:${NC}          ${FG_YELLOW}N/A (Ambiente Físico/WSL)${NC}"
fi
echo -e "  ${BOLD}Fail2Ban (Brute-Force):${NC}$(get_service_status fail2ban)"
echo -e "  ${BOLD}Atualiz. de Segurança:${NC} $(get_service_status unattended-upgrades)"
echo -e "  ${BOLD}Editor Vim:${NC}            $( [ -f /root/.vimrc ] && echo -e "${FG_GREEN}Configurado (Tema Sonokai / Airline)${NC}" || echo -e "${FG_YELLOW}Padrão${NC}")"
echo -e "  ${BOLD}Segurança SSH:${NC}         $(grep -qs -i "^PermitRootLogin[[:space:]]\+yes" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null && echo -e "${FG_YELLOW}Root Login Permitido${NC}" || echo -e "${FG_GREEN}Root Login Desabilitado (Hardened)${NC}")"
echo -e "  ${BOLD}Banner no Login:${NC}       $( [ -f /etc/profile.d/motd_banner.sh ] && echo -e "${FG_GREEN}Ativo (/etc/profile.d/motd_banner.sh)${NC}" || echo -e "${FG_YELLOW}Inativo${NC}")"
if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>/dev/null | grep -q "^Status:[[:space:]]*active"; then
    PORTAS_RAW=$(ufw status 2>/dev/null | grep -i "ALLOW" | awk '{print $1}' | sort -u)
    PORTAS_FORMATADAS=""
    for p in $PORTAS_RAW; do
      case "$p" in
        22/tcp|22) sname="SSH" ;;
        80/tcp|80) sname="HTTP" ;;
        443/tcp|443) sname="HTTPS" ;;
        10050/tcp|10050) sname="Zabbix Agent" ;;
        10051/tcp|10051) sname="Zabbix Server" ;;
        3306/tcp|3306) sname="MySQL/MariaDB" ;;
        5432/tcp|5432) sname="PostgreSQL" ;;
        *) sname=$(grep -w "${p%%/*}" /etc/services 2>/dev/null | head -n1 | awk '{print $1}'); sname=${sname:-Serviço} ;;
      esac
      if [ -z "$PORTAS_FORMATADAS" ]; then
        PORTAS_FORMATADAS="${p} (${sname})"
      else
        PORTAS_FORMATADAS="${PORTAS_FORMATADAS}, ${p} (${sname})"
      fi
    done
    echo -e "  ${BOLD}Firewall UFW:${NC}          ${FG_GREEN}Ativo${NC}"
    echo -e "  ${BOLD}Portas Liberadas (UFW):${NC}${FG_CYAN}${PORTAS_FORMATADAS:-Nenhuma porta liberada}${NC}"
  else
    echo -e "  ${BOLD}Firewall UFW:${NC}          ${FG_YELLOW}Inativo${NC}"
  fi
else
  echo -e "  ${BOLD}Firewall UFW:${NC}          ${FG_YELLOW}Inativo (Não Instalado)${NC}"
fi
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"

if [[ "$CRIAR_ADMIN" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Administrador:${NC}  ${FG_CYAN}administrador${NC} (Sudo Ativo)"
fi
if [[ "$CRIAR_GESET" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Geset:${NC}          ${FG_CYAN}geset${NC} (Sudo Ativo)"
fi
if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  echo -e "  ${BOLD}Usuário Customizado:${NC}    ${FG_CYAN}${NOVO_USER}${NC} (Grupo: ${NOME_GRUPO})"
  echo -e "  ${BOLD}Regras no Visudo:${NC}       /etc/sudoers.d/${ARQUIVO_FINAL_SUDO}"
fi
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 13. GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG DE INSTALAÇÃO
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
