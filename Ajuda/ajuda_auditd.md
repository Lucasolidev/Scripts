# 🛡️ Guia Prático e Comandos de Operação do Linux Audit Daemon (auditd)

![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardening-red?style=flat&logo=security&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência e auditoria do **auditd** (Linux Audit Daemon) para rastreamento de alterações em arquivos, configurações de serviços, comandos de terminal e integridade da infraestrutura em tempo real.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/audit/auditd.conf` | Arquivo principal de configuração do daemon, limites e rotação de logs. |
| `/etc/audit/rules.d/` | Diretório contendo as regras de auditoria modulares (`*.rules`). |
| `/etc/audit/rules.d/web_security.rules` | Regras específicas de monitoramento do diretório web e configurações do Apache/PHP. |
| `/etc/audit/audit.rules` | Arquivo consolidado de regras ativas carregadas no kernel. |
| `/var/log/audit/audit.log` | Arquivo bruto contendo todos os eventos de auditoria registrados. |

---

## ⚙️ 2. Gerenciamento e Controle do Serviço

### Status e Validação do Daemon

```bash
# Verificar status do serviço auditd
sudo systemctl status auditd
```

```bash
# Verificar se as regras do kernel estão ativas
sudo auditctl -s
```

### Validar e Carregar Regras (MANDATÓRIO)

```bash
# Verificar a sintaxe e a composição das regras antes de aplicá-las
sudo augenrules --check
```

```bash
# Compilar os arquivos de /etc/audit/rules.d/ e carregar as regras no kernel
sudo augenrules --load
```

```bash
# Listar todas as regras de auditoria atualmente carregadas no kernel
sudo auditctl -l
```

> 💡 *Valide as regras antes de carregá-las. Em ambientes críticos, mantenha uma sessão administrativa aberta para evitar perder o acesso durante alterações de segurança.*

### Rotação e Liberação de Logs

```bash
# Rotacionar logs do auditd em execução
sudo service auditd rotate
```

```bash
# ⚠️ Remover arquivos antigos rotacionados somente após confirmar que há backup
sudo rm -f /var/log/audit/audit.log.*
```

```bash
# ⚠️ Truncar o arquivo ativo somente se a política de retenção permitir
sudo truncate -s 0 /var/log/audit/audit.log
```

```bash
# Verificar espaço ocupado pelos logs
sudo du -sh /var/log/audit/
```

> 💡 *O comando `systemctl stop auditd` é bloqueado por padrão para proteção contra encobrimento de rastros. Para rotacionar logs com o daemon em execução, utilize o serviço nativo.*

---

## 🔍 3. Consultas e Filtros de Eventos com `ausearch`

> 💡 *Sempre utilize o parâmetro `-i` (interpret) para traduzir IDs numéricos de UID, GID, syscalls e timestamps em texto legível.*

### Consultas por Chave/Tag (`-k`)

```bash
# Buscar todas as alterações registradas no diretório web
sudo ausearch -k web_modificacoes -i
```

```bash
# Buscar alterações nas configurações do Apache
sudo ausearch -k config_apache -i
```

```bash
# Buscar alterações nas configurações do PHP
sudo ausearch -k config_php -i
```

```bash
# Buscar alterações nas configurações do banco de dados (MySQL / MariaDB)
sudo ausearch -k config_mysql -i
```

### Filtros Temporais e Recentes

```bash
# Consultar apenas eventos recentes
sudo ausearch -k web_modificacoes -ts recent -i
```

```bash
# Consultar eventos ocorridos no dia de hoje
sudo ausearch -k web_modificacoes -ts today -i
```

```bash
# Consultar eventos em um intervalo de tempo específico
sudo ausearch -k web_modificacoes -ts 01/09/2026 05:00:00 -te 01/09/2026 09:00:00 -i
```

### Filtros por Arquivo ou Usuário

```bash
# Rastrear todas as ações realizadas em um arquivo específico
sudo ausearch -f /caminho/do/diretorio/web/index.php -i
```

```bash
# Filtrar alterações realizadas pelo usuário do servidor web (www-data)
sudo ausearch -k web_modificacoes -ui www-data -i
```

```bash
# Filtrar alterações realizadas pelo root ou sessões administrativas
sudo ausearch -k web_modificacoes -ui root -i
```

---

## 📊 4. Relatórios Consolidados e Estatísticas com `aureport`

```bash
# Relatório consolidado e sumário de eventos por arquivo
sudo aureport -f -i --summary
```

```bash
# Lista cronológica de acessos e modificações em arquivos
sudo aureport -f -i
```

```bash
# Lista de todos os comandos executados no sistema
sudo aureport -c -i
```

```bash
# Relatório de tentativas de login e autenticação (sucesso e falha)
sudo aureport -au -i
```

```bash
# Resumo geral de segurança do sistema
sudo aureport --summary -i
```

---

## 🛡️ 5. Configuração de Regras de Auditoria Web (`web_security.rules`)

Para auditar o diretório da aplicação web e os arquivos de configuração do servidor LAMP, mantenha o arquivo `/etc/audit/rules.d/web_security.rules` com a seguinte estrutura:

```ini
# Monitora escrita (w) e alteração de atributos (a) no diretório do site
-w /var/www/html/meusite/ -p wa -k web_modificacoes
```

```ini
# Monitora configurações do Apache
-w /etc/apache2/ -p wa -k config_apache
```

```ini
# Monitora configurações do PHP
-w /etc/php/ -p wa -k config_php
```

```ini
# Monitora configurações do MariaDB / MySQL
-w /etc/mysql/ -p wa -k config_mysql
```

> 💡 *Depois de salvar a regra, execute `sudo augenrules --check` e, se não houver erros, `sudo augenrules --load`.*

---

## 💡 6. Como Interpretar os Logs do Auditd

Ao inspecionar a saída do `ausearch`, preste atenção aos quatro campos principais:

* `comm=` ou `exe=`: executável ou processo que disparou a ação.
* `auid=` / `uid=`: usuário responsável pelo evento; `auid` é o login original e `uid` é o usuário efetivo do processo, como `www-data`.
* `name=`: caminho do arquivo criado, editado ou excluído.
* `nametype=`: tipo de operação, como `CREATE`, `DELETE` ou `NORMAL`.
