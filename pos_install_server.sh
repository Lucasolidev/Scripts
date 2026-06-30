#!/bin/bash
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO - UBUNTU SERVER
# ==============================================================================
# Instala programas necessários QEMU, VMware, ncdu, fastfetch. 
# Ativação do root login por SSH (Opciional)
# Criação de usuário e grupo TI com suas retrições (Opcional)
# Adicionadr regras no firewall de SSH e Zabbix Agent porém não ativa o firewall
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
# Cores ANSI
VERDE="\033[0;32m"
AMARELO="\033[1;33m"
CIANO="\033[0;36m"
VERMELHO="\033[0;31m"
RESET="\033[0m"

# Verificar se o script está rodando como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Por favor, execute como root (sudo)${RESET}"
  exit
fi

echo -e "${CIANO}--- Iniciando Pós-Instalação do Servidor ---${RESET}"

# Perguntas interativas
read -p "$(echo -e ${AMARELO}"Deseja permitir o login direto como Root via SSH (PermitRootLogin yes)? (s/n): "${RESET})" PERMIT_ROOT
read -p "$(echo -e ${AMARELO}"Deseja criar o grupo 'TI' e um novo usuário administrativo? (s/n): "${RESET})" CRIAR_USUARIO

if [ "$CRIAR_USUARIO" == "s" ] || [ "$CRIAR_USUARIO" == "S" ]; then
  read -p "$(echo -e ${AMARELO}"Digite o nome do novo usuário: "${RESET})" NOVO_USER
  while [ -z "$NOVO_USER" ]; do
    read -p "$(echo -e ${VERMELHO}"O nome do usuário não pode ser vazio. Digite novamente: "${RESET})" NOVO_USER
  done
fi

echo "--------------------------------------------------------"
echo -e "${CIANO}Configurações coletadas. Iniciando os procedimentos...${RESET}"
echo "--------------------------------------------------------"

# 1. Atualização do Sistema
echo -e "${CIANO}Atualizando a lista de pacotes (apt update)...${RESET}"
apt update -y

echo -e "${CIANO}Aplicando atualizações de segurança e sistema (apt upgrade)...${RESET}"
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# 2. Instalação de Pacotes e Utilitários
echo -e "${CIANO}Instalando utilitários e agentes Hypervisor (QEMU, VMware, ncdu, fastfetch)...${RESET}"
apt install -y qemu-guest-agent open-vm-tools ncdu fastfetch
systemctl enable qemu-guest-agent open-vm-tools > /dev/null 2>&1
systemctl start qemu-guest-agent open-vm-tools > /dev/null 2>&1

# 3. Configuração do SSH (PermitRootLogin)
if [ "$PERMIT_ROOT" == "s" ] || [ "$PERMIT_ROOT" == "S" ]; then
  echo -e "${CIANO}Configurando PermitRootLogin para 'yes' no SSH...${RESET}"
  sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  systemctl restart sshd
else
  echo -e "${AMARELO}Mantendo configuração padrão para o login de Root no SSH.${RESET}"
fi

# 4. Criação do Grupo TI, Usuário Exclusivo e Regras do Visudo
if [ "$CRIAR_USUARIO" == "s" ] || [ "$CRIAR_USUARIO" == "S" ]; then
  echo -e "${CIANO}Criando o grupo 'TI'...${RESET}"
  getent group TI > /dev/null || groupadd TI

  echo -e "${CIANO}Criando o usuário '$NOVO_USER'...${RESET}"
  if id "$NOVO_USER" &>/dev/null; then
    echo -e "${AMARELO}Aviso: O usuário '$NOVO_USER' já existe. Adicionando ao grupo TI...${RESET}"
  else
    useradd -m -s /bin/bash "$NOVO_USER"
    echo -e "${AMARELO}Defina a senha para o usuário '$NOVO_USER':${RESET}"
    passwd "$NOVO_USER"
  fi

  usermod -aG TI "$NOVO_USER"
  echo -e "${VERDE}Usuário '$NOVO_USER' configurado e adicionado exclusivamente ao grupo TI.${RESET}"

  # Aplicando restrições do grupo TI no Sudoers
  echo -e "${CIANO}Aplicando restrições de segurança para o grupo TI no visudo...${RESET}"
  SUDOERS_TMP=$(mktemp)
  
  cat << 'EOF' > "$SUDOERS_TMP"
