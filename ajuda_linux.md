#🐧 Cheat Sheet - Administração Linux (Ubuntu Server)
#👤 Gerenciamento de Usuários e Grupos

### Listar todos os usuários do sistema
cut -d: -f1 /etc/passwd

## Listar usuários com acesso sudo
getent group sudo

## Criar um novo usuário com pasta home
sudo adduser nome_usuario

## Adicionar usuário existente ao grupo sudo
sudo usermod -aG sudo nome_usuario

## Bloquear login por senha para um usuário específico
sudo usermod -L nome_usuario

#🔐 SSH & Segurança

## Testar alterações no sshd_config antes de reiniciar
sudo sshd -t

## Reiniciar o serviço SSH com segurança
sudo systemctl restart ssh

## Ativar o firewall local UFW
sudo ufw enable

## Liberar porta SSH no UFW
sudo ufw allow 22/tcp

## Ver status do UFW com detalhes
sudo ufw status verbose

## Ajustar permissões rígidas da pasta e chaves SSH do usuário
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

#💾 Aumento de Armazenamento - Partição Simples (EXT4)

## 1. Verificar montagens atuais
df -hT

## 2. Forçar o Kernel a reconhecer o novo tamanho do disco (ex: sdc)
echo 1 > /sys/class/block/sdc/device/rescan

## 3. Confirmar se o disco principal cresceu no lsblk
lsblk

# 4. Instalar ferramenta de expansão de partição
apt update && apt install -y cloud-guest-utils

# 5. Expandir a partição 1 do disco target (Substitua sdX pelo seu disco)
growpart /dev/sdX 1

# 6. Redimensionar o sistema de arquivos ext4
resize2fs /dev/sdX1

# 7. Confirmar novo espaço
df -hT
📦 Aumento de Armazenamento - Volume Lógico (LVM)
Bash
# Expandir o Logical Volume (LV) + Sistema de Arquivos em um único comando
lvextend -r -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv

# Caso a partição física (PV) precise ser re-escaneada antes
pvresize /dev/sdX1
📊 Diagnóstico de Rede & Portas
Bash
# Ver conexões ativas e portas escutando (substituto moderno do netstat)
ss -tulpn

# Testar se uma porta remota está aberta (ex: teste de NAT/Firewall)
nc -zv 187.32.48.193 35222

# Ver IP local das interfaces
ip a
🧹 Limpeza & Espaço em Disco
Bash
# Ver quais arquivos/pastas estão consumindo mais espaço no diretório atual
du -h --max-depth=1 | sort -hr

# Limpar cache de pacotes antigos do APT
sudo apt autoremove --purge && sudo apt clean

# Ver logs do sistema ocupando espaço e limpar logs antigos
journalctl --disk-usage
sudo journalctl --vacuum-time=3d
🚀 Processos & Monitoramento
Bash
# Monitor interativo de CPU e RAM
htop

# Ver logs em tempo real de um serviço (ex: SSH)
sudo journalctl -u ssh -f -n 50
