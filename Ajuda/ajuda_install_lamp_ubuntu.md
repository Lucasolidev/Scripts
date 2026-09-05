# 🌐 Guia Prático e Cheat Sheet - Instalação LAMP Automática e Endurecida (Ubuntu)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-0078D4?style=flat&logo=dependabot&logoColor=white)

Guia operacional rápido, referência de configurações e *cheat sheet* para a pilha **LAMP (Apache 2.4 + MariaDB 11.4 LTS + PHP-FPM)** configurada através do script [`install_lamp_ubuntu.sh`](../install_lamp_ubuntu.sh). Contém comandos essenciais de administração, validação de sintaxe, gerenciamento de banco de dados, tuning do PHP e controle de permissões com **POSIX ACLs**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_install_lamp_ubuntu_*.log` | Log timestamped com a saída completa da instalação da pilha LAMP. |
| `/root/relatorio_install_lamp_ubuntu_latest.log` | Atalho para o último log gerado da instalação LAMP. |
| `/etc/apache2/apache2.conf` | Arquivo mestre de configuração global do Apache 2.4. |
| `/etc/apache2/conf-available/security.conf` | Diretivas de segurança global (`ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off`). |
| `/etc/apache2/conf-available/lamp-php-fpm.conf` | Ponte FastCGI universal com `SetHandler` apontando para o socket do PHP-FPM. |
| `/etc/apache2/sites-available/000-default.conf` | VirtualHost padrão na porta 80 com suporte a `.htaccess` (`AllowOverride All`). |
| `/etc/php/<versao>/fpm/php.ini` | Configuração mestre do interpretador PHP para requisições web via FPM. |
| `/run/php/php<versao>-fpm.sock` | Socket Unix de comunicação ultra-rápida entre o Apache e o PHP-FPM. |
| `/var/log/apache2/access.log` | Log de requisições e acessos HTTP/HTTPS recebidos pelo Apache. |
| `/var/log/apache2/error.log` | Log de erros do Apache e erros internos capturados do PHP (`log_errors = On`). |
| `/var/www/html/info.php` | Página de diagnóstico do ambiente PHP/Apache (remova em ambiente de produção). |

---

## ⚙️ 2. Execução Rápida do Script

### Execução via Linha Única
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh -O install_lamp_ubuntu.sh && chmod +x install_lamp_ubuntu.sh && sudo ./install_lamp_ubuntu.sh
```

### O que o instalador aplica automaticamente:
* **Isolamento de SO (Regra 9)**: No Ubuntu 22.04/24.04 LTS instala PHP 8.3 via PPA oficial `ondrej/php`. No Ubuntu 26.04 Dev instala o PHP nativo com resolução dinâmica de sockets.
* **Apache Otimizado**: Módulos modernos ativados (`rewrite`, `ssl`, `headers`, `deflate`, `expires`, `http2`, `remoteip`, `env`, `dir`, `mime`, `setenvif`) e inseguros desativados (`autoindex`, `status`, `mpm_prefork`).
* **Hardening no MariaDB**: Execução SQL via `mktemp` com suporte idempotente e preservação do login transparente `sudo mariadb` via `unix_socket`.
* **Hardening no PHP**: `display_errors = Off`, `log_errors = On`, `session.cookie_httponly = 1`, `session.cookie_samesite = "Lax"`, `session.use_only_cookies = 1`, `opcache.enable_cli = 1` e funções perigosas desativadas (`disable_functions`).
* **POSIX ACLs e Travessia**: Permissões de execução `+x` nos diretórios pai e herança mútua de permissões `rwx` entre `www-data` e o desenvolvedor (`DEV_USER`).

---

## 🌐 3. Operação e Gestão do Apache 2.4

### 3.1 Teste de Sintaxe e Recarga sem Queda (*Graceful*)
```bash
# Valida a sintaxe dos arquivos de configuração antes de aplicar alterações
sudo apache2ctl configtest
# OU de forma simplificada:
sudo apache2 -t

# Recarrega configurações sem derrubar conexões ativas de clientes (Zero Downtime)
sudo systemctl reload apache2

# Reiniciar o serviço Apache2
sudo systemctl restart apache2

# Verificar status detalhado do processo
sudo systemctl status apache2
```

### 3.2 Habilitação e Desativação de Módulos e Sites
```bash
# Habilitar um módulo (ex: headers)
sudo a2enmod headers

# Desabilitar módulos de risco (ex: listagem de diretórios)
sudo a2dismod -f autoindex status

# Habilitar uma configuração ou VirtualHost
sudo a2enconf lamp-php-fpm
sudo a2ensite meu_site.conf

# Desabilitar um VirtualHost
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

---

## ⚡ 4. Gestão do PHP e PHP-FPM

### 4.1 Comandos de Serviço e Sockets
```bash
# Verificar status do PHP-FPM (substitua pela versão ativa, ex: 8.3)
sudo systemctl status php8.3-fpm

# Reiniciar o serviço PHP-FPM após alterar o php.ini
sudo systemctl restart php8.3-fpm

# Localizar o socket Unix ativo do PHP-FPM
ls -la /run/php/php*-fpm.sock
```

### 4.2 Verificação de Extensões e Versão no Terminal
```bash
# Exibir versão ativa do PHP CLI
php -v

# Listar todas as extensões PHP carregadas
php -m

# Verificar valores de diretivas do php.ini via terminal
php -i | grep memory_limit
php -i | grep opcache.enable
```

---

## 🗄️ 5. Administração do MariaDB Server

### 5.1 Acesso Administrativo e Status
```bash
# Conectar como root diretamente no terminal local (via Unix Socket nativo)
sudo mariadb

# Conectar informando usuário e solicitando senha
mariadb -u root -p

# Verificar status do daemon MariaDB
sudo systemctl status mariadb
```

### 5.2 Comandos SQL Essenciais
```sql
-- Listar bancos de dados existentes
SHOW DATABASES;

-- Criar novo banco em UTF8MB4
CREATE DATABASE `meu_banco` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Criar usuário com senha e conceder privilégios totais
CREATE USER 'meu_usuario'@'localhost' IDENTIFIED BY '<senha_segura>';
GRANT ALL PRIVILEGES ON `meu_banco`.* TO 'meu_usuario'@'localhost';
FLUSH PRIVILEGES;

-- Listar usuários e métodos de autenticação
SELECT User, Host, plugin FROM mysql.user;
```

---

## 🔒 6. Gestão de Permissões Granulares (POSIX ACLs)

Se um desenvolvedor (ex: `zelio_dev`) precisar de acesso SFTP/SSH ao diretório do site:

```bash
# 1. Garantir permissão de travessia nos diretórios pai
sudo chmod o+x /var /var/www /var/www/html

# 2. Aplicar permissões recursivas e de herança contínua para www-data e o desenvolvedor
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx,u:zelio_dev:rwx,g:zelio_dev:rwx /var/www/html
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx,u:zelio_dev:rwx,g:zelio_dev:rwx /var/www/html

# 3. Visualizar as ACLs ativas no diretório
getfacl /var/www/html
```

---

## 📊 7. Monitoramento de Logs em Tempo Real

```bash
# Monitorar requisições em tempo real
sudo tail -f /var/log/apache2/access.log

# Monitorar erros do Apache e scripts PHP em tempo real
sudo tail -f /var/log/apache2/error.log

# Filtrar acessos HTTP 500 (Internal Server Error)
sudo grep "HTTP/1.1\" 500" /var/log/apache2/access.log
```
