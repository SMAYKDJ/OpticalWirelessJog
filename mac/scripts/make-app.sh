#!/bin/bash
# Compila e empacota o JogBridge como .app (necessário para as permissões
# de Monitoramento de Entrada ficarem associadas ao app).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/sw build -c release --product JogBridge
BIN="$(./scripts/sw build -c release --show-bin-path)/JogBridge"

APP="$HOME/Applications/JogBridge.app"
mkdir -p "$HOME/Applications"; rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/JogBridge"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Assinatura ad-hoc com Designated Requirement estável (evita que o macOS revogue a permissão após recompilar)
codesign --force --deep --sign - -r='designated => identifier "com.smaykdj.opticaljog"' "$APP"

echo ""
echo "✅ App gerado em: $APP"
echo "   Abra com:  open \"$APP\""
echo "   Na 1ª execução, permita Monitoramento de Entrada."
echo "   Se o mouse não for bloqueado (modo exclusivo), veja docs/solucao-de-problemas.md"
