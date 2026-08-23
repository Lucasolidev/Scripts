# 📊 Guia Prático e Comandos de Operação do Zabbix (Server, Agent & Proxy)

Este guia reúne os comandos essenciais para administração, diagnóstico, monitoramento e teste de métricas usando o **Zabbix Server**, **Zabbix Agent 2** e **Zabbix Proxy**.

---

## 📁 1. Arquivos de Configuração e Logs Vitais

### 📄 Arquivos de Configuração

* **`/etc/zabbix/zabbix_agent2.conf`** (ou `zabbix_agentd.conf`)  
  Arquivo de configuração do **Zabbix Agent 2** no cliente/servidor.

* **`/etc/zabbix/zabbix_proxy.conf`**  
  Arquivo de configuração do **Zabbix Proxy**.

* **`/etc/zabbix/zabbix_server.conf`**  
  Arquivo de configuração do **Zabbix Server**.

* **`/etc/zabbix/zabbix_agent2.d/`**  
  Diretório para incluir arquivos de configuração de plugins e métricas customizadas (`UserParameter`).

---

### 📜 Arquivos de Log

* **`/var/log/zabbix/zabbix_agent2.log`** — Log de execução do Zabbix Agent 2.
* **`/var/log/zabbix/zabbix_proxy.log`** — Log de execução do Zabbix Proxy.
* **`/var/log/zabbix/zabbix_server.log`** — Log de execução do Zabbix Server.

---

## ⚙️ 2. Comandos do Servidor e Serviços

* **Status e reinicialização dos serviços Zabbix:**
  ```bash
  # Zabbix Agent 2:
  sudo systemctl status zabbix-agent2
  sudo systemctl restart zabbix-agent2

  # Zabbix Proxy:
  sudo systemctl status zabbix-proxy
  sudo systemctl restart zabbix-proxy

  # Zabbix Server:
  sudo systemctl status zabbix-server
  sudo systemctl restart zabbix-server
  ```

* **Recarregar o Cache de Configuração do Zabbix Proxy em tempo real:**
  ```bash
  sudo zabbix_proxy -R config_cache_reload
  ```

* **Recarregar o Cache de Configuração do Zabbix Server:**
  ```bash
  sudo zabbix_server -R config_cache_reload
  ```

---

## 🔍 3. Teste e Coleta de Métricas Remotas (`zabbix_get`)

O utilitário `zabbix_get` permite testar a coleta de métricas em um agente remoto diretamente da linha de comando do Server ou Proxy.

* **Testar se o agente remoto responde à porta 10050 (Ping):**
  ```bash
  zabbix_get -s 192.168.1.50 -k agent.ping
  ```
  *(Retorno esperado: `1`)*

* **Consultar a versão do Zabbix Agent remoto:**
  ```bash
  zabbix_get -s 192.168.1.50 -k agent.version
  ```

* **Consultar o Hostname configurado no agente remoto:**
  ```bash
  zabbix_get -s 192.168.1.50 -k agent.hostname
  ```

* **Consultar o uso de CPU (Carga do sistema):**
  ```bash
  zabbix_get -s 192.168.1.50 -k system.cpu.load[all,avg1]
  ```

* **Consultar memória total e disponível:**
  ```bash
  zabbix_get -s 192.168.1.50 -k vm.memory.size[total]
  zabbix_get -s 192.168.1.50 -k vm.memory.size[available]
  ```

* **Consultar espaço em disco usado na raiz `/`:**
  ```bash
  zabbix_get -s 192.168.1.50 -k vfs.fs.size[/,pused]
  ```

---

## 📤 4. Envio Manual de Métricas (`zabbix_sender`)

O `zabbix_sender` é usado para enviar métricas ativas ou personalizadas (criadas por scripts) direto para o Zabbix Server ou Proxy sem depender da varredura padrão.

* **Enviar um valor numérico para uma chave do tipo Zabbix Trapper:**
  ```bash
  zabbix_sender -z 192.168.1.8 -s "NomeDoHostNoZabbix" -k "backup.status" -o 1
  ```
  *(Onde `-z` é o IP do Zabbix Server/Proxy, `-s` é o nome exato do Host cadastrado e `-k` é a chave trapper).*

* **Enviar métricas a partir de um arquivo em lote (`-i`):**
  ```bash
  zabbix_sender -z 192.168.1.8 -i /tmp/metricas.txt
  ```

---

## 📝 5. Criação de Parâmetros Customizados (`UserParameter`)

Você pode estender o Zabbix Agent criando comandos customizados no arquivo `/etc/zabbix/zabbix_agent2.d/custom.conf`:

```ini
# Exemplo 1: Contar quantos processos do Nginx estão rodando
UserParameter=custom.nginx.processes,pgrep -c nginx

# Exemplo 2: Verificar se um determinado serviço systemd está ativo (1 para active, 0 para inativo)
UserParameter=custom.service.status[*],systemctl is-active --quiet "$1" && echo 1 || echo 0
```

Após editar, recarregue o agente:
```bash
sudo systemctl restart zabbix-agent2
```
E teste localmente com o agente:
```bash
zabbix_agent2 -t custom.nginx.processes
```
