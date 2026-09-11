# 🔐 Cheat Sheet - Servidor de Autenticação FreeRADIUS no Linux

![FreeRADIUS](https://img.shields.io/badge/RADIUS-FreeRADIUS_3-blue?style=flat&logo=auth0&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Security](https://img.shields.io/badge/Security-informational?style=flat&logo=auth0&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia de sobrevivência e comandos práticos para configuração, homologação e diagnóstico do **FreeRADIUS 3** no Linux: cadastro de clientes NAS (switches, roteadores, Wi-Fi), criação de usuários de teste, execução em modo debug (`freeradius -X`) e validação de autenticação com `radtest`.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/etc/freeradius/3.0/radiusd.conf` | Arquivo principal de inicialização, portas e inclusões de módulos. |
| `/etc/freeradius/3.0/clients.conf` | Cadastro de equipamentos clientes NAS (IPs autorizados e *shared secrets*). |
| `/etc/freeradius/3.0/users` | Base de autenticação local de usuários (ou link para `mods-config/files/authorize`). |
| `/etc/freeradius/3.0/mods-enabled/` | Módulos ativos (ex: `ldap`, `sql`, `eap`, `files`). |
| `/var/log/freeradius/radius.log` | Arquivo de log principal com eventos de autenticação e falhas. |

---

## ⚙️ 2. Gerenciamento do Serviço e Teste em Modo Debug

### Controle Normal via Systemd
```bash
# Verificar status do serviço
sudo systemctl status freeradius

# Reiniciar o serviço
sudo systemctl restart freeradius
```

### 🐞 O Segredo de Ouro para Provas: Modo Debug (`freeradius -X`)
> 💡 *Em provas práticas ou diagnósticos difíceis, **NUNCA** depure o FreeRADIUS pelos arquivos de log do systemd. Pare o serviço e rode no terminal em modo debug:*

```bash
# 1. Pare o serviço em segundo plano:
sudo systemctl stop freeradius

# 2. Inicie o processo em primeiro plano com debug verboso total:
sudo freeradius -X
```
*O terminal exibirá todo o carregamento de configurações, dicionários e cada pacote RADIUS recebido detalhando o porquê de um `Access-Accept` ou `Access-Reject`.*  
*(Para sair do modo debug, basta pressionar `Ctrl + C` e depois reiniciar com `sudo systemctl start freeradius`).*

---

## 📡 3. Cadastro de Clientes NAS (`/etc/freeradius/3.0/clients.conf`)

Equipamentos de rede (Access Points, Switches, VPNs) que consultarão o FreeRADIUS devem ser declarados com seu IP e uma senha compartilhada (*secret*):

```text
# Exemplo 1: Cliente Localhost (Geralmente já vem pré-configurado para testes locais)
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
}

# Exemplo 2: Roteador / Switch / Access Point específico da rede
client switch-core {
    ipaddr = 192.168.1.1
    secret = <segredo_compartilhado_switch>
    shortname = SwitchCoreTI
}

# Exemplo 3: Subrede inteira de equipamentos de rede
client rede-wifi-corp {
    ipaddr = 192.168.10.0/24
    secret = <segredo_compartilhado_wifi>
    shortname = RedeWifiCorp
}
```

---

## 👤 4. Cadastro de Usuários de Autenticação Local (`/etc/freeradius/3.0/users`)

Edite `/etc/freeradius/3.0/users` (ou `/etc/freeradius/3.0/mods-config/files/authorize`):

```text
# Usuário de Teste com Senha em Texto Claro
usuario_teste Cleartext-Password := "<senha_do_usuario>"
    Reply-Message = "Autenticacao realizada com sucesso!"

# Usuário com restrições ou parâmetros de VLAN (se solicitado na prova)
analista_ti Cleartext-Password := "<senha_ti_123>"
    Tunnel-Type = VLAN,
    Tunnel-Medium-Type = IEEE-802,
    Tunnel-Private-Group-Id = "10"
```

---

## 🧪 5. Testes de Autenticação com `radtest`

O comando `radtest` simula um equipamento cliente enviando uma solicitação de login para o FreeRADIUS:

### Sintaxe do Comando
```bash
radtest <login> <senha> <ip_radius> <porta_nas> <secret>
```

### Exemplos de Execução
* **Testar o usuário local no localhost usando a secret padrão `testing123`:**
  ```bash
  radtest usuario_teste '<senha_do_usuario>' 127.0.0.1 0 testing123
  ```

* **Testar um servidor RADIUS em outro IP na rede:**
  ```bash
  radtest usuario_teste '<senha_do_usuario>' 192.168.1.10 0 <segredo_compartilhado>
  ```

### Interpretação dos Resultados
* ✅ **`Received Access-Accept`**: Autenticação aprovada! O usuário e senha estão corretos e o cliente NAS está autorizado.
* ❌ **`Received Access-Reject`**: Falha de login! Senha errada, usuário inexistente ou atributos recusados.
* 🛑 **`radclient: no response from server`**: Problema de rede, firewall bloqueando a porta UDP 1812 ou *secret* incorreta no `clients.conf`.

---

## 🛡️ 6. Portas de Rede e Firewall (UFW)

O FreeRADIUS utiliza o protocolo **UDP**:

```bash
# Liberar porta 1812 UDP (Autenticação)
sudo ufw allow 1812/udp

# Liberar porta 1813 UDP (Accounting / Contabilização de Sessões)
sudo ufw allow 1813/udp
```
