# 🏛️ Cheat Sheet - Administração Essencial de Oracle Database & IBM DB2 (Linux)

![Oracle](https://img.shields.io/badge/Oracle-F80000?style=flat&logo=oracle&logoColor=white)
![IBM](https://img.shields.io/badge/IBM_DB2-052FAD?style=flat&logo=ibm&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![SQL](https://img.shields.io/badge/SQL-CC292B?style=flat&logo=sqlite&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência rápida e comandos de sobrevivência para **Oracle Database** e **IBM DB2** no Linux: controle de instâncias e listeners, criação de usuários, backups (`expdp`/`impdp` e `db2 backup`/`restore`), migração com `db2move` e diagnóstico de portas de rede.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Sistema | Caminho / Arquivo | Descrição |
| :--- | :--- | :--- |
| **Oracle** | `$ORACLE_HOME/network/admin/listener.ora` | Configuração do listener (portas e serviços escutados). |
| **Oracle** | `$ORACLE_HOME/network/admin/tnsnames.ora` | Resolução de apelidos de conexão (TNS alias). |
| **Oracle** | `/etc/oratab` | Relação das instâncias (`ORACLE_SID`) e flag de auto-start (`Y/N`). |
| **Oracle** | `$ORACLE_BASE/diag/rdbms/.../trace/alert_<SID>.log` | Log principal de alertas e erros da instância Oracle. |
| **DB2** | `~db2inst1/sqllib/` | Scripts de ambiente e utilitários da instância do DB2. |
| **DB2** | `~db2inst1/sqllib/db2dump/db2diag.log` | Log de diagnóstico principal da instância IBM DB2. |
| **DB2** | `/etc/services` | Mapeamento das portas do DB2 (geralmente porta 50000/TCP). |

---

## 🔴 ORACLE DATABASE

### ⚙️ 2. Oracle: Variáveis de Ambiente e Inicialização

Para operar o Oracle no terminal, é **obrigatório** carregar as variáveis de ambiente do usuário `oracle`:

```bash
# Alternar para o usuário oracle do sistema
sudo -i -u oracle

# Definir ou checar variáveis de ambiente vitais
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$PATH:$ORACLE_HOME/bin

# Ou usar o script oficial de inicialização de ambiente oraenv:
. oraenv <<< "ORCL"
```

---

### 🚀 3. Oracle: Gerenciamento da Instância e do Listener

#### Listener de Rede (Porta 1521)
```bash
# Verificar o status do Listener
lsnrctl status

# Iniciar / Parar o Listener
lsnrctl start
lsnrctl stop
```

#### Instância do Banco (`sqlplus`)
```bash
# Conectar como administrador supremo (SYSDBA)
sqlplus / as sysdba
```
* **Comandos dentro do SQL*Plus (`SQL>`):**
  ```sql
  -- Iniciar a instância e abrir o banco:
  STARTUP;

  -- Se for Oracle Multitenant (12c/19c+), abrir todos os PDBs plugáveis:
  ALTER PLUGGABLE DATABASE ALL OPEN;

  -- Parar o banco de dados de forma graciosa (aguarda término de transações):
  SHUTDOWN IMMEDIATE;

  -- Verificar status do banco:
  SELECT status, instance_name FROM v$instance;
  ```

---

### 👤 4. Oracle: Usuários, Tablespaces e Permissões

Conectado via `sqlplus / as sysdba`:

```sql
-- Criar Tablespace:
CREATE TABLESPACE dados_app DATAFILE '/u01/app/oracle/oradata/ORCL/dados01.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;

-- Criar Usuário:
CREATE USER app_user IDENTIFIED BY "<senha_segura>" DEFAULT TABLESPACE dados_app TEMPORARY TABLESPACE temp;

-- Conceder permissões básicas de conexão e manipulação:
GRANT CONNECT, RESOURCE TO app_user;
ALTER USER app_user QUOTA UNLIMITED ON dados_app;

-- Conceder privilégio de DBA (apenas se solicitado explicitamente):
GRANT DBA TO app_user;
```

---

### 💾 5. Oracle: Backup e Restauração com Data Pump (`expdp` / `impdp`)

O Oracle Data Pump é o utilitário moderno padrão para exportar e importar schemas e tabelas.

#### Pré-requisito no SQL*Plus (Criar diretório lógico de dump):
```sql
CREATE OR REPLACE DIRECTORY dpump_dir AS '/u01/backups';
GRANT READ, WRITE ON DIRECTORY dpump_dir TO app_user;
```

#### Exportar (Dump com `expdp` no shell Linux):
```bash
# Exportar um schema/usuário completo:
expdp app_user/"<senha_segura>"@ORCL schemas=app_user directory=dpump_dir dumpfile=backup_schema.dmp logfile=expdp.log

# Exportar banco completo (requer privilégio DBA):
expdp system/"<senha_system>"@ORCL full=y directory=dpump_dir dumpfile=backup_full.dmp logfile=exp_full.log
```

#### Importar (Restore com `impdp` no shell Linux):
```bash
# Restaurar o schema no mesmo usuário:
impdp app_user/"<senha_segura>"@ORCL schemas=app_user directory=dpump_dir dumpfile=backup_schema.dmp logfile=impdp.log

# Restaurar de um schema antigo para um novo schema/usuário:
impdp system/"<senha_system>"@ORCL directory=dpump_dir dumpfile=backup_schema.dmp remap_schema=app_user:novo_user logfile=imp_remap.log
```

---

## 🔵 IBM DB2

### ⚙️ 6. DB2: Ambiente e Controle da Instância

O DB2 trabalha com instâncias associadas a usuários do Linux (normalmente `db2inst1`).

```bash
# Alternar para o dono da instância DB2
sudo -i -u db2inst1

# Listar instâncias existentes
db2ilist

# Iniciar a instância do DB2
db2start

# Parar a instância do DB2 (forçando encerramento se necessário)
db2stop force
```

---

### 📊 7. DB2: Comandos Operacionais da CLI (`db2`)

```bash
# Listar todos os bancos de dados catalogados:
db2 list db directory

# Conectar a um banco de dados:
db2 connect to MEUBANCO

# Desconectar do banco de dados:
db2 connect reset

# Criar um novo banco de dados:
db2 "create database MEUBANCO using codeset UTF-8 territory BR"

# Listar todas as tabelas do usuário conectado:
db2 list tables for all

# Executar consultas SQL diretas pelo shell:
db2 "select count(*) from MEUBANCO.CLIENTES"
```

---

### 💾 8. DB2: Backup e Restauração (`backup db` / `restore db`)

#### 1. Fazer Backup do Banco para Diretório
```bash
# Desconectar todas as sessões ativas antes do backup offline:
db2 force applications all
db2 terminate

# Executar backup para o diretório /backup:
db2 backup db MEUBANCO to /backup

# Backup online (se o log archive estiver configurado):
db2 backup db MEUBANCO online to /backup
```

#### 2. Restaurar Banco a partir de Backup
```bash
# Restaurar sobrepondo o banco existente:
db2 restore db MEUBANCO from /backup replace existing

# Restaurar com outro nome de banco (criação de clone de teste):
db2 restore db MEUBANCO from /backup into BANCOTESTE
```

#### 3. Migração em Massa com `db2move`
O utilitário `db2move` exporta ou importa todas as tabelas de um schema em formato IXF/DEL:
```bash
# Exportar todas as tabelas do banco para a pasta atual:
mkdir /tmp/db2_export && cd /tmp/db2_export
db2move MEUBANCO export

# Importar tabelas em outro banco:
cd /tmp/db2_export
db2move BANCO_NOVO import
```

---

## 🔍 9. Diagnóstico de Portas de Rede

| Banco | Porta Padrão | Teste de Escuta no Linux |
| :--- | :--- | :--- |
| **Oracle** | `1521/TCP` | `ss -tulnp \| grep 1521` ou `nc -zv 127.0.0.1 1521` |
| **IBM DB2** | `50000/TCP` (ou 60000) | `ss -tulnp \| grep 50000` ou `nc -zv 127.0.0.1 50000` |
