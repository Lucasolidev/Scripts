# 🚀 Guia Prático e Cheat Sheet - Instalação LEMP Automática e Endurecida (Ubuntu)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-0078D4?style=flat&logo=dependabot&logoColor=white)

Guia operacional rápido, referência de configurações e *cheat sheet* para a pilha **LEMP (Nginx Engine + MariaDB Server + PHP-FPM)** configurada através do script [`install_lemp_ubuntu.sh`](../install_lemp_ubuntu.sh). Contém comandos essenciais para gerenciamento do Nginx, validação de sintaxe, tuning de WebSockets, segurança e controle de permissões **POSIX ACLs**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_install_lemp_ubuntu_*.log` | Log timestamped com a saída completa da instalação da pilha LEMP. |
| `/root/relatorio_install_lemp_ubuntu_latest.log` | Atalho para o último log gerado da instalação LEMP. |
| `/etc/nginx/nginx.conf` | Arquivo principal de configuração global do Nginx. |
| `/etc/nginx/conf.d/tuning.conf` | Ajustes de alta performance (`worker_rlimit_nofile 65535`) e ocultação de versão (`server_tokens off`). |
| `/etc/nginx/conf.d/websocket.conf` | Mapeamento dinâmico para suporte a WebSockets sem interrupção de Keep-Alive HTTP. |
| `/etc/nginx/sites-available/<dominio>` | Configuração do VirtualHost (Server Block) do domínio configurado. |
| `/etc/nginx/sites-enabled/<dominio>` | Link simbólico ativando o VirtualHost no Nginx. |
| `/etc/php/<versao>/fpm/php.ini` | Configuração mestre do PHP-FPM para requisições web. |
| `/var/log/nginx/<dominio>_access.log` | Log de acessos HTTP/HTTPS exclusivo do domínio configurado. |
| `/var/log/nginx/<dominio>_error.log` | Log de erros de requisições e processamento do Nginx. |

---

## ⚙️ 2. Execução Rápida do Script

### Execução via Linha Única
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lemp_ubuntu.sh -O install_lemp_ubuntu.sh && chmod +x install_lemp_ubuntu.sh && sudo ./install_lemp_ubuntu.sh
```

### O que o instalador aplica automaticamente:
* **Nginx de Alta Performance**: Suporte nativo a HTTP/2, FastCGI com PHP-FPM, WebSockets e desativação de métodos HTTP inseguros (`if ($request_method !~ ^(GET|POST|HEAD)$ ) { return 405; }`).
* **Headers de Segurança Nativos**: Injeção de `X-Content-Type-Options "nosniff"`, `X-Frame-Options "SAMEORIGIN"`, `X-XSS-Protection "1; mode=block"` e `Referrer-Policy "strict-origin-when-cross-origin"`.
* **Hardening no MariaDB**: Execução SQL via `mktemp` com proteção idempotente e autenticação nativa `unix_socket` via `sudo mariadb`.
* **Hardening no PHP-FPM**: Timeouts ajustados, upload configurável, `display_errors = Off`, `session.use_only_cookies = 1` e funções críticas desativadas.
* **POSIX ACLs e Travessia**: Permissões de execução `+x` nos diretórios pai e herança mútua de permissões `rwx` entre `www-data` e o desenvolvedor (`DEV_USER`).

---

## 🌐 3. Operação e Gestão do Nginx

### 3.1 Teste de Sintaxe e Recarga sem Queda (*Zero Downtime*)
```bash
# ⚠️ MANDATÓRIO: Sempre testar a sintaxe antes de qualquer recarga!
sudo nginx -t

# Recarrega configurações sem derrubar conexões ativas (Zero Downtime)
sudo systemctl reload nginx

# Reiniciar o serviço Nginx
sudo systemctl restart nginx

# Verificar status detalhado do daemon
sudo systemctl status nginx
```

### 3.2 Habilitação e Desativação de Sites no Nginx
```bash
# Criar o link simbólico para ativar um site
sudo ln -sf /etc/nginx/sites-available/meu_site.com.br /etc/nginx/sites-enabled/

# Desativar um site (remover apenas o link simbólico)
sudo rm -f /etc/nginx/sites-enabled/meu_site.com.br
sudo nginx -t && sudo systemctl reload nginx
```

---

## ⚡ 4. Gestão do PHP-FPM com Nginx

### 4.1 Comandos de Serviço e Sockets
```bash
# Verificar status do PHP-FPM (ex: PHP 8.3)
sudo systemctl status php8.3-fpm

# Reiniciar o PHP-FPM
sudo systemctl restart php8.3-fpm

# Localizar arquivos de socket do FPM
ls -la /run/php/php*-fpm.sock /var/run/php/php*-fpm.sock
```

---

## 🗄️ 5. Administração do MariaDB Server

```bash
# Conectar localmente sem senha usando privilégios sudo (Unix Socket)
sudo mariadb

# Conectar solicitando senha do usuário root
mariadb -u root -p

# Reiniciar o serviço MariaDB
sudo systemctl restart mariadb
```

---

## 🔒 6. Gestão de Permissões Granulares (POSIX ACLs)

Para liberar acesso SFTP/SSH a um usuário desenvolvedor (ex: `zelio_dev`):

```bash
# 1. Garantir permissões de travessia nas pastas pai
sudo chmod o+x /var /var/www /var/www/html

# 2. Aplicar ACLs com herança recursiva para www-data e zelio_dev
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx,u:zelio_dev:rwx,g:zelio_dev:rwx /var/www/html
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx,u:zelio_dev:rwx,g:zelio_dev:rwx /var/www/html

# 3. Auditar as ACLs aplicadas
getfacl /var/www/html
```

---

## 📊 7. Monitoramento de Logs do Nginx

```bash
# Acompanhar requisições em tempo real
sudo tail -f /var/log/nginx/*access.log

# Acompanhar erros de FastCGI / Nginx em tempo real
sudo tail -f /var/log/nginx/*error.log

# Filtrar requisições bloqueadas por métodos HTTP ou regras de segurança (HTTP 403 / 405)
sudo grep -E " (403|405) " /var/log/nginx/*access.log
```
