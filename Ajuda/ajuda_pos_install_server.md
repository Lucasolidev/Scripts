# 🚀 Guia Prático e Cheat Sheet - Pós-Instalação e Utilitários (Ubuntu Server)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Vim](https://img.shields.io/badge/Vim-019733?style=flat&logo=vim&logoColor=white)
![Versão](https://img.shields.io/badge/Script-2.5-0078D4?style=flat)

Guia operacional rápido, referência de configurações e *cheat sheet* completo para servidores configurados com o script [`pos_install_server.sh`](../pos_install_server.sh). **Versão 2.5, destinada ao Ubuntu Server 24.04 e 26.04 com systemd. Instalação e reexecução testadas na Ubuntu-26.04-Teste em WSL; auditoria do kernel e hardening de `/dev/shm` ainda exigem VM convencional. O Ubuntu 24.04 permanece sem homologação dinâmica nesta entrega.** Contém os comandos práticos dos utilitários de **diagnóstico**, **rede**, **segurança (Lynis/Fail2Ban/UFW)**, **desempenho** e **produtividade**.

---

## 📁 1. Estrutura de Arquivos, Configurações e Logs Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/root/relatorio_pos_install_server_*.log` | Log completo e detalhado com timestamp da execução do script pós-instalação. |
| `/root/relatorio_pos_install_server_latest.log` | Cópia regular do último relatório, modo `0600`; salva também quando há falha após iniciar a captura. |
| `/root/backup_pos_install_server_*` | Backups administrativos por execução. Não incluem uma reversão completa de pacotes, usuários ou firewall. |
| `/etc/ssh/pos-install-server.conf` | Política SSH do script, incluída no início de `sshd_config`. |
| `/etc/audit/rules.d/server_security.rules` | Regras de auditoria de contas, sudoers, SSH, rede e persistência. |
| `/etc/pos-install-server/` | Aliases compartilhados e configuração opcional do Vim. |
| `/usr/local/share/pos-install-server/vim/2.5` | Plugins opcionais fixados por commit, compartilhados e pertencentes a root. |
| `/usr/local/bin/motd_banner.sh` | Script autônomo do banner dinâmico com métricas em tempo real (Host, CPU, RAM, Disco, IP, UFW). |
| `/etc/profile.d/motd_banner.sh` | Disparador automático do banner no login interativo via SSH ou console local. |
| `/etc/fail2ban/jail.d/99-pos-install-server.local` | Jaula SSH do script. `jail.local` e outras jaulas são preservadas. |
| `/etc/default/ufw` | Configurações do firewall UFW (incluindo suporte a IPv6 ativo `IPV6=yes`). |
| `/etc/default/keyboard` | Mapeamento dual de layout de teclado (`ABNT2` + `US-International`). |
| `/etc/sudoers.d/grupo_*` | Administração ampla com bloqueios de operações diretas para grupos operacionais. |
| `/root/.vimrc` / `/etc/skel/.vimrc` | Recebem chamada ao perfil compartilhado apenas se não existir configuração anterior e se a opção Vim for aceita. |
| `/var/log/sysstat/` | Diretório onde o `sysstat` armazena o histórico diário de métricas de CPU, RAM e I/O. |
| `/var/log/lynis.log` | Relatório completo e detalhado da última auditoria de segurança gerada pelo Lynis. |

---

## ⚙️ 2. Execução e Parâmetros do Script

### Executar a versão local em homologação

Transfira o arquivo **alterado neste checkout** para a VM. O download de `main` só conterá a versão 2.5 depois da publicação; não use o comando remoto para testar alterações ainda locais.

```bash
sudo bash ./pos_install_server.sh
```

### Execução da versão publicada

```bash
wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/pos_install_server.sh -O pos_install_server.sh && chmod +x pos_install_server.sh && sudo ./pos_install_server.sh
```

### Opções coletadas no início

| Opção | Padrão / comportamento |
| :--- | :--- |
| Upgrade do sistema | Não. O índice APT é atualizado para instalar dependências. |
| Permitir root no SSH | Não. Para desabilitá-lo, exige conta sudo preexistente com login SSH declarado como já testado e verificações locais. Sem isso, preserva a política anterior e registra pendência. |
| Habilitar UFW | Sim. Preserva regras existentes, libera portas SSH detectadas e mantém `10050/tcp` para qualquer origem, conforme decisão do proprietário. |
| Criar/garantir administrador e geset | Não. Ao aceitar, cria a conta ou garante associação ao grupo sudo; preserva senha existente. Senhas novas são solicitadas pelo `passwd`, sem eco. |
| Grupo operacional | Não. Ao aceitar, solicita o nome e cria/garante somente esse grupo e sua regra sudo. Preserva maiúsculas/minúsculas: `dev` e `DEV` são grupos distintos. Não cria automaticamente DEV, TI ou SUPORTE. |
| Usuário operacional | Opcional, após informar o grupo. Pode criar/vincular usuário ao grupo informado ou administrar somente o grupo, sem criar usuário. |
| Personalizar Vim | Não. Plugins fixados e perfis existentes preservados. |
| Conta com SSH testado | ENTER preserva a política de root. Conta criada durante a execução não serve como acesso previamente testado. |
| Exceções Fail2Ban | Somente loopback. Aceita IPs/CIDRs adicionais separados por espaço; não presume confiança em redes privadas inteiras. |

> ⚠️ Se estiver criando o primeiro administrador, termine a execução, teste o login dessa conta e o sudo em outra sessão e só depois reexecute para desabilitar root. Mantenha o console da VM disponível.

Ao criar uma conta, o script identifica o usuário antes de `New password:`. Esse campo solicita a **nova senha dessa conta**, e `Retype new password:` solicita sua confirmação. A ordem é `administrador`, `geset` e usuário customizado, pulando contas não solicitadas ou existentes. Contas existentes mantêm a senha. Os caracteres digitados não aparecem no terminal.

Responder **Sim** para criar/garantir uma conta não redefine sua senha quando ela já existe. Nesse caso, aparece `Conta <usuario> já existe: criação e definição de senha puladas; senha atual preservada.` O script garante o vínculo ao grupo solicitado e repete no resumo final o resultado de cada conta gerenciada, incluindo `administrador`, `geset` e usuário operacional.

Se as duas entradas da senha não coincidirem ou `passwd` falhar, o script oferece **tentar novamente (padrão Sim)**. Digite `s` ou pressione ENTER para repetir; `n` cancela a execução com código 2, mantendo a conta criada. Ctrl+C continua cancelando com código 130.

Se reexecutar após uma falha, a conta pode existir sem senha inicial. O script identifica esse estado sem exibir hashes e pergunta `Definir a senha inicial de <usuario> agora (s/N)`. Responda `s` para retomar; ao recusar, preserva a conta e registra pendência. Senhas já existentes, incluindo senhas bloqueadas com hash, não são redefinidas automaticamente.

### Configurações e resultados

- Locales: `en_US.UTF-8` padrão e suporte a `pt_BR.UTF-8`.
- Persistência dos locales: `/etc/locale.conf` no Ubuntu 26.04; no 24.04, preserva o layout legado ou usa esse arquivo quando há link de compatibilidade. O link `/etc/default/locale -> /etc/locale.conf` é preservado; backup e escrita atômica usam o arquivo regular.
- Teclado: ABNT2 + US-International, alternância com Alt+Shift; SSH usa o teclado do cliente.
- Horário: `America/Sao_Paulo`; preserva cliente NTP ativo e informa se a sincronização foi confirmada.
- `/dev/shm`: atualiza a entrada efetiva do fstab e verifica `noexec,nosuid,nodev` na montagem; ambientes restritos ficam pendentes.
- SSH: valida configuração antes do reload e confere o contexto conhecido. `ClientAliveInterval 300` e `ClientAliveCountMax 2` verificam clientes sem resposta, não inatividade humana.
- Configuração SSH personalizada, autenticação exclusivamente por chave, MFA ou regras Allow/Deny podem exigir revisão manual; o script preserva/restaura o SSH em vez de alterar esses mecanismos.
- Fail2Ban: backend systemd, portas SSH detectadas e verificação da jaula. Exceções anteriores da jaula SSH são substituídas pelos parâmetros informados; outras jaulas são preservadas.
- Atualizações automáticas: timers e parâmetro APT verificados; origens permitidas existentes são preservadas. Conferir execução real na homologação.
- QEMU/VMware: agente correspondente; ausência do canal QEMU é reportada sem esperar indefinidamente.

### O que o script prepara no servidor

O objetivo é preparar a base de administração, segurança e diagnóstico do Linux. A execução segue esta sequência:

| Etapa | O que acontece |
| :--- | :--- |
| Pacotes e repositórios | Atualiza o índice APT, habilita `universe`, instala as dependências e os utilitários. O upgrade dos pacotes existentes depende da resposta inicial. |
| Contas e permissões | Cria/garante as contas solicitadas, seus grupos e somente a regra sudo do grupo operacional informado. |
| Acesso SSH | Aplica a política solicitada para root, proíbe senhas vazias e configura keepalive; valida antes de recarregar. |
| Proteção e manutenção | Configura a jaula SSH do Fail2Ban, os timers de atualização, as regras/retenção do auditd e, se aceito, o UFW. |
| Preferências do sistema | Configura idiomas UTF-8, teclado, fuso e verifica a sincronização de horário; aplica hardening de `/dev/shm` em ambiente suportado. |
| Ambiente de trabalho | Instala aliases e banner; personaliza Vim se solicitado, preservando perfis existentes. |
| Resultado e recuperação | Mostra estados confirmados/pendentes e salva relatórios e backups dos arquivos administrativos alterados. |

### Programas instalados: finalidade e uso pelo script

As tabelas cobrem os **pacotes solicitados diretamente pelo script**. O APT também pode instalar suas dependências. Ferramentas descritas como **uso manual** ficam disponíveis para o administrador: sua instalação não significa que o script executou uma varredura, captura, teste de desempenho ou backup.

As dependências essenciais são `locales`, `openssh-server`, `sudo`, `fail2ban`, `python3-systemd`, `auditd`, `audispd-plugins`, `unattended-upgrades` e `ufw`: se a instalação de alguma falhar, a execução é interrompida. Os demais utilitários gerais também são solicitados normalmente; uma falha entra nas pendências. Somente os pacotes da personalização Vim e os agentes de virtualização abaixo dependem dessas condições específicas.

#### Base do sistema, acesso e segurança

| Pacote | Para que serve | O que o script faz com ele |
| :--- | :--- | :--- |
| `software-properties-common` | Fornece ferramentas para administrar repositórios APT, incluindo `add-apt-repository`. | Instala o suporte e habilita o repositório `universe` do Ubuntu. Não adiciona PPA de terceiros. |
| `locales` | Gera definições de idioma e codificação usadas para exibir/processar textos, datas e números. | Gera `en_US.UTF-8` e `pt_BR.UTF-8`, com inglês UTF-8 como padrão. |
| `openssh-server` | Permite acesso remoto ao terminal e transferência por mecanismos como SFTP/SCP através do SSH. | Configura e valida o servidor SSH, incluindo a política de root; identifica as portas para firewall e Fail2Ban. |
| `sudo` | Permite executar comandos com privilégios administrativos conforme a política sudoers; fornece `visudo` para validar essa política. | Vincula administradores ao grupo sudo e aplica a regra do grupo operacional solicitado. A implementação efetiva pode ser sudo-rs. |
| `fail2ban` | Detecta falhas repetidas de autenticação nos logs e bloqueia temporariamente os endereços envolvidos. | Configura e ativa a jaula `sshd` com backend systemd, limite de cinco falhas em dez minutos e bloqueio de uma hora. As exceções de IP vêm dos parâmetros iniciais. |
| `python3-systemd` | Permite que programas Python consultem recursos do systemd, incluindo o journal de logs. | Instala o suporte necessário para o Fail2Ban ler os eventos SSH pelo backend systemd. |
| `auditd` | Registra eventos de auditoria fornecidos pelo kernel, como alterações em arquivos sensíveis e execução de comandos monitorados. | Configura retenção e regras para contas, sudoers, SSH, rede e persistência. Em Linux suportado, carrega/confere as regras; em WSL/contêiner, informa a limitação. |
| `audispd-plugins` | Acrescenta plugins para encaminhar/processar eventos do sistema de auditoria. | Instala o pacote de suporte. Não configura encaminhamento para SIEM ou coletor remoto. |
| `unattended-upgrades` | Aplica automaticamente atualizações permitidas pela política de origens do APT, normalmente incluindo segurança. | Habilita a atualização periódica dos índices e as atualizações automáticas, com os timers APT. Preserva a política de origens da distribuição. |
| `ufw` | Simplifica a administração do firewall Linux, controlando o tráfego permitido. | Se aceito, ativa o firewall, permite portas SSH detectadas e `10050/tcp` para Zabbix em IPv4/IPv6. |

#### Monitoramento de recursos e diagnóstico local

| Pacote | Para que serve | O que o script faz com ele |
| :--- | :--- | :--- |
| `btop` | Mostra CPU, memória, processos, discos e rede em um painel interativo no terminal. | Disponibiliza para uso manual; ajuda a identificar consumo e gargalos em tempo real. |
| `htop` | Mostra processos e consumo de CPU/memória, permitindo ordenar e inspecionar a lista. | Disponibiliza para uso manual como alternativa de monitoramento de processos. |
| `iotop` | Mostra quais processos estão lendo/escrevendo em disco. | Disponibiliza para investigar gargalos de entrada/saída. A coleta depende dos recursos/permissões do kernel. |
| `sysstat` | Fornece ferramentas como `sar`, `iostat` e `pidstat` para estatísticas de CPU, memória, disco e processos, incluindo histórico. | Define `ENABLED="true"` quando existe `/etc/default/sysstat` e habilita/inicia o serviço; a frequência de coleta segue a configuração do pacote. |
| `ncdu` | Mostra o espaço usado pelas pastas e permite navegar pelos maiores consumidores. | Disponibiliza para análise manual de disco; não executa limpeza automática. |
| `lynis` | Examina a configuração do Linux e apresenta recomendações de segurança e hardening. | Disponibiliza para auditoria manual. Não executa a auditoria nem aplica automaticamente suas recomendações. |

#### Rede, conectividade e consultas

| Pacote | Para que serve | O que o script faz com ele |
| :--- | :--- | :--- |
| `curl` | Faz requisições e transferências por protocolos como HTTP/HTTPS; útil para consultar APIs e testar serviços. | Disponibiliza para uso manual e para o alias `myip`, que consulta o IP público quando executado. |
| `dnsutils` | Fornece consultas DNS, como `dig` e `nslookup`, para investigar resolução de nomes. | Disponibiliza para uso manual. No Ubuntu 26.04 homologado, o pacote virtual é atendido por `bind9-dnsutils`. |
| `net-tools` | Fornece ferramentas tradicionais de rede, como `ifconfig`, `netstat`, `route` e `arp`. | Disponibiliza para diagnóstico e compatibilidade com procedimentos antigos. O alias `ports` usa `ss`, não `netstat`. |
| `mtr-tiny` | Combina sondagens de conectividade e descoberta de rota para mostrar latência/perdas por salto; fornece `mtr` em terminal. | Disponibiliza para investigar caminhos de rede manualmente. |
| `iperf3` | Mede a capacidade de transferência entre dois pontos, com um lado atuando como servidor e o outro como cliente. | Disponibiliza a ferramenta; não inicia testes nem cria uma regra UFW para sua porta de teste. |
| `nmap` | Consulta portas e serviços de um destino para diagnosticar o que está acessível pela rede. | Disponibiliza para varreduras manuais; não executa varredura de redes durante a instalação. |
| `tcpdump` | Captura pacotes de uma interface para investigar conexões e protocolos. | Disponibiliza para captura manual; não inicia uma captura permanente. |

#### Terminal, edição, arquivos e permissões

| Pacote | Para que serve | O que o script faz com ele |
| :--- | :--- | :--- |
| `tmux` | Mantém sessões de terminal com janelas/painéis; permite desconectar e retomar trabalhos, enquanto o servidor permanece em execução. | Disponibiliza para uso manual; não cria sessões ou executa tarefas automaticamente. |
| `vim` | Editor de texto no terminal para editar código e configurações. | Instala o editor mesmo sem personalização. Tema e plugins dependem da resposta à opção Vim. |
| `jq` | Lê, filtra e formata dados JSON, como respostas de APIs e arquivos de configuração. | Disponibiliza para uso manual e automações do administrador. |
| `tree` | Exibe pastas e arquivos em forma de árvore, facilitando a compreensão da estrutura. | Disponibiliza para inspeção manual. |
| `rsync` | Sincroniza arquivos/diretórios, com transferência incremental e opções de preservação de atributos. | Disponibiliza para transferências e rotinas definidas pelo administrador. Não configura um backup recorrente ou destino remoto. |
| `unzip` | Extrai e lista o conteúdo de arquivos ZIP. | Disponibiliza para manipulação manual de arquivos compactados. |
| `p7zip-full` / `7zip` | Fornece ferramentas 7-Zip para compactar/extrair arquivos, incluindo o formato `.7z`. | Seleciona `p7zip-full` no Ubuntu 24.04 e `7zip` no Ubuntu 26.04. Não compacta backups automaticamente. |
| `acl` | Fornece `getfacl` e `setfacl` para consultar/definir permissões adicionais por usuário ou grupo. | Disponibiliza para administração de permissões. Não aplica ACLs de aplicação web ou acesso amplo às pastas automaticamente. |

#### Pacotes instalados somente em condições específicas

| Pacote | Para que serve | Quando o script solicita/configura |
| :--- | :--- | :--- |
| `git` | Obtém e controla versões de arquivos/repositórios. | Quando a personalização Vim é aceita, obtém os plugins nos commits fixados pelo script. |
| `ca-certificates` | Fornece certificados de autoridades confiáveis para validar conexões TLS/HTTPS. | Solicitado junto com Git ao aceitar a personalização Vim, para suporte às conexões HTTPS aos repositórios. Pode já estar instalado ou vir por outras dependências. |
| `qemu-guest-agent` | Permite comunicação entre a VM e um hipervisor compatível, para operações como consultar informações do convidado e coordenar tarefas. | Em virtualização detectada como KVM/QEMU/Bochs, instala o agente; tenta iniciar se o canal `org.qemu.guest_agent.0` estiver presente. Canal ausente gera pendência. |
| `open-vm-tools` | Fornece integração do Linux convidado com VMware, incluindo o serviço de ferramentas da VM. | Em virtualização VMware, instala e habilita/inicia o serviço. Não é solicitado pelo ramo WSL. |

#### Plugins opcionais do Vim

Os plugins são obtidos por Git e instalados como um pacote nativo compartilhado do Vim, **não como pacotes APT**. Só são preparados quando a personalização é aceita.

| Plugin | Para que serve | Configuração usada |
| :--- | :--- | :--- |
| `sonokai` | Define as cores do editor e do destaque de sintaxe. | Tema Sonokai, estilo Andromeda e TrueColor quando suportado. |
| `vim-airline` | Acrescenta uma barra de status e recursos de interface, como a barra de abas. | Tema `sonokai`, extensão de abas habilitada e símbolos Powerline. |
| `vim-airline-themes` | Fornece temas adicionais para a barra do Airline. | Disponível no conjunto compartilhado; o perfil seleciona o tema `sonokai`. |
| `vim-devicons` | Acrescenta ícones associados a tipos de arquivo nas integrações compatíveis. | Carregado no conjunto de plugins; a exibição dos símbolos depende de fonte compatível no terminal. |
| `vim-polyglot` | Acrescenta suporte de sintaxe e outros recursos de edição para várias linguagens. | Carregado com detecção de tipo de arquivo, plugins de arquivo e indentação habilitados no perfil. |

### Recursos que não são um pacote instalado

Os **aliases**, o **banner de boas-vindas**, as **contas/grupos**, as **regras sudoers**, o **teclado/fuso** e as **regras de `/dev/shm`** são configurações geradas usando recursos do sistema. O script preserva um cliente de horário ativo (`chrony` ou `systemd-timesyncd`); se não houver cliente ativo e a unidade timesyncd existir, tenta habilitá-la. Não instala um novo cliente NTP como parte da lista de pacotes.

Esta preparação também **não instala Apache, bancos de dados ou o agente Zabbix**. A regra `10050/tcp` apenas libera a porta para um agente que será instalado/configurado separadamente. Os utilitários de diagnóstico não configuram esses serviços de aplicação.

### Códigos de saída

O resumo mantém rótulos em negrito e cores: ciano para informações, verde para estados confirmados e amarelo para pendências ou estados não verificados. A cor não substitui o texto do resultado nem o código de saída; regras auditd apenas gravadas continuam pendentes de verificação no kernel.

| Código | Significado |
| :--- | :--- |
| `0` | Etapas solicitadas concluídas e verificações obrigatórias aprovadas. |
| `1` | Falha; consultar etapa e relatório. Alterações anteriores podem permanecer. |
| `2` | Entrada encerrada/cancelada durante perguntas. |
| `3` | Conclusão com pendências, por exemplo root preservado, NTP não sincronizado ou utilitário opcional ausente. |
| `129`, `130`, `143` | Interrupção por HUP, INT ou TERM. |

```bash
# Consultar imediatamente após a execução, antes de outro comando.
echo "$?"
```

Os relatórios têm cópia em `/root` e na home do usuário sudo, quando possível. Falha de exportação pode alterar o código final; nesse caso, a mensagem no terminal informa o destino preservado. A instalação não é uma transação global: backups não desinstalam pacotes nem desfazem contas ou regras UFW.

---

## ⌨️ 3. Aliases de Produtividade no Shell (`.bashrc`)

Os aliases abaixo ficam em `/etc/pos-install-server/bash_aliases`, com chamada em `/root/.bashrc`, `/etc/skel/.bashrc` e nos perfis das contas Bash elegíveis com home existente, obtidas pelo NSS. A etapa informa se o arquivo compartilhado foi instalado, atualizado ou já estava atualizado, e se a chamada de cada perfil foi adicionada ou já existia. Conteúdo anterior dos perfis é preservado; falhas aparecem nas pendências. O resumo final também identifica o estado do arquivo compartilhado.

Para carregar na sessão atual, execute como o próprio usuário; no próximo Bash interativo o carregamento ocorre pelo perfil:

```bash
source ~/.bashrc
```

| Alias | Comando Real | Finalidade Operacional |
| :--- | :--- | :--- |
| `ll` | `ls -alFh` | Listagem detalhada com arquivos ocultos e tamanhos legíveis (KB, MB, GB). |
| `rm` | `rm -I` | Remoção segura com confirmação inteligente ao apagar mais de 3 arquivos ou recursivo. |
| `cp` | `cp -i` | Cópia com confirmação interativa antes de sobrescrever arquivos. |
| `mv` | `mv -i` | Movimentação com confirmação interativa antes de sobrescrever. |
| `df` | `df -h` | Exibe partições de disco e espaço livre em formato humano. |
| `free` | `free -h` | Exibe memória RAM e SWAP detalhada. |
| `ports` | `sudo ss -tulanp` | Lista portas TCP e UDP abertas no servidor com os respectivos processos. |
| `myip` | `curl -fsS https://ifconfig.me; echo` | Retorna rapidamente o endereço IP público externo do servidor. |
| `update` | `sudo apt-get update && sudo apt-get upgrade -y` | Atualiza a lista de repositórios e pacotes do sistema com um só comando. |
| `clean` | `sudo apt-get autoremove -y && sudo apt-get autoclean` | Remove pacotes órfãos e limpa o cache de pacotes baixados pelo APT. |
| `reload` | `source ~/.bashrc` | Recarrega as configurações do shell sem necessidade de deslogar da sessão. |
| `motd` | `/usr/local/bin/motd_banner.sh` | Exibe o banner com diagnóstico e métricas do servidor sob demanda. |
| `..` | `cd ..` | Sobe um nível de diretório. |
| `...` | `cd ../..` | Sobe dois níveis de diretório. |

---

## 📊 4. Monitoramento e Diagnóstico de Desempenho

### 4.1 Monitor de Processos e Recursos (`btop` / `htop`)
```bash
# Abre o monitor visual moderno e completo (CPU, RAM, Discos, Processos e Rede)
btop

# Abre o monitor clássico de processos
htop
```
> 💡 *Dica no `btop`: Utilize as teclas `m` para abrir o menu de configurações e `Esc` ou `q` para sair.*

---

### 4.2 Diagnóstico de Gargalos de Disco e I/O (`iotop`)
Permite identificar instantaneamente qual processo está travando o servidor com leitura ou gravação pesada em disco:
```bash
# Abre o monitor interativo de I/O em tempo real
sudo iotop

# Exibe APENAS os processos que estão realmente utilizando disco no momento (Recomendado)
sudo iotop -o

# Modo não-interativo para captura em logs (executa 3 coletas e sai)
sudo iotop -b -n 3
```

---

### 4.3 Histórico de Desempenho e Métricas do Sistema (`sysstat` / `sar` / `iostat`)
O `sysstat` fornece histórico de métricas por coletas periódicas. O script habilita a coleta e o serviço; a frequência e o agendamento por timer ou cron dependem da configuração do pacote na distribuição, não são fixados pelo instalador.

```bash
# Diagnóstico de taxa de transferência e I/O detalhado por disco em tempo real (1s de intervalo, 5 coletas)
iostat -xz 1 5

# Histórico de uso de CPU do dia atual
sar -u

# Histórico de consumo de Memória RAM e Buffers do dia atual
sar -r

# Histórico de Load Average e fila de processos do dia atual
sar -q

# Consultar o histórico de um dia específico do mês (ex: dia 20)
sar -u -f /var/log/sysstat/sa20
```

---

### 4.4 Análise e Limpeza Visual de Espaço em Disco (`ncdu`)
```bash
# Analisa todo o sistema de arquivos raiz a partir de /
sudo ncdu /

# Analisa apenas uma pasta específica (ex: diretório de logs ou sites)
sudo ncdu /var/log
sudo ncdu /var/www
```
> 💡 *Navegação no `ncdu`: Use as setas `↑` e `↓` para navegar, `Enter` para abrir pastas, `d` para deletar arquivos pesados com segurança e `q` para sair.*

---

## 🌐 5. Diagnóstico de Rede e Conectividade

### 5.1 Ping e Traceroute Dinâmico em Tempo Real (`mtr`)
Combina a funcionalidade do `ping` e do `traceroute`, mostrando onde ocorrem perdas de pacotes ao longo da rota:
```bash
# Diagnóstico contínuo interativo para um host ou IP
mtr 8.8.8.8
mtr google.com.br

# Modo relatório sem interface (executa 10 pings por salto e exibe o resultado)
mtr -rw -c 10 1.1.1.1
```

---

### 5.2 Teste de Largura de Banda e Velocidade entre Servidores (`iperf3`)
```bash
# No Servidor 1 (Servidor de Teste / Receptor):
iperf3 -s

# No Servidor 2 (Cliente / Emissor):
iperf3 -c 192.168.1.50

# Teste com tráfego reverso (Download a partir do servidor 1):
iperf3 -c 192.168.1.50 -R
```

---

### 5.3 Auditoria e Verificação de Portas (`nmap`)
```bash
# Varredura rápida de portas TCP abertas no próprio servidor
nmap -sT localhost

# Verificar portas abertas e identificar versão dos serviços em um IP alvo
nmap -sV -Pn 192.168.1.100

# Testar se portas específicas estão abertas em um destino (ex: Web e SSH)
nmap -p 22,80,443,10050 192.168.1.100
```

---

### 5.4 Captura e Inspeção de Tráfego de Rede (`tcpdump`)
```bash
# Captura tráfego em tempo real na interface eth0 sem resolver DNS (-n)
sudo tcpdump -i eth0 -n

# Captura apenas pacotes na porta 80 ou 443 (HTTP/HTTPS)
sudo tcpdump -i eth0 port 80 or port 443 -n

# Captura apenas pacotes de ou para um IP específico
sudo tcpdump -i eth0 host 192.168.1.200 -n

# Salva a captura em arquivo compatível com o Wireshark
sudo tcpdump -i eth0 -w /tmp/captura_rede.pcap
```

---

### 5.5 Consultas de DNS (`dnsutils` / `dig` / `nslookup`)
```bash
# Consulta rápida de registro A via servidor DNS padrão
dig google.com +short

# Forçar consulta em um servidor DNS específico (ex: Cloudflare 1.1.1.1)
dig @1.1.1.1 meu_dominio.com.br

# Consulta de registros específicos (MX, TXT, NS, CNAME)
dig meu_dominio.com.br MX +short
dig meu_dominio.com.br TXT +short

# Consulta reversa de IP (PTR)
dig -x 8.8.8.8 +short
```

---

## 🛡️ 6. Auditoria de Segurança, Hardening e Firewall

### 6.1 Auditoria Completa de Segurança e Hardening Index (`lynis`)
O **Lynis** faz uma varredura profunda de conformidade, configurações de kernel, permissões e vulnerabilidades:
```bash
# Executa a auditoria completa do servidor com pausas interativas
sudo lynis audit system

# Executa a auditoria completa de forma direta (Modo Rápido / Relatório)
sudo lynis audit system -Q

# Consultar todos os AVISOS (Warnings) e SUGESTÕES (Suggestions) gerados
sudo grep -E "Warning:|Suggestion:" /var/log/lynis.log

# Ver detalhes e solução recomendada de um item específico (ex: NETW-2705 ou AUTH-9230)
sudo lynis show details NETW-2705
```

---

### 6.2 Prevenção de Força Bruta no SSH (`fail2ban`)
```bash
# Verifica o status da jaula do SSH e quantidade de IPs banidos
sudo fail2ban-client status sshd

# Desbane manualmente um endereço IP (ex: caso um administrador seja bloqueado)
sudo fail2ban-client set sshd unbanip 192.168.1.100

# Banir manualmente um IP suspeito
sudo fail2ban-client set sshd banip 203.0.113.50

# Acompanha o log de tentativas e bloqueios em tempo real
sudo tail -f /var/log/fail2ban.log
```

---

### 6.3 Gerenciamento do Firewall (`ufw`)
```bash
# Exibe as regras ativas numeradas
sudo ufw status numbered

# Liberar porta TCP (ex: HTTP 80 e HTTPS 443)
sudo ufw allow 80/tcp comment 'Acesso Web HTTP'
sudo ufw allow 443/tcp comment 'Acesso Web HTTPS'

# Liberar porta apenas para uma sub-rede confiável (ex: Banco de Dados MySQL)
sudo ufw allow from 192.168.1.0/24 to any port 3306 proto tcp comment 'MySQL Apenas Rede Local'

# Remover uma regra pelo número de identificação
sudo ufw delete 4

# Recarregar as regras do firewall (sem queda de conexões ativas)
sudo ufw reload
```

---

## ⚡ 7. Produtividade, Manipulação de Dados e Arquivos

### 7.1 Manipulação e Formatação de JSON (`jq`)
```bash
# Formata e colore uma resposta JSON crua
curl -s https://api.github.com/users/octocat | jq .

# Extrai chaves específicas de um JSON
curl -s https://api.github.com/users/octocat | jq '.name, .public_repos, .location'

# Filtra arrays com condições
cat dados.json | jq '.servidores[] | select(.ativo == true)'
```

---

### 7.2 Terminal Multiplexer para Processos Longos (`tmux`)
Permite rodar rotinas longas (backups, migrações, updates) sem risco de interrupção se a conexão SSH cair:
```bash
# Iniciar uma nova sessão nomeada
tmux new -s rotina_backup

# Desconectar da sessão deixando o processo rodando em background
# Pressione: Ctrl + b e depois a tecla d (Detach)

# Reconectar à sessão ativa
tmux attach -t rotina_backup
# Ou de forma simplificada:
tmux a -t rotina_backup

# Listar todas as sessões ativas no servidor
tmux ls
```
> 💡 *Consulte o guia completo com divisão de telas e atalhos em [ajuda_tmux.md](ajuda_tmux.md).*

---

### 7.3 Visualização de Árvore de Pastas (`tree`)
```bash
# Visualiza a estrutura de diretórios limitando a 2 níveis de profundidade
tree -L 2 /var/www

# Exibe apenas os diretórios (ocultando arquivos)
tree -d -L 2 /etc
```

---

### 7.4 Sincronização e Transferência Segura (`rsync`)
```bash
# Sincroniza pasta local para servidor remoto mantendo permissões e exibindo progresso
rsync -avzhP /var/www/meu_site/ administrador@192.168.1.50:/var/www/meu_site/

# Simulação de sincronização sem alterar arquivos (Dry-Run seguro)
rsync -avzhP --dry-run /var/www/meu_site/ /backup/www/
```

---

### 7.5 Descompactação de Arquivos (`unzip` / `p7zip-full` / `7zip`)
```bash
# Descompacta arquivo .zip em uma pasta de destino
unzip arquivo.zip -d /caminho/destino/

# Descompacta arquivo .7z ou .tar.gz com 7z
7z x backup.7z -o/caminho/destino/
```

---

## 📝 8. Vim Opcional (Sonokai e Airline)

Ao aceitar a personalização, o script obtém cinco plugins dos repositórios oficiais por commits fixos: Sonokai, vim-airline, vim-airline-themes, vim-devicons e vim-polyglot. Não usa vim-plug nem carrega Vim como root para instalar plugins.

O perfil fica em `/etc/pos-install-server/vimrc`, com numeração de linhas, recuo de quatro espaços, TrueColor, tema Sonokai Andromeda e Airline. Os plugins nativos ficam em `/usr/local/share/pos-install-server/vim/2.5`.

A etapa mostra progresso de obtenção e verificação de cada plugin. Ao concluir, informa se o pacote compartilhado foi instalado ou já existia, lista os cinco plugins disponíveis e resume tema, barra de status/abas, sintaxe, recuo, busca e mouse. Também mostra, por perfil e em contadores, chamadas adicionadas, chamadas já existentes, configurações personalizadas preservadas e falhas. A recusa da opção ou falha de instalação é anunciada explicitamente.

As configurações são carregadas ao abrir o Vim com um perfil vinculado. Perfis personalizados preservados não recebem a chamada automaticamente; ícones Devicons/Airline exigem fonte compatível no terminal.

Arquivos `.vimrc` existentes são preservados, inclusive personalizações de versões anteriores. Para adotar o perfil manualmente, acrescente a linha abaixo ao seu `.vimrc` após revisar possíveis conflitos:

```vim
source /etc/pos-install-server/vimrc
```

As gravações em homes ocorrem como o usuário, sem copiar `.vim` de root e sem `chown` recursivo. A fixação de commits melhora a reprodutibilidade; não equivale a uma auditoria dos plugins.

---

## 🔒 9. Contas Protegidas e Administração da Equipe

**O grupo operacional informado recebe administração ampla**, incluindo instalação de bancos, Apache e outras aplicações, sem aprovação a cada ação. O nome é livre dentro da validação técnica (até 32 letras/números/hífen/sublinhado, começando por letra ou sublinhado), preservando maiúsculas/minúsculas. Grupos de sistema (GID inferior a 1000 ou 65534) e os grupos `administrador`/`geset` são recusados para preservar as contas protegidas. Os bloqueios são barreiras operacionais para comandos diretos e podem ser contornados por quem possui poder de root.

Em uma VM limpa, informar `dev` cria somente `/etc/sudoers.d/grupo_dev`, com regra para `%dev`; informar `DEV` cria somente `grupo_DEV`, com regra para `%DEV`. Grupos/regras de execuções anteriores permanecem preservados. Um arquivo legado com nome em minúsculas pode ser reutilizado quando sua regra gerenciada corresponde ao grupo exato, evitando duplicata. Se o caminho já pertence a outro grupo (por exemplo, `grupo_dev` contendo `%DEV` ao solicitar `dev`), o script interrompe sem sobrescrever a regra: revisar pelo console com `visudo`, preservando o acesso administrativo.

| Operação | Política da versão 2.5 |
| :--- | :--- |
| Instalar/configurar aplicações | Permitido pela regra ampla. |
| Alterar a própria senha | Usar `passwd`, sem sudo. |
| `sudo passwd root`, `administrador` ou `geset` | Negado nas formas diretas listadas; opções e outros caminhos não são isolamento. |
| `sudo passwd` sem argumento | Negado, pois atuaria sobre root. |
| Editar arquivos protegidos | Bloqueia editor + caminho absoluto exato em nano, vi, vim, vim.tiny e editor; sudoedit também é negado. |
| Caminhos SSH protegidos pelas barreiras | `sshd_config`, `pos-install-server.conf` e arquivos `.conf` existentes em `sshd_config.d/` com nomes simples, sob `/etc/ssh/`. |
| Outros bloqueios preservados | visudo, usermod, gpasswd, su e leituras diretas específicas de shadow. Também é negado executar sudo dentro de outro sudo. |

> ⚠️ Shells, instaladores e outros programas privilegiados continuam capazes de modificar contas e SSH. As regras não impedem que outro administrador tome controle do servidor. Outras concessões sudoers ou associação ao grupo sudo também podem alterar o resultado efetivo; confira a política de cada conta.

```bash
sudo visudo -c
```

```bash
sudo -l -U '<usuario_operacional>'
```

```bash
id '<usuario_operacional>'
```

O sudo-rs 0.2.13 verificado nesta entrega rejeita curingas em argumentos. Por compatibilidade, as regras usam caminhos exatos: opções do editor, múltiplos arquivos, caminhos relativos e novos drop-ins não estão cobertos. Reexecute a gestão dos grupos para incluir novos `.conf`; nomes fora de letras, números, ponto, hífen e sublinhado geram pendência.

O script valida cada política com o visudo instalado e depois valida o sudoers completo. A compatibilidade de comportamento com sudo e sudo-rs deve ser homologada nas respectivas VMs; não é presumida apenas por uma sintaxe comum.

---

## 📊 10. Auditoria de Contas, Sudo e SSH

Em VM Linux com suporte, o resumo só informa auditoria ativa após conferir serviço, estado do kernel e regras carregadas. Caminhos inexistentes são omitidos. Em WSL/contêiner, o relatório indica que a validação depende do host. Na homologação WSL de 30/09/2026, os arquivos passaram, mas `auditd.service` e `audit-rules.service` ficaram em `failed` por não conseguirem ativar a auditoria do kernel. Não considerar a auditoria operacional nesse ambiente apenas porque o pacote e as regras existem.

```bash
sudo auditctl -s
```

```bash
sudo auditctl -l
```

```bash
sudo ausearch -k auth_mod -ts today -i
```

```bash
sudo ausearch -k sudo_mod -ts today -i
```

```bash
sudo ausearch -k ssh_mod -ts today -i
```

```bash
sudo ausearch -k priv_escalation -ts today -i
```

Consulte `auid` para a identidade de login quando disponível, além de `uid`, `exe` e resultado. Regras de execução e alteração não equivalem a gravar todo o conteúdo da sessão. Não publique saídas sem revisar dados sensíveis.

Logs locais não resistem a um administrador root mal-intencionado. Encaminhamento externo e backups fora do alcance da equipe são integrações separadas, ainda não configuradas por este script.

---

## ✅ 11. Roteiro de Homologação na VM Limpa

Realizar separadamente no Ubuntu 24.04 e 26.04, com console do hipervisor disponível. Nunca executar testes de instalação nos Golden Templates WSL.

1. Transferir a versão local 2.5, executar em terminal interativo e guardar código de saída e relatório.
2. Criar as contas desejadas. Conferir instalação de uma aplicação como usuário operacional e alteração da própria senha com `passwd`.
3. Conferir negativas **sem executar alterações de senha ou de arquivos reais**, usando consultas de política na sessão operacional:

```bash
sudo -l /usr/bin/passwd root
```

```bash
sudo -l /usr/bin/passwd administrador
```

```bash
sudo -l /usr/bin/passwd geset
```

```bash
sudo -l /usr/bin/nano /etc/ssh/sshd_config
```

4. Testar outra conexão SSH com a conta administrativa antes de fechar a atual. Reexecutar para desabilitar root somente após esse teste. Conferir configuração e listeners:

```bash
sudo sshd -t
```

```bash
sudo sshd -T | grep -E '^(port|permitrootlogin|permitemptypasswords|clientaliveinterval|clientalivecountmax) '
```

```bash
sudo ss -ltnp
```

5. Em snapshot descartável, testar SSH em porta alternativa e conferir se UFW a preserva. Confirmar `10050/tcp` conforme a política atual:

```bash
sudo ufw status numbered
```

```bash
sudo fail2ban-client status sshd
```

```bash
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer
```

```bash
sudo journalctl -u apt-daily-upgrade.service --since today
```

```bash
sudo unattended-upgrade --dry-run
```

6. Conferir horários, montagem e auditoria. O serviço APT pode estar inativo após concluir normalmente; avaliar timer e histórico.

```bash
timedatectl status
```

```bash
findmnt --mountpoint /dev/shm -o TARGET,OPTIONS
```

7. Em VM limpa, informar somente `dev`: conferir que apenas `grupo_dev` foi criado, com `%dev`. Repetir em outro teste com `DEV` e conferir `grupo_DEV`/`%DEV`. Testar gestão do grupo sem criar usuário; reexecutar recusando gestão de grupo e conferir que os arquivos `grupo_*` não mudaram. Na presença de regra legada, conferir reutilização somente quando o grupo exato corresponde e recusa de sobrescrita de outro grupo. Confirmar preservação dos perfis Vim e das outras jaulas Fail2Ban.
8. Na VM descartável, testar falha de dependência, configuração preexistente inválida e interrupção durante a execução: exigir relatório de falha, ausência de sucesso falso e recuperação do SSH quando sua etapa estiver em andamento.
9. Aceitar a opção Vim em outro teste e conferir tema/plugins com conta comum. Testar também uma home com `.vimrc` simbólico: o alvo não deve ser modificado como root.

**Validação da entrega:** `bash -n`, ShellCheck 0.9.0/0.11.0 e análise de sintaxe dos trechos shell gerados passaram no Ubuntu 24.04/26.04. Uma política representativa passou nos dois parsers visudo. Em 30/09/2026, a Ubuntu-26.04-Teste foi recriada e o instalador executado duas vezes com todas as opções Sim, grupo `dev` e três contas: nenhuma mensagem de erro do instalador, código 3 pelas pendências WSL. Foram aprovadas 91 verificações, incluindo logins SSH reais por loopback, sudo-rs, bloqueio Fail2Ban no nftables, pacotes, aliases e Vim carregados. Três verificações limitadas correspondem a auditoria do kernel/unidades auditd falhas e `/dev/shm`. Acesso de outro computador, Ubuntu 24.04 e controles de kernel em VM convencional permanecem pendentes.

---

## 🛠️ 12. Recuperação pelo Console

### Conta de serviço SSH ausente

`Privilege separation user sshd does not exist` indica ausência da conta de serviço do OpenSSH, não falha na senha dos administradores. No Ubuntu 26.04, o script confere essa conta após instalar os pacotes e pode criá-la pela definição oficial `/usr/lib/sysusers.d/openssh-server.conf`.

No WSL, o backup base de homologação contém um stub `systemd-sysusers` que retorna sucesso sem criar contas. Recriar a VM copia esse comportamento novamente. O script agora recupera automaticamente esse caso conhecido: confirma o conteúdo do stub, a diversion exata, o proprietário/permissões do `.real`, sua identificação systemd e o checksum contra os metadados do pacote instalado. Informa o uso do binário original e processa somente a definição do OpenSSH. Não remove a diversion, não altera Golden Templates e não define senhas administrativas. Stubs, destinos ou binários desconhecidos continuam sendo rejeitados; fora desse caso WSL, reparar o pacote/ambiente.

Na `Ubuntu-26.04-Teste` recriada em 30/09/2026, a execução completa confirmou a recuperação automática da conta faltante. **A cópia atualizada do instalador trata esse caso automaticamente.** Como recuperação manual somente nesse ambiente já identificado e após conferir o binário, executar dentro da distribuição:

```bash
sudo /usr/bin/systemd-sysusers.real /usr/lib/sysusers.d/openssh-server.conf
```

```bash
sudo /usr/sbin/sshd -t
```

Se a validação passar, reexecutar o script. Esse procedimento cria a conta técnica `sshd`, sem definir senha administrativa; não remove a diversion nem modifica os Golden Templates. A causa de outros serviços com contas ausentes deve ser diagnosticada separadamente. Em outra máquina, verificar primeiro o pacote e as substituições locais, sem presumir que exista um arquivo `.real`.

### Link de compatibilidade dos locales

O erro `Destino administrativo é um link simbólico: /etc/default/locale` foi corrigido na etapa de locales. O pacote pode manter esse caminho como link para `/etc/locale.conf`; o script agora verifica o destino conhecido e faz backup/gravação no arquivo real. Não remova o link nem substitua-o por arquivo regular. Após usar a cópia atualizada do script, reexecute a instalação. Links para outros destinos continuam sendo rejeitados.

### Restaurar configurações após falha

Backups ficam no diretório informado no relatório, mantendo caminhos como `etc/ssh/sshd_config`. Na falha da etapa SSH, o script tenta restaurar os dois arquivos gerenciados e recarregar o serviço. Em `SIGKILL`, queda de energia ou falha de disco, a restauração automática não é garantida.

Pelo console, compare o arquivo atual ao backup da execução. Restaure somente os arquivos envolvidos, incluindo o arquivo de política SSH se ele já existia; se era novo, remova apenas esse arquivo gerado e restaure o `sshd_config` original. Antes de recarregar:

```bash
sudo sshd -t
```

```bash
sudo systemctl reload ssh
```

Não restaure a árvore inteira de `/etc` indiscriminadamente. Pacotes instalados, contas criadas e regras UFW não são revertidos por esses backups. Para refazer o teste completo, restaure o snapshot da VM.

Referências técnicas: [configuração OpenSSH e keepalive](https://man.openbsd.org/sshd_config), [validações sshd -t/-T/-C](https://man.openbsd.org/sshd), [limites de restrições sudoers](https://github.com/sudo-project/sudo/blob/main/docs/sudoers.man.in) e [configuração oficial do Fail2Ban](https://github.com/fail2ban/fail2ban/blob/master/config/jail.conf).
