# 🛡️ Guia Prático e Comandos de Segurança de Rede (UFW, IPTables & Diagnóstico)

Este guia reúne os comandos essenciais para administração de **firewall**, liberação de portas, bloqueio de IPs, redirecionamento de tráfego (NAT) e diagnóstico de rede no Linux usando **UFW**, **IPTables** e utilitários de sistema.

---

## 🧱 1. Gerenciamento de Firewall com UFW (Uncomplicated Firewall)

O **UFW** é o gerenciador de firewall padrão e amigável do Ubuntu/Debian.

### 🛠️ Status e Operação Básica

* **Verificar o status detalhado do UFW (com números das regras):**
  ```bash
  sudo ufw status numbered
  ```

* **Ativar / Desativar o UFW:**
  ```bash
  sudo ufw enable
  sudo ufw disable
  ```

* **Recarregar regras sem interromper conexões:**
  ```bash
  sudo ufw reload
  ```

* **Resetar o UFW para as configurações padrão de fábrica:**
  ```bash
  sudo ufw reset
  ```

---

### 🔓 Liberação de Portas e Serviços (UFW)

* **Liberar uma porta TCP específica (ex: SSH 22, HTTP 80, HTTPS 443):**
  ```bash
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  ```

* **Liberar um intervalo de portas TCP/UDP:**
  ```bash
  sudo ufw allow 10000:10050/tcp
  ```

* **Liberar acesso vindo de um IP específico para uma porta (ex: permitir apenas o IP da empresa no SSH):**
  ```bash
  sudo ufw allow from 200.201.202.203 to any port 22 proto tcp
  ```

* **Liberar uma subrede inteira (CIDR):**
  ```bash
  sudo ufw allow from 192.168.1.0/24
  ```

---

### ⛔ Bloqueio de IPs e Portas (UFW)

* **Bloquear totalmente um IP malicioso:**
  ```bash
  sudo ufw deny from 192.168.1.150
  ```

* **Bloquear uma porta específica:**
  ```bash
  sudo ufw deny 23/tcp
  ```

---

### 🗑️ Remoção de Regras (UFW)

* **Remover regra especificando o número da linha (Mais seguro):**
  1. Liste as regras numeradas:
     ```bash
     sudo ufw status numbered
     ```
  2. Delete pelo número correspondente:
     ```bash
     sudo ufw delete 3
     ```

* **Remover regra especificando o comando original:**
  ```bash
  sudo ufw delete allow 80/tcp
  ```

---

## ⚡ 2. Redirecionamento de Portas e NAT (Port Forwarding via UFW)

Para redirecionar uma porta pública recebida na VPS para um IP interno ou outra porta local (ex: porta 80 ➔ 8080):

1. Edite o arquivo `/etc/default/ufw` e garanta que o repasse de pacotes esteja ativo:
   ```text
   DEFAULT_FORWARD_POLICY="ACCEPT"
   ```
2. Edite o arquivo `/etc/ufw/before.rules` e adicione no topo do arquivo (antes dos blocos de filtro):
   ```ini
   *nat
   :PREROUTING ACCEPT [0:0]
   # Redirecionar porta 80 externa para a porta 8080 local:
   -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
   COMMIT
   ```
3. Recarregue o UFW:
   ```bash
   sudo ufw reload
   ```

---

## ⚙️ 3. Comandos Tradicionais com IPTables

O `iptables` é o utilitário nativo de filtragem de pacotes do Kernel Linux.

* **Listar todas as regras ativas do IPTables:**
  ```bash
  sudo iptables -L -n -v
  ```

* **Listar regras com números de linha:**
  ```bash
  sudo iptables -L -n --line-numbers
  ```

* **Bloquear um IP imediatamente via IPTables:**
  ```bash
  sudo iptables -A INPUT -s 192.168.1.150 -j DROP
  ```

* **Liberar a porta 80/tcp no IPTables:**
  ```bash
  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  ```

* **Deletar uma regra do IPTables pela linha:**
  ```bash
  sudo iptables -D INPUT 2
  ```

* **Limpar TODAS as regras do IPTables (Flush):**
  ```bash
  sudo iptables -F
  ```

---

## 🔍 4. Diagnóstico de Rede e Monitoramento de Portas Aberta

* **Verificar todas as portas TCP e UDP escutando no sistema (com o processo correspondente):**
  ```bash
  sudo ss -tulnp
  # Ou comando clássico:
  sudo netstat -tulnp
  ```

* **Verificar qual processo específico está usando uma porta:**
  ```bash
  sudo lsof -i :80
  ```

* **Testar conectividade e abertura de porta em um servidor remoto (`nc` / `ncat`):**
  ```bash
  nc -zv 192.168.1.8 80
  ```

* **Capturar pacotes de rede em tempo real em uma interface (`tcpdump`):**
  ```bash
  sudo tcpdump -i eth0 port 80 -n
  ```
