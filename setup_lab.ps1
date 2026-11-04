<#
.SYNOPSIS
    Script de Inicializacao e Reset do Laboratorio de Supply Chain Security
    PowerShell Native Driver para Windows (100% paridade byte-a-byte com setup_lab.sh).
#>

param(
    [switch]$Clean
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 0. Limpar chaves temporarias e assinaturas de execucoes anteriores
foreach ($tmpFile in @("privkey.pem", "pubkey.pem", "dist/release.sig", "dist/payment-api-dist.tar.gz")) {
    $fullTmp = Join-Path $ScriptDir $tmpFile
    if (Test-Path -LiteralPath $fullTmp) {
        Remove-Item -LiteralPath $fullTmp -Force
    }
}

# 1. Normalizar fim de linha LF nos scripts de telemetria (protecao contra git core.autocrlf=true)
foreach ($shRel in @("scripts/download_agent.sh", "scripts/download_agent_compromised.sh", "scripts/secure_fetch.sh")) {
    $shFull = Join-Path $ScriptDir $shRel
    if (Test-Path -LiteralPath $shFull) {
        $rawText = [System.IO.File]::ReadAllText($shFull, $Utf8NoBom) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($shFull, $rawText, $Utf8NoBom)
    }
}

# 2. Restaurar src/package.json ao estado integro original (caso modificado na Fase 5)
$PkgPath = Join-Path $ScriptDir "src/package.json"
$CleanPkgJson = "{`n  `"name`": `"payment-api-service`",`n  `"version`": `"1.0.0`",`n  `"description`": `"Serviço de pagamentos para testes de integridade e Supply Chain`",`n  `"main`": `"app.py`",`n  `"scripts`": {`n    `"test`": `"echo \`"Executando testes unitarios...\`" && exit 0`"`n  },`n  `"dependencies`": {`n    `"express`": `"^4.18.2`",`n    `"cross-env`": `"^7.0.3`"`n  }`n}`n"
[System.IO.File]::WriteAllText($PkgPath, $CleanPkgJson, $Utf8NoBom)

if ($Clean) {
    $DistDirClean = Join-Path $ScriptDir "dist"
    if (Test-Path -LiteralPath $DistDirClean) {
        Remove-Item -LiteralPath $DistDirClean -Recurse -Force
    }
    Write-Host "[OK] Artefatos temporarios removidos e arquivos do laboratorio restaurados com sucesso." -ForegroundColor Green
    exit 0
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " INICIALIZANDO AMBIENTE DO LABORATORIO (SUPPLY CHAIN INTEGRITY)    " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 3. Garantir diretorio dist/ e gerar o pacote de release deterministico (LF, sem BOM)
$DistDir = Join-Path $ScriptDir "dist"
if (-not (Test-Path -LiteralPath $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

$ArtifactPath = Join-Path $DistDir "payment-api-dist.tar.gz"
Write-Host "[*] Empacotando artefato de release: dist/payment-api-dist.tar.gz..." -ForegroundColor Yellow

$CodeText = "#!/usr/bin/env python3`nprint('Payment API Microservice Compiled Binary v1.0.0')`n"
[System.IO.File]::WriteAllText($ArtifactPath, $CodeText, $Utf8NoBom)

# 4. Calcular hash SHA-256 real do artefato
$RealHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArtifactPath).Hash.ToLowerInvariant()
Write-Host "[*] Digest SHA-256 do Artefato: $RealHash" -ForegroundColor Green

# 5. Atualizar o arquivo slsa/provenance.json (sem BOM, formatacao limpa)
$ProvPath = Join-Path $ScriptDir "slsa/provenance.json"
if (Test-Path -LiteralPath $ProvPath) {
    $ProvText = [System.IO.File]::ReadAllText($ProvPath, $Utf8NoBom)
    $ProvText = $ProvText -replace '"sha256":\s*"[0-9a-fA-F]{64}"', "`"sha256`": `"$RealHash`""
    $ProvText = $ProvText -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($ProvPath, $ProvText, $Utf8NoBom)
    Write-Host "[*] Atestacao SLSA Provenance v1.0 sincronizada em: slsa/provenance.json" -ForegroundColor Green
}

# 6. Verificar disponibilidade do OpenSSL na sessao PowerShell
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "[AVISO] 'openssl' nao foi detectado no PATH do sistema." -ForegroundColor Yellow
    Write-Host "        Consulte SETUP_AMBIENTE.md para instrucoes de instalacao e configuracao permanente." -ForegroundColor Yellow
}

Write-Host "------------------------------------------------------------------"
Write-Host "[OK] Ambiente do laboratorio pronto para execucao!" -ForegroundColor Green
Write-Host "Consulte README.md para iniciar as atividades praticas."
