# Laboratório Prático CLI: Investigação Forense e Blindagem da Cadeia de Suprimentos

**Disciplina:** Supply Chain Security & DevSecOps Architecture (Ada Tech)  
**Foco:** Aulas 01 e 02 (Integridade Criptográfica, Ataques Históricos, Framework SLSA v1.0, OpenSSF Scorecard e Blindagem de Pipelines)

---

## 1. Visão Geral do Laboratório

Em ataques à cadeia de suprimentos de software moderna, os invasores raramente alteram o código de negócio diretamente no repositório. Em vez disso, exploram vulnerabilidades nos elos periféricos da esteira:
- Scripts remotos executados sem validação (`curl | bash`), como no caso **Codecov (2021)**;
- Adulteração silenciosa de compiladores e arquivos no servidor de build, como no caso **SolarWinds (2020)**;
- Injeções em tarballs e metadados de empacotamento, como no caso **XZ Utils (2024)**;
- Pipelines de CI/CD permissivas vulneráveis a **Poisoned Pipeline Execution (PPE)**;
- Dependências envenenadas por mutações silenciosas ou **Typosquatting** em ecossistemas abertos.

Neste laboratório 100% prático e executável em linha de comando, você atuará como Engenheiro Principal de DevSecOps, executando auditorias forenses, criando wrappers de validação criptográfica, inspecionando atestações de proveniência **SLSA v1.0** e blindando fluxos de trabalho de integração contínua.

---

## 2. Estrutura do Workspace

```text
lab_01_cli_supply_chain_integrity/
├── README.md                          # Este guia prático com comandos e fundamentação (Alunos)
├── teacher_guide_lab_01.md            # Guia ultradetalhado do instrutor para condução ao vivo
├── .gitattributes                     # Preservação determinística de fim de linha LF
├── setup_lab.ps1                      # Inicializador automático para Windows (PowerShell)
├── setup_lab.sh                       # Inicializador automático para Linux / macOS / WSL / Git Bash
├── dist/                              # Artefatos compilados de release (gerado no setup)
│   └── payment-api-dist.tar.gz
├── src/                               # Aplicação alvo de microsserviço
│   ├── app.py                         # Código-fonte Python
│   ├── package.json                   # Manifesto de dependências
│   └── package-lock.json              # Lockfile com hashes de integridade SHA-512
├── scripts/
│   ├── download_agent.sh              # Agente oficial legítimo
│   ├── download_agent_compromised.sh  # Agente adulterado (simulação Codecov)
│   ├── secure_fetch.sh                # Wrapper seguro com Hash Pinning (Bash)
│   └── secure_fetch.ps1               # Wrapper seguro com Hash Pinning (PowerShell)
├── .github/workflows/
│   ├── pipeline_vulneravel.yml        # Workflow com falhas graves (PPE, write-all, tag mutável)
│   └── pipeline_blindada.yml          # Workflow corrigido conforme SLSA L3 e Scorecard 10/10
├── slsa/
│   ├── provenance.json                # Atestação in-toto v1 / SLSA Provenance v1.0
│   └── verify_provenance.py           # Validador CLI de proveniência
└── tools/
    ├── audit_pipeline.py              # Auditor estático de regras OpenSSF Scorecard
    └── check_typos.py                 # Detector de typosquatting e auditor de lockfile
```

---

## 3. Preparação do Ambiente (Setup)

Abra o seu terminal na pasta do laboratório:

```bash
# No Linux / macOS / WSL:
chmod +x setup_lab.sh
./setup_lab.sh

# No Windows (PowerShell):
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup_lab.ps1
```

O setup cria o pacote de release `dist/payment-api-dist.tar.gz`, calcula seu hash SHA-256 e sincroniza a atestação SLSA de referência em `slsa/provenance.json`.

---

## 4. Roteiro Prático Passo a Passo (5 Fases)

### Fase 1: O Dilema Codecov — Scripts Remotos vs Hash Pinning

