# 🛡️ Guia Prático e Comandos de Operação do Fail2Ban (Linux Server)

![Fail2Ban](https://img.shields.io/badge/Fail2Ban-000000?style=flat&logo=shield&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Security](https://img.shields.io/badge/Security-Hardening-red?style=flat&logo=auth0&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de consulta rápida e manual operacional do **Fail2Ban** no **Ubuntu / Debian**, cobrindo gerenciamento de jails, comandos do `fail2ban-client`, desbloqueio de IPs, whitelist (`ignoreip`), filtros personalizados e boas práticas contra ataques de força bruta.

---

## 📁 1. Estrutura de Arquivos e Diretórios Vitais

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/fail2ban/` | Diretório raiz de configurações do Fail2Ban. |
| `/etc/fail2ban/jail.conf` | Configuração padrão de fábrica (**NÃO edite diretamente**; pode ser sobrescrito em updates). |
| `/etc/fail2ban/jail.local` | Arquivo de personalização do administrador (**Prioridade sobre jail.conf**). |
| `/etc/fail2ban/jail.d/` | Diretório para arquivos de jails modulares (ex: `sshd.local`, `nginx.local`). |
| `/etc/fail2ban/filter.d/` | Definições de regex e filtros de detecção de logs (ex: `sshd.conf`, `nginx-botsearch.conf`). |
| `/etc/fail2ban/action.d/` | Ações executadas ao banir (regras de `iptables`, `nftables`, `ufw`, notificações). |
| `/var/log/fail2ban.log` | Log oficial de eventos, inicialização, banimentos e unbans do Fail2Ban. |

---

## 🛠️ 2. Gerenciamento do Serviço (systemctl)

### Comandos de Controle do Serviço
```bash
# Verificar status do serviço Fail2Ban
sudo systemctl status fail2ban

# Iniciar / Parar o Fail2Ban
sudo systemctl start fail2ban
sudo systemctl stop fail2ban

# Reiniciar o serviço por completo (CRÍTICO se alterar portas ou backend)
sudo systemctl restart fail2ban

# Habilitar inicialização automática com o boot do sistema
sudo systemctl enable fail2ban
```

> 💡 *Sempre que alterar o arquivo `/etc/fail2ban/jail.local` ou filtros, execute `sudo fail2ban-client reload` para recarregar as regras sem matar as conexões ativas.*

---

## 📊 3. Inspeção e Monitoramento com fail2ban-client

### Consultar Status Global e Jails Ativas
```bash
# Testar se o daemon do Fail2Ban está respondendo
sudo fail2ban-client ping
# Retorno esperado: Server replied: pong

# Listar todas as jails ativas no momento
sudo fail2ban-client status
```

### Consultar Status e IPs Banidos de uma Jail Específica
```bash
# Ver o status da jail do SSH (sshd) e lista de IPs banidos atualmente
sudo fail2ban-client status sshd

# Ver o status de outras jails ativas (ex: Nginx, Apache)
sudo fail2ban-client status nginx-http-auth
sudo fail2ban-client status nginx-botsearch
sudo fail2ban-client status apache-auth
```

---

## 🔓 4. Desbloqueio e Banimento Manual de IPs

### Desbanir (Unban) de IPs Bloqueados
```bash
# Desbloquear um IP específico na jail sshd
sudo fail2ban-client set sshd unbanip <SEU_IP_BLOQUEADO>

# Exemplo prático de desbanimento:
sudo fail2ban-client set sshd unbanip 192.168.1.150

# Desbloquear um IP em todas as jails ativas de uma só vez
sudo fail2ban-client unban <SEU_IP_BLOQUEADO>

# Desbanir TODOS os IPs atualmente bloqueados na jail sshd (🔴 Ação em lote)
sudo fail2ban-client set sshd unbanip --all
```

### Banir Manualmente um IP Malicioso
```bash
# Bloquear imediatamente um IP invasor na jail sshd
sudo fail2ban-client set sshd banip 203.0.113.50

# Banir por uma sub-rede inteira (CIDR)
sudo fail2ban-client set sshd banip 203.0.113.0/24
```

---

## ⚙️ 5. Configuração Essencial e Whitelist (`jail.local`)

Crie ou edite o arquivo `/etc/fail2ban/jail.local` para sobrescrever as diretivas padrões com segurança:

```bash
# Criar cópia base caso ainda não exista
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

### Exemplo de Configuração Recomendada (`/etc/fail2ban/jail.local`):
```ini
[DEFAULT]
# IPs e Sub-redes em Whitelist que NUNCA devem ser banidos (separados por espaço)
ignoreip = 127.0.0.1/8 ::1 192.168.1.0/24 200.201.202.203

# Tempo que o IP ficará banido (ex: 1h = 1 hora, 1d = 1 dia, -1 = permanente)
bantime  = 1h

# Janela de tempo de monitoramento para contar as tentativas falhas
findtime = 10m

# Quantidade máxima de falhas dentro do findtime antes de banir
maxretry = 5

# Mecanismo de bloqueio (ufw ou iptables-multiport)
banaction = ufw
banaction_allports = ufw

# Backend de monitoramento (systemd é recomendado para Ubuntu 20.04/22.04/24.04)
backend = systemd

# -------------------------------------------------------------
# JAIL: Proteção SSH
# -------------------------------------------------------------
[sshd]
enabled  = true
port     = ssh
# Se você alterou a porta padrão do SSH (ex: 2222), declare abaixo:
# port   = 2222
mode     = aggressive
maxretry = 3
findtime = 15m
bantime  = 24h
```

### Recarregar Configurações do Fail2Ban
```bash
# Recarregar configurações sem reiniciar o processo
sudo fail2ban-client reload

# Recarregar apenas uma jail específica
sudo fail2ban-client reload sshd
```

---

## 🌐 6. Exemplos de Jails para Servidores Web (Nginx & Apache)

Adicione ao final de `/etc/fail2ban/jail.local` ou em `/etc/fail2ban/jail.d/web.local`:

### Jails para Nginx:
```ini
# Proteção contra erros de autenticação básica HTTP
[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 3

# Proteção contra scanners de vulnerabilidades e bots maliciosos
[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2
```

### Jails para Apache:
```ini
# Tentativas de login inválidas
[apache-auth]
enabled  = true
port     = http,https
logpath  = /var/log/apache2/error.log
maxretry = 3

# Proteção contra scripts maliciosos e exploits conhecidos
[apache-badbots]
enabled  = true
port     = http,https
logpath  = /var/log/apache2/access.log
maxretry = 2
```

---

## 🔍 7. Análise de Logs e Diagnóstico

### Monitorar o Log do Fail2Ban em Tempo Real
```bash
# Acompanhar eventos de ban e unban em tempo real
sudo tail -f /var/log/fail2ban.log

# Filtrar apenas os banimentos ocorridos no log
sudo grep "Ban " /var/log/fail2ban.log

# Filtrar eventos das últimas 50 linhas
sudo tail -n 50 /var/log/fail2ban.log | grep -E "Ban|Unban"
```

### Testar Expressões Regulares de Filtros (`fail2ban-regex`)
Antes de ativar um filtro customizado, teste se a regex captura os erros no log real:
```bash
# Testar filtro do SSH contra o journald
sudo fail2ban-regex systemd-journal /etc/fail2ban/filter.d/sshd.conf

# Testar filtro do Nginx contra o arquivo de log
sudo fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/nginx-botsearch.conf
```

---

## 🚀 8. Dicas Rápidas e Truques de Produção

* 💡 **Evite auto-bloqueio (Lockout)**: Sempre adicione o IP estático da sua VPN ou sub-rede de gerência à diretiva `ignoreip` em `[DEFAULT]`.
* 💡 **Ban Recorrente Progressivo (Recidive Jail)**: Para banir por períodos muito longos (ex: 1 semana a 1 mês) invasores reincidentes que são banidos repetidamente:
  ```ini
  [recidive]
  enabled  = true
  logpath  = /var/log/fail2ban.log
  banaction = ufw
  bantime  = 1w
  findtime = 1d
  maxretry = 3
  ```
* 💡 **Verificar Regras Aplicadas no Firewall (UFW / IPTables)**:
  ```bash
  # Verificar se os bans constam no UFW
  sudo ufw status verbose

  # Verificar a cadeia do fail2ban no iptables
  sudo iptables -L -n -v | grep -A 10 "f2b-"
  ```
