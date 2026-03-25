<#
.SYNOPSIS
  Envia eventos de avaliacao para a fila SQS (mesmo JSON do evaluation-service -> analytics).

.DESCRIPTION
  Por padrao usa SendMessageBatch (ate 10 msgs/chamada) para acelerar o envio.
  Requer AWS CLI autenticado e permissao sqs:SendMessage na fila.

.EXAMPLE
  $env:AWS_SQS_URL = "https://sqs.us-east-1.amazonaws.com/123456789012/fiap-evaluation-events"
  $env:AWS_REGION = "us-east-1"
  .\scripts\send-sqs-evaluation-events.ps1 -Count 200

.EXAMPLE
  .\scripts\send-sqs-evaluation-events.ps1 -Count 50 -NoBatch
#>

[CmdletBinding()]
param(
    [string] $QueueUrl,
    [int] $Count = 100,
    [int] $DelayMs = 0,
    [string] $UserId = "user-123",
    [string] $FlagName = "enable-new-dashboard",
    [string] $Region,
    [switch] $NoBatch,
    [ValidateRange(1, 10)][int] $BatchSize = 10
)

if (-not $QueueUrl) { $QueueUrl = $env:SQS_QUEUE_URL }
if (-not $QueueUrl) { $QueueUrl = $env:AWS_SQS_URL }
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

$ident = & aws sts get-caller-identity --region $Region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI nao autenticou ou regiao invalida. Rode 'aws configure' / SSO ou defina `$env:AWS_PROFILE. Detalhe:`n$ident"
    exit $LASTEXITCODE
}

function Send-OneByOne {
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
            "--message-body", $body,
            "--region", $Region
        )
        $out = & aws @argList 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host $out
            Write-Error "aws sqs send-message falhou (codigo $LASTEXITCODE)."
            exit $LASTEXITCODE
        }
        if ($DelayMs -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

function Send-Batches {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $remaining = $Count
    $idx = 1
    while ($remaining -gt 0) {
        $chunk = [Math]::Min($BatchSize, $remaining)
        $entryList = @()
        for ($k = 0; $k -lt $chunk; $k++) {
            $i = $idx + $k
            $resultBool = (($i % 2) -eq 0)
            $ts = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $obj = [ordered]@{
                user_id    = $UserId
                flag_name  = $FlagName
                result     = $resultBool
                timestamp  = $ts
            }
            $bodyStr = $obj | ConvertTo-Json -Compress
            $entryList += [ordered]@{ Id = "b$i"; MessageBody = $bodyStr }
        }

        $cliInput = [ordered]@{
            QueueUrl = $QueueUrl
            Entries  = $entryList
        }
        $json = $cliInput | ConvertTo-Json -Depth 10 -Compress
        $tmp = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), "json")
        try {
            [IO.File]::WriteAllText($tmp, $json, $utf8)
            $abs = (Resolve-Path -LiteralPath $tmp).Path
            $fileUri = "file:///" + $abs.Replace("\", "/")
            $out = & aws sqs send-message-batch --region $Region --cli-input-json $fileUri 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host $out
                Write-Error "aws sqs send-message-batch falhou (codigo $LASTEXITCODE)."
                exit $LASTEXITCODE
            }
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }

        $idx += $chunk
        $remaining -= $chunk
        if ($DelayMs -gt 0 -and $remaining -gt 0) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

if ($NoBatch) {
    Write-Host "Enviando $Count mensagem(ns) (um SendMessage por mensagem; regiao: $Region)..."
    Send-OneByOne
}
else {
    Write-Host "Enviando $Count mensagem(ns) em lotes de ate $BatchSize (SendMessageBatch; regiao: $Region)..."
    Send-Batches
}

Write-Host "Concluido: $Count mensagem(ns) enviada(s)."
