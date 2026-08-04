#!/bin/bash
# ------------------------------------------------
# Version: 1.0
# ------------------------------------------------
VERSION="1.0"
# ==============================================================================
# Execução recomendada via repositório: lucasolidev agendar_reinicio.sh
# ==============================================================================
# visualizar o script antes de executar:
#
# curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh
#
# Executar via URL diretamente:
# wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh | bash
# bash <(wget -qO- https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh)
# bash <(curl -s https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh)
# curl -fsSL https://raw.githubusercontent.com/lucasolidev/scripts/main/agendar_reinicio.sh | bash
#
# ==============================================================================

# Se executado via pipe (ex: wget -qO- URL | sudo bash), reconecta o STDIN ao terminal para permitir leitura interativa
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec 0</dev/tty
fi

# Solicita a hora no formato HH:MM
echo "Digite o horário que deseja reiniciar (formato HH:MM, ex: 23:30):"
read horaAlvo

# Verifica se o comando shutdown está disponível
if ! command -v shutdown &> /dev/null; then
    echo "Erro: comando 'shutdown' não encontrado."
    exit 1
fi

echo "--------------------------------------------------------"
echo "Agendando reinício para às $horaAlvo"
echo "Para CANCELAR este agendamento, use: sudo shutdown -c"
echo "--------------------------------------------------------"

# Executa o agendamento
# A sintaxe do shutdown no Linux é: shutdown [opção] [hora]
sudo shutdown -r "$horaAlvo"
