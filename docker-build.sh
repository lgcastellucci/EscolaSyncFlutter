#!/bin/bash
# Gera o AAB assinado inteiramente dentro do container Docker
# (não instala Flutter/Android SDK na máquina local).
#
# Uso:
#   ./docker-build.sh
#
# Requer:
#   - Docker instalado
#   - escolasync-release.keystore na raiz do projeto (não versionado)

set -e

KEYSTORE_FILE="escolasync-release.keystore"

if [ ! -f "$KEYSTORE_FILE" ]; then
  echo "ERRO: $KEYSTORE_FILE não encontrado na raiz do projeto."
  echo "Copie o keystore existente (já usado na Play Store) para cá antes de buildar."
  exit 1
fi

mkdir -p output

docker build -t escolasync-builder .

docker run --rm \
  -e KEY_ALIAS=escolasync \
  -e KEY_PASSWORD='Escola@Sync@2026' \
  -e STORE_PASSWORD='Escola@Sync@2026' \
  -e STORE_FILE=/keystore/escolasync-release.keystore \
  -v "$(pwd)/output:/app/build/app/outputs/bundle/release" \
  -v "$(pwd)/$KEYSTORE_FILE:/keystore/escolasync-release.keystore:ro" \
  -v "$(pwd)/build.sh:/app/build.sh:ro" \
  escolasync-builder \
  bash /app/build.sh

echo ""
echo "AAB gerado em ./output/app-release.aab"
echo "Suba esse arquivo como atualização do com.escolasync.app na Play Console."
