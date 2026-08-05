# 🐘 Guia Prático e Comandos de Operação do Samba (Server & Client)

Este guia reúne os principais comandos, arquivos de configuração, diretórios de logs e procedimentos operacionais para administrar o **Samba** em ambientes Linux (como **Servidor de Arquivos Standalone** ou **Controlador de Domínio Active Directory AD-DC**) e interagir via clientes **Linux** e **Windows**.

---

## 📁 1. Arquivos de Configuração e Diretórios Vitais

### 📄 Arquivos Principais

* **`/etc/samba/smb.conf`**  
  Arquivo principal de configuração do Samba. Define compartilhamentos, permissões, modo de segurança, regras de rede e configurações globais.

* **`/etc/krb5.conf`**  
  Arquivo de configuração do **Kerberos** (usado quando o Samba opera como Active Directory DC para autenticação de tickets).

* **`/etc/samba/lmhosts`**  
  Mapeamento estático de nomes NetBIOS para endereços IP (similar ao `/etc/hosts`).

* **`/var/lib/samba/private/sam.ldb`**  
  Banco de dados LDB contendo os objetos do Active Directory (usuários, grupos, políticas, senhas) quando o Samba atua como AD DC.

* **`/etc/samba/credentials`**  
  Arquivo protegido (`chmod 600`) recomendado para armazenar usuário e senha em montagens automáticas de clientes Linux.

---

## 📊 2. Arquivos de Log e Diagnóstico

Os logs do Samba por padrão ficam localizados no diretório `/var/log/samba/`.

### 📜 Principais Logs

* **`/var/log/samba/log.smbd`**  
  Log do serviço principal SMB (compartilhamentos de arquivos e impressoras).

* **`/var/log/samba/log.nmbd`**  
  Log do serviço NetBIOS (resolução de nomes na rede local).

* **`/var/log/samba/log.samba`**  
  Log unificado dos serviços do Active Directory DC.

* **`/var/log/samba/log.<ip_ou_nome_cliente>`**  
  Logs específicos gerados para cada máquina ou IP cliente que se conecta ao servidor.

### 🔍 Comandos para Monitorar Logs em Tempo Real

* **Acompanhar erros do serviço SMB em tempo real:**
  ```bash
  sudo tail -f /var/log/samba/log.smbd
  ```

* **Buscar erros críticos de acesso ou autenticação:**
  ```bash
  sudo grep -i "failed" /var/log/samba/log.smbd
  ```

---

## ⚙️ 3. Comandos de Gerenciamento do Servidor (Server-Side)

### 🛠️ Validação e Gerenciamento de Serviços

* **Validar a sintaxe do arquivo `smb.conf` (Obrigatório após edições):**
  ```bash
  sudo testparm -s
  ```

* **Status dos serviços no Ubuntu/Debian (Servidor de Arquivos Standalone):**
  ```bash
  sudo systemctl status smbd nmbd winbind
  sudo systemctl restart smbd nmbd winbind
  ```

* **Status do serviço no Samba Active Directory DC:**
  ```bash
  sudo systemctl status samba-ad-dc
  sudo systemctl restart samba-ad-dc
  ```

---

### 👥 4. Gerenciamento de Usuários (Samba Standalone / Servidor de Arquivos)

No Samba Standalone, o usuário deve primeiro existir no Linux (`/etc/passwd`) e depois ser adicionado à base de senhas do Samba (`smbpasswd`).

* **Adicionar/Criar usuário no Samba (define a senha de acesso à rede):**
  ```bash
  sudo smbpasswd -a nome_usuario
  ```

* **Alterar senha de um usuário no Samba:**
  ```bash
  sudo smbpasswd nome_usuario
  ```

* **Habilitar um usuário bloqueado no Samba:**
  ```bash
  sudo smbpasswd -e nome_usuario
  ```

* **Desabilitar/Bloquear um usuário no Samba:**
  ```bash
  sudo smbpasswd -d nome_usuario
  ```

* **Remover usuário da base de senhas do Samba:**
  ```bash
  sudo smbpasswd -x nome_usuario
  ```

* **Listar todos os usuários cadastrados no Samba:**
  ```bash
  sudo pdbedit -L -v
  ```

---

### 👑 5. Gerenciamento de Usuários e Grupos no Samba Active Directory (`samba-tool`)

Quando o Samba está configurado como **Active Directory DC**, utiliza-se a ferramenta oficial **`samba-tool`**.

#### 👤 Usuários no AD DC

* **Criar um novo usuário no Active Directory:**
  ```bash
  sudo samba-tool user create usuario_novo 'SenhaForte123'
  ```

* **Listar todos os usuários do domínio:**
  ```bash
  sudo samba-tool user list
  ```

* **Resetar/Alterar a senha de um usuário do domínio:**
  ```bash
  sudo samba-tool user setpassword usuario_novo
  ```

* **Habilitar / Desabilitar usuário no AD:**
  ```bash
  sudo samba-tool user enable usuario_novo
  sudo samba-tool user disable usuario_novo
  ```

* **Excluir um usuário do domínio:**
  ```bash
  sudo samba-tool user delete usuario_novo
  ```

#### 👥 Grupos e Permissões no AD DC

* **Listar grupos do domínio:**
  ```bash
  sudo samba-tool group list
  ```

* **Adicionar usuário a um grupo (ex: Domain Admins):**
  ```bash
  sudo samba-tool group addmembers "Domain Admins" nome_usuario
  ```

