# 🔴 Cheat Sheet - Administração Apache2 (Ubuntu / Debian)

![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência rápida para administração do servidor web **Apache2** em ambientes Debian/Ubuntu.

---

## 📁 Estrutura de Arquivos e Diretórios Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/apache2/` | Diretório raiz de todas as configurações do Apache. |
| `/etc/apache2/apache2.conf` | Arquivo principal de configuração global do servidor. |
| `/etc/apache2/ports.conf` | Define as portas onde o Apache escuta (ex: `Listen 80`, `Listen 443`). |
| `/etc/apache2/sites-available/` | Guarda os arquivos de VirtualHost criados (`.conf`). |
| `/etc/apache2/sites-enabled/` | Links simbólicos dos sites que estão **ATIVOS** no servidor. |
| `/etc/apache2/conf-available/` | Configurações globais opcionais (ex: `phpmyadmin.conf`, `security.conf`). |
| `/etc/apache2/conf-enabled/` | Links simbólicos de configurações globais ativas. |
| `/etc/apache2/mods-available/` | Módulos do Apache disponíveis (`rewrite`, `ssl`, `headers`, `proxy`). |
| `/etc/apache2/mods-enabled/` | Módulos atualmente ativos e carregados no servidor. |
| `/var/www/html/` | Diretório raiz padrão de documentos públicos (DocumentRoot). |
| `/var/log/apache2/error.log` | Log principal de erros do Apache e depuração do PHP. |
| `/var/log/apache2/access.log` | Log de acessos e requisições HTTP recebidas. |

---

## 🛠️ Comandos Principais de Gerenciamento do Serviço

### Testar a sintaxe dos arquivos de configuração (CRÍTICO - Sempre execute antes de reiniciar)
```bash
sudo apache2ctl configtest
# Ou de forma simplificada:
sudo apache2ctl -t
```

### Reiniciar o Apache2 (Aplica alterações completas de porta ou módulos)
```bash
sudo systemctl restart apache2
```

### Recarregar o Apache2 sem derrubar conexões ativas (Graceful Reload — Recomendado)
```bash
sudo systemctl reload apache2
```

### Verificar o status de execução do serviço
```bash
sudo systemctl status apache2
```

### Iniciar / Parar o serviço
```bash
sudo systemctl start apache2
sudo systemctl stop apache2
```

### Habilitar / Desabilitar a inicialização automática no boot do sistema
```bash
sudo systemctl enable apache2
sudo systemctl disable apache2
```

### Listar todos os VirtualHosts ativos e suas respectivas portas
```bash
sudo apache2ctl -S
```

### Listar todos os módulos atualmente carregados na memória
```bash
sudo apache2ctl -M
```

---

## 🌐 Gerenciamento de VirtualHosts (`a2ensite` / `a2dissite`)

### Habilitar um novo site / VirtualHost
```bash
sudo a2ensite meu_site.conf
sudo systemctl reload apache2
```

### Desabilitar um site / VirtualHost ativo
```bash
sudo a2dissite meu_site.conf
# Exemplo para desativar o site padrão inicial:
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

### 📄 Modelo Completo de VirtualHost HTTP (`/etc/apache2/sites-available/meu_site.conf`)
```apache
<VirtualHost *:80>
    ServerName meu_dominio.com.br
    ServerAlias www.meu_dominio.com.br
    ServerAdmin admin@meu_dominio.com.br

    DocumentRoot /var/www/meu_site

    <Directory /var/www/meu_site>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Configuração de Logs por Site
    ErrorLog ${APACHE_LOG_DIR}/meu_site_error.log
    CustomLog ${APACHE_LOG_DIR}/meu_site_access.log combined
</VirtualHost>
```

### 📄 Modelo Completo de VirtualHost HTTPS com SSL (`/etc/apache2/sites-available/meu_site-ssl.conf`)
```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName meu_dominio.com.br
    ServerAlias www.meu_dominio.com.br
    ServerAdmin admin@meu_dominio.com.br

    DocumentRoot /var/www/meu_site

    <Directory /var/www/meu_site>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/meu_dominio.com.br/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/meu_dominio.com.br/privkey.pem

    ErrorLog ${APACHE_LOG_DIR}/meu_site_ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/meu_site_ssl_access.log combined
</VirtualHost>
</IfModule>
```

---

## 🔌 Gerenciamento de Módulos (`a2enmod` / `a2dismod`)

### Habilitar `mod_rewrite` (Obrigatório para arquivos `.htaccess` e frameworks como Laravel/WordPress)
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

### Habilitar módulo SSL (Para conexões seguras HTTPS)
```bash
sudo a2enmod ssl
sudo systemctl restart apache2
```

### Habilitar módulos de Proxy Reverso (Proxy HTTP/WebSocket para Node.js, Python, Docker)
```bash
sudo a2enmod proxy proxy_http proxy_wstunnel headers
sudo systemctl restart apache2
```

### Desabilitar um módulo ativo
```bash
sudo a2dismod nome_do_modulo
sudo systemctl restart apache2
```

---

## 🔒 Permissões de Arquivos & POSIX ACLs de Herança Automática

### 1. Ajustar o proprietário Unix e permissões padrão
```bash
sudo chown -R www-data:www-data /var/www/meu_site
sudo find /var/www/meu_site -type d -exec chmod 755 {} \;
sudo find /var/www/meu_site -type f -exec chmod 644 {} \;
```

### 2. Aplicar POSIX ACLs com Herança Automática (Enterprise)
> 💡 *Qualquer novo arquivo ou pasta criado dentro de `/var/www/` (mesmo por `root` ou `git`) herdará automaticamente permissão total de acesso para o `www-data`!*

```bash
# Garantir que o utilitário de ACL está instalado
sudo apt-get install -y acl

# Permissão nos arquivos existentes
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx /var/www/

# Regra DEFAULT (Herança Automática para futuros arquivos e pastas)
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /var/www/

# Verificar as ACLs ativas em um diretório
getfacl /var/www/html
```

### 3. Esconder a versão do Apache nos cabeçalhos (Hardening de Segurança)
Edite o arquivo `/etc/apache2/conf-available/security.conf` ou adicione no final do `/etc/apache2/apache2.conf`:
```apache
ServerTokens Prod
ServerSignature Off
```
Em seguida, recarregue o Apache:
```bash
sudo systemctl reload apache2
```

---

## 🔍 Diagnóstico e Resolução de Problemas (Troubleshooting)

### Acompanhar logs de erro e acessos em tempo real
```bash
# Log de erros
sudo tail -f /var/log/apache2/error.log

# Log de acessos HTTP
sudo tail -f /var/log/apache2/access.log

# Filtrar acessos por IP ou código de erro HTTP (ex: erro 500)
sudo cat /var/log/apache2/access.log | grep " 500 "
sudo cat /var/log/apache2/access.log | grep "192.168.1.50"
```

### Verificar se a porta 80 ou 443 está aberta e escutando
```bash
sudo ss -tulpn | grep -E '80|443|apache'
```

### Principais Erros e Soluções:
* **`403 Forbidden`**: Verifique se o diretório tem permissão de leitura (`chmod 755` ou `Require all granted` no VirtualHost) ou se falta um arquivo `index.html` / `index.php`.
* **`500 Internal Server Error`**: Geralmente causado por sintaxe inválida dentro do arquivo `.htaccess` ou erro no script PHP. Consulte o log `/var/log/apache2/error.log`.
* **`Port 80 in use`**: Outro serviço (como Nginx ou Lighttpd) está ocupando a porta 80. Use `sudo ss -tulpn | grep :80` para descobrir o processo ocupante.

---

## 🔐 Certificado SSL Gratuito com Let's Encrypt (Certbot)

### 1. Instalar o Certbot para Apache no Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y certbot python3-certbot-apache
```

### 2. Gerar e aplicar o certificado SSL automaticamente
```bash
sudo certbot --apache -d meu_dominio.com.br -d www.meu_dominio.com.br
```

### 3. Testar a renovação automática do certificado
```bash
sudo certbot renew --dry-run
```
