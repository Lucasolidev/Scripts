# 🗂️ Guia Prático e Comandos de Operação do LDAP / OpenLDAP

Este guia reúne os principais conceitos, arquivos de configuração, logs e comandos para administração de serviços de diretório **LDAP / OpenLDAP (`slapd`)** no Linux, incluindo consultas, criação, modificação e alteração de senhas via arquivos **LDIF**.

---

## 📐 1. Conceitos Básicos da Estrutura LDAP (DIT)

O LDAP organiza os dados em uma árvore chamada **DIT (Directory Information Tree)**:

* **DN (Distinguished Name):** O caminho único e absoluto de um objeto (ex: `uid=joao,ou=usuarios,dc=empresa,dc=com,dc=br`).
* **RDN (Relative Distinguished Name):** O primeiro componente do DN (ex: `uid=joao`).
* **DC (Domain Component):** Partes do domínio (ex: `dc=empresa,dc=com,dc=br` para `empresa.com.br`).
* **OU (Organizational Unit):** Unidade organizacional / pasta (ex: `ou=usuarios`, `ou=grupos`).
* **CN (Common Name):** Nome comum de um usuário ou grupo (ex: `cn=Joao Silva` ou `cn=TI`).
* **UID (User ID):** Login do usuário (ex: `uid=joao`).
* **ObjectClass:** Define a estrutura e os atributos obrigatórios/opcionais de um objeto (ex: `inetOrgPerson`, `posixAccount`, `posixGroup`).

---

## 📁 2. Arquivos de Configuração e Diretórios Vitais

### 📄 Arquivos Principais (OpenLDAP)

* **`/etc/ldap/slapd.d/`** (Debian/Ubuntu) ou **`/etc/openldap/slapd.d/`** (RHEL/CentOS)  
  Diretório de configuração dinâmica OLC (**On-Line Configuration** ou `cn=config`). No OpenLDAP moderno, as configurações ficam salvas em arquivos LDIF dentro dessa pasta.

* **`/etc/ldap/ldap.conf`** ou **`/etc/openldap/ldap.conf`**  
  Arquivo de configuração padrão dos utilitários de cliente LDAP (`ldapsearch`, `ldapadd`, etc.). Define o servidor padrão (`URI`) e a base padrão (`BASE`).

* **`/var/lib/ldap/`**  
  Diretório onde fica armazenado o banco de dados físico dos objetos LDAP (MDB).

* **`/etc/ldap/schema/`**  
  Esquemas que definem os tipos de objetos suportados (`core.schema`, `cosine.schema`, `inetorgperson.schema`, `nis.schema`).

---

## 📊 3. Arquivos de Log e Diagnóstico

* **Syslog Geral:**  
  Por padrão, o `slapd` envia mensagens para o syslog do sistema:
  ```bash
  sudo tail -f /var/log/syslog | grep slapd
  # ou via journalctl:
  sudo journalctl -u slapd -f
  ```

* **Habilitar Log Detalhado do OpenLDAP:**  
  Para alterar o nível de log para depurar problemas de autenticação/conexão:
  ```bash
  sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
  dn: cn=config
  changeType: modify
  replace: olcLogLevel
  olcLogLevel: stats
  EOF
  ```
  *(Níveis comuns: `stats` para conexões e buscas; `args` para detalhes de consultas; `none` para desligar).*

---

## ⚙️ 4. Comandos de Gerenciamento do Servidor (Server-Side)

### 🛠️ Validação e Status do Serviço

* **Status do serviço OpenLDAP (`slapd`):**
  ```bash
  sudo systemctl status slapd
  sudo systemctl restart slapd
  ```

* **Testar a integridade da configuração do OpenLDAP:**
  ```bash
  sudo slaptest -v
  ```

* **Exportar todo o banco de dados LDAP para backup (arquivo LDIF):**
  ```bash
  sudo slapcat -b "dc=empresa,dc=com,dc=br" -l backup_ldap.ldif
  ```

---

## 🔍 5. Comandos de Consulta e Busca (`ldapsearch`)

O comando `ldapsearch` é a ferramenta principal para buscar objetos na árvore LDAP.

### 💡 Parâmetros Mais Usados:
* `-x`: Autenticação simples (em vez de SASL).
* `-H`: URI do servidor LDAP (ex: `ldap://127.0.0.1` ou `ldaps://ldap.empresa.com.br`).
* `-b`: Base DN onde a busca deve começar.
* `-D`: Bind DN (usuário usado para autenticar no LDAP).
* `-W`: Solicita a senha do Bind DN no terminal de forma oculta.

---

### 📋 Exemplos Práticos de Busca

