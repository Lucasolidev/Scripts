# 🐧 Cheat Sheet - WSL (Windows Subsystem for Linux)

![WSL](https://img.shields.io/badge/WSL_2-0078D4?style=flat&logo=windows&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Windows 11](https://img.shields.io/badge/Windows_11-0078D4?style=flat&logo=windows11&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

Guia prático de referência rápida com os principais comandos, dicas de produtividade e configurações avançadas do **WSL 2** no Windows 10 e Windows 11.

---

## ⚡ 1. Instalação e Inicialização Rápida

> 💡 *Execute os comandos abaixo no **PowerShell** ou **Prompt de Comando** como Administrador.*

### Instalação em um único comando
Instala o WSL 2 e a distribuição padrão (Ubuntu):
```powershell
wsl --install
```

### Listar distribuições disponíveis na Microsoft Store
```powershell
wsl --list --online
# ou
wsl -l -o
```

### Instalar uma distribuição específica
```powershell
wsl --install -d Ubuntu-24.04
# ou
wsl --install -d Debian
```

### Criar uma SEGUNDA instância com outro nome (ex: Ubuntu-26-Dev)
Nas versões recentes do WSL, você pode passar a flag `--name` diretamente no comando:
```powershell
wsl --install -d Ubuntu-26.04 --name Ubuntu-26-Dev
```

### Atualizar o Kernel e o componente do WSL
```powershell
wsl --update
```

---

## 📊 2. Gerenciamento de Distribuições e Status

### Exibir versões detalhadas dos componentes (Kernel, WSLg, Windows)
```powershell
wsl --version
# ou
wsl -v
```

### Listar distribuições instaladas e estado de execução
```powershell
wsl --list --verbose
# ou
wsl -l -v
```

### Definir o WSL 2 como versão padrão para novas distros
```powershell
wsl --set-default-version 2
```

### Converter uma distro existente para WSL 2
```powershell
wsl --set-version Ubuntu 2
```

### Definir a distribuição padrão
```powershell
wsl --set-default Ubuntu
```

### Entrar na distro padrão como usuário ROOT
```powershell
wsl -u root
```

### Entrar em uma distro específica com um usuário específico
```powershell
wsl -d Debian -u usuario
```

### Executar um comando Linux direto do PowerShell (sem entrar no shell)
```powershell
wsl ls -la /var/www
```

---

## 🛑 3. Desligamento e Reinicialização do WSL

### Encerrar todas as distros e desligar a máquina virtual do WSL (Reinicio Limpo)
> 💡 *Útil quando o WSL consome muita memória RAM ou quando você altera configurações no `.wslconfig`.*
```powershell
wsl --shutdown
```

### Encerrar uma distribuição específica
Para parar uma distribuição específica sem desligar as outras, use o comando `--terminate` (ou `-t`):
```powershell
wsl --terminate NomeDaDistro
```

**Exemplos:**
* Parar apenas o Ubuntu-24.04:
  ```powershell
  wsl -t Ubuntu-24.04
  ```
* Parar apenas o Ubuntu-26.04:
  ```powershell
  wsl -t Ubuntu-26.04
  ```

### Verificar o status global do WSL
```powershell
wsl --status
```

---

## 💾 4. Backup, Restauração e Exclusão de Distros (`.tar` e `.vhdx`)

### Estrutura final deste guia

As imagens-base ficam separadas das instalações ativas. Assim, elas podem ser reutilizadas para criar ambientes de teste independentes:

```text
C:\WSL\
├── Ubuntu-26.04.vhdx          # imagem-base pronta
├── Ubuntu-24.04.vhdx          # imagem-base pronta
├── Ubuntu-26.04\              # distribuição principal importada
├── Ubuntu-24.04\              # distribuição importada
├── Ubuntu-26.04-Teste\        # criada somente quando necessário
├── Ubuntu-24.04-Teste\        # criada somente quando necessário
└── wsl-pass.txt               # credenciais solicitadas
```

> ⚠️ O arquivo `C:\WSL\wsl-pass.txt` armazena a senha em texto puro. O script restringe suas permissões ao usuário atual, ao `SYSTEM` e aos administradores, mas o ideal é usar uma senha exclusiva para essas VMs e não reutilizá-la em outros serviços.

### 1. Instalar as duas distribuições sem abrir a configuração interativa

```powershell
wsl --update
wsl --set-default-version 2
wsl --install -d Ubuntu-26.04 --no-launch
wsl --install -d Ubuntu-24.04 --no-launch
```

Se o Windows solicitar uma reinicialização, reinicie antes de continuar.

### 2. Atualizar, instalar o ShellCheck e criar o usuário

Repita os comandos para cada distribuição. O script `Implantacao_WSL.ps1` automatiza esta etapa sem exibir a senha no terminal.

```powershell
# Ubuntu 26.04
wsl -d Ubuntu-26.04 -u root -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get -y dist-upgrade; apt-get install -y sudo shellcheck"
wsl -d Ubuntu-26.04 -u root -- bash -lc "id -u administrador >/dev/null 2>&1 || useradd --create-home --shell /bin/bash administrador; usermod --append --groups sudo administrador; printf '[user]\ndefault=administrador\n' > /etc/wsl.conf"
"administrador:<SuaSenhaWSL>" | wsl -d Ubuntu-26.04 -u root -- chpasswd

# Ubuntu 24.04
wsl -d Ubuntu-24.04 -u root -- bash -lc "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get -y dist-upgrade; apt-get install -y sudo shellcheck"
wsl -d Ubuntu-24.04 -u root -- bash -lc "id -u administrador >/dev/null 2>&1 || useradd --create-home --shell /bin/bash administrador; usermod --append --groups sudo administrador; printf '[user]\ndefault=administrador\n' > /etc/wsl.conf"
"administrador:<SuaSenhaWSL>" | wsl -d Ubuntu-24.04 -u root -- chpasswd
```

Salvar as credenciais solicitadas:

```powershell
New-Item -ItemType Directory -Force "C:\WSL"
@'
Distribuicoes: Ubuntu-26.04, Ubuntu-24.04
Usuario: administrador
Senha: <SuaSenhaWSL>
'@ | Set-Content -Encoding utf8 "C:\WSL\wsl-pass.txt"

$identidadeAtual = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls "C:\WSL\wsl-pass.txt" /inheritance:r /grant:r "${identidadeAtual}:(F)" "*S-1-5-18:(F)" "*S-1-5-32-544:(F)"
```

### 3. Exportar as distribuições prontas como imagens-base

Desligue o WSL para garantir consistência e exporte somente depois de concluir as atualizações:

```powershell
wsl --shutdown

wsl --export Ubuntu-26.04 "C:\WSL\Ubuntu-26.04.vhdx" --vhd
wsl --export Ubuntu-24.04 "C:\WSL\Ubuntu-24.04.vhdx" --vhd
```

> 💡 O `--export` apenas cria os arquivos VHDX. As distribuições registradas ainda continuam no local padrão até a execução de `wsl --unregister`.

### Onde fica uma distribuição instalada pela Store?
Uma distribuição instalada com `wsl --install` é armazenada automaticamente pelo Windows no perfil do usuário. O local pode variar conforme a versão do WSL/Windows, normalmente em um destes formatos:

```text
%LOCALAPPDATA%\Packages\<pacote-da-distribuicao>\LocalState\ext4.vhdx
%LOCALAPPDATA%\wsl\{GUID}\ext4.vhdx
```

Não é recomendado depender desses caminhos internos. Para verificar o caminho real de cada distribuição instalada, execute:

```powershell
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*" |
  Select-Object DistributionName, BasePath
```

Para escolher o local da distro, use `wsl --import`. Neste guia, as imagens-base, as distribuições ativas e as cópias de teste ficam sob `C:\WSL`.

### Backup Físico Manual (Cópia direta do arquivo `ext4.vhdx`)
Como cada distribuição do WSL 2 fica armazenada em um único arquivo de disco virtual (`ext4.vhdx`), você pode fazer um "snapshot físico" copiando o arquivo diretamente:

1. **OBRIGATÓRIO:** Desligue o WSL para evitar corrupção de dados durante a cópia:
   ```powershell
   wsl --shutdown
   ```
2. **Descobrir a pasta onde o `ext4.vhdx` está salvo no Windows:**
   Execute no PowerShell:
   ```powershell
   Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*" | Select-Object DistributionName, BasePath
   ```
   > 📁 *Nas versões recentes do WSL 2 (Windows 11), o disco fica salvo em `%LOCALAPPDATA%\wsl\{GUID}\ext4.vhdx`.*

3. **Fazer o backup:** Copie o arquivo `ext4.vhdx` da pasta informada no `BasePath` para a sua pasta de backups ou HD externo.

### 4. Remover as instalações do local padrão e reimportar em `C:\WSL`

Confirme primeiro que os dois arquivos existem e têm tamanho maior que zero:

```powershell
Get-Item "C:\WSL\Ubuntu-26.04.vhdx", "C:\WSL\Ubuntu-24.04.vhdx" |
  Select-Object FullName, Length
```

> ⚠️ `wsl --unregister` apaga a instalação registrada e seus dados. Execute os comandos abaixo somente depois de validar os dois VHDX exportados.

```powershell
wsl --unregister Ubuntu-26.04
wsl --unregister Ubuntu-24.04

wsl --import Ubuntu-26.04 "C:\WSL\Ubuntu-26.04" "C:\WSL\Ubuntu-26.04.vhdx" --vhd
wsl --import Ubuntu-24.04 "C:\WSL\Ubuntu-24.04" "C:\WSL\Ubuntu-24.04.vhdx" --vhd

wsl --set-default Ubuntu-26.04
wsl --shutdown
```

As imagens `C:\WSL\Ubuntu-26.04.vhdx` e `C:\WSL\Ubuntu-24.04.vhdx` permanecem como bases reutilizáveis. As distribuições ativas passam a ser armazenadas nas pastas de mesmo nome.

### 5. Criar instâncias de teste a partir das imagens-base

Quando precisar testar alguma alteração, importe novas cópias independentes:

```powershell
wsl --import Ubuntu-26.04-Teste "C:\WSL\Ubuntu-26.04-Teste" "C:\WSL\Ubuntu-26.04.vhdx" --vhd
wsl --import Ubuntu-24.04-Teste "C:\WSL\Ubuntu-24.04-Teste" "C:\WSL\Ubuntu-24.04.vhdx" --vhd
```

Para iniciar as cópias:

```powershell
wsl -d Ubuntu-26.04-Teste
wsl -d Ubuntu-24.04-Teste
```

Para descartar e recriar uma cópia de teste limpa:

```powershell
wsl --unregister Ubuntu-26.04-Teste
wsl --import Ubuntu-26.04-Teste "C:\WSL\Ubuntu-26.04-Teste" "C:\WSL\Ubuntu-26.04.vhdx" --vhd
```

> ⚠️ O diretório informado no `wsl --import` precisa estar vazio ou não existir. Nunca use `--import-in-place` com as imagens-base: isso faria o WSL utilizar diretamente o VHDX que deve permanecer preservado.

### 6. Automatizar o processo com PowerShell

Execute o script em um **PowerShell como Administrador**, a partir da raiz do repositório `Scripts`:

```powershell
# Instalar, preparar, exportar, desregistrar e reimportar as bases
.\Implantacao_WSL.ps1

# Se as distribuições já existem e você quer prepará-las conscientemente
.\Implantacao_WSL.ps1 -UsarDistribuicoesExistentes

# Criar Ubuntu-26.04-Teste e Ubuntu-24.04-Teste quando necessário
.\Implantacao_WSL.ps1 -Modo CriarTestes
```

No modo de preparação, o script solicita e confirma a senha com `Read-Host -AsSecureString`; informe a senha definida para essas VMs. O valor não fica gravado no código-fonte, mas é salvo em `C:\WSL\wsl-pass.txt` conforme solicitado. Antes de desregistrar as instalações originais, o script exige que você digite `DESREGISTRAR`. A opção `-SemConfirmacao` existe para execução automatizada, mas deve ser usada somente quando os VHDX já tiverem sido validados.

Confira o resultado:

```powershell
wsl --list --verbose
wsl --status
wsl -d Ubuntu-26.04 -- whoami
wsl -d Ubuntu-26.04 -- shellcheck --version
```

Referências oficiais: [comandos básicos do WSL](https://learn.microsoft.com/windows/wsl/basic-commands) e [configurações do `.wslconfig` e `/etc/wsl.conf`](https://learn.microsoft.com/windows/wsl/wsl-config).

### Excluir / Desinstalar uma distribuição (⚠️ Ação Irreversível)
```powershell
wsl --unregister NomeDaDistro
```

---

## 🔥 5. Dicas de Ouro & Interoperabilidade (Windows + Linux)

### Acessar arquivos do Windows a partir do Linux
As partições do Windows são montadas automaticamente em `/mnt/`:
```bash
cd /mnt/c/Users/SEU_USUARIO/Desktop
cd /mnt/d/Projetos_WEB
```

### Acessar arquivos do Linux no Windows Explorer
* **Abrir a pasta atual do WSL direto no Windows Explorer:**
  ```bash
  explorer.exe .
  ```
* **Navegar pelas distros pelo caminho de rede no Windows:**
  Pressione `Win + R` e digite:
  `\\wsl$\` ou `\\wsl.localhost\`

### Abrir o VS Code diretamente do terminal WSL
```bash
code .
```

### Copiar a saída de um comando Linux direto para a Área de Transferência do Windows
```bash
cat ~/.ssh/id_rsa.pub | clip.exe
```

### Executar executáveis do Windows a partir do Linux
```bash
# Exibir configurações de IP do Windows
ipconfig.exe

# Abrir o Bloco de Notas do Windows
notepad.exe arquivo.txt
```

---

## ⚙️ 6. Configurações Avançadas e Limite de Recursos

### Limitar Memória RAM e CPUs (`.wslconfig`)
O WSL 2 pode consumir muita memória RAM se não for limitado. Crie o arquivo `C:\Users\SEU_USUARIO\.wslconfig` no Windows.

#### Criar o arquivo `.wslconfig` direto pelo PowerShell:
```powershell
# Executar no PowerShell para criar o arquivo com limites de memória e desativar desligamento automático:
@'
[wsl2]
memory=2GB
processors=2
swap=512MB
localhostForwarding=true
vmIdleTimeout=600000
'@ | Out-File -Encoding utf8 "$env:USERPROFILE\.wslconfig"

# Conferir o conteúdo criado:
Get-Content "$env:USERPROFILE\.wslconfig"

# Abrir no Bloco de Notas caso queira editar manualmente:
notepad "$env:USERPROFILE\.wslconfig"

# Aplicar as mudanças (OBRIGATÓRIO reiniciar a VM do WSL):
wsl --shutdown
```

### ⏰ Ajustar ou Desativar o Tempo de Desligamento Automático (`vmIdleTimeout`)
Por padrão, o WSL 2 encerra a máquina virtual automaticamente após **60 segundos (1 minuto)** de inatividade (sem janelas ativas do terminal). 

Para alterar esse comportamento, edite o arquivo `C:\Users\SEU_USUARIO\.wslconfig`:

```ini
[wsl2]
# Opção A: Desativar completamente o desligamento automático por inatividade
vmIdleTimeout=-1

# Opção B: Aumentar o tempo limite (valor em milissegundos. Ex: 600000 = 10 minutos)
vmIdleTimeout=600000
```
> 💡 *Após alterar o arquivo, lembre-se de rodar `wsl --shutdown` no PowerShell para aplicar.*

### Habilitar o `systemctl` (Systemd) e Opções do WSL (`/etc/wsl.conf`)
Para habilitar o `systemctl` e configurar como o Linux interage com o Windows, edite o arquivo `/etc/wsl.conf` **dentro do Linux** (`sudo nano /etc/wsl.conf`):

```ini
[boot]
systemd=true

[automount]
options = "metadata,uid=1000,gid=1000,umask=022,fmask=111"
```
*Salve o arquivo e reinicie o WSL no PowerShell com `wsl --shutdown`.*

### 🛡️ Isolar o WSL (Desativar Montagem Automática das Unidades `/mnt/c`)
Por padrão, todas as unidades do Windows (`C:\`, `D:\`, etc.) são montadas automaticamente em `/mnt/`. Para aumentar a segurança e isolar o Linux do Windows:

1. No arquivo `/etc/wsl.conf` **dentro do Linux** (`sudo nano /etc/wsl.conf`), desative a montagem e impeça que o Linux tente importar variáveis do Windows:
   ```ini
   [boot]
   systemd=true

   [automount]
   enabled = false

   [interop]
   enabled = true
   appendWindowsPath = false
   ```
   > ⚠️ **Atenção sobre os efeitos colaterais:**
   > - **Alertas `Failed to translate 'C:\...'`:** Ocorrem se `appendWindowsPath` continuar `true` sem o `/mnt/c` montado. Definir `appendWindowsPath = false` remove esses avisos.
   > - **MobaXterm / VS Code:** A integração nativa do MobaXterm e do VS Code depende do `/mnt/c/` para funcionar. Se desativar o `automount`, o MobaXterm precisará conectar via **SSH tradicional** (`sudo service ssh start`).

2. No PowerShell do Windows, reinicie o WSL para aplicar:
   ```powershell
   wsl --shutdown
   ```

#### Mapear Apenas Uma Pasta Específica do Windows
Com a montagem automática desativada, você pode liberar o acesso a **apenas uma pasta escolhida** (ex: `D:\MeusProjetos`):
```bash
# 1. Criar o diretório de destino no Linux
sudo mkdir -p /mnt/projetos

# 2. Montar apenas a pasta desejada
sudo mount -t drvfs 'D:\MeusProjetos' /mnt/projetos
```
> 💡 *Para montar essa pasta automaticamente ao iniciar o Linux, adicione a linha abaixo no arquivo `/etc/fstab`:*
> `D:\MeusProjetos  /mnt/projetos  drvfs  defaults  0  0`

#### 📡 Conectar o MobaXterm via SSH (quando `automount = false`)
Com a montagem automática desativada, a sessão nativa do MobaXterm não funcionará. Para utilizar o MobaXterm neste modo isolado, conecte via **SSH**:

1. **Instalar, iniciar e habilitar o servidor SSH no Linux:**
   ```bash
   # Instalar o OpenSSH Server
   sudo apt update && sudo apt install -y openssh-server

   # Iniciar e habilitar o serviço de SSH (para iniciar com o sistema)
   sudo systemctl start ssh
   sudo systemctl enable ssh
   ```
   > 💡 *Para conferir se o serviço está ativo, rode `systemctl status ssh`. Deve exibir em verde: `Active: active (running)`.*

2. **Criar a Conexão SSH no MobaXterm:**
   - No MobaXterm, clique em **Session** -> **SSH**.
   - **Remote host:** `localhost` (ou `127.0.0.1`)
   - **Specify username:** marque a opção e digite seu usuário (ex: `administrador`)
   - **Port:** `22`
   - Clique em **OK**.


---

## 🌐 7. Acesso de Rede e Portas (`localhost`)

* **Navegador do Windows:** Qualquer servidor web (Nginx, Apache, Node.js, Vite) rodando na porta 3000, 80 ou 8080 dentro do WSL pode ser acessado direto no navegador do Windows digitando:
  `http://localhost:3000` ou `http://localhost:80`

* **Descobrir o IP interno do WSL:**
  - **Executando dentro do Linux (Bash):**
    ```bash
    hostname -I | awk '{print $1}'
    ```
  - **Executando pelo PowerShell do Windows:**
    ```powershell
    wsl hostname -I
    ```

---

## ❓ 8. Perguntas Frequentes (FAQ)

### O WSL liga sozinho o container ao iniciar o Windows?
* **Não por padrão (Início Sob Demanda):** O WSL não consome memória RAM nem CPU assim que o Windows liga. Ele permanece inativo até o momento em que você abre um terminal (Windows Terminal, PowerShell com `wsl`, VS Code) ou quando uma ferramenta inicia.
* **Exceção (Docker Desktop):** Se o **Docker Desktop** estiver instalado e configurado para *"Start Docker Desktop when you log in"*, ele acordará o WSL 2 automaticamente no login do Windows para disponibilizar os containers Docker.
* **Como desligar manualmente:** Sempre que quiser liberar toda a memória RAM reservada pelo WSL, abra o PowerShell e execute:
  ```powershell
  wsl --shutdown
  ```

### Se pegar vírus dentro do WSL, infecta o meu Windows?
* **Isolamento de Sistema:** O Linux roda dentro de um disco virtual isolado (`.vhdx`). Um vírus de Linux não consegue danificar o Kernel do Windows ou alterar o Registro do Windows.
* **Atenção aos arquivos compartilhados:** Como os discos do Windows costumam ser montados em `/mnt/c/`, scripts maliciosos rodando no Linux podem alterar arquivos das suas pastas pessoais do Windows caso tenham acesso.
* **Solução:** Se quiser isolar 100%, desative a montagem automática (`enabled = false` no `/etc/wsl.conf`) conforme demonstrado na seção 6.

### Por que o WSL desliga sozinho após 1 minuto de inatividade?
* **Motivo:** O WSL 2 vem com o parâmetro `vmIdleTimeout=60000` (60 segundos em milissegundos) ativado por padrão para liberar memória RAM do Windows quando o terminal é fechado.
* **Solução:** No arquivo `C:\Users\SEU_USUARIO\.wslconfig`, adicione:
  * `vmIdleTimeout=-1` para **nunca** desligar por inatividade.
  * `vmIdleTimeout=600000` para aumentar a tolerância para **10 minutos** (ou outro valor em milissegundos).
* Depois de salvar o arquivo, execute `wsl --shutdown` no PowerShell para aplicar.

