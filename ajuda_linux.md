# 🐧 Cheat Sheet - Administração Linux (Ubuntu Server)

## 🖥️ Informações do Sistema

### Verificar o sistema operacional e versão detalhada
```bash
cat /etc/os-release
```

### Exibir a versão do Kernel do Linux
```bash
uname -a
```

### Verificar hostname, versão do OS e arquitetura de forma geral
```bash
hostnamectl
```

## 📁 Manipulação de Arquivos & Diretórios

### Criar Diretórios (`mkdir`)
* **Criar pastas alinhadas (estrutura recursiva/pais):** Cria todas as pastas intermediárias caso não existam.
  ```bash
  mkdir -p /caminho/da/pasta/nova
  ```
* **Modo detalhado (Verbose):** Mostra uma mensagem para cada diretório criado.
  ```bash
  mkdir -pv pasta1/pasta2
  ```

### Copiar Arquivos e Pastas (`cp`)
* **Copiar pasta inteira recursivamente:**
  ```bash
  cp -r /origem/pasta /destino/pasta
  ```
* **Preservar atributos (permissões, datas de modificação e dono):**
  ```bash
  cp -p arquivo.txt /destino/
  ```
* **Copiar de forma interativa (pede confirmação antes de sobrescrever):**
  ```bash
  cp -i arquivo.txt /destino/
  ```
* **Copiar apenas arquivos mais novos (Update):**
  ```bash
  cp -u arquivo.txt /destino/
  ```

### Remover Arquivos e Pastas (`rm`) — Dicas de Segurança ⚠️
* **Remover pastas e subpastas recursivamente:**
  ```bash
  rm -rf /caminho/da/pasta
  ```
* **💡 Como remover com Segurança:**
  * **Confirmação Interativa (`-i` ou `-I`):** 
    Use `-i` para pedir confirmação em cada arquivo ou `-I` para confirmar uma única vez antes de apagar mais de 3 arquivos ou pastas recursivamente.
    ```bash
    rm -rI /caminho/da/pasta
    ```
  * **Visualizar antes de apagar (Regra de Ouro):** 
    Substitua o `rm` por `ls` antes para ter certeza do que será apagado:
    ```bash
    # Primeiro liste para confirmar:
    ls -la /caminho/pasta/*.log
    # Se estiver correto, execute a remoção:
    rm /caminho/pasta/*.log
    ```
  * **Cuidado com caminhos relativos:** Evite usar `rm -rf .*` (pode tentar apagar o diretório pai `..`). Dê preferência a caminhos absolutos completos.

### Buscar Arquivos e Pastas (`find`)
O utilitário `find` é extremamente poderoso para localizar itens com base em regras:
* **Buscar por nome (Ignorando maiúsculas/minúsculas - Case Insensitive):**
  ```bash
  find /diretorio/de/busca -iname "nome_do_arquivo.txt"
  ```
* **Buscar apenas arquivos (`-type f`) ou apenas pastas (`-type d`):**
  ```bash
  find /diretorio/de/busca -type f -name "*.log"
  find /diretorio/de/busca -type d -name "backup*"
  ```
* **Buscar arquivos por tamanho (ex: maiores que 100MB):**
  ```bash
  find /diretorio/de/busca -type f -size +100M
  ```
* **Buscar arquivos modificados nos últimos X dias (ex: últimos 7 dias):**
  ```bash
  find /diretorio/de/busca -type f -mtime -7
  ```
* **Buscar e executar uma ação (ex: buscar todos os `.tmp` e excluí-los):**
  ```bash
  find /diretorio/de/busca -type f -name "*.tmp" -exec rm -f {} \;
  ```

### Compactação & Descompactação (`tar`, `zip`, `unzip`, `gzip`, `bzip2`)
Guia rápido para empacotar, compactar e extrair arquivos:

* **Compactar pasta em `.tar.gz` (Gzip — Rápido e muito comum):**
  ```bash
  tar -czvf arquivo.tar.gz /caminho/da/pasta
  ```
  *(Parâmetros: `-c` cria, `-z` compacta com gzip, `-v` verbose, `-f` define o arquivo destino)*

* **Descompactar um arquivo `.tar.gz`:**
  ```bash
  tar -xzvf arquivo.tar.gz -C /diretorio/destino
  ```

* **Compactar pasta em `.tar.bz2` (Bzip2 — Maior compactação, mais lento):**
  ```bash
  tar -cjvf arquivo.tar.bz2 /caminho/da/pasta
  ```
  *(Parâmetros: `-j` compacta com bzip2)*

* **Descompactar um arquivo `.tar.bz2`:**
  ```bash
  tar -xjvf arquivo.tar.bz2 -C /diretorio/destino
  ```

