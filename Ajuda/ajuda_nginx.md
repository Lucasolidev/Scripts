# 🟢 Cheat Sheet - Administração Nginx (Ubuntu / Debian)

![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Caminho | Descrição |
| :--- | :--- |
| `/etc/nginx/nginx.conf` | Arquivo principal de configuração global do Nginx. |
| `/etc/nginx/sites-available/` | Guarda os arquivos de configuração de Server Block (VirtualHosts). |
| `/etc/nginx/sites-enabled/` | Links simbólicos dos Server Blocks atualmente ativos no sistema. |
| `/etc/nginx/snippets/` | Snippets reutilizáveis de configuração (ex: `fastcgi-php.conf`). |
| `/var/www/html/` | Diretório padrão de arquivos do servidor web (Document Root). |
| `/var/log/nginx/error.log` | Log principal de erros do Nginx. |
| `/var/log/nginx/access.log` | Log principal de acessos e requisições HTTP do Nginx. |
| `/run/php/php8.3-fpm.sock` | Socket Unix do PHP-FPM utilizado na comunicação com o Nginx. |

---

## 🛠️ 2. Comandos de Gerenciamento do Serviço

### Testar a sintaxe dos arquivos de configuração (MANDATÓRIO antes de reiniciar)
```bash
sudo nginx -t
```

### Recarregar o Nginx sem derrubar conexões ativas (Reload — Mais seguro)
```bash
sudo systemctl reload nginx
# Ou o atalho nativo do Nginx:
sudo nginx -s reload
```

### Reiniciar o serviço Nginx
```bash
sudo systemctl restart nginx
```

### Verificar o status de execução do serviço
```bash
sudo systemctl status nginx
```

### Iniciar / Parar o serviço
```bash
sudo systemctl start nginx
sudo systemctl stop nginx
```

### Habilitar / Desabilitar a inicialização automática no boot
```bash
sudo systemctl enable nginx
sudo systemctl disable nginx
```

---

## 🌐 3. Gerenciamento de Server Blocks (VirtualHosts)

### Habilitar um site (Criando o link simbólico em `sites-enabled`)
```bash
sudo ln -s /etc/nginx/sites-available/meu_site /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Desabilitar o site padrão inicial do Nginx
```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### 📄 Modelo Completo: Server Block Nginx + PHP-FPM + Cloudflare Tunnel
Comunicação via Socket PHP-FPM e limites de upload/download configurados (`/etc/nginx/sites-available/meu_site`):

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name meu_dominio.com.br www.meu_dominio.com.br _;
    root /var/www/meu_site;
    index index.php index.html index.htm;

    # Otimização de uploads e tempos de execução (ideal para Cloudflare Tunnel)
    client_max_body_size 2G;
    client_body_timeout 3600s;
    fastcgi_read_timeout 3600s;
    fastcgi_send_timeout 3600s;

    # Roteamento padrão para a aplicação
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # Bloquear acesso a arquivos ocultos (ex: .git, .env, .htaccess)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Processamento de arquivos PHP via FastCGI (Ajuste a versão do PHP-FPM se necessário)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### 📄 Modelo: Proxy Reverso para Aplicações Node.js / Python / Docker
```nginx
server {
    listen 80;
    server_name api.meu_dominio.com.br;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## ⚡ 4. Otimizações & Ajustes no `/etc/nginx/nginx.conf`

### 1. Aumentar limite global de Upload no Nginx
Adicione dentro do bloco `http { ... }`:
```nginx
http {
    client_max_body_size 500M;
    ...
}
```

### 2. Esconder a versão do Nginx nos cabeçalhos HTTP (Segurança)
No arquivo `/etc/nginx/nginx.conf`, descomente ou adicione dentro do bloco `http`:
```nginx
server_tokens off;
```

### 3. Ativar a compressão Gzip para acelerar o carregamento do site
Dentro do bloco `http` do `/etc/nginx/nginx.conf`:
```nginx
gzip on;
gzip_disable "msie6";
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

---

## 🔒 5. Permissões de Arquivos & Propriedade

### Ajustar permissões e proprietário do diretório da aplicação
```bash
sudo chown -R www-data:www-data /var/www/meu_site
sudo find /var/www/meu_site -type d -exec chmod 755 {} \;
sudo find /var/www/meu_site -type f -exec chmod 644 {} \;
```

---

## 🔍 6. Monitoramento e Resolução de Problemas (Troubleshooting)

### Acompanhar o log de erros do Nginx em tempo real
```bash
sudo tail -f /var/log/nginx/error.log
```

### Acompanhar requisições e acessos em tempo real
```bash
sudo tail -f /var/log/nginx/access.log
```

### Diagnosticar o Erro `502 Bad Gateway`
O erro 502 no Nginx geralmente significa que a aplicação backend ou o **PHP-FPM está desligado** ou que o caminho do socket está incorreto:
```bash
# 1. Verifique se o PHP-FPM está rodando:
sudo systemctl status php8.3-fpm

# 2. Verifique se o arquivo do socket existe:
ls -la /run/php/php*.sock
```

---

## 🔐 7. Certificado SSL Gratuito com Let's Encrypt (Certbot)

### 1. Instalar o Certbot para Nginx
```bash
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### 2. Gerar e configurar o certificado SSL automaticamente no Server Block
```bash
sudo certbot --nginx -d meu_dominio.com.br -d www.meu_dominio.com.br
```

### 3. Testar a renovação automática
```bash
sudo certbot renew --dry-run
```
