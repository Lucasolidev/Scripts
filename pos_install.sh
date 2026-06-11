#!/bin/bash

# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO AUTOMÁTICO E SEGURO - UBUNTU DESKTOP 26.04
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

VERDE='\033[0;32m'
AMARELO='\033[1;33m'
PADRAO='\033[0m'

echo "=================================================================="
echo "  Iniciando Instalação Automatizada - Ubuntu 26.04"
echo "=================================================================="

# Valida o sudo logo no início da execução para evitar travas
echo -e "${AMARELO}[!] Solicitando credenciais de administrador...${PADRAO}"
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ==============================================================================
# SEÇÃO 1: ATUALIZAÇÃO DO SISTEMA E GERENCIADOR NALA
# ==============================================================================
echo -e "\n${VERDE}[1/7] Atualizando repositórios e instalando dependências base...${PADRAO}"
sudo apt-get update
sudo apt-get install -y nala curl git unzip ncdu
sudo nala upgrade -y

# ==============================================================================
# SEÇÃO 2: SERVIÇOS E MONITOREAMENTO NATIVO (SSH E HTOP)
# ==============================================================================
echo -e "\n${VERDE}[2/7] Instalando OpenSSH Server e HTOP...${PADRAO}"
sudo nala install -y openssh-server htop
sudo systemctl enable --now ssh

# ==============================================================================
# SEÇÃO 3: INFO DO SISTEMA (FASTFETCH)
# ==============================================================================
echo -e "\n${VERDE}[3/7] Instalando Fastfetch (Sucessor do Neofetch)...${PADRAO}"
sudo nala install -y fastfetch

# ==============================================================================
# SEÇÃO 4: ECOSSISTEMA FLATPAK E GOOGLE CHROME
# ==============================================================================
echo -e "\n${VERDE}[4/7] Configurando Flatpak e instalando Google Chrome...${PADRAO}"
sudo nala install -y flatpak gnome-software-plugin-flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub com.google.Chrome

# ==============================================================================
# SEÇÃO 5: FONTE NERD FONT E POWERLINE (Para o Agnoster)
# ==============================================================================
echo -e "\n${VERDE}[5/7] Baixando e instalando Hack Nerd Font...${PADRAO}"
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/HackNerdFont-Regular.ttf \
    https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf
fc-cache -fv

# ==============================================================================
# SEÇÃO 6: EDITOR VIM E PERSONALIZAÇÃO DE PLUGINS
# ==============================================================================
echo -e "\n${VERDE}[6/7] Configurando e personalizando o editor Vim...${PADRAO}"
sudo nala install -y vim python3-pip
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

cat << 'EOF' > ~/.vimrc
" Seção de Plugins (vim-plug) """""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')
Plug 'sainnhe/sonokai'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'
Plug 'sheerun/vim-polyglot'
call plug#end()

" Global Sets """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax on
set nu
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smarttab
set smartindent
set hidden
set incsearch
set ignorecase
set smartcase
set scrolloff=8
set colorcolumn=100
set signcolumn=yes
set cmdheight=2
set updatetime=100
set encoding=utf-8
set nobackup
set nowritebackup
set splitright
set splitbelow
set autoread
set mouse=a
filetype on
filetype plugin on
filetype indent on

" Themes """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

let g:sonokai_style = 'andromeda'
let g:sonokai_enable_italic = 1
let g:sonokai_disable_italic_comment = 0
let g:sonokai_diagnostic_line_highlight = 1
let g:sonokai_current_word = 'bold'
colorscheme sonokai

if (has("nvim"))
    highlight Normal guibg=NONE ctermbg=NONE
    highlight EndOfBuffer guibg=NONE ctermbg=NONE
endif

" AirLine """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:airline_theme = 'sonokai'
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
EOF

# Instalação limpa e não-interativa dos plugins do Vim
vim -u NONE -N -e -s -c "source ~/.vimrc" -c "PlugInstall" -c "qa!"

# ==============================================================================
# SEÇÃO 7: CONFIGURAÇÃO DO SHELL ZSH E OH MY ZSH (Agnoster)
# ==============================================================================
echo -e "\n${VERDE}[7/7] Instalando e estruturando o Zsh (Tema Agnoster)...${PADRAO}"
sudo nala install -y zsh fonts-powerline

if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh -s /bin/zsh $USER
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/plugins"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ] && git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
[ ! -d "$ZSH_CUSTOM/plugins/history-search-multi-word" ] && git clone https://github.com/zdharma-continuum/history-search-multi-word.git "$ZSH_CUSTOM/plugins/history-search-multi-word"

# Reescreve o .zshrc garantindo a lista limpa de plugins pedida
cat << 'EOF' > ~/.zshrc
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

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

source $ZSH/oh-my-zsh.sh
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
EOF

# ==============================================================================
# SEÇÃO FINAL: ALIASES UNIVERSAIS E FUNÇÃO DINDÂMICA DO GITHUB
# ==============================================================================
echo -e "\n${VERDE}[*] Injetando aliases e a função do GitHub (Bash/Zsh)...${PADRAO}"

local BLOCO_CUSTOMIZACAO="
# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===
alias neofetch=\"fastfetch\"

load-script() {
    if [ -z \"\$1\" ]; then
        echo \"Uso: load-script nome_do_script.sh\"
        return 1
    fi
    curl -fsSL \"https://raw.githubusercontent.com/lucasolidev/linux/main/\$1\" | bash
}
alias lucasolidev=\"load-script\"
# === FIM DO BLOCO DO SCRIPT ===
"

# Injeta de forma limpa nos arquivos de perfil
sed -i '/# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===/,/# === FIM DO BLOCO DO SCRIPT ===/d' ~/.bashrc
echo "$BLOCO_CUSTOMIZACAO" >> ~/.bashrc

if [ -f "$HOME/.zshrc" ]; then
    sed -i '/# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===/,/# === FIM DO BLOCO DO SCRIPT ===/d' ~/.zshrc
    echo "$BLOCO_CUSTOMIZACAO" >> ~/.zshrc
fi

echo -e "\n${VERDE}[+] Todo o processo de pós-instalação foi concluído com sucesso!${PADRAO}"
echo -e "${AMARELO}[!] IMPORTANTE: Feche este terminal e abra um novo para carregar todo o seu ecossistema sem travas.${PADRAO}"