* **Compactar pasta em `.zip` (Compatível com Windows):**
  ```bash
  zip -r arquivo.zip /caminho/da/pasta
  ```

* **Descompactar um arquivo `.zip`:**
  ```bash
  unzip arquivo.zip -d /diretorio/destino
  ```

* **Compactar um único arquivo diretamente com `gzip` ou `bzip2`:**
  ```bash
  gzip arquivo.txt         # Gera arquivo.txt.gz e APAGA o original
  gzip -k arquivo.txt      # Gera arquivo.txt.gz e MANTÉM o original (-k)
  
  bzip2 arquivo.txt        # Gera arquivo.txt.bz2 (compactação mais forte que gzip)
  bzip2 -k arquivo.txt     # Gera arquivo.txt.bz2 e MANTÉM o original
  ```

* **Descompactar arquivos `.gz` ou `.bz2` diretamente:**
  ```bash
  gunzip arquivo.txt.gz    # Ou: gzip -d arquivo.txt.gz
  bunzip2 arquivo.txt.bz2  # Ou: bzip2 -d arquivo.txt.bz2
  ```

* **Visualizar o conteúdo de um `.tar.gz` sem extrair:**
  ```bash
  tar -tzf arquivo.tar.gz
  ```

## 👤 Gerenciamento de Usuários e Grupos

### Listar todos os usuários do sistema
```bash
cut -d: -f1 /etc/passwd
```

### Listar usuários com acesso sudo
```bash
getent group sudo
```

### Criar um novo usuário com pasta home
```bash
sudo adduser nome_usuario
```

### Adicionar usuário existente ao grupo sudo
```bash
sudo usermod -aG sudo nome_usuario
```

### Bloquear login por senha para um usuário específico
```bash
sudo usermod -L nome_usuario
```

### Verificar usuários atualmente logados no sistema (w vs who)
* **`who`** — Mostra uma lista direta dos usuários logados, indicando o terminal (TTY), data/hora de login e IP de origem.
  ```bash
  who
  ```
* **`w`** — Mais completo. Além de listar quem está logado, mostra o uptime/carga do sistema, tempo ocioso de cada terminal e **o que** cada usuário está executando no momento.
  ```bash
  w
  ```

## 🔐 SSH & Segurança

### Gerar novas chaves SSH (Par de chaves Pública/Privada)
* **Recomendado (Algoritmo ED25519 — mais seguro e rápido):**
  ```bash
  ssh-keygen -t ed25519 -C "seu_email@exemplo.com"
  ```
* **Legado/Compatibilidade (Algoritmo RSA de 4096 bits):**
  ```bash
  ssh-keygen -t rsa -b 4096 -C "seu_email@exemplo.com"
  ```

### Copiar a chave pública para o servidor (Autorizar o acesso)
Para conseguir se conectar sem senha, você precisa registrar a sua **chave pública** (arquivo `.pub`) dentro do arquivo `authorized_keys` no servidor de destino.

* **Método Automático (Recomendado via terminal Linux/macOS):**
  ```bash
  ssh-copy-id -i ~/.ssh/id_ed25519.pub usuario@ip_do_servidor
  ```
* **Método Manual (Caso esteja usando Windows ou fazendo direto no console do servidor):**
  1. Na sua máquina local, exiba o conteúdo da sua chave pública:
     ```bash
     cat ~/.ssh/id_ed25519.pub
     ```
  2. Copie todo o conteúdo retornado (a linha inteira).
  3. No servidor de destino, crie a pasta `.ssh` (se não existir) e adicione a chave no final do arquivo:
     ```bash
     mkdir -p ~/.ssh
     echo "cole_aqui_a_chave_publica_copiada" >> ~/.ssh/authorized_keys
     ```

### Testar alterações no sshd_config antes de reiniciar
```bash
sudo sshd -t
```

### Reiniciar o serviço SSH com segurança
```bash
sudo systemctl restart ssh
```

### Ativar o firewall local UFW
```bash
sudo ufw enable
```

### Liberar porta no UFW (com comentário identificador)
```bash
sudo ufw allow 22/tcp comment 'Acesso SSH principal'
```

### Excluir uma regra ativa no UFW
* **Método 1 — Excluir especificando a regra original:**
  ```bash
  sudo ufw delete allow 22/tcp
  ```
* **Método 2 — Excluir pelo número da regra (Recomendado/Mais prático):**
  1. Liste todas as regras ativas numeradas:
     ```bash
     sudo ufw status numbered
     ```
  2. Apague a regra desejada informando o número correspondente (ex: regra 2):
     ```bash
     sudo ufw delete 2
     ```

### Ver status do UFW com detalhes
```bash
sudo ufw status verbose
```

### Ajustar permissões rígidas da pasta e chaves SSH do usuário
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## 💾 Aumento de Armazenamento - Partição Simples (EXT4)

