# 🌐 Cheat Sheet - Administração Apache2 (Ubuntu Server)

![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência rápida para administração do servidor web **Apache2** em ambientes Debian/Ubuntu.

---

## 📁 Diretórios de Configuração e Arquivos Importantes

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/apache2/` | Diretório raiz de todas as configurações do Apache. |
| `/etc/apache2/apache2.conf` | Arquivo de configuração global do servidor. |
| `/etc/apache2/ports.conf` | Define as portas onde o Apache escuta (ex: `Listen 80`, `Listen 443`). |
| `/etc/apache2/sites-available/` | Guarda os arquivos de VirtualHost criados (`.conf`). |
| `/etc/apache2/sites-enabled/` | Guarda os links simbólicos dos sites que estão **ATIVOS**. |
| `/etc/apache2/conf-available/` | Configurações globais opcionais (ex: `phpmyadmin.conf`). |
| `/etc/apache2/conf-enabled/` | Links simbólicos de configurações globais ativas. |
| `/etc/apache2/mods-available/` | Módulos do Apache disponíveis (`rewrite`, `ssl`, `headers`). |
| `/etc/apache2/mods-enabled/` | Módulos ativados no servidor. |
| `/var/www/html/` | Diretório raiz padrão de documentos públicos (DocumentRoot). |
| `/var/log/apache2/access.log` | Log de acessos HTTP recebidos. |
| `/var/log/apache2/error.log` | Log de erros do servidor e depuração do PHP. |

---

## ⚡ Comandos Principais de Gerenciamento do Serviço

### Verificar o status do Apache2
```bash
systemctl status apache2
```

### Iniciar, parar ou reiniciar o Apache2
```bash
# Iniciar o serviço
sudo systemctl start apache2

# Parar o serviço
sudo systemctl stop apache2

# Reiniciar o serviço completo
sudo systemctl restart apache2

# Recarregar configurações sem derrubar conexões ativas (Graceful Reload)
sudo systemctl reload apache2
```

### Testar a sintaxe dos arquivos de configuração (CRÍTICO)
> 💡 *Sempre rode este comando antes de reiniciar o Apache para evitar derrubar o site por erro de digitação!*
```bash
sudo apache2ctl configtest
# ou
sudo apachectl -t
```

---

## 🔧 Gerenciamento de Sites e Módulos (`a2ensite`, `a2enmod`)

O Apache no Debian/Ubuntu possui utilitários exclusivos para ativar e desativar módulos e sites:

### Habilitar e Desabilitar Sites (VirtualHosts)
```bash
# Ativar um site disponível em /etc/apache2/sites-available/seusite.conf
sudo a2ensite seusite.conf

# Desativar um site (remove o link simbólico em sites-enabled)
sudo a2dissite 000-default.conf

# Aplicar as mudanças no servidor
sudo systemctl reload apache2
```

### Habilitar e Desabilitar Módulos do Apache
```bash
# Módulo de reescrita de URLs (.htaccess / URL amigável)
sudo a2enmod rewrite

# Módulo de suporte a HTTPS / SSL
sudo a2enmod ssl

# Módulo de manipulação de cabeçalhos HTTP
sudo a2enmod headers

# Módulos para Reverse Proxy (Proxy HTTP / WebSockets)
sudo a2enmod proxy proxy_http

# Desabilitar um módulo
sudo a2dismod nome_do_modulo

# Recarregar o Apache
sudo systemctl restart apache2
```

---

## 🌐 Exemplo Prático de VirtualHost (Site Completo)

Crie um arquivo em `/etc/apache2/sites-available/seusite.conf`:

```apache
<VirtualHost *:80>
    ServerName seusite.com.br
    ServerAlias www.seusite.com.br
    ServerAdmin admin@seusite.com.br

    # Pasta onde os arquivos do site estão armazenados
    DocumentRoot /var/www/seusite

    # Configuração de permissões e suporte a .htaccess
    <Directory /var/www/seusite>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Arquivos de Log específicos para este site
    ErrorLog ${APACHE_LOG_DIR}/seusite_error.log
    CustomLog ${APACHE_LOG_DIR}/seusite_access.log combined
</VirtualHost>
```

Para ativar este site:
```bash
sudo mkdir -p /var/www/seusite
sudo a2ensite seusite.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

---

## 🔐 Permissões de Arquivos & POSIX ACLs de Herança Automática

Para evitar erros de permissão de escrita e upload pelo usuário do Apache (`www-data`):

### 1. Definir o proprietário Unix inicial
```bash
sudo chown -R www-data:www-data /var/www/
sudo chmod -R 775 /var/www/
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
```

### 3. Verificar as ACLs ativas em um diretório
```bash
getfacl /var/www/html
```

---

## 🔍 Diagnóstico e Resolução de Problemas (Troubleshooting)

### Acompanhar logs de erros em tempo real
```bash
sudo tail -f /var/log/apache2/error.log
```

### Acompanhar acessos em tempo real
```bash
sudo tail -f /var/log/apache2/access.log
```

### Verificar se a porta 80 ou 443 está aberta e escutando
```bash
sudo ss -tulpn | grep -E '80|443|apache'
```

### Principais Erros e Soluções:
* **`403 Forbidden`**: Verifique se o diretório tem permissão de leitura (`chmod 775` ou `Require all granted` no VirtualHost) ou se falta um arquivo `index.html` / `index.php`.
* **`500 Internal Server Error`**: Geralmente causado por sintaxe inválida dentro do arquivo `.htaccess` ou erro no script PHP. Consulte o log `/var/log/apache2/error.log`.
* **`Port 80 in use`**: Outro serviço (como Nginx ou Lighttpd) está ocupando a porta 80. Use `sudo ss -tulpn | grep :80` para descobrir o processo.
