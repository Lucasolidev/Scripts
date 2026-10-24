# 🚀 Guia Prático e Cheat Sheet - Pós-Instalação e Utilitários (Debian Server)

![Debian](https://img.shields.io/badge/Debian-D70A53?style=flat&logo=debian&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Vim](https://img.shields.io/badge/Vim-019733?style=flat&logo=vim&logoColor=white)
![Versão](https://img.shields.io/badge/Script-2.5-0078D4?style=flat)

Guia operacional rápido, referência de configurações e *cheat sheet* completo para servidores configurados com o script [`pos_install_server_debian.sh`](../pos_install_server_debian.sh). **Versão 2.5, destinada ao Debian Server 12 (Bookworm) e 13 (Trixie) com systemd.** Aborda particularidades do Debian como garantia do `sudo`, sincronização de horário via `systemd-timesyncd`, repositórios `main` oficiais, hardening do SSH, firewall UFW e os comandos práticos dos utilitários de **diagnóstico**, **rede**, **segurança (Lynis/Fail2Ban/UFW/Auditd)**, **desempenho** e **produtividade**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_pos_install_server_debian_*.log` | Log completo e detalhado com timestamp da execução do script pós-instalação. |
| `/root/relatorio_pos_install_server_debian_latest.log` | Cópia regular do último relatório, modo `0600`; salva também quando há falha após iniciar a captura. |
| `/root/backup_pos_install_server_debian_*` | Backups administrativos por execução para recuperação rápida de arquivos alterados. |
| `/etc/ssh/sshd_config` | Arquivo principal SSH: contém diretamente `PermitRootLogin`, `PermitEmptyPasswords`, `ClientAliveInterval` e `ClientAliveCountMax`. |
| `/etc/audit/rules.d/server_security.rules` | Regras ativas de auditoria do Auditd (contas, sudoers, SSH, rede `/etc/network` e persistência). |
| `/etc/pos-install-server/` | Aliases compartilhados do Shell e configurações centralizadas do Vim. |
| `/usr/local/share/pos-install-server/vim/2.5` | Plugins opcionais fixados por commit (Sonokai, Airline, Polyglot, Devicons). |
| `/usr/local/bin/motd_banner.sh` | Script autônomo do banner dinâmico com métricas em tempo real (Host, OS, RAM, Discos, IPs, Firewall). |
| `/etc/profile.d/motd_banner.sh` | Disparador automático do banner no login interativo via SSH ou console local. |
| `/etc/fail2ban/jail.d/99-pos-install-server.local` | Jaula SSH gerenciada com backend `systemd` e proteção contra ataques de força bruta. |
| `/etc/default/ufw` | Configurações do firewall UFW (incluindo suporte a IPv6 ativo `IPV6=yes`). |
| `/etc/default/keyboard` | Mapeamento dual de layout de teclado (`ABNT2` + `US-International`). |
| `/etc/default/locale` | Arquivo oficial de configuração dos locales padrão no Debian (`en_US.UTF-8` e `pt_BR.UTF-8`). |
| `/etc/sudoers.d/grupo_*` | Administração ampla com barreiras de operações diretas para grupos operacionais. |
| `/var/log/sysstat/` | Diretório onde o `sysstat` armazena o histórico diário de métricas de CPU, RAM e I/O. |
| `/var/log/lynis.log` | Relatório detalhado das varreduras de auditoria de segurança geradas pelo Lynis. |

---

## ⚙️ 2. Execução e Parâmetros do Script

### Particularidade do Debian: Root vs Sudo na Instalação Inicial
Em instalações limpas do Debian onde uma senha de `root` foi definida no instalador da ISO, o utilitário `sudo` **não vem instalado por padrão**. O script foi projetado para contornar isso automaticamente: você pode executá-lo diretamente como `root` e ele garantirá a instalação do `sudo` e a criação do grupo `%sudo`.

### Execução da Versão Publicada (Comando Único Oficial)
```bash
wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/pos_install_server_debian.sh -O pos_install_server_debian.sh && sudo chmod +x pos_install_server_debian.sh && sudo ./pos_install_server_debian.sh
```

> 💡 *Se estiver logado como `root` e o comando `sudo` ainda não estiver instalado, execute diretamente:*
> ```bash
> wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/pos_install_server_debian.sh -O pos_install_server_debian.sh && chmod +x pos_install_server_debian.sh && ./pos_install_server_debian.sh
> ```

### Executar a Versão Local em Homologação
```bash
sudo bash ./pos_install_server_debian.sh
```

---

## 📋 3. Opções Coletadas no Início e Comportamentos

| Opção | Padrão | Comportamento |
| :--- | :---: | :--- |
| **Atualizar pacotes do sistema** | `Não` | O índice APT (`update`) é sempre atualizado para instalar dependências. Se aceito, aplica o `upgrade -y`. |
| **Permitir login de root via SSH** | `Não` | Exige informar uma conta `sudo` preexistente cujo login SSH já foi testado. Sem isso, preserva a política atual e registra pendência. |
| **Habilitar o Firewall UFW** | `Sim` | Preserva regras existentes, libera dinamicamente as portas SSH detectadas e libera Zabbix Agent (`10050/tcp`). |
| **Criar/garantir administrador no sudo** | `Não` | Cria a conta `administrador` ou garante sua associação ao grupo `sudo`. Se a conta já existir, a senha é preservada. |
| **Criar/garantir outra conta no sudo** | `Não` | Solicita o nome de login desejado, cria a conta ou garante sua associação ao grupo `sudo`. Se já existir, a senha é preservada. |
| **Criar/garantir grupo operacional** | `Não` | Solicita o nome exato (ex.: `dev`, `ti`), cria o grupo e aplica regras no `sudoers.d`. Permite vincular opcionalmente um usuário. |
| **Personalização opcional do Vim** | `Não` | Instala plugins oficiais fixados por commit (Sonokai/Airline), configurando perfis para `/root`, `/etc/skel` e usuários comuns. |
| **Exceções do Fail2Ban** | `Loopback` | Aceita IPs individuais (ex: `192.168.1.2`) ou sub-redes completas em formato CIDR (ex: `192.168.1.0/24 10.0.0.0/8`) que nunca serão bloqueados. |

> ⚠️ **Atenção para Desativação do Root no SSH:**
> Se estiver criando o primeiro administrador nesta execução, conclua o script, teste o login e o `sudo` desse usuário em uma **segunda sessão SSH**, e somente após validar o acesso reexecute o script para responder `Não` à permissão de root.

---

## 🛡️ 4. Hardening, Segurança e Manutenção do Sistema

### 4.1 SSH Hardening Centralizado
As diretivas essenciais são gravadas diretamente no `/etc/ssh/sshd_config`, sem arquivos intermediários legados:
* `PermitRootLogin`: Definido como `no` apenas com conta alternativa validada; caso contrário, a política existente é mantida.
* `PermitEmptyPasswords no`: Bloqueio estrito de senhas em branco.
* `ClientAliveInterval 300` e `ClientAliveCountMax 2`: Envia sinais keepalive a cada 5 minutos; clientes sem resposta são desconectados após 2 falhas.

Para inspecionar as diretivas efetivas interpretadas pelo daemon SSH:
```bash
sudo sshd -T | grep -E '^(permitrootlogin|permitemptypasswords|clientaliveinterval|clientalivecountmax) '
```

### 4.2 Fail2Ban (Proteção de Força Bruta)
Configurado em `/etc/fail2ban/jail.d/99-pos-install-server.local` com `backend = systemd`:
* Monitora as portas SSH detectadas em tempo real via Journald.
* Bloqueia o IP invasor por **1 hora** (`bantime = 3600`) após **5 tentativas falhas** em uma janela de 10 minutos.
* Adiciona automaticamente o IP da sessão SSH atual na lista de exceções (`ignoreip`).

Comandos úteis do Fail2Ban:
```bash
# Verificar status da jaula SSH
sudo fail2ban-client status sshd

# Desbanir um IP que foi bloqueado por engano
sudo fail2ban-client set sshd unbanip <ENDERECO_IP>

# Monitorar logs em tempo real
sudo journalctl -u fail2ban -f
```

### 4.3 Auditoria com Auditd
Monitora alterações em arquivos vitais do Debian:
* Identidade e Autenticação: `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/security`
* Privilégios: `/etc/sudoers`, `/etc/sudoers.d`
* Conexão e Rede: `/etc/ssh`, `/etc/hosts`, `/etc/resolv.conf`, `/etc/network`, `/etc/ufw`
* Escalonamento de Privilégios: `/usr/bin/sudo`, `/usr/bin/su`, `/usr/bin/passwd`

Comandos úteis de Auditoria:
```bash
# Consultar status da auditoria do kernel
sudo auditctl -s

# Listar regras de auditoria ativas
sudo auditctl -l

# Buscar eventos de escalonamento de privilégios
sudo ausearch -k priv_escalation -ts today

# Gerar relatório resumido de auditoria
sudo aureport --summary
```

### 4.4 Firewall UFW Dual-Stack (IPv4/IPv6)
```bash
# Verificar status detalhado e regras numeradas
sudo ufw status numbered

# Liberar porta de serviço customizada (ex: Nginx 80 e 443)
sudo ufw allow 80/tcp comment 'HTTP Web'
sudo ufw allow 443/tcp comment 'HTTPS Web'

# Remover regra pelo número
sudo ufw delete <NUMERO_DA_REGRA>
```

### 4.5 Hardening de `/dev/shm`
Aplica no `/etc/fstab` as opções `noexec,nosuid,nodev` para a partição temporária compartilhada em memória, impedindo a execução direta de binários baixados em `/dev/shm`.
```bash
# Validar flags de montagem atuais
findmnt -kno TARGET,OPTIONS /dev/shm
```

---

## 👥 5. Gestão de Contas, Grupos e Políticas Sudoers

### Criação Segura com Diálogo Nativo `passwd`
* O script utiliza o utilitário nativo `passwd` diretamente no terminal interativo. As senhas nunca passam por variáveis de ambiente, histórico do bash ou arquivos de log.
* Se a conta informada já existir, a senha atual é estritamente **preservada** e o script apenas garante o vínculo com o grupo correto.

### Barreiras Operacionais para Grupos de Suporte/Dev
Para grupos operacionais (ex: `dev`, `ti`), o script cria regras em `/etc/sudoers.d/grupo_<NOME>` que concedem administração ampla, mas impedem:
* Alteração direta de senhas de contas protegidas (`root`, `administrador` e conta administrativa adicional informada).
* Edição direta de arquivos críticos (`/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`).
* Escalonamento irrestrito através de `visudo`, `usermod`, `gpasswd` ou `su`.

---

## 🛠️ 6. Cheat Sheet de Comandos dos Utilitários Instalados

### 6.1 Diagnóstico de Recursos e Desempenho

#### `btop` & `htop` (Monitoramento Interativo)
```bash
# Painel moderno com gráficos de CPU, Memória, Discos, Processos e Rede
btop

# Monitor clássico de processos ordenável por CPU ou Memória
htop
```

#### `iotop` (Diagnóstico de I/O de Disco)
```bash
# Exibir apenas processos que estão efetuando I/O no momento
sudo iotop -oP

# Monitorar I/O acumulado por processo
sudo iotop -a
```

#### `sysstat` / `sar` / `iostat` (Histórico de Métricas)
```bash
# Relatório de utilização de CPU de hoje
sar -u

# Utilização de memória RAM e swap
sar -r

# Estatísticas de I/O por disco em tempo real (intervalo de 2s, 5 amostras)
iostat -xz 2 5
```

#### `ncdu` (Uso de Disco por Pastas)
```bash
# Analisar a raiz do sistema excluindo outros pontos de montagem
sudo ncdu -x /

# Analisar rapidamente uma pasta específica
ncdu /var/log
```

---

### 6.2 Rede, Portas e Conectividade

#### `ss` & `net-tools` (Inspeção de Portas e Conexões)
```bash
# Listar todas as portas TCP/UDP em escuta com nome do processo (alias 'ports')
sudo ss -tulanp

# Ver conexões TCP estabelecidas
ss -t -a state established
```

#### `bind9-dnsutils` (`dig` & `nslookup`)
```bash
# Consultar DNS detalhado com tempo de resposta
dig google.com +trace

# Consulta DNS reversa
dig -x 8.8.8.8 +short
```

#### `mtr` (Traceroute Contínuo com Estatísticas de Perda de Pacotes)
```bash
# Diagnóstico de rota e latência em tempo real
mtr -rw 1.1.1.1
```

#### `iperf3` (Teste de Largura de Banda e Throughput)
```bash
# No servidor (modo receptor):
iperf3 -s

# No cliente (modo transmissor):
iperf3 -c <IP_DO_SERVIDOR> -t 10
```

#### `tcpdump` & `nmap` (Captura e Varredura de Portas)
```bash
# Capturar os primeiros 20 pacotes na interface eth0 na porta 22
sudo tcpdump -i any -c 20 port 22 -nn

# Varredura rápida de portas no host local
nmap -sT -p 1-1024 localhost
```

---

### 6.3 Auditoria de Segurança com Lynis

O **Lynis** é um scanner de auditoria de conformidade e hardening para sistemas Linux.

```bash
# Executar auditoria de segurança completa do sistema
sudo lynis audit system

# Consultar o relatório e o índice de hardening
grep "Hardening index" /var/log/lynis.log

# Listar apenas os avisos e sugestões encontrados
grep -E '(WARNING|SUGGESTION)' /var/log/lynis.log
```

---

### 6.4 Produtividade: Aliases e Banner Dinâmico

#### Aliases Pré-Configurados (em `/etc/pos-install-server/bash_aliases`)
Disponíveis para todos os usuários com login interativo no Bash:

| Alias | Comando Executado | Finalidade |
| :--- | :--- | :--- |
| `ll` | `ls -alFh` | Listagem completa com permissões legíveis e tamanhos humanos. |
| `rm` | `rm -I` | Proteção contra remoção acidental de múltiplos arquivos. |
| `cp` | `cp -i` | Confirmação antes de sobrescrever arquivos existentes. |
| `mv` | `mv -i` | Confirmação antes de sobrescrever arquivos de destino. |
| `df` | `df -h` | Espaço de discos em formato legível (G, M). |
| `free` | `free -h` | Memória RAM e SWAP em formato legível. |
| `ports` | `sudo ss -tulanp` | Portas e serviços em escuta no servidor. |
| `myip` | `curl -fsS https://ifconfig.me; echo` | Consulta do endereço IP público da conexão. |
| `update` | `sudo apt-get update && sudo apt-get upgrade -y` | Atualização completa de pacotes do sistema. |
| `clean` | `sudo apt-get autoremove -y && sudo apt-get autoclean` | Limpeza de pacotes órfãos e cache do APT. |
| `motd` | `/usr/local/bin/motd_banner.sh` | Exibe o banner dinâmico de diagnóstico a qualquer momento. |
| `reload` | `source ~/.bashrc` | Recarrega o perfil e aliases na sessão atual. |

#### Banner Dinâmico no Login (`motd_banner.sh`)
Exibe no login de console e SSH:
* Hostname, Sistema Operacional (`Debian GNU/Linux 12/13`) e Kernel
* Uptime detalhado do servidor
* Memória RAM e SWAP em uso/livre
* Utilização de todas as partições montadas
* IPs locais de todas as interfaces físicas ativas
* Status em tempo real do Firewall UFW
