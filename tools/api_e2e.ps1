# End-to-end proof for the M7 backend.
#
# Starts uvicorn on 127.0.0.1:8000 against a throwaway SQLite file, runs
# server/e2e_client.py (guest login -> save put -> leaderboard get -> tournament
# submit), prints PASS and always stops the server.
#
# Usage:  pwsh -File tools/api_e2e.ps1
param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$serverDir = Join-Path $repoRoot "server"
$python = Join-Path $serverDir ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    $python = "python"
    Write-Host "[api_e2e] server/.venv not found, falling back to system python"
} else {
    Write-Host "[api_e2e] using server/.venv"
}

$dbPath = Join-Path $serverDir "e2e.db"
if (Test-Path $dbPath) { Remove-Item -LiteralPath $dbPath -Force }
$stdoutLog = Join-Path $serverDir "e2e_server.log"
$stderrLog = Join-Path $serverDir "e2e_server.err"
foreach ($log in @($stdoutLog, $stderrLog)) {
    if (Test-Path $log) { Remove-Item -LiteralPath $log -Force }
}

# Refuse to attach to an already running server: the proof must use this DB.
try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$Port/healthz" -TimeoutSec 2 | Out-Null
    Write-Error "Something is already listening on 127.0.0.1:$Port; stop it before running the e2e proof."
} catch {
    # Expected: nothing is listening yet.
}

$previous = @{
    DATABASE_URL = $env:DATABASE_URL
    JWT_SECRET = $env:JWT_SECRET
    RUN_HMAC_SECRET = $env:RUN_HMAC_SECRET
    ADMOB_SSV_SECRET = $env:ADMOB_SSV_SECRET
    RATE_LIMIT_ENABLED = $env:RATE_LIMIT_ENABLED
    E2E_BASE_URL = $env:E2E_BASE_URL
}
$env:DATABASE_URL = "sqlite+aiosqlite:///./e2e.db"
$env:JWT_SECRET = "e2e-secret"
$env:RUN_HMAC_SECRET = ""
$env:ADMOB_SSV_SECRET = "e2e-ssv"
$env:RATE_LIMIT_ENABLED = "false"
$env:E2E_BASE_URL = "http://127.0.0.1:$Port"

$server = $null
$exitCode = 1
try {
    Write-Host "[api_e2e] starting uvicorn on 127.0.0.1:$Port"
    $server = Start-Process -FilePath $python `
        -ArgumentList @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "$Port") `
        -WorkingDirectory $serverDir -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 500
        if ($server.HasExited) { break }
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/healthz" -TimeoutSec 2
            if ($health.status -eq "ok") { $ready = $true; break }
        } catch {
            # not up yet
        }
    }
    if (-not $ready) {
        Write-Host "[api_e2e] server did not become ready" -ForegroundColor Red
        if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 30 }
        exit 1
    }
    Write-Host "[api_e2e] healthz ok ($($health.database))"

    & $python (Join-Path $serverDir "e2e_client.py")
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "[api_e2e] e2e client failed" -ForegroundColor Red
        if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 30 }
    }
} finally {
    if ($server -ne $null -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
        $server.WaitForExit(5000) | Out-Null
        Write-Host "[api_e2e] server stopped (pid $($server.Id))"
    }
    $env:DATABASE_URL = $previous.DATABASE_URL
    $env:JWT_SECRET = $previous.JWT_SECRET
    $env:RUN_HMAC_SECRET = $previous.RUN_HMAC_SECRET
    $env:ADMOB_SSV_SECRET = $previous.ADMOB_SSV_SECRET
    $env:RATE_LIMIT_ENABLED = $previous.RATE_LIMIT_ENABLED
    $env:E2E_BASE_URL = $previous.E2E_BASE_URL
}

if ($exitCode -eq 0) {
    Write-Host "[api_e2e] E2E PASS" -ForegroundColor Green
} else {
    Write-Host "[api_e2e] E2E FAIL" -ForegroundColor Red
}
exit $exitCode
