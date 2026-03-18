# Executar no PowerShell na pasta do projeto (com Git instalado):
#   .\scripts\do-commit.ps1
# Instalar Git: https://git-scm.com/download/win ou winget install Git.Git

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git nao encontrado. Instale Git for Windows e abra um novo terminal."
}
if (-not (Test-Path .git)) {
    git init
    git branch -M main
}
git add -A
git status
git commit -m @"
chore: ajustes stack FIAP, docs AWS/K8s e compose

- docker-compose: redes, portas DB, redis, credenciais analytics (EC2)
- flag/targeting: FLAG_/TARGETING_DATABASE_URL
- evaluation: toFloat64, fetchRule 404, io.ReadAll
- auth: log seguro em validate
- k8s: secrets, portas 8002-8004, redis evaluation
- docs: LEARNER-LAB, AWS-DEPLOY-ORDEM, CONEXAO-SSH, README checklist
- Makefile aws target, scripts ec2-user-data
- .gitignore: pem, ssourl, .env
"@

Write-Host "Commit concluido. Para enviar: git remote add origin <url> && git push -u origin main" -ForegroundColor Green
