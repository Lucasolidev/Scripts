# 🚀 Guia Prático e Cheat Sheet - Pós-Instalação e Utilitários (Ubuntu Server)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Vim](https://img.shields.io/badge/Vim-019733?style=flat&logo=vim&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-0078D4?style=flat&logo=dependabot&logoColor=white)

Guia operacional rápido, referência de configurações e *cheat sheet* completo para servidores configurados com o script [`pos_install_server.sh`](../pos_install_server.sh). Contém os comandos práticos dos utilitários de **diagnóstico**, **rede**, **segurança (Lynis/Fail2Ban/UFW)**, **desempenho** e **produtividade**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_pos_install_server_*.log` | Log completo e detalhado com timestamp da execução do script pós-instalação. |
| `/root/relatorio_pos_install_server_latest.log` | Atalho fixo apontando para o último log gerado de pós-instalação. |
| `/etc/profile.d/motd_banner.sh` | Script do banner dinâmico de boas-vindas exibido após o login via SSH ou console. |
| `/etc/fail2ban/jail.local` | Configuração local da jaula de proteção contra força bruta no SSH. |
| `/etc/default/ufw` | Configurações do firewall UFW (incluindo suporte a IPv6 ativo `IPV6=yes`). |
| `/etc/default/keyboard` | Mapeamento dual de layout de teclado (`ABNT2` + `US-International`). |
| `/etc/sudoers.d/grupo_*` | Regras de restrição de segurança do Visudo para grupos customizados de TI/Dev. |
| `/root/.vimrc` / `/etc/skel/.vimrc` | Configuração global do editor Vim com tema Sonokai Andromeda e barra Airline. |
| `/var/log/sysstat/` | Diretório onde o `sysstat` armazena o histórico diário de métricas de CPU, RAM e I/O. |
| `/var/log/lynis.log` | Relatório completo e detalhado da última auditoria de segurança gerada pelo Lynis. |

---

## ⚙️ 2. Execução e Parâmetros do Script

### Execução Direta via Linha Única
```bash
# Baixa, concede permissão de execução e executa com privilégios root
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh -O pos_install_server.sh && chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
```

### O que o script aplica automaticamente:
* **Locales & Fuso Horário**: Sistema em inglês (`en_US.UTF-8`) com suporte a `pt_BR.UTF-8` e fuso `America/Sao_Paulo` (NTP ativo).
* **Teclado Dual**: Padrão `ABNT2` (pt-br) + `US-International` com acentos (alterna pressionando `Alt + Shift`).
* **Proteção `/dev/shm`**: Memória RAM compartilhada montada no `/etc/fstab` com flags `noexec,nosuid,nodev` contra execução de malware.
* **Hardening no SSH**: Desabilita senhas em branco (`PermitEmptyPasswords no`), timeout de ociosidade de 10 min e bloqueio opcional de Root.
* **Agente de VM Inteligente**: Detecta se o host é **Proxmox/KVM** (`qemu-guest-agent`) ou **VMware** (`open-vm-tools`), ativando apenas o correspondente sem causar timeouts.

---

## ⌨️ 3. Aliases de Produtividade no Shell (`.bashrc`)

Os aliases abaixo são configurados automaticamente em `/root/.bashrc`, `/etc/skel/.bashrc` e nas pastas home dos usuários:

| Alias | Comando Real | Finalidade Operacional |
| :--- | :--- | :--- |
| `ll` | `ls -alFh` | Listagem detalhada com arquivos ocultos e tamanhos legíveis (KB, MB, GB). |
| `rm` | `rm -I` | Remoção segura com confirmação inteligente ao apagar mais de 3 arquivos ou recursivo. |
| `cp` | `cp -i` | Cópia com confirmação interativa antes de sobrescrever arquivos. |
| `mv` | `mv -i` | Movimentação com confirmação interativa antes de sobrescrever. |
| `df` | `df -h` | Exibe partições de disco e espaço livre em formato humano. |
| `free` | `free -h` | Exibe memória RAM e SWAP detalhada. |
| `ports` | `sudo ss -tulanp` | Lista portas TCP e UDP abertas no servidor com os respectivos processos. |
| `myip` | `curl -s ifconfig.me; echo` | Retorna rapidamente o endereço IP público externo do servidor. |
| `update` | `sudo apt update && sudo apt upgrade -y` | Atualiza a lista de repositórios e pacotes do sistema com um só comando. |
| `clean` | `sudo apt autoremove -y && sudo apt autoclean` | Remove pacotes órfãos e limpa o cache de pacotes baixados pelo APT. |
| `reload` | `source ~/.bashrc` | Recarrega as configurações do shell sem necessidade de deslogar da sessão. |
| `..` | `cd ..` | Sobe um nível de diretório. |
| `...` | `cd ../..` | Sobe dois níveis de diretório. |

---

## 📊 4. Monitoramento e Diagnóstico de Desempenho

### 4.1 Monitor de Processos e Recursos (`btop` / `htop`)
```bash
# Abre o monitor visual moderno e completo (CPU, RAM, Discos, Processos e Rede)
btop