# Grupo TI com restricao de alterar senha do root e geset e leitura do shadow
%TI ALL=(ALL:ALL) ALL, !/usr/bin/passwd root, !/usr/bin/passwd geset, !/usr/bin/passwd "", !/usr/sbin/visudo, !/usr/sbin/usermod, !/usr/bin/gpasswd, !/usr/bin/su, !/usr/bin/sudo -i, !/usr/bin/sudo -s, !/usr/bin/sudo /bin/bash, !/usr/bin/sudo /bin/sh, !/usr/bin/sudoedit /etc/sudoers*, !/usr/bin/sudoedit /etc/shadow, !/usr/bin/nano /etc/shadow, !/usr/bin/vi /etc/shadow, !/usr/bin/nano /etc/sudoers*, !/usr/bin/vi /etc/sudoers*, !/usr/bin/cat /etc/shadow, !/usr/bin/head /etc/shadow, !/usr/bin/tail /etc/shadow, !/usr/bin/grep * /etc/shadow, !/usr/bin/less /etc/shadow, !/usr/bin/awk * /etc/shadow, !/usr/bin/cp /etc/shadow *, !/usr/bin/chmod * *shadow*, !/usr/bin/chown * *shadow*, !/usr/bin/cat *shadow*
EOF

  if visudo -cf "$SUDOERS_TMP" > /dev/null 2>&1; then
    mv "$SUDOERS_TMP" /etc/sudoers.d/grupo_ti
    chmod 0440 /etc/sudoers.d/grupo_ti
    echo -e "${VERDE}Regras do visudo para o grupo TI aplicadas com sucesso!${RESET}"
  else
    echo -e "${VERMELHO}Erro: Sintaxe das regras do visudo inválida. As restrições NÃO foram aplicadas.${RESET}"
    rm -f "$SUDOERS_TMP"
  fi
fi

# 5. Configurar Regras de Firewall (UFW) sem ativar o serviço
if command -v ufw >/dev/null 2>&1; then
  echo -e "${CIANO}Configurando regras no UFW...${RESET}"
  ufw allow 22/tcp comment 'Acesso SSH Remoto'
  ufw allow 10050/tcp comment 'Zabbix Agent Port'
else
  echo -e "${AMARELO}UFW não encontrado. Pulando firewall.${RESET}"
fi

# OUTCOME VISUAL FINAL DO SERVIDOR
echo -e "${VERDE}--------------------------------------------------------"
echo "Pós-instalação concluída com sucesso!"
echo -e "--------------------------------------------------------${RESET}"
echo -e "${CIANO}Status dos Agentes Instalados:${RESET}"
echo " - QEMU Guest Agent: $(systemctl is-active qemu-guest-agent)"
echo " - Open VM Tools:   $(systemctl is-active open-vm-tools)"
echo "--------------------------------------------------------"
echo -e "${CIANO}Regras atuais configuradas no UFW (apenas se ativo):${RESET}"
ufw show added
echo "--------------------------------------------------------"

if [ "$CRIAR_USUARIO" == "s" ] || [ "$CRIAR_USUARIO" == "S" ]; then
  echo -e "${CIANO}Informações do usuário criado:${RESET}"
  id "$NOVO_USER"
  echo "--------------------------------------------------------"
  echo -e "${CIANO}Verificação do arquivo de restrições do grupo TI:${RESET}"
  if [ -f /etc/sudoers.d/grupo_ti ]; then
    echo -e "${VERDE}Arquivo /etc/sudoers.d/grupo_ti criado e ativo.${RESET}"
  else
    echo -e "${VERMELHO}Aviso: Arquivo de restrições não encontrado ou falhou na validação.${RESET}"
  fi
  echo "--------------------------------------------------------"
fi
