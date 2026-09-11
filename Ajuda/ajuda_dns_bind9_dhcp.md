# 🌐 Cheat Sheet - Servidores DNS (BIND9) e DHCP (ISC-DHCP-Server) no Linux

![DNS](https://img.shields.io/badge/DNS-BIND9-blue?style=flat&logo=cloudflare&logoColor=white)
![DHCP](https://img.shields.io/badge/DHCP-ISC--DHCP-orange?style=flat)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia prático e comandos essenciais para implementação e troubleshooting de servidores de rede **DNS (BIND9 / Named)** e **DHCP (ISC-DHCP-Server)** no Linux: arquivos de zona direta e reversa, checagem de sintaxe (`named-checkconf`, `named-checkzone`), escopos de distribuição de IP, reservas por MAC e diagnóstico de concessões.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave

| Serviço | Caminho / Arquivo | Descrição |
| :--- | :--- | :--- |
| **BIND9** | `/etc/bind/named.conf` | Arquivo principal que inclui os demais arquivos de configuração. |
| **BIND9** | `/etc/bind/named.conf.options` | Opções globais de escuta, recursão e forwarders (DNS upstream). |
| **BIND9** | `/etc/bind/named.conf.local` | Declaração de zonas locais (zonas diretas e reversas). |
| **BIND9** | `/etc/bind/db.<zona>` | Arquivo de mapeamento de registros da zona direta ou reversa. |
| **DHCP** | `/etc/default/isc-dhcp-server` | Define em qual(is) placa(s) de rede física o servidor DHCP escutará. |
| **DHCP** | `/etc/dhcp/dhcpd.conf` | Arquivo principal de escopos, faixas de IP (ranges), gateways e reservas. |
| **DHCP** | `/var/lib/dhcp/dhcpd.leases` | Base com o histórico e concessões ativas distribuídas aos clientes. |

---

## 🌐 SERVIDOR DNS (BIND9)

### ⚙️ 2. Gerenciamento do Serviço e Validação Prévia

> ⚠️ **MANDATÓRIO:** Nunca reinicie o serviço BIND sem antes checar a sintaxe dos arquivos para não derrubar a resolução de nomes da rede!

```bash
# 1. Validar sintaxe global dos arquivos named.conf (se não retornar nada, está perfeito):
sudo named-checkconf

# 2. Validar sintaxe e integridade de um arquivo de zona específica:
sudo named-checkzone empresa.local /etc/bind/db.empresa.local
sudo named-checkzone 1.168.192.in-addr.arpa /etc/bind/db.192.168.1

# 3. Status, reinício ou recarga graciosa das zonas:
sudo systemctl status named   # ou bind9
sudo systemctl reload named   # Recarrega zonas sem derrubar o processo
sudo systemctl restart named
```

---

### 📝 3. Declaração de Zonas no `/etc/bind/named.conf.local`

Adicione as diretivas da sua zona direta e da zona reversa:

```text
// Zona Direta (Nome -> IP)
zone "empresa.local" {
    type master;
    file "/etc/bind/db.empresa.local";
    allow-transfer { none; }; // Em produção, colocar IP do DNS escravo
};

// Zona Reversa para rede 192.168.1.0/24 (IP -> Nome)
zone "1.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.1";
    allow-transfer { none; };
};
```

---

### 📄 4. Modelos Prontos de Arquivos de Zona

#### 🅰️ Zona Direta: `/etc/bind/db.empresa.local`
```text
$TTL    604800
@       IN      SOA     ns1.empresa.local. admin.empresa.local. (
                              2         ; Serial (incrementar sempre que alterar!)
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
; Servidores de Nome (NS)
@       IN      NS      ns1.empresa.local.

; Registros A (Hostnames para IP)
ns1     IN      A       192.168.1.10
srv01   IN      A       192.168.1.20
router  IN      A       192.168.1.1

; Apelidos (CNAME)
www     IN      CNAME   srv01
mail    IN      CNAME   srv01

; Registro de Servidor de E-mail (MX)
@       IN      MX  10  srv01.empresa.local.
```

#### 🔄 Zona Reversa: `/etc/bind/db.192.168.1`
```text
$TTL    604800
@       IN      SOA     ns1.empresa.local. admin.empresa.local. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
; Servidor de Nome
@       IN      NS      ns1.empresa.local.

; Ponteiros Reversos (PTR) - Último octeto do IP
10      IN      PTR     ns1.empresa.local.
20      IN      PTR     srv01.empresa.local.
1       IN      PTR     router.empresa.local.
```

---

### 🔍 5. Testes de Resolução DNS com `dig`, `nslookup` e `host`

```bash
# Testar resolução direta apontando para o servidor local:
dig @127.0.0.1 srv01.empresa.local

# Testar resposta curta rápida:
dig @127.0.0.1 srv01.empresa.local +short

# Testar resolução reversa:
dig @127.0.0.1 -x 192.168.1.20 +short

# Teste clássico com nslookup:
nslookup srv01.empresa.local 127.0.0.1
```

---

## 📡 SERVIDOR DHCP (ISC-DHCP-SERVER)

### ⚙️ 6. Gerenciamento do Serviço e Interface de Escuta

1. **Definir a interface física de rede em `/etc/default/isc-dhcp-server`:**
   ```text
   INTERFACESv4="eth0"
   ```

2. **Validar sintaxe do arquivo de configuração (MANDATÓRIO):**
   ```bash
   sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
   ```

3. **Status e controle do serviço:**
   ```bash
   sudo systemctl status isc-dhcp-server
   sudo systemctl restart isc-dhcp-server
   ```

---

### 📋 7. Configuração de Escopo e Reserva Estática (`/etc/dhcp/dhcpd.conf`)

Edite `/etc/dhcp/dhcpd.conf`:

```text
# Parâmetros Globais
default-lease-time 600;
max-lease-time 7200;
authoritative; # Declara este servidor como oficial da rede

# Subrede e Escopo de Distribuição de IPs
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;                # Faixa dinâmica
    option routers 192.168.1.1;                         # Gateway Padrão
    option subnet-mask 255.255.255.0;
    option domain-name-servers 192.168.1.10, 8.8.8.8;  # Servidores DNS
    option domain-name "empresa.local";                 # Sufixo de domínio
    option broadcast-address 192.168.1.255;
}

# Reserva de IP Fixo por Endereço MAC (Static Lease)
host impressora-ti {
    hardware ethernet 00:11:22:33:44:55;
    fixed-address 192.168.1.50;
}

host diretoria-laptop {
    hardware ethernet AA:BB:CC:DD:EE:FF;
    fixed-address 192.168.1.55;
}
```

---

### 📊 8. Diagnóstico de Concessões e Logs do DHCP

* **Verificar concessões (leases) ativas distribuídas no momento:**
  ```bash
  cat /var/lib/dhcp/dhcpd.leases
  ```

* **Acompanhar a negociação DHCP em tempo real (D.O.R.A. - Discover, Offer, Request, Ack):**
  ```bash
  sudo journalctl -u isc-dhcp-server -f
  # Ou via syslog:
  sudo grep -i dhcpd /var/log/syslog | tail -n 30
  ```

---

## 🛡️ 9. Portas de Firewall para DNS e DHCP

```bash
# Liberar DNS (Porta 53 TCP e UDP):
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Liberar DHCP Server (Porta 67 UDP vindo de clientes porta 68 UDP):
sudo ufw allow 67/udp
```
