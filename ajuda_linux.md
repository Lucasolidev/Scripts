# 🐧 Cheat Sheet - Administração Linux (Ubuntu Server)

## 👤 Gerenciamento de Usuários e Grupos

### Listar todos os usuários do sistema
```bash
cut -d: -f1 /etc/passwd
```

### Listar usuários com acesso sudo
```bash
getent group sudo
```

### Criar um novo usuário com pasta home
```bash
sudo adduser nome_usuario
```

### Adicionar usuário existente ao grupo sudo
```bash
sudo usermod -aG sudo nome_usuario
```

### Bloquear login por senha para um usuário específico
```bash
sudo usermod -L nome_usuario
```

## 🔐 SSH & Segurança

### Testar alterações no sshd_config antes de reiniciar
```bash
sudo sshd -t
```

### Reiniciar o serviço SSH com segurança
```bash
sudo systemctl restart ssh
```

### Ativar o firewall local UFW
```bash
sudo ufw enable
```

### Liberar porta SSH no UFW
```bash
sudo ufw allow 22/tcp
```

### Ver status do UFW com detalhes
```bash
sudo ufw status verbose
```

### Ajustar permissões rígidas da pasta e chaves SSH do usuário
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## 💾 Aumento de Armazenamento - Partição Simples (EXT4)

### 1. Verificar montagens atuais
```bash
df -hT
```

### 2. Forçar o Kernel a reconhecer o novo tamanho do disco (ex: sdc)
```bash
echo 1 > /sys/class/block/sdc/device/rescan
```

### 3. Confirmar se o disco principal cresceu no lsblk
```bash
lsblk
```

### 4. Instalar ferramenta de expansão de partição
```bash
apt update && apt install -y cloud-guest-utils
```

### 5. Expandir a partição 1 do disco target (Substitua sdX pelo seu disco)
```bash
growpart /dev/sdX 1
```

### 6. Redimensionar o sistema de arquivos ext4
```bash
resize2fs /dev/sdX1
```

### 7. Confirmar novo espaço
```bash
df -hT
```

## 📦 Aumento de Armazenamento - Volume Lógico (LVM)

### Expandir o Logical Volume (LV) + Sistema de Arquivos em um único comando
```bash
lvextend -r -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```

### Caso a partição física (PV) precise ser re-escaneada antes
```bash
pvresize /dev/sdX1
```

## 📊 Diagnóstico de Rede & Portas

### Ver conexões ativas e portas escutando (substituto moderno do netstat)
```bash
ss -tulpn
```

### Testar se uma porta remota está aberta (ex: teste de NAT/Firewall)
```bash
nc -zv 187.32.48.193 35222
```

### Ver IP local das interfaces
```bash
ip a
```

## 🧹 Limpeza & Espaço em Disco

### Ver quais arquivos/pastas estão consumindo mais espaço no diretório atual
```bash
du -h --max-depth=1 | sort -hr
```

### Limpar cache de pacotes antigos do APT
```bash
sudo apt autoremove --purge && sudo apt clean
```

### Ver logs do sistema ocupando espaço e limpar logs antigos
```bash
journalctl --disk-usage
sudo journalctl --vacuum-time=3d
```

## 🚀 Processos & Monitoramento

### Monitor interativo de CPU e RAM
```bash
htop
```

### Ver logs em tempo real de um serviço (ex: SSH)
```bash
sudo journalctl -u ssh -f -n 50
```
