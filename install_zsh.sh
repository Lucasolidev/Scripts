#!/bin/bash
# ------------------------------------------------
# Version: 1.1
# ------------------------------------------------
VERSION="1.1"
# ==============================================================================
# SCRIPT DE INSTALAÇÃO E CONFIGURAÇÃO DO TERMINAL ZSH - UBUNTU 24.04 / 26.04
# COM OH MY ZSH, TEMA AGNOSTER / POWERLEVEL10K, PLUGINS E CUSTOMIZAÇÕES
# ==============================================================================
# Execução recomendada (copiar e colar comando único):
# wget https://raw.githubusercontent.com/Lucasolidev/Scripts/main/install_zsh.sh -O install_zsh.sh && sudo chmod +x install_zsh.sh && sudo ./install_zsh.sh
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
LOG_FILENAME="relatorio_install_zsh_${LOG_TIMESTAMP}.log"
LOG_LATEST="relatorio_install_zsh_latest.log"

RUNTIME_DIR=$(mktemp -d -p /tmp install_zsh.XXXXXXXX) || exit 1
chmod 700 "$RUNTIME_DIR"
LOG_TMP="${RUNTIME_DIR}/${LOG_FILENAME}"
touch "$LOG_TMP" && chmod 600 "$LOG_TMP"

cleanup() {
    rm -rf -- "$RUNTIME_DIR"
}
trap cleanup EXIT INT TERM HUP

exec > >(tee -a "$LOG_TMP") 2>&1

PACOTES_INSTALADOS=()

# Determina usuário alvo real
ALVO_USER="${SUDO_USER:-root}"
ALVO_HOME=$(getent passwd "$ALVO_USER" | cut -d: -f6)

# ==============================================================================
# 2 - INSTALAÇÃO DE PACOTES E DEPENDÊNCIAS
# ==============================================================================
print_header "INSTALAÇÃO DE PACOTES E DEPENDÊNCIAS"

log_info "Atualizando repositórios..."
apt-get update -y > /dev/null 2>&1 || true

DEPENDENCIAS=(
    "zsh"
    "git"
    "curl"
    "unzip"
    "htop"
    "openssh-server"
    "fonts-powerline"
    "fonts-firacode"
)

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

log_info "Ativando serviço SSH..."
systemctl enable --now ssh > /dev/null 2>&1 || true
log_success "Serviço SSH: $(get_service_status ssh)"

# ==============================================================================
# 3 - CONFIGURAÇÃO DO SHELL PADRÃO
# ==============================================================================
print_header "DEFINIÇÃO DO SHELL PADRÃO (ZSH)"

ZSH_BIN=$(command -v zsh || echo "/bin/zsh")
if [ -x "$ZSH_BIN" ]; then
    log_info "Alterando shell padrão de '$ALVO_USER' para $ZSH_BIN..."
    chsh -s "$ZSH_BIN" "$ALVO_USER" > /dev/null 2>&1 || true
    if [ "$ALVO_USER" != "root" ]; then
        chsh -s "$ZSH_BIN" root > /dev/null 2>&1 || true
    fi
    log_success "Shell padrão atualizado para Zsh."
fi

# ==============================================================================
# 4 - INSTALAÇÃO SEGURA DO OH MY ZSH E PLUGINS
# ==============================================================================
print_header "OH MY ZSH E PLUGINS"

