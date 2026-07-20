param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

Write-Host "Resetting local ASP.NET Core development settings..." -ForegroundColor Cyan

# Remove stale per-process and per-user URL bindings. A browser path such as
# /account/login must never be part of ASPNETCORE_URLS.
[Environment]::SetEnvironmentVariable('ASPNETCORE_URLS', $null, 'Process')
[Environment]::SetEnvironmentVariable('ASPNETCORE_URLS', $null, 'User')
Remove-Item Env:ASPNETCORE_URLS -ErrorAction SilentlyContinue

# Stop processes that may lock build output.
Get-Process dotnet, iisexpress, MSBuild, devenv -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

# Remove Visual Studio and compiler caches.
Remove-Item (Join-Path $ProjectRoot '.vs') -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $ProjectRoot -Directory -Recurse -Force |
    Where-Object { $_.Name -in @('bin', 'obj') } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Local cache reset completed." -ForegroundColor Green
Write-Host "Open the solution, select 'TahirFxTrader.Web (HTTP)', and run it." -ForegroundColor Yellow
Write-Host "Application URL: http://localhost:5188" -ForegroundColor Yellow
Write-Host "Login page:      http://localhost:5188/account/login" -ForegroundColor Yellow
