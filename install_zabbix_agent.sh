#!/bin/bash
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E ZABBIX AGENT 7 - UBUNTU 24.04
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_zabbix_agent.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/linux/main/agendar_reinicio.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/linux/main/agendar_reinicio.sh
#
# Executar via URL
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/linux/main/agendar_reinicio.sh)
#
# ==============================================================================
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

# Configurações padrão
DEFAULT_HOSTNAME="Cliente_ServBkp"
DEFAULT_SERVER="192.168.1.254"

echo -e "${CIANO}--- Configuração do Zabbix Agent ---${RESET}"

# Perguntas
read -p "$(echo -e ${AMARELO}"Digite o Hostname (Padrão: $DEFAULT_HOSTNAME): "${RESET})" INPUT_HOSTNAME
HOSTNAME=${INPUT_HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "$(echo -e ${AMARELO}"Digite o IP do Servidor Zabbix (Padrão: $DEFAULT_SERVER): "${RESET})" INPUT_SERVER
SERVER=${INPUT_SERVER:-$DEFAULT_SERVER}

read -p "$(echo -e ${AMARELO}"Deseja aplicar estas configurações ao arquivo final? (s/n): "${RESET})" CONFIRMAR

# 1. Download e Instalação do repositório
echo -e "${CIANO}Configurando repositório Zabbix...${RESET}"
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb > /dev/null
apt update -y

# 2. Instalação do agente e criação de diretórios de runtime
echo -e "${CIANO}Instalando Zabbix Agent...${RESET}"
apt install -y zabbix-agent

mkdir -p /var/log/zabbix
mkdir -p /var/run/zabbix
chown -R zabbix:zabbix /var/log/zabbix
chown -R zabbix:zabbix /var/run/zabbix

# 3. Configuração do arquivo zabbix_agentd.conf
if [ "$CONFIRMAR" == "s" ] || [ "$CONFIRMAR" == "S" ]; then
    echo -e "${CIANO}Aplicando arquivo de configurações customizadas...${RESET}"
    cat <<EOF > /etc/zabbix/zabbix_agentd.conf
### Agente Zabbix ###

Hostname=$HOSTNAME
Server=$SERVER
ServerActive=$SERVER

ListenPort=10050
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=2
DebugLevel=3
Timeout=30

# Endereco IP WAN
UserParameter=net.ipaddress,curl -s -L -k http://www.geset.com.br/suporte/ip.php
EOF
else
    echo -e "${AMARELO}Configuração automática pulada. Ajuste manualmente.${RESET}"
fi

# 4. Configurar Regras de Firewall (UFW) sem ativar o serviço
if command -v ufw >/dev/null 2>&1; then
  echo -e "${CIANO}Configurando regra no UFW...${RESET}"
  ufw allow 10050/tcp comment 'Zabbix Agent Port'
else
  echo -e "${AMARELO}UFW não encontrado. Pulando firewall.${RESET}"
fi

# 5. Habilitar e iniciar o serviço
chown -R zabbix:zabbix /var/run/zabbix
systemctl enable zabbix-agent
systemctl restart zabbix-agent

# OUTCOME VISUAL FINAL DO AGENTE
echo -e "${VERDE}--------------------------------------------------------"
echo "Processo concluído!"
echo -e "--------------------------------------------------------${RESET}"
echo -e "${CIANO}Exibindo os logs do Zabbix Agent (/var/log/zabbix/zabbix_agentd.log):${RESET}"
echo "--------------------------------------------------------"
sleep 2
cat /var/log/zabbix/zabbix_agentd.log
echo "--------------------------------------------------------"
