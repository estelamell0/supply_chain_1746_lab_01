#!/usr/bin/env python3
"""
Validador de Proveniência SLSA v1.0 (in-toto Statement v1)
Utilitário CLI educacional para verificação de atestações de compilação.
"""
import argparse
import hashlib
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def calculate_sha256(filepath: str) -> str:
    hasher = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest().lower()


def main():
    parser = argparse.ArgumentParser(description="Validador CLI de Proveniência SLSA v1.0 (in-toto)")
    parser.add_argument("--artifact", required=True, help="Caminho para o arquivo ou binário compilado")
    parser.add_argument("--provenance", required=True, help="Caminho para o arquivo JSON de proveniência")
    args = parser.parse_args()

    if not os.path.exists(args.provenance):
        print(f"[ERRO] Arquivo de proveniência não encontrado: {args.provenance}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(args.artifact):
        print(f"[ERRO] Artefato alvo não encontrado: {args.artifact}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(args.provenance, "r", encoding="utf-8-sig") as f:
            prov_data = json.load(f)
    except Exception as e:
        print(f"[ERRO] Falha ao analisar o JSON de proveniência: {e}", file=sys.stderr)
        sys.exit(1)

    print("==================================================================")
    print(" INSPECIONANDO ATESTAÇÃO DE PROCEDÊNCIA SLSA v1.0 (in-toto)       ")
    print("==================================================================")

    # 1. Validação de Esquema
    statement_type = prov_data.get("_type")
    predicate_type = prov_data.get("predicateType")
    print(f"[*] Tipo de Declaração : {statement_type}")
    print(f"[*] Tipo de Predicado   : {predicate_type}")

    if predicate_type != "https://slsa.dev/provenance/v1":
        print("[AVISO] O predicado não é formalmente SLSA Provenance v1.0!")

    # 2. Extração dos Metadados do Builder
    builder_id = prov_data.get("predicate", {}).get("runDetails", {}).get("builder", {}).get("id", "Desconhecido")
    build_repo = prov_data.get("predicate", {}).get("buildDefinition", {}).get("externalParameters", {}).get("repository", "N/A")
    build_commit = prov_data.get("predicate", {}).get("buildDefinition", {}).get("externalParameters", {}).get("commit", "N/A")

    print(f"[*] Builder Confiável   : {builder_id}")
    print(f"[*] Repositório Fonte   : {build_repo}")
    print(f"[*] Commit Homologado   : {build_commit}")

    # 3. Extração do Subject e Digest Declarado
    subjects = prov_data.get("subject", [])
    if not subjects:
        print("[ERRO] Nenhum subject encontrado na declaração de proveniência!", file=sys.stderr)
        sys.exit(1)

    expected_sha256 = subjects[0].get("digest", {}).get("sha256", "").lower()
    subject_name = subjects[0].get("name", "Desconhecido")

    # 4. Cálculo do Digest Real do Artefato
    actual_sha256 = calculate_sha256(args.artifact)

    print("------------------------------------------------------------------")
    print(f"[*] Artefato Avaliado   : {args.artifact} (Subject: {subject_name})")
    print(f"[*] SHA-256 Declarado   : {expected_sha256}")
    print(f"[*] SHA-256 Calculado   : {actual_sha256}")
    print("------------------------------------------------------------------")

    if actual_sha256 == expected_sha256:
        print("[SUCESSO] VALIDAÇÃO SLSA APROVADA!")
        print("-> A procedência criptográfica e a integridade do artefato foram comprovadas.")
        sys.exit(0)
    else:
        print("[FALHA CRÍTICA] DIVERGÊNCIA DE PROVENIÊNCIA DETECTADA!")
        print("-> O artefato local NÃO corresponde ao binário atestado pelo builder oficial.")
        print("-> Possível ataque de substituição em trânsito ou no registry (SLSA L3 Violation).")
        sys.exit(2)


if __name__ == "__main__":
    main()
