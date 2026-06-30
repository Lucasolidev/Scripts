#!/bin/bash
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO - UBUNTU SERVER
# ==============================================================================
# O que este script faz (Descrição e Auditoria de Funções):
# 1. Valida privilégios de execução (exige Root/Sudo).
# 2. Atualiza os espelhos do APT e aplica patches de segurança do sistema.
# 3. Instala pacotes vitais (QEMU Guest Agent, Open VM Tools, ncdu, fastfetch).
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

export DEBIAN_FRONTEND=noninteractive

# Cores ANSI para legibilidade dos logs
VERDE="\033[0;32m"
AMARELO="\033[1;33m"
CIANO="\033[0;36m"
VERMELHO="\033[0;31m"
RESET="\033[0m"

# Verificar se o script está rodando como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Por favor, execute como root (sudo)${RESET}"
  exit 1
fi

echo -e "${CIANO}--- Iniciando Pós-Instalação do Servidor ---${RESET}"

# ==============================================================================
# BLOCO DE INTERATIVIDADE ECOLETAS DE PARÂMETROS
# ==============================================================================

# Sugestão de Melhoria 1: SSH por padrão desabilitado, necessitando de ação explícita 'yes' para abrir o Root.
read -p "$(echo -e ${AMARELO}"Visando segurança, o padrão é desabilitar o login de Root via SSH. Deseja forçar a ativação (yes)? (s/n): "${RESET})" PERMIT_ROOT

# Alteração: Criação assistida do usuário administrador tradicional
read -p "$(echo -e ${AMARELO}"Deseja criar o usuário padrão 'administrador' com acesso total ao Sudo? (s/n): "${RESET})" CRIAR_ADMIN
if [[ "$CRIAR_ADMIN" =~ ^[Ss]$ ]]; then
  if id "administrador" &>/dev/null; then
    echo -e "${AMARELO}[!] O usuário 'administrador' já existe no sistema.${RESET}"
  fi
fi

# Alteração: Escolha dinâmica de Grupo Customizado para restrição via Visudo
read -p "$(echo -e ${AMARELO}"Deseja criar um grupo restrito (ex: TI, DEV) e um novo usuário vinculado a ele? (s/n): "${RESET})" CRIAR_USUARIO

if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  # Escolha do nome do grupo customizado
  read -p "$(echo -e ${AMARELO}"Digite o nome do GRUPO que deseja criar (ex: TI, DEV, SUPORTE): "${RESET})" NOME_GRUPO
  while [ -z "$NOME_GRUPO" ]; do
    read -p "$(echo -e ${VERMELHO}"O nome do grupo não pode ser vazio. Digite novamente: "${RESET})" NOME_GRUPO
  done

  # Coleta do nome do usuário exclusivo deste grupo
  read -p "$(echo -e ${AMARELO}"Digite o nome do novo usuário para o grupo $NOME_GRUPO: "${RESET})" NOVO_USER
  while [ -z "$NOVO_USER" ]; do
    read -p "$(echo -e ${VERMELHO}"O nome do usuário não pode ser vazio. Digite novamente: "${RESET})" NOVO_USER
  done
fi

echo "--------------------------------------------------------"
echo -e "${CIANO}Configurações coletadas. Iniciando os procedimentos...${RESET}"
echo "--------------------------------------------------------"

# ==============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA
# ==============================================================================
echo -e "${CIANO}Atualizando a lista de pacotes (apt update)...${RESET}"
apt update -y

echo -e "${CIANO}Aplicando atualizações de segurança e sistema (apt upgrade)...${RESET}"
apt upgrade -y

# ==============================================================================
# 2. INSTALAÇÃO DE PACOTES E UTILLITÁRIOS
# ==============================================================================
echo -e "${CIANO}Instalando utilitários e agentes Hypervisor (QEMU, VMware, ncdu, fastfetch)...${RESET}"
apt install -y qemu-guest-agent open-vm-tools ncdu fastfetch

systemctl enable --now qemu-guest-agent open-vm-tools > /dev/null 2>&1

# ==============================================================================
# 3. CONFIGURAÇÃO DO SSH (Aumento de segurança padrão)
# ==============================================================================
# Modificado: Se o usuário não disser Explicitamente "Sim", o script blinda a config para "no"
if [[ "$PERMIT_ROOT" =~ ^[Ss]$ ]]; then
  echo -e "${AMARELO}[!] Alerta de Segurança: Configurando PermitRootLogin para 'yes' no SSH...${RESET}"
  sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
else
  echo -e "${VERDE}[+] Segurança Aplicada: Desabilitando explicitamente o login de Root via SSH (Padrão).${RESET}"
  sed -i '/^#\?PermitRootLogin/d' /etc/ssh/sshd_config
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config
fi
systemctl restart sshd

