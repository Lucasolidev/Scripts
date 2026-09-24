#!/bin/bash
# ==============================================================================
# Script: pos_install_server.sh
# Descrição: Pós-instalação, hardening e segurança automatizada para Ubuntu Server
# Autor: Lucas Oliveira
# Repositório: https://github.com/Lucasolidev/Scripts
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/pos_install_server.sh -O pos_install_server.sh && sudo chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo) e captura logs de auditoria em /root e na Home.
# 2. Atualiza os espelhos do APT e aplica patches de segurança do sistema (opcional).
# 3. Instala utilitários vitais (curl, vim, ncdu, btop, htop, tmux, fail2ban, auditd, audispd-plugins, dnsutils, net-tools, unattended-upgrades, mtr, iperf3, nmap, tcpdump, iotop, jq, tree, rsync, unzip, p7zip, sysstat, lynis).
# 4. Ajusta locales (en_US/pt_BR UTF-8), fuso horário (America/Sao_Paulo + NTP) e layout de teclado (ABNT2 + US-Intl).
# 5. Aplica proteção de memória compartilhada em RAM (/dev/shm) montada com 'noexec,nosuid,nodev' no /etc/fstab contra botnets/webshells.
# 6. Configura aliases de produtividade e segurança no Shell (ll='ls -alFh', rm, cp, mv, df, free, ports, myip, update, clean, reload).
# 7. Endurece o SSH (Hardening): Desabilita login de Root (opcional), impede senhas em branco e aplica timeout de ociosidade de 10 min.
# 8. Configura o Auditd com rotação de logs e regras ativas para monitorar identidades, sudoers, ssh, rede e persistência.
# 9. Configura a jaula do Fail2Ban (força bruta SSH) e ativa atualizações automáticas de segurança (unattended-upgrades).
# 10. Oferece criação opcional dos usuários padrão 'administrador' (sudo) e 'geset' (sudo).
# 11. Permite criar grupo customizado (TI, DEV) e novo usuário com restrições dinâmicas no Visudo (bloqueio de senha root/geset e shadow).
# 12. Configura e ativa o Firewall UFW Dual-Stack (IPv4/IPv6) liberando portas SSH (22/tcp) e Zabbix Agent (10050/tcp).
# 13. Configura e personaliza o editor Vim com tema Sonokai, Airline e plugins com suporte multi-usuário (/root, /etc/skel, /home).
# 14. Instala o Banner dinâmico de Boas-Vindas no login (/usr/local/bin/motd_banner.sh integrado ao /etc/profile.d e /etc/bash.bashrc) com Hostname, Sistema, Kernel, Uptime, RAM, Discos, IPs e Status do Firewall UFW.
# 15. Exibe o Resumo da Instalação com auditoria completa de status, pacotes, serviços e grava os logs em /root e na Home.
# ==============================================================================

set -Eeuo pipefail
umask 077

VERSION="2.2"
export VERSION
export DEBIAN_FRONTEND=noninteractive

# ==========================================
# PALETA DE CORES (ANSI ESCAPE CODES)
# ==========================================
NC='\033[0m'              # Reset (Sem Cor)
BOLD='\033[1m'
DIM='\033[2m'

# Cores de Fonte (Foreground)
FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_CYAN='\033[36m'

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

