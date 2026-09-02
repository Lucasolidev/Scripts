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
| /etc/audit/auditd.conf | Arquivo principal de configuração do daemon, limites e rotação de logs |
| /etc/audit/rules.d/ | Diretório contendo as regras de auditoria modulares (*.rules) |
| /etc/audit/rules.d/web_security.rules | Regras específicas de monitoramento do diretório web e configs do Apache/PHP |
| /etc/audit/audit.rules | Arquivo consolidado de regras ativas carregadas no kernel |
| /var/log/audit/audit.log | Arquivo bruto contendo todos os eventos de auditoria registrados |

---

## ⚙️ 2. Gerenciamento e Controle do Serviço

### Status e Validação do Daemon
`ash
# Verificar status do serviço auditd
sudo systemctl status auditd

# Verificar se as regras do kernel estão ativas
sudo auditctl -s
`

### Carregar e Aplicar Regras
`ash
# Compila os arquivos de /etc/audit/rules.d/ e carrega as regras no kernel (MANDATÓRIO)
sudo augenrules --load

# Listar todas as regras de auditoria atualmente carregadas no kernel
sudo auditctl -l
`

### Rotação e Liberação de Logs
> 💡 *O comando systemctl stop auditd é bloqueado por padrão para proteção contra encobrimento de rastros. Para rotacionar logs de forma segura, utilize o serviço nativo:*

`ash
# 1. Rotacionar logs do auditd em execução
sudo service auditd rotate

# 2. Limpar arquivos antigos rotacionados (se necessário liberar espaço)
sudo rm -f /var/log/audit/audit.log.*

# 3. Truncar arquivo ativo com segurança
sudo truncate -s 0 /var/log/audit/audit.log

# 4. Verificar espaço ocupado pelos logs
sudo du -sh /var/log/audit/
`

---

## 🔍 3. Consultas e Filtros de Eventos com usearch

> 💡 *Sempre utilize o parâmetro -i (interpret) para traduzir IDs numéricos de UID, GID, syscalls e timestamps em texto legível.*

### Consultas por Chave/Tag (-k)
`ash
# Buscar todas as alterações registradas no diretório web
sudo ausearch -k web_modificacoes -i

# Buscar alterações nas configurações do Apache
sudo ausearch -k config_apache -i

# Buscar alterações nas configurações do PHP
sudo ausearch -k config_php -i

# Buscar alterações nas configurações do banco de dados (MySQL / MariaDB)
sudo ausearch -k config_mysql -i
`

### Filtros Temporais e Recentes
`ash
# Consultar apenas eventos das últimas horas/minutos
sudo ausearch -k web_modificacoes -ts recent -i

# Consultar eventos ocorridos no dia de hoje
sudo ausearch -k web_modificacoes -ts today -i

# Consultar eventos em um intervalo de tempo específico
sudo ausearch -k web_modificacoes -ts 01/09/2026 05:00:00 -te 01/09/2026 09:00:00 -i
`

### Filtros por Arquivo ou Usuário
`ash
# Rastrear todas as ações realizadas em um arquivo específico
sudo ausearch -f /caminho/do/diretorio/web/index.php -i

# Filtrar alterações realizadas exclusivamente pelo usuário do servidor web (www-data)
sudo ausearch -k web_modificacoes -ui www-data -i

# Filtrar alterações realizadas pelo root ou sessões administrativas
sudo ausearch -k web_modificacoes -ui root -i
`

---

## 📊 4. Relatórios Consolidados e Estatísticas com ureport

`ash
# Relatório consolidado e sumário de eventos por arquivo
sudo aureport -f -i --summary

# Lista cronológica de acessos e modificações em arquivos
sudo aureport -f -i

# Lista de todos os comandos executados no sistema
sudo aureport -c -i

# Relatório de tentativas de login e autenticação (sucesso e falha)
sudo aureport -au -i

# Resumo geral de segurança do sistema
sudo aureport --summary -i
`

---

## 🛡️ 5. Configuração de Regras de Auditoria Web (web_security.rules)

Para auditar o diretório da aplicação web e os arquivos de configuração do servidor LAMP, mantenha o arquivo /etc/audit/rules.d/web_security.rules com a seguinte estrutura:

`ini
# Monitora escrita (w) e alteração de atributos (a) no diretório do site
-w /var/www/html/meusite/ -p wa -k web_modificacoes

# Monitora configurações do Apache
-w /etc/apache2/ -p wa -k config_apache

# Monitora configurações do PHP
-w /etc/php/ -p wa -k config_php

# Monitora configurações do MariaDB / MySQL
-w /etc/mysql/ -p wa -k config_mysql
`

---

## 💡 6. Como Interpretar os Logs do Auditd

Ao inspecionar a saída do usearch, preste atenção nos 4 campos principais:

* comm= ou exe=: O executável/processo que disparou a ação (ex: /usr/sbin/apache2, php-fpm8.3, /usr/bin/touch, /usr/bin/chown).
* uid= / uid=: O usuário responsável pelo evento (uid é o login original do terminal, uid é o usuário do processo como www-data ou oot).
* 
ame=: O caminho do arquivo que foi criado, editado ou excluído.
* 
ametype=: O tipo de operação (CREATE para novo arquivo, DELETE para exclusão, NORMAL para edição/escrita).