#### O Problema
No incidente Codecov de 2021, milhares de esteiras corporativas executavam `curl -s https://codecov.io/bash | bash`. Quando a conta de armazenamento do fornecedor foi invadida, o script foi modificado para roubar variáveis de ambiente (`$GITHUB_TOKEN`, chaves de nuvem, etc.).

#### Execução
1. Calcule o hash SHA-256 do script de telemetria legítimo:
   ```bash
   # Bash:
   sha256sum scripts/download_agent.sh

   # PowerShell:
   Get-FileHash -Algorithm SHA256 scripts/download_agent.sh
   ```
   *Valor esperado:* `bab6970eaffe7b9b8a0254332c33a638b175fd92e2eb5e69e66df509affdc1a7`

2. Execute o wrapper seguro `secure_fetch` apontando para o script legítimo:
   ```bash
   # Bash:
   ./scripts/secure_fetch.sh scripts/download_agent.sh

   # PowerShell:
   .\scripts\secure_fetch.ps1 -TargetScript scripts/download_agent.sh
   ```
   *Resultado:* O wrapper confirma a integridade criptográfica e autoriza a execução.

3. Agora, simule o comprometimento da infraestrutura do fornecedor, tentando executar a versão adulterada:
   ```bash
   # Bash:
   ./scripts/secure_fetch.sh scripts/download_agent_compromised.sh

   # PowerShell:
   .\scripts\secure_fetch.ps1 -TargetScript scripts/download_agent_compromised.sh
   ```
   *Resultado:* O wrapper emite `[ALERTA DE SEGURANÇA MÁXIMA] FALHA DE INTEGRIDADE CRIPTOGRÁFICA!` e aborta com código de saída 2, impedindo o vazamento de credenciais.

---

### Fase 2: Simulação SolarWinds — Assinatura Digital e Detecção de Build Adulterado

#### O Problema
No ataque Sunspot (SolarWinds), o código-fonte no Git estava 100% limpo, mas o executável gerado foi modificado durante o milissegundo da compilação. Como um consumidor pode atestar que o artefato distribuído não foi alterado após ser assinado pela equipe autorizada?

#### Execução
> **Nota para usuários de Windows PowerShell:** Caso o comando `openssl` não esteja no `PATH` da sua janela atual do PowerShell, adicione o diretório do Git for Windows antes de iniciar a Fase 2:
> ```powershell
> $env:PATH += ";C:\Program Files\Git\usr\bin"
> ```

1. Gere um par de chaves assimétricas usando OpenSSL no terminal:
   ```bash
   # Gerar chave privada ECDSA (curva P-256):
   openssl ecparam -genkey -name prime256v1 -out privkey.pem

   # Extrair a chave pública correspondente:
   openssl ec -in privkey.pem -pubout -out pubkey.pem
   ```

2. Assine digitalmente o pacote de release oficial gerado no setup:
   ```bash
   openssl dgst -sha256 -sign privkey.pem -out dist/release.sig dist/payment-api-dist.tar.gz
   ```

3. Valide a assinatura usando a chave pública (simulando a verificação feita por um cliente ou admission controller):
   ```bash
   openssl dgst -sha256 -verify pubkey.pem -signature dist/release.sig dist/payment-api-dist.tar.gz
   ```
   *Resultado:* `Verified OK`

4. Simule a injeção maliciosa do malware Sunspot (adulterando apenas 1 byte do binário):
   ```bash
   # Bash:
   echo "malicious_payload_sunspot" >> dist/payment-api-dist.tar.gz

   # PowerShell:
   Add-Content -Path dist/payment-api-dist.tar.gz -Value "malicious_payload_sunspot"
   ```

5. Repita a verificação da assinatura:
   ```bash
   openssl dgst -sha256 -verify pubkey.pem -signature dist/release.sig dist/payment-api-dist.tar.gz
   ```
   *Resultado:* `Verification Failure`. A alteração física do arquivo torna a assinatura matematicamente inválida, impedindo a subida do artefato trojanizado em produção.

---

### Fase 3: Auditoria Estática de Workflows CI/CD (OpenSSF Scorecard & PPE)

