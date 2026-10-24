# 🛢️ Guia Prático, Comparativo e Comandos de Operação do MariaDB & MySQL

![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CC292B?style=flat&logo=sqlite&logoColor=white)

Este guia reúne as diferenças conceituais entre **MariaDB vs MySQL**, um comparativo dos principais bancos de dados do mercado (**SQLite, PostgreSQL, SQL Server**) e todos os comandos essenciais para administração, gerenciamento de usuários, backup, restauração e solução de problemas.

---

## 🥊 1. MariaDB vs MySQL: Qual a Diferença e Quando Usar Cada Um?

### 📜 A História e Origem

* **MySQL:** Criado em 1995. Em 2008 foi comprado pela Sun Microsystems e, em 2010, adquirido pela **Oracle Corporation**.
* **MariaDB:** Criado em 2009 pelo próprio fundador original do MySQL (*Michael "Monty" Widenius*) como um *fork 100% Open-Source*. Foi criado para garantir que o banco permanecesse livre e comunitário caso a Oracle decidisse fechar o código do MySQL.

---

### ⚖️ Principais Diferenças

| Recurso | **MariaDB** | **MySQL** |
| :--- | :--- | :--- |
| **Licença** | 100% Livre (GPL v2) | Dupla Licença (Open-Source e Comercial Oracle) |
| **Desenvolvimento** | Comunitário e Transparente (MariaDB Foundation) | Controlado pela empresa proprietária (Oracle) |
| **Motores de Busca** | Motores avançados inclusos (**Aria**, **MyRocks**, **ColumnStore**) | Motores tradicionais (InnoDB, MyISAM) |
| **Desempenho** | Otimizador de queries mais ágil sob alta concorrência | Excelente, porém otimizações avançadas focam na versão paga |
| **Padrão no Linux** | **Padrão absoluto** no Ubuntu, Debian, RedHat, Rocky Linux | Requer adicionar repositório oficial da Oracle |

---

### 💡 Quando Usar Cada Um?

* **Use o MariaDB (Recomendado para a maioria dos projetos):**
  * Para qualquer servidor Linux, hospedagem web, WordPress, Laravel, Node.js, Python.
  * Quando você deseja **100% de código aberto**, custo zero, maior velocidade em queries e compatibilidade total com o ecossistema MySQL (ele aceita os mesmos comandos e drivers).
* **Use o MySQL:**
  * Quando contratado por grandes corporações (Enterprise) que exigem **suporte comercial pago oficial da Oracle**.
  * Quando algum software proprietário antigo exigir estritamente a assinatura da versão Oracle MySQL.

---

## 📊 2. Comparativo Geral dos Principais Bancos de Dados

