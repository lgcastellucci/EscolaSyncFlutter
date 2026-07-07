#!/bin/bash
# Verifica se o keystore de assinatura está no lugar certo e é válido
# ANTES de rodar o flutter build — pra falhar cedo com uma mensagem
# clara, em vez de um erro genérico do Gradle lá na frente.
#
# Uso (dentro do container, antes do build):
#   ./build.sh
#
# Lê os mesmos nomes de variável usados no docker-compose.yml /
# docker-build.sh (STORE_FILE, KEY_ALIAS, STORE_PASSWORD).

set -uo pipefail

KEYSTORE_PATH="${STORE_FILE:-/app/escolasync-release.keystore}"
ALIAS="${KEY_ALIAS:-escolasync}"
STORE_PASSWORD="${STORE_PASSWORD:-Escola@Sync@2026}"

echo "🔍 Verificando keystore em: $KEYSTORE_PATH"

if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "❌ Keystore NÃO encontrado em $KEYSTORE_PATH"
  echo "   Copie escolasync-release.keystore para esse caminho antes de buildar."
  echo "   Ex.: docker cp escolasync-release.keystore escolasync-builder:$KEYSTORE_PATH"
  exit 1
fi

SIZE=$(stat -c%s "$KEYSTORE_PATH" 2>/dev/null || stat -f%z "$KEYSTORE_PATH" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 100 ]; then
  echo "❌ Arquivo encontrado, mas parece vazio ou corrompido ($SIZE bytes)."
  exit 1
fi
echo "✅ Arquivo encontrado ($SIZE bytes)."

if command -v keytool >/dev/null 2>&1; then
  echo "🔍 Validando alias \"$ALIAS\" e senha..."
  if keytool -list -keystore "$KEYSTORE_PATH" -alias "$ALIAS" -storepass "$STORE_PASSWORD" >/dev/null 2>&1; then
    echo "✅ Alias e senha conferem."
  else
    echo "❌ Não foi possível abrir o keystore com alias=\"$ALIAS\" e a senha configurada."
    echo "   Confira as variáveis KEY_ALIAS / STORE_PASSWORD / KEY_PASSWORD."
    exit 1
  fi

  echo ""
  echo "🔑 SHA-1 deste keystore (precisa ser EXATAMENTE este que está"
  echo "   cadastrado no Client ID Android, no Google Cloud Console —"
  echo "   google_sign_in valida por package name + SHA-1, sem"
  echo "   client_id/secret no código):"
  keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$ALIAS" -storepass "$STORE_PASSWORD" 2>/dev/null \
    | grep "SHA1:" | sed 's/^/   /'
else
  echo "⚠️  keytool não encontrado no PATH — pulando validação de alias/senha."
  echo "   (isso não deveria acontecer na imagem ghcr.io/cirruslabs/flutter, que já traz o JDK)"
fi

echo ""
echo "✅ Keystore OK."

echo ""
echo "🔍 Gerando a versao flutter"

flutter clean
flutter pub get
flutter build appbundle --release

cp build/app/outputs/bundle/release/app-release.aab . 