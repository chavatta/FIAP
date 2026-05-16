# Demo Script for FIAP Challenge 2 - PowerShell Automation

Write-Host "Step 2: Bringing down and up the stack..."

# Stop and remove containers/volumes
docker-compose down -v

# Start services in detached mode
docker-compose up -d

# Show running containers
docker-compose ps

Write-Host "Confirm 9 containers are running (5 apps + 2 Postgres + Redis + DynamoDB Local)."

Write-Host "Step 3: Checking health of services..."

# Health checks
$healthUrls = @(
    "http://localhost:8001/health",
    "http://localhost:8002/health",
    "http://localhost:8003/health",
    "http://localhost:8004/health",
    "http://localhost:8005/health"
)

foreach ($url in $healthUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing | Select-Object -ExpandProperty Content
        Write-Host "$url : $response"
    } catch {
        Write-Host "$url : Error - $($_.Exception.Message)"
    }
}

Write-Host "Step 4: Full flow (Auth -> Flag/Targeting -> Evaluation)"

# 1) Create API key
Write-Host "Creating API key..."
try {
    $keyResponse = Invoke-WebRequest -Uri http://localhost:8001/admin/keys -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer admin-secreto-123"} -Body '{"name":"evaluation-service"}' -UseBasicParsing | Select-Object -ExpandProperty Content
    Write-Host "Key response: $keyResponse"
    
    # Parse the key
    $keyJson = $keyResponse | ConvertFrom-Json
    $KEY = $keyJson.key
    Write-Host "Extracted KEY: $KEY"
} catch {
    Write-Host "Error creating API key: $($_.Exception.Message)"
    exit 1
}

# 2) Update .env with the key
Write-Host "Updating .env with SERVICE_API_KEY..."
$envPath = ".env"
$envContent = Get-Content $envPath
$updatedContent = $envContent -replace '^SERVICE_API_KEY=.*', "SERVICE_API_KEY=$KEY"
$updatedContent | Set-Content $envPath
Write-Host ".env updated."

# 3) Restart evaluation-service (force recreate to reload .env)
Write-Host "Recreating evaluation-service to reload .env..."
docker-compose up -d --force-recreate evaluation-service

# Wait a bit
Start-Sleep 10

# 4) Create flag
Write-Host "Creating flag..."
try {
    $flagResponse = Invoke-WebRequest -Uri http://localhost:8002/flags -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $KEY"} -Body '{"name":"enable-new-dashboard","description":"demo pdf","is_enabled":true}' -UseBasicParsing
    Write-Host "Flag creation status: $($flagResponse.StatusCode)"
    $flagContent = $flagResponse | Select-Object -ExpandProperty Content
    Write-Host "Flag response: $flagContent"
} catch {
    Write-Host "Error creating flag: $($_.Exception.Message)"
}

# 5) Create rule
Write-Host "Creating rule..."
try {
    $ruleResponse = Invoke-WebRequest -Uri http://localhost:8003/rules -Method POST -Headers @{"Content-Type"="application/json"; "Authorization"="Bearer $KEY"} -Body '{"flag_name":"enable-new-dashboard","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}' -UseBasicParsing
    Write-Host "Rule creation status: $($ruleResponse.StatusCode)"
    $ruleContent = $ruleResponse | Select-Object -ExpandProperty Content
    Write-Host "Rule response: $ruleContent"
} catch {
    Write-Host "Error creating rule: $($_.Exception.Message)"
}

# 6) Evaluate
Write-Host "Evaluating flags..."
try {
    $eval1 = Invoke-WebRequest -Uri "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard" -UseBasicParsing | Select-Object -ExpandProperty Content
    Write-Host "Evaluate user-123: $eval1"
} catch {
    Write-Host "Error evaluating user-123: $($_.Exception.Message)"
}

try {
    $eval2 = Invoke-WebRequest -Uri "http://localhost:8004/evaluate?user_id=user-abc&flag_name=enable-new-dashboard" -UseBasicParsing | Select-Object -ExpandProperty Content
    Write-Host "Evaluate user-abc: $eval2"
} catch {
    Write-Host "Error evaluating user-abc: $($_.Exception.Message)"
}

Write-Host "Challenge Local complete!"