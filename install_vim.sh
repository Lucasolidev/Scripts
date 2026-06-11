#!/bin/bash
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO EDITOR VIM - UBUNTU 26.04
# ==============================================================================
# Execução recomendada via repositório: lucasolidev install_vim.sh
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

VERDE='\033[0;32m'
AMARELO='\033[1;33m'
PADRAO='\033[0m'

main() {
    clear
    echo "=================================================================="
    echo "  Configurando o Editor Vim e Plugins"
    echo "=================================================================="
    
    # Valida o sudo logo no início da execução
    echo -e "${AMARELO}[!] Solicitando credenciais de administrador...${PADRAO}"
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    echo -e "${VERDE}[*] Verificando e instalando dependências base...${PADRAO}"
    sudo apt-get update && sudo apt-get install -y nala curl git
    sudo nala install -y vim python3-pip

    echo -e "${VERDE}[*] Baixando o gerenciador de plugins 'vim-plug'...${PADRAO}"
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    echo -e "${VERDE}[*] Criando o arquivo de configuração ~/.vimrc...${PADRAO}"
    
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

    echo -e "${VERDE}[*] Instalando os plugins do Vim de forma isolada...${PADRAO}"
    vim -u NONE -N -e -s -c "source ~/.vimrc" -c "PlugInstall" -c "qa!"
    
    echo -e "\n${VERDE}[+] Editor Vim instalado e personalizado com sucesso!${PADRAO}"
}

main
