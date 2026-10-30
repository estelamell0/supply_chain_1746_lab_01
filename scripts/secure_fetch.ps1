<#
.SYNOPSIS
    Wrapper Seguro com Verificacao Estrita de Integridade Criptografica (Hash Pinning)
    PowerShell Native Driver para o Laboratorio de Supply Chain Security.
#>

param (
    [string]$TargetScript = "scripts/download_agent.sh"
)

$ExpectedSha = "BAB6970EAFFE7B9B8A0254332C33A638B175FD92E2EB5E69E66DF509AFFDC1A7"

Write-Host "[SECURE-FETCH] Inspecionando integridade do artefato: $TargetScript" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $TargetScript)) {
    Write-Error "[ERRO CRITICO] Arquivo '$TargetScript' nao encontrado!"
    exit 1
}

$ActualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $TargetScript).Hash.ToUpperInvariant()

Write-Host "[SECURE-FETCH] Hash Calculado : $($ActualSha.ToLowerInvariant())"
Write-Host "[SECURE-FETCH] Hash Homologado: $($ExpectedSha.ToLowerInvariant())"

if ($ActualSha -ne $ExpectedSha) {
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " [ALERTA DE SEGURANCA MAXIMA] FALHA DE INTEGRIDADE CRIPTOGRAFICA!     " -ForegroundColor Red
    Write-Host " O hash do script diverge do valor homologado pela equipe de AppSec.  " -ForegroundColor Red
    Write-Host " Abortando execucao antes que qualquer comando seja executado!        " -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 2
}

Write-Host "[SECURE-FETCH] Integridade confirmada com sucesso! Executando script de forma segura:" -ForegroundColor Green
Write-Host "----------------------------------------------------------------------"

$GitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path -LiteralPath $GitBash) {
    & $GitBash $TargetScript
} else {
    Get-Content -LiteralPath $TargetScript -Encoding UTF8 | Where-Object { $_ -match '^echo ' } | ForEach-Object {
        $msg = $_ -replace '^echo\s+"(.*)"$', '$1'
        Write-Host $msg
    }
}