* **1. Buscar TODOS os objetos da base (Anônimo ou Autenticado):**
  ```bash
  ldapsearch -x -b "dc=empresa,dc=com,dc=br" -H ldap://127.0.0.1
  ```

* **2. Buscar autenticando como administrador (Bind DN):**
  ```bash
  ldapsearch -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -b "dc=empresa,dc=com,dc=br" -H ldap://127.0.0.1
  ```

* **3. Buscar um usuário específico pelo UID (login):**
  ```bash
  ldapsearch -x -b "ou=usuarios,dc=empresa,dc=com,dc=br" "(uid=joao)"
  ```

* **4. Buscar apenas contas de usuários Linux (`posixAccount`):**
  ```bash
  ldapsearch -x -b "dc=empresa,dc=com,dc=br" "(objectClass=posixAccount)"
  ```

* **5. Buscar todos os membros de um grupo específico:**
  ```bash
  ldapsearch -x -b "ou=grupos,dc=empresa,dc=com,dc=br" "(cn=TI)"
  ```

* **6. Retornar apenas atributos específicos (ex: nome e e-mail):**
  ```bash
  ldapsearch -x -b "ou=usuarios,dc=empresa,dc=com,dc=br" "(uid=joao)" cn mail uidNumber
  ```

---

## 📝 6. Inserção, Modificação e Troca de Senha (`ldapadd`, `ldapmodify`, `ldappasswd`)

### ➕ 1. Adicionar Objetos (`ldapadd`)

Para criar objetos, cria-se um arquivo de texto no formato **.ldif** e executa-se o `ldapadd`:

```bash
ldapadd -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -f novo_objeto.ldif -H ldap://127.0.0.1
```

---

### ✏️ 2. Modificar Objetos (`ldapmodify`)

Para alterar ou adicionar atributos em objetos existentes:

```bash
ldapmodify -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -f alteracao.ldif -H ldap://127.0.0.1
```

---

### 🔑 3. Alterar Senha de Usuário (`ldappasswd`)

O utilitário `ldappasswd` permite alterar a senha de um usuário diretamente:

* **Alterar senha de um usuário solicitando a nova senha interativamente:**
  ```bash
  ldappasswd -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -S "uid=joao,ou=usuarios,dc=empresa,dc=com,dc=br"
  ```

---

### ❌ 4. Deletar Objetos (`ldapdelete`)

Para apagar um objeto da árvore LDAP informando seu DN completo:

```bash
ldapdelete -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W "uid=joao,ou=usuarios,dc=empresa,dc=com,dc=br"
```

---

## 📄 7. Modelos de Arquivos LDIF (Prontos para Uso)

### 📂 Modelo 1: Criar Unidade Organizacional (OU) (`ou_usuarios.ldif`)
```ldif
dn: ou=usuarios,dc=empresa,dc=com,dc=br
objectClass: top
objectClass: organizationalUnit
ou: usuarios
```

---

### 👥 Modelo 2: Criar Grupo POSIX (`grupo_ti.ldif`)
```ldif
dn: cn=TI,ou=grupos,dc=empresa,dc=com,dc=br
objectClass: top
objectClass: posixGroup
cn: TI
gidNumber: 10001
```

---

### 👤 Modelo 3: Criar Usuário Completo (`usuario_joao.ldif`)
```ldif
dn: uid=joao,ou=usuarios,dc=empresa,dc=com,dc=br
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Joao Silva
sn: Silva
uid: joao
uidNumber: 10002
gidNumber: 10001
homeDirectory: /home/joao
loginShell: /bin/bash
mail: joao@empresa.com.br
userPassword: {SSHA}SenhaCriptografadaAqui
```

---

### ✏️ Modelo 4: Alterar Atributo (Adicionar E-mail) (`alterar_email.ldif`)
```ldif
dn: uid=joao,ou=usuarios,dc=empresa,dc=com,dc=br
changeType: modify
replace: mail
mail: joao.silva@novoemail.com.br
```

---

## 🐧 8. Validação no Cliente Linux (SSSD / PAM / NSS)

Se uma máquina Linux estiver configurada para autenticar usuários via LDAP (usando **SSSD** ou `nslcd`), use estes comandos para testar:

* **Verificar se o sistema enxerga o usuário LDAP:**
  ```bash
  getent passwd joao
  ```

* **Verificar os grupos e GIDs do usuário LDAP:**
  ```bash
  id joao
  ```

* **Limpar o cache do SSSD (forçar atualização dos dados LDAP):**
  ```bash
  sudo sssctl cache-remove -E
  sudo systemctl restart sssd
  ```
