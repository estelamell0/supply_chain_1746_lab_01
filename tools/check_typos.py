#!/usr/bin/env python3
"""
Detector de Typosquatting e Auditor de Integridade de Lockfile (npm ci)
Verifica distância de edição (Levenshtein) contra pacotes populares e sincronia com package-lock.json.
"""
import argparse
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

POPULAR_PACKAGES = [
    "express", "lodash", "cross-env", "react", "axios",
    "request", "requests", "chalk", "moment", "commander"
]


def levenshtein(s1: str, s2: str) -> int:
    if len(s1) < len(s2):
        return levenshtein(s2, s1)
    if len(s2) == 0:
        return len(s1)
    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
    return previous_row[-1]


def main():
    parser = argparse.ArgumentParser(description="Auditor de Typosquatting e Lockfile em package.json")
    parser.add_argument("package_json", help="Caminho para o arquivo package.json")
    args = parser.parse_args()

    if not os.path.exists(args.package_json):
        print(f"[ERRO] Arquivo não encontrado: {args.package_json}", file=sys.stderr)
        sys.exit(1)

    with open(args.package_json, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    deps = list(data.get("dependencies", {}).keys()) + list(data.get("devDependencies", {}).keys())

    print("==================================================================")
    print(" AUDITORIA DE TYPOSQUATTING & INTEGRIDADE DE LOCKFILE (AULA 02)   ")
    print("==================================================================")
    print(f"[*] Pacotes declarados no manifesto: {deps}")

    alerts = 0
    for dep in deps:
        for popular in POPULAR_PACKAGES:
            dist = levenshtein(dep, popular)
            if dist == 1:
                print(
                    f"[ALERTA CRÍTICO] Possível Typosquatting: '{dep}' é quase idêntico "
                    f"ao pacote consagrado '{popular}' (Distância Levenshtein = 1)!"
                )
                alerts += 1
            elif dist == 0:
                print(f"[OK] Pacote legítimo verificado no dicionário: '{dep}'")

    # Verificação complementar do package-lock.json adjacente (Simulação npm ci)
    lockfile_path = os.path.join(os.path.dirname(args.package_json), "package-lock.json")
    if os.path.exists(lockfile_path):
        with open(lockfile_path, "r", encoding="utf-8-sig") as lf:
            lock_data = json.load(lf)
        packages_map = lock_data.get("packages", {})
        for dep in deps:
            node_key = f"node_modules/{dep}"
            if node_key not in packages_map:
                print(
                    f"[ALERTA DE LOCKFILE] Divergência estilo 'npm ci': '{dep}' foi declarado no "
                    f"package.json, mas NÃO existe no package-lock.json congelado!"
                )
                alerts += 1
            else:
                integrity = packages_map[node_key].get("integrity", "")
                if integrity.startswith("sha512-"):
                    print(f"[OK] Lockfile íntegro para '{dep}' ({integrity[:28]}...)")
                else:
                    print(f"[ALERTA DE LOCKFILE] Pacote '{dep}' sem hash SHA-512 de integridade!")
                    alerts += 1

    print("------------------------------------------------------------------")
    if alerts > 0:
        print(f"[FALHA] {alerts} violação(ões) de segurança detectada(s). Bloquear build!")
        sys.exit(1)
    else:
        print("[SUCESSO] Nenhuma discrepância de typosquatting ou lockfile detectada.")
        sys.exit(0)


if __name__ == "__main__":
    main()
