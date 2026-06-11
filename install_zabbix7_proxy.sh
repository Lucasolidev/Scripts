#!/bin/bash
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E ZABBIX PROXY 7.0 LTS - UBUNTU 24.04
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_zabbix7_proxy.sh
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

# Cores ANSI para destaque no terminal
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

echo -e "${CIANO}--- Iniciando Instalação Automatizada Zabbix Proxy 7.0 LTS + Agent + SNMP (Ubuntu 24.04) ---${RESET}"

# Perguntas de configuração
read -p "$(echo -e ${AMARELO}"Digite o Hostname do Proxy (Padrão: Cliente_ZabbixProxy): "${RESET})" PROXY_HOSTNAME
PROXY_HOSTNAME=${PROXY_HOSTNAME:-Cliente_ZabbixProxy}

read -p "$(echo -e ${AMARELO}"Digite o Hostname do Agente (Padrão: Cliente_ServProg): "${RESET})" AGENT_HOSTNAME
AGENT_HOSTNAME=${AGENT_HOSTNAME:-Cliente_ServProg}

read -p "$(echo -e ${AMARELO}"Digite o IP do servidor Zabbix/Proxy (Padrão: 192.168.x.x): "${RESET})" PROXY_IP
PROXY_IP=${PROXY_IP:-192.168.x.x}

# 1. Repositório Oficial Zabbix 7.0 LTS para Ubuntu 24.04
echo -e "${CIANO}[Etapa 1] Configurando repositório do Zabbix 7.0 LTS...${RESET}"
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb > /dev/null
apt update

# 2. Instalação dos Pacotes (O APT agora cria o usuário zabbix nativamente aqui)
echo -e "${CIANO}[Etapa 2] Instalando pacotes do Zabbix Proxy, Agent e SNMP...${RESET}"
apt install -y zabbix-proxy-sqlite3 zabbix-agent curl snmpd snmp-mibs-downloader fping openssl snmp sqlite3

# 3. Preparar diretórios de log, runtime e aplicação de permissões (Agora com usuário já existente)
echo -e "${CIANO}[Etapa 3] Configurando diretórios de trabalho e permissões...${RESET}"
mkdir -p /var/log/zabbix
mkdir -p /var/lib/zabbix
mkdir -p /var/run/zabbix
chown -R zabbix:zabbix /var/log/zabbix
chown -R zabbix:zabbix /var/lib/zabbix
chown -R zabbix:zabbix /var/run/zabbix
chmod -R 775 /var/log/zabbix

# 4. Gerar Chave PSK
echo -e "${CIANO}[Etapa 4] Gerando chave PSK...${RESET}"
openssl rand -hex 32 | tee /etc/zabbix/zabbix_proxy.psk > /dev/null
chown zabbix:zabbix /etc/zabbix/zabbix_proxy.psk
chmod 600 /etc/zabbix/zabbix_proxy.psk

# 5. Configurar Banco de Dados do Proxy (SQLite3)
echo -e "${CIANO}[Etapa 5] Populando banco de dados SQLite3 para o Proxy...${RESET}"
zcat /usr/share/doc/zabbix-proxy-sqlite3/schema.sql.gz | sqlite3 /var/lib/zabbix/zabbix.db
chown -R zabbix:zabbix /var/lib/zabbix

# 6. Configurar zabbix_proxy.conf
echo -e "${CIANO}[Etapa 6] Criando arquivo zabbix_proxy.conf...${RESET}"
cat <<EOF > /etc/zabbix/zabbix_proxy.conf
Server=monitor.geset.com.br
Hostname=$PROXY_HOSTNAME
DBName=/var/lib/zabbix/zabbix.db
LogFile=/var/log/zabbix/zabbix_proxy.log
PidFile=/var/run/zabbix/zabbix_proxy.pid
FpingLocation=/usr/bin/fping
ProxyMode=0
LogFileSize=10
DebugLevel=3
CacheSize=2G
DataSenderFrequency=30
ProxyOfflineBuffer=24
ProxyLocalBuffer=4
UnavailableDelay=20
UnreachablePeriod=60
ProxyConfigFrequency=60
HistoryCacheSize=32M
StartIPMIPollers=1
Timeout=5
StartPingers=5
StartDiscoverers=5
StartVMwareCollectors=5
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=$PROXY_HOSTNAME
TLSPSKFile=/etc/zabbix/zabbix_proxy.psk
EOF

