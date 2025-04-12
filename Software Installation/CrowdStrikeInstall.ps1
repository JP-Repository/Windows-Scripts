<#
.SYNOPSIS
    Installs and registers CrowdStrike Falcon Sensor on remote servers.

.DESCRIPTION
    This script automates the installation of the CrowdStrike Falcon Sensor 
    on a list of remote servers, uninstalling any existing installations if needed,
    copying the installer, running it silently, and confirming installation.

.NOTES
    Script Name    : CrowdStrikeInstall.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Automate the deployment of CrowdStrike Falcon Sensor on servers.

.PREREQUISITES
    - Ensure WinRM is enabled on target servers.
    - A valid Falcon Sensor installer is placed at the specified path.
    - CID (Customer ID Checksum) is required.
    - Administrator privileges on remote servers.

.PARAMETERS
    None

.EXAMPLE
    .\CrowdStrikeInstall.ps1
#>

# Variables
$Servers = Get-Content "C:\Temp\TestServers.txt"
$SensorInstallerPath = "C:\Temp\WindowsSensor64.msi"
$CustomerID = "YOUR-CROWDSTRIKE-CID-HERE"
$logFilePath = "C:\Temp\CrowdStrikeInstallLog.txt"
$errorCsvPath = "C:\Temp\CrowdStrikeInstallErrors.csv"

# Initialize counters
$successCount = 0
$failureCount = 0
$skippedCount = 0

# Initialize error CSV
"Server,Reason" | Out-File -FilePath $errorCsvPath

# Start logging
"###### CrowdStrike Falcon Sensor Installation Log ######" | Out-File -FilePath $logFilePath -Append
"Script started at $(Get-Date)" | Out-File -FilePath $logFilePath -Append

foreach ($Server in $Servers) {
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $failureCount++
        "Error: Server name is null or empty." | Out-File -FilePath $errorCsvPath -Append
        continue
    }

    Write-Host "Processing $Server..." -ForegroundColor Cyan
    try {
        $psRemotingEnabled = Test-Connection -ComputerName $Server -Count 1 -Quiet
        if (-not $psRemotingEnabled) {
            $failureCount++
            "$Server,Error: Unable to connect to the server. Ensure WinRM is enabled." | Out-File -FilePath $errorCsvPath -Append
            continue
        }

        Invoke-Command -ComputerName $Server -ScriptBlock { Enable-PSRemoting -Force }

        # Check if Falcon Sensor already installed
        $IsInstalled = Invoke-Command -ComputerName $Server -ScriptBlock {
            Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "CrowdStrike Falcon Sensor*" }
        }

        if ($IsInstalled) {
            Write-Host "CrowdStrike Falcon Sensor already installed on $Server. Skipping..." -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        # Copy installer
        Invoke-Command -ComputerName $Server -ScriptBlock { mkdir "C:\Temp" -Force }
        Copy-Item -Path $SensorInstallerPath -Destination "\\$Server\C$\Temp"

        # Install Sensor
        Invoke-Command -ComputerName $Server -ScriptBlock {
            param ($cid)
            $installer = "C:\Temp\WindowsSensor64.msi"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$installer`" /quiet CID=$cid" -Wait
        } -ArgumentList $CustomerID

        # Validate installation
        $ValidateInstall = Invoke-Command -ComputerName $Server -ScriptBlock {
            Get-Service -Name CSFalconSensor -ErrorAction SilentlyContinue
        }

        if ($ValidateInstall -ne $null) {
            Write-Host "CrowdStrike Falcon Sensor successfully installed on $Server." -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "Sensor installation failed or service not found on $Server." -ForegroundColor Red
            "$Server,Error: Sensor service not found after installation." | Out-File -FilePath $errorCsvPath -Append
            $failureCount++
        }

    } catch {
        Write-Host "An error occurred on $Server $_" -ForegroundColor Red
        "$Server,Error: $_" | Out-File -FilePath $errorCsvPath -Append
        $failureCount++
    }
}

# Summary
Write-Host "###### Script completed ######"
Write-Host "Summary: $successCount succeeded, $failureCount failed, $skippedCount skipped."
"Script completed at $(Get-Date)" | Out-File -FilePath $logFilePath -Append
"Summary: $successCount succeeded, $failureCount failed, $skippedCount skipped." | Out-File -FilePath $logFilePath -Append
