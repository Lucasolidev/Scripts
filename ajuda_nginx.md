# 🚀 Cheat Sheet - Administração Nginx + PHP-FPM (Ubuntu Server)

![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-5FA04E?style=flat&logo=nodedotjs&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=flat&logo=cloudflare&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência rápida para administração do servidor web de alta performance **Nginx** com **PHP-FPM** e **Reverse Proxy** em ambientes Debian/Ubuntu.

---

## 📁 Diretórios de Configuração e Arquivos Importantes

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/nginx/` | Diretório raiz de todas as configurações do Nginx. |
| `/etc/nginx/nginx.conf` | Configuração global (worker processes, gzip, buffer, logs). |
| `/etc/nginx/sites-available/` | Guarda os arquivos de VirtualHost/Blocos `server` criados. |
| `/etc/nginx/sites-enabled/` | Guarda os links simbólicos dos sites que estão **ATIVOS**. |
| `/etc/nginx/snippets/` | Trechos de configuração reutilizáveis (ex: `fastcgi-php.conf`). |
| `/etc/php/X.Y/fpm/php.ini` | Configuração principal do interpretador PHP-FPM. |
| `/etc/php/X.Y/fpm/pool.d/www.conf` | Configuração de processos, usuários e sockets do PHP-FPM. |
| `/run/php/phpX.Y-fpm.sock` | Socket UNIX de comunicação do PHP-FPM com o Nginx. |
| `/var/www/` | Diretório raiz padrão das aplicações web (`/var/www/gerenciador`). |
| `/var/log/nginx/access.log` | Log de acessos HTTP recebidos. |
| `/var/log/nginx/error.log` | Log de erros do servidor Nginx. |

---

## ⚡ Comandos Principais de Gerenciamento dos Serviços

### Gerenciar o serviço do Nginx
```bash
# Verificar status do Nginx
sudo systemctl status nginx

# Iniciar, parar ou reiniciar o Nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# Recarregar configurações sem queda de conexões (Graceful Reload)
sudo systemctl reload nginx
```

### Testar a sintaxe dos arquivos do Nginx (OBRIGATÓRIO)
> 💡 *NUNCA reinicie o Nginx sem antes validar a sintaxe com `nginx -t`. Se houver um ponto e vírgula `;` faltando, o Nginx avisará aqui antes de derrubar o site!*
```bash
sudo nginx -t
```

### Gerenciar o serviço do PHP-FPM
```bash
# Substitua 8.3 ou 8.5 pela versão instalada
sudo systemctl status php8.3-fpm
sudo systemctl restart php8.3-fpm
sudo systemctl reload php8.3-fpm
```

---

## 🔧 Ativar e Desativar Sites no Nginx

No Nginx, um site é ativado criando um link simbólico da pasta `sites-available` para a pasta `sites-enabled`:

```bash
# Ativar um site (Criar link simbólico)
sudo ln -sf /etc/nginx/sites-available/dl.nuvemativa.com.br /etc/nginx/sites-enabled/

# Remover o site padrão de demonstração
sudo rm -f /etc/nginx/sites-enabled/default

# Validar sintaxe e aplicar
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🌐 Exemplo Prático 1: VirtualHost PHP-FPM (Otimizado para Uploads Grandes & Cloudflare)

Crie o arquivo em `/etc/nginx/sites-available/dl.nuvemativa.com.br`:

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name dl.nuvemativa.com.br _;
    root /var/www/gerenciador;
    index index.php index.html index.htm;

    # Otimizações de limite de Upload e Timeouts longos
    client_max_body_size 2G;
    client_body_timeout 3600s;
    fastcgi_read_timeout 3600s;
    fastcgi_send_timeout 3600s;

    # Encaminhamento de protocolo HTTPS do Cloudflare Tunnel
    proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;

    # Roteamento de arquivos estáticos e URLs amigáveis
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Bloquear arquivos ocultos (.env, .git, .htaccess)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Processamento de arquivos PHP via FastCGI (Socket UNIX)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

---

## 🔄 Exemplo Prático 2: Reverse Proxy para Aplicações Node.js / Express / PM2

Crie o arquivo em `/etc/nginx/sites-available/app-node.conf`:

```nginx
server {
    listen 80;
    server_name app.nuvemativa.com.br;

    client_max_body_size 500M;

    location / {
        # Endereço da aplicação Node.js / PM2 rodando localmente
        proxy_pass http://127.0.0.1:3000;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;

        # Repassar o IP real do visitante e protocolo HTTPS do Cloudflare
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

---

## 🔐 Permissões de Arquivos & POSIX ACLs de Herança Automática

Para evitar erros de permissão de escrita e upload pelo usuário do Nginx (`www-data`):

### 1. Definir o proprietário Unix inicial
```bash
sudo chown -R www-data:www-data /var/www/
sudo chmod -R 775 /var/www/
```

### 2. Aplicar POSIX ACLs com Herança Automática (Enterprise)
> 💡 *Qualquer novo arquivo ou pasta criado dentro de `/var/www/` (mesmo por `root`, via SFTP ou por `git clone`) herdará automaticamente permissão total de leitura, escrita e execução para o `www-data`!*

```bash
# Garantir que o utilitário de ACL está instalado
sudo apt-get install -y acl

# Permissão nos arquivos existentes
sudo setfacl -R -m u:www-data:rwx,g:www-data:rwx /var/www/

# Regra DEFAULT (Herança Automática para futuros arquivos e pastas)
sudo setfacl -R -d -m u:www-data:rwx,g:www-data:rwx /var/www/
```

### 3. Consultar as regras ACL ativas
```bash
getfacl /var/www/
```

---

## 🔍 Diagnóstico e Resolução de Problemas (Troubleshooting)

### Acompanhar logs de erros em tempo real
```bash
# Log de erros do Nginx
sudo tail -f /var/log/nginx/error.log

# Log de erros do PHP-FPM
sudo tail -f /var/log/php8.3-fpm.log
```

### Principais Erros e Como Resolver:
* **`413 Request Entity Too Large`**: O arquivo enviado é maior do que o configurado no Nginx. Adicione `client_max_body_size 2G;` dentro do bloco `server {}` no VirtualHost e rode `sudo systemctl reload nginx`.
* **`502 Bad Gateway`**: O Nginx não conseguiu se comunicar com o PHP-FPM ou com o Node.js. Verifique se o serviço está ativo com `systemctl status php8.3-fpm` ou se o socket em `/run/php/php8.3-fpm.sock` existe.
* **`504 Gateway Timeout`**: O script PHP ou a requisição demorou mais tempo para responder do que o limite permitido. Aumente `fastcgi_read_timeout 3600s;` no Nginx e `max_execution_time = 3600` no `php.ini`.
* **`403 Forbidden`**: Verifique as permissões de leitura no diretório raiz do site e se a opção `index` está configurada corretamente no VirtualHost.