# ==============================================================================
# OTIMIZAÇÃO EXTRA: CRIÇÃO DO USUÁRIO ADMINISTRADOR BÁSICO
# ==============================================================================
if [[ "$CRIAR_ADMIN" =~ ^[Ss]$ ]]; then
  if ! id "administrador" &>/dev/null; then
    echo -e "${CIANO}Criando usuário administrativo padrão ('administrador')...${RESET}"
    useradd -m -s /bin/bash -G sudo administrador
    echo -e "${AMARELO}Defina a senha para o usuário 'administrador':${RESET}"
    passwd administrador
  fi
fi

# ==============================================================================
# 4. CRIAÇÃO DO GRUPO PARAMETRIZADO, USUÁRIO EXCLUSIVO E REGRAS DO VISUDO
# ==============================================================================
if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  # Higieniza a string transformando o nome do grupo em letras maiúsculas para o padrão Unix
  NOME_GRUPO=$(echo "$NOME_GRUPO" | tr '[:lower:]' '[:upper:]')

  echo -e "${CIANO}Criando/Verificando o grupo customizado '$NOME_GRUPO'...${RESET}"
  getent group "$NOME_GRUPO" > /dev/null || groupadd "$NOME_GRUPO"

  echo -e "${CIANO}Criando o usuário '$NOVO_USER'...${RESET}"
  if id "$NOVO_USER" &>/dev/null; then
    echo -e "${AMARELO}Aviso: O usuário '$NOVO_USER' já existe. Vinculando ao grupo $NOME_GRUPO...${RESET}"
  else
    useradd -m -s /bin/bash "$NOVO_USER"
    echo -e "${AMARELO}Defina a senha para o usuário '$NOVO_USER':${RESET}"
    passwd "$NOVO_USER"
  fi

  # Garante que o usuário pertença ao grupo customizado
  usermod -aG "$NOME_GRUPO" "$NOVO_USER"
  echo -e "${VERDE}Usuário '$NOVO_USER' configurado e adicionado ao grupo $NOME_GRUPO.${RESET}"

  # Sugestão de Melhoria 2: Validação se o usuário 'geset' existe para evitar erros de sintaxe no Sudoers
  echo -e "${CIANO}Auditando existência do usuário 'geset' para regras do Sudoers...${RESET}"
  if id "geset" &>/dev/null; then
    REGRA_GESET=", !/usr/bin/passwd geset"
    echo -e "${VERDE}[+] Usuário geset localizado. Amarra de proteção adicionada ao Visudo.${RESET}"
  else
    REGRA_GESET=""
    echo -e "${AMARELO}[-] Usuário geset não existe neste servidor. Removendo amarra pendente para evitar falha no Visudo.${RESET}"
  fi

  echo -e "${CIANO}Aplicando restrições de segurança dinâmicas para o grupo $NOME_GRUPO no visudo...${RESET}"
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
    echo -e "${VERDE}Regras do visudo para o grupo $NOME_GRUPO aplicadas com sucesso!${RESET}"
  else
    echo -e "${VERMELHO}Erro crítico: Sintaxe das regras do visudo inválida. As restrições NÃO foram aplicadas.${RESET}"
    rm -f "$SUDOERS_TMP"
  fi
fi

# ==============================================================================
# 5. CONFIGURAR REGRAS DE FIREWALL (UFW)
# ==============================================================================
if command -v ufw >/dev/null 2>&1; then
  echo -e "${CIANO}Configurando regras básicas no UFW...${RESET}"
  ufw allow 22/tcp comment 'Acesso SSH Remoto'
  ufw allow 10050/tcp comment 'Zabbix Agent Port'
else
  echo -e "${AMARELO}UFW não encontrado. Instalação e parametrização pulada.${RESET}"
fi

# ==============================================================================
# OUTCOME VISUAL FINAL DO SERVIDOR
# ==============================================================================
echo -e "${VERDE}--------------------------------------------------------"
echo "Pós-instalação concluída com sucesso!"
echo -e "--------------------------------------------------------${RESET}"
echo -e "${CIANO}Status dos Agentes Instalados:${RESET}"
echo " - QEMU Guest Agent: $(systemctl is-active qemu-guest-agent)"
echo " - Open VM Tools:   $(systemctl is-active open-vm-tools)"
echo "--------------------------------------------------------"
echo -e "${CIANO}Regras atuais pré-configuradas no UFW:${RESET}"
ufw show added
echo "--------------------------------------------------------"

if [[ "$CRIAR_USUARIO" =~ ^[Ss]$ ]]; then
  echo -e "${CIANO}Informações do usuário exclusivo criado:${RESET}"
  id "$NOVO_USER"
  echo "--------------------------------------------------------"
  echo -e "${CIANO}Verificação do arquivo de restrições do grupo $NOME_GRUPO:${RESET}"
  if [ -f "/etc/sudoers.d/$ARQUIVO_FINAL_SUDO" ]; then
    echo -e "${VERDE}Arquivo /etc/sudoers.d/$ARQUIVO_FINAL_SUDO criado e ativo.${RESET}"
  else
    echo -e "${VERMELHO}Aviso: Arquivo de restrições (/etc/sudoers.d/$ARQUIVO_FINAL_SUDO) falhou na validação.${RESET}"
  fi
  echo "--------------------------------------------------------"
fi
