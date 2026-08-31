# 📋 Checklist de Coleta Pré-Migração de Servidor Web (Joomla & Aplicações PHP)

![Migration](https://img.shields.io/badge/Migration-Ready-blue?style=flat&logo=serverfault&logoColor=white)
![Joomla](https://img.shields.io/badge/Joomla_5-5091CD?style=flat&logo=joomla&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)

Este documento reúne todas as informações, arquivos, credenciais e parâmetros essenciais que devem ser coletados e salvos no **servidor em produção atual** antes de iniciar o processo de migração para o novo ambiente Ubuntu Server.

---

## 📑 Índice Rápido
1. [Configurações da Aplicação (`configuration.php`)](#1--configurações-da-aplicação-configurationphp)
2. [Backup do Banco de Dados (MariaDB / MySQL)](#2--backup-do-banco-de-dados-mariadb--mysql)
3. [Compactação e Arquivos do Site](#3--compactação-e-arquivos-do-site)
4. [Mapeamento de Rotinas Agendadas (Cron Jobs)](#4--mapeamento-de-rotinas-agendadas-cron-jobs)
5. [Certificados SSL e Ajustes de DNS](#5--certificados-ssl-e-ajustes-de-dns)
6. [Tabela de Parâmetros para Preenchimento](#6--tabela-de-parâmetros-para-preenchimento)
7. [Roteiro de Restauração no Novo Servidor](#7--roteiro-de-restauração-no-novo-servidor)

---

## 1. 🗂️ Configurações da Aplicação (`configuration.php`)

Localizado na raiz da aplicação web atual (ex: `/var/www/html/configuration.php` ou `/var/www/meusite/configuration.php`).

### 🔍 Parâmetros a extrair do arquivo:
```php
// Conexão com o Banco de Dados (Use os mesmos valores no script para facilitar)
public $dbtype = '<driver_mysqli>';          // Tipo de driver
public $host = '<host_do_banco>';            // Host do banco
public $user = '<usuario_do_banco>';         // Usuário do banco
public $password = '<senha_do_usuario>';     // Senha do usuário em texto plano
public $db = '<nome_da_base_de_dados>';      // Nome da base de dados
public $dbprefix = '<prefixo_tabelas_jos_>'; // Prefixo das tabelas (MANDATÓRIO)

// Segurança e Chave Criptográfica
public $secret = '<chave_secreta_unica>';    // Mantém hashes e sessões válidas

// Configuração de Envio de E-mails
public $mailer = '<metodo_smtp_ou_mail>';    // mail ou smtp
public $mailfrom = '<email_remetente>';
public $fromname = '<nome_do_site>';
public $smtphost = '<host_servidor_smtp>';
public $smtpport = '<porta_smtp_587_465>';   // 465 (SSL) ou 587 (TLS)
public $smtpauth = true;                     // true ou false
public $smtpuser = '<usuario_smtp>';
public $smtppass = '<senha_smtp>';
public $smtpsecure = '<tls_ou_ssl>';

// Caminhos Locais Antigos (Deverão ser adaptados no novo servidor)
public $log_path = '/var/www/.../administrator/logs';
public $tmp_path = '/var/www/.../tmp';
```

> 💡 **Dica de Ouro**: Se você utilizar o mesmo **Nome do Banco**, **Usuário** e **Senha** durante a execução do `install_lamp_ubuntu_joomla5.sh`, o Joomla já conectará de primeira sem precisar reconfigurar as credenciais do banco!

---

## 2. 🛢️ Backup do Banco de Dados (MariaDB / MySQL)

Gere um dump completo, transacional e com suporte completo a caracteres `utf8mb4`:

```bash
# 1. Identificar a versão e charset atual:
mariadb --version 2>/dev/null || mysql --version

# 2. Gerar o dump consistente com rotinas e triggers:
mysqldump -u root -p \
  --single-transaction \
  --routines \
  --triggers \
  --default-character-set=utf8mb4 \
  NOME_DO_BANCO_ATUAL > backup_joomla_origem.sql

# 3. Compactar o dump para transferência rápida:
gzip -9 backup_joomla_origem.sql
# Resultado: backup_joomla_origem.sql.gz
```

---

## 3. 📁 Compactação e Arquivos do Site

Gere uma cópia compactada preservando permissões e arquivos ocultos (`.htaccess`, `.user.ini`):

```bash
# 1. Navegar até o diretório pai ou raiz do site:
cd /caminho/do/site/atual

# 2. Compactar mantendo permissões originais:
tar -czvf /tmp/joomla_files_origem.tar.gz .

# 3. Verificar o tamanho total gerado:
ls -lh /tmp/joomla_files_origem.tar.gz

# 4. Verificar se há regras customizadas no .htaccess:
cat .htaccess | grep -E "RewriteCond|RewriteRule|Redirect|Header|Deny"
```

---

## 4. ⏰ Mapeamento de Rotinas Agendadas (Cron Jobs)

Verifique se existem tarefas automáticas no agendador do Linux:

```bash
# Verificar crontab do root:
sudo crontab -l

# Verificar crontab do usuário web:
sudo crontab -u www-data -l

# Verificar agendamentos em arquivos do sistema:
ls -la /etc/cron.d/
cat /etc/cron.d/* 2>/dev/null
```

---

## 5. 🌐 Certificados SSL e Ajustes de DNS

### ⏳ Ação Prévia (24 a 48 horas antes da migração):
* Acesse o painel da sua Zona de DNS (Registro.br, Cloudflare, Route53, etc.).
* **Reduza o TTL (Time-To-Live)** dos apontamentos `@` e `www` para **300 segundos (5 minutos)**.
* Isso garante que, quando o IP for trocado para o novo servidor, a propagação mundial ocorra em poucos minutos.

### 🔒 Certificados Digitais SSL existentes:
Se você utiliza certificados comerciais próprios emitidos previamente, faça o backup dos seguintes arquivos:
* Certificado (`.crt` ou `certificate.crt`)
* Chave Privada (`.key` ou `private.key`)
* Cadeia Intermediária (`ca-bundle.crt` ou `bundle.crt`)

---

## 6. 📝 Tabela de Parâmetros para Preenchimento

Imprima ou anote estes dados antes de desligar o servidor antigo:

| Parâmetro | Valor no Servidor Atual | Observações |
| :--- | :--- | :--- |
| **Domínio Oficial** | | Ex: `prototipo.net.br` |
| **IP do Servidor Novo** | | Para apontamento DNS |
| **Ponto de Montagem Novo** | | Ex: `/mnt/dados/prototipo.net.br` |
| **Nome da Base de Dados** | | `public $db` |
| **Usuário do Banco** | | `public $user` |
| **Senha do Usuário Banco** | | `public $password` |
| **Prefixo das Tabelas** | | `public $dbprefix` (ex: `jos_`) |
| **Servidor SMTP E-mail** | | `public $smtphost` |
| **Porta SMTP** | | `public $smtpport` (587 / 465) |
| **Usuário SMTP** | | `public $smtpuser` |
| **Senha SMTP** | | `public $smtppass` |

---

## 7. 🚀 Roteiro de Restauração no Novo Servidor

Após coletar os arquivos `backup_joomla_origem.sql.gz` e `joomla_files_origem.tar.gz`:

```bash
# 1. No novo servidor, prepare o SO base:
sudo ./pos_install_server.sh

# 2. Instale e configure o ambiente LAMP Joomla 5:
sudo ./install_lamp_ubuntu_joomla5.sh
# (Informe o domínio, diretório no disco correto e credenciais do banco)

# 3. Extrair os arquivos do site no diretório configurado:
tar -xzvf joomla_files_origem.tar.gz -C /caminho/do/diretorio/web/

# 4. Restaurar a base de dados:
gunzip < backup_joomla_origem.sql.gz | mariadb -u root -p NOME_DO_BANCO

# 5. Ajustar os caminhos no configuration.php do novo servidor:
# Edite: public $log_path e public $tmp_path para o novo diretório web

# 6. Reaplicar permissões seguras e POSIX ACLs:
chown -R www-data:www-data /caminho/do/diretorio/web/
chmod -R 775 /caminho/do/diretorio/web/
setfacl -R -m u:www-data:rwx,g:www-data:rwx /caminho/do/diretorio/web/
setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /caminho/do/diretorio/web/

# 7. Apontar o DNS (Tipo A) para o IP do novo servidor.
```
