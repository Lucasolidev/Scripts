# 🚀 Linux & Windows Automation Scripts

![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=flat&logo=gnu-bash&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)

Repositório centralizado de scripts de automação, ferramentas de pós-instalação e guias de referência rápida para administração de servidores e estações Linux e Windows.

---

## 📖 Guias de Consulta Rápida (Cheat Sheets)

Acesse os manuais e guias rápidos de consulta para servidores, ferramentas e utilitários:

* 🐧 **[Guia de Ajuda Linux](ajuda_linux.md)** — Atalhos, manipulação de arquivos, permissões, POSIX ACLs e comandos essenciais do Ubuntu Server.
* 🖥️ **[Guia de Ajuda Tmux](ajuda_tmux.md)** — Gerenciamento de sessões, navegação de abas, divisão de painéis e rolagem de histórico no terminal.
* 💻 **[Guia de Ajuda WSL 2](ajuda_wsl.md)** — Instalação, gerenciamento de distros, backups (`.tar`), limites do `.wslconfig` e integração Windows/Linux.
* 🚀 **[Guia de Ajuda Nginx + PHP-FPM](ajuda_nginx.md)** — Estrutura de diretórios, blocos `server`, Reverse Proxy, PHP-FPM, timeouts e solução de erros (413, 502, 504).
* 🌐 **[Guia de Ajuda Apache2](ajuda_apache2.md)** — Estrutura de diretórios, `a2enmod`, `a2ensite`, suporte a `.htaccess`, POSIX ACLs, VirtualHosts e diagnóstico.
* 🪟 **[Guia de Ajuda Windows](ajuda_windows.md)** — Comandos essenciais de PowerShell, CMD, redes e administração de sistemas Windows.
* 📝 **[Guia de Ajuda Vim](ajuda_vim.md)** — Comandos de edição, navegação, buscas e atalhos de teclado no editor Vim.

---

## 🛠️ Principais Scripts de Instalação e Automação

### 1. Pós-Instalação do Ubuntu Server (`pos_install_server.sh`)
Prepara um novo servidor Ubuntu Server aplicando atualizações, instalando utilitários essenciais (`curl`, `ncdu`, `fastfetch`, `qemu-guest-agent`, `htop`, `tmux`, `dnsutils`, `net-tools`), fuso horário `America/Sao_Paulo` (NTP), hardening no SSH, proteção Fail2Ban, atualizações automáticas e gerenciamento de usuários/grupos restritos com Visudo:
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh | sudo bash
```

### 2. Pós-Instalação do Ubuntu Desktop (`pos_install_desktop.sh`)
Prepara uma nova estação Ubuntu Desktop com o gerenciador `nala`, ferramentas dev/diagnóstico (`btop`, `build-essential`, `jq`, `tldr`, `htop`), Flatpak/Flathub, Google Chrome, Hack Nerd Font, Vim com temas/plugins e Zsh com Oh My Zsh (tema Agnoster) e Firewall UFW ativado:
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh | sudo bash
```

### 3. Instalador Nginx + PHP-FPM + MariaDB (`install_nginx_php_ubuntu.sh`)
Instala e otimiza a pilha Nginx com suporte a PHP-FPM (uploads de até 2GB, timeouts longos de 3600s), MariaDB Server, herança de permissões automática com POSIX ACLs e firewall Fail2Ban/UFW:
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_nginx_php_ubuntu.sh | sudo bash
```

### 4. Instalador LAMP - Apache2 + MariaDB + PHP (`install_lamp_ubuntu.sh`)
Instala e otimiza a pilha LAMP (Apache2 com mod_rewrite, MariaDB Server, PHP, suporte a phpMyAdmin opcional, POSIX ACLs e Fail2Ban):
```bash
curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh | sudo bash
```

---

## 📐 Padrões de Código e Templates
* 📄 **[Template Padrão Shell Script](Padrao_Shell_Script_Template_Visual.md)** — Modelo padrão com paleta de cores ANSI, logs, hardening e cabeçalhos visuais para scripts Bash.
* 📄 **[Template Padrão PowerShell Script](Padrao_PowerShell_Script_Template_Visual.md)** — Modelo padrão para scripts de automação em PowerShell.
