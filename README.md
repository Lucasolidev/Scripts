# 🚀 Linux & Windows Automation Scripts

![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=flat&logo=gnu-bash&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)
![Zabbix](https://img.shields.io/badge/Zabbix-F11033?style=flat&logo=zabbix&logoColor=white)

Repositório centralizado de scripts de automação, ferramentas de pós-instalação e guias de referência rápida para administração de servidores e estações Linux e Windows.

---

## 📖 Guias de Consulta Rápida (Cheat Sheets)

Acesse os manuais e guias rápidos de consulta para servidores, ferramentas e utilitários:

* 🐧 **[Guia de Ajuda Linux](Ajuda/ajuda_linux.md)** — Atalhos, manipulação de arquivos, permissões, POSIX ACLs, rsync/scp, usuários e comandos essenciais do Ubuntu Server.
* 🐳 **[Guia de Ajuda Docker & Compose](Ajuda/ajuda_docker.md)** — Comandos de contêineres, imagens, volumes, redes e orquestração com Docker Compose.
* 📊 **[Guia de Ajuda Zabbix](Ajuda/ajuda_zabbix.md)** — Monitoramento, `zabbix_get`, `zabbix_sender`, `zabbix_proxy`, agente 2 e `UserParameter`.
* 🛢️ **[Guia de Ajuda MariaDB & MySQL](Ajuda/ajuda_mariadb_mysql.md)** — Administração SQL, permissões, backups (`mariadb-dump`), restore, otimização e reset de root.
* 🛡️ **[Guia de Ajuda Firewall UFW & IPTables](Ajuda/ajuda_ufw_iptables.md)** — Regras de firewall, liberação por IP/porta, redirecionamento NAT (Port Forwarding) e `ss`/`tcpdump`.
* 🔒 **[Guia de Ajuda Fail2Ban](Ajuda/ajuda_fail2ban.md)** — Prevenção de intrusão e brute force, status de jails, unban/ban de IPs, whitelists (`ignoreip`) e logs.
* 🌿 **[Guia de Ajuda Git & GitHub](Ajuda/ajuda_git.md)** — Workflow diário, gerenciamento de branches, `stash`, desfazer commits, `reset --hard` e remotos.
* 🐘 **[Guia de Ajuda Samba](Ajuda/ajuda_samba.md)** — Comandos de servidor (Standalone e AD DC), `samba-tool`, `smbstatus`, comandos de cliente Linux/Windows e permissões POSIX ACL.
* 🗂️ **[Guia de Ajuda LDAP / OpenLDAP](Ajuda/ajuda_ldap.md)** — Estrutura DIT, consultas com `ldapsearch`, inclusões com `ldapadd`, alterações com `ldapmodify`, `ldappasswd` e arquivos LDIF.
* 🚀 **[Guia de Ajuda Nginx + PHP-FPM](Ajuda/ajuda_nginx.md)** — Estrutura de diretórios, blocos `server`, Reverse Proxy, PHP-FPM, timeouts e solução de erros (413, 502, 504).
* 🌐 **[Guia de Ajuda Apache2](Ajuda/ajuda_apache2.md)** — Estrutura de diretórios, `a2enmod`, `a2ensite`, suporte a `.htaccess`, POSIX ACLs, VirtualHosts e diagnóstico.
* 🖥️ **[Guia de Ajuda Tmux](Ajuda/ajuda_tmux.md)** — Gerenciamento de sessões, navegação de abas, divisão de painéis e rolagem de histórico no terminal.
* 💻 **[Guia de Ajuda WSL 2](Ajuda/ajuda_wsl.md)** — Instalação, gerenciamento de distros, backups (`.tar`), limites do `.wslconfig` e integração Windows/Linux.
* 🪟 **[Guia de Ajuda Windows](Ajuda/ajuda_windows.md)** — Comandos essenciais de PowerShell, CMD, redes e administração de sistemas Windows.
* 📝 **[Guia de Ajuda Vim](Ajuda/ajuda_vim.md)** — Comandos de edição, navegação, buscas e atalhos de teclado no editor Vim.
* 📋 **[Checklist de Coleta Pré-Migração Web](Ajuda/checklist_pre_migracao_joomla.md)** — Procedimento de auditoria, coleta de credenciais, dump de banco, arquivos e DNS antes da virada de servidor.

---

## 🛠️ Principais Scripts de Instalação e Automação

### 1. Pós-Instalação do Ubuntu Server (`pos_install_server.sh`)
Prepara um novo servidor Ubuntu Server aplicando atualizações, instalando utilitários essenciais (`curl`, `vim`, `ncdu`, `btop`, `qemu-guest-agent`, `htop`, `tmux`, `dnsutils`, `net-tools`), fuso horário `America/Sao_Paulo` (NTP), layout dual de teclado (ABNT2 + US-Intl), hardening no SSH, proteção RAM `/dev/shm` (noexec), proteção Fail2Ban, UFW IPv4/IPv6 e gerenciamento de usuários com Visudo:
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

### 5. Instalador LAMP Especializado - Joomla 5.x (`install_lamp_ubuntu_joomla5.sh`)
Instala e configura a pilha LAMP genérica e reutilizável para qualquer domínio com todos os **requisitos recomendados oficiais do Joomla 5.x** (Apache 2.4 com mod_rewrite/HTTP2, MariaDB 11.4 com UTF8MB4, PHP 8.3 com memória de 512MB, OPcache otimizado, rotinas agendadas no Cron para `cli/joomla.php`, headers de segurança e permissões POSIX ACL):
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_lamp_ubuntu_joomla5.sh -O install_lamp_ubuntu_joomla5.sh && chmod +x install_lamp_ubuntu_joomla5.sh && sudo ./install_lamp_ubuntu_joomla5.sh
```

### 6. Auditoria e Inventário do Servidor Linux (`auditoria_servidor_inventario.sh`)
Script não-invasivo de diagnóstico e varredura completa pré-migração. Mapeia versão do SO, hardware, **todas as portas em escuta e seus processos/aplicações**, servidores web (Apache/Nginx) e VirtualHosts, versões do PHP/módulos, bancos de dados (MariaDB/MySQL/Postgres), **detecção automática de CMSs no disco (Joomla, WordPress, Laravel)**, regras de firewall, crontabs e contêineres Docker. Gera relatório estruturado salvo automaticamente na pasta **Home do usuário** e em `/root`:
```bash
wget https://raw.githubusercontent.com/lucasolidev/scripts/main/auditoria_servidor_inventario.sh -O auditoria_servidor_inventario.sh && chmod +x auditoria_servidor_inventario.sh && sudo ./auditoria_servidor_inventario.sh
```


---

## 📐 Padrões de Código e Templates
* 📄 **[Template Padrão Shell Script](Architecture/ARCHITECTURE_Shell_Script_Template_Visual.md)** — Modelo padrão com paleta de cores ANSI, logs, hardening e cabeçalhos visuais para scripts Bash.
* 📄 **[Template Padrão PowerShell Script](Architecture/ARCHITECTURE_PowerShell_Script_Template_Visual.md)** — Modelo padrão para scripts de automação em PowerShell.
* 📐 **[Padrão de Guias de Ajuda](Architecture/ARCHITECTURE_AJUDA.md)** — Especificação e padronização para a criação de novos manuais e cheat sheets.
