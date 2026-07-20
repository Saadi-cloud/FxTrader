param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PreferredServer = ""
)

$ErrorActionPreference = "Stop"

function Test-SqlConnection {
    param([Parameter(Mandatory = $true)][string]$ServerName)

    $connectionString = "Server=$ServerName;Database=master;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=4;"
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    try {
        $connection.Open()
        return $true
    }
    catch {
        return $false
    }
    finally {
        $connection.Dispose()
    }
}

function Add-Candidate {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]]$List,
        [string]$Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value) -and -not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

Write-Host "Detecting a local SQL Server Database Engine instance..." -ForegroundColor Cyan

$candidates = New-Object 'System.Collections.Generic.List[string]'
Add-Candidate -List $candidates -Value $PreferredServer
Add-Candidate -List $candidates -Value $env:TAHIR_SQL_SERVER

$localDbCommand = Get-Command SqlLocalDB.exe -ErrorAction SilentlyContinue
if ($null -ne $localDbCommand) {
    try {
        & $localDbCommand.Source start MSSQLLocalDB | Out-Null
        Add-Candidate -List $candidates -Value "(localdb)\MSSQLLocalDB"
    }
    catch {
        Write-Host "LocalDB is installed but could not be started: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

try {
    $sqlServices = Get-CimInstance Win32_Service -ErrorAction Stop |
        Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' }

    foreach ($service in $sqlServices) {
        if ($service.State -ne "Running") {
            try {
                Start-Service -Name $service.Name -ErrorAction Stop
                Write-Host "Started SQL service: $($service.Name)" -ForegroundColor DarkGray
            }
            catch {
                Write-Host "SQL service $($service.Name) exists but is not running." -ForegroundColor Yellow
            }
        }

        if ($service.Name -eq "MSSQLSERVER") {
            Add-Candidate -List $candidates -Value "localhost"
        }
        elseif ($service.Name.StartsWith('MSSQL$')) {
            $instanceName = $service.Name.Substring(6)
            Add-Candidate -List $candidates -Value "localhost\$instanceName"
        }
    }
}
catch {
    Write-Host "Could not enumerate SQL Server services: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Common local instance names are last-resort candidates.
Add-Candidate -List $candidates -Value "localhost\SQLEXPRESS"
Add-Candidate -List $candidates -Value ".\SQLEXPRESS"
Add-Candidate -List $candidates -Value "localhost"
Add-Candidate -List $candidates -Value "."

$selectedServer = $null
foreach ($candidate in $candidates) {
    Write-Host "Testing $candidate ..." -ForegroundColor DarkGray
    if (Test-SqlConnection -ServerName $candidate) {
        $selectedServer = $candidate
        break
    }
}

if ([string]::IsNullOrWhiteSpace($selectedServer)) {
    throw @"
No accessible SQL Server Database Engine instance was found.

Installing SQL Server Management Studio alone is not enough. Install one of:
  - SQL Server Express LocalDB, or
  - SQL Server Express/Developer Database Engine.

After installation, rerun this script. You can force an instance name with:
  .\scripts\Setup-LocalDatabase.ps1 -PreferredServer ".\SQLEXPRESS"
"@
}

Write-Host "Using SQL Server instance: $selectedServer" -ForegroundColor Green

$databaseScript = Join-Path $ProjectRoot "Database\FXTraderDb.sql"
if (-not (Test-Path -LiteralPath $databaseScript)) {
    throw "Database script was not found: $databaseScript"
}

$masterConnectionString = "Server=$selectedServer;Database=master;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=15;"
$connection = New-Object System.Data.SqlClient.SqlConnection $masterConnectionString
$connection.Open()

try {
    $sqlText = Get-Content -LiteralPath $databaseScript -Raw
    $batches = [regex]::Split($sqlText, '(?im)^[ \t]*GO[ \t]*(?:--.*)?\r?$')
    $batchNumber = 0

    foreach ($batch in $batches) {
        if ([string]::IsNullOrWhiteSpace($batch)) {
            continue
        }

        $batchNumber++
        $command = $connection.CreateCommand()
        try {
            $command.CommandTimeout = 180
            $command.CommandText = $batch
            [void]$command.ExecuteNonQuery()
        }
        catch {
            throw "Database setup failed in SQL batch $batchNumber. $($_.Exception.Message)"
        }
        finally {
            $command.Dispose()
        }
    }
}
finally {
    $connection.Dispose()
}

$developmentSettingsPath = Join-Path $ProjectRoot "src\TahirFxTrader.Web\appsettings.Development.json"
$developmentConnectionString = "Server=$selectedServer;Database=TahirFxTraderDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=False"
$developmentSettings = [ordered]@{
    "ConnectionStrings" = [ordered]@{
        "DefaultConnection" = $developmentConnectionString
    }
    "Logging" = [ordered]@{
        "LogLevel" = [ordered]@{
            "Default" = "Information"
            "Microsoft.AspNetCore" = "Warning"
        }
    }
}

$developmentSettings |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $developmentSettingsPath -Encoding UTF8

Write-Host "" 
Write-Host "Database TahirFxTraderDb was created/updated successfully." -ForegroundColor Green
Write-Host "Development connection string was saved to:" -ForegroundColor Green
Write-Host "  $developmentSettingsPath" -ForegroundColor White
Write-Host "" 
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  dotnet run --project .\src\TahirFxTrader.Web\TahirFxTrader.Web.csproj --launch-profile 'TahirFxTrader.Web (HTTP)'" -ForegroundColor White
