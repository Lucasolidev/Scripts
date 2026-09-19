#!/bin/bash
# ------------------------------------------------
# Version: 1.2
# ------------------------------------------------
VERSION="1.2"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO EDITOR VIM - UBUNTU SERVER / DESKTOP
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_vim.sh -O install_vim.sh && sudo chmod +x install_vim.sh && sudo ./install_vim.sh
# ==============================================================================

set -Eeuo pipefail
umask 077
export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# 1 - INICIALIZAÇÃO E FUNÇÕES BASE
# ==============================================================================

# 1.1 - PALETA DE CORES E ESTILOS (ANSI)
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

readonly FG_CYAN='\033[36m'
readonly FG_YELLOW='\033[33m'
readonly FG_GREEN='\033[32m'
readonly FG_RED='\033[31m'
readonly FG_WHITE='\033[37m'

readonly ARROW="❯"

draw_separator() {
    echo -e "${DIM}${FG_CYAN}────────────────────────────────────────────────────────────────${NC}"
}

print_header() {
    local title="$1"
    echo -e ""
    echo -e "${FG_CYAN}${BOLD}${ARROW} ${title}${NC}"
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

log_info()    { echo -e "  ${FG_CYAN}[i]${NC}  ${BOLD}INFO:${NC}      $1"; }
log_success() { echo -e "  ${FG_GREEN}[+]${NC}  ${FG_GREEN}${BOLD}SUCESSO:${NC}   $1"; }
log_warning() { echo -e "  ${FG_YELLOW}[!]${NC}  ${FG_YELLOW}${BOLD}ATENÇÃO:${NC}   $1"; }
log_error()   { echo -e "  ${FG_RED}[x]${NC}  ${FG_RED}${BOLD}ERRO:${NC}      $1"; }
log_skipped() { echo -e "  ${FG_RED}[-]${NC}  ${FG_RED}${BOLD}PULADO:${NC}    $1"; }

print_alert_box() {
    local msg="$1"
    echo -e "\n  ${FG_YELLOW}${BOLD}⚠ ATENÇÃO REQUERIDA:${NC} ${FG_YELLOW}${msg}${NC}\n"
}

# 1.2 - VALIDAÇÃO DE PRIVILÉGIOS E INICIALIZAÇÃO DE LOG
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\n  ${FG_RED}${BOLD}[x] ERRO:${NC} Este script precisa ser executado como root (use sudo).\n"
    exit 1
fi

LOG_TIMESTAMP=$(date '+%d%m%Y_%H%M')
LOG_FILENAME="relatorio_install_vim_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_vim_latest.log"

RUNTIME_DIR=$(mktemp -d -p /tmp install_vim.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP

exec > >(tee -a "$LOG_TMP") 2>&1

PACOTES_INSTALADOS=()

# ==============================================================================
# 2 - INSTALAÇÃO DE PACOTES
# ==============================================================================
print_header "INSTALAÇÃO DE PACOTES"

log_info "Atualizando repositórios do sistema..."
apt-get update -y > /dev/null 2>&1 || true

DEPENDENCIAS=("curl" "git" "vim")
for pkg in "${DEPENDENCIAS[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log_skipped "Pacote '$pkg' já está instalado."
        PACOTES_INSTALADOS+=("$pkg")
    else
        log_info "Instalando pacote: ${pkg}..."
        if apt-get install -y "$pkg" > /dev/null 2>&1; then
            log_success "Pacote '$pkg' instalado com sucesso."
            PACOTES_INSTALADOS+=("$pkg")
        else
            log_error "Falha ao instalar o pacote '$pkg'."
        fi
    fi
done

# ==============================================================================
# 3 - CONFIGURAÇÃO DO GERENCIADOR VIM-PLUG E PLUGINS
# ==============================================================================
print_header "CONFIGURAÇÃO DO VIM E PLUGINS"

log_info "Preparando diretórios para o vim-plug (/root e /etc/skel)..."
mkdir -p /root/.vim/autoload /root/.vim/plugged /etc/skel/.vim/autoload /etc/skel/.vim/plugged

log_info "Baixando o gerenciador de plugins 'vim-plug'..."
curl -fLo /root/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim > /dev/null 2>&1 || {
    log_error "Falha ao baixar plug.vim para /root."
}
cp /root/.vim/autoload/plug.vim /etc/skel/.vim/autoload/plug.vim 2>/dev/null || true
log_success "Vim-plug configurado com sucesso."

log_info "Criando arquivo de configuração /root/.vimrc..."
cat << 'EOF' > /root/.vimrc
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
set smartindent      " Automatically inserts one extra level of indentation
set autoindent       " Minimal automatic indenting for any filetype
set hidden           " Hides the current buffer when a new file is open
set incsearch        " Incremental search
set ignorecase       " Ignore case in search patterns
set smartcase        " Override ignorecase if search pattern contains uppercase
set nobackup         " No backup file
set nowritebackup    " No backup file while editing
set splitbelow       " Horizontal splits will automatically be below
set splitright       " Vertical split will automatically be to the right
set t_Co=256         " Support 256 colors
set noshowmode       " Do not show mode since airline handles it
set cursorline       " Highlight current line

" Themes & Appearance """"""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('termguicolors')
    set termguicolors
endif

let g:sonokai_style = 'andromeda'
let g:sonokai_enable_italic = 1
let g:sonokai_disable_italic_comment = 1

silent! colorscheme sonokai

let g:airline_theme = 'sonokai'
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
EOF

cp /root/.vimrc /etc/skel/.vimrc 2>/dev/null || true

# Replicar para as homes dos usuários existentes
for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        user_name=$(basename "$home_dir")
        mkdir -p "$home_dir/.vim/autoload" "$home_dir/.vim/plugged" 2>/dev/null || true
        cp /root/.vim/autoload/plug.vim "$home_dir/.vim/autoload/plug.vim" 2>/dev/null || true
        cp /root/.vimrc "$home_dir/.vimrc" 2>/dev/null || true
        chown -R "$user_name:$user_name" "$home_dir/.vim" "$home_dir/.vimrc" 2>/dev/null || true
    fi
done

log_info "Instalando plugins silenciosamente via vim-plug..."
vim +PlugInstall +qall > /dev/null 2>&1 || true
log_success "Configuração do Vim e plugins aplicada com sucesso."

# ==============================================================================
# 4 - RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")

echo -e "  ${FG_GREEN}${BOLD}✔ INSTALAÇÃO DO VIM CONCLUÍDA COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Status do Editor:${NC}      ${FG_GREEN}Configurado e Otimizado${NC}"
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
echo -e "  ${BOLD}Tema Visual:${NC}           ${FG_GREEN}Sonokai (Andromeda) + Airline${NC}"
echo -e "  ${BOLD}Perfis Atendidos:${NC}      ${FG_CYAN}/root, /etc/skel e /home/*${NC}"
echo -e "  ${BOLD}Versão do Script:${NC}      ${FG_WHITE}${VERSION}${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

# ==============================================================================
# 5 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -d "$REAL_USER_HOME" ]; then
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chmod 600 "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${REAL_USER_HOME}/${LOG_FILENAME}" "${REAL_USER_HOME}/${LOG_LATEST}" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${REAL_USER_HOME}/${LOG_FILENAME}"
    fi
fi

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