# 7. Configurar zabbix_agentd.conf
echo -e "${CIANO}[Etapa 7] Criando arquivo zabbix_agentd.conf...${RESET}"
cat <<EOF > /etc/zabbix/zabbix_agentd.conf
Hostname=$AGENT_HOSTNAME
Server=127.0.0.1,$PROXY_IP
ServerActive=127.0.0.1,$PROXY_IP
ListenPort=10050
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=2
DebugLevel=3
Timeout=3
UserParameter=net.ipaddress,curl -s -L -k http://www.geset.com.br/suporte/ip.php
EOF

# 8. Configurar SNMP
echo -e "${CIANO}[Etapa 8] Configurando ambiente SNMP...${RESET}"
echo "mibs :" > /etc/snmp/snmp.conf
cat <<EOF > /etc/snmp/snmpd.conf
rocommunity cliente_snmp 127.0.0.1 .1
rocommunity cliente_snmp 192.168.0.0/16 .1
EOF

# 9. Configurar Regras de Firewall (UFW) sem ativar o serviço
if command -v ufw >/dev/null 2>&1; then
  echo -e "${CIANO}[Etapa 9] Configurando regras no UFW...${RESET}"
  ufw allow 10050/tcp comment 'Zabbix Agent Port'
  ufw allow 10051/tcp comment 'Zabbix Proxy Port'
  ufw allow 22/tcp comment 'Acesso SSH Remoto'
  ufw allow 161/udp comment 'SNMP Polling Port'
  ufw allow 1161/udp comment 'SNMP Traps / Custom Port'
  echo -e "${VERDE}Regras de firewall adicionadas com sucesso!${RESET}"
else
  echo -e "${AMARELO}UFW não encontrado. Pulando configuração de firewall.${RESET}"
fi

# 10. Reiniciar e Habilitar Serviços
chown -R zabbix:zabbix /var/run/zabbix
echo -e "${CIANO}[Etapa 10] Ativando e reiniciando serviços daemons...${RESET}"
systemctl restart snmpd zabbix-proxy zabbix-agent
systemctl enable snmpd zabbix-proxy zabbix-agent

# OUTCOME VISUAL FINAL
echo -e "${VERDE}--------------------------------------------------------"
echo "Instalação finalizada com sucesso!"
echo -e "--------------------------------------------------------${RESET}"
echo -e "${AMARELO}Identity PSK:${RESET} $PROXY_HOSTNAME"
echo -e "${AMARELO}Chave PSK (copie abaixo para configurar no Zabbix Server):${RESET}"
echo "--------------------------------------------------------"
cat /etc/zabbix/zabbix_proxy.psk
echo ""
echo "--------------------------------------------------------"
echo -e "${CIANO}Regras atuais configuradas no UFW (apenas se ativo):${RESET}"
ufw show added
echo "--------------------------------------------------------"
echo -e "${CIANO}Exibindo os logs de inicialização do Zabbix Agent:${RESET}"
echo "--------------------------------------------------------"
sleep 10
cat /var/log/zabbix/zabbix_agentd.log
echo "--------------------------------------------------------"
echo "--------------------------------------------------------"
echo -e "${CIANO}Exibindo os logs de inicialização do Zabbix Proxy:${RESET}"
echo "--------------------------------------------------------"
# Verificar o Log: cat /var/log/zabbix/zabbix_proxyd.log