# Abre o monitor clássico de processos
htop
```
> 💡 *Dica no `btop`: Utilize as teclas `m` para abrir o menu de configurações e `Esc` ou `q` para sair.*

---

### 4.2 Diagnóstico de Gargalos de Disco e I/O (`iotop`)
Permite identificar instantaneamente qual processo está travando o servidor com leitura ou gravação pesada em disco:
```bash
# Abre o monitor interativo de I/O em tempo real
sudo iotop

# Exibe APENAS os processos que estão realmente utilizando disco no momento (Recomendado)
sudo iotop -o

# Modo não-interativo para captura em logs (executa 3 coletas e sai)
sudo iotop -b -n 3
```

---

### 4.3 Histórico de Desempenho e Métricas do Sistema (`sysstat` / `sar` / `iostat`)
O daemon do `sysstat` roda em background coletando estatísticas do servidor a cada 10 minutos.

```bash
# Diagnóstico de taxa de transferência e I/O detalhado por disco em tempo real (1s de intervalo, 5 coletas)
iostat -xz 1 5

# Histórico de uso de CPU do dia atual
sar -u

# Histórico de consumo de Memória RAM e Buffers do dia atual
sar -r

# Histórico de Load Average e fila de processos do dia atual
sar -q

# Consultar o histórico de um dia específico do mês (ex: dia 20)
sar -u -f /var/log/sysstat/sa20
```

---

### 4.4 Análise e Limpeza Visual de Espaço em Disco (`ncdu`)
```bash
# Analisa todo o sistema de arquivos raiz a partir de /
sudo ncdu /

# Analisa apenas uma pasta específica (ex: diretório de logs ou sites)
sudo ncdu /var/log
sudo ncdu /var/www
```
> 💡 *Navegação no `ncdu`: Use as setas `↑` e `↓` para navegar, `Enter` para abrir pastas, `d` para deletar arquivos pesados com segurança e `q` para sair.*

---

## 🌐 5. Diagnóstico de Rede e Conectividade

### 5.1 Ping e Traceroute Dinâmico em Tempo Real (`mtr`)
Combina a funcionalidade do `ping` e do `traceroute`, mostrando onde ocorrem perdas de pacotes ao longo da rota:
```bash
# Diagnóstico contínuo interativo para um host ou IP
mtr 8.8.8.8
mtr google.com.br

# Modo relatório sem interface (executa 10 pings por salto e exibe o resultado)
mtr -rw -c 10 1.1.1.1
```

---

### 5.2 Teste de Largura de Banda e Velocidade entre Servidores (`iperf3`)
```bash
# No Servidor 1 (Servidor de Teste / Receptor):
iperf3 -s

# No Servidor 2 (Cliente / Emissor):
iperf3 -c 192.168.1.50

# Teste com tráfego reverso (Download a partir do servidor 1):
iperf3 -c 192.168.1.50 -R
```

---

### 5.3 Auditoria e Verificação de Portas (`nmap`)
```bash
# Varredura rápida de portas TCP abertas no próprio servidor
nmap -sT localhost

