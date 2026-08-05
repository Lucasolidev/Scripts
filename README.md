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

* 🐧 **[Guia de Ajuda Linux](ajuda_linux.md)** — Atalhos, manipulação de arquivos, permissões, POSIX ACLs, rsync/scp, usuários e comandos essenciais do Ubuntu Server.
* 🐘 **[Guia de Ajuda Samba](ajuda_samba.md)** — Comandos de servidor (Standalone e AD DC), `samba-tool`, `smbstatus`, comandos de cliente Linux/Windows e permissões POSIX ACL.
* 🗂️ **[Guia de Ajuda LDAP / OpenLDAP](ajuda_ldap.md)** — Estrutura DIT, consultas com `ldapsearch`, inclusões com `ldapadd`, alterações com `ldapmodify`, `ldappasswd` e arquivos LDIF.
* 🚀 **[Guia de Ajuda Nginx + PHP-FPM](ajuda_nginx.md)** — Estrutura de diretórios, blocos `server`, Reverse Proxy, PHP-FPM, timeouts e solução de erros (413, 502, 504).
* 🌐 **[Guia de Ajuda Apache2](ajuda_apache2.md)** — Estrutura de diretórios, `a2enmod`, `a2ensite`, suporte a `.htaccess`, POSIX ACLs, VirtualHosts e diagnóstico.
* 🖥️ **[Guia de Ajuda Tmux](ajuda_tmux.md)** — Gerenciamento de sessões, navegação de abas, divisão de painéis e rolagem de histórico no terminal.
* 💻 **[Guia de Ajuda WSL 2](ajuda_wsl.md)** — Instalação, gerenciamento de distros, backups (`.tar`), limites do `.wslconfig` e integração Windows/Linux.
* 🪟 **[Guia de Ajuda Windows](ajuda_windows.md)** — Comandos essenciais de PowerShell, CMD, redes e administração de sistemas Windows.
* 📝 **[Guia de Ajuda Vim](ajuda_vim.md)** — Comandos de edição, navegação, buscas e atalhos de teclado no editor Vim.

---

## 🛠️ Principais Scripts de Instalação e Automação

### 1. Pós-Instalação do Ubuntu Server (`pos_install_server.sh`)
Prepara um novo servidor Ubuntu Server aplicando atualizações, instalando utilitários essenciais (`curl`, `ncdu`, `fastfetch`, `qemu-guest-agent`, `htop`, `tmux`, `dnsutils`, `net-tools`), fuso horário `America/Sao_Paulo` (NTP), layout dual de teclado (ABNT2 + US-Intl), hardening no SSH, proteção RAM `/dev/shm` (noexec), proteção Fail2Ban, UFW IPv4/IPv6 e gerenciamento de usuários com Visudo:
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_server.sh -O pos_install_server.sh && chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
```

### 2. Pós-Instalação do Ubuntu Desktop (`pos_install_desktop.sh`)
Prepara uma nova estação Ubuntu Desktop com o gerenciador `nala`, ferramentas dev/diagnóstico (`btop`, `build-essential`, `jq`, `tldr`, `htop`), Flatpak/Flathub, Google Chrome, Hack Nerd Font, Vim configurado, Zsh com Oh My Zsh (tema Agnoster), teclado dual (ABNT2 + US-Intl) e Firewall UFW ativado:
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh -O pos_install_desktop.sh && chmod +x pos_install_desktop.sh && sudo ./pos_install_desktop.sh
```

### 3. Instalador LEMP - Nginx + MariaDB + PHP-FPM (`install_lemp_ubuntu.sh`)
Instala e otimiza a pilha LEMP com suporte a PHP-FPM (uploads ilimitados, timeouts de 7200s, `server_tokens off`, `disable_functions` ativas), MariaDB Server seguro, suporte a WebSockets, herança de permissões automática com POSIX ACLs e firewall Fail2Ban (com jaula `nginx-botsearch`) e UFW:
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lemp_ubuntu.sh -O install_lemp_ubuntu.sh && chmod +x install_lemp_ubuntu.sh && sudo ./install_lemp_ubuntu.sh
```

### 4. Instalador LAMP - Apache2 + MariaDB + PHP (`install_lamp_ubuntu.sh`)
Instala e otimiza a pilha LAMP (Apache2 com mod_rewrite, `ServerTokens Prod`, MariaDB Server seguro, PHP com `disable_functions` de risco inativas, suporte a phpMyAdmin opcional, POSIX ACLs e Fail2Ban com `apache-badbots`):
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu.sh -O install_lamp_ubuntu.sh && chmod +x install_lamp_ubuntu.sh && sudo ./install_lamp_ubuntu.sh
```

---

## 📐 Padrões de Código e Templates
* 📄 **[Template Padrão Shell Script](Padrao_Shell_Script_Template_Visual.md)** — Modelo padrão com paleta de cores ANSI, logs, hardening e cabeçalhos visuais para scripts Bash.
* 📄 **[Template Padrão PowerShell Script](Padrao_PowerShell_Script_Template_Visual.md)** — Modelo padrão para scripts de automação em PowerShell.