| Banco de Dados | Arquitetura | Melhor Cenário de Uso |
| :--- | :--- | :--- |
| **MariaDB / MySQL** | Relacional (Servidor) | **Sistemas Web, E-commerce, WordPress, APIs Node/PHP/Python**. Muito rápido para operações de leitura e escrita web. |
| **PostgreSQL** | Relacional Avançado (Servidor) | **Sistemas Financeiros, BI, ERPs complexos, Dados Geográficos (PostGIS)**. Focado em conformidade estrita ACID, integridade de dados e consultas analíticas pesadas. |
| **SQLite** | Relacional Embutido (Arquivo único) | **Aplicativos Mobile (Android/iOS), Apps Desktop, IoT, Testes Locais e Sites Pequenos**. Não roda como serviço de rede; o banco inteiro é um único arquivo de disco. |
| **Microsoft SQL Server** | Relacional (Servidor) | **Ecossistemas Microsoft (.NET/C#), ERPs Corporativos (TOTVS, SAP)**. Integração nativa com Windows Server e Active Directory. |
| **MongoDB / Redis** | NoSQL (Não Relacional) | **Cache em memória (Redis), Documentos JSON flexíveis sem esquema fixo (MongoDB), Notificações em Tempo Real**. |

---

## 📁 3. Arquivos de Configuração e Logs Vitais

### 📄 Arquivos de Configuração

* **`/etc/mysql/mariadb.conf.d/50-server.cnf`** (Debian/Ubuntu MariaDB)  
  Arquivo principal de configuração do servidor MariaDB.

* **`/etc/mysql/my.cnf`** ou **`/etc/my.cnf`**  
  Arquivo de configuração global do MariaDB/MySQL.

---

### 📜 Arquivos de Log

* **`/var/log/mysql/error.log`** — Log principal de erros do MariaDB/MySQL.
* **`/var/log/mysql/mariadb-slow.log`** — Log de queries lentas (*Slow Query Log*).

---

## ⚙️ 4. Conexão e Gerenciamento de Serviços

* **Status e reinicialização do banco de dados:**
  ```bash
  sudo systemctl status mariadb
  sudo systemctl restart mariadb
  ```

* **Conectar ao MariaDB como root (com solicitação de senha):**
  ```bash
  sudo mysql -u root -p
  ```

---

## 👤 5. Gerenciamento de Usuários, Senhas e Permissões (SQL)

Conectado ao prompt do MariaDB (`mysql>`), use os comandos abaixo:

* **Criar um novo banco de dados:**
  ```sql
  CREATE DATABASE meubanco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ```

* **Criar um novo usuário com senha:**
  ```sql
  CREATE USER 'meuusuario'@'localhost' IDENTIFIED BY '<senha_do_usuario>';
  -- Ou permitir acesso de qualquer IP (%):
  CREATE USER 'meuusuario'@'%' IDENTIFIED BY '<senha_do_usuario>';
  ```

* **Conceder todos os privilégios de um banco para um usuário:**
  ```sql
  GRANT ALL PRIVILEGES ON meubanco.* TO 'meuusuario'@'localhost';
  FLUSH PRIVILEGES;
  ```

* **Listar todos os usuários cadastrados:**
  ```sql
  SELECT User, Host, Plugin FROM mysql.user;
  ```

* **Alterar a senha de um usuário existente:**
  ```sql
  ALTER USER 'meuusuario'@'localhost' IDENTIFIED BY '<nova_senha>';
  FLUSH PRIVILEGES;
  ```

* **Remover/Deletar um usuário:**
  ```sql
  DROP USER 'meuusuario'@'localhost';
  ```

* **Remover um banco de dados:**
  ```sql
  DROP DATABASE meubanco;
  ```

---

## 💾 6. Backup, Restauração e Migração Completa pela Rede

### 📦 6.1 Fazendo Backup (Dump)

* **Backup padrão de UM BANCO com flags recomendadas de integridade (Sem travar tabelas InnoDB):**
  ```bash
  mariadb-dump -u root -p --single-transaction --quick --routines --triggers --events meubanco > backup_meubanco.sql
  # Ou usando mysqldump:
  mysqldump -u root -p --single-transaction --quick --routines --triggers --events meubanco > backup_meubanco.sql
  ```
  > 💡 *`--single-transaction` garante consistência sem bloquear escritas no InnoDB; `--quick` lê linha por linha sem esgotar a RAM; `--routines --triggers --events` preserva procedures e gatilhos.*

* **Backup compactado diretamente em `.sql.gz` (Economiza banda e espaço em disco):**
  ```bash
  mariadb-dump -u root -p --single-transaction --quick meubanco | gzip > backup_meubanco.sql.gz
  ```

* **Backup de TODOS OS BANCOS do servidor:**
  ```bash
  mariadb-dump -u root -p --all-databases --single-transaction --quick --routines --triggers --events > backup_todos_bancos.sql
  ```

* **Backup apenas da estrutura (sem dados / DDL):**
  ```bash
  mariadb-dump -u root -p --no-data meubanco > estrutura_meubanco.sql
  ```

* **Backup apenas dos dados (sem CREATE TABLE / DML):**
  ```bash
  mariadb-dump -u root -p --no-create-info meubanco > dados_meubanco.sql
  ```

---

### 🌐 6.2 Copiando o Dump pela Rede para Outro Servidor Linux

Após gerar o arquivo de dump (`backup_meubanco.sql` ou `.sql.gz`), transfira para o servidor de destino:

#### Opção A: Usando `scp` (Secure Copy)
* **Cópia simples de arquivo único:**
  ```bash
  scp backup_meubanco.sql.gz <usuario_remoto>@<ip_destino>:/tmp/
  ```

* **Cópia via `scp` com porta SSH não-padrão (ex: 2222) e compressão de rede (`-C`):**
  ```bash
  scp -P 2222 -C backup_meubanco.sql.gz <usuario_remoto>@<ip_destino>:/tmp/
  ```

#### Opção B: Usando `rsync` (Recomendado para dumps grandes - exibe progresso e permite continuar se cair)
* **Cópia com barra de progresso em tempo real (`-P` ou `--progress`) e compressão (`-z`):**
  ```bash
  rsync -avzP backup_meubanco.sql.gz <usuario_remoto>@<ip_destino>:/tmp/
  ```

* **Cópia via `rsync` especificando porta SSH não padrão:**
  ```bash
  rsync -avzP -e "ssh -p 2222" backup_meubanco.sql.gz <usuario_remoto>@<ip_destino>:/tmp/
  ```

---

### 🚀 6.3 Migração Direta via Tubulação SSH (Sem Gravar Arquivo Intermediário no Disco!)
Se você tem pouco espaço em disco ou quer agilizar a prova prática, pode extrair o dump no servidor de origem e injetar diretamente no MariaDB/MySQL do servidor destino em um único comando:

* **Dump no servidor local ➔ Restore direto no servidor remoto:**
  ```bash
  mariadb-dump -u root -p --single-transaction meubanco | ssh <usuario_remoto>@<ip_destino> "mariadb -u root -p<senha_destino> meubanco_destino"
  ```

* **Se a porta SSH remota for diferente:**
  ```bash
  mariadb-dump -u root -p --single-transaction meubanco | ssh -p 2222 <usuario_remoto>@<ip_destino> "mariadb -u root -p<senha_destino> meubanco_destino"
  ```

---

### 📥 6.4 Restaurando o Backup no Servidor de Destino

No servidor de destino, antes de importar, garanta que o banco de dados e usuário existam:

1. **Criar o banco no destino (caso ainda não exista):**
   ```bash
   mysql -u root -p -e "CREATE DATABASE meubanco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   ```

2. **Restaurar a partir de arquivo `.sql` comum:**
   ```bash
   mariadb -u root -p meubanco < /tmp/backup_meubanco.sql
   # Ou com mysql:
   mysql -u root -p meubanco < /tmp/backup_meubanco.sql
   ```

3. **Restaurar a partir de arquivo compactado `.sql.gz` diretamente:**
   ```bash
   gunzip < /tmp/backup_meubanco.sql.gz | mariadb -u root -p meubanco
   # Ou com zcat:
   zcat /tmp/backup_meubanco.sql.gz | mysql -u root -p meubanco
   ```

4. **Restaurar backup completo (`--all-databases`):**
   ```bash
   mariadb -u root -p < /tmp/backup_todos_bancos.sql
   ```

---

### ✅ 6.5 Validação Pós-Migração e Integridade

* **Verificar tabelas importadas e quantidade de registros:**
  ```bash
  mysql -u root -p -e "USE meubanco; SHOW TABLES;"
  mysql -u root -p -e "SELECT count(*) FROM meubanco.<tabela_principal>;"
  ```

* **Checagem e otimização de integridade das tabelas (`mysqlcheck`):**
  ```bash
  mysqlcheck -u root -p --check --optimize meubanco
  ```

---

### 🔓 6.6 Habilitar Conexão Remota ao Banco (Se Exigido na Prova)

Por padrão o MariaDB/MySQL escuta apenas em `127.0.0.1`. Se a prova pedir para uma aplicação em outro servidor conectar no banco:

1. Edite o arquivo de configuração (`/etc/mysql/mariadb.conf.d/50-server.cnf` ou `/etc/mysql/mysql.conf.d/mysqld.cnf`):
   ```ini
   # Alterar de:
   bind-address = 127.0.0.1
   # Para escutar em todas as interfaces:
   bind-address = 0.0.0.0
   ```
2. Reinicie o serviço:
   ```bash
   sudo systemctl restart mariadb # ou mysql
   ```
3. Garanta que o usuário tenha permissão para conectar a partir do IP remoto ou de qualquer IP (`%`):
   ```sql
   CREATE USER 'meuusuario'@'%' IDENTIFIED BY '<senha_segura>';
   GRANT ALL PRIVILEGES ON meubanco.* TO 'meuusuario'@'%';
   FLUSH PRIVILEGES;
   ```
4. Libere a porta no firewall:
   ```bash
   sudo ufw allow 3306/tcp
   ```

## 📊 7. Diagnóstico e Monitoramento de Performance

* **Verificar conexões e queries rodando em tempo real:**
  ```sql
  SHOW PROCESSLIST;
  -- Ou mostrar queries completas sem cortar texto:
  SHOW FULL PROCESSLIST;
  ```

* **Matar uma query travada (usando o ID da coluna Id do PROCESSLIST):**
  ```sql
  KILL 1045;
  ```

* **Verificar o status dos motores de armazenamento (InnoDB):**
  ```sql
  SHOW ENGINE INNODB STATUS\G
  ```

* **Verificar o tamanho em MB de cada banco de dados no disco:**
  ```sql
  SELECT table_schema AS "Banco", 
         ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS "Tamanho (MB)" 
  FROM information_schema.TABLES 
  GROUP BY table_schema;
  ```

---

## 🔑 8. Procedimento para Resetar a Senha de Root Perdida

Caso perca a senha do `root` do MariaDB:

1. Pare o serviço do MariaDB:
   ```bash
   sudo systemctl stop mariadb
   ```
2. Inicie o MariaDB pulando a tabela de concessão de permissões:
   ```bash
   sudo mysqld_safe --skip-grant-tables --skip-networking &
   ```
3. Conecte ao MariaDB sem senha:
   ```bash
   sudo mysql -u root
   ```
4. Execute os comandos para resetar a senha:
   ```sql
   FLUSH PRIVILEGES;
   ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('<nova_senha_root>');
   FLUSH PRIVILEGES;
   EXIT;
   ```
5. Reinicie o MariaDB normalmente:
   ```bash
   sudo pkill mysqld
   sudo systemctl start mariadb
   ```
