# Enviar para https://github.com/chavatta/FIAP.git
# .\scripts\push-github.ps1          -> pull + push
# .\scripts\push-github.ps1 -Force -> sobrescreve main no GitHub

param([switch]$Force)

Set-Location (Split-Path $PSScriptRoot -Parent)

$g = @(
    "$env:ProgramFiles\Git\bin\git.exe",
    "$env:ProgramFiles\Git\cmd\git.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $g) { throw "Git nao encontrado." }

# Garantir que existe remote "origin" apontando para o repo
& $g remote remove origin 2>&1 | Out-Null
& $g remote add origin https://github.com/chavatta/FIAP.git 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    & $g remote set-url origin https://github.com/chavatta/FIAP.git
}

Write-Host "Remotes:" ; & $g remote -v

& $g fetch origin
if ($LASTEXITCODE -ne 0) { throw "git fetch falhou." }

if ($Force) {
    Write-Host "Push --force..." -ForegroundColor Yellow
    & $g push -u origin main --force
} else {
    & $g pull origin main --allow-unrelated-histories --no-edit
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Pull falhou. Usa: .\scripts\push-github.ps1 -Force" -ForegroundColor Yellow
        exit 1
    }
    & $g push -u origin main
}
Write-Host "Feito." -ForegroundColor Green
