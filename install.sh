#!/bin/bash
# ==============================================================================
# Optical Wireless Jog - Script de Instalação e Inicialização
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$HOME/Applications/JogBridge.app"

echo "========================================================"
echo " 🎧 OPTICAL WIRELESS JOG - TRAKTOR PRO 4 BRIDGE"
echo "========================================================"
echo ""

# 1. Verificar ferramentas de compilação da Apple
if ! command -v swift &>/dev/null; then
    echo "⚠️  Ferramentas do Swift/Xcode não encontradas."
    echo "   Instalando Command Line Tools da Apple..."
    xcode-select --install || true
    echo "   Após a conclusão da instalação da Apple, execute este script novamente."
    exit 1
fi

# 2. Compilar e instalar se o app não existir ou se solicitado recompilar
REBUILD=0
if [ ! -d "$APP_PATH" ] || [ "${1:-}" = "--rebuild" ]; then
    REBUILD=1
fi

if [ "$REBUILD" -eq 1 ]; then
    echo "📦 Compilando e gerando o JogBridge.app..."
    cd "$SCRIPT_DIR/mac"
    ./scripts/make-app.sh
    echo ""
else
    echo "✅ JogBridge.app já instalado em: $APP_PATH"
fi

# 3. Verificar permissão de Monitoramento de Entrada do macOS
echo "🔒 Verificando permissões de Monitoramento de Entrada..."
if ! tccutil reset ListenEvent com.smaykdj.opticaljog 2>/dev/null; then
    # Se o tccutil não resetar (normal em usuário comum), continua
    true
fi

# 4. Abrir o aplicativo
echo "🚀 Abrindo Optical Wireless Jog..."
open "$APP_PATH"

echo ""
echo "========================================================"
echo "🎉 PRONTO! O aplicativo está aberto."
echo ""
echo "📌 NOTAS IMPORTANTES:"
echo " 1. Se for a 1ª vez, permita 'Monitoramento de Entrada' em:"
echo "    Ajustes do Sistema ▸ Privacidade e Segurança ▸ Monitoramento de Entrada"
echo " 2. No Traktor Pro 4, verifique a porta MIDI virtual 'Optical Jog'."
echo " 3. Use o botão direito do mouse para alternar entre Deck A e Deck B!"
echo "========================================================"