is_wsl() {
    grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
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
LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_pos_install_server_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_pos_install_server_latest.log"
LOG_DIR=$(mktemp -d -p /tmp pos_install_server.XXXXXX)
LOG_FILE="${LOG_DIR}/${LOG_FILENAME}"

# Redireciona a saída do script para o terminal e grava no log simultaneamente
exec > >(tee -a "$LOG_FILE") 2>&1

print_header "COLETA DE PARÂMETROS"

read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja atualizar o sistema (apt update e upgrade)? (s/N): ${NC}")" EXEC_UPDATE || true
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja permitir o login de ROOT via SSH? (s/N): ${NC}")" PERMITIR_ROOT_SSH || true
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja habilitar o Firewall UFW? (S/n): ${NC}")" HABILITAR_UFW || true
HABILITAR_UFW=${HABILITAR_UFW:-S}
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'administrador' (sudo)? (s/N): ${NC}")" CRIAR_ADMIN || true
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar o usuário 'geset' (sudo)? (s/N): ${NC}")" CRIAR_GESET || true
read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Deseja criar um grupo restrito (ex: TI, DEV) e um novo usuário vinculado a ele? (s/N): ${NC}")" CRIAR_USUARIO || true

if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do GRUPO que deseja criar (ex: TI, DEV, SUPORTE): ${NC}")" NOME_GRUPO || true
  while [ -z "${NOME_GRUPO:-}" ]; do
    read -r -p "$(echo -e "  ${FG_RED}${ARROW} O nome do grupo não pode ser vazio. Digite novamente: ${NC}")" NOME_GRUPO || true
  done

  read -r -p "$(echo -e "  ${FG_YELLOW}${ARROW} Digite o nome do novo usuário para o grupo ${BOLD}$NOME_GRUPO${NC}${FG_YELLOW}: ${NC}")" NOVO_USER || true
  while [ -z "${NOVO_USER:-}" ]; do
    read -r -p "$(echo -e "  ${FG_RED}${ARROW} O nome do usuário não pode ser vazio. Digite novamente: ${NC}")" NOVO_USER || true
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
PACOTES=(curl ncdu btop locales htop tmux fail2ban auditd audispd-plugins dnsutils net-tools unattended-upgrades ufw vim mtr-tiny iperf3 nmap tcpdump iotop jq tree rsync unzip p7zip-full sysstat lynis)

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
    if [[ "$pacote" == "qemu-guest-agent" || "$pacote" == "open-vm-tools" || "$pacote" == "fail2ban" || "$pacote" == "sysstat" ]]; then
      if [[ "$pacote" == "sysstat" ]]; then
        sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat 2>/dev/null || true
      fi
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
    grep -q "alias motd=" "$bashrc" || echo "alias motd='/usr/local/bin/motd_banner.sh'" >> "$bashrc"
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
  log_info "Configurando jaula do Fail2Ban com whitelist para proteção do SSH..."
  cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
# Whitelist: loopback local e sub-redes privadas seguras (ajuste conforme sua rede)
ignoreip = 127.0.0.1/8 ::1 192.168.0.0/22 10.0.0.0/8 172.16.0.0/12

[sshd]
enabled = true
port = ssh
maxretry = 5
findtime = 600
bantime = 3600
EOF
  systemctl restart fail2ban > /dev/null 2>&1
  log_success "Fail2Ban ativado com whitelist (ignoreip) e proteção SSH (5 tentativas)."
fi

log_info "Configurando atualizações automáticas de segurança (unattended-upgrades)..."
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades > /dev/null 2>&1 || true
log_success "Atualizações de segurança automáticas (unattended-upgrades) ativas e validadas."

# ==============================================================================
# AUDITD - AUDITORIA DO KERNEL, ROTAÇÃO DE LOGS E MONITORAMENTO DE INTEGRIDADE
# ==============================================================================
AUDIT_STATUS="Inativo"
if command -v auditd >/dev/null 2>&1; then
  log_info "Configurando rotação e retenção de logs do Auditd (/etc/audit/auditd.conf)..."
  if [ -f /etc/audit/auditd.conf ]; then
    sed -i 's/^#\?max_log_file =.*/max_log_file = 50/' /etc/audit/auditd.conf
    sed -i 's/^#\?num_logs =.*/num_logs = 10/' /etc/audit/auditd.conf
    sed -i 's/^#\?max_log_file_action =.*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf
    sed -i 's/^#\?space_left =.*/space_left = 100/' /etc/audit/auditd.conf
    sed -i 's/^#\?space_left_action =.*/space_left_action = SYSLOG/' /etc/audit/auditd.conf
    sed -i 's/^#\?admin_space_left_action =.*/admin_space_left_action = SUSPEND/' /etc/audit/auditd.conf
    log_success "Parâmetros de rotação e proteção de disco configurados no auditd.conf."
  fi

  log_info "Criando regras de auditoria para diretórios e arquivos críticos..."
  mkdir -p /etc/audit/rules.d
  cat <<'EOF' > /etc/audit/rules.d/server_security.rules
# ==============================================================================
# REGRAS DE AUDITORIA DE SEGURANCA - LINUX SERVER (AUDITD)
# Monitoramento de identidade, autenticacao, rede, persistencia e escalada
# ==============================================================================

# 1. Identidade, Contas de Usuarios e Grupos
-w /etc/passwd -p wa -k auth_mod
-w /etc/shadow -p wa -k auth_mod
-w /etc/group -p wa -k auth_mod
-w /etc/gshadow -p wa -k auth_mod
-w /etc/security/ -p wa -k auth_mod

# 2. Privilegios Administrativos e Regras Sudo
-w /etc/sudoers -p wa -k sudo_mod
-w /etc/sudoers.d/ -p wa -k sudo_mod

# 3. Configuracoes do Servico SSH
-w /etc/ssh/sshd_config -p wa -k ssh_mod
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_mod

# 4. Configuracoes de Rede e Regras de Firewall
-w /etc/hosts -p wa -k net_mod
-w /etc/resolv.conf -p wa -k net_mod
-w /etc/netplan/ -p wa -k net_mod
-w /etc/network/ -p wa -k net_mod
-w /etc/ufw/ -p wa -k net_mod

# 5. Agendamentos de Tarefas e Persistencia do Sistema
-w /etc/crontab -p wa -k cron_mod
-w /etc/cron.d/ -p wa -k cron_mod
-w /etc/cron.daily/ -p wa -k cron_mod
-w /etc/cron.hourly/ -p wa -k cron_mod
-w /etc/cron.monthly/ -p wa -k cron_mod
-w /etc/cron.weekly/ -p wa -k cron_mod
-w /etc/systemd/system/ -p wa -k systemd_mod

# 6. Binarios Criticos de Execucao e Escalada de Privilegios
-w /usr/bin/sudo -p x -k priv_escalation
-w /usr/bin/su -p x -k priv_escalation
-w /usr/bin/passwd -p x -k priv_escalation
EOF

  log_info "Carregando regras de auditoria no kernel..."
  if is_wsl; then
    AUDIT_STATUS="Indisponivel no WSL (kernel sem suporte a regras auditd)"
    log_warning "WSL detectado: kernel WSL não suporta regras de auditoria; auditd em tempo real desativado apenas neste ambiente."
  else
    augenrules --load > /dev/null 2>&1 || log_warning "Falha ao carregar as regras com augenrules."
    systemctl enable --now auditd > /dev/null 2>&1 || true
    service auditd restart > /dev/null 2>&1 || true
    AUDIT_STATUS="Ativo (Monitorando identidades, sudo, ssh, rede e persistência)"
    log_success "Auditd configurado e ativo com rotação de logs e regras carregadas."
  fi
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
# 11. BANNER DINÂMICO DE BOAS-VINDAS NO LOGIN (/usr/local/bin/motd_banner.sh)
# ==============================================================================
print_header "BANNER DE BOAS-VINDAS NO LOGIN"
log_info "Configurando banner de boas-vindas dinâmico em /usr/local/bin/motd_banner.sh..."

cat << 'EOF' > /usr/local/bin/motd_banner.sh
#!/bin/bash
# ==============================================================================
# Banner Dinâmico de Boas-Vindas e Diagnóstico do Servidor
# Exibido automaticamente em sessões interativas de shell (SSH / Console)
# ==============================================================================

# Executa apenas se a saída padrão for um terminal interativo (evita quebrar scp/sftp/rsync)
[ -t 1 ] || exit 0

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
DISCOS_RAW=$(df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 -x rootfs 2>/dev/null | awk 'NR>1 && ($1 ~ /^\/dev/ || $1 ~ /:/) && $6 !~ /^\/boot/ {print $6, $3, $2, $4, $5}')
if [ -n "$DISCOS_RAW" ]; then
  while read -r mountpoint used total free perc; do
    if [ -n "$mountpoint" ]; then
      DISCOS_ENCONTRADOS=1
      lbl="Disco (${mountpoint}):"
      printf "     \033[1m%-18s\033[0m \033[36mUsado: %s / Total: %s (Livre: %s | %s)\033[0m\n" "$lbl" "$used" "$total" "$free" "$perc"
    fi
  done <<< "$DISCOS_RAW"
fi

if [ "$DISCOS_ENCONTRADOS" -eq 0 ]; then
  ROOT_DF=$(df -h / 2>/dev/null | awk 'NR==2 {print "Usado: " $3 " / Total: " $2 " (Livre: " $4 " | " $5 ")"}')
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "Disco (/):" "${ROOT_DF}"
fi

# Interfaces de Rede e Endereços IPv4
IPS_ENCONTRADOS=0
IPS_RAW=$(ip -4 -o addr show scope global 2>/dev/null | awk '$2 != "lo" {split($4, a, "/"); print $2, a[1]}')
if [ -n "$IPS_RAW" ]; then
  while read -r iface ip_addr; do
    if [ -n "$iface" ] && [ -n "$ip_addr" ]; then
      IPS_ENCONTRADOS=1
      lbl="IP (${iface}):"
      printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "$lbl" "$ip_addr"
    fi
  done <<< "$IPS_RAW"
fi

if [ "$IPS_ENCONTRADOS" -eq 0 ]; then
  IP_FALLBACK=$(hostname -I 2>/dev/null | awk '{print $1}')
  printf "     \033[1m%-18s\033[0m \033[36m%s\033[0m\n" "IP Local:" "${IP_FALLBACK:-N/A}"
fi

# Status do Firewall UFW
if (grep -qs -i "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null && systemctl is-active --quiet ufw 2>/dev/null) || (ufw status 2>/dev/null | grep -qi "^Status:[[:space:]]*active"); then
  UFW_STATUS_TXT="\033[1;32mAtivo\033[0m"
elif command -v ufw >/dev/null 2>&1; then
  UFW_STATUS_TXT="\033[1;33mInativo\033[0m"
else
  UFW_STATUS_TXT="\033[1;33mNão Instalado\033[0m"
fi
printf "     \033[1m%-18s\033[0m %b\n" "Firewall UFW:" "${UFW_STATUS_TXT}"

echo -e "\033[1;36m================================================================\033[0m\n"
EOF

chmod 755 /usr/local/bin/motd_banner.sh

log_info "Integrando banner ao /etc/profile.d/ e /etc/bash.bashrc com controle de sessão..."
cat << 'EOF' > /etc/profile.d/motd_banner.sh
#!/bin/sh
# Exibe o banner apenas em terminais interativos (login shell)
if [ -t 1 ] && [ -z "$__MOTD_SHOWN" ] && [ -x /usr/local/bin/motd_banner.sh ]; then
  export __MOTD_SHOWN=1
  /usr/local/bin/motd_banner.sh
fi
EOF
chmod 755 /etc/profile.d/motd_banner.sh

# Garante a chamada em /etc/bash.bashrc para shells interativos não-login
if ! grep -q "motd_banner.sh" /etc/bash.bashrc 2>/dev/null; then
  cat << 'EOF' >> /etc/bash.bashrc

# Exibe o banner dinâmico do servidor em shells interativos (se ainda não exibido na sessão)
if [ -t 1 ] && [ -z "$__MOTD_SHOWN" ] && [ -x /usr/local/bin/motd_banner.sh ]; then
  export __MOTD_SHOWN=1
  /usr/local/bin/motd_banner.sh
fi
EOF
fi

# Desativa notícias de publicidade do Ubuntu motd para manter login limpo
chmod -x /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news 2>/dev/null || true
rm -f /etc/update-motd.d/01-custom-banner 2>/dev/null || true

# Remove qualquer .hushlogin que possa silenciar o login
rm -f /root/.hushlogin /home/*/.hushlogin 2>/dev/null || true

log_success "Banner dinâmico configurado em /usr/local/bin/motd_banner.sh, /etc/profile.d/ e /etc/bash.bashrc."

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
echo -e "  ${BOLD}Auditd (Integridade):${NC}  ${FG_GREEN}${AUDIT_STATUS}${NC}"
echo -e "  ${BOLD}Editor Vim:${NC}            $( [ -f /root/.vimrc ] && echo -e "${FG_GREEN}Configurado (Tema Sonokai / Airline)${NC}" || echo -e "${FG_YELLOW}Padrão${NC}")"
echo -e "  ${BOLD}Segurança SSH:${NC}         $(grep -qs -i "^PermitRootLogin[[:space:]]\+yes" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null && echo -e "${FG_YELLOW}Root Login Permitido${NC}" || echo -e "${FG_GREEN}Root Login Desabilitado (Hardened)${NC}")"
echo -e "  ${BOLD}Banner no Login:${NC}       $( [ -x /usr/local/bin/motd_banner.sh ] && echo -e "${FG_GREEN}Ativo (/etc/profile.d & /etc/bash.bashrc)${NC}" || echo -e "${FG_YELLOW}Inativo${NC}")"
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
cp "$LOG_FILE" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_FILE" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

# Se executado via sudo, salva também na pasta home do usuário real
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  if [ -d "$REAL_USER_HOME" ]; then
    cp "$LOG_FILE" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
    cp "$LOG_FILE" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
    chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
    log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
  fi
fi

rm -rf "$LOG_DIR" 2>/dev/null || true

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
