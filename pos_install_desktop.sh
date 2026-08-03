#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO AUTOMÁTICO E SEGURO - UBUNTU DESKTOP 26.04
# ==============================================================================
# Execução recomendada via repositório: lucasolidev pos_install_desktop.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh
#
# Executar via URL
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/pos_install_desktop.sh | bash
#
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# ==========================================
# PALETA DE CORES (ANSI ESCAPE CODES)
# ==========================================
NC='\033[0m'              # Reset (Sem Cor)
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

# Cores de Fonte (Foreground)
FG_BLACK='\033[30m'
FG_RED='\033[31m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_BLUE='\033[34m'
FG_MAGENTA='\033[35m'
FG_CYAN='\033[36m'
FG_WHITE='\033[37m'

# Símbolos Customizados
ARROW="❯"

# ==========================================
# FUNÇÕES DE HIGHLIGHT E LOGGING
# ==========================================

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
}

get_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${FG_GREEN}Ativo${NC}"
    else
        echo -e "${FG_YELLOW}Inativo${NC}"
    fi
}

log_info() {
    echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"
}

log_success() {
    echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"
}

log_warning() {
    echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"
}

log_error() {
    echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"
}

print_alert_box() {
    local msg="$1"
    echo -e ""
    echo -e "  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}"
    echo -e ""
}

# ==============================================================================
# INÍCIO DO SCRIPT
# ==============================================================================

clear

echo -e "\n${FG_CYAN}${BOLD}================================================================${NC}"
echo -e "${FG_CYAN}${BOLD}       SYSTEM MANAGER - PÓS-INSTALAÇÃO DO UBUNTU DESKTOP        ${NC}"
echo -e "${FG_CYAN}${BOLD}================================================================${NC}"

# Valida o sudo logo no início da execução para evitar travas
log_warning "Solicitando credenciais de administrador..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ==============================================================================
# 1. ATUALIZAÇÃO DO SISTEMA E DEPENDÊNCIAS BASE
# ==============================================================================
print_header "ATUALIZAÇÃO DO SISTEMA E GERENCIADOR NALA"

log_info "Atualizando repositórios e instalando dependências base..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y nala curl git unzip ncdu locales > /dev/null 2>&1
sudo nala upgrade -y > /dev/null 2>&1
log_success "Repositórios atualizados e pacotes base instalados."

# ==============================================================================
# 2. CONFIGURAÇÃO DE LOCALES (UTF-8) E TECLADO
# ==============================================================================
print_header "CONFIGURAÇÃO DE LOCALES (UTF-8) E TECLADO"

log_info "Configurando suporte completo a UTF-8 (en_US.UTF-8 e pt_BR.UTF-8)..."
sudo sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen en_US.UTF-8 pt_BR.UTF-8 > /dev/null 2>&1
sudo update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8 > /dev/null 2>&1
log_success "Locales UTF-8 gerados com sucesso."

log_info "Configurando layouts de teclado (US-International com Acentos + ABNT2)..."
sudo cat <<EOF | sudo tee /etc/default/keyboard > /dev/null
XKBMODEL="pc105"
XKBLAYOUT="us,br"
XKBVARIANT="intl,"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

sudo setupcon --force > /dev/null 2>&1 || true

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl'), ('xkb', 'br')]" 2>/dev/null || true
fi
log_success "Teclado configurado: US-International + ABNT2 (Alterna com Alt+Shift)."

# ==============================================================================
# 3. INSTALAÇÃO DE SERVIÇOS E FERRAMENTAS BASE (SSH E HTOP)
# ==============================================================================
print_header "SERVIÇOS E MONITORAMENTO (SSH E HTOP)"

log_info "Instalando OpenSSH Server e HTOP..."
sudo nala install -y openssh-server htop > /dev/null 2>&1
sudo systemctl enable --now ssh > /dev/null 2>&1
log_success "OpenSSH Server e HTOP instalados e ativos."

# ==============================================================================
# 4. INFORMAÇÕES DO SISTEMA (FASTFETCH)
# ==============================================================================
print_header "INFORMAÇÕES DO SISTEMA (FASTFETCH)"

log_info "Instalando Fastfetch..."
sudo nala install -y fastfetch > /dev/null 2>&1
log_success "Fastfetch instalado com sucesso."

# ==============================================================================
# 5. ECOSSISTEMA FLATPAK E GOOGLE CHROME
# ==============================================================================
print_header "ECOSSISTEMA FLATPAK E GOOGLE CHROME"

log_info "Configurando Flatpak e repositório Flathub..."
sudo nala install -y flatpak gnome-software-plugin-flatpak > /dev/null 2>&1
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1

log_info "Instalando Google Chrome via Flatpak..."
sudo flatpak install -y flathub com.google.Chrome > /dev/null 2>&1
log_success "Flatpak e Google Chrome configurados com sucesso."