### 1. Verificar montagens atuais
```bash
df -hT
```

### 2. Forçar o Kernel a reconhecer o novo tamanho do disco (ex: sdc)
```bash
echo 1 > /sys/class/block/sdc/device/rescan
```

### 3. Confirmar se o disco principal cresceu no lsblk
```bash
lsblk
```

### 4. Instalar ferramenta de expansão de partição
```bash
apt update && apt install -y cloud-guest-utils
```

### 5. Expandir a partição 1 do disco target (Substitua sdX pelo seu disco)
```bash
growpart /dev/sdX 1
```

### 6. Redimensionar o sistema de arquivos ext4
```bash
resize2fs /dev/sdX1
```

### 7. Confirmar novo espaço
```bash
df -hT
```

## 📦 Aumento de Armazenamento - Volume Lógico (LVM)

### Expandir o Logical Volume (LV) + Sistema de Arquivos em um único comando
```bash
lvextend -r -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```

### Caso a partição física (PV) precise ser re-escaneada antes
```bash
pvresize /dev/sdX1
```

## 📊 Diagnóstico de Rede & Portas

### Ver conexões ativas e portas escutando (substituto moderno do netstat)
```bash
ss -tulpn
```

### Testar se uma porta remota está aberta (ex: teste de NAT/Firewall)
```bash
nc -zv 187.32.48.193 35222
```

### Ver IP local das interfaces
```bash
ip a
```

## 🧹 Limpeza & Espaço em Disco

### Ver quais arquivos/pastas estão consumindo mais espaço no diretório atual
```bash
du -h --max-depth=1 | sort -hr
```

### Limpar cache de pacotes antigos do APT
```bash
sudo apt autoremove --purge && sudo apt clean
```

### Ver logs do sistema ocupando espaço e limpar logs antigos
```bash
journalctl --disk-usage
sudo journalctl --vacuum-time=3d
```
## 🔍 Análise de Logs & Erros (tail & journalctl)

### Principais arquivos de log no Ubuntu Server
* `/var/log/syslog` — Registro geral de eventos do sistema.
* `/var/log/auth.log` — Log de autenticação, acessos SSH, tentativas de login e uso do `sudo`.
* `/var/log/kern.log` — Mensagens do Kernel, avisos de hardware e problemas com dispositivos.
* `/var/log/dpkg.log` — Histórico de instalação, atualização e remoção de pacotes via APT.

### Monitorar o log do sistema em tempo real
```bash
tail -f /var/log/syslog
```

### Ver as últimas 100 linhas de um log
```bash
tail -n 100 /var/log/syslog
```

### Mostrar as últimas 50 linhas e continuar acompanhando em tempo real
```bash
tail -n 50 -f /var/log/syslog
```

### Filtrar apenas erros ou falhas em tempo real
```bash
tail -f /var/log/syslog | grep -i -E "error|fail|warning"
```

### Monitorar múltiplos logs simultaneamente (syslog e auth.log)
```bash
tail -f /var/log/syslog /var/log/auth.log
```

### Filtrar erros e buscar problemas com journalctl
* **Ver apenas erros/falhas do boot atual:**
  ```bash
  sudo journalctl -p err -b
  ```
* **Ver logs do boot anterior (útil após travamentos):**
  ```bash
  sudo journalctl -b -1
  ```
* **Ver logs de um serviço específico em tempo real (ex: SSH, Apache, Nginx):**
  ```bash
  sudo journalctl -u ssh -f
  ```
* **Filtrar logs por tempo (ex: última 1 hora, ou período específico):**
  ```bash
  sudo journalctl --since "1 hour ago"
  sudo journalctl --since "2026-07-20 14:00:00" --until "2026-07-20 16:00:00"
  ```
* **Ver logs apenas relacionados ao Kernel (equivalente ao dmesg):**
  ```bash
  sudo journalctl -k
  ```
* **Acompanhar todos os logs do sistema em tempo real:**
  ```bash
  sudo journalctl -f
  ```

## 🚀 Processos & Monitoramento

### Monitor interativo de CPU e RAM
```bash
htop
```

### Listar todos os processos ativos no sistema
```bash
ps aux
```

### Encontrar um processo específico pelo nome
```bash
ps aux | grep nome_do_processo
```

### Matar um processo de forma forçada usando o PID
```bash
kill -9 PID
```

### Matar processos pelo nome
```bash
killall nome_do_processo
```

### Verificar uso de memória RAM e Swap de forma legível
```bash
free -h
```

### Identificar qual processo está ocupando uma porta específica (ex: 80)
```bash
sudo lsof -i :80
```

### Exibir o uptime (tempo online) e as médias de carga do processador (load average)
```bash
uptime
```
