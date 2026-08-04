#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"

# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO ZSH - UBUNTU 26.04 (CORRIGIDO)
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_zsh.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh
#
# Executar via URL diretamente (exige sudo):
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh | sudo bash
# sudo bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh)
# sudo bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_zsh.sh | sudo bash
#
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

VERDE='\033[0;32m'
AMARELO='\033[1;33m'
PADRAO='\033[0m'

main() {
    clear
    echo "=================================================================="
    echo "  Configurando Terminal Zsh, Oh My Zsh e Temas"
    echo "=================================================================="
    
    # Se executado via pipe (ex: wget -qO- URL | bash), reconecta o STDIN ao terminal para permitir leitura interativa
    if [ ! -t 0 ] && [ -e /dev/tty ]; then
      exec 0</dev/tty
    fi

    # Valida o sudo logo no início da execução
    echo -e "${AMARELO}[!] Solicitando credenciais de administrador...${PADRAO}"
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    # Garante a existência do nala e dependências básicas de download logo no início
    echo -e "${VERDE}[*] Verificando e instalando dependências base...${PADRAO}"
    sudo apt-get update && sudo apt-get install -y nala curl git unzip

    # --- SESSÃO: SSH E FERRAMENTAS NATIVAS ---
    echo -e "\n${VERDE}[*] Instalando OpenSSH Server e HTOP...${PADRAO}"
    sudo nala install -y openssh-server htop
    sudo systemctl enable --now ssh

    # --- SESSÃO: FLATPAK E GOOGLE CHROME ---
    echo -e "\n${VERDE}[*] Instalando Flatpak, Plugin da Loja e Google Chrome...${PADRAO}"
    # CORREÇÃO: Adicionado o gnome-software-plugin-flatpak para integrar com a loja gráfica
    sudo nala install -y flatpak gnome-software-plugin-flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    echo -e "${VERDE}[*] Instalando Google Chrome via Flatpak...${PADRAO}"
    sudo flatpak install -y flathub com.google.Chrome

    # --- SESSÃO: CONFIGURAÇÃO DO ZSH ---
    export KEEP_ZSHRC=yes
    
    echo -e "\n${VERDE}[*] Instalando Zsh, fontes-powerline e fontes-firacode via Nala...${PADRAO}"
    sudo nala install -y zsh fonts-powerline

    # Muda o shell padrão de forma não interativa se necessário
    if [ "$SHELL" != "/bin/zsh" ]; then
        echo -e "${VERDE}[*] Alterando o shell padrão para Zsh...${PADRAO}"
        sudo chsh -s /bin/zsh $USER
    fi

    echo -e "${VERDE}[*] Instalando/Verificando Oh My Zsh...${PADRAO}"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

    echo -e "${VERDE}[*] Baixando o tema Powerlevel10k...${PADRAO}"
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi

    echo -e "${VERDE}[*] Clonando/Atualizando plugins do Zsh personalizados...${PADRAO}"
    mkdir -p "$ZSH_CUSTOM/plugins"
    [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ] && git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    [ ! -d "$ZSH_CUSTOM/plugins/history-search-multi-word" ] && git clone https://github.com/zdharma-continuum/history-search-multi-word.git "$ZSH_CUSTOM/plugins/history-search-multi-word"

    echo -e "${VERDE}[*] LIMPANDO E REESCREVENDO O ARQUIVO ~/.zshrc DO ZERO...${PADRAO}"
    
    cat << 'EOF' > ~/.zshrc
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Define o tema Agnoster como padrão estável
ZSH_THEME="agnoster"

# Lista definitiva de plugins (git, ufw e systemd foram removidos)
plugins=(
  copypath 
  copybuffer 
  history 
  colored-man-pages 
  sudo 
  zsh-autosuggestions 
  zsh-syntax-highlighting 
  zsh-completions 
  history-search-multi-word
)

# Carrega o Oh My Zsh
source $ZSH/oh-my-zsh.sh

# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===
# Ativar FPATH para o zsh-completions funcionar corretamente
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Alias para redirecionar Neofetch legado para o Fastfetch moderno
alias neofetch="fastfetch"

# Aliases para troca rápida de Layout de Teclado no Terminal / SSH (Wayland)
alias tc-br="gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'br'), ('xkb', 'us+intl')]\""
alias tc-us="gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us+intl'), ('xkb', 'br')]\""

# Função dinâmica para rodar qualquer script direto do seu repositório GitHub de forma ágil
load-script() {
    if [ -z "$1" ]; then
        echo "Uso: load-script nome_do_script.sh"
        return 1
    fi
    curl -fsSL "https://raw.githubusercontent.com/lucasolidev/scripts/main/$1" | bash
}
alias lucasolidev="load-script"

# Nota: Caso queira testar ou alternar para o Powerlevel10k no futuro,
# basta mudar a linha ZSH_THEME para: ZSH_THEME="powerlevel10k/powerlevel10k"
# === FIM DO BLOCO DO SCRIPT ===
EOF
    echo -e "${VERDE}[+] Arquivo ~/.zshrc gerado com sucesso!${PADRAO}"
    
    # Injeta os aliases também no bashrc, garantindo que o comando 'lucasolidev' funcione mesmo antes do primeiro reboot
    local BLOCO_BASH="
# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===
alias neofetch=\"fastfetch\"
alias tc-br=\"gsettings set org.gnome.desktop.input-sources sources \\\"[('xkb', 'br'), ('xkb', 'us+intl')]\\\"\"
alias tc-us=\"gsettings set org.gnome.desktop.input-sources sources \\\"[('xkb', 'us+intl'), ('xkb', 'br')]\\\"\"

load-script() {
    if [ -z \"\$1\" ]; then
        echo \"Uso: load-script nome_do_script.sh\"
        return 1
    fi
    curl -fsSL \"https://raw.githubusercontent.com/lucasolidev/scripts/main/\$1\" | bash
}
alias lucasolidev=\"load-script\"
# === FIM DO BLOCO DO SCRIPT ===
"
    sed -i '/# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===/,/# === FIM DO BLOCO DO SCRIPT ===/d' ~/.bashrc
    echo "$BLOCO_BASH" >> ~/.bashrc

    echo -e "\n${VERDE}[+] Ambiente Zsh e Softwares configurados com sucesso!${PADRAO}"
    echo -e "${AMARELO}[!] IMPORTANTE: Feche este terminal e abra uma nova janela para carregar o Zsh e ver o Chrome no menu gráfico.${PADRAO}"
}

main
