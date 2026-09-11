# 🗂️ Guia Prático e Comandos de Operação do LDAP / OpenLDAP

![OpenLDAP](https://img.shields.io/badge/OpenLDAP-002B49?style=flat&logo=openldap&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Security](https://img.shields.io/badge/Security-informational?style=flat&logo=auth0&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

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

---

## 🧭 5. Colinha Mestra de Parâmetros da CLI LDAP

| Parâmetro | Significado / Função | Exemplo de Uso |
| :--- | :--- | :--- |
| **`-x`** | **Autenticação Simples** (desativa SASL, obrigatório na maioria das provas) | `ldapsearch -x ...` |
| **`-D <DN>`** | **Bind DN** (usuário que está autenticando) | `-D "cn=admin,dc=empresa,dc=com,dc=br"` |
| **`-W`** | **Solicita a Senha** interativamente (oculta no terminal) | `ldapsearch -x -D ... -W` |
| **`-w <senha>`** | **Informa a Senha Inline** (evita prompt, útil em scripts) | `-w '<senha_admin>'` |
| **`-H <URI>`** | **URI do Servidor** (protocolo + IP/Host + porta) | `-H ldap://127.0.0.1:389` ou `ldaps://host:636` |
| **`-b <DN>`** | **Search Base** (ponto inicial da árvore para a busca) | `-b "dc=empresa,dc=com,dc=br"` |
| **`-s <escopo>`** | **Escopo da Busca** (`base` = só o DN, `one` = 1 nível abaixo, `sub` = recursivo total) | `-s sub` ou `-s one` |
| **`-LLL`** | **Saída Limpa** (remove comentários `#`, versão LDIF e linhas extras) | `ldapsearch -x -LLL ...` |
| **`-f <arq>`** | **Arquivo LDIF** de entrada para inserção ou modificação | `ldapadd -f novo.ldif` |
| **`-c`** | **Modo Contínuo** (continua executando mesmo se encontrar erros) | `ldapadd -c -f lote.ldif` |
| **`-S`** | **Prompt de Nova Senha** (exclusivo do `ldappasswd`) | `ldappasswd -S ...` |
| **`-s <senha>`** | **Nova Senha Inline** (exclusivo do `ldappasswd`) | `ldappasswd -s '<nova_senha>' ...` |
| **`-Y EXTERNAL`** | **Autenticação SASL Local** via socket root (não pede senha!) | `ldapmodify -Y EXTERNAL -H ldapi:///` |

---

## 🔍 6. Comandos de Consulta e Busca (`ldapsearch`)

* **1. Buscar TODOS os objetos da base (com saída limpa sem comentários):**
  ```bash
  ldapsearch -x -LLL -b "dc=empresa,dc=com,dc=br" -H ldap://127.0.0.1
  ```

* **2. Buscar autenticando como administrador (Bind DN) com prompt de senha:**
  ```bash
  ldapsearch -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -b "dc=empresa,dc=com,dc=br" -H ldap://127.0.0.1
  ```

* **3. Buscar um usuário específico pelo UID (login):**
  ```bash
  ldapsearch -x -b "ou=usuarios,dc=empresa,dc=com,dc=br" "(uid=joao)"
  ```

* **4. Filtros Combinados (Lógica AND `&` / OR `|` / NOT `!`):**
  ```bash
  # AND: Usuário que seja posixAccount E tenha UID joao
  ldapsearch -x -b "dc=empresa,dc=com,dc=br" "(&(objectClass=posixAccount)(uid=joao))"

  # OR: Usuários do setor TI OU Diretoria
  ldapsearch -x -b "dc=empresa,dc=com,dc=br" "(|(ou=TI)(ou=Diretoria))"

  # NOT: Contas que NÃO têm o shell /bin/false
  ldapsearch -x -b "dc=empresa,dc=com,dc=br" "(&(objectClass=posixAccount)(!(loginShell=/bin/false)))"
  ```

* **5. Retornar apenas atributos específicos (ex: nome, e-mail e UID Number):**
  ```bash
  ldapsearch -x -b "ou=usuarios,dc=empresa,dc=com,dc=br" "(uid=joao)" cn mail uidNumber
  ```

* **6. Exportar resultado da busca diretamente para arquivo LDIF:**
  ```bash
  ldapsearch -x -LLL -b "dc=empresa,dc=com,dc=br" "(objectClass=posixAccount)" > usuarios_exportados.ldif
  ```

---

## 📝 7. Inserção, Modificação e Troca de Senha (`ldapadd`, `ldapmodify`, `ldappasswd`)

### ➕ 1. Adicionar Objetos Rapidamente via Terminal (HereDoc - Sem Criar Arquivo Separado)
Para agilizar em provas práticas, você pode injetar o LDIF diretamente na CLI:

```bash
ldapadd -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -H ldap://127.0.0.1 <<EOF
dn: uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Maria Silva
sn: Silva
uid: mariasilva
uidNumber: 10005
gidNumber: 10001
homeDirectory: /home/mariasilva
loginShell: /bin/bash
mail: maria.silva@empresa.com.br
userPassword: <senha_usuario>
EOF
```

---

### ✏️ 2. Modificar Atributos de Objetos Existentes (`ldapmodify`)

* **Alterar/Substituir um atributo existente (`replace`):**
  ```bash
  ldapmodify -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -H ldap://127.0.0.1 <<EOF
  dn: uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br
  changetype: modify
  replace: mail
  mail: maria.novoemail@empresa.com.br
  EOF
  ```

* **Adicionar um novo atributo a um objeto (`add`):**
  ```bash
  ldapmodify -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -H ldap://127.0.0.1 <<EOF
  dn: uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br
  changetype: modify
  add: telephoneNumber
  telephoneNumber: +55 11 99999-8888
  EOF
  ```

* **Remover um atributo de um objeto (`delete`):**
  ```bash
  ldapmodify -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -H ldap://127.0.0.1 <<EOF
  dn: uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br
  changetype: modify
  delete: telephoneNumber
  EOF
  ```

---

### 🔑 3. Gerenciamento e Troca de Senhas (`ldappasswd` e `slappasswd`)

* **Alterar senha de usuário solicitando interativamente no terminal:**
  ```bash
  ldappasswd -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -S "uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br"
  ```

* **Alterar senha de usuário informando a nova senha inline (`-s`):**
  ```bash
  ldappasswd -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -s '<nova_senha>' "uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br"
  ```

* **Gerar Hash de Senha Seguro (SSHA) no terminal:**
  ```bash
  slappasswd -s '<minha_senha>'
  # Saída: {SSHA}d41d8cd98f00b204e9800998ecf8427e...
  ```

* **Resetar a Senha do Admin do OpenLDAP via Socket Local (Sem Saber a Senha Antiga):**
  ```bash
  # 1. Gere o novo hash:
  NOVO_HASH=$(slappasswd -s '<nova_senha_admin>')

  # 2. Aplique direto no cn=config usando o usuário root do Linux via ldapi:
  sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
  dn: olcDatabase={1}mdb,cn=config
  changetype: modify
  replace: olcRootPW
  olcRootPW: $NOVO_HASH
  EOF
  ```

---

### ❌ 4. Deletar Objetos (`ldapdelete`)

* **Remover um usuário ou grupo pelo DN completo:**
  ```bash
  ldapdelete -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W "uid=mariasilva,ou=usuarios,dc=empresa,dc=com,dc=br"
  ```

* **Remover recursivamente (árvore com sub-objetos - `-r`):**
  ```bash
  ldapdelete -x -D "cn=admin,dc=empresa,dc=com,dc=br" -W -r "ou=antiga,dc=empresa,dc=com,dc=br"
  ```

---

### 📦 5. Backup e Restauração de Baixo Nível (`slapcat` e `slapadd`)

* **Backup completo do banco de dados de usuários (`slapcat`):**
  ```bash
  sudo slapcat -n 1 -l /backup/backup_dados_ldap.ldif
  ```

* **Backup da configuração dinâmica `cn=config`:**
  ```bash
  sudo slapcat -n 0 -l /backup/backup_config_ldap.ldif
  ```

* **Restauração Offline com `slapadd` (Procedimento Seguro de Recuperação):**
  ```bash
  # 1. Pare o serviço slapd obrigatoriamente:
  sudo systemctl stop slapd

  # 2. Limpe os arquivos antigos do banco de dados (faça backup antes se necessário):
  sudo rm -rf /var/lib/ldap/*

  # 3. Importe o arquivo LDIF:
  sudo slapadd -n 1 -l /backup/backup_dados_ldap.ldif

  # 4. Ajuste as permissões vitais do diretório:
  sudo chown -R openldap:openldap /var/lib/ldap/

  # 5. Inicie o serviço novamente:
  sudo systemctl start slapd
  ```

---

## 📄 8. Modelos de Arquivos LDIF (Prontos para Uso)

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
userPassword: <hash_ou_senha_aqui>
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

## 🐧 9. Validação no Cliente Linux (SSSD / PAM / NSS)

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
