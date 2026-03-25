<#
.SYNOPSIS
  Envia eventos de avaliacao para a fila SQS (mesmo JSON do evaluation-service -> analytics).

.DESCRIPTION
  Requer AWS CLI autenticado e permissao sqs:SendMessage na fila.
  Formato da mensagem: user_id, flag_name, result, timestamp (compativel com analytics-service/app.py).

.EXAMPLE
  $env:AWS_SQS_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/fiap-evaluation-events"
  $env:AWS_REGION = "us-east-1"
  .\scripts\send-sqs-evaluation-events.ps1 -Count 200

.EXAMPLE
  .\scripts\send-sqs-evaluation-events.ps1 -QueueUrl $env:AWS_SQS_URL -Count 50 -DelayMs 10
#>

[CmdletBinding()]
param(
    [string] $QueueUrl,
    [int] $Count = 100,
    [int] $DelayMs = 0,
    [string] $UserId = "user-123",
    [string] $FlagName = "enable-new-dashboard",
    [string] $Region
)

if (-not $QueueUrl) { $QueueUrl = $env:SQS_QUEUE_URL }
if (-not $QueueUrl) { $QueueUrl = "https://sqs.us-east-1.amazonaws.com/905418013072/fiap-evaluation-events" }
if (-not $Region) { $Region = $env:AWS_REGION }
if (-not $Region) { $Region = $env:AWS_DEFAULT_REGION }
if (-not $Region) { $Region = "us-east-1" }
if (-not $QueueUrl) {
    Write-Error "Defina -QueueUrl ou as variaveis de ambiente SQS_QUEUE_URL / AWS_SQS_URL."
    exit 1
}

$aws = Get-Command aws -ErrorAction SilentlyContinue
if (-not $aws) {
    Write-Error "AWS CLI nao encontrado no PATH."
    exit 1
}

if ($Count -lt 1) {
    Write-Error "-Count deve ser >= 1."
    exit 1
}

# Falha cedo com mensagem visivel (evita codigo 253 opaco sem stderr)
$ident = & aws sts get-caller-identity --region $Region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI nao autenticou ou regiao invalida. Rode 'aws configure' / SSO ou defina `$env:AWS_PROFILE. Detalhe:`n$ident"
    exit $LASTEXITCODE
}

Write-Host "Enviando $Count mensagem(ns) para a fila (regiao: $Region)..."

for ($i = 1; $i -le $Count; $i++) {
    $resultBool = (($i % 2) -eq 0)
    $ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $obj = [ordered]@{
        user_id    = $UserId
        flag_name  = $FlagName
        result     = $resultBool
        timestamp  = $ts
    }
    $body = $obj | ConvertTo-Json -Compress

    $argList = @(
        "sqs", "send-message",
        "--queue-url", $QueueUrl,
        "--message-body", $body
    )
    $argList += @("--region", $Region)

    $out = & aws @argList 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host $out
        Write-Error "aws sqs send-message falhou (codigo $code). Mensagem acima. Comum: credenciais expiradas, fila em outra regiao, ou sem sqs:SendMessage."
        exit $code
    }

    if ($DelayMs -gt 0) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

Write-Host "Concluido: $Count mensagem(ns) enviada(s)."
