# 🚀 Guia de Pós-Instalação do Ubuntu Server & Manual dos Utilitários

Este guia documenta todas as configurações realizadas pelo script [`pos_install_server.sh`](../pos_install_server.sh) e serve como manual de referência rápida (*Cheat Sheet*) para os utilitários e ferramentas de diagnóstico, rede, performance e segurança instalados no servidor.

---

## 📌 1. Como Executar o Script

Comando único e direto para download e execução:
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh -O pos_install_server.sh && chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
```

---

## 🛡️ 2. Resumo das Configurações de Segurança e Sistema

| Área | O que o script aplica |
| :--- | :--- |
| **Locales & Fuso Horário** | `en_US.UTF-8` (sistema em inglês) com suporte completo a `pt_BR.UTF-8`, Fuso `America/Sao_Paulo` com sincronização NTP (`systemd-timesyncd`). |
| **Layouts de Teclado** | `ABNT2` (Padrão Ativo) + `US-International` com acentos (Alterna usando `Alt + Shift`). |
| **Proteção `/dev/shm`** | Memória RAM compartilhada montada no `/etc/fstab` com `noexec,nosuid,nodev` para mitigar execução de botnets e webshells. |
| **Hardening SSH** | Desabilita senhas em branco (`PermitEmptyPasswords no`), timeout de ociosidade de 10 min (`ClientAliveInterval 300` / `ClientAliveCountMax 2`) e bloqueio opcional de Root. |
| **Firewall UFW** | Dual-Stack (IPv4 e IPv6) com portas essenciais liberadas (`22/tcp` SSH, `10050/tcp` Zabbix Agent). |
| **Fail2Ban** | Jaula do SSH ativada protegendo contra ataques de força bruta (5 tentativas erradas = bloqueio de 1 hora). |
| **Atualizações de Segurança** | `unattended-upgrades` ativo para aplicação automática em segundo plano apenas de patches de segurança. |
| **Editor Vim** | Customizado com tema moderno **Sonokai (Andromeda)**, barra **Airline** e plugins pré-instalados para `/root`, `/etc/skel` e todos os usuários em `/home`. |
| **Banner no Login (MOTD)** | Diagnóstico automático ao logar via SSH: Hostname, Kernel, Uptime, RAM, **SWAP**, **todas as partições/discos montados** com cálculo de espaço livre e **todas as placas de rede com seus IPs**. |

---

## ⌨️ 3. Aliases de Produtividade Configurados no Shell

Os seguintes atalhos estão ativos em todos os perfis `.bashrc`:

| Alias | Comando Executado | Descrição |
| :--- | :--- | :--- |
| `ll` | `ls -alFh` | Lista detalhada com arquivos ocultos, tamanhos legíveis (KB, MB, GB). |
| `rm` | `rm -I` | Remove arquivos pedindo confirmação inteligente caso sejam mais de 3 itens ou recursivo. |
| `cp` | `cp -i` | Pede confirmação antes de sobrescrever arquivos existentes. |
| `mv` | `mv -i` | Pede confirmação antes de mover sobre arquivos existentes. |
| `df` | `df -h` | Exibe uso de disco em formato humano. |
| `free` | `free -h` | Exibe uso de memória RAM e SWAP em formato humano. |
| `ports` | `sudo ss -tulanp` | Lista todas as portas TCP/UDP abertas e os processos responsáveis. |
| `myip` | `curl -s ifconfig.me; echo` | Consulta e exibe o endereço IPv4 público do servidor. |
| `..` | `cd ..` | Volta um nível de diretório. |
| `...` | `cd ../..` | Volta dois níveis de diretório. |
| `update` | `sudo apt-get update && sudo apt-get upgrade -y` | Atualiza repositórios e pacotes do servidor com um único comando. |
| `clean` | `sudo apt-get autoremove -y && sudo apt-get autoclean` | Remove pacotes órfãos e limpa o cache do APT. |
| `reload` | `source ~/.bashrc` | Recarrega as configurações do shell sem precisar deslogar. |

---

## 📊 4. Manual de Uso das Ferramentas Instaladas

### 🔍 4.1. Monitoramento de Recursos e Processos

#### • `btop` / `htop` (Monitores Visuais de Processos)
* **Como usar**: Execute `btop` ou `htop`.
* **Principais funções**:
  - `btop`: Interface gráfica moderna em terminal, monitor de CPU, RAM, Discos, Processos e consumo de Rede por processo.
  - Teclas úteis no `btop`: `m` (menu/opções), `Esc` ou `q` (sair), setas para navegar nos processos.
  - Teclas úteis no `htop`: `F6` (ordenar por CPU/Memória), `F9` (finalizar processo `kill`), `F3` (pesquisar).

#### • `iotop` (Diagnóstico de I/O e Gargalo de Disco)
* **Quando usar**: Quando o servidor estiver lento ou com alto *I/O Wait*, para descobrir qual processo está sobrecarregando o disco.
* **Comandos**:
  ```bash
  sudo iotop        # Visualização completa de I/O
  sudo iotop -o     # Mostra APENAS processos que estão realmente gravando/lendo no disco no momento
  sudo iotop -b -n 3 # Modo batch para scripts/logs (gera 3 iterações)
  ```

#### • `sysstat` (`sar`, `iostat`, `mpstat`) (Histórico de Desempenho)
* **O que faz**: O serviço coleta métricas a cada 10 minutos e salva em `/var/log/sysstat/`.
* **Comandos principais**:
  ```bash
  iostat -xz 1 5   # Diagnóstico detalhado de I/O por disco em tempo real
  sar -u           # Histórico de uso de CPU do dia
  sar -r           # Histórico de consumo de Memória RAM do dia
  sar -q           # Histórico de Load Average do dia
  sar -u -f /var/log/sysstat/sa20  # Consulta o histórico do dia 20 do mês
  ```

#### • `ncdu` (Análise de Espaço em Disco)
* **Como usar**: `sudo ncdu /` ou `ncdu /var/log`
* **Navegação**: Use as setas para entrar em pastas, `d` para apagar um arquivo/pasta pesado com segurança, `q` para sair.

---

### 🌐 4.2. Rede e Diagnóstico de Conectividade

#### • `mtr` (Ping + Traceroute Dinâmico em Tempo Real)
* **Como usar**: `mtr 8.8.8.8` ou `mtr google.com`
* **Vantagem**: Identifica exatamente em qual roteador/salto está ocorrendo perda de pacotes (`Loss%`) ou latência alta.
* Modo relatório (sem tela interativa):
  ```bash
  mtr -rw -c 10 1.1.1.1
  ```

#### • `iperf3` (Teste de Velocidade de Rede entre Servidores)
* **No Servidor A (Receptor)**:
  ```bash
  iperf3 -s
  ```
* **No Servidor B (Emissor)**:
  ```bash
  iperf3 -c IP_DO_SERVIDOR_A
  ```
* Mostra a velocidade real em Gbps/Mbps e perda de pacotes da sua infraestrutura.

#### • `nmap` (Auditor de Portas e Serviços)
* **Varredura rápida no próprio servidor**:
  ```bash
  nmap -sT localhost
  ```
* **Verificar portas abertas em outro host**:
  ```bash
  nmap -sV -Pn IP_DO_ALVO
  ```
* **Testar se uma porta específica está aberta**:
  ```bash
  nmap -p 80,443,10050 192.168.1.50
  ```

#### • `tcpdump` (Captura de Tráfego de Rede)
* **Inspecionar tráfego de uma interface específica**:
  ```bash
  sudo tcpdump -i eth0 -n
  ```
* **Filtrar tráfego de uma porta (ex: porta 80 ou 443)**:
  ```bash
  sudo tcpdump -i eth0 port 80 -n
  ```
* **Filtrar tráfego de um IP específico**:
  ```bash
  sudo tcpdump -i eth0 host 192.168.1.100 -n
  ```

#### • `dnsutils` (`dig` / `nslookup`)
* Testar resolução de DNS direto em um servidor específico:
  ```bash
  dig @1.1.1.1 google.com +short
  dig -x 8.8.8.8 +short   # Consulta reversa (PTR)
  ```

---

### 🛡️ 4.3. Auditoria de Segurança & Firewall

#### • `lynis` (Auditor de Segurança e Hardening)
* **Executar auditoria completa com pausamento por seção**:
  ```bash
  sudo lynis audit system
  ```
* **Executar auditoria completa rápida (modo silencioso/resumo)**:
  ```bash
  sudo lynis audit system -Q
  ```
* **Consultar apenas sugestões e avisos identificados**:
  ```bash
  sudo lynis show suggestions
  sudo lynis show warnings
  ```
* Os relatórios completos ficam gravados em `/var/log/lynis.log` e `/var/log/lynis-report.dat`.

#### • `fail2ban` (Proteção contra Força Bruta)
* **Ver o status da jaula do SSH e IPs atualmente banidos**:
  ```bash
  sudo fail2ban-client status sshd
  ```
* **Desbanir manualmente um IP (ex: caso alguém erre a senha 5x)**:
  ```bash
  sudo fail2ban-client set sshd unbanip 192.168.1.100
  ```
* **Consultar logs de bloqueio**:
  ```bash
  sudo tail -f /var/log/fail2ban.log
  ```

#### • `ufw` (Firewall Descomplicado)
* **Ver status detalhado das regras e portas**:
  ```bash
  sudo ufw status numbered
  ```
* **Liberar uma nova porta (ex: HTTP/HTTPS ou MySQL)**:
  ```bash
  sudo ufw allow 80/tcp comment 'Servidor Web HTTP'
  sudo ufw allow 443/tcp comment 'Servidor Web HTTPS'
  sudo ufw allow from 192.168.1.0/24 to any port 3306 proto tcp comment 'MySQL Apenas Rede Local'
  ```
* **Deletar uma regra pelo número**:
  ```bash
  sudo ufw status numbered
  sudo ufw delete 3
  ```

---

### ⚡ 4.4. Produtividade e Manipulação de Dados

#### • `jq` (Processador de JSON via CLI)
* **Formatar e colorir uma resposta JSON**:
  ```bash
  curl -s https://api.github.com/users/octocat | jq .
  ```
* **Extrair campos específicos**:
  ```bash
  curl -s https://api.github.com/users/octocat | jq '.name, .public_repos'
  ```

#### • `tmux` (Terminal Multiplexer)
* Evita que comandos ou scripts longos morram se o SSH for desconectado.
* **Criar sessão**: `tmux new -s backup`
* **Desconectar da sessão sem encerrar**: `Ctrl + b` depois `d`
* **Reconectar à sessão**: `tmux a -t backup`
* *(Consulte o guia completo em [ajuda_tmux.md](ajuda_tmux.md))*.

#### • `tree` (Árvore de Diretórios)
* Visualizar pastas limitando a profundidade:
  ```bash
  tree -L 2 /var/www
  tree -d /etc       # Apenas diretórios
  ```

#### • `rsync` (Sincronização Rápida e Backups)
* Sincronizar pasta local para servidor remoto com barra de progresso:
  ```bash
  rsync -avzhP /var/www/ administrador@192.168.1.50:/backup/www/
  ```

---

## 🔒 5. Políticas do Visudo para Usuários Criados

Quando o script cria um grupo customizado (ex: `TI`, `DEV`) com usuário associado, ele aplica automaticamente restrições em `/etc/sudoers.d/`:

* ✅ O usuário pode executar comandos administrativos normais com `sudo`.
* ❌ **Bloqueado**: Alterar a senha do usuário `root` ou `geset` (`!/usr/bin/passwd root`, `!/usr/bin/passwd geset`).
* ❌ **Bloqueado**: Leitura direta do arquivo de senhas do sistema (`/etc/shadow`) via `cat`, `less`, `nano`, `vi`, `cp`, etc.
* ❌ **Bloqueado**: Execução de `sudo -i`, `sudo -s` ou `sudo /bin/bash` diretos.
