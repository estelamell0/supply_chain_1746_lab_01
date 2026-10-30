#!/usr/bin/env bash
# Wrapper Seguro com Verificação Estrita de Integridade Criptográfica (Hash Pinning)
# Prevenção contra ataques no estilo Codecov Bash Uploader

set -euo pipefail

TARGET_SCRIPT="${1:-scripts/download_agent.sh}"
# Hash SHA-256 legítimo e homologado do script (formato LF / 301 bytes)
EXPECTED_SHA="bab6970eaffe7b9b8a0254332c33a638b175fd92e2eb5e69e66df509affdc1a7"

echo "[SECURE-FETCH] Inspecionando integridade do artefato: $TARGET_SCRIPT"

if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "[ERRO CRÍTICO] Arquivo '$TARGET_SCRIPT' não encontrado!" >&2
    exit 1
fi

# Calcula o hash SHA-256 do arquivo local/baixado
if command -v sha256sum &> /dev/null; then
    ACTUAL_SHA=$(sha256sum "$TARGET_SCRIPT" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
    ACTUAL_SHA=$(shasum -a 256 "$TARGET_SCRIPT" | awk '{print $1}')
else
    echo "[ERRO] Utilitário sha256sum ou shasum não encontrado!" >&2
    exit 1
fi

echo "[SECURE-FETCH] Hash Calculado : $ACTUAL_SHA"
echo "[SECURE-FETCH] Hash Homologado: $EXPECTED_SHA"

# Comparação estrita sem tolerância a divergências
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "======================================================================" >&2
    echo " [ALERTA DE SEGURANÇA MÁXIMA] FALHA DE INTEGRIDADE CRIPTOGRÁFICA!     " >&2
    echo " O hash do script diverge do valor homologado pela equipe de AppSec.  " >&2
    echo " Abortando execução antes que qualquer comando seja executado!        " >&2
    echo "======================================================================" >&2
    exit 2
fi

echo "[SECURE-FETCH] Integridade confirmada com sucesso! Executando script de forma segura:"
echo "----------------------------------------------------------------------"
bash "$TARGET_SCRIPT"