# Verificar portas abertas e identificar versão dos serviços em um IP alvo
nmap -sV -Pn 192.168.1.100

# Testar se portas específicas estão abertas em um destino (ex: Web e SSH)
nmap -p 22,80,443,10050 192.168.1.100
```

---

### 5.4 Captura e Inspeção de Tráfego de Rede (`tcpdump`)
```bash
# Captura tráfego em tempo real na interface eth0 sem resolver DNS (-n)
sudo tcpdump -i eth0 -n

# Captura apenas pacotes na porta 80 ou 443 (HTTP/HTTPS)
sudo tcpdump -i eth0 port 80 or port 443 -n

# Captura apenas pacotes de ou para um IP específico
sudo tcpdump -i eth0 host 192.168.1.200 -n

# Salva a captura em arquivo compatível com o Wireshark
sudo tcpdump -i eth0 -w /tmp/captura_rede.pcap
```

---

### 5.5 Consultas de DNS (`dnsutils` / `dig` / `nslookup`)
```bash
# Consulta rápida de registro A via servidor DNS padrão
dig google.com +short

# Forçar consulta em um servidor DNS específico (ex: Cloudflare 1.1.1.1)
dig @1.1.1.1 meu_dominio.com.br

# Consulta de registros específicos (MX, TXT, NS, CNAME)
dig meu_dominio.com.br MX +short
dig meu_dominio.com.br TXT +short

# Consulta reversa de IP (PTR)
dig -x 8.8.8.8 +short
```

---

## 🛡️ 6. Auditoria de Segurança, Hardening e Firewall

### 6.1 Auditoria Completa de Segurança e Hardening Index (`lynis`)
O **Lynis** faz uma varredura profunda de conformidade, configurações de kernel, permissões e vulnerabilidades:
```bash
# Executa a auditoria completa do servidor com pausas interativas
sudo lynis audit system

# Executa a auditoria completa de forma direta (Modo Rápido / Relatório)
sudo lynis audit system -Q

# Consultar todos os AVISOS (Warnings) e SUGESTÕES (Suggestions) gerados
sudo grep -E "Warning:|Suggestion:" /var/log/lynis.log

# Ver detalhes e solução recomendada de um item específico (ex: NETW-2705 ou AUTH-9230)
sudo lynis show details NETW-2705
```

---

### 6.2 Prevenção de Força Bruta no SSH (`fail2ban`)
```bash
# Verifica o status da jaula do SSH e quantidade de IPs banidos
sudo fail2ban-client status sshd

# Desbane manualmente um endereço IP (ex: caso um administrador seja bloqueado)
sudo fail2ban-client set sshd unbanip 192.168.1.100

# Banir manualmente um IP suspeito
sudo fail2ban-client set sshd banip 203.0.113.50

# Acompanha o log de tentativas e bloqueios em tempo real
sudo tail -f /var/log/fail2ban.log
```

---

### 6.3 Gerenciamento do Firewall (`ufw`)
```bash
# Exibe as regras ativas numeradas
sudo ufw status numbered

# Liberar porta TCP (ex: HTTP 80 e HTTPS 443)
sudo ufw allow 80/tcp comment 'Acesso Web HTTP'
sudo ufw allow 443/tcp comment 'Acesso Web HTTPS'

# Liberar porta apenas para uma sub-rede confiável (ex: Banco de Dados MySQL)
sudo ufw allow from 192.168.1.0/24 to any port 3306 proto tcp comment 'MySQL Apenas Rede Local'

# Remover uma regra pelo número de identificação
sudo ufw delete 4

# Recarregar as regras do firewall (sem queda de conexões ativas)
sudo ufw reload
```

---

## ⚡ 7. Produtividade, Manipulação de Dados e Arquivos

### 7.1 Manipulação e Formatação de JSON (`jq`)
```bash
# Formata e colore uma resposta JSON crua
curl -s https://api.github.com/users/octocat | jq .

# Extrai chaves específicas de um JSON
curl -s https://api.github.com/users/octocat | jq '.name, .public_repos, .location'