#### O Problema
Workflows de automação com permissões elevadas (`permissions: write-all`), gatilhos arriscados (`pull_request_target`) ou tags mutáveis (`actions/checkout@v4`) representam o vetor primário de invasão em repositórios corporativos.

#### Execução
1. Execute o auditor estático contra o workflow legado da empresa:
   ```bash
   python tools/audit_pipeline.py .github/workflows/pipeline_vulneravel.yml
   ```
   *Diagnóstico emitido:*
   - `[CRÍTICA] Dangerous-Workflow (PPE)`: Uso indevido de `pull_request_target`.
   - `[ALTA] Token-Permissions`: `permissions: write-all` concedendo privilégios excessivos.
   - `[ALTA] Pinned-Dependencies`: Tag mutável `actions/checkout@v4`.
   - `[CRÍTICA] Remote-Script-Execution`: `curl | bash` sem verificação de hash.
   - *Pontuação Final:* `0.0 / 10.0` (REPROVADO).

2. Agora execute o auditor contra o workflow blindado:
   ```bash
   python tools/audit_pipeline.py .github/workflows/pipeline_blindada.yml
   ```
   *Diagnóstico emitido:*
   - *Pontuação Final:* `10.0 / 10.0` (APROVADO).
   - O workflow adota `permissions: read-all`, fixa actions pelo commit SHA imutável de 40 caracteres e executa scripts exclusivamente via wrapper criptográfico.

---

### Fase 4: Validação Forense de Proveniência SLSA v1.0 (in-toto)

#### O Problema
No nível de maturidade **SLSA Build Level 3**, cada artefato gerado deve vir acompanhado de uma declaração formal de proveniência (in-toto Statement) assinada pelo builder oficial, atestando o repositório, o commit exato e os parâmetros de compilação.

#### Execução
1. Inspecione o arquivo de proveniência oficial:
   ```bash
   # Bash:
   cat slsa/provenance.json

   # PowerShell:
   Get-Content slsa/provenance.json
   ```
   Observe os campos estruturais:
   - `_type`: `"https://in-toto.io/Statement/v1"`
   - `subject[0].digest.sha256`: Digest do binário atestado.
   - `predicate.buildDefinition`: Repositório, commit e parâmetros de compilação.
   - `predicate.runDetails.builder.id`: Identificador do runner seguro (`actions/runner@v2`).

2. Restaure o artefato limpo executando o setup novamente para garantir que o binário esteja íntegro:
   ```bash
   # Bash: ./setup_lab.sh | PowerShell: .\setup_lab.ps1
   ```

3. Execute o validador de proveniência:
   ```bash
   python slsa/verify_provenance.py --artifact dist/payment-api-dist.tar.gz --provenance slsa/provenance.json
   ```
   *Resultado:* `[SUCESSO] VALIDAÇÃO SLSA APROVADA!`

4. Altere o artefato adicionando qualquer dado espúrio e re-execute o validador:
   ```bash
   # Bash:
   echo "tampered" >> dist/payment-api-dist.tar.gz
   # PowerShell:
   Add-Content -Path dist/payment-api-dist.tar.gz -Value "tampered"

   python slsa/verify_provenance.py --artifact dist/payment-api-dist.tar.gz --provenance slsa/provenance.json
   ```
   *Resultado:* `[FALHA CRÍTICA] DIVERGÊNCIA DE PROVENIÊNCIA DETECTADA!` (Código de saída 2).

---

### Fase 5 (Ponte Aula 02): Imutabilidade de Lockfiles e Bloqueio de Typosquatting

#### O Problema
Em gerenciadores de pacotes (`npm`, `pip`, `cargo`), desenvolvedores frequentemente digitam nomes com pequenos erros ortográficos (*typosquatting*) ou confiam em version ranges semânticos (`^` e `~`) sem validar hashes de integridade.

#### Execução
1. Inspecione os atributos de integridade criptográfica no arquivo `src/package-lock.json`:
   ```bash
   # Bash:
   grep -n "integrity" src/package-lock.json

   # PowerShell:
   Select-String -Path src/package-lock.json -Pattern "integrity"
   ```
   *Explicação:* O prefixo `sha512-...` garante que o tarball baixado pelo comando `npm ci` tenha exatamente o conteúdo auditado no momento do congelamento do lockfile.