* **Listar membros de um grupo:**
  ```bash
  sudo samba-tool group listmembers "Domain Admins"
  ```

#### 🏥 Manutenção do Banco de Dados LDB

* **Verificar a integridade do banco do Active Directory:**
  ```bash
  sudo samba-tool dbcheck
  ```

* **Testar o nível funcional do domínio:**
  ```bash
  sudo samba-tool domain info 127.0.0.1
  ```

---

### 📊 6. Monitoramento de Conexões e Arquivos Abertos (`smbstatus`)

O comando `smbstatus` mostra quem está conectado no servidor em tempo real e quais arquivos estão abertos/bloqueados.

* **Exibir relatório completo de sessões, compartilhamentos e bloqueios:**
  ```bash
  sudo smbstatus
  ```

* **Listar apenas as conexões ativas por usuário e máquina:**
  ```bash
  sudo smbstatus --processes
  ```

* **Listar os compartilhamentos que estão sendo acessados agora:**
  ```bash
  sudo smbstatus --shares
  ```

* **Listar arquivos que estão bloqueados (open/locked) no momento:**
  ```bash
  sudo smbstatus --locks
  ```

---

## 💻 7. Comandos do Cliente (Client-Side)

### 🐧 No Cliente Linux

#### 1. Listar compartilhamentos disponíveis em um servidor
```bash
smbclient -L //192.168.1.8 -U nome_usuario
```

#### 2. Conectar de forma interativa estilo CLI/FTP
```bash
smbclient //192.168.1.8/compartilhamento -U nome_usuario
```

#### 3. Montar compartilhamento manualmente via terminal
```bash
sudo mkdir -p /mnt/samba_pasta
sudo mount -t cifs -o username=administrador,password=SuaSenha,domain=MEUDOMINIO //192.168.1.8/arquivos /mnt/samba_pasta
```

#### 4. Montar compartilhamento de forma permanente no `/etc/fstab` (Recomendado)

1. Crie um arquivo de credenciais seguro em `/etc/samba/credentials`:
   ```bash
   sudo nano /etc/samba/credentials
   ```
   Adicione o conteúdo:
   ```ini
   username=administrador
   password=SuaSenhaSegura
   domain=MEUDOMINIO
   ```
2. Ajuste as permissões do arquivo:
   ```bash
   sudo chmod 600 /etc/samba/credentials
   ```
3. Adicione a linha no `/etc/fstab`:
   ```text
   //192.168.1.8/arquivos /mnt/samba_pasta cifs credentials=/etc/samba/credentials,iocharset=utf8,uid=1000,gid=1000,file_mode=0775,dir_mode=0775 0 0
   ```
4. Teste a montagem sem reiniciar:
   ```bash
   sudo mount -a
   ```

---

### 🪟 No Cliente Windows (CMD / PowerShell)

#### 1. Mapear unidade de rede no Windows
```cmd
net use Z: \\192.168.1.8\arquivos /user:MEUDOMINIO\administrador SuaSenha /persistent:yes
```

#### 2. Listar todas as conexões de rede mapeadas no Windows
```cmd
net use
```

#### 3. Desconectar uma unidade de rede específica (ex: drive Z:)
```cmd
net use Z: /delete
```

#### 4. Limpar TODAS as credenciais e conexões salvas do Samba no Windows
*(Útil para resolver problemas de login com usuário errado no Windows)*
```cmd
net use * /delete /yes
```

#### 5. Limpar o cache de credenciais do Windows via Prompt
```cmd
cmdkey /list
cmdkey /delete:TargetName=192.168.1.8
```

#### 6. Consultar o nome NetBIOS e IP do servidor
```cmd
nbtstat -A 192.168.1.8
```

---

## 🔒 8. Permissões POSIX ACL no Linux para o Samba

Para garantir que novos arquivos e pastas criados por usuários do Windows/Linux herdem as permissões corretas no disco do Linux:

```bash
# 1. Definir o proprietário e grupo padrão do compartilhamento
sudo chown -R www-data:www-data /var/www/arquivos
sudo chmod -R 775 /var/www/arquivos

# 2. Aplicar herança automática POSIX ACLs (setfacl)
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx /var/www/arquivos
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /var/www/arquivos

# 3. Visualizar as permissões detalhadas da pasta
getfacl /var/www/arquivos
```

---

## 📋 9. Modelo de `smb.conf` de Produção (Servidor de Arquivos)

Aqui está um exemplo de `/etc/samba/smb.conf` pronto e seguro para Servidor de Arquivos:

```ini
[global]
   workgroup = WORKGROUP
   server string = Servidor de Arquivos Samba %v
   netbios name = NUVEMSERVER
   security = user
   map to guest = Bad User
   dns proxy = no

   # Otimizações de Desempenho
   socket options = TCP_NODELAY SO_RCVBUF=65536 SO_SNDBUF=65536
   read raw = yes
   write raw = yes
   max xmit = 65535
   deadtime = 15

   # Logs
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

# COMPARTILHAMENTO PÚBLICO (SOMENTE LEITURA / ESCRITA)
[Publico]
   comment = Arquivos Publicos da Empresa
   path = /var/www/publico
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0775
   directory mask = 0775

# COMPARTILHAMENTO RESTRITO (EXIGE AUTENTICAÇÃO)
[ArquivosTI]
   comment = Arquivos Restritos do Setor de TI
   path = /var/www/ti
   browseable = yes
   writable = yes
   guest ok = no
   valid users = @ti, administrador
   create mask = 0770
   directory mask = 0770
```
