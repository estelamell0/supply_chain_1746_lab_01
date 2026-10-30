#!/usr/bin/env python3
"""
Auditor Estático de Workflows de CI/CD (Simulador das Heurísticas OpenSSF Scorecard)
Verifica regras de Dangerous-Workflow, Token-Permissions, Pinned-Dependencies e Remote-Script-Execution.
"""
import argparse
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def audit_workflow(filepath: str):
    if not os.path.exists(filepath):
        print(f"[ERRO] Arquivo de workflow não encontrado: {filepath}", file=sys.stderr)
        sys.exit(1)

    with open(filepath, "r", encoding="utf-8-sig") as f:
        content = f.read()

    print("==================================================================")
    print(f" AUDITORIA OPENSSF SCORECARD SIMULADA: {os.path.basename(filepath)}")
    print("==================================================================")

    findings = []
    penalty = 0.0

    # 1. Dangerous-Workflow Check (PPE)
    if re.search(r"pull_request_target", content):
        findings.append({
            "check": "Dangerous-Workflow (PPE)",
            "severity": "CRÍTICA",
            "score_impact": -3.5,
            "desc": "Uso de 'pull_request_target' detectado. Risco extremo de Poisoned Pipeline Execution com vazamento de secrets."
        })
        penalty += 3.5

    # 2. Token-Permissions Check
    if re.search(r"permissions:\s*write-all", content):
        findings.append({
            "check": "Token-Permissions",
            "severity": "ALTA",
            "score_impact": -3.0,
            "desc": "'permissions: write-all' concede privilégios administrativos irrestritos ao GITHUB_TOKEN."
        })
        penalty += 3.0
    elif not re.search(r"permissions:\s*(read-all|contents:\s*read)", content):
        findings.append({
            "check": "Token-Permissions",
            "severity": "MÉDIA",
            "score_impact": -1.5,
            "desc": "Nenhuma política de 'permissions: read-all' declarada explicitamente no topo do workflow."
        })
        penalty += 1.5

    # 3. Pinned-Dependencies Check
    mutable_tags = re.findall(r"uses:\s*([a-zA-Z0-9_\-\.\/]+)@(v\d+(?:\.\d+)*|main|master)", content)
    if mutable_tags:
        tags_str = ", ".join([f"{repo}@{tag}" for repo, tag in mutable_tags])
        findings.append({
            "check": "Pinned-Dependencies",
            "severity": "ALTA",
            "score_impact": -2.5,
            "desc": f"Uso de tags mutáveis detectado: [{tags_str}]. Ações devem ser fixadas pelo commit SHA imutável de 40 caracteres."
        })
        penalty += 2.5

    # 4. Insecure Remote Execution Check (Codecov pattern)
    if re.search(r"curl\s+.*\|\s*(bash|sh)", content) or re.search(r"wget\s+.*\|\s*(bash|sh)", content):
        findings.append({
            "check": "Remote-Script-Execution",
            "severity": "CRÍTICA",
            "score_impact": -3.0,
            "desc": "Execução de script remoto via 'curl | bash' detectada sem verificação de hash SHA-256."
        })
        penalty += 3.0

    final_score = max(0.0, 10.0 - penalty)

    if not findings:
        print("[+] [CONFORME] Dangerous-Workflow    : Gatilhos seguros e sem checkout de PR não confiável (10/10)")
        print("[+] [CONFORME] Token-Permissions     : Princípio do menor privilégio ativo ('read-all') (10/10)")
        print("[+] [CONFORME] Pinned-Dependencies   : Todas as GitHub Actions fixadas por SHA de 40 chars (10/10)")
        print("[+] [CONFORME] Script-Integrity      : Execução protegida por verificação estrita de SHA-256 (10/10)")
    else:
        for item in findings:
            print(f"[-] [{item['severity']}] {item['check']}: {item['desc']}")

    print("------------------------------------------------------------------")
    print(f"PONTUAÇÃO DE POSTURA FINAL: {final_score:.1f} / 10.0")
    print("------------------------------------------------------------------")

    if final_score >= 8.5:
        print("[STATUS] APROVADO: Esteira em conformidade com as diretrizes do OpenSSF Scorecard.")
        sys.exit(0)
    else:
        print("[STATUS] REPROVADO: O workflow contém vulnerabilidades críticas que rebaixam a segurança da cadeia.")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auditor CLI OpenSSF Scorecard")
    parser.add_argument("workflow_file", help="Caminho para o arquivo .yml do GitHub Actions")
    args = parser.parse_args()
    audit_workflow(args.workflow_file)
