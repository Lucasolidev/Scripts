# 🚀 Linux & Windows Automation Scripts

![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=flat&logo=gnu-bash&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)

Repositório centralizado de scripts de automação, ferramentas de pós-instalação e guias de referência rápida para administração de servidores Linux e Windows.

---

## 📖 Guias de Consulta Rápida (Cheat Sheets)

Acesse os manuais e guias rápidos de consulta para servidores e ferramentas:

* 🐧 **[Guia de Ajuda Linux](ajuda_linux.md)** — Atalhos, manipulação de arquivos, permissões, POSIX ACLs e comandos essenciais do Ubuntu Server.
* 🚀 **[Guia de Ajuda Nginx + PHP-FPM](ajuda_nginx.md)** — Estrutura de diretórios, blocos `server`, Reverse Proxy, PHP-FPM, timeouts e solução de erros (413, 502, 504).
* 🌐 **[Guia de Ajuda Apache2](ajuda_apache.md)** — Estrutura de diretórios, `a2enmod`, `a2ensite`, suporte a `.htaccess`, VirtualHosts e diagnóstico.
* 🪟 **[Guia de Ajuda Windows](ajuda_windows.md)** — Comandos essenciais de PowerShell, CMD, redes e administração de sistemas Windows.
* 📝 **[Guia de Ajuda Vim](ajuda_vim.md)** — Comandos de edição, navegação, buscas e atalhos de teclado no editor Vim.

---

## 🛠️ Principais Scripts de Instalação e Automação

### 1. Pós-Instalação de Servidores Ubuntu (`pos_install_server.sh`)
Prepara um novo servidor Ubuntu Server aplicando atualizações, instalando utilitários essenciais (`curl`, `ncdu`, `fastfetch`, `qemu-guest-agent`), endurecendo a segurança SSH e criando usuários/grupos:
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh | sudo bash
```

### 2. Instalador Nginx + PHP-FPM + MariaDB (`install_nginx_php_ubuntu.sh`)
Instala e otimiza a pilha Nginx com suporte a PHP-FPM (uploads de até 2GB, timeouts longos de 3600s), MariaDB Server, herança de permissões automática com POSIX ACLs e firewall Fail2Ban/UFW:
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh | sudo bash
```

### 3. Instalador LAMP - Apache2 + MariaDB + PHP (`install_lamp_ubuntu.sh`)
Instala e otimiza a pilha LAMP (Apache2 com mod_rewrite, MariaDB Server, PHP, suporte a phpMyAdmin opcional, POSIX ACLs e Fail2Ban):
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh | sudo bash
```

---

## 📐 Padrões de Código e Templates
* 📄 **[Template Padrão Shell Script](Padrao_Shell_Script_Template_Visual.md)** — Modelo padrão com paleta de cores ANSI, logs e cabeçalhos visuais para scripts Bash.
* 📄 **[Template Padrão PowerShell Script](Padrao_PowerShell_Script_Template_Visual.md)** — Modelo padrão para scripts de automação em PowerShell.
