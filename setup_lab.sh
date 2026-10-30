#!/usr/bin/env bash
# Script de Inicialização e Reset do Laboratório de Supply Chain Security
# Bash Native Driver para Linux / macOS / WSL / Git Bash (100% paridade com setup_lab.ps1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 0. Limpar chaves temporárias e assinaturas de execuções anteriores
rm -f privkey.pem pubkey.pem dist/release.sig dist/payment-api-dist.tar.gz

# 1. Normalizar fim de linha LF nos scripts de telemetria (proteção contra git core.autocrlf=true)
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    PYTHON_CMD="python"
fi

"$PYTHON_CMD" -c "
for p in ['scripts/download_agent.sh', 'scripts/download_agent_compromised.sh', 'scripts/secure_fetch.sh']:
    with open(p, 'rb') as f:
        raw = f.read().replace(b'\r\n', b'\n')
    with open(p, 'wb') as f:
        f.write(raw)
"

# 2. Restaurar src/package.json ao estado íntegro original (caso modificado na Fase 5)
cat << 'EOF' > src/package.json
{
  "name": "payment-api-service",
  "version": "1.0.0",
  "description": "Serviço de pagamentos para testes de integridade e Supply Chain",
  "main": "app.py",
  "scripts": {
    "test": "echo \"Executando testes unitarios...\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cross-env": "^7.0.3"
  }
}
EOF

if [[ "${1:-}" == "--clean" || "${1:-}" == "-Clean" ]]; then
    rm -rf dist
    echo "[OK] Artefatos temporários removidos e arquivos do laboratório restaurados com sucesso."
    exit 0
fi

echo "=================================================================="
echo " INICIALIZANDO AMBIENTE DO LABORATÓRIO (SUPPLY CHAIN INTEGRITY)    "
echo "=================================================================="

# 3. Garantir diretório dist/ e gerar o pacote de release determinístico (LF, sem BOM)
mkdir -p dist
ARTIFACT_PATH="dist/payment-api-dist.tar.gz"
echo "[*] Empacotando artefato de release: $ARTIFACT_PATH..."

printf "#!/usr/bin/env python3\nprint('Payment API Microservice Compiled Binary v1.0.0')\n" > "$ARTIFACT_PATH"

# 4. Calcular hash SHA-256 real do artefato
if command -v sha256sum &> /dev/null; then
    REAL_HASH=$(sha256sum "$ARTIFACT_PATH" | awk '{print $1}')
else
    REAL_HASH=$(shasum -a 256 "$ARTIFACT_PATH" | awk '{print $1}')
fi
echo "[*] Digest SHA-256 do Artefato: $REAL_HASH"

# 5. Atualizar o arquivo slsa/provenance.json com o hash real para validação inicial
PROV_PATH="slsa/provenance.json"
if [ -f "$PROV_PATH" ]; then
    "$PYTHON_CMD" -c "
import json
with open('$PROV_PATH', 'r', encoding='utf-8-sig') as f:
    data = json.load(f)
data['subject'][0]['digest']['sha256'] = '$REAL_HASH'
with open('$PROV_PATH', 'w', encoding='utf-8', newline='\n') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    echo "[*] Atestação SLSA Provenance v1.0 sincronizada em: $PROV_PATH"
fi

# Tornar scripts executáveis
chmod +x scripts/*.sh tools/*.py slsa/*.py 2>/dev/null || true

echo "------------------------------------------------------------------"
echo "[OK] Ambiente do laboratório pronto para execução!"
echo "Consulte README.md (alunos) ou teacher_guide_lab_01.md (instrutor)."
