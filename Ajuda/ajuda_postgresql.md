# 🐘 Cheat Sheet - Administração, Migração e Operação do PostgreSQL

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CC292B?style=flat&logo=sqlite&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de referência rápida e comandos essenciais para administração do **PostgreSQL** no Linux: instalação, gerenciamento de usuários e bancos, resolução da autenticação no `pg_hba.conf`, backups com `pg_dump`/`pg_dumpall`, restauração com `pg_restore`/`psql`, e transferência de dumps pela rede com `scp`, `rsync` e túnel SSH.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/postgresql/<versao>/main/postgresql.conf` | Arquivo principal de configuração do PostgreSQL (porta, escuta IP, memória). |
| `/etc/postgresql/<versao>/main/pg_hba.conf` | Arquivo de controle de autenticação de clientes (**Host-Based Authentication**). |
| `/var/lib/postgresql/<versao>/main/` | Diretório contendo os arquivos físicos dos bancos de dados (*Cluster Data Directory*). |
| `/var/log/postgresql/` | Arquivos de log de erros e eventos do servidor PostgreSQL. |
| `/usr/lib/postgresql/<versao>/bin/` | Binários dos utilitários (`psql`, `pg_dump`, `pg_restore`, `initdb`). |

> 💡 *Para descobrir a versão instalada no Debian/Ubuntu: `pg_lsclusters` ou `psql --version`.*

---

## ⚙️ 2. Gerenciamento do Serviço e Acesso Inicial

### Status e Controle do Serviço
```bash
# Verificar status do serviço
sudo systemctl status postgresql

# Reiniciar o serviço
sudo systemctl restart postgresql

# Recarregar configurações sem desconectar usuários (após alterar pg_hba.conf)
sudo systemctl reload postgresql
```

### Acessar a CLI Interativa (`psql`)
O PostgreSQL cria um usuário de sistema chamado `postgres`. Para acessar inicialmente:
```bash
# Conectar diretamente ao console como superusuário postgres
sudo -u postgres psql

# Ou alternar para o shell do usuário postgres e depois abrir o psql
sudo -i -u postgres
psql
```

### Comandos Internos Essenciais da CLI do `psql` (Meta-comandos com barra)
* `\l` ou `\l+` : Listar todos os bancos de dados e seus tamanhos.
* `\c <nome_banco>` : Conectar e mudar para outro banco de dados.
* `\dt` ou `\dt+` : Listar tabelas do banco atual.
* `\du` : Listar usuários/roles e seus privilégios.
* `\d <tabela>` : Descrever colunas e tipos de uma tabela específica.
* `\dn` : Listar schemas existentes.
* `\x` : Alternar visualização expandida de resultados (ótimo para linhas largas).
* `\q` : Sair do psql e voltar ao terminal Linux.

---

## 👤 3. Gerenciamento de Bancos, Usuários e Permissões (SQL)

Conectado ao prompt do PostgreSQL (`postgres=#`), execute:

### Criar Banco de Dados
```sql
CREATE DATABASE meubanco WITH ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';
```

### Criar Usuário (Role) com Senha
```sql
CREATE USER meuusuario WITH ENCRYPTED PASSWORD '<senha_segura>';
```

### Conceder Privilégios Totais ao Usuário no Banco
```sql
GRANT ALL PRIVILEGES ON DATABASE meubanco TO meuusuario;
-- No PostgreSQL 15+, também é necessário liberar privilégios no schema public:
\c meubanco
GRANT ALL ON SCHEMA public TO meuusuario;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO meuusuario;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO meuusuario;
```

### Tornar um Usuário Superusuário ou Permitir Criar Bancos
```sql
ALTER USER meuusuario WITH CREATEDB;
-- Conceder superusuário (cuidado):
ALTER USER meuusuario WITH SUPERUSER;
```

### Alterar Senha de Usuário Existente
```sql
ALTER USER meuusuario WITH PASSWORD '<nova_senha_segura>';
```

### Remover Usuário e Banco
```sql
DROP DATABASE meubanco;
DROP USER meuusuario;
```

---

## 🔑 4. Pegadinha Clássica de Prova: Autenticação e Acesso Remoto

Por padrão, o PostgreSQL rejeita conexões de rede e conexões locais com senha se o `pg_hba.conf` estiver no modo `peer`!

### Passo 1: Permitir Escuta em Todas as Interfaces de Rede
Edite o arquivo `/etc/postgresql/<versao>/main/postgresql.conf`:
```ini
# Localize a linha listen_addresses e descomente/altere:
listen_addresses = '*'
```

### Passo 2: Configurar Métodos de Autenticação (`pg_hba.conf`)
Edite o arquivo `/etc/postgresql/<versao>/main/pg_hba.conf`:
```text
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Conexão local via socket Unix (altere de peer para scram-sha-256 ou md5 se quiser usar senha no terminal):
local   all             all                                     scram-sha-256

# Conexão local via IPv4 (localhost / 127.0.0.1):
host    all             all             127.0.0.1/32            scram-sha-256

# Liberar acesso para a rede local ou servidores de aplicação:
host    all             all             192.168.1.0/24          scram-sha-256

# Liberar acesso de qualquer IP (caso exigido em ambiente de teste/VPS):
host    all             all             0.0.0.0/0               scram-sha-256
```
> 💡 *Diferença de métodos:*
> * `peer`: Usa o login do sistema operacional Linux. Se o usuário Linux não chamar `postgres`, o login é negado.
> * `scram-sha-256` ou `md5`: Exige a senha cadastrada no banco (padrão de conexões de rede e aplicações web).
> * `trust`: Permite acesso sem senha alguma (NUNCA usar em produção).

