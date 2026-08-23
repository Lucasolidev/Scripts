# 🛢️ Guia Prático, Comparativo e Comandos de Operação do MariaDB & MySQL

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

## 💾 6. Backup e Restauração (`mariadb-dump` / `mysqldump`)

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
   ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('NovaSenhaRoot123');
   FLUSH PRIVILEGES;
   EXIT;
   ```
5. Reinicie o MariaDB normalmente:
   ```bash
   sudo pkill mysqld
   sudo systemctl start mariadb
   ```