2. Execute o detector de Typosquatting fornecido no laboratório:
   ```bash
   python tools/check_typos.py src/package.json
   ```
   *Resultado:* `[SUCESSO] Nenhuma discrepância de typosquatting detectada nas dependências.`

3. Edite o arquivo `src/package.json` e altere a dependência `"cross-env"` para `"crossenv"` (ataque real de typosquatting registrado no npm):
   - Altere `"cross-env": "^7.0.3"` para `"crossenv": "^7.0.3"`.

4. Re-execute o detector:
   ```bash
   python tools/check_typos.py src/package.json
   ```
   *Resultado:*
   ```text
   [ALERTA CRÍTICO] Possível Typosquatting: 'crossenv' é quase idêntico ao pacote consagrado 'cross-env' (Distância 1)!
   [FALHA] 1 suspeita(s) de typosquatting encontrada(s). Bloquear build!
   ```

---

## 5. Questões de Autoavaliação e Fixação

Ao concluir o laboratório, responda às seguintes perguntas técnicas:

1. **Por que o comando `npm install` é expressamente desencorajado em esteiras de produção e qual a diferença técnica em relação ao `npm ci`?**
2. **No ataque SolarWinds, por que a assinatura digital com o certificado corporativo legítimo foi insuficiente para proteger os 18.000 clientes da empresa?**
3. **Qual a vulnerabilidade fundamental na instrução `actions/checkout@v4` e por que a fixação por commit SHA (40 caracteres) é mandatório para conformidade com o nível SLSA L3?**
4. **Em um ataque de Poisoned Pipeline Execution (PPE) alavancado por `pull_request_target`, qual recurso da esteira o atacante obtém e como a restrição `permissions: read-all` reduz o raio de explosão?**

---

## 6. Gabarito Resumido das Questões de Fixação

<details>
<summary><strong>Clique para expandir o Gabarito Oficial</strong></summary>

1. **`npm install` vs `npm ci`:**  
   O `npm install` é permissivo: caso encontre divergências ou operadores de range (`^`), ele pode resolver versões mais novas e reescrever o `package-lock.json` em tempo de execução, permitindo que pacotes maliciosos recém-publicados entrem no build. O `npm ci` (Clean Install) é estrito e determinístico: ele nunca altera o lockfile, apaga a pasta `node_modules` e falha imediatamente se o `package.json` e o `package-lock.json` não coincidirem exatamente em versões e hashes de integridade SHA-512.

2. **Assinatura SolarWinds:**  
   A assinatura tradicional valida apenas que o binário foi assinado pela autoridade da chave privada corporativa. Como o malware *Sunspot* adulterou os arquivos-fonte em memória durante a compilação do `csc.exe` *antes* da fase de assinatura, o binário já foi gerado infectado e depois assinado legitimamente. Sem ambientes de build herméticos e isolados (SLSA L3) e compilação reproduzível, a assinatura atesta com sucesso um artefato comprometido.

3. **Fragilidade de Tags Mutáveis:**  
   Tags no Git (como `@v4` ou `@v1.2.0`) são ponteiros mutáveis que podem ser deletados e recriados apontando para qualquer commit por qualquer conta com permissão de escrita no repositório da action. Fixar pelo commit SHA de 40 caracteres garante imutabilidade matemática garantida pelo grafo do Git (Merkle Tree).

4. **PPE e `pull_request_target`:**  
   O gatilho `pull_request_target` executa no contexto do repositório base e tem acesso direto aos secrets da organização (ex: tokens de nuvem, credenciais de deploy). Se o workflow fizer checkout do código enviado pelo PR externo não confiável e executar comandos (como scripts de teste ou build), o código do invasor roda com acesso total aos segredos. Definir `permissions: read-all` impede que o token herdado possua poderes de escrita no repositório, mitigando a capacidade do invasor de injetar commits maliciosos na branch `main`.

</details>

