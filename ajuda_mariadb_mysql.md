# 🛢️ Guia Prático e Comandos de Operação do MariaDB & MySQL

Este guia reúne os comandos essenciais para administração, gerenciamento de usuários, backup, restauração, otimização e solução de problemas no **MariaDB** e **MySQL**.

---

## 📁 1. Arquivos de Configuração e Logs Vitais

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

## ⚙️ 2. Conexão e Gerenciamento de Serviços

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

## 👤 3. Gerenciamento de Usuários, Senhas e Permissões (SQL)

Conectado ao prompt do MariaDB (`mysql>`), use os comandos abaixo:

* **Criar um novo banco de dados:**
  ```sql
  CREATE DATABASE meubanco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  ```

* **Criar um novo usuário com senha:**
  ```sql
  CREATE USER 'meuusuario'@'localhost' IDENTIFIED BY 'SenhaForte123!';
  -- Ou permitir acesso de qualquer IP (%):
  CREATE USER 'meuusuario'@'%' IDENTIFIED BY 'SenhaForte123!';
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
  ALTER USER 'meuusuario'@'localhost' IDENTIFIED BY 'NovaSenha123!';
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

## 💾 4. Backup e Restauração (`mariadb-dump` / `mysqldump`)

### 📦 Fazendo Backup (Dump)

* **Fazer backup de UM BANCO ESPECÍFICO para um arquivo `.sql`:**
  ```bash
  mariadb-dump -u root -p meubanco > backup_meubanco.sql
  # Ou mysqldump:
  mysqldump -u root -p meubanco > backup_meubanco.sql
  ```

* **Fazer backup compactado diretamente em `.sql.gz`:**
  ```bash
  mariadb-dump -u root -p meubanco | gzip > backup_meubanco.sql.gz
  ```

* **Fazer backup de TODOS OS BANCOS do servidor:**
  ```bash
  mariadb-dump -u root -p --all-databases > backup_todos_bancos.sql
  ```

---

### 📥 Restaurando Backup (Restore)

* **Restaurar um arquivo `.sql` em um banco existente:**
  ```bash
  mariadb -u root -p meubanco < backup_meubanco.sql
  ```

* **Restaurar um arquivo `.sql.gz` compactado:**
  ```bash
  gunzip < backup_meubanco.sql.gz | mariadb -u root -p meubanco
  ```

---

## 📊 5. Diagnóstico e Monitoramento de Performance

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

## 🔑 6. Procedimento para Resetar a Senha de Root Perdida

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
   ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('NovaSenhaRoot123');
   FLUSH PRIVILEGES;
   EXIT;
   ```
5. Reinicie o MariaDB normalmente:
   ```bash
   sudo pkill mysqld
   sudo systemctl start mariadb
   ```