# ==============================================================================
# 6. FONTE NERD FONT E POWERLINE
# ==============================================================================
print_header "INSTALAÇÃO DE FONTE NERD FONT"

log_info "Baixando e instalando Hack Nerd Font..."
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/HackNerdFont-Regular.ttf \
    https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf > /dev/null 2>&1
fc-cache -fv > /dev/null 2>&1
log_success "Hack Nerd Font instalada com sucesso."

# ==============================================================================
# 7. EDITOR VIM E PERSONALIZAÇÃO DE PLUGINS
# ==============================================================================
print_header "CONFIGURAÇÃO DO EDITOR VIM"

log_info "Instalando Vim, Python3-pip e Vim-Plug..."
sudo nala install -y vim python3-pip > /dev/null 2>&1
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim > /dev/null 2>&1

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

log_info "Instalando plugins do Vim..."
vim -u NONE -N -e -s -c "source ~/.vimrc" -c "PlugInstall" -c "qa!" > /dev/null 2>&1
log_success "Editor Vim e plugins configurados com sucesso."

# ==============================================================================
# 8. CONFIGURAÇÃO DO SHELL ZSH E OH MY ZSH
# ==============================================================================
print_header "CONFIGURAÇÃO DO SHELL ZSH E OH MY ZSH"

log_info "Instalando Zsh e fontes Powerline..."
sudo nala install -y zsh fonts-powerline > /dev/null 2>&1

if [ "$SHELL" != "/bin/zsh" ]; then
    sudo chsh -s /bin/zsh $USER > /dev/null 2>&1
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Instalando Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/plugins"
[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" > /dev/null 2>&1
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" > /dev/null 2>&1
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" > /dev/null 2>&1
[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ] && git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions" > /dev/null 2>&1
[ ! -d "$ZSH_CUSTOM/plugins/history-search-multi-word" ] && git clone https://github.com/zdharma-continuum/history-search-multi-word.git "$ZSH_CUSTOM/plugins/history-search-multi-word" > /dev/null 2>&1

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
log_success "Zsh e Oh My Zsh (Tema Agnoster) configurados com sucesso."

# ==============================================================================
# 9. ALIASES UNIVERSAIS E FUNÇÕES DO GITHUB
# ==============================================================================
print_header "INJEÇÃO DE ALIASES E CUSTOMIZAÇÕES DO SHELL"

log_info "Configurando aliases e atalhos customizados..."
BLOCO_CUSTOMIZACAO="
# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===
alias neofetch=\"fastfetch\"

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
echo "$BLOCO_CUSTOMIZACAO" >> ~/.bashrc

if [ -f "$HOME/.zshrc" ]; then
    sed -i '/# === BLOCO DE CUSTOMIZACAO DO SCRIPT ===/,/# === FIM DO BLOCO DO SCRIPT ===/d' ~/.zshrc
    echo "$BLOCO_CUSTOMIZACAO" >> ~/.zshrc
fi
log_success "Aliases e função lucasolidev injetados no .bashrc e .zshrc."

# ==============================================================================
# 10. RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

KEYBOARD_STATUS="Não configurado"
if [ -f /etc/default/keyboard ]; then
  if grep -q 'XKBLAYOUT="us,br"' /etc/default/keyboard 2>/dev/null; then
    KEYBOARD_STATUS="US-International (Acentos) + ABNT2 (Alt+Shift)"
  else
    LAYOUT=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    KEYBOARD_STATUS="${LAYOUT:-Padrao}"
  fi
fi

echo -e "  ${FG_GREEN}${BOLD}✔ PÓS-INSTALAÇÃO DO UBUNTU DESKTOP FINALIZADA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Sistema:${NC}     ${FG_GREEN}Operacional e Otimizado${NC}"
echo -e "  ${BOLD}Locales UTF-8:${NC}         ${FG_GREEN}pt_BR.UTF-8 / en_US.UTF-8 (Gerados)${NC}"
echo -e "  ${BOLD}Mapa de Teclado:${NC}       ${FG_CYAN}${KEYBOARD_STATUS}${NC}"
echo -e "  ${BOLD}OpenSSH Server:${NC}        $(get_service_status ssh)"
echo -e "  ${BOLD}Shell Padrão:${NC}          ${FG_CYAN}Zsh + Oh My Zsh (Tema Agnoster)${NC}"
echo -e "  ${BOLD}Flatpak / Flathub:${NC}     ${FG_GREEN}Ativo e Integrado${NC}"
echo -e "  ${BOLD}Google Chrome:${NC}         ${FG_GREEN}Instalado${NC}"
echo -e "  ${BOLD}Comando GitHub:${NC}        ${FG_CYAN}lucasolidev <script.sh>${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

print_alert_box "IMPORTANTE: Feche este terminal e abra um novo para carregar todo o seu ecossistema sem travas."

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
