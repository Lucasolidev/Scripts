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

### Atualizar o Kernel e o componente do WSL
```powershell
wsl --update
```

---

## 📊 2. Gerenciamento de Distribuições e Status

### Listar distribuições instaladas e versões em execução
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
```powershell
wsl --terminate Ubuntu
# ou
wsl -t Ubuntu
```

### Verificar o status global do WSL
```powershell
wsl --status
```

---

## 💾 4. Backup, Restauração e Exclusão de Distros (`.tar`)

### Criar backup (Exportar) de uma distro inteira
```powershell
wsl --export Ubuntu "D:\Backups\Ubuntu_Backup.tar"
```

### Restaurar (Importar) um backup em qualquer pasta do Windows
```powershell
wsl --import Ubuntu_Dev "D:\WSL\Ubuntu_Dev" "D:\Backups\Ubuntu_Backup.tar" --version 2
```

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
Crie o arquivo `C:\Users\SEU_USUARIO\.wslconfig` no Windows para impedir que o WSL consuma toda a memória RAM do computador:

```ini
[wsl2]
# Limite máximo de memória RAM
memory=4GB

# Número de núcleos de CPU
processors=4

# Tamanho do arquivo de troca (SWAP)
swap=2GB

# Permitir acesso a serviços rodando no WSL via localhost no Windows
localhostForwarding=true
```
*Após salvar o arquivo, rode `wsl --shutdown` no PowerShell para aplicar.*

### Habilitar o `systemctl` (Systemd) no WSL (`/etc/wsl.conf`)
Para conseguir rodar serviços com `systemctl start apache2` ou `systemctl start docker` dentro do WSL, edite o arquivo `/etc/wsl.conf` **dentro do Linux**:

```ini
[boot]
systemd=true

[automount]
options = "metadata,uid=1000,gid=1000,umask=022,fmask=111"
```
*Salve o arquivo e reinicie o WSL no PowerShell com `wsl --shutdown`.*

---

## 🌐 7. Acesso de Rede e Portas (`localhost`)

* **Navegador do Windows:** Qualquer servidor web (Nginx, Apache, Node.js, Vite) rodando na porta 3000, 80 ou 8080 dentro do WSL pode ser acessado direto no navegador do Windows digitando:
  `http://localhost:3000` ou `http://localhost:80`

* **Descobrir o IP interno do WSL:**
  ```bash
  hostname -I | awk '{print $1}'
  ```