configurar_oh_my_zsh() {
    local target_user="$1"
    local target_home="$2"

    local omz_dir="$target_home/.oh-my-zsh"
    local custom_dir="$omz_dir/custom"

    log_info "Configurando Oh My Zsh para o usuário '$target_user' em $target_home..."

    if [ ! -d "$omz_dir" ]; then
        log_info "Clonando Oh My Zsh oficial via Git..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir" > /dev/null 2>&1
        log_success "Oh My Zsh clonado com sucesso em $omz_dir."
    else
        log_skipped "Oh My Zsh já existente em $omz_dir."
    fi

    mkdir -p "$custom_dir/themes" "$custom_dir/plugins"

    # Tema Powerlevel10k
    if [ ! -d "$custom_dir/themes/powerlevel10k" ]; then
        log_info "Clonando tema Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k" > /dev/null 2>&1 || true
    fi

    # Plugins Zsh
    local PLUGINS_GIT=(
        "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
        "zsh-completions|https://github.com/zsh-users/zsh-completions"
        "history-search-multi-word|https://github.com/zdharma-continuum/history-search-multi-word.git"
    )

    for item in "${PLUGINS_GIT[@]}"; do
        local p_name="${item%%|*}"
        local p_url="${item##*|}"
        if [ ! -d "$custom_dir/plugins/$p_name" ]; then
            log_info "Clonando plugin '$p_name'..."
            git clone --depth=1 "$p_url" "$custom_dir/plugins/$p_name" > /dev/null 2>&1 || true
        fi
    done

    # Escreve o arquivo .zshrc
    cat << 'EOF' > "$target_home/.zshrc"
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Define o tema Agnoster como padrao estavel
ZSH_THEME="agnoster"

# Lista definitiva de plugins
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
[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# === BLOCO DE CUSTOMIZACAO DO PROJETO ===
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

alias neofetch="fastfetch 2>/dev/null || uname -a"
alias tc-br="gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'br'), ('xkb', 'us+intl')]\" 2>/dev/null || true"
alias tc-us="gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us+intl'), ('xkb', 'br')]\" 2>/dev/null || true"

load-script() {
    local script_name="${1:-}"
    if [ -z "$script_name" ]; then
        echo "Uso: load-script <nome_do_script.sh>"
        return 1
    fi
    local url="https://raw.githubusercontent.com/Lucasolidev/Scripts/main/${script_name}"
    if curl -fsSL "$url" -o "$script_name"; then
        chmod +x "$script_name"
        sudo ./"$script_name"
    else
        echo "Falha ao baixar o script '$script_name'."
        return 1
    fi
}
alias lucasolidev="load-script"
# === FIM DO BLOCO DO PROJETO ===
EOF

    chown -R "$target_user:$target_user" "$omz_dir" "$target_home/.zshrc" 2>/dev/null || true
    chmod 644 "$target_home/.zshrc"
    log_success "Arquivo .zshrc configurado para '$target_user'."
}

configurar_oh_my_zsh "$ALVO_USER" "$ALVO_HOME"
if [ "$ALVO_USER" != "root" ]; then
    configurar_oh_my_zsh "root" "/root"
fi

# ==============================================================================
# 5 - RESUMO DA INSTALAÇÃO
# ==============================================================================
print_header "RESUMO DA INSTALAÇÃO"

LISTA_PACOTES=$(IFS=', '; echo "${PACOTES_INSTALADOS[*]}")

echo -e "  ${FG_GREEN}${BOLD}✔ AMBIENTE ZSH CONFIGURADO COM SUCESSO!${NC}\n"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Shell Configurado:${NC}     ${FG_GREEN}Zsh + Oh My Zsh (Tema Agnoster)${NC}"
echo -e "  ${BOLD}Usuário Atendido:${NC}      ${FG_CYAN}${ALVO_USER}${NC} ($ALVO_HOME)"
echo -e "  ${BOLD}Pacotes Instalados:${NC}    ${FG_CYAN}${LISTA_PACOTES:-Nenhum}${NC}"
echo -e "  ${BOLD}Plugins Ativos:${NC}        ${FG_GREEN}autosuggestions, syntax-highlighting, completions, history-search${NC}"
echo -e "  ${BOLD}Versão do Script:${NC}      ${FG_WHITE}${VERSION}${NC}"
echo -e "  ${BOLD}Log de Instalação:${NC}     ${FG_CYAN}/root/${LOG_FILENAME}${NC}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}\n"

print_alert_box "Para carregar o novo ambiente imediatamente, feche este terminal e abra uma nova sessão SSH/Console."

# ==============================================================================
# 6 - GERAÇÃO E SALVAMENTO DOS ARQUIVOS DE LOG
# ==============================================================================
print_header "ARQUIVOS DE LOG DA INSTALAÇÃO"

cp "$LOG_TMP" "/root/${LOG_FILENAME}" 2>/dev/null || true
cp "$LOG_TMP" "/root/${LOG_LATEST}" 2>/dev/null || true
chmod 600 "/root/${LOG_FILENAME}" "/root/${LOG_LATEST}" 2>/dev/null || true
log_success "Log salvo em: /root/${LOG_FILENAME}"
log_success "Atalho do último log: /root/${LOG_LATEST}"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    if [ -d "$ALVO_HOME" ]; then
        cp "$LOG_TMP" "${ALVO_HOME}/${LOG_FILENAME}" 2>/dev/null || true
        cp "$LOG_TMP" "${ALVO_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chmod 600 "${ALVO_HOME}/${LOG_FILENAME}" "${ALVO_HOME}/${LOG_LATEST}" 2>/dev/null || true
        chown "$SUDO_USER:$SUDO_USER" "${ALVO_HOME}/${LOG_FILENAME}" "${ALVO_HOME}/${LOG_LATEST}" 2>/dev/null || true
        log_success "Log salvo na Home ($SUDO_USER): ${ALVO_HOME}/${LOG_FILENAME}"
    fi
fi

draw_separator
echo -e "  ${DIM}Processo finalizado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
