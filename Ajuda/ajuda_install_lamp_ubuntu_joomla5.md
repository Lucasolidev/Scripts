# 🇯 Guia Prático e Cheat Sheet - Instalação LAMP Endurecida para Joomla 5 (Ubuntu)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Joomla](https://img.shields.io/badge/Joomla_5-5091CD?style=flat&logo=joomla&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB_11.4_LTS-003545?style=flat&logo=mariadb&logoColor=white)
![PHP](https://img.shields.io/badge/PHP_8.3-777BB4?style=flat&logo=php&logoColor=white)
![Auditd](https://img.shields.io/badge/Auditd-Realtime_Monitor-0078D4?style=flat&logo=linux&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened_v2.1-28A745?style=flat&logo=dependabot&logoColor=white)

Guia operacional rápido, referência técnica e *cheat sheet* para o ambiente de produção **Joomla 5** configurado através do script [`install_lamp_ubuntu_joomla5.sh`](../install_lamp_ubuntu_joomla5.sh). Abrange a operação do **Apache 2.4 com FastCGI/HTTP2**, **MariaDB 11.4 LTS (UTF8MB4)**, **PHP 8.3/8.5 (OPcache, APCu e Redis)**, **Blindagem Anti-Webshells**, **Auditoria em Tempo Real (Auditd)**, rotinas CLI do **Cron**, segurança com **Fail2Ban/UFW** e permissões **POSIX ACLs**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_install_lamp_ubuntu_joomla5_*.log` | Log timestamped com a saída completa da instalação do ambiente Joomla 5. |
| `/root/relatorio_install_lamp_ubuntu_joomla5_latest.log` | Atalho fixo apontando para o último log gerado. |
| `/etc/apache2/sites-available/<dominio>.conf` | VirtualHost otimizado com regras anti-webshell, bloqueio de arquivos sensíveis e headers. |
| `/etc/apache2/sites-available/000-default.conf` | VirtualHost padrão blindado impedindo execução de PHP em pastas estáticas. |
| `/etc/mysql/mariadb.conf.d/60-joomla5.cnf` | Tuning do MariaDB (UTF8MB4, `innodb_buffer_pool_size = 256M`, `max_allowed_packet = 64M`). |
| `/etc/cron.d/joomla5_<dominio>_scheduler` | Agendador do Cron executando `cli/joomla.php scheduler:run` a cada 5 minutos como `www-data`. |
| `/etc/audit/rules.d/web_security.rules` | Regras ativas do Auditd monitorando criação, escrita e modificação de arquivos web. |
| `/etc/fail2ban/jail.d/apache-joomla.local` | Jaula modular do Fail2Ban com bloqueio automatico de ataques web e scanners (BadBots). |
| `<JOOMLA_ROOT>/configuration.php` | Arquivo mestre de configuração e banco de dados do Joomla 5. |
| `<JOOMLA_ROOT>/.htaccess` | Regras de reescrita ativas para URLs amigáveis (SEF) e segurança de rotas. |

---

## ⚙️ 2. Execução Rápida do Script

### Execução via Linha Única
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu_joomla5.sh -O install_lamp_ubuntu_joomla5.sh && chmod +x install_lamp_ubuntu_joomla5.sh && sudo ./install_lamp_ubuntu_joomla5.sh
```

### O que o instalador aplica automaticamente (v2.1):
* **Download Oficial do Joomla 5.x**: Baixa e descompacta automaticamente a última versão estável oficial do Joomla 5 no DocumentRoot.
* **Blindagem Anti-Webshell no Apache**: Bloqueio de execução de scripts PHP (`.php`, `.phtml`, `.php5`, `.inc`) dentro das pastas `assets`, `images`, `cache`, `tmp`, `media` e `phocadownloadpap`.
* **Bloqueio de Extensões Sensíveis**: Nega acesso direto via web para extensões de backup e scripts (`.log`, `.sql`, `.bak`, `.old`, `.orig`, `.ini`, `.sh`, `.tar`, `.gz`, `.zip`).
* **Proteção de Arquivos Ocultos**: Bloqueia acesso a `.git`, `.env`, `.user.ini`, preservando o funcionamento pleno do `.htaccess`.
* **Suíte PHP Completa e Hardening**: Instala PHP 8.3/8.5 com `disable_functions` rigoroso (`exec`, `shell_exec`, `system`, `passthru`, `proc_open`, `popen`, `show_source`, `pcntl_exec`), `session.cookie_httponly = 1`, `session.cookie_samesite = 'Lax'`.
* **Auditoria em Tempo Real (Auditd)**: Monitora em ncvel de kernel qualquer alteração, criação ou deleção de arquivos no diretório web (`-k web_modificacoes`).
* **Cron Oficial Integrado**: Cria o agendador de 5 minutos executando `cli/joomla.php scheduler:run` para limpeza de cache e publicação de artigos.
* **POSIX ACLs e Travessia**: Permissões `775/664` com herança contínua mútua entre `www-data` e o desenvolvedor (`DEV_USER`).

---

## 🌐 3. Operação e Gestão do Apache

### 3.1 Testes de Sintaxe e Reinicialização
```bash
# Validar arquivos de configuração antes de reiniciar
sudo apache2ctl configtest

# Recarregar configurações sem queda de conexões (Graceful Reload)
sudo systemctl reload apache2

# Reiniciar o serviço Apache2
sudo systemctl restart apache2
```

### 3.2 Habilitação e Desativação de Sites
```bash
# Habilitar o VirtualHost do Joomla 5
sudo a2ensite meu_site.com.br.conf
sudo systemctl reload apache2

# Desabilitar o site padrão do Apache
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

---

## ⚡ 4. Gestão do PHP-FPM, APCu e OPcache

### 4.1 Comandos de Serviço
```bash
# Verificar status do PHP-FPM
sudo systemctl status php8.3-fpm

# Reiniciar o PHP-FPM (necessário após editar php.ini ou atualizar módulos)
sudo systemctl restart php8.3-fpm
```

### 4.2 Verificação de Módulos e Aceleração do Joomla
```bash
# Verificar se APCu, Redis e OPcache estão ativos
php -m | grep -E "apcu|redis|Zend OPcache|igbinary"

# Checar limites de memória, uploads e funções bloqueadas
php -i | grep -E "memory_limit|upload_max_filesize|post_max_size|disable_functions"
```

---

## 🗄 5. Administração do MariaDB Server (Joomla 5)

### 5.1 Acesso Administrativo Direto
```bash
# Acesso nativo via Unix Socket (sem senha no terminal com sudo)
sudo mariadb

# Acesso com usuário e senha do Joomla
mariadb -u joomla_usuario_usr -p joomla_banco_db
```

### 5.2 Comandos Úteis de Manutenção no Banco
```sql
-- Verificar tabelas do Joomla 5
USE `joomla_meubanco_db`;
SHOW TABLES;

-- Checar tamanho das tabelas e do banco de dados
SELECT table_name AS "Tabela",
ROUND(((data_length + index_length) / 1024 / 1024), 2) AS "Tamanho_MB"
FROM information_schema.TABLES
WHERE table_schema = "joomla_meubanco_db"
ORDER BY (data_length + index_length) DESC LIMIT 10;
```

---

## 🔍 6. Auditoria Forense e Tempo Real com Auditd

Para detalhes completos de auditoria e interpretação forense, consulte o guia especializado [`ajuda_auditd.md`](ajuda_auditd.md).

```bash
# 1. Consultar qualquer arquivo criado, modificado ou deletado no Joomla
sudo ausearch -k web_modificacoes -i

# 2. Consultar eventos recentes (últimos 10 minutos)
sudo ausearch -k web_modificacoes -ts recent -i

# 3. Gerar relatório sumário de alterações em arquivos
sudo aureport -f -i --summary

# 4. Validar se o daemon auditd está operacional
sudo systemctl status auditd
```

---

## ⚙️ 7. Gestão das Tarefas Agendadas (Cron CLI do Joomla 5)

O Joomla 5 utiliza uma rotina CLI nativa que dispensa chamadas via `wget` ou `curl` externo.

```bash
# Executar manualmente o agendador de tarefas do Joomla como www-data
sudo -u www-data php /var/www/html/meu_site.com.br/cli/joomla.php scheduler:run

# Listar as tarefas registradas no Joomla
sudo -u www-data php /var/www/html/meu_site.com.br/cli/joomla.php scheduler:list

# Verificar o agendamento no sistema operacional
cat /etc/cron.d/joomla5_*
```

---

## 🔒 8. Gestão de Permissões Granulares (POSIX ACLs)

Para conceder acesso total a um desenvolvedor (ex: `developer_user`) na pasta do site (inclusive em pontos de montagem como `/arquivos/sistemas/site/meusite`):

```bash
# 1. Garantir permissões de travessia em todas as pastas pai
sudo chmod o+x /arquivos /arquivos/sistemas /arquivos/sistemas/site

# 2. Aplicar permissões recursivas e herança padrão para www-data e o desenvolvedor
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx,u:developer_user:rwx,g:developer_user:rwx /var/www/html/meu_site.com.br
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx,u:developer_user:rwx,g:developer_user:rwx /var/www/html/meu_site.com.br

# 3. Auditar a herança de permissões ativa
getfacl /var/www/html/meu_site.com.br
```

---

## 🛁️ 9. Monitoramento de Segurança (Fail2Ban & Logs)

```bash
# Verificar status da jaula Apache/Joomla no Fail2Ban
sudo fail2ban-client status apache-badbots
sudo fail2ban-client status apache-auth
sudo fail2ban-client status joomla-admin

# Desbloquear um IP bloqueado por engano
sudo fail2ban-client set apache-badbots unbanip 192.168.1.100
sudo fail2ban-client set joomla-admin unbanip 192.168.1.100

# Acompanhar logs de acessos e erros do Joomla e Apache em tempo real
sudo tail -f /var/log/apache2/*access.log
sudo tail -f /var/log/apache2/*error.log
```
