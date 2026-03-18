# Executar: .\scripts\do-commit.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$gitExe = $null
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitExe = "git"
} else {
    $pf86 = [Environment]::GetFolderPath("ProgramFilesX86")
    foreach ($p in @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\bin\git.exe",
        "$pf86\Git\cmd\git.exe"
    )) {
        if (Test-Path -LiteralPath $p) { $gitExe = $p; break }
    }
}
if (-not $gitExe) {
    Write-Error "Git nao encontrado. winget install Git.Git e reabra o terminal."
}

function Invoke-Git { & $gitExe @args }

if (-not (Test-Path .git)) {
    Invoke-Git init
    Invoke-Git branch -M main
}
Invoke-Git add -A
Invoke-Git status

# Mensagem multilinha (here-string literal @' '@ evita erro com linhas que comecam em -)
$commitMsg = @'
chore: ajustes stack FIAP, docs AWS/K8s e compose

- docker-compose: redes, portas DB, redis, credenciais analytics (EC2)
- flag/targeting: FLAG_/TARGETING_DATABASE_URL
- evaluation: toFloat64, fetchRule 404, io.ReadAll
- auth: log seguro em validate
- k8s: secrets, portas, redis evaluation
- docs: LEARNER-LAB, AWS-DEPLOY-ORDEM, CONEXAO-SSH
- scripts ec2-user-data; .gitignore
'@

Invoke-Git commit -m $commitMsg

Write-Host "Commit concluido. Push: git remote add origin <url> && git push -u origin main" -ForegroundColor Green
