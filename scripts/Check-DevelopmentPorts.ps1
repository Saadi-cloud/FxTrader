$ports = @(5080, 7080, 5188, 7188)

foreach ($port in $ports) {
    $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if (-not $connections) {
        Write-Host "Port $port is available." -ForegroundColor Green
        continue
    }

    foreach ($connection in $connections) {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        $processName = if ($process) { $process.ProcessName } else { "Unknown" }
        Write-Host "Port $port is used by PID $($connection.OwningProcess) ($processName)." -ForegroundColor Yellow
    }
}
