# 🔴 Cheat Sheet - Administração Apache2 (Ubuntu / Debian)

![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

## 📁 Estrutura de Arquivos e Diretórios Chave

| Caminho | Descrição |
| :--- | :--- |
| `/etc/apache2/apache2.conf` | Arquivo principal de configuração global do Apache. |
| `/etc/apache2/ports.conf` | Define as portas em que o Apache escuta (ex: 80, 443). |
| `/etc/apache2/sites-available/` | Guarda todos os arquivos de VirtualHost criados. |
| `/etc/apache2/sites-enabled/` | Links simbólicos dos VirtualHosts atualmente ativos no sistema. |
| `/etc/apache2/mods-available/` | Módulos do Apache disponíveis para instalação/ativação. |
| `/etc/apache2/mods-enabled/` | Módulos atualmente ativos (`mod_rewrite`, `ssl`, `headers`, etc). |
| `/var/www/html/` | Diretório padrão de arquivos do servidor web (Document Root). |
| `/var/log/apache2/error.log` | Log de erros principais do Apache. |
| `/var/log/apache2/access.log` | Log de acessos e requisições HTTP. |

---

## 🛠️ Comandos de Gerenciamento do Serviço

### Testar a sintaxe dos arquivos de configuração (Sempre execute antes de reiniciar)
```bash
sudo apache2ctl configtest
# Ou de forma simplificada:
sudo apache2ctl -t
```

### Reiniciar o Apache2 (Aplica alterações de porta ou módulos)
```bash
sudo systemctl restart apache2
```

### Recarregar o Apache2 sem queda (Graceful Reload — Recomendado para mudanças de VirtualHost)
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

## 🔒 Permissões de Arquivos & Segurança Básica

### Ajustar o proprietário e grupo correto para o diretório Web
```bash
sudo chown -R www-data:www-data /var/www/meu_site
```

### Permissões recomendadas (755 para pastas e 644 para arquivos)
```bash
sudo find /var/www/meu_site -type d -exec chmod 755 {} \;
sudo find /var/www/meu_site -type f -exec chmod 644 {} \;
```

### Esconder a versão do Apache nos cabeçalhos (Hardening de Segurança)
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

## 🔍 Monitoramento e Análise de Logs

### Acompanhar logs de erro em tempo real
```bash
sudo tail -f /var/log/apache2/error.log
```

### Acompanhar requisições e acessos HTTP em tempo real
```bash
sudo tail -f /var/log/apache2/access.log
```

### Filtrar acessos por IP ou código de erro HTTP (ex: erro 500)
```bash
sudo cat /var/log/apache2/access.log | grep " 500 "
sudo cat /var/log/apache2/access.log | grep "192.168.1.50"
```

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
