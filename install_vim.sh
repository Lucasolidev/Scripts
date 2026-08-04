#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO EDITOR VIM - UBUNTU 26.04
# ==============================================================================
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_vim.sh
# ==============================================================================
# Baixar o script:
# wget https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh
# curl -O https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh
#
# Visualizar o script antes de executar:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh
#
# Executar via URL diretamente (exige sudo):
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh | sudo bash
# sudo bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh)
# sudo bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/install_vim.sh | sudo bash
#
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# ==========================================
# PALETA DE CORES (ANSI ESCAPE CODES) E FUNÇÕES
# ==========================================
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

FG_CYAN='\033[36m'
FG_YELLOW='\033[33m'
FG_GREEN='\033[32m'
FG_RED='\033[31m'
FG_WHITE='\033[37m'

ARROW="❯"

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}=== SYSTEM MANAGER ===${NC}"
    echo -e "${FG_CYAN}${BOLD}❯ ${title}${NC}"
    draw_separator
}

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# ==============================================================================
# INÍCIO DO SCRIPT
# ==============================================================================

clear

print_header "CONFIGURANDO O EDITOR VIM E PLUGINS"

# Se executado via pipe (ex: wget -qO- URL | bash), reconecta o STDIN ao terminal para permitir leitura interativa
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec 0</dev/tty
fi

# Valida o sudo logo no início da execução
log_warning "Solicitando credenciais de administrador..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

print_header "INSTALAÇÃO DE PACOTES"
log_info "Verificando e instalando dependências base (nala, curl, git)..."
if sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y nala curl git > /dev/null 2>&1; then
    log_success "Dependências instaladas."
else
    log_error "Falha ao instalar dependências base."
fi

log_info "Instalando vim e python3-pip via nala..."
if sudo nala install -y vim python3-pip > /dev/null 2>&1; then
    log_success "Vim e python3-pip instalados."
else
    log_error "Falha ao instalar vim e pip."
fi

print_header "CONFIGURAÇÃO DO VIM"
log_info "Baixando o gerenciador de plugins 'vim-plug'..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim > /dev/null 2>&1
log_success "Vim-plug baixado."

log_info "Criando o arquivo de configuração ~/.vimrc..."
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
syntax on            " Enable syntax highlight
set nu               " Enable line numbers
set tabstop=4        " Show existing tab with 4 spaces width
set softtabstop=4    " Show existing tab with 4 spaces width
set shiftwidth=4     " When indenting with '>', use 4 spaces width
set expandtab        " On pressing tab, insert 4 spaces
set smarttab         " insert tabs on the start of a line according to shiftwidth
set smartindent      " Automatically inserts one extra level of indentation in some cases
set hidden           " Hides the current buffer when a new file is openned
set incsearch        " Incremental search
set ignorecase       " Ingore case in search
set smartcase        " Consider case if there is a upper case character
set scrolloff=8      " Minimum number of lines to keep above and below the cursor
set colorcolumn=100  " Draws a line at the given line to keep aware of the line size
set signcolumn=yes   " Add a column on the left. Useful for linting
set cmdheight=2      " Give more space for displaying messages
set updatetime=100   " Time in miliseconds to consider the changes
set encoding=utf-8   " The encoding should be utf-8 to activate the font icons
set nobackup         " No backup files
set nowritebackup    " No backup files
set splitright       " Create the vertical splits to the right
set splitbelow       " Create the horizontal splits below
set autoread         " Update vim after file update from outside
set mouse=a          " Enable mouse support
filetype on          " Detect and set the filetype option and trigger the FileType Event
filetype plugin on   " Load the plugin file for the file type, if any
filetype indent on   " Load the indent file for the file type, if any

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
log_success "Arquivo ~/.vimrc criado com sucesso."

log_info "Instalando os plugins do Vim de forma isolada..."
vim -u NONE -N -e -s -c "source ~/.vimrc" -c "PlugInstall" -c "qa!" > /dev/null 2>&1
log_success "Plugins do Vim instalados."

print_header "RESUMO DO SISTEMA"
log_success "Editor Vim instalado e personalizado com sucesso!"
echo ""
draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
