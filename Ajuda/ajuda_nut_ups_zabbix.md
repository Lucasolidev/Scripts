# 🔋 Guia Prático: Monitoramento Universal de Nobreaks USB com NUT & Zabbix 7.0

![NUT](https://img.shields.io/badge/Network_UPS_Tools-NUT-blue?style=flat)
![Zabbix](https://img.shields.io/badge/Zabbix-7.0_LTS-D40000?style=flat&logo=zabbix&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_|_26.04-E95420?style=flat&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![Security](https://img.shields.io/badge/Shutdown-Desativado-yellow?style=flat)

Este guia reúne os procedimentos de operação, comandos de teste em tempo real, importação do template no Zabbix 7.0 e solução de problemas para o monitoramento de nobreaks **APC Smart-UPS SMC2200BI-BR** e qualquer outro fabricante compatível com a lista [HCL do NUT](https://networkupstools.org/stable-hcl.html) via cabo USB no Ubuntu Server 24.04 e 26.04.

---

## ⚡ Execução Rápida do Script de Instalação

```bash
wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_nut_ups_zabbix.sh -O install_nut_ups_zabbix.sh && sudo chmod +x install_nut_ups_zabbix.sh && sudo ./install_nut_ups_zabbix.sh
```

---

## 📁 1. Arquivos de Configuração e Diretórios

| Arquivo / Diretório | Descrição |
| :--- | :--- |
| `/etc/nut/nut.conf` | Define o modo de operação (`MODE=standalone`). |
| `/etc/nut/ups.conf` | Configura o driver (`usbhid-ups`), porta (`auto`) e nobreak. |
| `/etc/nut/upsd.conf` | Define as portas e endereços de escuta local do NUT. |
| `/etc/nut/upsd.users` | Credenciais internas de serviço (geradas aleatoriamente via OpenSSL). |
| `/etc/nut/upsmon.conf` | Gerenciador de eventos (**desligamento do servidor desativado**). |
| `/etc/udev/rules.d/90-nut-ups.rules` | Regras UDEV de permissão automática na porta USB para o grupo `nut`. |
| `/etc/zabbix/scripts/nut-ups-status.sh` | Script otimizado de leitura e parsing de métricas para o Zabbix. |
| `/etc/zabbix/zabbix_agentd.d/userparameter_nut.conf` | Parâmetros de coleta do Zabbix Agent (`UserParameter`). |

---

## 🔍 2. Diagnóstico e Verificação do Nobreak USB

### 2.1 Verificar se o cabo USB foi reconhecido pelo Kernel
Execute:
```bash
lsusb
```
*Deverá exibir uma linha identificando o fabricante (ex: `051d:0002 American Power Conversion Uninterruptible Power Supply` para APC).*

### 2.2 Consultar todas as métricas do Nobreak em tempo real (`upsc`)
```bash
# Consultar todas as variáveis reportadas pelo nobreak:
upsc Cliente_Nobreak@localhost

# Consultar uma métrica específica (ex: carga da bateria):
upsc Cliente_Nobreak@localhost battery.charge

# Consultar a tensão da rede elétrica:
upsc Cliente_Nobreak@localhost input.voltage

# Consultar o status operacional (OL = On Line, OB = On Battery, LB = Low Battery):
upsc Cliente_Nobreak@localhost ups.status
```

---

## 📊 3. Teste das Métricas pelo Zabbix Agent

Você pode testar localmente como o agente do Zabbix responderá antes mesmo de abrir a interface Web:

```bash
# Teste de status operacional:
zabbix_agentd -t 'nut.get[Cliente_Nobreak,ups.status]'

# Teste de tensão de entrada:
zabbix_agentd -t 'nut.get[Cliente_Nobreak,input.voltage]'

# Teste de carga em Watts calculada:
zabbix_agentd -t 'nut.power_watts[Cliente_Nobreak,2200]'

# Teste de código numérico para o gráfico de status:
zabbix_agentd -t 'nut.ups_status_code[Cliente_Nobreak]'
```

---

## 📥 4. Importando o Template no Zabbix Server 7.0

1. Acesse o **Zabbix Frontend** (`http://<ip-do-zabbix>/zabbix`).
2. No menu lateral, acesse **Data collection** ➔ **Templates**.
3. No canto superior direito, clique em **Import**.
4. Selecione o arquivo [`zbx_nut_ups_template.yaml`](../zbx_nut_ups_template.yaml).
5. Deixe marcadas as opções padrão e clique em **Import**.
6. Acesse **Data collection** ➔ **Hosts**, localize o seu Host (`Cliente_Nobreak` ou o servidor onde o nobreak está conectado) e adicione o template:
   * **Template associado:** `APC & Universal UPS by NUT (Zabbix Agent)`.
7. Na aba **Macros** do Host, você pode ajustar:
   * `{$UPS_NAME}`: Nome dado ao nobreak no arquivo `/etc/nut/ups.conf` (padrão: `Cliente_Nobreak`).
   * `{$UPS_NOMINAL_POWER}`: Potência do equipamento em Watts (padrão: `2200`).

---

## 🛡️ 5. Como funciona a Política de Desligamento Desativada?

Por requisição explícita deste projeto, o comando padrão de desligamento do NUT foi substituído no `/etc/nut/upsmon.conf`:
```text
SHUTDOWNCMD "/usr/bin/logger -t nut-upsmon 'ALERTA CRITICO: Nobreak em nivel critico de bateria! Desligamento automatico desativado por configuracao.'"
```

* **Comportamento:** Quando houver falta de energia ou a bateria estiver em nível crítico, o sistema operacional **NÃO** executa `poweroff`, `shutdown` ou `init 0`.
* O daemon apenas emite alertas no syslog (`/var/log/syslog`) e na console (`wall`).
* Todos os alarmes, disparos de e-mail e alertas de Telegram são geridos de forma centralizada pelo **Zabbix Server**.

---

## 🔄 6. Como Adicionar Outros Nobreaks (SMS, Eaton, etc.)

O NUT é universal. Para monitorar outro nobreak de marca diferente no mesmo servidor ou em outro servidor Ubuntu:
1. Verifique o driver recomendado na [HCL do NUT](https://networkupstools.org/stable-hcl.html) (ex: `megatec`, `blazer_usb`, `riello_usb`, `bcmxcp_usb`).
2. Edite `/etc/nut/ups.conf`:
   ```ini
   [Nobreak_SMS]
       driver = blazer_usb
       port = auto
       desc = "Nobreak SMS Gateway"
   ```
3. Reinicie os serviços:
   ```bash
   sudo upsdrvctl restart
   sudo systemctl restart nut-server
   ```
4. Teste com `upsc Nobreak_SMS@localhost`.