### Passo 3: Recarregar o PostgreSQL e Liberar Firewall
```bash
sudo systemctl restart postgresql
sudo ufw allow 5432/tcp
```

### Passo 4: Testar Conexão Remota
```bash
psql -h <ip_do_servidor> -U meuusuario -d meubanco -W
```

---

## 💾 5. Backup (Dump) e Restauração Completa

O PostgreSQL possui dois utilitários principais de backup: `pg_dump` (um banco específico) e `pg_dumpall` (toda a instância).

### 📦 5.1 Fazendo Backup (Dump)

* **Opção 1: Formato Custom `.dump` (Altamente Recomendado para Produção e Provas):**
  O formato custom (`-F c`) é compactado, permite restaurar tabelas selecionadas e suporta multithread no `pg_restore`.
  ```bash
  pg_dump -U postgres -h localhost -F c -b -v -f /tmp/backup_meubanco.dump meubanco
  ```

* **Opção 2: Formato SQL Texto Plano (`.sql`):**
  Gera comandos SQL puros (legível em editores de texto).
  ```bash
  pg_dump -U postgres -h localhost -F p -v meubanco > /tmp/backup_meubanco.sql
  ```

* **Opção 3: Backup de TODOS OS BANCOS, Usuários e Permissões (`pg_dumpall`):**
  Ideal para migrar o servidor PostgreSQL completo:
  ```bash
  pg_dumpall -U postgres -h localhost -v > /tmp/backup_todos_bancos.sql
  ```

* **Opção 4: Backup apenas da estrutura (DDL / sem dados):**
  ```bash
  pg_dump -U postgres -s -F c -f /tmp/schema_meubanco.dump meubanco
  ```

---

### 🌐 5.2 Copiando o Dump pela Rede para Outro Linux

Após gerar o arquivo `/tmp/backup_meubanco.dump` no servidor de origem, transfira para o servidor de destino:

#### Via `scp` (Com barra de status e porta não padrão):
```bash
scp -P 22 -C /tmp/backup_meubanco.dump <usuario_remoto>@<ip_destino>:/tmp/
```

#### Via `rsync` (Recomendado - suporta continuação se cair):
```bash
rsync -avzP -e "ssh -p 22" /tmp/backup_meubanco.dump <usuario_remoto>@<ip_destino>:/tmp/
```

---

### 🚀 5.3 Migração Direta via Tubulação SSH (Sem Gravar Arquivo Intermediário!)
Para migrar o banco rapidamente entre dois servidores Linux sem precisar de espaço em disco extra:

```bash
pg_dump -U postgres -h localhost meubanco | ssh <usuario_remoto>@<ip_destino> "psql -U postgres -d meubanco"
```

---

### 📥 5.4 Restaurando o Backup no Servidor de Destino

No servidor de destino:

#### 1. Restaurando Formato Custom (`.dump`) com `pg_restore`:
```bash
# Caso o banco meubanco já exista no destino:
pg_restore -U postgres -h localhost -d meubanco -v /tmp/backup_meubanco.dump

# Caso queira que o comando limpe/recrie os objetos antes de importar:
pg_restore -U postgres -h localhost -d meubanco --clean --if-exists -v /tmp/backup_meubanco.dump

# Restauração multithread acelerada (usando 4 núcleos de CPU):
pg_restore -U postgres -h localhost -d meubanco -j 4 -v /tmp/backup_meubanco.dump
```

#### 2. Restaurando Formato SQL Texto (`.sql`):
```bash
# Se o banco não existir, crie-o primeiro:
sudo -u postgres createdb meubanco

# Importe o arquivo SQL usando o psql:
psql -U postgres -h localhost -d meubanco < /tmp/backup_meubanco.sql
```

#### 3. Restaurando Backup Geral de Toda a Instância (`pg_dumpall`):
```bash
psql -U postgres -h localhost -f /tmp/backup_todos_bancos.sql
```

---

## 📊 6. Diagnóstico e Resolução de Problemas

### Checar Conexões e Queries Ativas em Tempo Real
```sql
SELECT pid, usename, client_addr, state, query, age(clock_timestamp(), query_start) AS duracao
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duracao DESC;
```

### Cancelar ou Matar Queries Travadas
```sql
-- Cancelar gentilmente uma query pelo PID:
SELECT pg_cancel_backend(12345);

-- Forçar encerramento imediato da conexão se a query travar o processo:
SELECT pg_terminate_backend(12345);
```

### Verificar Tamanho dos Bancos no Disco
```sql
SELECT pg_database.datname AS "Banco",
       pg_size_pretty(pg_database_size(pg_database.datname)) AS "Tamanho"
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

### Manutenção e Otimização de Tabelas
```sql
-- Liberar espaço em disco e atualizar estatísticas do otimizador:
VACUUM (VERBOSE, ANALYZE);

-- Limpeza profunda reescrevendo tabelas (bloqueia leituras/escritas temporariamente):
VACUUM FULL;
```