# Filtra arrays com condições
cat dados.json | jq '.servidores[] | select(.ativo == true)'
```

---

### 7.2 Terminal Multiplexer para Processos Longos (`tmux`)
Permite rodar rotinas longas (backups, migrações, updates) sem risco de interrupção se a conexão SSH cair:
```bash
# Iniciar uma nova sessão nomeada
tmux new -s rotina_backup

# Desconectar da sessão deixando o processo rodando em background
# Pressione: Ctrl + b e depois a tecla d (Detach)

# Reconectar à sessão ativa
tmux attach -t rotina_backup
# Ou de forma simplificada:
tmux a -t rotina_backup

# Listar todas as sessões ativas no servidor
tmux ls
```
> 💡 *Consulte o guia completo com divisão de telas e atalhos em [ajuda_tmux.md](ajuda_tmux.md).*

---

### 7.3 Visualização de Árvore de Pastas (`tree`)
```bash
# Visualiza a estrutura de diretórios limitando a 2 níveis de profundidade
tree -L 2 /var/www

# Exibe apenas os diretórios (ocultando arquivos)
tree -d -L 2 /etc
```

---

### 7.4 Sincronização e Transferência Segura (`rsync`)
```bash
# Sincroniza pasta local para servidor remoto mantendo permissões e exibindo progresso
rsync -avzhP /var/www/meu_site/ administrador@192.168.1.50:/var/www/meu_site/

# Simulação de sincronização sem alterar arquivos (Dry-Run seguro)
rsync -avzhP --dry-run /var/www/meu_site/ /backup/www/
```

---

### 7.5 Descompactação de Arquivos (`unzip` / `p7zip`)
```bash
# Descompacta arquivo .zip em uma pasta de destino
unzip arquivo.zip -d /caminho/destino/

# Descompacta arquivo .7z ou .tar.gz com 7z
7z x backup.7z -o/caminho/destino/
```

---

## 📝 8. Editor Vim Customizado (Sonokai & Airline)

O arquivo de configuração `/root/.vimrc` (repassado para `/etc/skel` e todos os usuários em `/home`) vem pré-configurado com:
* **Tema Visual**: Sonokai (Andromeda) com destaque sintático e suporte a TrueColor.
* **Barra de Status**: `vim-airline` com visualização de modo, codificação UTF-8 e linha/coluna.
* **Produtividade**: Numeração de linhas ativa (`nu`), recuo de 4 espaços (`shiftwidth=4`), rolagem suave (`scrolloff=8`) e suporte a mouse (`mouse=a`).

### Atalhos Úteis no Vim:
* `:w` $\rightarrow$ Salvar o arquivo.
* `:q!` $\rightarrow$ Sair sem salvar alterações.
* `:wq` ou `ZZ` $\rightarrow$ Salvar e sair.
* `/palavra` $\rightarrow$ Pesquisar por uma palavra (`n` vai para o próximo resultado, `N` vai para o anterior).
* `u` $\rightarrow$ Desfazer última alteração (*Undo*).
* `Ctrl + r` $\rightarrow$ Refazer alteração (*Redo*).
* `:set paste` $\rightarrow$ Modo colagem (evita quebra de identação ao colar código externo).

---

## 🔒 9. Gerenciamento de Usuários e Regras do Visudo

Ao solicitar a criação de um grupo customizado (ex: `TI`, `DEV`) durante a execução do script, o sistema gera uma regra de segurança em `/etc/sudoers.d/`:

* ✅ **Permitido**: Executar comandos administrativos do dia a dia com `sudo`.
* ❌ **Bloqueado por Segurança**:
  - Alterar a senha do usuário `root` ou `geset` (`!/usr/bin/passwd root`, `!/usr/bin/passwd geset`).
  - Leitura direta do arquivo de senhas hash (`/etc/shadow`) via `cat`, `less`, `more`, `tail`, `grep`, `nano`, `vi`, `cp`.
  - Execução direta de shells privilegiados sem log (`sudo -i`, `sudo -s`, `sudo /bin/bash`, `sudo /bin/sh`).
