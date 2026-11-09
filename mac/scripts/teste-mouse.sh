#!/bin/bash
# Etapas 1 e 2 (T1/T2) com registro automático em log.
# Uso:  ./scripts/teste-mouse.sh          (detecta o mouse do receptor USB)
#       ./scripts/teste-mouse.sh 2        (força o índice 2)
#       SEGUNDOS=20 ./scripts/teste-mouse.sh
#       SUDO=1 ./scripts/teste-mouse.sh   (monitor como administrador; pede a senha)
#       NOSEIZE=1 ./scripts/teste-mouse.sh (sem modo exclusivo, só observa)
#       BLOQUEAR=1 ./scripts/teste-mouse.sh (protótipo do filtro de cursor)
cd "$(dirname "$0")/.."
LOGDIR="$(cd .. && pwd)/logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/teste-mouse-$(date +%Y%m%d-%H%M%S).log"
SEGUNDOS="${SEGUNDOS:-15}"

{
  echo "===== Optical Wireless Jog — teste do mouse ====="
  date
  sw_vers 2>/dev/null
  uname -m
  swift --version 2>&1 | head -1
} > "$LOG"

{
  echo "--- Processos que podem prender o mouse ---"
  ps -axo pid,comm | grep -iE "jogprobe|JogBridge|karabiner|grabber|bridge|steermouse|logi|razer|bettermouse|mos\b|linearmouse|usb overdrive" | grep -v grep || echo "(nenhum encontrado)"
  echo "-------------------------------------------"
} >> "$LOG" 2>&1
echo "Compilando…"
./scripts/sw build --product jogprobe >> "$LOG" 2>&1 || { echo "Falha na compilação. Log: $LOG"; exit 1; }
BIN="$(./scripts/sw build --show-bin-path)/jogprobe"

echo ""
echo "===== T1 — dispositivos =====" | tee -a "$LOG"
"$BIN" 2>&1 | tee -a "$LOG"

N="$1"
if [ -z "$N" ]; then
  N=$("$BIN" 2>/dev/null | awk '/^\[[0-9]+\]/{gsub(/[\[\]]/,"",$1); idx=$1} /Transporte: USB/{print idx; exit}')
fi
if [ -z "$N" ]; then
  echo "Nenhum mouse USB encontrado automaticamente. Rode de novo informando o índice: ./scripts/teste-mouse.sh N" | tee -a "$LOG"
  echo "Log salvo em: $LOG"
  exit 1
fi

echo "" | tee -a "$LOG"
echo "===== T2 — monitor do dispositivo [$N] por $SEGUNDOS s =====" | tee -a "$LOG"
echo ">>> AGORA: arraste o mouse ~10 cm para a frente, pare, 10 cm para trás,"
echo ">>> depois vai-e-vem rápido. Observe se o CURSOR da tela se move."
PREFIX=""
if [ "$SUDO" = "1" ]; then PREFIX="sudo"; echo "(monitor como administrador)" | tee -a "$LOG"; fi
SEIZE="--seize"
if [ "$NOSEIZE" = "1" ]; then SEIZE=""; echo "(SEM modo exclusivo)" | tee -a "$LOG"; fi
if [ "$BLOQUEAR" = "1" ]; then SEIZE="--bloquear-cursor"; echo "(filtro de cursor — protótipo)" | tee -a "$LOG"; fi
$PREFIX "$BIN" monitor "$N" $SEIZE --segundos "$SEGUNDOS" 2>&1 | tee -a "$LOG"
echo "" ; read -r -p "O CURSOR se moveu durante o teste? (s/n): " CURSOR
echo "Resposta do usuário — cursor se moveu: $CURSOR" >> "$LOG"

echo ""
echo "✅ Log salvo em: $LOG"
